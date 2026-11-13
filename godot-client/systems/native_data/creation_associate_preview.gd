extends RefCounted
# 88ad50 imports a private UTC using the same7f7e20 stats loader as BIC.
# Reuse the existing pregame projectors; no live creature or player stats.
const Preview=preload("res://systems/native_data/character_preview.gd")
const Skills=preload("res://systems/native_data/pregame_skills.gd")
const Spells=preload("res://systems/native_data/pregame_spells.gd")
const Record=preload("res://systems/native_data/pregame_record.gd")
const Values=preload("res://systems/native_data/character_record_values.gd")
static func source(document: Dictionary) -> Dictionary:
	if document.get("type")!="UTC " or not document.get("root") is Dictionary:return {"ready":false,"reason":"The selected associate template is not a native UTC."}
	var display:=Preview.project(document.root)
	if display.has("error"):return {"ready":false,"reason":str(display.error)}
	var stats:=Skills.source(document);display.skillSource=stats;display.recordSource=Record.source(document,stats);display.spellSource=Spells.source(document,stats)
	return {"ready":true,"value":display}
static func compose(display: Dictionary,projection: Dictionary,text,rules,revision: int) -> Dictionary:
	var model: Dictionary=projection.get("record",{})
	if not model.get("ready",false):return {"ready":false,"dependencies":projection.get("dependencies",[])}
	var labels:={"title":{"text":text.raw({"strRef":0xf182})+", "+text.name(display,-1)}}
	var race: String=model.subrace if not str(model.subrace).is_empty() else rules.title("racialtypes",int(model.race));var classes: Array=[]
	for item in model.classes:classes.append(rules.title("classes",int(item.id))+" ("+Values.integer_text(item.level)+")")
	labels.classes={"text":race+", "+text.raw({"strRef":model.alignmentRef})+"\n"+"\n\n".join(classes)+"\n"}
	for ability in model.abilities:
		var key:=str(ability.key).to_lower();labels[key+"stat"]={"text":Values.integer_text(ability.score)};labels[key+"mod"]={"text":Values.integer_text(ability.modifier)}
	for pair in [["lac",321],["lhp",320]]:labels[pair[0]]={"text":text.raw({"strRef":pair[1]})}
	labels.hitpoints={"text":Values.integer_text(model.currentHP)+"/"+Values.integer_text(model.maximumHP)};labels.armorclass={"text":Values.integer_text(model.armorClass)}
	labels.experience={"text":text.raw({"strRef":314})+": "+Values.integer_text(model.experience)};labels.nextlevel={"text":text.raw({"strRef":315})+": "+(text.raw({"strRef":model.nextMaximumRef}) if model.nextMaximumRef>=0 else Values.integer_text(model.nextExperience))}
	var lists: Dictionary={}
	for pair in [["1","skills","skills"],["3","spells","spells"]]:
		var page: Dictionary=projection.get(pair[1],{});var entries: Array=[]
		if page.get("ready",false):
			for raw in page.get("entries",[]):
				var entry: Dictionary=raw.duplicate(true)
				if entry.get("summary",false):entry.name=text.raw({"strRef":entry.nameRef});entry.description={}
				else:entry.name=rules.title(pair[2],int(entry.id));entry.icon=rules.icon(pair[2],int(entry.id));entry.description=rules.description(pair[2],int(entry.id))
				entries.append(entry)
		lists[pair[0]]={"entries":preload("res://systems/native_data/character_record_entries.gd").ordered(entries)}
	var feats: Array=rules.record_feat_entries(display.get("feats",[]));lists["2"]={"entries":feats if rules.record_errors.is_empty() else []}
	return {"ready":true,"labels":labels,"portrait":rules.portrait({"replicated":display},4),"lists":lists,"revision":revision}
