extends SceneTree
const Text=preload("res://systems/native_data/talk_text.gd")
const Cache=preload("res://systems/native_data/ruleset_cache.gd")
const Values=preload("res://systems/native_data/character_record_values.gd")
const CreationRules=preload("res://systems/native_data/creation_rules.gd")
const Game=preload("res://systems/native_data/game_ui_rules.gd")
const HP=preload("res://systems/native_data/client_presentation_hp.gd")
const Level=preload("res://systems/native_level_up.gd")
class UiData extends RefCounted:
	var text
class Front extends Node:
	func owns(ticket: Array) -> bool: return ticket==[1]
class ColdCreator extends "res://systems/native_creation.gd":
	var fixture_completions:=0
	var fixture_serial:=0
	func render() -> void: pass
	func _process(_delta: float) -> void:
		var queued: Array=resource_queue.duplicate(); resource_queue.clear()
		for job in queued:
			fixture_serial+=1; jobs[fixture_serial]=job
			prepared(fixture_serial,{"error":"","value":{"orderedRows":[{"SkillIndex":0}]},"bytes":PackedByteArray()}); fixture_completions+=1
	func close() -> void:
		dead=true; resource_queue.clear(); jobs.clear()
var checks:=0
var failures: Array=[]
func _initialize() -> void: call_deferred("run")
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures.append(label); print("FAIL ",label)
func run() -> void:
	var output:=""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="): output=argument.substr(9)
	if output.is_empty() or FileAccess.file_exists(output): quit(2); return
	var text:=Text.new(); var initial:={"orderedRows":[{"Label":"Test","Value":"4"}]}
	text.publish_table("ruleset",initial); var first=Cache.current(text.tables); var first_view: Dictionary=text.tables.duplicate()
	check(text.revision==1 and first!=null and Values.cfg(text.tables,"Test",8)==4,"A ruleset publication builds once and increments text revision exactly once")
	check(not initial.is_read_only() and text.tables.ruleset.is_read_only() and text.tables.ruleset.orderedRows[0].is_read_only(),"Talk publishes an isolated recursively immutable source while leaving caller input mutable")
	initial.orderedRows[0].Value="9"; check(Values.cfg(text.tables,"Test",8)==4,"Caller-side in-place mutation cannot change published values")
	text.publish_table("ruleset",initial); var second=Cache.current(text.tables)
	check(text.revision==2 and second!=first and Cache.current(first_view)==null and Values.cfg(text.tables,"Test",8)==9,"Republishing the same modified caller input retires the preceding generation")
	text.publish_table("classes",{"orderedRows":[]})
	check(text.revision==3 and Cache.current(text.tables)==second,"Unrelated table publication does not rebuild or retire the active ruleset")
	text.tables.ruleset={"orderedRows":[{"Label":"Test","Value":"12tail"}]}
	check(Cache.current(text.tables)==null and Values.cfg(text.tables,"Test",8)==12,"A direct source replacement bypasses the old cache and uses native fallback")
	text.publish_table("ruleset",{}); var error_view: Dictionary=text.tables.duplicate()
	check(text.revision==4 and Values.cfg(text.tables,"Test",8)==8 and Cache.current(text.tables)!=null,"An explicit unavailable-table publication increments once and keeps missing values as caller defaults")
	text.close(); check(Cache.current(error_view)==null and text.tables.is_empty() and Values.cfg(text.tables,"Test",8)==8,"Closing the text owner retires leases and clears current sources")
	# Confirm the corrected native parser for all previously divergent consumers.
	var raw:={"ruleset":{"orderedRows":[{"Label":"CHARGEN_BASE_ABILITY_MIN","Value":"0x12"},{"Label":"chargen_base_ability_min","Value":"99"},{"Label":"SPELL_METAMAGIC_EMPOWER_COST","Value":"3tail"},{"Label":"SPELL_METAMAGIC_EMPOWER_COST","Value":"****"},{"Label":"spell_metamagic_empower_cost","Value":"9"}]}}
	var rules:=CreationRules.new(); rules.tables=raw; var game:=Game.new(); game.text=text; text.tables=raw
	check(Values.cfg(raw,"CHARGEN_BASE_ABILITY_MIN",8)==0 and rules.cfg("BASE_ABILITY_MIN",8)==0 and HP.cfg(raw,"CHARGEN_BASE_ABILITY_MIN",8)==0,"Uncached native record/creation/private-HP callers use exact labels and decimal prefix parsing")
	check(game.meta_cost(1)==3 and game.meta_cost(2)==1,"Metamagic preserves original last nonempty exact label and missing-cost default")
	raw.ruleset.orderedRows.append_array([{"Label":"EPIC_GREAT_STAT_BONUS","Value":"2tail"},{"Label":"epic_great_stat_bonus","Value":"99"}])
	var level:=Level.new(); level.rules=game; level.desktop={"owner_ui":{"text":text}}; level.snapshot={"classes":[],"baseAbilities":[10,10,10,10,10,10],"race":0}; level.draft={"classId":0,"ability":6,"feats":[814]}
	check(level.abilities()==[12,10,10,10,10,10],"Native level-up Epic ability bonus uses the same exact-label decimal-prefix ruleset getter")
	text.close(); text=Text.new(); var fixture_ui:=UiData.new(); fixture_ui.text=text
	var creator:=ColdCreator.new(); creator.ui=fixture_ui; creator.rules.tables=text.tables; creator.connection=1; creator.draft_scope=1; creator.phase="editing"; creator.source_frontend=Front.new(); creator.add_child(creator.source_frontend); root.add_child(creator)
	var baseline:=text.revision
	creator.jobs[91]={"kind":"table","key":"cold_preference","name":"cold_preference"}; creator.prepared(91,{"error":"","value":{"orderedRows":[{"SkillIndex":0}]}})
	check(text.revision==baseline and creator.rules.tables.has("cold_preference"),"Non-ruleset preference completion keeps the recommendation wait's revision unchanged")
	creator.jobs[92]={"kind":"table","key":"ruleset","name":"ruleset"}; creator.prepared(92,{"error":"","value":{"orderedRows":[{"Label":"Test","Value":"5"}]}})
	var created_view: Dictionary=text.tables.duplicate()
	check(text.revision==baseline+1 and Values.cfg(text.tables,"Test",8)==5,"Creator ruleset completion publishes through its existing shared text owner once")
	creator.jobs[93]={"kind":"table","key":"ruleset","name":"ruleset"}; creator.prepared(93,{"error":"Owned fixture error"})
	check(text.revision==baseline+2 and Cache.current(created_view)==null and Values.cfg(text.tables,"Test",8)==8,"Creator ruleset error retires its preceding cache with one unavailable publication")
	text.publish_table("ruleset",{"orderedRows":[{"Label":"CHARGEN_BASE_ABILITY_MIN","Value":"8"},{"Label":"CHARGEN_ABILITY_NEUTRAL_VALUE","Value":"10"},{"Label":"CHARGEN_ABILITY_MODIFIER_INCREMENT","Value":"2"},{"Label":"CHARGEN_ENABLE_RECOMMENDED_BUTTON","Value":"1"},{"Label":"CHARGEN_SKILL_MAX_LEVEL_1_BONUS","Value":"3"}]})
	text.publish_table("classes",{"orderedRows":[{"PlayerClass":1,"SkillsTable":"class_skills","SkillPointBase":2,"HitDie":8,"Package":0}]}); text.publish_table("racialtypes",{"orderedRows":[{"SkillPointModifierAbility":"Int","FirstLevelSkillPointsMultiplier":4}]})
	text.publish_table("skills",{"orderedRows":[{"Name":100,"Description":101,"Untrained":1,"AllClassesCanUse":1,"KeyAbility":"INT","Icon":"isk_fixture"}]}); text.publish_table("class_skills",{"orderedRows":[{"SkillIndex":0,"ClassSkill":1}]})
	text.publish_table("packages",{"orderedRows":[{"ClassID":0,"PlayerClass":1,"Name":102,"Description":103,"SkillPref2DA":"cold_skill_pref"}]}); text.overrides={100:"Skill",101:"Description",102:"Package",103:"Package description"}
	creator.rules.draft={"classId":0,"raceId":0,"packageId":0,"abilities":{"Str":12,"Dex":12,"Con":12,"Int":12,"Wis":12,"Cha":12},"skills":{},"feats":[],"known":{},"memorized":{},"domains":[],"school":0}; creator.rules.record_skill_points(4)
	baseline=text.revision; var result: Dictionary=await creator.edit_source_skills("recommend",0,creator.summary_identity(),[1])
	check(result.get("ready",false) and creator.phase=="editing" and creator.rules.draft.skills.get(0)==4 and creator.fixture_completions==1 and text.revision==baseline,"Actual cold Skills recommendation loads its own preference then completes without self-cancellation")
	text.tables.erase("cold_skill_pref"); creator.requested.clear(); creator.rules.draft.skills={}; creator.rules.record_skill_points(4)
	result=await creator.commit_source_package("automatic",0,creator.summary_identity(),[1])
	check(result.get("accepted",false) and creator.phase=="editing" and creator.rules.draft.skills.get(0)==4 and creator.fixture_completions==2 and text.revision==baseline,"Actual cold Package recommendation completes its own resource wait and native draft assignment")
	creator.close(); creator.free(); text.close(); await process_frame
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"publicConnections":0,"gpuBenchmark":false},"  ")+"\n"); file.close(); quit(0 if failures.is_empty() else 1)
