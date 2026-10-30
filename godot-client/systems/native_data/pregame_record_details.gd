extends RefCounted
# Original pregame Character SetData1409bbfc0, not in-world combat calculation.
const Skills=preload("res://systems/native_data/pregame_skills.gd")
const Values=preload("res://systems/native_data/character_record_values.gd")
static func source(document: Dictionary) -> Dictionary:
	var root: Dictionary=document.root; var types: Dictionary=document.field_types.get(0,{})
	var saves: Array=[]; var combat: Array=[0,0,0]
	for key in ["FortSaveThrow","RefSaveThrow","WillSaveThrow"]: saves.append(Values.signed8(int(root[key])) if types.get(key)==1 else 0)
	if types.get("CombatInfo")==14 and root.get("CombatInfo") is Dictionary:
		var info: Dictionary=root.CombatInfo; var info_types:=Skills.types(document,info)
		for at in 3:
			var key: String=["SpellResistance","ArcaneSpellFail","ArmorCheckPen"][at]
			if info_types.get(key)==0: combat[at]=int(info[key])&255
	return {"savingThrows":saves,"combatPreview":combat}
static func compute(source_data: Dictionary,tables: Dictionary,classes: Array) -> Dictionary:
	if not tables.has("classes"): return {"ready":false,"dependencies":["classes"],"entries":[]}
	var pending: Array=[]; var attack:=0; var class_count:=Skills.rows(tables,"classes").size()&255
	for item in classes.slice(0,8):
		var id:=int(item.id)&255; var level:=int(item.level)&255
		if id>=class_count: continue
		var name:=Skills.table_name(Skills.row(tables,"classes",id),"AttackBonusTable")
		if not name.is_empty() and not tables.has(name):
			if not pending.has(name): pending.append(name)
			continue
		if level>=1 and level<=60: attack=Values.signed8(attack+(Skills.number(Skills.row(tables,name,level-1),"BAB")&255))
	if not pending.is_empty(): return {"ready":false,"dependencies":pending,"entries":[]}
	var entries: Array=[]; var saves: Array=source_data.get("savingThrows",[0,0,0]); var combat: Array=source_data.get("combatPreview",[0,0,0])
	for at in 3: entries.append({"labelRef":[317,318,319][at],"suffix":": ","parts":[{"text":str(Values.signed8(int(saves[at])))}]})
	# The cached BAB getter accumulates a byte; this caller zero-extends it for
	# ToString, unlike the sign-extended saving throws above.
	for pair in [[40424,str(attack&255)],[58349,str(int(combat[0])&255)],[58350,str(int(combat[1])&255)+"%"],[58351,"0" if int(combat[2])&255==0 else "-"+str(int(combat[2])&255)]]: entries.append({"labelRef":pair[0],"suffix":"","parts":[{"text":pair[1]}]})
	var law:=int(source_data.get("lawChaos",15)); var good:=int(source_data.get("goodEvil",85))
	var titles: Dictionary={Vector2i(100,100):10500,Vector2i(100,50):10502,Vector2i(100,0):10503,Vector2i(50,100):10504,Vector2i(50,50):10505,Vector2i(50,0):10506,Vector2i(0,100):10507,Vector2i(0,50):10508,Vector2i(0,0):10509}
	if titles.has(Vector2i(law,good)): entries.append({"labelRef":66198,"suffix":"","parts":[{"strRef":titles[Vector2i(law,good)]}]})
	entries.append({"labelRef":58348,"suffix":"","parts":[{"strRef":267 if law<31 else 268 if law>69 else 264},{"text":" ("+str(law)+"), "},{"strRef":266 if good<31 else 265 if good>69 else 264},{"text":" ("+str(good)+")"}]})
	# Original pregame SetData ends with the Effects heading. It does not import
	# or execute a BIC EffectList to fabricate active gameplay effects here.
	entries.append({"labelRef":58352,"suffix":"","parts":[]})
	return {"ready":true,"dependencies":[],"entries":entries}
static func markup(entries: Array,lookup: Callable) -> Array:
	var result: Array=[]; var gray: String="<c"+String.chr(170).repeat(3)+">"
	for row in entries:
		var line: String=gray+str(lookup.call(int(row.labelRef)))+str(row.suffix)+"</c>"
		for part in row.parts: line+=str(lookup.call(int(part.strRef))) if part.has("strRef") else str(part.get("text",""))
		result.append(line)
	return result
