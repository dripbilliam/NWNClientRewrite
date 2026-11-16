extends RefCounted
# Original portal activation and character handoff packets. The session owns
# cancellation, disconnect and fresh-login ordering; this file only decodes.
const Requirements=preload("res://systems/native_data/native_resource_requirements.gd")
const Text=preload("res://systems/native_data/native_gff_text.gd")
const MAX_CHARACTER_BYTES:=948*65535-16

static func accepted(major: int,minor: int)->bool:
	return major==42 and minor==1 or major==43 and minor in [2,3]

static func character_request()->PackedByteArray:
	return PackedByteArray([112,43,1])

static func endpoint(address: String)->Dictionary:
	if address.is_empty() or address.length()>261:return {"error":"Invalid native portal address"}
	var pattern:=RegEx.create_from_string("^([A-Za-z0-9._-]+)(?::([0-9]{1,5}))?$")
	var matched:=pattern.search(address)
	if matched==null:return {"error":"Invalid native portal address"}
	var host:=matched.get_string(1)
	var port_text:=matched.get_string(2)
	var port:=5121 if port_text.is_empty() else int(port_text)
	if host.is_empty() or host.length()>255 or port<1 or port>65535:return {"error":"Invalid native portal address"}
	return {"host":host,"port":port}

static func valid_reference(resref: String)->bool:
	if resref.is_empty():return false
	for index in range(resref.length()):
		var code:=resref.unicode_at(index)
		if code<32 or code in [47,92,58]:return false
	var encoded: Dictionary=Text.encode(resref)
	return not encoded.has("error") and encoded.bytes.size()<=16

static func decode_packet(packet: PackedByteArray)->Dictionary:
	if packet.size()<8 or packet[0]!=80 or not accepted(int(packet[1]),int(packet[2])):
		return {"error":"Invalid native portal envelope"}
	var major:=int(packet[1]);var minor:=int(packet[2])
	var reader:=Requirements.Reader.new()
	if not reader.configure(packet.slice(3)):
		return {"error":"Invalid native portal stream: "+reader.error}
	var message: Dictionary={"major":major,"minor":minor}
	if major==42:
		var address:=reader.string()
		var password:=reader.string()
		var waypoint:=reader.string()
		var seamless:=reader.boolean()
		var parsed:=endpoint(address)
		if parsed.has("error") or password.length()>4096 or waypoint.length()>4096 or password.find(char(0))>=0 or waypoint.find(char(0))>=0:
			return {"error":"Invalid native portal fields"}
		message.kind="portal-activate"
		message.host=parsed.host;message.port=parsed.port
		message.password=password;message.waypoint=waypoint;message.seamless=seamless
	elif minor==3:
		var resref:=reader.string()
		var source:=17 if reader.boolean() else 2
		if not valid_reference(resref):return {"error":"Invalid native portal character reference"}
		message.kind="portal-character";message.resref=resref;message.source=source
	else:
		var first_name: Dictionary={"gender":reader.byte_bits(1),"strRef":reader.dword()} if reader.boolean() else {"text":reader.string()}
		var last_name: Dictionary={"gender":reader.byte_bits(1),"strRef":reader.dword()} if reader.boolean() else {"text":reader.string()}
		var length:=reader.dword()
		if length<1 or length>MAX_CHARACTER_BYTES or length>reader.byte_size-reader.byte_cursor:
			return {"error":"Invalid native portal character size"}
		message.kind="portal-character"
		message.firstName=first_name;message.lastName=last_name
		message.data=reader.raw(length)
	if not reader.finished():
		return {"error":"Invalid native portal fields: "+(reader.error if not reader.error.is_empty() else "stream incomplete")}
	return message
