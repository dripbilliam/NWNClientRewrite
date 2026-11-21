extends RefCounted
# Godot owns the NWN cryptographic session. The existing libhydrogen helper
# keeps private key material in a private pipe and never exposes it to logs.
const MAX_FRAME:=65537
const TIMEOUT_MS:=5000
var child: Dictionary={}
var closed:=false
var pending:=false
var write_task_id: int=-1
var last_error: String=""

func open(executable: String)->bool:
	if closed or not child.is_empty() or not executable.is_absolute_path() or not FileAccess.file_exists(executable):return false
	child=OS.execute_with_pipe(executable,PackedStringArray(),true)
	if not child.has("stdio") or not child.has("pid"):
		child.clear()
		return false
	var loop:=Engine.get_main_loop()
	if loop is SceneTree:loop.process_frame.connect(Callable(self,"idle_poll"))
	return true

func exact(count: int,deadline: int)->PackedByteArray:
	var result:=PackedByteArray()
	var pipe: FileAccess=child.stdio
	while not closed and result.size()<count and Time.get_ticks_msec()<deadline:
		discard_stderr()
		var available:=pipe.get_length()
		if available>0:
			var part:=pipe.get_buffer(mini(count-result.size(),available))
			if not part.is_empty():result.append_array(part)
		elif not OS.is_process_running(int(child.pid)):break
		if result.size()<count and not closed:await (Engine.get_main_loop() as SceneTree).process_frame
	return result

func discard_stderr()->void:
	if child.is_empty() or not child.has("stderr"):return
	var stream: FileAccess=child.stderr
	if stream==null:return
	var available:=stream.get_length()
	if available>0:
		var discarded:=stream.get_buffer(mini(available,65536))
		discarded.fill(0)

func idle_poll()->void:
	if closed or child.is_empty():return
	discard_stderr()
	if pending:return
	if child.stdio.get_length()>0 or not OS.is_process_running(int(child.pid)):close()

func request(operation: int,payload: PackedByteArray=PackedByteArray())->Dictionary:
	if closed or child.is_empty():return {"error":"Native network crypto helper is closed"}
	if pending:return {"error":"Concurrent native crypto operations are unavailable"}
	if payload.size()>65535:return {"error":"Invalid native crypto request size"}
	if child.stdio.get_length()>0:
		close()
		return {"error":"Unexpected native network crypto response"}
	pending=true
	var deadline:=Time.get_ticks_msec()+TIMEOUT_MS
	var frame:=PackedByteArray();frame.resize(5);frame.encode_u32(0,payload.size()+1);frame[4]=operation;frame.append_array(payload)
	var pipe: FileAccess=child.stdio
	var write_state: Dictionary={"ok":false}
	var task_id:=WorkerThreadPool.add_task(func():write_state.ok=pipe.store_buffer(frame),true,"NWN crypto pipe write")
	write_task_id=task_id
	while not closed and not WorkerThreadPool.is_task_completed(task_id):
		if closed or Time.get_ticks_msec()>=deadline:
			if not child.is_empty() and OS.is_process_running(int(child.pid)):OS.kill(int(child.pid))
		await (Engine.get_main_loop() as SceneTree).process_frame
	if write_task_id==task_id:
		WorkerThreadPool.wait_for_task_completion(task_id)
		write_task_id=-1
	frame.fill(0)
	if closed:
		pending=false
		return {"error":"Native network crypto helper closed"}
	if Time.get_ticks_msec()>=deadline:
		pending=false
		close()
		return {"error":"Native network crypto helper timed out"}
	if not bool(write_state.ok):
		pending=false
		close()
		return {"error":"Native network crypto helper input failed"}
	var header:=await exact(5,deadline)
	if header.size()!=5:
		var failure:="Native network crypto helper stopped"
		if closed:failure="Native network crypto helper closed"
		elif Time.get_ticks_msec()>=deadline:failure="Native network crypto helper timed out"
		pending=false
		if not closed:close()
		return {"error":failure}
	if closed:
		pending=false
		return {"error":"Native network crypto helper closed"}
	var length:=int(header.decode_u32(0))
	if length<1 or length>MAX_FRAME:
		pending=false
		close()
		return {"error":"Invalid native network crypto response"}
	var output:=await exact(length-1,deadline)
	if output.size()!=length-1:
		var failure:="Native network crypto helper stopped"
		if closed:failure="Native network crypto helper closed"
		elif Time.get_ticks_msec()>=deadline:failure="Native network crypto helper timed out"
		pending=false
		if not closed:close()
		return {"error":failure}
	if closed:
		output.fill(0)
		pending=false
		return {"error":"Native network crypto helper closed"}
	if child.stdio.get_length()>0:
		output.fill(0)
		pending=false
		close()
		return {"error":"Unexpected native network crypto response"}
	pending=false
	if header[4]!=0:
		output.fill(0)
		return {"error":"Native network cryptographic authentication failed" if header[4]==2 else "Invalid native crypto operation"}
	return {"bytes":output}

func start()->Dictionary:
	var result: Dictionary=await request(1)
	if not result.has("bytes") or result.bytes.size()!=32:return {"error":result.get("error","Invalid native key-exchange packet1")}
	return result

func finish(packet2: PackedByteArray)->Dictionary:
	if packet2.size()!=80:return {"error":"Invalid native key-exchange packet2"}
	var result: Dictionary=await request(2,packet2)
	if not result.has("bytes") or result.bytes.size()!=80:
		return {"error":result.get("error","Invalid native key-exchange packet3")}
	var packet3: PackedByteArray=result.bytes.slice(0,48)
	var server_public_key: PackedByteArray=result.bytes.slice(48,80)
	result.bytes.fill(0)
	return {"packet3":packet3,"server_public_key":server_public_key}

func reset()->bool:
	var result: Dictionary=await request(3)
	if not result.has("bytes"):
		last_error=str(result.get("error","Invalid native crypto operation"))
		return false
	last_error=""
	return true

func application_id()->int:
	var result: Dictionary=await request(7)
	if not result.has("bytes") or result.bytes.size()!=4:
		last_error=str(result.get("error","Invalid native application identity output"))
		return -1
	last_error=""
	return int(result.bytes.decode_u32(0))

func platform_identity(platform_id: int,key: PackedByteArray)->Dictionary:
	if platform_id<0 or platform_id>255 or key.size()!=32:return {"error":"Invalid native platform identity input"}
	var payload:=PackedByteArray([platform_id]);payload.append_array(key)
	var result: Dictionary=await request(4,payload);payload.fill(0)
	if not result.has("bytes") or result.bytes.size()!=36:return {"error":result.get("error","Invalid native platform identity output")}
	var value: String=result.bytes.hex_encode()
	result.bytes.fill(0)
	return {"identity":value}

func seal(plain: PackedByteArray)->Dictionary:
	if plain.size()>65466:return {"error":"Invalid native session plaintext length"}
	var result: Dictionary=await request(5,plain)
	if not result.has("bytes") or result.bytes.size()!=plain.size()+36:return {"error":result.get("error","Invalid native session ciphertext length")}
	return result

func unseal(ciphertext: PackedByteArray)->Dictionary:
	if ciphertext.size()<36 or ciphertext.size()>65502:return {"error":"Invalid native session ciphertext length"}
	var result: Dictionary=await request(6,ciphertext)
	if not result.has("bytes") or result.bytes.size()!=ciphertext.size()-36:return {"error":result.get("error","Invalid native session plaintext length")}
	return result

func close()->void:
	if closed:return
	closed=true
	var loop:=Engine.get_main_loop()
	if loop is SceneTree and loop.process_frame.is_connected(Callable(self,"idle_poll")):loop.process_frame.disconnect(Callable(self,"idle_poll"))
	if child.is_empty():return
	var pid:=int(child.pid)
	if write_task_id>=0 and OS.is_process_running(pid):OS.kill(pid)
	child.stdio.close()
	if write_task_id>=0:
		WorkerThreadPool.wait_for_task_completion(write_task_id)
		write_task_id=-1
	if child.has("stderr"):child.stderr.close()
	child.clear()
	pending=false
	if not OS.is_process_running(pid):return
	if loop is SceneTree:
		var timer: SceneTreeTimer=loop.create_timer(0.5)
		timer.timeout.connect(func():
			if OS.is_process_running(pid):OS.kill(pid))
	else:OS.kill(pid)
