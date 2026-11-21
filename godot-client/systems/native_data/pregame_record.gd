extends RefCounted
# Original CNWCCreatureStats BIC import1407f7e20 and the numeric/heading
# portion of CCharPageChar::SetData1409bbfc0. Display projection only.
# Full combat detail text, disclosure variants and list gestures remain open.
const Skills=preload("res://systems/native_data/pregame_skills.gd")
const Values=preload("res://systems/native_data/character_record_values.gd")
const Details=preload("res://systems/native_data/pregame_record_details.gd")
static func signed16(value: int) -> int:
	value&=65535
	return value-65536 if value>=32768 else value
static func source(document: Dictionary,stats: Dictionary) -> Dictionary:
	var root: Dictionary=document.root; var types: Dictionary=document.field_types.get(0,{})
	var result:={"stats":stats,"armorClass":0,"maximumHP":0,"currentHP":0,"experience":0,"goodEvil":85,"lawChaos":15,"subrace":"","native_only":true}
	for pair in [["ArmorClass","armorClass"],["MaxHitPoints","maximumHP"]]:
		if types.get(pair[0])==3: result[pair[1]]=signed16(int(root[pair[0]]))
	# Original import defaults PregameCurrent to MaxHitPoints, then renders
	# current plus the constructor's zero temporary HP. CurrentHitPoints and
	# HitPoints are separate fields and do not supply these preview labels.
	result.currentHP=signed16(int(root.PregameCurrent)) if types.get("PregameCurrent")==3 else result.maximumHP
	if types.get("Experience")==4: result.experience=int(root.Experience)&0xffffffff
	for pair in [["GoodEvil","goodEvil"],["LawfulChaotic","lawChaos"]]:
		if types.get(pair[0])==0: result[pair[1]]=mini(100,int(root[pair[0]])&255)
	if types.get("Subrace")==10: result.subrace=str(root.Subrace)
	result.merge(Details.source(document))
	return result
static func compute(source_data: Dictionary,tables: Dictionary) -> Dictionary:
	var projection:=Skills.compute(source_data.get("stats",{}),tables)
	var pending: Array=projection.get("dependencies",[]).duplicate()
	if not tables.has("exptable"): pending.append("exptable")
	if not pending.is_empty(): return {"ready":false,"dependencies":pending,"errors":[]}
	if not projection.get("ready",false): return {"ready":false,"dependencies":[],"errors":projection.get("errors",[])}
	var details:=Details.compute(source_data,tables,projection.classes)
	if not details.ready: return {"ready":false,"dependencies":details.dependencies,"errors":[]}
	var level:=0
	for item in projection.classes: level=(level+int(item.level))&255
	var next_value: Variant=null
	if level<40:
		var raw: Variant=Values.field(Skills.row(tables,"exptable",level),"XP")
		if raw==null or str(raw) in ["","****"]: return {"ready":false,"dependencies":[],"errors":["The active experience table has no next-level value."]}
		next_value=Values.signed32(Skills.number({"XP":raw},"XP"))
	var law:=int(source_data.get("lawChaos",15)); var good:=int(source_data.get("goodEvil",85))
	var law_index:=2 if law<31 else 0 if law>69 else 1
	var good_index:=2 if good<31 else 0 if good>69 else 1
	return {"ready":true,"dependencies":[],"errors":[],"abilities":Values.abilities(projection.scores,[0,0,0,0,0,0],0,tables),"classes":projection.classes,"race":int(source_data.get("stats",{}).get("race",6)),"subrace":str(source_data.get("subrace","")),"alignmentRef":112+law_index*3+good_index,"armorClass":signed16(int(source_data.get("armorClass",0))),"currentHP":signed16(int(source_data.get("currentHP",0))),"maximumHP":signed16(int(source_data.get("maximumHP",0))),"experience":Values.signed32(int(source_data.get("experience",0))),"nextExperience":next_value,"nextMaximumRef":0x285f if level>=40 else -1,"details":details.entries,"native_only":true,"fullRecordParity":false}
