extends RefCounted
const Reader=preload("res://systems/native_data/native_resource_requirements.gd")
const Text=preload("res://systems/native_data/native_gff_text.gd")

static func device_echo_request(packet: PackedByteArray)->Dictionary:
	if packet.size()<8 or packet[0]!=80 or packet[1]!=54 or packet[2]!=2:return {"error":"Not a native device echo request"}
	var reader:=Reader.Reader.new()
	if not reader.configure(packet.slice(3)):return {"error":reader.error}
	var length:=reader.dword()
	if length>reader.byte_size-reader.byte_cursor:return {"error":"Native device echo exceeds its message body"}
	var data:=reader.raw(length)
	if data.size()!=length or not reader.finished():return {"error":"Native device echo is incomplete"}
	return {"data":data}

static func device_echo_response(data: PackedByteArray)->Dictionary:
	if data.size()>64*1024*1024-12:return {"error":"Native device echo response exceeds bound"}
	var bytes:=PackedByteArray([112,54,3])
	var header:=PackedByteArray();header.resize(8)
	header.encode_u32(0,11+data.size())
	header.encode_u32(4,data.size())
	bytes.append_array(header);bytes.append_array(data);bytes.append(0x60)
	return {"bytes":bytes}

static func login_waypoint_response(value: String)->Dictionary:
	if value.to_utf8_buffer().has(0):return {"error":"Invalid native login waypoint"}
	if value.is_empty():return {"bytes":PackedByteArray()}
	var encoded: Dictionary=Text.encode(value)
	if encoded.has("error") or encoded.bytes.size()>64*1024*1024:return {"error":"Native login waypoint cannot be encoded"}
	var bytes:=PackedByteArray([112,2,13])
	var header:=PackedByteArray();header.resize(8)
	header.encode_u32(0,11+encoded.bytes.size())
	header.encode_u32(4,encoded.bytes.size())
	bytes.append_array(header);bytes.append_array(encoded.bytes);bytes.append(0x60)
	return {"bytes":bytes}
