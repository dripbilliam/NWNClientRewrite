extends RefCounted
# Original mode1 private clone after Class/Attributes/Skills. This adapter
# never composes creation's first-level draft or mutates received storage.
const Tables=preload("res://systems/native_data/creation_feat_tables.gd")
const Vitals=preload("res://systems/native_data/level_up_vitals.gd")
const Slots=preload("res://systems/native_data/creation_feat_slots.gd")
const Values=preload("res://systems/native_data/character_record_values.gd")
const Skills=preload("res://systems/native_data/pregame_skills.gd")
static func pending(reason: String,dependencies: Array=[]) -> Dictionary:return {"ready":false,"reason":reason,"dependencies":dependencies}
static func base_attack(classes: Array,tables: Dictionary) -> Dictionary:
	# SetClassLevel7f9a60 ->7f7b80 invalidates cache9b. Getter7f0900
	# adds each class BYTE;2997b0 reads only levels1..60. Loader29a3c0
	# stores successful INT BAB as BYTE, failed reads as zero in60 rows.
	var total:=0
	for cls in classes:
		if not cls is Dictionary or not Vitals.Class.integer(cls.get("id"),0,254) or not Vitals.Class.integer(cls.get("level"),0,255):return pending("Private class BAB source is malformed.")
		if int(cls.id)>=(Skills.rows(tables,"classes").size()&255):return pending("Private class BAB metadata is unavailable.")
		var level:=int(cls.level)
		if level<1 or level>60:continue
		var name:=Skills.table_name(Skills.row(tables,"classes",int(cls.id)),"AttackBonusTable")
		if name.is_empty() or not tables.has(name):return pending("Active class attack-bonus table is unavailable.",[name] if not name.is_empty() else [])
		var read:=Tables.integer(tables[name],level-1,"BAB")
		if not read.ready:return pending(str(read.reason))
		total=(total+(int(read.value)&255 if read.ok else 0))&255
	return {"ready":true,"value":total}
static func compose(received: Dictionary,class_id: int,ability: int,ranks: Array,tables: Dictionary,context: Dictionary,chosen: Array=[],prepared: Dictionary={}) -> Dictionary:
	var missing: Array=[]
	for name in ["classes","racialtypes","ruleset","feat","skills"]:
		if not tables.has(name):missing.append(name)
	if not missing.is_empty():return pending("Active mode1 feat rules have not arrived.",missing)
	var vitals:=Vitals.project(received,class_id,ability,tables)
	if not vitals.ready:return vitals
	#837f60 copies base save9c; the new private CON setter refreshes98.
	# The existing begin-result producer does not yet expose this context.
	if not Vitals.Class.integer(context.get("baseFortitude"),-128,127):return pending("Received private base Fortitude context is unavailable.")
	if not received.get("feats") is Array or received.feats.size()>65535:return pending("Received owned feat storage is unavailable.")
	for id in received.feats:
		if not Vitals.Class.integer(id,0,65535):return pending("Received owned feat ID is malformed.")
	if ranks.size()!=(Skills.rows(tables,"skills").size()&255):return pending("Private level-up skill storage is incomplete.")
	for rank in ranks:
		if not Vitals.Class.integer(rank,0,255):return pending("Private level-up skill BYTE is malformed.")
	var decoded:=prepared if prepared.get("ready",false) else Tables.decode(tables.feat)
	if not decoded.ready:return decoded
	var definitions: Array=decoded.definitions;var classes: Array=[]
	for source in vitals.classes:
		var cls: Dictionary=source.duplicate(true);var row:=Skills.row(tables,"classes",int(cls.id))
		var feat_name:=Skills.table_name(row,"FeatsTable");var skill_name:=Skills.table_name(row,"SkillsTable")
		for name in [feat_name,skill_name]:
			if not name.is_empty() and not tables.has(name):return pending("Active owned-class feat/skill storage is unavailable.",[name])
		var records:=Tables.class_records(tables.get(feat_name,{}),definitions)
		if not records.ready:return records
		cls.feats=records.records;cls.skills=[]
		var skill_table: Dictionary=tables.get(skill_name,{})
		for at in skill_table.get("orderedRows",[]).size():
			var read:=Tables.integer(skill_table,at,"SkillIndex")
			if not read.ready:return read
			var id:=int(read.value)&65535
			if id>=ranks.size():return pending("Owned class references unavailable original skill storage.")
			cls.skills.append(id)
		classes.append(cls)
	var current: Dictionary=classes[int(vitals.current)];var class_row:=Skills.row(tables,"classes",class_id)
	var bonus_name:=Skills.table_name(class_row,"BonusFeatsTable")
	if not bonus_name.is_empty() and not tables.has(bonus_name):return pending("Active class bonus feat storage is unavailable.",[bonus_name])
	var attack:=base_attack(classes,tables)
	if not attack.ready:return attack
	# IDs have already passed the received WORD validation above. Canonicalize
	# only this detached private view: JSON FLOAT membership must match physical
	# INT feat IDs, including existing grants and prerequisite checks.
	var owned: Array=received.feats.map(func(id):return int(id));var grants: Dictionary={}
	#7ebd50 visits physical valid IDs and grants only the first class record
	# at exactly the new current-class level; old/racial grants stay received.
	for record in current.feats:
		if not grants.has(int(record.id)):grants[int(record.id)]=int(record.List)==3 and int(record.level)==int(current.level)
	for id in definitions.size():
		if definitions[id].valid and grants.get(id,false) and not owned.has(id):owned.append(id)
	var skills: Array=[]
	for id in ranks.size():
		var skill:={"rank":int(ranks[id])}
		for key in ["Untrained","AllClassesCanUse"]:
			var read:=Tables.integer(tables.skills,id,key)
			if not read.ready:return read
			skill[key]=int(read.value)
		skills.append(skill)
	var slots:=Slots.calculate(tables,int(received.race),class_id,int(vitals.level),int(current.level))
	var source:={"current":int(vitals.current),"classes":classes,"definitions":definitions,"scores":vitals.scores,"baseAttack":int(attack.value),"fortitude":Values.signed8(int(context.baseFortitude)+int(vitals.modifiers[2])),"owned":owned,"selected":chosen.duplicate(),"normal":int(slots.normal),"bonus":int(slots.bonus),"skills":skills,"spellLevels":{}}
	return {"ready":true,"source":source,"vitals":vitals,"classId":class_id,"raceId":int(received.race)}
static func resolve_spells(snapshot: Dictionary,resolver: Callable) -> Dictionary:
	if not snapshot.get("ready",false):return snapshot
	var required: Dictionary={}
	for feat in snapshot.source.definitions:
		if feat.valid and int(feat.MinSpellLvl)!=0:required[int(feat.MinSpellLvl)]=true
	for level in required:
		if not resolver.is_valid():return pending("Original mode1 spell-capacity owner is unavailable.")
		var value: Variant=resolver.call(snapshot,int(level))
		if not value is Dictionary or not value.get("ready",false) or not value.get("allowed") is bool:return pending("Original mode1 spell-capacity result is unavailable.")
		snapshot.source.spellLevels[level]=value.allowed
	return snapshot
