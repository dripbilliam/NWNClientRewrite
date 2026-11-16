extends RefCounted
# Original server 40/1..8 ambient audio commands. These address the current
# area's audio owner, not a replicated game object or renderer instance.
const Requirements=preload("res://systems/native_data/native_resource_requirements.gd")

static func accepted(major: int,minor: int)->bool:
	return major==40 and minor>=1 and minor<=8

static func decode_packet(packet: PackedByteArray)->Dictionary:
	if packet.size()<8 or packet[0]!=80 or not accepted(int(packet[1]),int(packet[2])):
		return {"error":"Invalid native ambient envelope"}
	var operation:=int(packet[2])
	var reader:=Requirements.Reader.new()
	if not reader.configure(packet.slice(3)):
		return {"error":"Invalid native ambient stream: "+reader.error}
	var message: Dictionary={"kind":"ambient-command","major":40,"minor":operation,"operation":operation}
	if operation in [1,4,6]:message.play=int(reader.boolean())
	elif operation in [2,5]:message.value=reader.signed_dword()
	else:message.day=int(reader.boolean());message.value=reader.signed_dword()
	if not reader.finished():
		return {"error":"Invalid native ambient fields: "+(reader.error if not reader.error.is_empty() else "stream incomplete")}
	return message
