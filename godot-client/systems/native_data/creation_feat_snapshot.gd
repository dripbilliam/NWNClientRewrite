extends RefCounted
# First-level CG_FEATS adapter. This reads the connection's draft/rule owner;
# it is not an in-world stat cache or a replacement for received level-up data.
const Tables=preload("res://systems/native_data/creation_feat_tables.gd")
const Vitals=preload("res://systems/native_data/creation_vitals.gd")
const Values=preload("res://systems/native_data/character_record_values.gd")
const Skills=preload("res://systems/native_data/pregame_skills.gd")
const Slots=preload("res://systems/native_data/creation_feat_slots.gd")
const Capacity=preload("res://systems/native_data/creation_feat_spell_capacity.gd")
const Game=preload("res://systems/native_data/game_ui_rules.gd")
const Abilities=preload("res://systems/native_data/ability_radial.gd")
const Spell=preload("res://systems/native_data/spell_radial.gd")
const Choice=preload("res://systems/native_data/creation_feat_choice_rules.gd")
class TableView extends RefCounted:
	var tables: Dictionary={}
static func pending(reason: String,dependencies: Array=[]) -> Dictionary:return {"ready":false,"reason":reason,"dependencies":dependencies}
static func compose(rules,chosen: Array=[],prepared: Dictionary={}) -> Dictionary:
	var tables: Dictionary=rules.tables;var d: Dictionary=rules.draft
	var missing: Array=[]
	for key in ["feat","classes","racialtypes","skills","ruleset"]:
		if not tables.has(key):missing.append(key)
	if not missing.is_empty():return pending("Active feat rules have not arrived.",missing)
	if not d.has_all(["raceId","classId","abilities","skills","domains","school"]):return pending("First-level character draft is incomplete.")
	for key in Skills.KEYS:
		if not d.abilities.has(key):return pending("A raw character ability is unavailable.")
	var class_id:=int(d.classId);var race_id:=int(d.raceId)
	if class_id<0 or class_id>=(rules.rows("classes").size()&255) or race_id<0 or race_id>=(rules.rows("racialtypes").size()&255):return pending("Physical character class/race is unavailable.")
	var cls: Dictionary=rules.row("classes",class_id);var race: Dictionary=rules.row("racialtypes",race_id)
	for key in ["FeatsTable","SkillsTable","StatGainTable","AttackBonusTable","BonusFeatsTable","SpellGainTable","SpellKnownTable"]:
		var name:=Skills.table_name(cls,key)
		if not name.is_empty() and not tables.has(name) and not missing.has(name):missing.append(name)
	var race_feats:=Skills.table_name(race,"FeatsTable")
	if not race_feats.is_empty() and not tables.has(race_feats):missing.append(race_feats)
	if not missing.is_empty():return pending("Active class/race feat dependencies have not arrived.",missing)
	var decoded:=prepared if prepared.get("ready",false) else Tables.decode(tables.feat)
	if not decoded.ready:return pending(str(decoded.get("reason","Active feat definitions are unresolved.")))
	var definitions: Array=decoded.definitions
	var class_table: Dictionary=tables.get(Skills.table_name(cls,"FeatsTable"),{})
	var records:=Tables.class_records(class_table,definitions)
	if not records.ready:return pending(str(records.reason))
	var scores:=Vitals.effective({"classId":class_id,"race":race_id,"abilities":d.abilities},tables)
	if not scores.ready:return pending("Effective first-level ability cache is unavailable.",scores.get("dependencies",[]))
	var fortitude: Variant=Values.modifier(int(scores.scores[2]),tables)
	if fortitude==null:return pending("First-level Constitution modifier is unavailable.")
	var attack_table:=Skills.table_name(cls,"AttackBonusTable")
	if attack_table.is_empty():return pending("Original class attack-bonus storage is unavailable.")
	var attack:=Tables.integer(tables[attack_table],0,"BAB")
	if not attack.ready:return pending(str(attack.reason))
	var skills: Array=[];var class_skills: Array=[]
	for id in (rules.rows("skills").size()&255):
		var skill:={"rank":int(d.skills.get(id,0))&255}
		for key in ["Untrained","AllClassesCanUse"]:
			var value:=Tables.integer(tables.skills,id,key)
			if not value.ready:return pending(str(value.reason))
			skill[key]=int(value.value)
		skills.append(skill)
	var skill_table: Dictionary=tables.get(Skills.table_name(cls,"SkillsTable"),{})
	for at in skill_table.get("orderedRows",[]).size():
		var value:=Tables.integer(skill_table,at,"SkillIndex")
		if not value.ready:return pending(str(value.reason))
		var id:=int(value.value)&65535
		if id>=skills.size():return pending("Class skill table references unavailable original skill storage.")
		class_skills.append(id)
	# Original7ebd50 iterates valid physical feat IDs. The first matching class
	# record owns its grant level; a later duplicate must not grant it early.
	var racial: Dictionary={};var granted: Dictionary={}
	var race_table: Dictionary=tables.get(race_feats,{})
	for at in race_table.get("orderedRows",[]).size():
		var value:=Tables.integer(race_table,at,"FeatIndex")
		if not value.ready:return pending(str(value.reason))
		racial[int(value.value)&65535]=true
	for record in records.records:
		if not granted.has(int(record.id)):granted[int(record.id)]=int(record.List)==3 and int(record.level)==1
	var owned: Array=[]
	for id in definitions.size():
		if definitions[id].valid and (racial.has(id) or granted.get(id,false)):owned.append(id)
	if rules.num(cls,"PickDomains")!=0:
		if not tables.has("domains"):return pending("Active domain grants have not arrived.",["domains"])
		for domain in d.domains.slice(0,2):
			var value:=Tables.integer(tables.domains,int(domain)&255,"GrantedFeat")
			if not value.ready:return pending(str(value.reason))
			var id:=int(value.value)&65535
			if id<definitions.size() and definitions[id].valid and not owned.has(id):owned.append(id)
	var slots:=Slots.calculate(tables,race_id,class_id,1,1)
	# New-character7ea7a0/SetClass/CON initialize the Fort cache from base0;
	# importing first-row FortSave here would invent an extra class save.
	var source:={"current":0,"classes":[{"id":class_id,"level":1,"feats":records.records,"skills":class_skills}],"definitions":definitions,"scores":scores.scores,"baseAttack":int(attack.value)&255,"fortitude":Values.signed8(int(fortitude)),"owned":owned,"selected":chosen.duplicate(),"normal":int(slots.normal),"bonus":int(slots.bonus),"skills":skills,"spellLevels":{}}
	return {"ready":true,"source":source,"scores":scores,"classId":class_id,"raceId":race_id}
static func resolve_spells(snapshot: Dictionary,rules) -> Dictionary:
	if not snapshot.get("ready",false):return snapshot
	var source: Dictionary=snapshot.source;var required: Dictionary={}
	for feat in source.definitions:
		if feat.valid and (int(feat.MinSpellLvl)&255)!=0:required[int(feat.MinSpellLvl)&255]=true
	if required.is_empty():return snapshot
	var tables: Dictionary=rules.tables;var cls: Dictionary=rules.cls();var d: Dictionary=rules.draft
	var spell: Dictionary={}
	for key in ["SpellCaster","MemorizesSpells","SpellbookRestricted","LearnScroll"]:
		var value:=Tables.integer(tables.classes,int(snapshot.classId),key)
		if not value.ready:return pending(str(value.reason))
		spell[key]=int(value.value)
	if int(spell.SpellCaster)==0:
		for level in required:source.spellLevels[level]=false
		return snapshot
	var ability:=Skills.KEYS.map(func(key):return str(key).to_upper()).find(str(Game.cell(cls,"SpellcastingAbil","")).to_upper())
	if ability<0:return pending("Original spellcasting ability metadata is unavailable.")
	var raw: Array=[];var race_adjust: Array=[]
	for key in Skills.KEYS:
		raw.append(int(d.abilities[key])&255)
		var value:=Tables.integer(tables.racialtypes,int(snapshot.raceId),str(key)+"Adjust")
		if not value.ready:return pending(str(value.reason))
		race_adjust.append(Values.signed8(int(value.value)))
	var gain_table: Dictionary=tables.get(Skills.table_name(cls,"SpellGainTable"),{})
	var count:=Tables.integer(gain_table,0,"NumSpellLevels")
	if not count.ready:return pending(str(count.reason))
	var known_name:=Skills.table_name(cls,"SpellKnownTable");var known_table: Dictionary=tables.get(known_name,{})
	spell.ability=ability;spell.abilityGain=snapshot.scores.gains;spell.knownPresent=not known_name.is_empty();spell.NumSpellLevels=int(count.value)&255;spell.known=[];spell.gain=[]
	var normalized_gain:={"NumSpellLevels":int(spell.NumSpellLevels)}
	for level in int(spell.NumSpellLevels):
		var gain:=Tables.integer(gain_table,0,"SpellLevel"+str(level));var known:=Tables.integer(known_table,0,"SpellLevel"+str(level))
		if not gain.ready or not known.ready:return pending("Active spell capacity row conversion is unresolved.")
		spell.gain.append(int(gain.value)&255 if gain.ok else 255);spell.known.append(int(known.value)&255 if known.ok else 0)
		normalized_gain["SpellLevel"+str(level)]=int(spell.gain[-1])
	source.classes[0].spell=spell
	var context:={"classes":source.classes,"baseAbilities":raw,"raceAdjust":race_adjust}
	var actor:={"replicated":{"stats":{"racialType":int(snapshot.raceId),"classes":[{"id":int(snapshot.classId),"level":1,"school":int(d.school)&255}]}},"clientAbilityCache":{"base":raw,"current":source.scores,"bonuses":[0,0,0,0,0,0],"dex":0}}
	# Reuse the original-backed getter with decoded gain cells. Its owner must
	# report unavailable inputs explicitly, rather than wrapping an error0.
	var view:=TableView.new();view.tables=tables.duplicate();var gain_name:=Skills.table_name(cls,"SpellGainTable")
	if not gain_name.is_empty():view.tables[gain_name]={"orderedRows":[normalized_gain]}
	var game:=Game.new();game.text=view;var abilities:=Abilities.new();abilities.rules=game
	var getter:=Spell.new();getter.rules=game;getter.abilities=abilities
	var memorizing: Callable=func(index: int,level: int):
		getter.errors.clear();var value:=getter.spell_gain(actor,index,level)
		return {"ready":getter.errors.is_empty(),"gain":value}
	for level in required:
		var answer:=Capacity.evaluate(context,int(level),memorizing)
		if not answer.ready:return pending(str(answer.reason))
		source.spellLevels[int(level)]=bool(answer.allowed)
	return snapshot
static func validate_choices(rules,chosen: Array) -> Dictionary:
	var current:=resolve_spells(compose(rules,chosen),rules)
	if not current.ready:return current
	var source: Dictionary=current.source;var seen: Dictionary={}
	for id in chosen:
		if not id is int or id<0 or id>=source.definitions.size() or seen.has(id):return {"ready":true,"valid":false,"reason":"Invalid physical feat selection."}
		seen[id]=true
		var check:=source.duplicate();check.selected=chosen.duplicate();check.selected.erase(id);check.featId=id;check.feat=source.definitions[id]
		var allowed:=Choice.evaluate(check)
		if not allowed.ready:return allowed
		if not allowed.allowed:return {"ready":true,"valid":false,"reason":"Active feat prerequisites or reservations changed."}
	var remaining:=(int(source.normal)+int(source.bonus)-chosen.size())&255
	if remaining!=0:
		for id in source.definitions.size():
			var check:=source.duplicate();check.featId=id;check.feat=source.definitions[id]
			var allowed:=Choice.evaluate(check)
			if not allowed.ready:return allowed
			if allowed.allowed:return {"ready":true,"valid":false,"reason":"Select every available feat choice."}
	return {"ready":true,"valid":true}
static func school_slot_reset(rules) -> Dictionary:
	#9c8c60 calls7faf60 BEFORE writing the selected school. Preserve that
	# cache ordering instead of deriving all visible slots from the new school.
	var tables: Dictionary=rules.tables;var d: Dictionary=rules.draft;var id:=int(d.get("classId",-1));var race:=int(d.get("raceId",-1))
	if not tables.has_all(["classes","racialtypes","ruleset"]) or id<0 or id>=(rules.rows("classes").size()&255):return pending("School spell-slot source is unavailable.")
	var memorizes:=Tables.integer(tables.classes,id,"MemorizesSpells")
	if not memorizes.ready or not memorizes.ok:return pending("Original class memorization metadata is unavailable.")
	var counts: Dictionary={}
	for level in 10:counts[level]=0
	if int(memorizes.value)==0:return {"ready":true,"counts":counts,"school":int(d.school)&255}
	for key in Skills.KEYS:
		if not d.get("abilities",{}).has(key):return pending("School raw abilities are unavailable.")
	var values:=Vitals.effective({"classId":id,"race":race,"abilities":d.abilities},tables)
	if not values.ready:return pending("School ability cache is unavailable.",values.get("dependencies",[]))
	var gain_name:=Skills.table_name(rules.cls(),"SpellGainTable")
	if gain_name.is_empty() or not tables.has(gain_name):return pending("School spell-gain table is unavailable.")
	var gain_table: Dictionary=tables[gain_name];var read_count:=Tables.integer(gain_table,0,"NumSpellLevels")
	if not read_count.ready or not read_count.ok:return pending("School spell-gain count is unavailable.")
	var normalized:={"NumSpellLevels":int(read_count.value)&255}
	for level in int(normalized.NumSpellLevels):
		var read:=Tables.integer(gain_table,0,"SpellLevel"+str(level))
		if not read.ready:return pending(str(read.reason))
		normalized["SpellLevel"+str(level)]=int(read.value)&255 if read.ok else 255
	var raw: Array=[]
	for key in Skills.KEYS:raw.append(int(d.abilities[key])&255)
	var actor:={"replicated":{"stats":{"racialType":race,"classes":[{"id":id,"level":1,"school":int(d.school)&255}]}},"clientAbilityCache":{"base":raw,"current":values.scores,"bonuses":[0,0,0,0,0,0],"dex":0}}
	var view:=TableView.new();view.tables=tables.duplicate();view.tables[gain_name]={"orderedRows":[normalized]}
	var game:=Game.new();game.text=view;var abilities:=Abilities.new();abilities.rules=game;var getter:=Spell.new();getter.rules=game;getter.abilities=abilities
	for level in 10:
		counts[level]=getter.spell_gain(actor,0,level)
		if not getter.errors.is_empty():return pending(str(getter.errors[0]))
	return {"ready":true,"counts":counts,"school":int(d.school)&255}
