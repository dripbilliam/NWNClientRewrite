extends RefCounted
# Original server 31/22. Permission and field114 remain raw received scalars;
# decoding does not grant a DM role or an all-skills override.
const Requirements=preload("res://systems/native_data/native_resource_requirements.gd")

static func accepted(major: int,minor: int)->bool:
	return major==31 and minor==22

static func decode_packet(packet: PackedByteArray)->Dictionary:
	if packet.size()<8 or packet[0]!=80 or not accepted(int(packet[1]),int(packet[2])):
		return {"error":"Invalid native DM permission envelope"}
	var reader:=Requirements.Reader.new()
	if not reader.configure(packet.slice(3)):
		return {"error":"Invalid native DM permission stream: "+reader.error}
	var permission:=int(reader.boolean())
	var field114:=int(reader.boolean())
	var parameter:=reader.signed_dword()
	if not reader.finished():
		return {"error":"Invalid native DM permission fields: "+(reader.error if not reader.error.is_empty() else "stream incomplete")}
	return {"kind":"game-master-permission","major":31,"minor":22,"permission":permission,"field114":field114,"parameter":parameter}
