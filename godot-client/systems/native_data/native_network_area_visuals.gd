extends RefCounted
# Dynamic area weather, wind, and area-owned visual effects from server 4/*.
# Packet interpretation only; the current area and renderer own application.
const Requirements=preload("res://systems/native_data/native_resource_requirements.gd")
const ObjectUpdates=preload("res://systems/native_data/native_object_updates.gd")

static func accepted(major: int,minor: int)->bool:
	return major==4 and minor in [2,4,13]

static func decode_packet(packet: PackedByteArray,build: Dictionary={})->Dictionary:
	if packet.size()<8 or packet[0]!=80 or not accepted(int(packet[1]),int(packet[2])):
		return {"error":"Invalid native area visual envelope"}
	var minor:=int(packet[2])
	var reader:=Requirements.Reader.new()
	if not reader.configure(packet.slice(3)):
		return {"error":"Invalid native area visual stream: "+reader.error}
	var message: Dictionary={"major":4,"minor":minor}
	match minor:
		4:
			message.kind="area-weather"
			message.weather={"type":reader.byte(),"enabled":int(reader.boolean())}
		13:
			message.kind="area-wind"
			var fields: Dictionary={}
			for field in ["e8","ec","f0","f4","f8","fc"]:fields[field]=reader.float32()
			message.fields=fields
		2:
			if not build.has("number") or not build.has("revision") or not build.has("postfix"):
				return {"error":"Native area visual server build is unavailable"}
			message.kind="area-visual"
			message.visualId=reader.word()
			message.position=[reader.float32(),reader.float32(),reader.float32()]
			message.visualTransform=ObjectUpdates.visual_transform(reader,build) if ObjectUpdates.at_least(build,14) else {"keys":[],"entries":[]}
	if message.get("visualTransform",{}) is Dictionary and message.get("visualTransform",{}).has("error"):
		return {"error":str(message.visualTransform.error)}
	if not reader.finished():
		return {"error":"Invalid native area visual fields: "+(reader.error if not reader.error.is_empty() else "stream incomplete")}
	return message
