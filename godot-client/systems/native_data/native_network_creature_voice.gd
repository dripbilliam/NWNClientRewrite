extends RefCounted
# Original server quick-chat relay 22/0 and creature voice 26/1. The packet
# retains the actor's canonical client OBJECT_ID; presentation owns SSF lookup,
# captions, position, sound replacement and lifetime cancellation.
const Requirements=preload("res://systems/native_data/native_resource_requirements.gd")

static func accepted(major: int,minor: int)->bool:
	return major==22 and minor==0 or major==26 and minor==1

static func decode_packet(packet: PackedByteArray)->Dictionary:
	if packet.size()<8 or packet[0]!=80 or not accepted(int(packet[1]),int(packet[2])):
		return {"error":"Invalid native creature-voice envelope"}
	var major:=int(packet[1]);var minor:=int(packet[2])
	var reader:=Requirements.Reader.new()
	if not reader.configure(packet.slice(3)):
		return {"error":"Invalid native creature-voice stream: "+reader.error}
	var object_id: int=reader.object_id()
	var message: Dictionary={"major":major,"minor":minor,"objectId":object_id}
	if major==22:
		message.kind="quick-chat";message.quickChat=reader.word()
	else:
		message.kind="voice-play";message.voiceCode=reader.byte()
	if not reader.finished():
		return {"error":"Invalid native creature-voice fields: "+(reader.error if not reader.error.is_empty() else "stream incomplete")}
	return message
