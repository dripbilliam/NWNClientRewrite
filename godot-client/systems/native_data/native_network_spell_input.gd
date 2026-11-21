extends RefCounted
# Original native spell and innate request writers from network_spell_input.js.
# These only serialize requests; the server owns preparation and cast outcomes.
const OBJECT_INVALID:=0x7f000000
const Rules=preload("res://systems/native_data/game_ui_rules.gd")
const SpellMetadata=preload("res://systems/native_data/spell_metadata.gd")

# The first family child supplies client target/preview metadata. The request
# keeps the original spell WORD; family selection is a separate UI action.
static func spell_target_definition(spell_id: int,rules) -> Dictionary:
	var selected:=spell_id&65535
	var table: Dictionary=rules.text.tables.get("spells",{})
	var spell: Variant=SpellMetadata.casting_spell(table,selected)
	if spell==null:return {}
	var talent: Variant=SpellMetadata.talent_spell(table,selected)
	var children: Array=talent.children if talent!=null else []
	if not children.is_empty():
		selected=int(children[0])&0xffffffff
		spell=SpellMetadata.casting_spell(table,selected)
		if spell==null:return {}
		talent=SpellMetadata.talent_spell(table,selected)
		children=talent.children if talent!=null else []
	spell.children=children
	spell.row=rules.row("spells",selected)
	return spell

static func prepare_spell_target(actor: Dictionary,request: Dictionary,rules,auto_self: int=1,inventory_mode: Variant=null,container_mode: Variant=null) -> Dictionary:
	if actor.is_empty():return {"mode":"unavailable"}
	var spell_id: Variant=request.get("spellId")
	if not (spell_id is int or spell_id is float and is_finite(spell_id) and spell_id==floor(spell_id)):return {"mode":"unavailable"}
	var definition:=spell_target_definition(int(spell_id),rules)
	if definition.is_empty():return {"mode":"unavailable"}
	var mask:=int(definition.targetType)&65535
	var self_target:=(((mask-1)&65531)==0) and (auto_self&255)!=0
	if mask==9:self_target=(auto_self&255)!=0 and inventory_mode!=1 and container_mode!=1
	var target_types: Array=[]
	for pair in [[1,5],[2,5],[4,2],[8,6],[16,10],[32,9],[64,7]]:
		if (mask&int(pair[0]))!=0:target_types.append(pair[1])
	var selected: Dictionary=request.duplicate(true);selected.spellId=int(spell_id)&65535
	return {"mode":"self" if self_target else "target","request":selected,"definition":definition,"targetTypes":target_types}

static func spell_creature_target_veto(spell_id: int,actor: Dictionary,target: Dictionary,rules) -> bool:
	var definition:=spell_target_definition(spell_id,rules)
	if definition.is_empty():return true
	if int(target.get("objectType",0))==5:
		var mask:=int(definition.targetType)&65535
		if (mask&1)==0 and int(target.get("id",OBJECT_INVALID))==int(actor.get("id",OBJECT_INVALID)):return true
		if (mask&2)==0 and int(target.get("id",OBJECT_INVALID))!=int(actor.get("id",OBJECT_INVALID)):return true
	return false

static func uint(value: Variant)->bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)==floor(float(value)) and value>=0 and value<=0xffffffff

static func byte(value: Variant)->bool:
	return uint(value) and value<=255

static func word(value: Variant)->bool:
	return uint(value) and value<=65535

static func f32(value: float)->float:
	var bytes:=PackedByteArray([0,0,0,0])
	bytes.encode_float(0,value)
	return bytes.decode_float(0)

static func point_valid(position: Variant)->bool:
	if not position is Array or position.size()!=3:return false
	for value in position:
		if not (value is int or value is float) or not is_finite(float(value)) or not is_finite(f32(float(value))):return false
	return true

static func point_present(point: Array)->bool:
	var x: float=point[0];var y: float=point[1];var z: float=point[2]
	var square_sum:=f32(f32(f32(x*x)+f32(y*y))+f32(z*z))
	return (f32(sqrt(square_sum)) if square_sum>0.0 else 0.0)>=f32(0.00001)

static func append_u32(bytes: PackedByteArray,value: int)->PackedByteArray:
	var offset:=bytes.size();bytes.resize(offset+4);bytes.encode_u32(offset,value)
	return bytes

static func append_u16(bytes: PackedByteArray,value: int)->PackedByteArray:
	var offset:=bytes.size();bytes.resize(offset+2);bytes.encode_u16(offset,value)
	return bytes

static func append_f32(bytes: PackedByteArray,value: float)->PackedByteArray:
	var offset:=bytes.size();bytes.resize(offset+4);bytes.encode_float(offset,value)
	return bytes

static func finish(bytes: PackedByteArray)->PackedByteArray:
	# NativeMessageWriter(1) stores the byte-stream length before its residual
	# three zero bits; the appended residual byte is 0x60.
	bytes.encode_u32(3,bytes.size())
	bytes.append(0x60)
	return bytes

static func spell_preparation_request(request: Dictionary)->Dictionary:
	var class_index: Variant=request.get("classIndex")
	var spell_id: Variant=request.get("spellId")
	var slot: Variant=request.get("slot")
	var domain_level: Variant=request.get("domainLevel",0)
	var metamagic: Variant=request.get("metamagic",0)
	if not uint(spell_id) or not byte(class_index) or not byte(slot) or not byte(domain_level) or not byte(metamagic):
		return {"error":"Invalid native spell preparation request"}
	var bytes:=PackedByteArray([112,6,16,0,0,0,0])
	bytes.append(int(class_index));bytes=append_u32(bytes,int(spell_id))
	bytes.append(int(slot));bytes.append(int(domain_level));bytes.append(int(metamagic))
	return {"bytes":finish(bytes)}

static func spell_preparation_clear_request(request: Dictionary)->Dictionary:
	var class_index: Variant=request.get("classIndex")
	var level: Variant=request.get("level")
	var slot: Variant=request.get("slot")
	if not byte(class_index) or not byte(level) or not byte(slot):
		return {"error":"Invalid native spell preparation clear request"}
	var bytes:=PackedByteArray([112,6,17,0,0,0,0])
	bytes.append(int(class_index));bytes.append(int(level));bytes.append(int(slot))
	return {"bytes":finish(bytes)}

static func spell_cast_request(request: Dictionary)->Dictionary:
	var spell_id: Variant=request.get("spellId")
	var class_index: Variant=request.get("classIndex",0)
	var domain_level: Variant=request.get("domainLevel",0)
	var metamagic: Variant=request.get("metamagic",0)
	var spontaneous: Variant=request.get("spontaneous",false)
	var target_id: Variant=request.get("targetId",OBJECT_INVALID)
	var position: Variant=request.get("position",[0,0,0])
	var target_type: Variant=request.get("targetType")
	var valid_spontaneous: bool=spontaneous is bool or (spontaneous is int or spontaneous is float) and spontaneous in [0,1]
	if not uint(spell_id) or not uint(target_id) or not byte(class_index) or not byte(domain_level) or not byte(metamagic) or not valid_spontaneous or not word(target_type) or not point_valid(position):
		return {"error":"Invalid native spell cast request"}
	var point: Array=[f32(float(position[0])),f32(float(position[1])),f32(float(position[2]))]
	var has_point:=point_present(point)
	var has_target:=int(target_id)!=OBJECT_INVALID
	var bytes:=PackedByteArray([112,6,18,0,0,0,0])
	bytes=append_u32(bytes,int(spell_id))
	bytes.append(int(class_index));bytes.append(int(domain_level));bytes.append(int(metamagic))
	bytes.append((1 if has_target else 0)|(2 if has_point else 0)|(4 if bool(spontaneous) else 0))
	if has_target:bytes=append_u32(bytes,int(target_id))
	if has_point:
		bytes=append_f32(bytes,point[0]);bytes=append_f32(bytes,point[1])
		bytes=append_f32(bytes,f32(point[2]+f32(0.3)))
	bytes=append_u16(bytes,int(target_type))
	return {"bytes":finish(bytes)}

static func spell_like_cast_request(request: Dictionary)->Dictionary:
	var spell_id: Variant=request.get("spellId")
	var caster_level: Variant=request.get("casterLevel")
	var target_id: Variant=request.get("targetId",OBJECT_INVALID)
	var position: Variant=request.get("position",[0,0,0])
	if not uint(spell_id) or not byte(caster_level) or not uint(target_id) or not point_valid(position):
		return {"error":"Invalid native innate cast request"}
	var point: Array=[f32(float(position[0])),f32(float(position[1])),f32(float(position[2]))]
	var has_point:=point_present(point)
	var has_target:=int(target_id)!=OBJECT_INVALID
	var bytes:=PackedByteArray([112,6,35,0,0,0,0])
	bytes=append_u32(bytes,int(spell_id));bytes.append(int(caster_level))
	bytes.append((1 if has_target else 0)|(2 if has_point else 0))
	if has_target:bytes=append_u32(bytes,int(target_id))
	if has_point:
		bytes=append_f32(bytes,point[0]);bytes=append_f32(bytes,point[1])
		bytes=append_f32(bytes,f32(point[2]+f32(0.3)))
	return {"bytes":finish(bytes)}
