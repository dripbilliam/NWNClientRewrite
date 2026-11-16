extends RefCounted
# Original server 52/2-3 TLK overrides and 54/2 opaque device echo. The
# existing Godot 54/2 reader remains the sole production echo byte owner.
const Requirements=preload("res://systems/native_data/native_resource_requirements.gd")
const Runtime=preload("res://systems/native_data/native_runtime_messages.gd")

static func accepted(major: int,minor: int)->bool:
	return major==52 and minor in [2,3] or major==54 and minor==2

static func decode_packet(packet: PackedByteArray)->Dictionary:
	if packet.size()<8 or packet[0]!=80 or not accepted(int(packet[1]),int(packet[2])):
		return {"error":"Invalid native runtime envelope"}
	var major:=int(packet[1]);var minor:=int(packet[2])
	if major==54:
		var echo: Dictionary=Runtime.device_echo_request(packet)
		if echo.has("error"):return echo
		return {"kind":"device-echo-request","major":54,"minor":2,"data":echo.data}
	var reader:=Requirements.Reader.new()
	if not reader.configure(packet.slice(3)):
		return {"error":"Invalid native TLK override stream: "+reader.error}
	var count:=1 if minor==2 else reader.dword()
	if count<0 or count>int((reader.byte_size-reader.byte_cursor)/8):
		return {"error":"Invalid native TLK override count"}
	var entries: Array[Dictionary]=[]
	for _index in count:entries.append({"strRef":reader.dword(),"text":reader.string()})
	if not reader.finished():
		return {"error":"Invalid native TLK override fields: "+(reader.error if not reader.error.is_empty() else "stream incomplete")}
	return {"kind":"tlk-overrides","major":52,"minor":minor,"entries":entries}
