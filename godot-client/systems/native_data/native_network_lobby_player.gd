extends RefCounted
# Original server 49/3 connected-player lobby record. This is separate from
# world object creation and the 17/2 playable character list.
const Requirements=preload("res://systems/native_data/native_resource_requirements.gd")
const Characters=preload("res://systems/native_data/native_server_characters.gd")

static func accepted(major: int,minor: int)->bool:
	return major==49 and minor==3

static func decode_packet(packet: PackedByteArray)->Dictionary:
	if packet.size()<8 or packet[0]!=80 or not accepted(int(packet[1]),int(packet[2])):
		return {"error":"Invalid native lobby-player envelope"}
	var reader:=Requirements.Reader.new()
	if not reader.configure(packet.slice(3)):
		return {"error":"Invalid native lobby-player stream: "+reader.error}
	var present: bool=reader.boolean()
	var character: Dictionary={"id":reader.dword()}
	if present:
		character.firstName=Characters.localized(reader)
		character.lastName=Characters.localized(reader)
		character.portrait=reader.word()
		if int(character.portrait)>0xfffd:character.portraitRef=reader.resref()
		var count: int=reader.byte()
		if not reader.error.is_empty() or count>int((reader.byte_size-reader.byte_cursor)/2):
			return {"error":"Invalid native lobby-player class count"}
		var classes: Array[Dictionary]=[]
		for _index in count:classes.append({"id":reader.byte(),"level":reader.byte()})
		character.classes=classes
	if not reader.finished():
		return {"error":"Invalid native lobby-player fields: "+(reader.error if not reader.error.is_empty() else "stream incomplete")}
	return {"kind":"server-character-player","major":49,"minor":3,"present":present,"character":character}
