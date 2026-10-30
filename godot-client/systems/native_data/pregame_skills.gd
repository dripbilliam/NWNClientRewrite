extends RefCounted
# Mode-zero preview data only: CNWCCreatureStats BIC import1407f7e20,
# ability gains1407f1110, skill values1407fadc0 and original eligibility mask.
# This does not calculate authoritative in-world skill checks/effect bonuses.
const Game=preload("res://systems/native_data/game_ui_rules.gd")
const Values=preload("res://systems/native_data/character_record_values.gd")
const KEYS=["Str","Dex","Con","Int","Wis","Cha"]
static func types(document: Dictionary,node: Dictionary) -> Dictionary:
	for id in document.records:
		if is_same(document.records[id],node): return document.field_types.get(id,{})
	return {}
static func source(document: Dictionary) -> Dictionary:
	var root: Dictionary=document.root; var root_types: Dictionary=document.field_types.get(0,{})
	var result:={"abilities":{},"race":6,"classes":[{"id":4,"level":1}],"ranks":[],"dexterityAdjustment":0,"lostAbilities":false,"native_only":true}
	for key in KEYS: result.abilities[key]=int(root.get(key,0))&255 if root_types.get(key)==0 else 0
	if root_types.get("Race")==0: result.race=int(root.Race)&255
	if root_types.get("ClassList")==15 and not root.ClassList.is_empty() and root.ClassList.size()&255!=0:
		result.classes=[]
		for index in mini(8,root.ClassList.size()&255):
			var item: Dictionary=root.ClassList[index]; var item_types:=types(document,item); var id:=4 if index==0 else 255; var level:=1 if index==0 else 0
			if item_types.get("Class")==5 and int(item.Class)!=-1: id=int(item.Class)&255
			if item_types.get("ClassLevel")==3 and int(item.ClassLevel)&255!=0: level=int(item.ClassLevel)&255
			result.classes.append({"id":id,"level":level})
		while not result.classes.is_empty() and result.classes[-1].id==255: result.classes.pop_back()
	if root_types.get("SkillList")==15:
		for index in mini(255,root.SkillList.size()&65535):
			var item: Dictionary=root.SkillList[index]; var item_types:=types(document,item)
			result.ranks.append(int(item.Rank)&255 if item_types.get("Rank")==0 else 0)
	return result
static func rows(tables: Dictionary,name: String) -> Array: return tables.get(name.to_lower(),{}).get("orderedRows",[])
static func row(tables: Dictionary,name: String,id: int) -> Dictionary:
	var list:=rows(tables,name); return list[id] if id>=0 and id<list.size() else {}
static func number(data: Dictionary,key: String,fallback: int=0) -> int: return Game.number(Game.cell(data,key),fallback)
static func table_name(data: Dictionary,key: String) -> String:
	var value:=str(Game.cell(data,key,"")); return "" if value in ["","****"] else value.to_lower()
static func dependencies(source_data: Dictionary,tables: Dictionary) -> Array:
	var names: Array=[]
	for name in ["classes","racialtypes","skills","ruleset"]:
		if not tables.has(name): names.append(name)
	for item in source_data.get("classes",[]).slice(0,8):
		var id:=int(item.id)&255; var data:=row(tables,"classes",id if id<(rows(tables,"classes").size()&255) else 0)
		for field in ["SkillsTable","StatGainTable"]:
			var name:=table_name(data,field)
			if not name.is_empty() and not tables.has(name) and not names.has(name): names.append(name)
	return names
static func class_gains(source_data: Dictionary,tables: Dictionary) -> Array:
	var gains: Array=[0,0,0,0,0,0]
	for item in source_data.get("classes",[]).slice(0,8):
		var id:=int(item.id)&255
		if id>=(rows(tables,"classes").size()&255): continue
		var table:=table_name(row(tables,"classes",id),"StatGainTable"); var level:=int(item.level)&255
		if level>60: return [] # Original storage is60 rows; do not emulate invalid memory reads.
		for ability in 6:
			var sum:=0
			for at in level: sum=Values.signed8(sum+Values.signed8(number(row(tables,table,at),KEYS[ability])))
			gains[ability]+=sum
	for ability in 6: gains[ability]=clampi(int(gains[ability]),-128,127)
	return gains
static func compute(source_data: Dictionary,tables: Dictionary) -> Dictionary:
	var pending:=dependencies(source_data,tables)
	if not pending.is_empty(): return {"ready":false,"dependencies":pending,"errors":[]}
	var gains:=class_gains(source_data,tables)
	if gains.is_empty(): return {"ready":false,"dependencies":[],"errors":["Pregame class stat-gain level exceeds original table storage."]}
	var scores: Array=[]; var race:=int(source_data.get("race",6))&255; var race_data:=row(tables,"racialtypes",race)
	for ability in 6:
		var score:=Values.cfg(tables,"CHARGEN_BASE_ABILITY_MIN",8)&255
		if race<(rows(tables,"racialtypes").size()&255): score=(int(source_data.get("abilities",{}).get(KEYS[ability],0))+Values.signed8(number(race_data,KEYS[ability]+"Adjust"))+int(gains[ability]))&255
		scores.append(score)
	var count:=rows(tables,"skills").size()&255; var values: Array=[]; var mask:=0; var classes: Array=source_data.get("classes",[]).slice(0,8).duplicate(true); var errors: Array=[]
	for id in count:
		var data:=row(tables,"skills",id); var rank:=int(source_data.ranks[id])&255 if id<source_data.get("ranks",[]).size() else 0
		var untrained:=number(data,"Untrained")!=0; var value:=0
		if untrained or rank!=0:
			# The original loader compares exact uppercase3-letter strings, then
			# defaults unknown KeyAbility to STR rather than guessing another key.
			var ability: int=["STR","DEX","CON","INT","WIS","CHA"].find(str(Game.cell(data,"KeyAbility",""))); ability=maxi(0,ability)
			var modifier: Variant=Values.modifier(int(scores[ability]),tables)
			if modifier==null: errors.append("Pregame ability modifier rules are invalid.")
			else: value=Values.signed8(rank+int(modifier)+(Values.signed8(int(source_data.get("dexterityAdjustment",0))) if ability==1 else 0))
		values.append(value)
		if not untrained:
			if Values.signed8(rank)>0: mask|=1<<(id&31)
		else:
			for item in classes:
				var class_id:=int(item.id)&255
				if class_id>=(rows(tables,"classes").size()&255): item.id=0; continue
				var usable:=number(data,"AllClassesCanUse")!=0
				for entry in rows(tables,table_name(row(tables,"classes",class_id),"SkillsTable")):
					if number(entry,"SkillIndex",-1)&65535==id: usable=true; break
				if usable: mask|=1<<(id&31)
	var admitted: Array=[]
	for id in count:
		if mask&(1<<(id&31)): admitted.append({"id":id,"value":values[id],"lostAbilities":bool(source_data.get("lostAbilities",false))})
	return {"ready":errors.is_empty(),"dependencies":[],"errors":errors,"entries":admitted,"scores":scores,"classGains":gains,"values":values,"mask":mask&0xffffffff,"classes":classes,"native_only":true,"fullGameplaySkillParity":false}
