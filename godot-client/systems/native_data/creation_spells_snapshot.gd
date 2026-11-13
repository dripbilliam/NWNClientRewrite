extends RefCounted
# First-level active-table adapter for CG_SPELLS. It borrows existing draft,
# ability and spell-gain owners; it does not own Nodes or replicated world data.
const Tables=preload("res://systems/native_data/creation_feat_tables.gd")
const State=preload("res://systems/native_data/creation_spells_state.gd")
const Vitals=preload("res://systems/native_data/creation_vitals.gd")
const Values=preload("res://systems/native_data/character_record_values.gd")
const Skills=preload("res://systems/native_data/pregame_skills.gd")
const Game=preload("res://systems/native_data/game_ui_rules.gd")
const Abilities=preload("res://systems/native_data/ability_radial.gd")
const Spell=preload("res://systems/native_data/spell_radial.gd")
const SCHOOL_BYTES={"A":1,"C":2,"D":3,"E":4,"V":5,"I":6,"N":7,"T":8}
class TableView extends RefCounted:
	var tables: Dictionary={}
static func pending(message: String,dependencies: Array=[]) -> Dictionary:return {"ready":false,"reason":message,"dependencies":dependencies}
static func level(table: Dictionary,id: int,column: String,caster: bool,player: bool,lookup: Dictionary={}) -> Dictionary:
	# Original2af530: standard columns consume cached255 defaults; custom
	# columns consume a successful active C2DA lookup. Neither filters Master,
	# UserType or Name, unlike the older generic spell_options method.
	if not caster and player:return {"ready":true,"value":255}
	var read:=Tables.integer(table,id,column,lookup)
	if not read.ready:return read
	return {"ready":true,"value":int(read.value)&255 if read.ok else 255}
static func compose(rules,active_text,require_selection_counter: bool=true) -> Dictionary:
	var tables: Dictionary=rules.tables;var d: Dictionary=rules.draft;var missing: Array=[]
	for key in ["classes","racialtypes","ruleset","spells"]:
		if not tables.has(key):missing.append(key)
	if not missing.is_empty():return pending("Active spell selection data has not arrived.",missing)
	if active_text==null or not active_text.has_method("raw"):return pending("Active spell names are unavailable.")
	if not d.has_all(["classId","raceId","abilities","school","known"]) or not d.known is Dictionary:return pending("The first-level spell draft is incomplete.")
	var id:=int(d.classId);var race:=int(d.raceId)
	if id<0 or id>=(tables.classes.get("orderedRows",[]).size()&255) or race<0 or race>=tables.racialtypes.get("orderedRows",[]).size():return pending("The selected class/race is unavailable.")
	var cls: Dictionary=rules.cls();var decoded: Dictionary={};var class_lookup:=Tables.columns(tables.classes)
	for key in ["SpellCaster","PlayerClass","MemorizesSpells","LearnScroll","SpellbookRestricted","PickSchool"]:
		var read:=Tables.integer(tables.classes,id,key,class_lookup)
		if not read.ready or not read.ok:return pending("Conditional native class metadata is unavailable: "+key)
		decoded[key]=int(int(read.value)!=0)
	var primary_cell:=Tables.cell(tables.classes,id,"SpellcastingAbil",class_lookup)
	var ability:=Skills.KEYS.map(func(key):return str(key).to_upper()).find(str(primary_cell.text))
	if not primary_cell.found or ability<0:return pending("The native spellcasting ability is unavailable.")
	var raw: Array=[];var race_adjust: Array=[]
	for key in Skills.KEYS:
		if not State.scalar(d.abilities.get(key)):return pending("A raw draft ability is unavailable.")
		raw.append(int(d.abilities[key])&255)
		var read:=Tables.integer(tables.racialtypes,race,str(key)+"Adjust")
		if not read.ready:return pending("Native racial ability conversion is unresolved.")
		race_adjust.append(Values.signed8(int(read.value)))
	var scores:=Vitals.effective({"classId":id,"race":race,"abilities":d.abilities},tables)
	if not scores.ready:return pending("Native draft ability gains are unavailable.",scores.get("dependencies",[]))
	var modifier: Variant=Values.modifier(int(scores.scores[3]),tables)
	if modifier==null:return pending("Active Intelligence modifier rules are invalid.")
	var gain_name:=Skills.table_name(cls,"SpellGainTable");var known_name:=Skills.table_name(cls,"SpellKnownTable")
	if gain_name.is_empty() or not tables.has(gain_name):return pending("The active spell-gain table is unavailable.",[gain_name] if not gain_name.is_empty() else [])
	if not known_name.is_empty() and not tables.has(known_name):return pending("The active known-spell table is unavailable.",[known_name])
	var count:=Tables.integer(tables[gain_name],0,"NumSpellLevels")
	if not count.ready or not count.ok:return pending("Native spell-level count is unavailable.")
	var level_count:=int(count.value)&255;var normalized_gain:={"NumSpellLevels":level_count};var known_cells: Array=[]
	for at in level_count:
		var gain:=Tables.integer(tables[gain_name],0,"SpellLevel"+str(at));var known:=Tables.integer(tables.get(known_name,{}),0,"SpellLevel"+str(at))
		if not gain.ready or not known.ready:return pending("An active spell-level conversion is unresolved.")
		normalized_gain["SpellLevel"+str(at)]=int(gain.value)&255 if gain.ok else 255;known_cells.append(int(known.value)&255 if known.ok else 0)
	var capacity: Array=[];var minimum: Array=[];var gained: Array=[];var books: Array=[]
	var effective: int=(int(raw[ability])+int(race_adjust[ability])+int(scores.gains[ability]))&255
	var minimum_score: int=maxi(3,Values.signed8(int(raw[ability]))+int(race_adjust[ability])+int(scores.gains[ability]))&255
	for at in 10:
		var target:=int(known_cells[at]) if at<level_count and not known_name.is_empty() else 0
		if target!=0 and decoded.SpellbookRestricted!=0 and decoded.LearnScroll==0 and at>0 and int(known_cells[at-1])==0 and effective<at+10:target=0
		capacity.append(target);minimum.append(decoded.SpellCaster!=0 and minimum_score>=at-1+Values.cfg(tables,"CHARGEN_BASE_ABILITY_MIN_PRIMARY",11))
		var book: Variant=d.known.get(at,d.known.get(str(at),[]))
		if not book is Array or book.any(func(spell_id):return not State.scalar(spell_id)):return pending("A draft known-spell list is unavailable.")
		books.append(book.map(func(spell_id):return int(spell_id)))
	#9ce190 writes its shared counter from GetSpellsKnownLeft inside every
	# enabled, minimum-eligible non-scroll level, including a full book (0).
	#9c3250 does not initialize the prior counter if no such level is visited.
	if require_selection_counter and decoded.MemorizesSpells!=0 and decoded.LearnScroll==0:
		var counter_written:=false
		for at in 10:
			if (int(capacity[at])&255)!=0 and minimum[at]:counter_written=true;break
		if not counter_written:return pending("This native class combination requires an unbound prior spell-selection counter.")
	# Reuse the independently original-backed spell-gain implementation.
	var view:=TableView.new();view.tables=tables.duplicate();view.tables[gain_name]={"orderedRows":[normalized_gain]}
	var class_rows: Array=tables.classes.orderedRows.duplicate();var getter_cls:=cls.duplicate();getter_cls.merge(decoded,true);getter_cls.SpellGainTable=gain_name;class_rows[id]=getter_cls;view.tables.classes={"orderedRows":class_rows}
	var game:=Game.new();game.text=view;var abilities:=Abilities.new();abilities.rules=game;var getter:=Spell.new();getter.rules=game;getter.abilities=abilities
	var actor:={"replicated":{"stats":{"racialType":race,"classes":[{"id":id,"level":1,"school":int(d.school)&255}]}},"clientAbilityCache":{"base":raw,"current":scores.scores,"bonuses":[0,0,0,0,0,0],"dex":0}}
	for at in 10:
		gained.append(getter.spell_gain(actor,0,at))
		if not getter.errors.is_empty():return pending(str(getter.errors[0]))
	var opposition: Variant=null
	if decoded.PickSchool!=0 and (int(d.school)&255)!=0:
		if not tables.has("spellschools"):return pending("Active opposing-school data is unavailable.",["spellschools"])
		var read:=Tables.integer(tables.spellschools,int(d.school)&255,"Opposition")
		if not read.ready:return pending("Native opposition conversion is unresolved.")
		if read.ok:opposition=int(read.value)&255
	var column:=Tables.cell(tables.classes,id,"SpellTableColumn",class_lookup)
	if not column.found:return pending("The class's active spell-table column is unavailable.")
	var definitions: Array=[];var spell_table: Dictionary=tables.spells;var lookup:=Tables.columns(spell_table)
	for spell_id in spell_table.get("orderedRows",[]).size():
		var spell_level:=level(spell_table,spell_id,str(column.text),decoded.SpellCaster!=0,decoded.PlayerClass!=0,lookup)
		var name:=Tables.integer(spell_table,spell_id,"Name",lookup);var description:=Tables.integer(spell_table,spell_id,"SpellDesc",lookup)
		if not spell_level.ready or not name.ready or not description.ready:return pending("Active spell definition conversion is unresolved.")
		var school:=Tables.cell(spell_table,spell_id,"School",lookup);var school_byte: Variant=SCHOOL_BYTES.get(str(school.text).left(1))
		var icon:=Tables.cell(spell_table,spell_id,"IconResRef",lookup)
		definitions.append({"id":spell_id,"level":int(spell_level.value),"school":school_byte,"title":int(name.value)&0xffffffff,"description":int(description.value)&0xffffffff,"name":active_text.raw({"strRef":int(name.value)&0xffffffff}),"icon":str(icon.text).left(16).to_lower() if icon.found and icon.text!="****" else null})
	var source:={"memorizes":decoded.MemorizesSpells!=0,"learnScroll":decoded.LearnScroll!=0,"pickSchool":decoded.PickSchool!=0,"keepBudget":false,"classLevel":1,"intModifier":int(modifier),"baseInt":raw[3],"school":int(d.school)&255,"storedRemaining":0,"opposition":opposition,"spells":definitions,"known":books,"capacity":capacity,"gain":gained,"minimum":minimum}
	return {"ready":true,"source":source,"classId":id,"raceId":race,"scope":"native_first_level_draft","dependencies":[]}
