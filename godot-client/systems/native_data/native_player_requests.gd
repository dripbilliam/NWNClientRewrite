extends RefCounted
# Original client waypoint sender 1407c0970. Coordinates and client object IDs
# are transmitted unchanged; the server owns pathfinding and movement state.
const INVALID:=0x7f000000
const GffText=preload("res://systems/native_data/native_gff_text.gd")

static func valid_id(value: int)->bool:return value>=0 and value<=0xffffffff

static func waypoint(area_id: int,position: Array,sequence: int,run: bool,client_path: bool=false,fractional: int=0,target_id: int=INVALID)->Dictionary:
	if not valid_id(area_id) or not valid_id(target_id) or position.size()!=3 or sequence<0 or sequence>255 or fractional<0 or fractional>255:return {"error":"Invalid native waypoint request"}
	var bytes:=PackedByteArray([112,6,1]);bytes.resize(30)
	bytes.encode_u32(3,29)
	bytes.encode_u32(7,area_id)
	for index in range(3):
		var coordinate: Variant=position[index]
		if not coordinate is float and not coordinate is int or not is_finite(float(coordinate)):return {"error":"Invalid native waypoint coordinate"}
		bytes.encode_float(11+index*4,float(coordinate))
		if not is_finite(bytes.decode_float(11+index*4)):return {"error":"Native waypoint coordinate exceeds float32"}
	bytes[23]=sequence
	bytes[24]=fractional
	bytes.encode_u32(25,target_id)
	bytes[29]=0xa0 | (0x10 if run else 0) | (0x08 if client_path else 0)
	return {"bytes":bytes}

# Original keyboard sender 7bf980: 6/29. The 3-bit Create prefix and the
# 12-bit heading leave one undefined padding bit in the final byte.
static func drive(area_id: int,position: Array,heading: int,sequence: int,flags: int)->Dictionary:
	if not valid_id(area_id) or position.size()!=2 or heading<0 or heading>3599 or sequence<0 or sequence>255 or flags<1 or flags>63:return {"error":"Invalid native drive request"}
	var bytes:=PackedByteArray([112,6,29]);bytes.resize(23)
	bytes.encode_u32(3,22)
	for index in range(2):
		var coordinate: Variant=position[index]
		if not coordinate is float and not coordinate is int or not is_finite(float(coordinate)):return {"error":"Invalid native drive coordinate"}
		bytes.encode_float(7+index*4,float(coordinate))
		if not is_finite(bytes.decode_float(7+index*4)):return {"error":"Native drive coordinate exceeds float32"}
	bytes.encode_u32(15,area_id)
	bytes[19]=heading>>4
	bytes[20]=sequence
	bytes[21]=flags
	bytes[22]=0xe0 | ((heading&15)<<1)
	return {"bytes":bytes}

static func abort_drive()->Dictionary:
	return {"bytes":PackedByteArray([112,6,33])}

# Original turn-only sender 7c03b0: 6/28. The last five residual bits are
# undefined native padding and are kept zero here.
static func orientation(position: Array)->Dictionary:
	if position.size()!=2:return {"error":"Invalid native drive orientation"}
	var x: Variant=position[0];var y: Variant=position[1]
	if not (x is float or x is int) or not (y is float or y is int) or not is_finite(float(x)) or not is_finite(float(y)) or absf(sqrt(float(x)*float(x)+float(y)*float(y))-1.0)>0.001:return {"error":"Invalid native drive orientation"}
	var bytes:=PackedByteArray([112,6,28]);bytes.resize(16)
	bytes.encode_u32(3,15)
	bytes.encode_float(7,float(x));bytes.encode_float(11,float(y))
	if not is_finite(bytes.decode_float(7)) or not is_finite(bytes.decode_float(11)):return {"error":"Native drive orientation exceeds float32"}
	bytes[15]=0x60
	return {"bytes":bytes}

# Original 6/2, 6/5 and 6/8 target-only senders. The client object ID is
# copied unchanged; target ownership and action validity belong to the session.
static func target(target_id: int,operation: String)->Dictionary:
	if not valid_id(target_id):return {"error":"Invalid native interaction target"}
	var minor: int={"attack":2,"examine":5,"talk":8}.get(operation,-1)
	if minor<0:return {"error":"Invalid native target operation"}
	var bytes:=PackedByteArray([112,6,minor,11,0,0,0]);bytes.resize(12)
	bytes.encode_u32(7,target_id);bytes[11]=0x60
	return {"bytes":bytes}

# Original 6/3 open/close and 6/11 use-object writers. The native suffix is
# the 3-bit Create prefix plus the two original use flags for the latter.
static func door(target_id: int,open: bool)->Dictionary:
	if not valid_id(target_id):return {"error":"Invalid native door target"}
	var bytes:=PackedByteArray([112,6,3,13,0,0,0]);bytes.resize(14)
	bytes.encode_u32(7,target_id);bytes.encode_u16(11,21 if open else 22);bytes[13]=0x60
	return {"bytes":bytes}

static func use_object(target_id: int,placeable: bool)->Dictionary:
	if not valid_id(target_id):return {"error":"Invalid native object-use target"}
	var bytes:=PackedByteArray([112,6,11,11,0,0,0]);bytes.resize(12)
	bytes.encode_u32(7,target_id);bytes[11]=0xa8 if placeable else 0xa0
	return {"bytes":bytes}

# Original inventory GUI senders 7be110/7be060. The suffix contains the
# 3-bit Create marker and the one-bit open/self value; remaining bits are
# native padding and stay zero in the Godot packet.
static func inventory_window(owner_id: int,opened: bool)->Dictionary:
	if not valid_id(owner_id):return {"error":"Invalid native inventory owner"}
	var bytes:=PackedByteArray([112,13,1,11,0,0,0]);bytes.resize(12)
	bytes.encode_u32(7,owner_id);bytes[11]=0x95 if opened else 0x85
	return {"bytes":bytes}

static func inventory_panel(panel: int,is_self: bool=true)->Dictionary:
	if panel<0 or panel>255:return {"error":"Invalid native inventory panel"}
	return {"bytes":PackedByteArray([112,13,2,8,0,0,0,panel,0x95 if is_self else 0x85])}

# Original client7c0d70/7c0f60/7c1100/7c1030 senders. The server owns
# ownership transfers, slot fit, cursed-item checks and final inventory state.
static func item_repository(item_id: int,operation: String,destination_id: int,x: int=255,y: int=255)->Dictionary:
	var minor: int={"pickup":5,"unequip":7,"move":9}.get(operation,-1)
	if minor<0 or not valid_id(item_id) or not valid_id(destination_id) or x<0 or x>255 or y<0 or y>255:return {"error":"Invalid native repository request"}
	var bytes:=PackedByteArray([112,12,minor,17,0,0,0]);bytes.resize(18)
	bytes.encode_u32(7,item_id);bytes.encode_u32(11,destination_id);bytes[15]=x;bytes[16]=y;bytes[17]=0x60
	return {"bytes":bytes}

static func item_equip(item_id: int,destination_id: int,slot: int)->Dictionary:
	if not valid_id(item_id) or not valid_id(destination_id) or not valid_id(slot):return {"error":"Invalid native equip request"}
	var bytes:=PackedByteArray([112,12,1,19,0,0,0]);bytes.resize(20)
	bytes.encode_u32(7,item_id);bytes.encode_u32(11,destination_id);bytes.encode_u32(15,slot);bytes[19]=0x60
	return {"bytes":bytes}

static func item_drop(item_id: int,position: Array)->Dictionary:
	if not valid_id(item_id) or position.size()!=3:return {"error":"Invalid native item drop request"}
	var bytes:=PackedByteArray([112,12,3,23,0,0,0]);bytes.resize(24)
	bytes.encode_u32(7,item_id)
	for index in range(3):
		var value: Variant=position[index]
		if not (value is int or value is float) or not is_finite(float(value)):return {"error":"Invalid native item drop position"}
		bytes.encode_float(11+index*4,float(value))
		if not is_finite(bytes.decode_float(11+index*4)):return {"error":"Native item drop coordinate exceeds float32"}
	bytes[23]=0x60
	return {"bytes":bytes}

static func item_toggle(item_id: int,second_id: int=INVALID)->Dictionary:
	if not valid_id(item_id) or not valid_id(second_id):return {"error":"Invalid native equipment toggle"}
	var paired:=second_id!=INVALID
	var bytes:=PackedByteArray([112,12,11,15 if paired else 11,0,0,0]);bytes.resize(16 if paired else 12)
	bytes.encode_u32(7,item_id)
	if paired:bytes.encode_u32(11,second_id)
	bytes[bytes.size()-1]=0x90 if paired else 0x80
	return {"bytes":bytes}

static func item_split(item_id: int,amount: int)->Dictionary:
	if not valid_id(item_id) or amount<1 or amount>65535:return {"error":"Invalid native item split amount"}
	var bytes:=PackedByteArray([112,6,23,13,0,0,0]);bytes.resize(14)
	bytes.encode_u32(7,item_id);bytes.encode_u16(11,amount);bytes[13]=0x60
	return {"bytes":bytes}

static func item_learn(item_id: int)->Dictionary:
	if not valid_id(item_id):return {"error":"Invalid native scroll item"}
	var bytes:=PackedByteArray([112,12,13,11,0,0,0]);bytes.resize(12)
	bytes.encode_u32(7,item_id);bytes[11]=0x60
	return {"bytes":bytes}

# Original client7ba540..7bab8e, server445030. Tell targets are player IDs or
# first-name strings, never creature object IDs.
static func chat(channel: int,value: String,player_id: int=-1,recipient: String="")->Dictionary:
	if channel not in [1,2,3,4,6,14] or value.to_utf8_buffer().has(0):return {"error":"Invalid native chat request"}
	var encoded: Dictionary=GffText.encode(value)
	if encoded.has("error") or encoded.bytes.size()>65535:return {"error":"Native chat text cannot be encoded"}
	var named:=not recipient.is_empty()
	if channel==4:
		if named==valid_id(player_id) or recipient.to_utf8_buffer().has(0):return {"error":"Invalid native tell recipient"}
	elif named or player_id>=0:return {"error":"Unexpected native chat recipient"}
	var name: Dictionary=GffText.encode(recipient) if named else {"bytes":PackedByteArray()}
	if name.has("error") or name.bytes.size()>65535:return {"error":"Native tell name cannot be encoded"}
	var size: int=12+encoded.bytes.size()+(name.bytes.size() if named else 0)+(4 if channel==4 else 0)
	var bytes:=PackedByteArray([112,9,channel,0,0,0,0]);bytes.resize(size)
	bytes.encode_u32(3,size-1)
	var at:=7
	if channel==4:
		bytes.encode_u32(at,name.bytes.size() if named else player_id);at+=4
		if named:
			for code in name.bytes:bytes[at]=code;at+=1
	bytes.encode_u32(at,encoded.bytes.size());at+=4
	for code in encoded.bytes:bytes[at]=code;at+=1
	bytes[at]=0x90 if named else 0x80 if channel==4 else 0x60
	return {"bytes":bytes}

static func dialog_reply(owner_id: int,entry_id: int,reply_id: int,abort: bool=false)->Dictionary:
	if not valid_id(owner_id) or not valid_id(entry_id) or not valid_id(reply_id):return {"error":"Invalid native dialog reply"}
	var bytes:=PackedByteArray([112,20,3,20,0,0,0]);bytes.resize(21)
	bytes.encode_u32(7,owner_id);bytes.encode_u32(11,reply_id);bytes[15]=1 if abort else 0;bytes.encode_u32(16,entry_id);bytes[20]=0x60
	return {"bytes":bytes}

# Original quickbar-driven native22/0, 6/27, 6/30 and 6/19 senders.
static func quick_chat(command: int)->Dictionary:
	if command<0 or command>65535:return {"error":"Invalid native quick-chat command"}
	var bytes:=PackedByteArray([112,22,0,9,0,0,0]);bytes.resize(10)
	bytes.encode_u16(7,command);bytes[9]=0x60
	return {"bytes":bytes}

static func associate_command(target_id: int,command: int)->Dictionary:
	if not valid_id(target_id) or command< -2147483648 or command>2147483647:return {"error":"Invalid native associate command"}
	var bytes:=PackedByteArray([112,6,27,15,0,0,0]);bytes.resize(16)
	bytes.encode_u32(7,target_id);bytes.encode_s32(11,command);bytes[15]=0x60
	return {"bytes":bytes}

static func cancel_polymorph(actor_id: int)->Dictionary:
	if not valid_id(actor_id):return {"error":"Invalid native polymorph actor"}
	var bytes:=PackedByteArray([112,6,30,11,0,0,0]);bytes.resize(12)
	bytes.encode_u32(7,actor_id);bytes[11]=0x60
	return {"bytes":bytes}

static func possess_familiar()->Dictionary:
	return {"bytes":PackedByteArray([112,6,19])}

# Original player->server major30/minor2 shortcut writer. Residual bool bits
# remain separate from the byte body, as in CNWMessage::GetWriteMessage.
static func quickbar_assignment(index: int,button: Dictionary)->Dictionary:
	if index<0 or index>=36:return {"error":"Invalid native quickbar index"}
	var kind:=int(button.get("type",0))
	if kind<0 or kind>48:return {"error":"Invalid native quickbar type"}
	var body:=PackedByteArray([index,kind]);var suffix:=0x60
	if kind==1:
		var item_id:=int(button.get("itemId",-1));var second_id:=int(button.get("secondaryItemId",INVALID));var parameter:=int(button.get("intParam",0))
		if not valid_id(item_id) or not valid_id(second_id) or parameter< -2147483648 or parameter>2147483647:return {"error":"Invalid native quickbar item"}
		append_u32(body,item_id);append_u32(body,parameter)
		if second_id!=INVALID:append_u32(body,second_id)
		suffix=0x90 if second_id!=INVALID else 0x80
	elif kind==2:
		var class_index:=int(button.get("classIndex",-1));var spell_id:=int(button.get("intParam",-1));var metamagic:=int(button.get("metamagic",-1));var domain_level:=int(button.get("domainLevel",-1))
		if class_index<0 or class_index>255 or not valid_id(spell_id) or metamagic<0 or metamagic>255 or domain_level<0 or domain_level>255:return {"error":"Invalid native quickbar spell"}
		body.append(class_index);append_u32(body,spell_id);body.append(metamagic);body.append(domain_level)
	elif kind in [3,4,8,10,27,28,31,32,33,34,37,42,43,45,46,47,48]:
		var parameter:=int(button.get("intParam",0))
		if parameter< -2147483648 or parameter>2147483647:return {"error":"Invalid native quickbar integer"}
		append_u32(body,parameter)
	elif kind in [11,12,13,14,15,16,17,29,30]:
		var resource: Variant=button.get("resRef")
		if not resource is String:return {"error":"Invalid native quickbar resource"}
		var resource_value:=str(resource)
		for offset in resource_value.length():
			if resource_value.unicode_at(offset)==0:resource_value=resource_value.substr(0,offset);break
		var encoded: Dictionary=GffText.encode(resource_value)
		if encoded.has("error"):return {"error":"Invalid native quickbar resource"}
		var resref: PackedByteArray=encoded.bytes.slice(0,16);resref.resize(16);body.append_array(resref)
		if kind<=17:
			if not button.get("toolTip") is String:return {"error":"Invalid native quickbar text"}
			var text: Dictionary=append_quickbar_text(body,str(button.toolTip))
			if text.has("error"):return text
	elif kind==18:
		for field in ["commandLabel","commandLine"]:
			if not button.get(field) is String:return {"error":"Invalid native quickbar text"}
			var text: Dictionary=append_quickbar_text(body,str(button[field]))
			if text.has("error"):return text
	elif kind==39:
		var parameter:=int(button.get("intParam",0));var associate_type:=int(button.get("associateType",-1));var associate_id:=int(button.get("associateId",-1))
		if parameter< -2147483648 or parameter>2147483647 or associate_type<0 or associate_type>65535 or not valid_id(associate_id):return {"error":"Invalid native quickbar associate"}
		append_u32(body,parameter);append_u16(body,associate_type);append_u32(body,associate_id)
	elif kind==44:
		var parameter:=int(button.get("intParam",-1));var domain_level:=int(button.get("domainLevel",-1))
		if not valid_id(parameter) or domain_level<0 or domain_level>255:return {"error":"Invalid native quickbar ability"}
		append_u32(body,parameter);body.append(domain_level)
	elif kind not in [0,6,7,19,20,21,22,23,24,25,35,36,38,40,41]:return {"error":"Unsupported native quickbar assignment type"}
	var bytes:=PackedByteArray([112,30,2]);bytes.resize(7);bytes.encode_u32(3,7+body.size());bytes.append_array(body);bytes.append(suffix)
	return {"bytes":bytes}

static func append_u16(bytes: PackedByteArray,value: int)->void:
	var at:=bytes.size();bytes.resize(at+2);bytes.encode_u16(at,value)

static func append_u32(bytes: PackedByteArray,value: int)->void:
	var at:=bytes.size();bytes.resize(at+4);bytes.encode_u32(at,value)

static func append_quickbar_text(bytes: PackedByteArray,value: String)->Dictionary:
	var encoded: Dictionary=GffText.encode(value)
	if encoded.has("error") or encoded.bytes.size()>65535:return {"error":"Invalid native quickbar text"}
	append_u32(bytes,encoded.bytes.size());bytes.append_array(encoded.bytes)
	return {}
