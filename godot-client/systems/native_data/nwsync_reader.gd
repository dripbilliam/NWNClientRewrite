extends RefCounted
# Native read-only SQLite helper. Requests are serialized across asset workers;
# only raw cache records cross this pipe, never renderer-prepared data.
const LIMIT:=256*1024*1024
var child: Dictionary={}
var mutex:=Mutex.new()
var closed:=false
var timeout_ms:=30000
func open(executable: String, directory: String) -> bool:
	if not child.is_empty() or closed or not executable.is_absolute_path() or not directory.is_absolute_path(): return false
	child=OS.execute_with_pipe(executable,PackedStringArray([directory]),false)
	return child.has("stdio") and child.has("pid")
func exact(pipe: FileAccess, count: int, deadline: int) -> PackedByteArray:
	var result:=PackedByteArray()
	while result.size()<count and Time.get_ticks_msec()<deadline:
		var part:=pipe.get_buffer(mini(65536,count-result.size()))
		if not part.is_empty(): result.append_array(part)
		elif not OS.is_process_running(int(child.pid)): break
		else: OS.delay_usec(1000)
	return result
func request(operation: int, payload: PackedByteArray) -> Dictionary:
	var began:=Time.get_ticks_usec()
	mutex.lock()
	var acquired:=Time.get_ticks_usec()
	var result:=_request(operation,payload)
	result.timings={"wait_us":acquired-began,"pipe_us":Time.get_ticks_usec()-acquired}
	mutex.unlock()
	return result
func _request(operation: int, payload: PackedByteArray) -> Dictionary:
	if closed or child.is_empty(): return {"error":"Native NWSync reader is closed"}
	if operation not in [1,2,4,5] or payload.size()>40: return {"error":"Invalid native NWSync request"}
	var pipe: FileAccess=child.stdio
	var frame:=PackedByteArray(); frame.resize(5); frame.encode_u32(0,payload.size()+1); frame[4]=operation; frame.append_array(payload)
	pipe.store_buffer(frame)
	var deadline:=Time.get_ticks_msec()+timeout_ms
	var header:=exact(pipe,4,deadline)
	if header.size()!=4: _close(); return {"error":"Native NWSync reader timed out or exited"}
	var length:=int(header.decode_u32(0))
	if length<1 or length>LIMIT+1: _close(); return {"error":"Native NWSync response exceeds bound"}
	var body:=exact(pipe,length,deadline)
	if body.size()!=length: _close(); return {"error":"Native NWSync response is incomplete"}
	if body[0]==1: return {"missing":true}
	if body[0]!=0: return {"error":"Native NWSync cache rejected the request"}
	return {"bytes":body.slice(1)}
func close() -> void:
	mutex.lock(); _close(); mutex.unlock()
func _close() -> void:
	if closed: return
	closed=true
	if child.is_empty(): return
	var pid:=int(child.pid)
	child.stdio.close()
	if child.has("stderr"): child.stderr.close()
	var deadline:=Time.get_ticks_msec()+100
	while OS.is_process_running(pid) and Time.get_ticks_msec()<deadline: OS.delay_usec(1000)
	if OS.is_process_running(pid): OS.kill(pid)
	child.clear()
func _notification(what: int) -> void:
	# During RefCounted destruction GDScript method dispatch may already have
	# lost its script instance. Release native handles here without self calls.
	if what==NOTIFICATION_PREDELETE and not closed:
		closed=true
		if not child.is_empty():
			child.stdio.close()
			if child.has("stderr"): child.stderr.close()
			if OS.is_process_running(int(child.pid)): OS.kill(int(child.pid))
