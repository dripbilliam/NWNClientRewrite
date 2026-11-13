extends RefCounted
const Spells=preload("res://systems/native_data/live_summary_spells.gd")
const Entries=preload("res://systems/native_data/character_record_entries.gd")
static func compose(rules,ui_rules) -> Dictionary:
	var d: Dictionary=rules.draft; var result: Dictionary={}
	var primary: Array=rules.granted_feats()
	for feat in d.feats: primary.append(int(feat.id))
	var feats: Array=ui_rules.record_feat_entries(primary)
	result["2"]={"ready":ui_rules.record_errors.is_empty(),"entries":feats if ui_rules.record_errors.is_empty() else [],"errors":ui_rules.record_errors.duplicate()}
	var stats:={"abilities":d.abilities.duplicate(),"race":int(d.raceId),"classes":[{"id":int(d.classId),"level":1}]}
	var levels: Array=[]
	for level in 10: levels.append(d.known.get(level,[]).duplicate())
	var spells:=Spells.compute(stats,[{"school":int(d.school),"levels":levels}],rules.tables)
	if spells.ready:
		for entry in spells.entries:
			if entry.summary: entry.name=ui_rules.text.raw({"strRef":int(entry.nameRef)}); entry.description={}
			else:
				var data: Dictionary=ui_rules.row("spells",int(entry.id)); entry.name=ui_rules.text.raw({"strRef":ui_rules.number(ui_rules.cell(data,"Name"),4294967295)}); entry.icon=ui_rules.icon("spells",int(entry.id)); entry.description=ui_rules.description("spells",int(entry.id))
		spells.entries=Entries.ordered(spells.entries)
	result["3"]=spells
	var skill_data=preload("res://systems/native_data/creation_skill_summary.gd")
	var skills: Dictionary=skill_data.project(skill_data.source(rules),rules.tables,rules.skill_summary_mask)
	if skills.ready:
		for entry in skills.entries:
			entry.name=ui_rules.title("skills",int(entry.id)); entry.icon=ui_rules.icon("skills",int(entry.id)); entry.description=ui_rules.description("skills",int(entry.id))
		skills.entries=Entries.ordered(skills.entries)
	result["1"]=skills
	return result
