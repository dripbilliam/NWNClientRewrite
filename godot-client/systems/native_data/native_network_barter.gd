extends RefCounted
# Original server 35/2,4,8,10,11 replies and client 35 requests. The session
# owns trade validity and lifetime; this codec never predicts offer contents.
const Requirements=preload("res://systems/native_data/native_resource_requirements.gd")
const INVALID:=0x7f000000
const REQUEST_MINORS={"start":1,"close":3,"add":5,"remove":6,"lock":7,"accept":9,"window":12,"move":13}

static func accepted(major: int,minor: int)->bool:
	return major==35 and minor in [2,4,8,10,11]

static func decode_packet(packet: PackedByteArray)->Dictionary:
	if packet.size()<8 or packet[0]!=80 or not accepted(int(packet[1]),int(packet[2])):
		return {"error":"Invalid native barter envelope"}
	var minor:=int(packet[2])
	var reader:=Requirements.Reader.new()
	if not reader.configure(packet.slice(3)):
		return {"error":"Invalid native barter stream: "+reader.error}
	var message: Dictionary={"major":35,"minor":minor}
	match minor:
		2:message.kind="barter-start";message.firstId=reader.object_id();message.secondId=reader.object_id()
		4:message.kind="barter-close";message.completed=reader.boolean()
		8,10:
			message.kind="barter-lock" if minor==8 else "barter-accept"
			message.initiator=reader.boolean();message.value=reader.boolean()
		11:message.kind="barter-reject";message.operation=reader.byte();message.reason=reader.byte();message.targetId=reader.object_id()
	if not reader.finished():
		return {"error":"Invalid native barter fields: "+(reader.error if not reader.error.is_empty() else "stream incomplete")}
	return message

static func valid_id(value: Variant)->bool:
	return value is int and value>=0 and value<=0xffffffff

static func valid_byte(value: Variant)->bool:
	return value is int and value>=0 and value<=255

static func request(operation: String,target_id: int=INVALID,item_id: int=INVALID,value: bool=false,x: int=255,y: int=255)->Dictionary:
	if not REQUEST_MINORS.has(operation) or not valid_id(target_id) or not valid_id(item_id) or not valid_byte(x) or not valid_byte(y):
		return {"error":"Invalid native barter request"}
	var minor:=int(REQUEST_MINORS[operation])
	var bytes:=PackedByteArray([112,35,minor])
	if operation=="start":
		bytes.resize(16);bytes.encode_u32(3,15);bytes.encode_u32(7,target_id);bytes.encode_u32(11,item_id);bytes[15]=0x65
	elif operation in ["add","remove","move"]:
		bytes.resize(14);bytes.encode_u32(3,13);bytes.encode_u32(7,item_id);bytes[11]=x;bytes[12]=y;bytes[13]=0x65
	else:
		bytes.resize(8);bytes.encode_u32(3,7);bytes[7]=0x95 if operation=="close" or value else 0x85
	return {"bytes":bytes}
