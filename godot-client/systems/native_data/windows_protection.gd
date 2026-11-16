extends RefCounted
# The Godot settings owner uses this narrow Windows API bridge. Secret bytes
# travel only through a private child pipe; no command line or log contains them.
const MAX_BYTES:=65536
var child: Dictionary={}
var closed:=false

func open(executable: String)->bool:
	if closed or not child.is_empty() or not executable.is_absolute_path() or not FileAccess.file_exists(executable):return false
	child=OS.execute_with_pipe(executable,PackedStringArray(["serve"]),false)
	return child.has("stdio") and child.has("pid")

func exact(pipe: FileAccess,count: int)->PackedByteArray:
	var bytes:=PackedByteArray()
	var deadline:=Time.get_ticks_msec()+15000
	while bytes.size()<count and Time.get_ticks_msec()<deadline:
		var part:=pipe.get_buffer(count-bytes.size())
		if not part.is_empty():bytes.append_array(part)
		elif not OS.is_process_running(int(child.pid)):break
		else:OS.delay_usec(1000)
	return bytes

func request(operation: int,payload: PackedByteArray)->Dictionary:
	if closed or child.is_empty() or operation not in [1,2] or payload.is_empty() or payload.size()>MAX_BYTES:return {"error":"Windows key protection is unavailable"}
	var pipe: FileAccess=child.stdio
	var frame:=PackedByteArray();frame.resize(5);frame.encode_u32(0,payload.size());frame[4]=operation;frame.append_array(payload)
	pipe.store_buffer(frame)
	frame.fill(0)
	var header:=exact(pipe,5)
	if header.size()!=5:close();return {"error":"Windows key protection stopped responding"}
	var length:=int(header.decode_u32(0))
	if header[4]!=0 or length<1 or length>MAX_BYTES:return {"error":"Windows could not unlock this user's saved key"}
	var output:=exact(pipe,length)
	if output.size()!=length:close();return {"error":"Windows key protection returned incomplete data"}
	return {"bytes":output}

func protect(value: PackedByteArray)->Dictionary:return request(1,value)
func unprotect(value: PackedByteArray)->Dictionary:return request(2,value)

func close()->void:
	if closed:return
	closed=true
	if child.is_empty():return
	var pid:=int(child.pid)
	child.stdio.close()
	if child.has("stderr"):child.stderr.close()
	var deadline:=Time.get_ticks_msec()+100
	while OS.is_process_running(pid) and Time.get_ticks_msec()<deadline:OS.delay_usec(1000)
	if OS.is_process_running(pid):OS.kill(pid)
	child.clear()
