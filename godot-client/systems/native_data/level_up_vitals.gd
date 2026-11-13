extends RefCounted
# Private level-up ability projection, not the live creature's effect cache.
# Original837dc0 constructs new stats;837f60 copies raw76..7b through the
# six setters. Constructor bonus7d..82/Dex7c remain zero in that clone.
const Skills=preload("res://systems/native_data/pregame_skills.gd")
const Values=preload("res://systems/native_data/character_record_values.gd")
const Class=preload("res://systems/native_data/level_up_class_state.gd")
const KEYS=["Str","Dex","Con","Int","Wis","Cha"]
static func pending(reason: String) -> Dictionary:return {"ready":false,"reason":reason}
static func next_classes(snapshot: Dictionary,class_id: int) -> Dictionary:
	if not snapshot.get("classes") is Array or snapshot.classes.is_empty() or snapshot.classes.size()>8:return pending("Received level-up classes are unavailable.")
	var classes: Array=[];var current:=-1;var seen: Dictionary={};var total:=0
	for value in snapshot.classes:
		if not value is Dictionary or not Class.integer(value.get("id"),0,254) or not Class.integer(value.get("level"),1,254) or seen.has(int(value.id)):return pending("Received level-up class storage is malformed.")
		seen[int(value.id)]=true;total+=int(value.level);classes.append(value.duplicate(true))
		if int(value.id)==class_id:current=classes.size()-1;classes[-1].level=int(value.level)+1
	if current<0:
		if classes.size()==8:return pending("Original class storage is full.")
		current=classes.size();classes.append({"id":class_id,"level":1})
	return {"ready":true,"classes":classes,"current":current,"level":total+1}
static func project(snapshot: Dictionary,class_id: int,selected_ability: int,tables: Dictionary) -> Dictionary:
	if not tables.has_all(["classes","racialtypes","ruleset"]) or class_id<0 or class_id>=(Skills.rows(tables,"classes").size()&255):return pending("Active level-up class rules are unavailable.")
	if not Class.integer(snapshot.get("race"),0,254) or int(snapshot.race)>=Skills.rows(tables,"racialtypes").size() or not snapshot.get("baseAbilities") is Array or snapshot.baseAbilities.size()!=6:return pending("Received raw level-up abilities/race are unavailable.")
	for value in snapshot.baseAbilities:
		if not Class.integer(value,0,255):return pending("Received raw level-up ability is malformed.")
	if selected_ability< -1 or selected_ability>5:return pending("Private level-up ability choice is malformed.")
	var advanced:=next_classes(snapshot,class_id)
	if not advanced.ready:return advanced
	var source:={"classes":advanced.classes};var missing: Array=[]
	for cls in advanced.classes:
		var name:=Skills.table_name(Skills.row(tables,"classes",int(cls.id)),"StatGainTable")
		if not name.is_empty() and not tables.has(name):missing.append(name)
		if int(cls.id)>=(Skills.rows(tables,"classes").size()&255):return pending("An owned class is absent from the active physical table.")
	if not missing.is_empty():return {"ready":false,"reason":"Active class ability-gain storage is unavailable.","dependencies":missing}
	var gains:=Skills.class_gains(source,tables)
	if gains.size()!=6:return pending("Class level exceeds original ability-gain storage.")
	var raw: Array=[];var racial: Array=[];var scores: Array=[];var modifiers: Array=[]
	var race:=Skills.row(tables,"racialtypes",int(snapshot.race))
	for index in 6:
		raw.append((int(snapshot.baseAbilities[index])+int(selected_ability==index))&255)
		racial.append(Values.signed8(Skills.number(race,KEYS[index]+"Adjust")))
		scores.append((int(raw[index])+int(racial[index])+int(gains[index]))&255)
		var value: Variant=Values.modifier(int(scores[index]),tables)
		if value==null:return pending("Active ability-modifier rules are unavailable.")
		modifiers.append(Values.signed8(int(value)))
	return {"ready":true,"raw":raw,"racial":racial,"gains":gains,"scores":scores,"modifiers":modifiers,"points":1 if selected_ability<0 else 0,"selectedAbility":selected_ability,"classes":advanced.classes,"current":advanced.current,"level":advanced.level}
