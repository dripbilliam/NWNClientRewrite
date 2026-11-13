extends SceneTree
const Capacity=preload("res://systems/native_data/creation_feat_spell_capacity.gd")
const Requirements=preload("res://systems/native_data/creation_feat_requirements.gd")
const Spell=preload("res://systems/native_data/spell_radial.gd")
const Abilities=preload("res://systems/native_data/ability_radial.gd")
const Rules=preload("res://systems/native_data/game_ui_rules.gd")
const Talk=preload("res://systems/native_data/talk_text.gd")
const Skills=preload("res://systems/native_data/pregame_skills.gd")
const KEYS=["Str","Dex","Con","Int","Wis","Cha"]
var checks:=0
var failures: Array=[]
var timing: Array=[]
var mismatch_details: Array=[]
func _initialize() -> void:call_deferred("run")
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label)
func s8(value: int) -> int:return (value&255)-256 if value&128 else value&255
func table_model(case: Dictionary) -> Dictionary:
	var classes: Array=[];var tables:={"racialtypes":{"orderedRows":[{}]},"classes":{"orderedRows":classes}}
	for at in 6:
		tables.racialtypes.orderedRows[0][KEYS[at]+"Adjust"]=int(case.raceAdjust[at])
		classes.append({})
	for cls in case.classes:
		var source: Dictionary=cls.spell;var row:=source.duplicate(true)
		row.SpellcastingAbil=KEYS[int(source.ability)].to_upper();row.StatGainTable="teststat"+str(int(cls.id));row.SpellGainTable="testspell"+str(int(cls.id));row.PlayerClass=1
		classes[int(cls.id)]=row
		var stats: Array=[]
		for values in source.statGain:
			var gains: Dictionary={}
			for at in 6:gains[KEYS[at]]=int(values[at])
			stats.append(gains)
		tables[row.StatGainTable]={"orderedRows":stats}
		var gain:={"NumSpellLevels":int(source.NumSpellLevels)}
		for at in source.gain.size():gain["SpellLevel"+str(at)]=int(source.gain[at])
		var spells: Array=[]
		for at in 40:spells.append(gain.duplicate())
		tables[row.SpellGainTable]={"orderedRows":spells}
	var settings: Array=[]
	for key in case.settings:settings.append({"Label":key,"Value":str(int(case.settings[key]))})
	tables.ruleset={"orderedRows":settings}
	return tables
func actor_model(case: Dictionary) -> Dictionary:
	var classes: Array=[]
	for cls in case.classes:classes.append({"id":int(cls.id),"level":int(cls.level),"school":int(cls.spell.school)})
	return {"replicated":{"stats":{"racialType":0,"classes":classes}},"clientAbilityCache":{"base":case.baseAbilities.duplicate(),"current":case.scores.duplicate(),"bonuses":case.abilityBonuses.duplicate(),"dex":int(case.dexterityAdjustment)}}
func source_model(case: Dictionary) -> Dictionary:
	var source:=case.duplicate(true)
	for cls in source.classes:
		var gains: Array=[0,0,0,0,0,0]
		for level in mini(60,int(cls.level)&255):
			for at in 6:gains[at]=s8(int(gains[at])+s8(int(cls.spell.statGain[level][at])))
		cls.spell.abilityGain=gains
	return source
func run() -> void:
	var output:="";var oracle:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):output=arg.trim_prefix("--report=")
		if arg.begins_with("--oracle="):oracle=arg.trim_prefix("--oracle=")
	if output.is_empty() or oracle.is_empty() or FileAccess.file_exists(output):quit(2);return
	var packet: Variant=JSON.parse_string(FileAccess.get_file_as_string(oracle))
	if not packet is Dictionary or packet.get("target")!="3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a" or not packet.get("rows") is Array:quit(2);return
	var first_actor: Dictionary={};var first_source: Dictionary={};var first_spell
	for index in packet.rows.size():
		var observed: Dictionary=packet.rows[index];var case: Dictionary=observed.case;var source:=source_model(case);var actor:=actor_model(case)
		var text:=Talk.new();text.tables=table_model(case);text.publish_table("ruleset",text.tables.ruleset)
		var rules:=Rules.new();rules.text=text
		var abilities:=Abilities.new();abilities.rules=rules
		var spell:=Spell.new();spell.rules=rules;spell.abilities=abilities
		var class_gains:=Skills.class_gains({"classes":actor.replicated.stats.classes},text.tables)
		check(class_gains.size()==6 and range(6).all(func(at):return (int(class_gains[at])&255)==int(observed.abilityGains[at])),"Original cumulative class gains "+str(index))
		for value in observed.memorizingGains:
			var actual_gain:=spell.spell_gain(actor,int(value.index),int(case.feat.MINSPELLLVL)&255)
			check(actual_gain==int(value.gain),"Original memorizing getter "+str(index)+"/"+str(int(value.index)))
			if actual_gain!=int(value.gain) and mismatch_details.size()<32:mismatch_details.append({"case":index,"classIndex":int(value.index),"expected":int(value.gain),"actual":actual_gain,"classGains":class_gains,"required":int(case.feat.MINSPELLLVL)&255})
		var before:=JSON.stringify(source);var actor_before:=JSON.stringify(actor)
		var gained: Callable=func(at: int,level: int):return {"ready":true,"gain":spell.spell_gain(actor,at,level)}
		var result:=Capacity.evaluate(source,int(case.feat.MINSPELLLVL),gained)
		check(result.ready and result.allowed==observed.accepted,"Original complete mixed-class prerequisite "+str(index))
		var required:=int(case.feat.MINSPELLLVL)&255
		if required!=0:source.spellLevels={required:result.allowed}
		var composed:=Requirements.evaluate(source,case.feat)
		check(composed.ready and composed.allowed==observed.accepted,"Composed original full feat requirements "+str(index))
		source.erase("spellLevels")
		check(JSON.stringify(source)==before and JSON.stringify(actor)==actor_before,"Queries retain native source/actor "+str(index))
		check(spell.errors.is_empty(),"No missing native getter data "+str(index))
		if first_source.is_empty() and required>0:first_source=source;first_actor=actor;first_spell=spell
	var missing:={"classes":[{"spell":{"SpellCaster":1,"MemorizesSpells":1}}]}
	check(not Capacity.evaluate(missing,1).ready,"Absent memorizing owner remains unavailable")
	for invalid in [null,{}, {"ready":false,"gain":0},{"ready":true},{"ready":true,"gain":null},{"ready":true,"gain":true},{"ready":true,"gain":-1},{"ready":true,"gain":256},{"ready":true,"gain":1.5}]:
		check(not Capacity.evaluate(missing,1,func(_at,_level):return invalid).ready,"Unavailable or invalid gain is not zero: "+str(invalid))
	check(Capacity.evaluate(missing,0).allowed,"Zero-level requirement doesn't invent a storage dependency")
	check(not Capacity.evaluate({},1).ready,"Missing class list differs from known empty list")
	check(Capacity.evaluate({"classes":[]},1).ready and not Capacity.evaluate({"classes":[]},1).allowed,"Known no classes cannot supply positive spell level")
	var mixed:=missing.duplicate(true);mixed.classes.append({"spell":{"SpellCaster":1,"MemorizesSpells":1}})
	check(Capacity.evaluate(mixed,1,func(at,_level):return {"ready":false} if at==0 else {"ready":true,"gain":1}).allowed,"A definite later class satisfies OR despite another unavailable capacity")
	var nonmemorizing:={"baseAbilities":[12,12,12,12,12,12],"raceAdjust":[0,0,0,0,0,0],"classes":[{"level":1,"spell":{"SpellCaster":1,"MemorizesSpells":0,"SpellbookRestricted":0,"LearnScroll":0,"ability":0,"abilityGain":[0,0,0,0,0,0],"knownPresent":false,"NumSpellLevels":2,"known":[0,0],"gain":[0,1]}}]}
	check(Capacity.evaluate(nonmemorizing,1).allowed,"Complete non-memorizing class retains its native positive gain")
	for key in ["baseAbilities","raceAdjust"]:
		var unavailable:=nonmemorizing.duplicate(true);unavailable[key][0]=null
		check(not Capacity.evaluate(unavailable,1).ready,"Unavailable ability element stays unavailable: "+key)
	for key in ["knownPresent","SpellbookRestricted","LearnScroll","ability","NumSpellLevels"]:
		var unavailable:=nonmemorizing.duplicate(true);unavailable.classes[0].spell[key]=null
		check(not Capacity.evaluate(unavailable,1).ready,"Unavailable spell metadata stays unavailable: "+key)
	for key in ["abilityGain","known","gain"]:
		var unavailable:=nonmemorizing.duplicate(true);unavailable.classes[0].spell[key][0]=null
		check(not Capacity.evaluate(unavailable,1).ready,"Unavailable spell storage stays unavailable: "+key)
	var getter: Callable=func(at,level):return {"ready":true,"gain":first_spell.spell_gain(first_actor,at,level)}
	for at in 200:
		var started:=Time.get_ticks_usec();Capacity.evaluate(first_source,1,getter);timing.append((Time.get_ticks_usec()-started)/1000.0)
	timing.sort()
	var cost:={"samples":timing.size(),"p95_ms":timing[ceili(timing.size()*.95)-1],"max_ms":timing[-1]}
	var report:={"success":failures.is_empty(),"checks":checks,"failures":failures,"mismatch_details":mismatch_details,"original_cases":packet.rows.size(),"capacity_cpu":cost,"scope":"Decoded active-rule/native-stat fixtures, actual native spell-gain owner, unchanged original prerequisite/getter corpus. No live draft/UI/server/pixels acceptance."}
	var file:=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close();print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
