extends RefCounted
# Original mode1 CG_SPELLS input. Existing class books are copied; appended
# class records alone use the proven constructor-empty arrays/School0.
const Tables=preload("res://systems/native_data/creation_feat_tables.gd")
const Capacity=preload("res://systems/native_data/level_up_feat_capacity.gd")
const Levels=preload("res://systems/native_data/creation_spells_snapshot.gd")
const Skills=preload("res://systems/native_data/pregame_skills.gd")
const Values=preload("res://systems/native_data/character_record_values.gd")
const Class=preload("res://systems/native_data/level_up_class_state.gd")
const Counter=preload("res://systems/native_data/level_up_spell_counter.gd")
static func pending(reason: String) -> Dictionary:return {"ready":false,"reason":reason}
static func compose(received: Dictionary,private_snapshot: Dictionary,tables: Dictionary,text,chosen_school: int=-1) -> Dictionary:
	if not private_snapshot.get("ready",false) or not tables.has("spells") or text==null or not text.has_method("raw"):return pending("Private mode1 spell source is unavailable.")
	var projected:=private_snapshot.duplicate(true);var index:=int(projected.source.current)
	var fresh: bool=index==received.classes.size() and projected.source.classes.size()==received.classes.size()+1
	if fresh:
		#7ea230 constructs8 records with7ea700; ten default known arrays and
		# DWORD+148=ff000000 leave school+14a zero.7f69a0 reads that byte;
		#837f60 only overwrites copied owned records.7f9820 does not clear them.
		projected.source.classes[index].school=0
		projected.vitals.classes[index].school=0
	if chosen_school>=0:
		if chosen_school>255:return pending("Private mode1 school is outside its BYTE range.")
		projected.source.classes[index].school=chosen_school;projected.vitals.classes[index].school=chosen_school
	var prepared:=Capacity.prepare(projected,tables,true)
	if not prepared.ready:return prepared
	var cls: Dictionary=prepared.source.classes[index];var spell: Dictionary=cls.spell;var id:=int(cls.id)
	if int(spell.SpellCaster)==0:return pending("This routed native class lacks spellcaster storage.")
	var school:=int(cls.get("school",0)) if int(spell.PickSchool)==0 or Class.integer(cls.get("school"),0,255) else -1
	if school<0:return pending("Copied mode1 school is unavailable.")
	var player:=Tables.integer(tables.classes,id,"PlayerClass")
	var column:=Tables.cell(tables.classes,id,"SpellTableColumn")
	if not player.ready or not player.ok or not column.found:return pending("Active mode1 physical spell class metadata is unavailable.")
	var known: Array=[]
	if not fresh:
		var books: Variant=received.get("spellbooks");var book: Variant=books.get(str(index),books.get(index)) if books is Dictionary else null
		if not book is Dictionary or not book.get("known") is Array:return pending("Copied owned-class known-spell storage is unavailable.")
		known=book.known.duplicate()
		for value in known:
			if not Class.integer(value,0,4294967295):return pending("Copied owned-class known spell is malformed.")
	var definitions: Array=[];var by_id: Dictionary={};var lookup:=Tables.columns(tables.spells)
	for spell_id in tables.spells.get("orderedRows",[]).size():
		var level:=Levels.level(tables.spells,spell_id,str(column.text),true,int(player.value)!=0,lookup)
		var title:=Tables.integer(tables.spells,spell_id,"Name",lookup);var description:=Tables.integer(tables.spells,spell_id,"SpellDesc",lookup)
		if not level.ready or not title.ready or not description.ready:return pending("Active mode1 physical spell conversion is unresolved.")
		var source_school:=Tables.cell(tables.spells,spell_id,"School",lookup);var icon:=Tables.cell(tables.spells,spell_id,"IconResRef",lookup)
		var entry:={"id":spell_id,"level":int(level.value),"school":Levels.SCHOOL_BYTES.get(str(source_school.text).left(1)),"title":int(title.value)&0xffffffff,"description":int(description.value)&0xffffffff,"name":text.raw({"strRef":int(title.value)&0xffffffff}),"icon":str(icon.text).left(16).to_lower() if icon.found and icon.text!="****" else null}
		definitions.append(entry);by_id[spell_id]=entry
	var books: Array=[]
	for at in 10:books.append([])
	for value in known:
		var spell_id:=int(value)
		if not by_id.has(spell_id) or int(by_id[spell_id].level)>=10:return pending("Copied known spell lacks a valid active class level.")
		books[int(by_id[spell_id].level)].append(spell_id)
	for book in books:
		if book.size()>255:return pending("Original known-spell BYTE traversal exceeds its verified range.")
	var opposition: Variant=null
	if int(spell.PickSchool)!=0 and school!=0:
		if not tables.has("spellschools"):return pending("Active opposing-school storage is unavailable.")
		var read:=Tables.integer(tables.spellschools,school,"Opposition")
		if not read.ready:return pending("Active opposing-school conversion is unresolved.")
		if read.ok:opposition=int(read.value)&255
	var raw: Array=projected.vitals.raw;var ability:=int(spell.ability)
	var effective: int=(int(raw[ability])+int(projected.vitals.racial[ability])+int(spell.abilityGain[ability]))&255
	var minimum_score: int=maxi(3,Values.signed8(int(raw[ability]))+int(projected.vitals.racial[ability])+int(projected.vitals.gains[ability]))&255
	var slots: Array=[];var gained: Array=[];var minimum: Array=[];var getter=prepared.getter
	for at in 10:
		var count: int=int(spell.known[at]) if spell.knownPresent and at<int(spell.NumSpellLevels) else 0
		if count!=0 and int(spell.SpellbookRestricted)!=0 and int(spell.LearnScroll)==0 and at>0 and int(spell.known[at-1])==0 and effective<at+10:count=0
		slots.append(count);minimum.append(minimum_score>=at-1+Values.cfg(tables,"CHARGEN_BASE_ABILITY_MIN_PRIMARY",11))
		getter.errors.clear();gained.append(getter.spell_gain(prepared.actor,index,at))
		if not getter.errors.is_empty():return pending(str(getter.errors[0]))
	var initialized: Dictionary={}
	if int(spell.MemorizesSpells)!=0 and int(spell.LearnScroll)==0:
		initialized=Counter.derive(slots,minimum,books)
		if not initialized.ready:return initialized
	var source:={"memorizes":int(spell.MemorizesSpells)!=0,"learnScroll":int(spell.LearnScroll)!=0,"pickSchool":int(spell.PickSchool)!=0,"keepBudget":false,"classLevel":int(cls.level),"intModifier":int(projected.vitals.modifiers[3]),"baseInt":int(raw[3]),"school":school,"storedRemaining":int(initialized.get("counter",0)),"opposition":opposition,"spells":definitions,"known":books,"capacity":slots,"gain":gained,"minimum":minimum}
	return {"ready":true,"source":source,"classId":id,"classIndex":index,"newClassRecord":fresh,"counterInitialization":initialized,"scope":"native_private_mode1"}
