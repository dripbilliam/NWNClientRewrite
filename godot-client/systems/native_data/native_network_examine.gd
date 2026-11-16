extends RefCounted
# Original server 27/2..6 examination disclosure. The server decides what the
# player may see; this decoder does not infer details from local object state.
const Requirements=preload("res://systems/native_data/native_resource_requirements.gd")
const Area=preload("res://systems/native_data/native_area_state.gd")
const Characters=preload("res://systems/native_data/native_server_characters.gd")
const INVALID:=0x7f000000
const TYPES={2:"item",3:"creature",4:"placeable",5:"trap",6:"door"}

static func accepted(major: int,minor: int)->bool:
	return major==27 and minor in [2,3,4,5,6]

static func decode_packet(packet: PackedByteArray,server_build: Dictionary={})->Dictionary:
	if packet.size()<8 or packet[0]!=80 or not accepted(int(packet[1]),int(packet[2])):
		return {"error":"Invalid native examination envelope"}
	var minor:=int(packet[2])
	if minor==3 and not valid_build(server_build):return {"error":"Native examination server build is unavailable"}
	var reader:=Requirements.Reader.new()
	if not reader.configure(packet.slice(3)):
		return {"error":"Invalid native examination stream: "+reader.error}
	var target_id:=reader.object_id()
	var message: Dictionary={"kind":"examine","major":27,"minor":minor,"targetId":target_id,"type":TYPES[minor]}
	match minor:
		2:decode_item(reader,message)
		3:decode_creature(reader,server_build,message)
		5:decode_trap(reader,message)
		_:message.description=description(reader)
	if message.has("error") or not reader.finished():
		return {"error":"Invalid native examination fields: "+str(message.get("error",reader.error if not reader.error.is_empty() else "stream incomplete"))}
	return message

static func valid_build(build: Dictionary)->bool:
	for key in ["number","revision","postfix"]:
		var value: Variant=build.get(key)
		if not (value is int or value is float) or int(value)<0 or float(value)!=float(int(value)):return false
	return true

static func description(reader: Requirements.Reader)->Dictionary:
	return {"text":reader.string()} if reader.boolean() else Characters.localized(reader)

static func decode_item(reader: Requirements.Reader,message: Dictionary)->void:
	if int(message.targetId)==INVALID:message.close=true;return
	message.actorId=reader.object_id()
	message.identified=int(reader.boolean())
	if message.identified:message.canUse=int(reader.boolean())
	message.description=description(reader)
	message.meetsLevel=int(reader.boolean())
	if not message.meetsLevel:message.minimumLevel=reader.byte()
	message.charges=reader.signed_dword()
	message.weight=reader.signed_dword()
	if reader.boolean():message.value=reader.dword()
	if message.identified:
		var count:=reader.word()
		if count>int((reader.byte_size-reader.byte_cursor)/7):message.error="Invalid native examination property count";return
		var properties: Array[Dictionary]=[]
		for _index in range(count):properties.append({"type":reader.word(),"subtype":reader.word(),"costValue":reader.word(),"uses":reader.byte(),"usable":int(reader.boolean())})
		message.properties=properties

static func decode_creature(reader: Requirements.Reader,build: Dictionary,message: Dictionary)->void:
	message.description=description(reader)
	message.hasDetails=int(reader.boolean())
	if not message.hasDetails:return
	if reader.boolean():message.name={"firstName":Characters.localized(reader),"lastName":Characters.localized(reader)}
	else:message.name={"text":reader.string()}
	message.portraitId=reader.word()
	if int(message.portraitId)>=0xfffe:message.portrait=reader.resref()
	message.damageLevel=reader.byte();message.reaction=reader.byte()
	if reader.boolean():message.challengeRating=reader.float32()
	if reader.boolean():
		var wide:=Area.at_least(build,37,2)
		var count:=reader.word() if wide else reader.byte()
		if count>int((reader.byte_size-reader.byte_cursor)/(2 if wide else 1)):
			message.error="Invalid native examination effect count";return
		var effects: Array[int]=[]
		for _index in range(count):effects.append(reader.word() if wide else reader.byte())
		message.effects=effects
	if reader.boolean():message.playerLevel=reader.signed_dword();message.playerFlags=reader.dword()

static func decode_trap(reader: Requirements.Reader,message: Dictionary)->void:
	message.success=int(reader.boolean())
	if reader.boolean():message.name={"text":reader.string()}
	message.trapType=reader.byte();message.assessment=reader.byte()
