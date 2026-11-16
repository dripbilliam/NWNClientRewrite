extends RefCounted
# Original server 23/2..7 sound-object commands. The 23/6 payload uses the
# same packed state as area 4/1; the world owns identity and area validation.
const Requirements=preload("res://systems/native_data/native_resource_requirements.gd")
const Area=preload("res://systems/native_data/native_area_state.gd")

static func accepted(major: int,minor: int)->bool:
	return major==23 and minor>=2 and minor<=7

static func decode_packet(packet: PackedByteArray)->Dictionary:
	if packet.size()<8 or packet[0]!=80 or not accepted(int(packet[1]),int(packet[2])):
		return {"error":"Invalid native sound-object envelope"}
	var operation:=int(packet[2])
	var reader:=Requirements.Reader.new()
	if not reader.configure(packet.slice(3)):
		return {"error":"Invalid native sound-object stream: "+reader.error}
	var message: Dictionary={"kind":"sound-object","major":23,"minor":operation,"operation":operation,"objectId":reader.object_id()}
	match operation:
		4:message.volume=reader.signed_dword()
		5:message.position=[reader.float32(),reader.float32(),reader.float32()]
		6:
			message.areaId=reader.object_id()
			message.sound=Area.sound_state(reader)
			if message.sound.has("error"):return {"error":str(message.sound.error)}
	if not reader.finished():
		return {"error":"Invalid native sound-object fields: "+(reader.error if not reader.error.is_empty() else "stream incomplete")}
	return message
