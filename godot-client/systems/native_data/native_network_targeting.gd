extends RefCounted
# Original server 18/23 and 57/1-2 targeting instructions. The world owns
# command versions and selection lifecycle; decoding never submits an action.
const Requirements=preload("res://systems/native_data/native_resource_requirements.gd")
const INVALID:=0x7f000000
const TARGET_KINDS=[5,6,7,10,11,12,9,14,13,2]

static func valid_uint(value: Variant)->bool:
	return (value is int or value is float) and is_finite(float(value)) and floor(float(value))==float(value) and value>=0 and value<=0xffffffff

static func kinds(mask: int)->Array:
	# network_script_targeting.js:scriptTargetKinds preserves this exact bit order.
	var result: Array=[]
	for bit in TARGET_KINDS.size():
		if (mask&(1<<bit))!=0:result.append(TARGET_KINDS[bit])
	return result

static func allowed(mode: Dictionary,object_type: int)->bool:
	return kinds(int(mode.get("objectMask",0))).has(object_type)

static func selection_request(target_id: Variant,position: Variant)->Dictionary:
	# Original client 7c0110 sends 112/6/37 with raw client OBJECT_ID and
	# three finite f32 coordinates; it does not submit a spell cast.
	if not valid_uint(target_id) or not position is Array or position.size()!=3:return {"error":"Invalid native script target selection"}
	for value in position:
		if not (value is int or value is float) or not is_finite(float(value)) or not is_finite(float(PackedFloat32Array([float(value)])[0])):
			return {"error":"Invalid native script target selection"}
	var bytes:=PackedByteArray([112,6,37]);bytes.resize(24)
	bytes.encode_u32(3,23)
	bytes.encode_u32(7,int(target_id))
	for index in 3:bytes.encode_float(11+index*4,float(position[index]))
	bytes[23]=0x60
	return {"bytes":bytes}

static func accepted(major: int,minor: int)->bool:
	return major==18 and minor==23 or major==57 and minor in [1,2]

static func decode_packet(packet: PackedByteArray)->Dictionary:
	if packet.size()<8 or packet[0]!=80 or not accepted(int(packet[1]),int(packet[2])):
		return {"error":"Invalid native targeting envelope"}
	var major:=int(packet[1]);var minor:=int(packet[2])
	var reader:=Requirements.Reader.new()
	if not reader.configure(packet.slice(3)):
		return {"error":"Invalid native targeting stream: "+reader.error}
	var message: Dictionary={"major":major,"minor":minor}
	if major==18:
		message.kind="script-targeting";message.objectMask=reader.dword();message.cursor=reader.dword();message.badCursor=reader.dword()
	elif minor==1:
		message.kind="spell-targeting-data";message.spellId=reader.signed_dword();message.shape=reader.signed_dword();message.sizeX=reader.float32();message.sizeY=reader.float32();message.flags=reader.signed_dword()
	else:
		message.kind="script-targeting-data";message.shape=reader.signed_dword();message.sizeX=reader.float32();message.sizeY=reader.float32();message.flags=reader.signed_dword();message.range=reader.float32();message.spellId=reader.signed_dword();message.featId=reader.signed_dword()
	if not reader.finished():
		return {"error":"Invalid native targeting fields: "+(reader.error if not reader.error.is_empty() else "stream incomplete")}
	return message
