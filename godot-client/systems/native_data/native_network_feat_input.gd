extends RefCounted
# Native feat, mode, and quickbar feat-use requests from network_feat_input.js.
const OBJECT_INVALID:=0x7f000000
const Rules=preload("res://systems/native_data/game_ui_rules.gd")
const TARGET_MODES={28:3,19:4,30:7,204:6,899:6,866:6,389:8,390:9,425:11,947:12}

static func prepare_feat_target(request: Dictionary,feat_rules,auto_self: int=1) -> Dictionary:
	var raw: Variant=request.get("featId")
	if not (raw is int or raw is float and is_finite(raw) and raw==floor(raw)):return {"mode":"unavailable"}
	var packed:=int(raw);var id:=packed&65535
	var auxiliary:=int(request.get("auxiliary",(packed>>16)&65535))&65535
	var info: Dictionary=feat_rules.feat(id)
	if info.is_empty():return {"mode":"unavailable"}
	var binding: Dictionary=request.duplicate(true);binding.featId=id;binding.auxiliary=auxiliary
	if auxiliary==0 and TARGET_MODES.has(id):return {"mode":"mode","modeId":TARGET_MODES[id],"request":binding}
	if int(info.get("targetSelf",0))!=0 and (auto_self&255)!=0:return {"mode":"self","request":binding}
	var definition: Dictionary={"targetType":3}
	if int(info.get("spellId",-1))!=-1:
		var spell_id: int=int(feat_rules.target_spell(id,auxiliary))
		var spell: Dictionary=feat_rules.rules.row("spells",spell_id)
		definition={"id":spell_id,"targetType":Rules.number(Rules.cell(spell,"TargetType"),0)&65535} if not spell.is_empty() else {}
	var kinds: Array=[]
	if int(info.get("spellId",-1))==-1:kinds.append(5)
	else:
		var mask:=int(definition.get("targetType",0))
		for pair in [[1,5],[2,5],[4,2],[8,6],[16,10],[32,9],[64,7]]:
			if (mask&int(pair[0]))!=0:kinds.append(pair[1])
	return {"mode":"target","request":binding,"definition":definition,"targetTypes":kinds}

static func feat_target_allowed(definition: Dictionary,target: Dictionary) -> bool:
	var mask:=int(definition.get("targetType",0))
	if target.is_empty():return (mask&4)!=0
	var bit:=int({5:3,6:8,10:16,9:32,7:64}.get(int(target.get("objectType",0)),0))
	return (mask&bit)!=0

static func uint(value: Variant)->bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)==floor(float(value)) and value>=0 and value<=0xffffffff

static func word(value: Variant)->bool:
	return uint(value) and value<=65535

static func f32(value: float)->float:
	var bytes:=PackedByteArray([0,0,0,0]);bytes.encode_float(0,value)
	return bytes.decode_float(0)

static func point_valid(position: Variant)->bool:
	if not position is Array or position.size()!=3:return false
	for value in position:
		if not (value is int or value is float) or not is_finite(float(value)) or not is_finite(f32(float(value))):return false
	return true

static func feat_use_request(request: Dictionary)->Dictionary:
	var feat_id: Variant=request.get("featId")
	var auxiliary: Variant=request.get("auxiliary",0)
	var target_id: Variant=request.get("targetId",OBJECT_INVALID)
	var position: Variant=request.get("position",null)
	if not word(feat_id) or not word(auxiliary) or not uint(target_id) or int(target_id)==OBJECT_INVALID and not point_valid(position):
		return {"error":"Invalid native feat request"}
	var location:=int(target_id)==OBJECT_INVALID
	var size:=28 if location else 16
	var bytes:=PackedByteArray([112,6,6]);bytes.resize(size)
	bytes.encode_u32(3,size-1)
	bytes.encode_u16(7,int(feat_id));bytes.encode_u16(9,int(auxiliary))
	bytes.encode_u32(11,int(target_id))
	if location:
		for index in range(3):bytes.encode_float(15+index*4,f32(float(position[index])))
	bytes[size-1]=0x60
	return {"bytes":bytes}

static func mode_change_request(request: Dictionary)->Dictionary:
	var mode_id: Variant=request.get("modeId")
	var target_id: Variant=request.get("targetId",OBJECT_INVALID)
	if not uint(mode_id) or mode_id>255 or int(mode_id)==5 and not uint(target_id):
		return {"error":"Invalid native mode request"}
	var targeted:=int(mode_id)==5
	var size:=13 if targeted else 9
	var bytes:=PackedByteArray([112,6,10]);bytes.resize(size)
	bytes.encode_u32(3,size-1);bytes[7]=int(mode_id)
	if targeted:bytes.encode_u32(8,int(target_id))
	bytes[size-1]=0x60
	return {"bytes":bytes}

static func network_feat_uses(actor: Variant,feat_rules: RefCounted,id: int)->int:
	id&=65535
	if not actor is Dictionary:return 0
	var player: Dictionary=actor.get("playerState",{})
	if not player.get("feats",[]).has(id) and not player.get("bonusFeats",[]).has(id):return 0
	var counters: Dictionary=player.get("featUses",{})
	if counters.has(str(id)):return int(counters[str(id)])
	if counters.has(id):return int(counters[id])
	# featInfo requires the physical row's Feat cell before UsesPerDay can
	# classify a missing counter as native unlimited (100).
	if feat_rules.feat(id).is_empty():return 0
	var row: Dictionary=feat_rules.rules.row("feat",id)
	return 100 if (Rules.number(Rules.cell(row,"UsesPerDay"),0)&255)==0 else 0
