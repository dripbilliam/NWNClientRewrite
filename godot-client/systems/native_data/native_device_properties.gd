extends RefCounted
const Text=preload("res://systems/native_data/native_gff_text.gd")
const KEYS=["gui_scale","gui_width","gui_height"]

static func request(key: String,value: int)->Dictionary:
	if key not in KEYS or value<0 or value>2147483647 or key!="gui_scale" and value<1:return {"error":"Invalid native device property"}
	var encoded: Dictionary=Text.encode(key)
	if encoded.has("error"):return encoded
	var bytes:=PackedByteArray([112,54,1])
	var boundary:=PackedByteArray();boundary.resize(4);boundary.encode_u32(0,25+encoded.bytes.size())
	bytes.append_array(boundary)
	bytes.append_array(PackedByteArray([3,1,14,8]))
	var length:=PackedByteArray();length.resize(4);length.encode_u32(0,encoded.bytes.size())
	bytes.append_array(length)
	bytes.append_array(encoded.bytes)
	bytes.append(8)
	bytes.append_array(PackedByteArray([1,0,0,0]))
	bytes.append(8)
	var number:=PackedByteArray();number.resize(4);number.encode_u32(0,value)
	bytes.append_array(number)
	bytes.append(0x60)
	return {"bytes":bytes}
