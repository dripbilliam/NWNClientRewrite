extends SceneTree
const Spell=preload("res://systems/native_data/spell_radial.gd")
const Ability=preload("res://systems/native_data/ability_radial.gd")
const Rules=preload("res://systems/native_data/game_ui_rules.gd")
class Text extends RefCounted:
	var tables: Dictionary={}
var checks:=0
var failures: Array=[]
func six(value: Variant) -> Array: return value if value is Array else [value,value,value,value,value,value]
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("report") or not args.has("fixture") or FileAccess.file_exists(args.report): quit(2); return
	var proof: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(args.fixture)); var text:=Text.new(); var rules:=Rules.new(); rules.text=text; var abilities:=Ability.new(); abilities.rules=rules; var helper:=Spell.new(); helper.rules=rules; helper.abilities=abilities
	if proof.target!="3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a": quit(3); return
	var skipped:=0
	for sample in proof.cases:
		var c: Dictionary=sample.case; var mods:=six(c.modifier); var valid: bool=c.classes.all(func(cls):return int(cls.level)<=40) and mods.all(func(value):return int(value)>=-5 and int(value)<=122)
		# Captured old final-query fixtures can return an arbitrary gain for an
		# out-of-range effective level. Such a query is not real class storage.
		if not sample.queries.all(func(query):return int(query.level)>0 and int(query.level)<=40): valid=false
		if not valid: skipped+=1; continue
		var rows: Array=[]
		for id in 40: rows.append({})
		text.tables={"classes":{"orderedRows":rows},"racialtypes":{"orderedRows":[{}]},"ruleset":{"orderedRows":[{"Label":"CHARGEN_BASE_ABILITY_MIN_PRIMARY","Value":str(int(c.minimum))}]}}
		var race: Dictionary={}
		for at in 6: race["%sAdjust"%[Spell.Skills.KEYS[at]]]=int(six(c.race)[at])
		text.tables.racialtypes.orderedRows[0]=race
		for index in c.classes.size():
			var cls: Dictionary=c.classes[index]; var data: Dictionary=c.defs[str(int(cls.id))]; var gain: Dictionary={"NumSpellLevels":10}
			for level in 10: gain["SpellLevel"+str(level)]=int(c.returnGain)
			text.tables["gain"+str(index)]={"orderedRows":[]}; text.tables["stat"+str(index)]={"orderedRows":[]}
			for level in 40:
				text.tables["gain"+str(index)].orderedRows.append(gain)
				var stats: Dictionary={}
				for at in 6: stats[Spell.Skills.KEYS[at]]=int(six(c.gain)[at]) if index==0 and level==0 else 0
				text.tables["stat"+str(index)].orderedRows.append(stats)
			rows[int(cls.id)]={"SpellcastingAbil":Spell.Skills.KEYS[int(c.ability)],"SpellCaster":data.spellCaster,"Arcane":data.arcane,"PickSchool":data.get("pickSchool",0),"ArcSpellLvlMod":data.arcaneModifier,"DivSpellLvlMod":data.divineModifier,"SpellGainTable":"gain"+str(index),"StatGainTable":"stat"+str(index)}
		var actor:={"replicated":{"stats":{"classes":c.classes,"racialType":0}},"clientAbilityCache":{"base":six(c.base),"current":mods.map(func(value):return 10+2*int(value)),"bonuses":six(c.bonus),"dex":int(c.dex)}}
		var actual:=helper.spell_gain(actor,int(c.index),int(c.level)); checks+=1
		if actual!=int(sample.result) and failures.size()<10: failures.append({"case":c,"actual":actual,"expected":sample.result})
	var file:=FileAccess.open(args.report,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"skipped_unrealizable_captured_queries":skipped,"helper_errors":helper.errors,"publicConnections":0,"scope":"Original instruction spell-gain arithmetic/prestige/rival fixtures with captured lower queries converted to realizable current catalog/cache data; does not prove authoritative spell slots."},"  ")); file.close(); quit(0 if failures.is_empty() else 1)
func _initialize() -> void: call_deferred("run")
