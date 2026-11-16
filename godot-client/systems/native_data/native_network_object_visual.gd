extends RefCounted
# Server 5/3 is a transient visual delivery, not an object creation/update.
# The caller supplies the module's exact visualeffects.2da Type_FD lookup.
const Requirements=preload("res://systems/native_data/native_resource_requirements.gd")
const ObjectUpdates=preload("res://systems/native_data/native_object_updates.gd")
const INVALID=0x7f000000

static func accepted(major: int,minor: int)->bool:
	return major==5 and minor==3

static func decode_packet(packet: PackedByteArray,build: Dictionary={},providers: Dictionary={})->Dictionary:
	if packet.size()<8 or packet[0]!=80 or not accepted(int(packet[1]),int(packet[2])):
		return {"error":"Invalid native object visual envelope"}
	if not build.has("number") or not build.has("revision") or not build.has("postfix"):
		return {"error":"Native object visual server build is unavailable"}
	var is_beam: Callable=providers.get("isBeam",Callable())
	if not is_beam.is_valid():
		return {"error":"Native visual classification is unavailable"}
	var reader:=Requirements.Reader.new()
	if not reader.configure(packet.slice(3)):
		return {"error":"Invalid native object visual stream: "+reader.error}
	var target_id:=reader.object_id()
	var visual_id:=reader.word()
	var position: Array=[reader.float32(),reader.float32(),reader.float32()]
	if not reader.error.is_empty():return {"error":"Invalid native object visual header: "+reader.error}
	var beam: Variant=is_beam.call(visual_id)
	if not beam is bool:return {"error":"Native visual classification is unavailable"}
	var message: Dictionary={"kind":"object-visual","major":5,"minor":3,"targetId":target_id,"visualId":visual_id,"position":position,"sourceId":INVALID,"flag":0,"missMode":0,"duration":0}
	if beam or visual_id==999:
		message.sourceId=reader.object_id()
		message.flag=reader.byte()
		message.missMode=reader.byte()
		message.sourcePosition=[reader.float32(),reader.float32(),reader.float32()]
		if target_id==INVALID:message.duration=reader.float32()
	message.visualTransform=ObjectUpdates.visual_transform(reader,build) if ObjectUpdates.at_least(build,14) else {"keys":[],"entries":[]}
	if message.visualTransform.has("error"):
		return {"error":str(message.visualTransform.error)}
	if not reader.finished():
		return {"error":"Invalid native object visual fields: "+(reader.error if not reader.error.is_empty() else "stream incomplete")}
	return message
