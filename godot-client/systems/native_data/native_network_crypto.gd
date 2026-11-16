extends RefCounted
# Godot owns the NWN cryptographic session. The existing libhydrogen helper
# keeps private key material in a private pipe and never exposes it to logs.
const MAX_FRAME:=65537
const TIMEOUT_MS:=5000
var child: Dictionary={}
var closed:=false
var phase:=0

func open(executable: String)->bool:
	if closed or not child.is_empty() or not executable.is_absolute_path() or not FileAccess.file_exists(executable):return false
	child=OS.execute_with_pipe(executable,PackedStringArray(),false)
	if not child.has("stdio") or not child.has("pid"):
		child.clear()
		return false
	return true

func exact(count: int)->PackedByteArray:
	var result:=PackedByteArray()
	var deadline:=Time.get_ticks_msec()+TIMEOUT_MS
	var pipe: FileAccess=child.stdio
	while result.size()<count and Time.get_ticks_msec()<deadline:
		var part:=pipe.get_buffer(count-result.size())
		if not part.is_empty():result.append_array(part)
		elif not OS.is_process_running(int(child.pid)):break
		else:OS.delay_usec(1000)
	return result

func request(operation: int,payload: PackedByteArray=PackedByteArray())->Dictionary:
	if closed or child.is_empty() or operation<1 or operation>7 or payload.size()>65535:return {"error":"NWN cryptography is unavailable"}
	var frame:=PackedByteArray();frame.resize(5);frame.encode_u32(0,payload.size()+1);frame[4]=operation;frame.append_array(payload)
	var pipe: FileAccess=child.stdio
	pipe.store_buffer(frame)
	frame.fill(0)
	var header:=exact(5)
	if header.size()!=5:close();return {"error":"NWN cryptography stopped responding"}
	var length:=int(header.decode_u32(0))
	if length<1 or length>MAX_FRAME:close();return {"error":"Invalid NWN cryptography response"}
	var output:=exact(length-1)
	if output.size()!=length-1:close();return {"error":"Incomplete NWN cryptography response"}
	if header[4]!=0:
		output.fill(0)
		return {"error":"NWN cryptographic authentication failed" if header[4]==2 else "Invalid NWN cryptographic operation"}
	return {"bytes":output}

func start()->Dictionary:
	if phase!=0:return {"error":"NWN key exchange has already started"}
	var result:=request(1)
	if not result.has("bytes") or result.bytes.size()!=32:return {"error":result.get("error","Invalid NWN key exchange packet 1")}
	phase=1
	return result

func finish(packet2: PackedByteArray)->Dictionary:
	if phase!=1 or packet2.size()!=80:return {"error":"Invalid NWN key exchange packet 2"}
	var result:=request(2,packet2)
	if not result.has("bytes") or result.bytes.size()!=80:
		phase=0
		return {"error":result.get("error","Invalid NWN key exchange packet 3")}
	phase=3
	var packet3: PackedByteArray=result.bytes.slice(0,48)
	var server_public_key: PackedByteArray=result.bytes.slice(48,80)
	result.bytes.fill(0)
	return {"packet3":packet3,"server_public_key":server_public_key}

func reset()->bool:
	var result:=request(3)
	if not result.has("bytes"):return false
	phase=0
	return true

func application_id()->int:
	var result:=request(7)
	if not result.has("bytes") or result.bytes.size()!=4:return -1
	return int(result.bytes.decode_u32(0))

func platform_identity(platform_id: int,key: PackedByteArray)->Dictionary:
	if platform_id<0 or platform_id>255 or key.size()!=32:return {"error":"Invalid NWN platform identity input"}
	var payload:=PackedByteArray([platform_id]);payload.append_array(key)
	var result:=request(4,payload);payload.fill(0)
	if not result.has("bytes") or result.bytes.size()!=36:return {"error":result.get("error","Invalid NWN platform identity output")}
	var value: String=result.bytes.hex_encode()
	result.bytes.fill(0)
	return {"identity":value}

func seal(plain: PackedByteArray)->Dictionary:
	if phase!=3 or plain.size()>65466:return {"error":"Invalid NWN session plaintext"}
	var result:=request(5,plain)
	if not result.has("bytes") or result.bytes.size()!=plain.size()+36:return {"error":result.get("error","Invalid NWN session ciphertext")}
	return result

func unseal(ciphertext: PackedByteArray)->Dictionary:
	if phase!=3 or ciphertext.size()<36 or ciphertext.size()>65502:return {"error":"Invalid NWN session ciphertext"}
	var result:=request(6,ciphertext)
	if not result.has("bytes") or result.bytes.size()!=ciphertext.size()-36:return {"error":result.get("error","Invalid NWN session plaintext")}
	return result

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
	phase=0
