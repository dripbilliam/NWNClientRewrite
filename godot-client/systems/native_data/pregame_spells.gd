extends RefCounted
# Original mode-zero CCharPageSpells1409c1b50. Display inspection only.
const Skills=preload("res://systems/native_data/pregame_skills.gd")
const Values=preload("res://systems/native_data/character_record_values.gd")
const Game=preload("res://systems/native_data/game_ui_rules.gd")
const SUMMARY_CLERIC=[0,68520,68522,68523,68524,68525,68526,68527,68529,68530]
const SUMMARY_DRUID=[0,68531,68532,68533,68534,68535,68536,68537,68538,68539]
const SUMMARY_ICONS=["ir_cantrips","ir_level1","ir_level2","ir_level3","ir_level4","ir_level5","ir_level6","ir_level789","ir_level789","ir_level789"]
static func source(document: Dictionary,stats: Dictionary) -> Dictionary:
	var result:={"stats":stats,"books":[],"native_only":true}; var root: Dictionary=document.root; var root_types: Dictionary=document.field_types.get(0,{})
	var classes: Array=root.get("ClassList",[]) if root_types.get("ClassList")==15 else []
	for index in stats.classes.size():
		var book:={"known":[],"school":0}
		if index<classes.size():
			var item: Dictionary=classes[index]; var item_types:=Skills.types(document,item)
			if item_types.get("School")==0: book.school=int(item.School)&255
			for level in 10:
				var key:="KnownList"+str(level)
				if item_types.get(key)!=15: continue
				if item[key].size()>65535: return {"error":"Original known-spell source count exceeds its supported index width."}
				for spell in item[key]:
					var spell_types:=Skills.types(document,spell)
					book.known.append(int(spell.Spell)&65535 if spell_types.get("Spell")==2 else 65535)
		result.books.append(book)
	return result
static func dependencies(source_data: Dictionary,tables: Dictionary) -> Array:
	var names:=Skills.dependencies(source_data.get("stats",{}),tables)
	if not tables.has("spells"): names.append("spells")
	for item in source_data.get("stats",{}).get("classes",[]).slice(0,8):
		var id:=int(item.id)&255; var data:=Skills.row(tables,"classes",id if id<(Skills.rows(tables,"classes").size()&255) else 0); var name:=Skills.table_name(data,"SpellGainTable")
		if not name.is_empty() and not tables.has(name) and not names.has(name): names.append(name)
	return names
static func primary(data: Dictionary) -> int: return ["STR","DEX","CON","INT","WIS","CHA"].find(str(Game.cell(data,"SpellcastingAbil","")))
static func is_caster(data: Dictionary) -> bool: return Skills.number(data,"SpellCaster")!=0
static func is_arcane(data: Dictionary) -> bool: return Skills.number(data,"Arcane")!=0
static func ability_met(stats: Dictionary,classes: Array,gains: Array,tables: Dictionary,index: int,level: int) -> bool:
	var data:=Skills.row(tables,"classes",int(classes[index].id)); var ability:=primary(data)
	if ability<0: return false
	var key: String=Skills.KEYS[ability]; var race:=Skills.row(tables,"racialtypes",int(stats.race)&255)
	var score:=maxi(3,Values.signed8(int(stats.abilities.get(key,0)))+Values.signed8(Skills.number(race,key+"Adjust"))+int(gains[ability]))&255
	return level-1+Values.cfg(tables,"CHARGEN_BASE_ABILITY_MIN_PRIMARY",11)<=score
static func minimum(stats: Dictionary,classes: Array,gains: Array,tables: Dictionary,index: int,level: int) -> bool:
	return is_caster(Skills.row(tables,"classes",int(classes[index].id))) and ability_met(stats,classes,gains,tables,index,level)
static func prestige_levels(classes: Array,tables: Dictionary,index: int) -> int:
	var target:=Skills.row(tables,"classes",int(classes[index].id)); var bonus:=0
	for at in classes.size():
		if at==index: continue
		var other:=Skills.row(tables,"classes",int(classes[at].id))
		if is_caster(other): continue
		var divisor:=Skills.number(other,"ArcSpellLvlMod" if is_arcane(target) else "DivSpellLvlMod")&255
		if divisor==0: continue
		for rival in classes.size():
			if rival==at or rival==index: continue
			var rival_data:=Skills.row(tables,"classes",int(classes[rival].id))
			if not is_caster(rival_data) or is_arcane(rival_data)!=is_arcane(target): continue
			if int(classes[rival].level)>int(classes[index].level) or int(classes[rival].level)==int(classes[index].level) and rival>index: divisor=0
		if divisor>0: bonus=Values.signed8(bonus+int((int(classes[at].level)-1+divisor)/divisor))
	return bonus
static func slots(stats: Dictionary,books: Array,classes: Array,gains: Array,scores: Array,tables: Dictionary,index: int,level: int) -> int:
	if not ability_met(stats,classes,gains,tables,index,level): return 0
	var data:=Skills.row(tables,"classes",int(classes[index].id)); var ability:=primary(data); var modifier: Variant=Values.modifier(int(scores[ability]),tables)
	if modifier==null: return -1
	var bonus:=0
	if level>0:
		if int(modifier)>0 and level<=int(modifier): bonus=maxi(0,int((int(modifier)-level+4)/4))
		if Skills.number(data,"PickSchool")!=0 and index<books.size() and int(books[index].get("school",0))&255!=0: bonus+=1
	var effective: int=(int(classes[index].level)+prestige_levels(classes,tables,index))&255
	if effective<1 or effective>40: return 0
	var gain:=Skills.row(tables,Skills.table_name(data,"SpellGainTable"),effective-1)
	if level>=(Skills.number(gain,"NumSpellLevels")&255): return 0
	var base:=Skills.number(gain,"SpellLevel"+str(level),255)&255
	return 0 if base==255 else (base+bonus)&255
static func spell_level(data: Dictionary,spell: Dictionary) -> int:
	if spell.is_empty() or not is_caster(data) and Skills.number(data,"PlayerClass")!=0: return 255
	var column:=str(Game.cell(data,"SpellTableColumn",""))
	return Skills.number(spell,column,255)&255 if column not in ["","****"] else 255
static func compute(source_data: Dictionary,tables: Dictionary) -> Dictionary:
	if source_data.has("error"): return {"ready":false,"dependencies":[],"errors":[str(source_data.error)]}
	var pending:=dependencies(source_data,tables)
	if not pending.is_empty(): return {"ready":false,"dependencies":pending,"errors":[]}
	var stats: Dictionary=source_data.stats; var skill_data:=Skills.compute(stats,tables)
	if not skill_data.ready: return {"ready":false,"dependencies":skill_data.dependencies,"errors":skill_data.errors}
	var classes: Array=skill_data.classes; var normalized: Dictionary=stats.duplicate(true); normalized.classes=classes; var gains:=Skills.class_gains(normalized,tables)
	if gains.is_empty(): return {"ready":false,"dependencies":[],"errors":["Original class stat-gain storage is unavailable."]}
	var entries: Array=[]; var minimums: Array=[]; var counts: Array=[]; var highest: Array=[]; var errors: Array=[]; var books: Array=source_data.get("books",[])
	for index in classes.size():
		var data:=Skills.row(tables,"classes",int(classes[index].id)); var met: Array=[]; var uses: Array=[]; var top:=-1
		for level in 10:
			met.append(minimum(stats,classes,gains,tables,index,level)); var value:=slots(stats,books,classes,gains,skill_data.scores,tables,index,level); uses.append(value)
			if value<0: errors.append("Original spell modifier rules are invalid.")
			if met[-1] and value>0: top=level
		minimums.append(met); counts.append(uses); highest.append(top)
		if Skills.number(data,"SpellbookRestricted")==0 and top>0: entries.append({"id":-1,"classIndex":index,"level":top,"summary":true,"nameRef":SUMMARY_DRUID[top] if int(classes[index].id)==3 else SUMMARY_CLERIC[top],"icon":SUMMARY_ICONS[top]})
	for index in classes.size():
		var data:=Skills.row(tables,"classes",int(classes[index].id)); var grouped: Array=[]
		for level in 10: grouped.append([])
		if index<books.size():
			for raw_id in books[index].get("known",[]):
				var id:=int(raw_id)&65535; var spell:=Skills.row(tables,"spells",id); var level:=spell_level(data,spell)
				if level<10: grouped[level].append(id)
		for level in 10:
			if grouped[level].size()>255: return {"ready":false,"dependencies":[],"errors":["Original pregame spell-row index exceeds its supported width."]}
			for id in grouped[level]: entries.append({"id":id,"classIndex":index,"level":level,"summary":false})
	return {"ready":errors.is_empty(),"dependencies":[],"errors":errors,"entries":entries,"minimums":minimums,"slots":counts,"highest":highest,"classes":classes,"native_only":true,"fullGameplaySpellParity":false}
