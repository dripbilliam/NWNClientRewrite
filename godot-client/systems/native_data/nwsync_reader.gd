extends RefCounted
# Native read-only SQLite helper. Requests are serialized across asset workers;
# only raw cache records cross this pipe, never renderer-prepared data.
const LIMIT:=256*1024*1024
var child: Dictionary={}
var mutex:=Mutex.new()
var state_mutex:=Mutex.new()
var closed:=false
var pending:=false
var owned_pid:=-1
var process_pipe:=false
var timeout_ms:=30000
func open(executable: String, directory: String) -> bool:
	mutex.lock()
	state_mutex.lock()
	var allowed:=child.is_empty() and not closed and executable.is_absolute_path() and directory.is_absolute_path()
	state_mutex.unlock()
	if not allowed:mutex.unlock();return false
	var started:=OS.execute_with_pipe(executable,PackedStringArray([directory]),false)
	var ready:=started.has("stdio") and started.has("pid") and int(started.pid)>0
	state_mutex.lock()
	if ready and not closed:
		child=started;owned_pid=int(started.pid);process_pipe=true
		state_mutex.unlock();mutex.unlock();return true
	state_mutex.unlock()
	# A concurrent close may have cancelled startup while the process was being
	# created. Do not publish an orphaned pipe or kill a PID owned by close().
	if started.has("stdio"):started.stdio.close()
	if started.has("stderr"):started.stderr.close()
	if started.has("pid") and int(started.pid)>0 and OS.is_process_running(int(started.pid)):OS.kill(int(started.pid))
	mutex.unlock()
	return false
func cancelled()->bool:
	state_mutex.lock();var value:=closed;state_mutex.unlock()
	return value
func exact(pipe: FileAccess, count: int, deadline: int) -> PackedByteArray:
	var result:=PackedByteArray()
	while result.size()<count and Time.get_ticks_msec()<deadline:
		if cancelled():break
		var part:=pipe.get_buffer(mini(65536,count-result.size()))
		if cancelled():break
		if not part.is_empty(): result.append_array(part)
		elif not OS.is_process_running(int(child.pid)): break
		else: OS.delay_usec(1000)
	return result
func request(operation: int, payload: PackedByteArray) -> Dictionary:
	var began:=Time.get_ticks_usec()
	mutex.lock()
	var acquired:=Time.get_ticks_usec()
	state_mutex.lock();pending=true;state_mutex.unlock()
	var result:=_request(operation,payload)
	state_mutex.lock();pending=false;state_mutex.unlock()
	result.timings={"wait_us":acquired-began,"pipe_us":Time.get_ticks_usec()-acquired}
	mutex.unlock()
	return result
func _request(operation: int, payload: PackedByteArray) -> Dictionary:
	if cancelled() or child.is_empty(): return {"error":"NWSync content reader is closed"}
	if payload.size()+1>LIMIT: return {"error":"NWSync reader request exceeds the supported size"}
	if operation<0 or operation>255: return {"error":"NWSync content reader rejected the data"}
	var pipe: FileAccess=child.stdio
	var frame:=PackedByteArray(); frame.resize(5); frame.encode_u32(0,payload.size()+1); frame[4]=operation; frame.append_array(payload)
	pipe.store_buffer(frame)
	if cancelled():return {"error":"NWSync content reader is unavailable"}
	var deadline:=Time.get_ticks_msec()+timeout_ms
	var header:=exact(pipe,4,deadline)
	if cancelled():return {"error":"NWSync content reader is unavailable"}
	if header.size()!=4: _close(); return {"error":"NWSync content reader is unavailable"}
	var length:=int(header.decode_u32(0))
	if length<1 or length>LIMIT+1: _close(); return {"error":"NWSync content reader is unavailable"}
	var body:=exact(pipe,length,deadline)
	if cancelled():return {"error":"NWSync content reader is unavailable"}
	if body.size()!=length: _close(); return {"error":"NWSync content reader is unavailable"}
	# For a nonblocking process pipe, get_length() is unread buffered bytes.
	# File-backed synthetic fixtures instead expose total length/position.
	var surplus:=pipe.get_length() if process_pipe else pipe.get_length()-pipe.get_position()
	if surplus>0: _close(); return {"error":"NWSync content reader is unavailable"}
	if body[0]==1: return {"missing":true}
	if body[0]!=0: return {"error":"NWSync content reader rejected the data"}
	return {"bytes":body.slice(1)}
func close() -> void:
	# Mark cancellation and stop only our helper before waiting for a request
	# holding the pipe mutex. Closing FileAccess concurrently with get_buffer
	# would race, so handle cleanup remains serialized below.
	state_mutex.lock()
	closed=true
	var pid:=owned_pid
	# Node ends stdin first and kills the child after a 500 ms grace period.
	# An active synchronous Godot pipe read must be interrupted immediately.
	if pending and pid>0 and OS.is_process_running(pid):OS.kill(pid)
	state_mutex.unlock()
	mutex.lock();_close();mutex.unlock()
func _close() -> void:
	state_mutex.lock();closed=true;var pid:=owned_pid;owned_pid=-1;state_mutex.unlock()
	if child.is_empty(): return
	child.stdio.close()
	if child.has("stderr"): child.stderr.close()
	if pid>0:
		var deadline:=Time.get_ticks_msec()+500
		while OS.is_process_running(pid) and Time.get_ticks_msec()<deadline: OS.delay_usec(1000)
		if OS.is_process_running(pid): OS.kill(pid)
	child.clear()
	process_pipe=false
func _notification(what: int) -> void:
	# During RefCounted destruction GDScript method dispatch may already have
	# lost its script instance. Release native handles here without self calls.
	if what==NOTIFICATION_PREDELETE:
		# Store.readers and the active request's local `owned` keep a reference
		# until its request returns; this is only abandoned-reader cleanup.
		mutex.lock()
		state_mutex.lock();closed=true;var pid:=owned_pid;owned_pid=-1;state_mutex.unlock()
		if not child.is_empty():
			child.stdio.close()
			if child.has("stderr"): child.stderr.close()
			if pid>0 and OS.is_process_running(pid): OS.kill(pid)
			child.clear()
		process_pipe=false
		mutex.unlock()
