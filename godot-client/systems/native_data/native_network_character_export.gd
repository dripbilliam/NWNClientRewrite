extends RefCounted
# Original server 3/10 export response. Names identify the character for the
# save UI; the BIC payload remains opaque and byte-exact for a durable owner.
const Requirements=preload("res://systems/native_data/native_resource_requirements.gd")
const Characters=preload("res://systems/native_data/native_server_characters.gd")
const MAX_CHARACTER_BYTES:=948*65535-16

static func accepted(major: int,minor: int)->bool:
	return major==3 and minor==10

static func decode_packet(packet: PackedByteArray)->Dictionary:
	if packet.size()<8 or packet[0]!=80 or not accepted(int(packet[1]),int(packet[2])):
		return {"error":"Invalid native character-export envelope"}
	var reader:=Requirements.Reader.new()
	if not reader.configure(packet.slice(3)):
		return {"error":"Invalid native character-export stream: "+reader.error}
	var first_name: Dictionary=Characters.localized(reader)
	var last_name: Dictionary=Characters.localized(reader)
	var length: int=reader.dword()
	if not reader.error.is_empty() or length>MAX_CHARACTER_BYTES or length>reader.byte_size-reader.byte_cursor:
		return {"error":"Invalid native character-export size"}
	var data: PackedByteArray=reader.raw(length)
	if data.size()!=length or not reader.finished():
		return {"error":"Invalid native character-export fields: "+(reader.error if not reader.error.is_empty() else "stream incomplete")}
	return {"kind":"character-export","major":3,"minor":10,"firstName":first_name,"lastName":last_name,"data":data}
