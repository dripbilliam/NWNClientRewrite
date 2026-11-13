extends RefCounted
# CCharPageSpells::SetData1409c1810 (live draft, not BIC import1409c1b50).
# Known lists already have their class/level placement. Unrestricted classes
# contribute a highest-castable-level summary, never individual known rows.
const Spells=preload("res://systems/native_data/pregame_spells.gd")
const Skills=preload("res://systems/native_data/pregame_skills.gd")
const Values=preload("res://systems/native_data/character_record_values.gd")
static func compute(stats: Dictionary,books: Array,tables: Dictionary) -> Dictionary:
	var pending: Array=[]
	for name in ["classes","racialtypes","ruleset","spells"]:
		if not tables.has(name): pending.append(name)
	var classes: Array=stats.get("classes",[])
	for item in classes:
		var data:=Skills.row(tables,"classes",int(item.id))
		for field in ["StatGainTable","SpellGainTable"]:
			var name:=Skills.table_name(data,field)
			if not name.is_empty() and not tables.has(name) and not pending.has(name): pending.append(name)
	if not pending.is_empty(): return {"ready":false,"dependencies":pending,"errors":[],"entries":[]}
	var invalid:=classes.size()>8 or books.size()!=classes.size()
	for item in classes:
		invalid=invalid or int(item.id)<0 or int(item.id)>254 or int(item.id)>=(Skills.rows(tables,"classes").size()&255) or int(item.level)<1 or int(item.level)>60
	var race:=int(stats.get("race",-1))
	if invalid or race<0 or race>=(Skills.rows(tables,"racialtypes").size()&255): return {"ready":false,"dependencies":[],"errors":["Live summary class/race storage is unavailable."],"entries":[]}
	var gains:=Skills.class_gains(stats,tables); var scores: Array=[]
	for ability in 6: scores.append((int(stats.get("abilities",{}).get(Skills.KEYS[ability],0))+Values.signed8(Skills.number(Skills.row(tables,"racialtypes",race),Skills.KEYS[ability]+"Adjust"))+int(gains[ability]))&255)
	var entries: Array=[]; var minimums: Array=[]; var counts: Array=[]; var errors: Array=[]
	for index in classes.size():
		var data:=Skills.row(tables,"classes",int(classes[index].id)); var met: Array=[]; var uses: Array=[]; var top:=-1
		for level in 10:
			met.append(Spells.minimum(stats,classes,gains,tables,index,level))
			var value:=Spells.slots(stats,books,classes,gains,scores,tables,index,level); uses.append(value)
			if value<0: errors.append("Original spell modifier rules are invalid.")
			if met[-1] and value>0: top=level
		minimums.append(met); counts.append(uses)
		if Skills.number(data,"SpellbookRestricted")==0 and top>0: entries.append({"id":-1,"classIndex":index,"level":top,"summary":true,"nameRef":Spells.SUMMARY_DRUID[top] if int(classes[index].id)==3 else Spells.SUMMARY_CLERIC[top],"icon":Spells.SUMMARY_ICONS[top]})
	for index in classes.size():
		if Skills.number(Skills.row(tables,"classes",int(classes[index].id)),"SpellbookRestricted")==0: continue
		var levels: Array=books[index].get("levels",[])
		for level in mini(10,levels.size()):
			if levels[level].size()>255: return {"ready":false,"dependencies":[],"errors":["Original live spell-row index exceeds its supported width."],"entries":[]}
			for raw_id in levels[level]:
				var id:=int(raw_id)&65535
				if not Skills.row(tables,"spells",id).is_empty(): entries.append({"id":id,"classIndex":index,"level":level,"summary":false})
	return {"ready":errors.is_empty(),"dependencies":[],"errors":errors,"entries":entries if errors.is_empty() else [],"minimums":minimums,"slots":counts,"native_only":true,"fullGameplaySpellParity":false}
