extends RefCounted
# Original server 3/9: detached pause DTO. Clock and scene mutation belong to
# the session and clock owner after a complete packet has been admitted.
const Requirements=preload("res://systems/native_data/native_resource_requirements.gd")

static func accepted(major: int,minor: int)->bool:
	return major==3 and minor==9

static func decode_packet(packet: PackedByteArray)->Dictionary:
	if packet.size()<8 or packet[0]!=80 or not accepted(int(packet[1]),int(packet[2])):
		return {"error":"Invalid native module-pause envelope"}
	var reader:=Requirements.Reader.new()
	if not reader.configure(packet.slice(3)):
		return {"error":"Invalid native module-pause stream: "+reader.error}
	var mask: int=reader.byte_bits(2)
	var value: int=1 if reader.boolean() else 0
	var count: int=reader.word_bits(16)
	if not reader.error.is_empty() or count>int((reader.byte_size-reader.byte_cursor)/4):
		return {"error":"Invalid native module-pause exclusion count"}
	var exclusion_ids: Array[int]=[]
	for _index in count:
		exclusion_ids.append(reader.object_id())
	if not reader.finished():
		return {"error":"Invalid native module-pause fields: "+(reader.error if not reader.error.is_empty() else "stream incomplete")}
	return {"kind":"module-pause-state","major":3,"minor":9,"mask":mask,"value":value,"exclusionIds":exclusion_ids}
