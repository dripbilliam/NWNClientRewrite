extends RefCounted
# Mode1 prerequisite7ee690 traverses every advanced class. Nonmemorizing
# checks use that class's own ability gain; memorizing7f6b20 uses the private
# clone's complete effective ability cache. Neither uses spent spell uses.
const Capacity=preload("res://systems/native_data/creation_feat_spell_capacity.gd")
const Tables=preload("res://systems/native_data/creation_feat_tables.gd")
const Skills=preload("res://systems/native_data/pregame_skills.gd")
const Values=preload("res://systems/native_data/character_record_values.gd")
const Game=preload("res://systems/native_data/game_ui_rules.gd")
const Abilities=preload("res://systems/native_data/ability_radial.gd")
const Spell=preload("res://systems/native_data/spell_radial.gd")
const Class=preload("res://systems/native_data/level_up_class_state.gd")
class TableView extends RefCounted:
	var tables: Dictionary={}
static func pending(reason: String) -> Dictionary:return {"ready":false,"allowed":false,"reason":reason}
static func prepare(snapshot: Dictionary,tables: Dictionary,needs_gain: bool=false) -> Dictionary:
	if not snapshot.get("ready",false):return pending("Private mode1 spell prerequisites are unavailable.")
	var vitals: Dictionary=snapshot.vitals;var classes: Array=[];var normalized:=tables.duplicate();var class_rows: Array=tables.classes.orderedRows.duplicate()
	for original in snapshot.source.classes:
		var cls: Dictionary=original.duplicate(true);var id:=int(cls.id);var level:=int(cls.level);var decoded: Dictionary={};var row: Dictionary=class_rows[id]
		var caster:=Tables.integer(tables.classes,id,"SpellCaster")
		if not caster.ready or not caster.ok:return pending("Original owned-class spellcaster flag is unavailable.")
		decoded.SpellCaster=int(caster.value);cls.spell=decoded
		if int(caster.value)==0:classes.append(cls);continue
		if level<1 or level>40:return pending("Original class spell storage is outside the verified forty-level range.")
		for key in ["MemorizesSpells","SpellbookRestricted","LearnScroll"]:
			var read:=Tables.integer(tables.classes,id,key)
			if not read.ready or not read.ok:return pending("Original owned-class spell flag is unavailable: "+key)
			decoded[key]=int(read.value)
		var primary:=Tables.cell(tables.classes,id,"SpellcastingAbil")
		var ability:=Skills.KEYS.map(func(key):return str(key).to_upper()).find(str(primary.text).to_upper())
		if not primary.found or ability<0:return pending("Original owned-class spellcasting ability is unavailable.")
		var gain_name:=Skills.table_name(row,"SpellGainTable");var known_name:=Skills.table_name(row,"SpellKnownTable")
		if gain_name.is_empty() or not tables.has(gain_name) or not known_name.is_empty() and not tables.has(known_name):return pending("Active owned-class gain/known spell tables are unavailable.")
		var count:=Tables.integer(tables[gain_name],level-1,"NumSpellLevels")
		if not count.ready or not count.ok or int(count.value)&255>10:return pending("Original owned-class spell-level count is unavailable or outside ten-level storage.")
		decoded.ability=ability;decoded.NumSpellLevels=int(count.value)&255;decoded.knownPresent=not known_name.is_empty();decoded.gain=[];decoded.known=[]
		decoded.abilityGain=Skills.class_gains({"classes":[cls]},tables)
		if decoded.abilityGain.size()!=6:return pending("Original per-class cumulative spell ability gain is unavailable.")
		for at in int(decoded.NumSpellLevels):
			var gained:=Tables.integer(tables[gain_name],level-1,"SpellLevel"+str(at));var known:=Tables.integer(tables.get(known_name,{}),level-1,"SpellLevel"+str(at))
			if not gained.ready or not known.ready:return pending("Active owned-class spell conversion is unresolved.")
			decoded.gain.append(int(gained.value)&255 if gained.ok else 255);decoded.known.append(int(known.value)&255 if known.ok else 0)
		if needs_gain or int(decoded.MemorizesSpells)!=0:
			var school:=Tables.integer(tables.classes,id,"PickSchool")
			if not school.ready or not school.ok:return pending("Original memorizing class school metadata is unavailable.")
			decoded.PickSchool=int(school.value)
			if int(school.value)!=0 and not Class.integer(cls.get("school"),0,255):return pending("Copied private class school is unavailable.")
			# Decode the getter's active physical gain rows without changing the
			# shared source table or replacing multiclass/prestige level logic.
			var gains: Array=[]
			for index in mini(40,tables[gain_name].get("orderedRows",[]).size()):
				var levels:=Tables.integer(tables[gain_name],index,"NumSpellLevels")
				if not levels.ready or not levels.ok or int(levels.value)&255>10:return pending("Original memorizing gain-row count is unavailable.")
				var normalized_row:={"NumSpellLevels":int(levels.value)&255}
				for at in int(normalized_row.NumSpellLevels):
					var gained:=Tables.integer(tables[gain_name],index,"SpellLevel"+str(at))
					if not gained.ready:return pending("Original memorizing gain-row conversion is unresolved.")
					normalized_row["SpellLevel"+str(at)]=int(gained.value)&255 if gained.ok else 255
				gains.append(normalized_row)
			normalized[gain_name]={"orderedRows":gains}
		var getter_row:=row.duplicate();getter_row.merge(decoded,true);class_rows[id]=getter_row;classes.append(cls)
	normalized.classes=tables.classes.duplicate();normalized.classes.orderedRows=class_rows
	if needs_gain or classes.any(func(cls):return int(cls.spell.get("MemorizesSpells",0))!=0):
		#7f6b20's shared getter includes original prestige advancement. Do not
		# turn an undisclosed conditional class field into its fallback zero.
		for cls in classes:
			var id:=int(cls.id);var row: Dictionary=class_rows[id]
			for field in ["Arcane"] if int(cls.spell.SpellCaster)!=0 else ["ArcSpellLvlMod","DivSpellLvlMod"]:
				var read:=Tables.integer(tables.classes,id,field)
				if not read.ready or not read.ok:return pending("Original prestige spell metadata is unavailable: "+field)
				row=row.duplicate();row[field]=int(read.value);class_rows[id]=row
		normalized.classes.orderedRows=class_rows
	var context:={"classes":classes,"baseAbilities":vitals.raw,"raceAdjust":vitals.racial}
	var private_actor:={"replicated":{"stats":{"racialType":snapshot.raceId,"classes":classes}},"clientAbilityCache":{"base":vitals.raw,"current":vitals.scores,"bonuses":[0,0,0,0,0,0],"dex":0}}
	var view:=TableView.new();view.tables=normalized;var game:=Game.new();game.text=view
	var abilities:=Abilities.new();abilities.rules=game;var getter:=Spell.new();getter.rules=game;getter.abilities=abilities
	return {"ready":true,"source":context,"actor":private_actor,"getter":getter}
static func evaluate(snapshot: Dictionary,required: int,tables: Dictionary) -> Dictionary:
	if required&255==0:return {"ready":true,"allowed":true}
	var prepared:=prepare(snapshot,tables)
	if not prepared.ready:return prepared
	var getter=prepared.getter
	var memorizing: Callable=func(index: int,spell_level: int):
		getter.errors.clear();var gained: int=getter.spell_gain(prepared.actor,index,spell_level)
		return {"ready":getter.errors.is_empty(),"gain":gained}
	return Capacity.evaluate(prepared.source,required,memorizing)
