extends RefCounted
# Live first-level draft caches, not imported BIC or in-world effect statistics.
# Class OK8e36d0 clears +84 only when changing class; SetClass7f9820 fills a
# zero cache. CON7f96d0 and DEX7f9ba0 then update visible HP/AC from raw choices.
const Skills=preload("res://systems/native_data/pregame_skills.gd")
const Values=preload("res://systems/native_data/character_record_values.gd")
const KEYS=["Str","Dex","Con","Int","Wis","Cha"]
static func effective(source: Dictionary,tables: Dictionary) -> Dictionary:
	var missing: Array=[]
	for name in ["classes","racialtypes","ruleset"]:
		if not tables.has(name): missing.append(name)
	var id:=int(source.get("classId",-1)); var race:=int(source.get("race",-1)); var data:=Skills.row(tables,"classes",id)
	var gain_table:=Skills.table_name(data,"StatGainTable")
	if not gain_table.is_empty() and not tables.has(gain_table): missing.append(gain_table)
	if not missing.is_empty(): return {"ready":false,"dependencies":missing,"errors":[]}
	if id<0 or id>=(Skills.rows(tables,"classes").size()&255) or race<0 or race>=Skills.rows(tables,"racialtypes").size(): return {"ready":false,"dependencies":[],"errors":["Live creation class/race is unavailable."]}
	var gains:=Skills.class_gains({"classes":[{"id":id,"level":1}]},tables); var race_data:=Skills.row(tables,"racialtypes",race); var scores: Array=[]
	for at in 6: scores.append((int(source.get("abilities",{}).get(KEYS[at],0))+Values.signed8(Skills.number(race_data,KEYS[at]+"Adjust"))+int(gains[at]))&255)
	return {"ready":true,"dependencies":[],"errors":[],"scores":scores,"gains":gains}
static func initial_abilities(id: int,race: int,tables: Dictionary) -> Dictionary:
	var abilities: Dictionary={}
	for key in KEYS: abilities[key]=Values.cfg(tables,"CHARGEN_BASE_ABILITY_MIN",8)&255
	var input:={"classId":id,"race":race,"abilities":abilities}; var values:=effective(input,tables)
	if not values.ready: return values
	var data:=Skills.row(tables,"classes",id)
	if Skills.number(data,"SpellCaster")!=0:
		var ability: int=KEYS.map(func(key):return str(key).to_upper()).find(str(Values.field(data,"SpellcastingAbil")).to_upper())
		if ability>=0:
			# Original sets the effective primary score to MIN_PRIMARY even when
			# a racial/class increase already exceeds it; it does not max(0,delta).
			var adjustment:=Values.signed8(Skills.number(Skills.row(tables,"racialtypes",race),KEYS[ability]+"Adjust"))+int(values.gains[ability])
			abilities[KEYS[ability]]=(Values.cfg(tables,"CHARGEN_BASE_ABILITY_MIN_PRIMARY",11)-adjustment)&255
	return {"ready":true,"abilities":abilities}
static func starting_hitdie(id: int,feats: Array,tables: Dictionary) -> Variant:
	if not tables.has("classes") or id<0 or id>=(Skills.rows(tables,"classes").size()&255): return null
	if id==37:
		for option in [[0x3db,"FEAT_DRAGON_HD12",12],[0x414,"FEAT_DRAGON_HD10",10],[0x413,"FEAT_DRAGON_HD8",8],[0x412,"FEAT_DRAGON_HD6",6]]:
			if feats.has(option[0]):
				if not tables.has("ruleset"): return null
				return Values.cfg(tables,str(option[1]),int(option[2]))&255
	return Skills.number(Skills.row(tables,"classes",id),"HitDie")&255
static func project(source: Dictionary,tables: Dictionary,base_hp: Variant) -> Dictionary:
	var values:=effective(source,tables)
	if not values.ready: return values
	if base_hp==null: return {"ready":false,"dependencies":[],"errors":["Live creation hit-die cache has not been committed."]}
	var dexterity: Variant=Values.modifier(int(values.scores[1]),tables); var constitution: Variant=Values.modifier(int(values.scores[2]),tables)
	if dexterity==null or constitution==null: return {"ready":false,"dependencies":[],"errors":["Live creation ability-modifier rules are invalid."]}
	var hp:=maxi(1,int(base_hp)+int(constitution))
	return {"ready":true,"dependencies":[],"errors":[],"scores":values.scores,"fields":{"currentHP":hp,"temporaryHP":0,"maximumHP":hp,"armorBase":10+Values.signed8(int(dexterity)+Values.signed8(int(source.get("dexterityAdjustment",0)))),"armorModeBonus":0}}
