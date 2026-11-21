extends RefCounted
# Original 55/1,2,4,5 server messages and 55/3,4 client input framing.
const Requirements=preload("res://systems/native_data/native_resource_requirements.gd")
const Text=preload("res://systems/native_data/native_gff_text.gd")
const Ubjson=preload("res://systems/native_data/native_nui_ubjson.gd")
const MINORS=[1,2,4,5]
const MAX_MESSAGE:=64*1024*1024

static func accepted(major: int,minor: int)->bool:return major==55 and minor in MINORS

static func read_json(reader: RefCounted)->Dictionary:
	var size: int=reader.dword()
	if not reader.error.is_empty() or size>reader.byte_size-reader.byte_cursor:return {"error":"Truncated native NUI JSON"}
	var bytes: PackedByteArray=reader.raw(size)
	if not reader.error.is_empty():return {"error":reader.error}
	return Ubjson.decode(bytes)

static func decode_packet(packet: PackedByteArray)->Dictionary:
	if packet.size()<8 or packet.size()>MAX_MESSAGE or packet[0]!=80 or not accepted(int(packet[1]),int(packet[2])):return {"error":"Invalid native NUI envelope"}
	var minor:=int(packet[2])
	var reader:=Requirements.Reader.new()
	if not reader.configure(packet.slice(3)):return {"error":"Invalid native NUI framing: "+reader.error}
	var message: Dictionary={"major":55,"minor":minor}
	match minor:
		1:
			var token: int=reader.signed_dword();var id: String=reader.string();var format: int=reader.signed_dword()
			message={"kind":"nui-create","major":55,"minor":1,"token":token,"id":id,"format":format}
			if format==1:
				var value: Dictionary=read_json(reader)
				if value.has("error"):return {"error":value.error}
				message.layout=value.value
			elif format==0:
				message.resref=reader.resref();message.layout={}
			else:return {"error":"Unsupported native NUI layout format"}
		2:message={"kind":"nui-destroy","major":55,"minor":2,"token":reader.signed_dword()}
		4:
			var count: int=reader.signed_dword()
			if not reader.error.is_empty() or count<0 or count>(reader.byte_size-reader.byte_cursor)/8:return {"error":"Invalid native NUI bind count"}
			var updates: Array=[]
			for _index in count:
				var token: int=reader.signed_dword();var bind: String=reader.string();var value: Dictionary=read_json(reader)
				if value.has("error"):return {"error":value.error}
				updates.append({"token":token,"bind":bind,"value":value.value})
			message={"kind":"nui-binds","major":55,"minor":4,"updates":updates}
		5:
			var token: int=reader.signed_dword();var element: String=reader.string();var value: Dictionary=read_json(reader)
			if value.has("error"):return {"error":value.error}
			message={"kind":"nui-layout","major":55,"minor":5,"token":token,"element":element,"layout":value.value}
	if not reader.finished():return {"error":"Invalid native NUI fields: "+reader.error}
	return message

static func valid_int32(value: Variant)->bool:return (value is int or value is float) and is_finite(float(value)) and value==floor(float(value)) and value>=-2147483648 and value<=2147483647

static func append_i32(bytes: PackedByteArray,value: int)->void:
	var at:=bytes.size();bytes.resize(at+4);bytes.encode_s32(at,value)

static func append_string(bytes: PackedByteArray,value: String)->Dictionary:
	var result: Dictionary=preload("res://systems/native_data/native_script_string.gd").bytes(value)
	if result.has("error"):return result
	var encoded: PackedByteArray=result.value
	if encoded.size()>MAX_MESSAGE-bytes.size()-8:return {"error":"Native NUI input text exceeds bound"}
	append_i32(bytes,encoded.size());bytes.append_array(encoded)
	return {}

static func append_json(bytes: PackedByteArray,value: Variant)->Dictionary:
	var encoded: Dictionary=Ubjson.encode(value)
	if encoded.has("error"):return encoded
	if encoded.bytes.size()>MAX_MESSAGE-bytes.size()-8:return {"error":"Native NUI input JSON exceeds bound"}
	append_i32(bytes,encoded.bytes.size());bytes.append_array(encoded.bytes)
	return {}

static func input_packet(token: int,events: Array,binds: Array,indexed_binds: bool)->Dictionary:
	if not valid_int32(token) or token==0 or not events.is_empty() and not binds.is_empty() or events.size()+binds.size()<1 or events.size()+binds.size()>65535:return {"error":"Invalid native NUI input batch"}
	var minor:=3 if not events.is_empty() else 4
	var entries: Array=events if minor==3 else binds
	var bytes:=PackedByteArray([112,55,minor,0,0,0,0]);append_i32(bytes,entries.size())
	for entry in entries:
		if not entry is Dictionary or not valid_int32(entry.get("index",-1)) or not valid_int32(entry.get("token",token)) or int(entry.get("token",token))==0:return {"error":"Invalid native NUI input identity"}
		append_i32(bytes,int(entry.get("token",token)))
		var result: Dictionary={}
		if minor==3:
			if not entry.get("type") is String or not entry.get("element") is String:return {"error":"Invalid native NUI event"}
			result=append_string(bytes,str(entry.type))
			if result.has("error"):return result
			result=append_string(bytes,str(entry.element))
			if result.has("error"):return result
			append_i32(bytes,int(entry.get("index",-1)))
			result=append_json(bytes,entry.get("payload"))
		else:
			if not entry.get("bind") is String or str(entry.bind).is_empty():return {"error":"Invalid native NUI bind"}
			result=append_string(bytes,str(entry.bind))
			if result.has("error"):return result
			result=append_json(bytes,entry.get("value"))
			if not result.has("error") and indexed_binds:append_i32(bytes,int(entry.get("index",-1)))
		if result.has("error"):return result
		if bytes.size()>MAX_MESSAGE-1:return {"error":"Native NUI input exceeds bound"}
	bytes.append(0x60);bytes.encode_u32(3,bytes.size()-1)
	return {"bytes":bytes}
