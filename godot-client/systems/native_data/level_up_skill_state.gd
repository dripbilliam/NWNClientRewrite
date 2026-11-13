extends RefCounted
# Original Skills(mode1)9c3040 retains entry ranks/pointWORD separately. These
# private choices never replace the received actor's skills or point cache.
const Rules=preload("res://systems/native_data/creation_skill_rules.gd")
const Order=preload("res://systems/native_data/creation_skill_state.gd")
const Vitals=preload("res://systems/native_data/level_up_vitals.gd")
const Values=preload("res://systems/native_data/character_record_values.gd")
const Game=preload("res://systems/native_data/game_ui_rules.gd")
var source: Dictionary={}
var vitals: Dictionary={}
var baseline: Array=[]
var ranks: Array=[]
var points:=0
var initial_points:=0
var class_id:=-1
var level:=0
var resources_ready:=false
var failure:=""
var table_inputs: Dictionary={}
func current_tables(tables: Dictionary) -> bool:
	if not resources_ready:return false
	for name in table_inputs:
		if not tables.has(name) or not is_same(table_inputs[name],tables[name]):return false
	return true
func configure(snapshot: Dictionary,selected_class: int,ability: int,tables: Dictionary) -> bool:
	resources_ready=false;source={};baseline=[];ranks=[];vitals={};table_inputs={};failure="Received level-up skill storage is unavailable."
	vitals=Vitals.project(snapshot,selected_class,ability,tables)
	if not vitals.get("ready",false):failure=str(vitals.get("reason",failure));return false
	if not tables.has("skills") or not snapshot.get("skills") is Array or snapshot.skills.size()!=(Rules.rows(tables,"skills").size()&255) or not Vitals.Class.integer(snapshot.get("fieldDC6"),0,65535):return false
	for value in snapshot.skills:
		if not Vitals.Class.integer(value,-128,127):return false
	var missing: Array=[]
	var cls:=Rules.row(tables,"classes",selected_class);var name:=str(Game.cell(cls,"SkillsTable",""))
	if name not in ["","****"] and not tables.has(name.to_lower()):missing.append(name.to_lower())
	if not missing.is_empty():failure="Active class skill storage is unavailable.";return false
	var budget: Variant=Rules.budget(tables,selected_class,int(snapshot.race),vitals.scores,0,int(snapshot.fieldDC6),int(vitals.level))
	if budget==null:failure="Active level-up skill point rules are unavailable.";return false
	source=snapshot.duplicate(true);class_id=selected_class;level=int(vitals.level);points=int(budget);initial_points=points
	for value in snapshot.skills:baseline.append(int(value)&255)
	for key in ["classes","racialtypes","ruleset","skills"]:table_inputs[key]=tables[key]
	if name not in ["","****"]:table_inputs[name.to_lower()]=tables[name.to_lower()]
	for value in vitals.classes:
		var gain:=Vitals.Skills.table_name(Rules.row(tables,"classes",int(value.id)),"StatGainTable")
		if not gain.is_empty():table_inputs[gain]=tables[gain]
	ranks=baseline.duplicate();resources_ready=true;failure="";return true
func move(id: int,direction: int,tables: Dictionary) -> bool:
	if not current_tables(tables) or id<0 or id>=ranks.size():return false
	var next:=Rules.move(tables,class_id,id,int(ranks[id]),points,int(baseline[id]),direction,level)
	if not next.changed:return false
	ranks[id]=int(next.rank);points=int(next.points);return true
func reset_recommendation() -> void:
	if not resources_ready:return
	ranks=baseline.duplicate();points=initial_points
func recommend(ids: Array,tables: Dictionary) -> Dictionary:
	if not current_tables(tables):return {"ready":false,"reason":"Active level-up skill rules changed."}
	for id in ids:
		if not id is int or id<0 or id>=ranks.size():return {"ready":false,"reason":"A recommended skill has no verified native storage."}
	#7eb300 fills each listed skill before advancing, using the same original
	# BYTE rank/WORD points/total-level cost policy as manual mode1 arrows.
	for id in ids:
		if points==0:break
		while move(int(id),1,tables):pass
	return {"ready":true}
func changes() -> Array:
	var result: Array=[]
	for id in ranks.size():result.append((int(ranks[id])-int(baseline[id]))&255)
	return result
func compose(tables: Dictionary,text) -> Dictionary:
	var unavailable:={"ready":false,"entries":[],"details":{},"reason":failure}
	if not current_tables(tables):unavailable.reason="Active level-up skill rules changed or are unavailable.";return unavailable
	var entries: Array=[];var details: Dictionary={}
	for id in ranks.size():
		var data:=Rules.row(tables,"skills",id)
		if Rules.number(data,"HideFromLevelUp")!=0:continue
		var rule:=Rules.rule(tables,class_id,id,level);var title:=Rules.number(data,"Name",4294967295)&0xffffffff;var description:=Rules.number(data,"Description",4294967295)&0xffffffff
		var name: String=text.raw({"strRef":title})
		if rule.classSkill:name+=" "+text.raw({"strRef":52951})
		var icon:=str(Game.cell(data,"Icon","")).to_lower()
		if icon=="****":icon=""
		var entry:={"id":id,"name":name,"enabled":rule.allowed,"classSkill":rule.classSkill,"title":title,"description":description,"icon":icon}
		var position:=0
		while position<entries.size() and Order.compare(str(entries[position].name),name)<0:position+=1
		entries.insert(position,entry)
		var ability:=maxi(0,["STR","DEX","CON","INT","WIS","CHA"].find(str(Game.cell(data,"KeyAbility",""))))
		var modifier: int=vitals.modifiers[ability];var rank:=Values.signed8(int(ranks[id]));var trained: bool=Rules.number(data,"Untrained")!=0
		details[id]={"rank":rank,"modifier":modifier,"value":Values.signed8(rank+modifier) if trained or rank!=0 else 0,"cost":int(rule.cost),"maximum":int(rule.max)}
	return {"ready":true,"entries":entries,"details":details,"points":points,"classId":class_id}
