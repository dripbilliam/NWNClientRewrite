extends RefCounted
# Original active-item-property request 6/9. Optional fields are selected by
# the native residual bool stream, with no spell point epsilon or Z adjustment.
const OBJECT_INVALID:=0x7f000000
const Rules=preload("res://systems/native_data/game_ui_rules.gd")

static func item_spell_target_definition(item: Dictionary,packed: int,providers) -> Dictionary:
	var id: int=providers.property_spell(item,packed&65535)&0xffffffff
	var spell: Dictionary=providers._spell(id)
	if spell.is_empty():return {}
	var children: Array=providers._children(id)
	if ((packed>>16)&65535)!=255 and (children.size()&255)>0:
		var child:=(packed>>16)&255
		if child>=children.size():return {}
		id=int(children[child])&0xffffffff;spell=providers._spell(id)
		if spell.is_empty():return {}
	var result:=spell.duplicate(true)
	result.id=id;result.targetType=Rules.number(Rules.cell(spell,"TargetType"),0)&65535
	result.children=providers._children(id)
	return result

static func prepare_item_target(item_id: int,packed: int,providers,inventory_mode: int=0,container_mode: int=0,auto_self: int=1,report: Callable=Callable()) -> Dictionary:
	var item: Dictionary=providers.item(item_id&0xffffffff)
	if item.is_empty():return {"mode":"unavailable"}
	var property: Dictionary=providers._property(item,packed&65535)
	if property.is_empty():return {"mode":"unavailable"}
	var state: Dictionary={"mode":"target","itemId":item_id&0xffffffff,"packed":packed,"point":[0.0,0.0,0.0],"targetId":OBJECT_INVALID,"targetTypes":[],"flags":0,"creatureVeto":false,"definition":{}}
	var kind:=int(property.get("type",0))&65535
	if kind==15:
		state.flags=31;state.creatureVeto=true
		var spell:=item_spell_target_definition(item,packed,providers)
		state.definition=spell
		if spell.is_empty():return state
		var mask:=int(spell.targetType)&65535;var base: Dictionary=providers.base_info(item);var self_target:=false
		if not base.is_empty():
			var behavior:=int(base.qbBehaviour)&255
			if behavior==2 or mask==1:self_target=(auto_self&255)!=0
			elif mask==9:self_target=(auto_self&255)!=0 and inventory_mode!=1 and container_mode!=1
		if self_target:state.mode="self";state.targetId=providers.controlled_id()&0xffffffff;return state
		for pair in [[1,5],[2,5],[4,2],[8,6],[16,10],[32,9],[64,7]]:
			if (mask&int(pair[0]))!=0:state.targetTypes.append([pair[1],29])
		if report.is_valid():report.call("network.item-target-preview-unhandled","Native item targeting preview is not connected",{"spellId":int(spell.id)})
		return state
	if kind==55:state.flags=43;state.targetTypes=[[10,41],[9,41]]
	elif kind==70:state.flags=35;state.targetTypes=[[2,33],[5,33],[10,33],[9,33]]
	elif kind==80:state.flags=57;state.targetTypes=[[2,55],[5,55],[10,55],[9,55]]
	elif report.is_valid():report.call("network.item-target-warning","ActivateActionTarget: unsupported active property type",{})
	return state

static func item_creature_target_veto(item_id: int,packed: int,target_id: int,providers) -> bool:
	var item: Dictionary=providers.item(item_id&0xffffffff)
	if item.is_empty():return true
	var spell:=item_spell_target_definition(item,packed,providers)
	if spell.is_empty():return true
	var object: Dictionary=providers.world_state.registry.get(target_id&0xffffffff,{})
	if int(object.get("objectType",0))!=5 or bool(object.get("replicationRemoved",false)):return false
	var mask:=int(spell.targetType)&65535
	if (mask&1)==0 and int(object.get("id",target_id))==providers.controlled_id():return true
	if (mask&2)==0 and int(object.get("id",target_id))!=providers.controlled_id():return true
	return false

static func confirm_item_target(state: Dictionary,target_id: int,point: Array,providers) -> Dictionary:
	var position:=point.duplicate()
	var target: Dictionary=providers.item(target_id&0xffffffff)
	if not target.is_empty():
		var canonical: Dictionary=target.get("canonical",{})
		var location: Variant=canonical.get("inventoryLocation")
		var possessor_id: Variant=location.get("ownerId") if location is Dictionary else null
		if possessor_id==null:possessor_id=canonical.get("equipmentOwnerId",OBJECT_INVALID)
		var possessor: Dictionary=providers.world_state.registry.get(int(possessor_id),{})
		if int(possessor.get("objectType",0))==5 and not bool(possessor.get("replicationRemoved",false)):
			position=possessor.get("replicated",{}).get("position",[0.0,0.0,0.0]).duplicate()
		else:position=canonical.get("replicated",{}).get("position",[0.0,0.0,0.0]).duplicate()
	return {"kind":"native-item-ability","itemId":int(state.itemId)&0xffffffff,"propertyIndex":int(state.packed)&255,"variant":(int(state.packed)>>16)&255,"targetId":target_id&0xffffffff,"position":position}

static func uint(value: Variant)->bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)==floor(float(value)) and value>=0 and value<=0xffffffff

static func byte(value: Variant)->bool:
	return uint(value) and value<=255

static func f32(value: float)->float:
	var bytes:=PackedByteArray([0,0,0,0]);bytes.encode_float(0,value)
	return bytes.decode_float(0)

static func item_use_request(request: Dictionary)->Dictionary:
	var item_id: Variant=request.get("itemId")
	var property_index: Variant=request.get("propertyIndex")
	var variant: Variant=request.get("variant",255)
	var target_id: Variant=request.get("targetId",OBJECT_INVALID)
	var position: Variant=request.get("position",[0,0,0])
	if not uint(item_id) or not byte(property_index) or not byte(variant) or not uint(target_id) or not position is Array or position.size()!=3:
		return {"error":"Invalid native item-use request"}
	for coordinate in position:
		if not (coordinate is int or coordinate is float) or not is_finite(float(coordinate)) or not is_finite(f32(float(coordinate))):
			return {"error":"Invalid native item-use request"}
	var point: Array=[f32(float(position[0])),f32(float(position[1])),f32(float(position[2]))]
	var has_variant:=int(variant)!=255
	var has_target:=int(target_id)!=OBJECT_INVALID
	var has_point: bool=point[0]!=0.0 or point[1]!=0.0 or point[2]!=0.0
	var body_size:=5+(1 if has_variant else 0)+(4 if has_target else 0)+(12 if has_point else 0)
	var bytes:=PackedByteArray([112,6,9]);bytes.resize(7+body_size+1)
	bytes.encode_u32(3,7+body_size)
	bytes.encode_u32(7,int(item_id));bytes[11]=int(property_index)
	var offset:=12
	if has_variant:
		bytes[offset]=int(variant)
		offset+=1
	if has_target:
		bytes.encode_u32(offset,int(target_id))
		offset+=4
	if has_point:
		for index in range(3):bytes.encode_float(offset+index*4,point[index])
		offset+=12
	# Create writes three zero prefix bits. Three following bools occupy bits
	# 4, 3 and 2; six residual bits set the 0xc0 suffix high-bit count.
	bytes[offset]=0xc0|(0x10 if has_variant else 0)|(0x08 if has_target else 0)|(0x04 if has_point else 0)
	return {"bytes":bytes}
