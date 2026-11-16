extends RefCounted
# Original server 34/1 safe-projectile header. This only describes a private
# presentation projectile; it never allocates a canonical game object.
const Requirements=preload("res://systems/native_data/native_resource_requirements.gd")

static func accepted(major: int,minor: int)->bool:
	return major==34 and minor==1

static func decode_packet(packet: PackedByteArray)->Dictionary:
	if packet.size()<8 or packet[0]!=80 or not accepted(int(packet[1]),int(packet[2])):
		return {"error":"Invalid native projectile envelope"}
	var reader:=Requirements.Reader.new()
	if not reader.configure(packet.slice(3)):
		return {"error":"Invalid native projectile stream: "+reader.error}
	var header: Dictionary={"sourceId":reader.object_id(),"targetId":reader.object_id(),"from":[reader.float32(),reader.float32(),reader.float32()],"to":[reader.float32(),reader.float32(),reader.float32()],"duration":reader.dword(),"appearance":reader.byte(),"spellId":null,"path":null,"baseItem":255,"result":0}
	if not reader.error.is_empty():return {"error":"Invalid native projectile header: "+reader.error}
	if int(header.appearance)==6:
		header.spellId=reader.dword()
	elif int(header.appearance)==7:
		header.spellId=reader.dword();header.path=reader.byte()
	else:
		header.path=reader.byte();header.baseItem=reader.byte();header.result=reader.byte()
	if not reader.finished():
		return {"error":"Invalid native projectile fields: "+(reader.error if not reader.error.is_empty() else "stream incomplete")}
	return {"kind":"safe-projectile","major":34,"minor":1,"header":header}
