extends RefCounted
# Original creation skill allocation7f7a00/ee3e0 and point budget7ec0c0.
# Original BYTE/WORD widths matter independently of the displayed skill value.
const Game=preload("res://systems/native_data/game_ui_rules.gd")
const Values=preload("res://systems/native_data/character_record_values.gd")
const KEYS=["Str","Dex","Con","Int","Wis","Cha"]
static func word(value: int) -> int:return (value&65535)-65536 if value&32768 else value&65535
static func rows(tables: Dictionary,name: String) -> Array:return tables.get(name.to_lower(),{}).get("orderedRows",[])
static func row(tables: Dictionary,name: String,index: int) -> Dictionary:
	var entries:=rows(tables,name);return entries[index] if index>=0 and index<entries.size() else {}
static func number(data: Dictionary,key: String,fallback: int=0) -> int:return Game.number(Game.cell(data,key),fallback)
static func rule(tables: Dictionary,class_id: int,id: int,level: int=1) -> Dictionary:
	var data:=row(tables,"skills",id);var found:=false;var class_skill:=false
	if id<0 or id>=(rows(tables,"skills").size()&255):return {"allowed":false,"classSkill":false,"cost":2,"max":0}
	var cls:=row(tables,"classes",class_id);var name:=str(Game.cell(cls,"SkillsTable",""))
	for entry in rows(tables,name):
		if number(entry,"SkillIndex",-1)&65535==id:found=true;class_skill=number(entry,"ClassSkill")!=0;break
	var maximum: int=(Values.cfg(tables,"CHARGEN_SKILL_MAX_LEVEL_1_BONUS",3)+(level&255))&255
	return {"allowed":number(data,"AllClassesCanUse")!=0 or found,"classSkill":class_skill,"cost":1 if class_skill else 2,"max":maximum if class_skill else maximum>>1}
static func budget(tables: Dictionary,class_id: int,race_id: int,scores: Array,dexterity_adjustment: int=0,existing: int=0,level: int=1) -> Variant:
	if scores.size()!=6 or row(tables,"classes",class_id).is_empty() or row(tables,"racialtypes",race_id).is_empty():return null
	var race:=row(tables,"racialtypes",race_id);var table: Dictionary=tables.get("racialtypes",{});var ability:=3
	var column_present: bool=table.get("columns",[]).any(func(name):return str(name).to_lower()=="skillpointmodifierability") or Game.cell(race,"SkillPointModifierAbility")!=null
	if column_present:
		ability=KEYS.map(func(key):return str(key).to_lower()).find(str(Game.cell(race,"SkillPointModifierAbility","")).to_lower())
	var modifier:=0
	if ability>=0 and ability<6:
		var value: Variant=Values.modifier(int(scores[ability])&255,tables)
		if value==null:return null
		modifier=Values.signed8(int(value))
		if ability==1:modifier=Values.signed8(modifier+Values.signed8(dexterity_adjustment))
	var points:=maxi(1,(number(row(tables,"classes",class_id),"SkillPointBase")&255)+modifier)
	var extra:=word(number(race,"ExtraSkillPointsPerLevel"));var multiplier:=word(number(race,"FirstLevelSkillPointsMultiplier",4)) if level&255==1 else 1
	return word(existing+(points+extra)*multiplier)
static func move(tables: Dictionary,class_id: int,id: int,raw: int,points: int,baseline: int,direction: int,level: int=1) -> Dictionary:
	var info:=rule(tables,class_id,id,level);var rank:=raw&255;var remaining:=word(points);var changed:=false
	if info.allowed:
		if direction==1:
			var affordable: bool=remaining!=0 if info.classSkill else (remaining&65535)>=2
			if affordable and Values.signed8(rank)<int(info.max):rank=(rank+1)&255;remaining=word(remaining-int(info.cost));changed=true
		elif direction==-1 and Values.signed8(rank)!=(baseline&255):rank=(rank-1)&255;remaining=word(remaining+int(info.cost));changed=true
	return {"rank":rank,"points":remaining,"changed":changed}
