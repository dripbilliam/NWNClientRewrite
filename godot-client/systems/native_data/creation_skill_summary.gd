extends RefCounted
# Original live Skills cache: constructor/reset clear +E0, Skills OK9c8d10
# and package OK8e4620 commit its mask; rank writes7fa8b0 update +D0 only.
# Valid unbuffed creation stats share the verified arithmetic/mask algorithm
# with BIC import, but importing on every read would lose this lifecycle.
const Skills=preload("res://systems/native_data/pregame_skills.gd")
static func source(rules) -> Dictionary:
	var d: Dictionary=rules.draft; var ranks: Array=[]
	for id in (rules.rows("skills").size()&255): ranks.append(int(d.skills.get(id,0))&255)
	return {"abilities":d.abilities.duplicate(),"race":int(d.raceId),"classes":[{"id":int(d.classId),"level":1}],"ranks":ranks,"dexterityAdjustment":0,"lostAbilities":false,"native_only":true}
static func calculate(stats: Dictionary,tables: Dictionary) -> Dictionary:
	var pending:=Skills.dependencies(stats,tables)
	if not pending.is_empty(): return {"ready":false,"dependencies":pending,"errors":[],"entries":[]}
	var classes: Array=stats.get("classes",[]); var invalid:=classes.size()>8
	for item in classes: invalid=invalid or int(item.id)<0 or int(item.id)>=(Skills.rows(tables,"classes").size()&255) or int(item.level)<0 or int(item.level)>60
	var race:=int(stats.get("race",-1))
	if invalid or race<0 or race>=(Skills.rows(tables,"racialtypes").size()&255): return {"ready":false,"dependencies":[],"errors":["Original live skill class/race storage is unavailable."],"entries":[]}
	return Skills.compute(stats,tables)
static func project(stats: Dictionary,tables: Dictionary,committed_mask: int) -> Dictionary:
	var result:=calculate(stats,tables)
	if not result.ready: return result
	result.mask=committed_mask&0xffffffff; result.entries=[]
	for id in result["values"].size():
		if result.mask&(1<<(id&31)): result.entries.append({"id":id,"value":result["values"][id],"lostAbilities":bool(stats.get("lostAbilities",false))})
	result.fullCreationSkillParity=false
	return result
