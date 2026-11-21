extends RefCounted
# Original party roster and invitation packets. Membership only reports raw
# server object IDs; it never creates, removes, or owns replicated creatures.
const Requirements=preload("res://systems/native_data/native_resource_requirements.gd")
const PARTY_INPUT_MINORS={"list":2,"leave":6,"kick":7,"transfer":8,"invite":9,"ignore":10,"accept":11,"reject":12}

static func valid_target(value: Variant)->bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)==floor(float(value)) and value>=0 and value<=0xffffffff

static func party_request(operation: String,target_id: Variant=null)->Dictionary:
	if not PARTY_INPUT_MINORS.has(operation):return {"error":"Invalid native party operation"}
	if operation=="list":
		if target_id!=null:return {"error":"A party-list refresh has no target"}
		return {"bytes":PackedByteArray([112,14,2])}
	if not valid_target(target_id):return {"error":"Invalid native party target"}
	var bytes:=PackedByteArray([112,14,int(PARTY_INPUT_MINORS[operation]),11,0,0,0]);bytes.resize(12)
	bytes.encode_u32(7,int(target_id));bytes[11]=0x60
	return {"bytes":bytes}

static func player_list_gui_request(operation: String,target_id: Variant,include_position: bool)->Dictionary:
	var event:=12 if operation=="select" else 28 if operation=="tell" else -1
	if event<0 or not valid_target(target_id):return {"error":"Invalid native player-list GUI request"}
	var size:=28 if include_position else 16
	var bytes:=PackedByteArray([112,53,1]);bytes.resize(size)
	bytes.encode_u32(3,size-1);bytes.encode_u16(7,event);bytes.encode_u16(9,0);bytes.encode_u32(11,int(target_id))
	# The optional versioned XYZ floats are zero in the original sender.
	bytes[size-1]=0x60
	return {"bytes":bytes}

static func accepted(major: int,minor: int)->bool:
	return major==14 and minor in [1,3,4] or major==36 and minor==3

static func decode_packet(packet: PackedByteArray)->Dictionary:
	if packet.size()<8 or packet[0]!=80 or not accepted(int(packet[1]),int(packet[2])):
		return {"error":"Invalid native party envelope"}
	var major:=int(packet[1]);var minor:=int(packet[2])
	var reader:=Requirements.Reader.new()
	if not reader.configure(packet.slice(3)):
		return {"error":"Invalid native party stream: "+reader.error}
	var message: Dictionary={"major":major,"minor":minor}
	if major==36:
		message.kind="party-invite-notice"
		message.name=reader.string()
	else:
		var count:=reader.signed_dword()
		if count>int((reader.byte_size-reader.byte_cursor)/4):
			return {"error":"Invalid native party-list count"}
		var ids: Array[int]=[]
		for _index in range(maxi(0,count)):ids.append(reader.object_id())
		message.kind="party-list"
		message.operation={1:"all",3:"add",4:"remove"}[minor]
		message.count=count
		message.ids=ids
	if not reader.finished():
		return {"error":"Invalid native party fields: "+(reader.error if not reader.error.is_empty() else "stream incomplete")}
	return message
