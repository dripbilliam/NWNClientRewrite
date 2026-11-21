extends RefCounted
# Original client 112/29/4 begin and 112/29/0 proposal. The residual byte's
# lower five bits are native allocator residue; only its upper Create bits are
# defined. This writer zeroes the undefined bits.
const ScriptString=preload("res://systems/native_data/native_script_string.gd")

static func begin()->PackedByteArray:return PackedByteArray([112,29,4])

static func character_sheet(actor_id: int)->PackedByteArray:
	var bytes:=PackedByteArray([112,21,1,12,0,0,0,0,0,0,0,0,96])
	bytes.encode_u32(8,actor_id)
	return bytes

static func cancel(include_position: bool)->PackedByteArray:
	return PackedByteArray([112,53,1,27,0,0,0,16,0,0,0,0,0,0,127,0,0,0,0,0,0,0,0,0,0,0,0,96]) if include_position else PackedByteArray([112,53,1,15,0,0,0,16,0,0,0,0,0,0,127,96])

static func whole(value: Variant,minimum: int,maximum: int)->bool:
	return (value is int or value is float and is_finite(value) and value==floor(value)) and int(value)>=minimum and int(value)<=maximum

static func western_bytes(value: Variant)->Dictionary:
	if not value is String:return {"error":"Invalid native level-up text"}
	var encoded: Dictionary=ScriptString.bytes(value)
	if encoded.has("error"):return encoded
	var bytes: PackedByteArray=encoded.value
	if bytes.size()>255:return {"error":"Native level-up text exceeds bound"}
	return {"bytes":bytes}

static func append_u16(bytes: PackedByteArray,value: int)->void:
	var offset:=bytes.size();bytes.resize(offset+2);bytes.encode_u16(offset,value)

static func append_u32(bytes: PackedByteArray,value: int)->void:
	var offset:=bytes.size();bytes.resize(offset+4);bytes.encode_u32(offset,value&0xffffffff)

static func proposal(value: Dictionary,options: Dictionary)->Dictionary:
	var level: Variant=options.get("level");var skill_count: Variant=options.get("skillCount")
	var class_id: Variant=value.get("classId");var ability: Variant=value.get("ability",6);var hit_die: Variant=value.get("hitDie")
	var skill_points: Variant=value.get("skillPoints");var skills: Variant=value.get("skills");var feats: Variant=value.get("feats")
	var field_e34: Variant=value.get("fieldE34");var field_e30: Variant=value.get("fieldE30")
	if not whole(level,1,254) or not whole(skill_count,0,255) or not whole(class_id,0,254) or not whole(ability,0,6) or not whole(hit_die,1,255) or not whole(skill_points,0,65535) or not whole(field_e34,-2147483648,2147483647) or not whole(field_e30,-2147483648,2147483647):return {"error":"Invalid native level-up proposal scalars"}
	if not skills is Array or skills.size()!=int(skill_count) or not feats is Array or feats.size()>255:return {"error":"Invalid native level-up skill or feat lists"}
	for rank in skills:
		if not whole(rank,0,127):return {"error":"Invalid native level-up skill rank"}
	for feat in feats:
		if not whole(feat,0,65535):return {"error":"Invalid native level-up feat"}
	if (int(level)+1)%4==0 and int(ability)==6 or (int(level)+1)%4!=0 and int(ability)!=6:return {"error":"Invalid native level-up ability choice"}
	var familiar: Dictionary=western_bytes(value.get("fieldE48"))
	var companion: Dictionary=western_bytes(value.get("fieldE38"))
	if familiar.has("error") or companion.has("error"):return {"error":"Invalid native level-up associate text"}
	var pick_domains:=bool(options.get("pickDomains",false));var pick_school:=bool(options.get("pickSchool",false))
	var domains: Variant=value.get("domains",[]);var school: Variant=value.get("school",0)
	if pick_domains:
		if not domains is Array or domains.size()!=2:return {"error":"Invalid native level-up domains"}
		for domain in domains:
			if not whole(domain,0,255):return {"error":"Invalid native level-up domain"}
	if pick_school and not whole(school,0,255):return {"error":"Invalid native level-up school"}
	var known: Variant=value.get("known",{});var removed: Variant=value.get("removed",{})
	if not known is Dictionary or not removed is Dictionary:return {"error":"Invalid native level-up spellbooks"}
	var bytes:=PackedByteArray([112,29,0,0,0,0,0])
	bytes.append(int(class_id))
	if (int(level)+1)%4==0:bytes.append(int(ability))
	bytes.append(int(hit_die))
	var mask:=0
	for index in skills.size():
		if int(skills[index])!=0:mask|=1<<(index&31)
	append_u32(bytes,mask)
	for index in skills.size():
		if mask & (1<<(index&31)):bytes.append(int(skills[index]))
	append_u16(bytes,int(skill_points));bytes.append(feats.size())
	for feat in feats:append_u16(bytes,int(feat))
	for spell_level in 10:
		for book in [known,removed]:
			var spells: Variant=book.get(str(spell_level),book.get(spell_level,[]))
			if not spells is Array or spells.size()>255:return {"error":"Invalid native level-up spell list"}
			for spell in spells:
				if not whole(spell,0,0xffffffff):return {"error":"Invalid native level-up spell"}
			bytes.append(spells.size())
			for spell in spells:append_u32(bytes,int(spell))
	append_u32(bytes,int(field_e34));append_u32(bytes,familiar.bytes.size());bytes.append_array(familiar.bytes)
	append_u32(bytes,int(field_e30));append_u32(bytes,companion.bytes.size());bytes.append_array(companion.bytes)
	if pick_domains:
		for domain in domains:bytes.append(int(domain))
	if pick_school:bytes.append(int(school))
	bytes.encode_u32(3,bytes.size())
	bytes.append(0x60)
	return {"bytes":bytes}
