extends SceneTree
# Actual native draft/UI-data owners, CPU only. Both installed content and the
# authorized pregame capture's available overrides are resolved by the catalog.
# Missing capture resources retain installed provenance; no public session runs.
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Text=preload("res://systems/native_data/talk_text.gd")
const Cache=preload("res://systems/native_data/ruleset_cache.gd")
const Values=preload("res://systems/native_data/character_record_values.gd")
const Creator=preload("res://systems/native_creation.gd")
const Level=preload("res://systems/native_level_up.gd")
const Game=preload("res://systems/native_data/game_ui_rules.gd")
class UiData extends RefCounted:
	var text
class DesktopData extends RefCounted:
	var owner_ui
	var rules
var report:={"success":false,"publicConnections":0,"gpuBenchmark":false,"cases":[],"failures":[]}
var current_case: Dictionary={}
func _initialize() -> void: call_deferred("run")
func table(catalog,text,name: String) -> void:
	name=name.to_lower()
	if name.is_empty() or name=="****" or text.tables.has(name): return
	var began:=Time.get_ticks_usec(); var bytes: PackedByteArray=catalog.get_resource(name,2017)
	if not catalog.failure.is_empty(): text.publish_table(name,{"orderedRows":[]}); return
	var parser:=preload("res://systems/native_data/two_da.gd").new(); var parsed: Dictionary=parser.parse(preload("res://systems/native_data/binary_data.gd").new(bytes).text(0,bytes.size()))
	text.publish_table(name,parsed)
	var location: Dictionary=catalog.location(name,2017)
	current_case.resources.append({"name":name,"sha256":preload("res://systems/native_data/prepared_cache.gd").digest(bytes),"binding":location.get("layer",{}).get("binding_identity",""),"read_decode_publish_ms":(Time.get_ticks_usec()-began)/1000.0})
func measure(name: String,operation: Callable) -> void:
	var times: Array=[]; var value: Variant=null
	for round_index in 12:
		var began:=Time.get_ticks_usec(); value=operation.call(); times.append((Time.get_ticks_usec()-began)/1000.0)
	times.sort(); current_case.timings[name]={"min_ms":times[0],"median_ms":times[6],"p95_ms":times[11],"result_sha256":preload("res://systems/native_data/prepared_cache.gd").digest(var_to_bytes(value))}
func meta_costs(game) -> Array:
	var result: Array=[]
	for mask in [1,2,4,8,16,32]: result.append(game.meta_cost(mask))
	return result
func run() -> void:
	var args: Dictionary={}
	for argument in OS.get_cmdline_user_args():
		var pair:=argument.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has_all(["install","capture","report"]) or FileAccess.file_exists(args.report): quit(2); return
	for use_capture in [false,true]:
		current_case={"source":"installed+captured-overrides" if use_capture else "installed","resources":[],"timings":{}}; report.cases.append(current_case)
		var catalog:=Catalog.new(); catalog.mount_install(args.install)
		if use_capture: catalog.mount_directory(str(args.capture).path_join("resources"),50000000)
		var text:=Text.new(); text.base.open_file(str(args.install).path_join("lang/en/data/dialog.tlk"))
		for name in ["classes","racialtypes","ruleset","skills","packages","feat","spells"]: table(catalog,text,name)
		for data in text.tables.classes.get("orderedRows",[]):
			for field in ["StatGainTable","SkillsTable","AttackBonusTable","SavingThrowTable","FeatsTable","BonusFeatsTable","SpellGainTable","SpellKnownTable","PreReqTable"]: table(catalog,text,str(Game.cell(data,field,"")))
		for data in text.tables.racialtypes.get("orderedRows",[]): table(catalog,text,str(Game.cell(data,"FeatsTable","")))
		current_case.ruleset_rows=text.tables.ruleset.get("orderedRows",[]).size(); current_case.owner_cache_active=Cache.current(text.tables)!=null
		var core_owner:=Cache.Owner.new(); var prototype:=core_owner.prepare(text.tables.ruleset,[1,current_case.source,1]); current_case.prototype_publication_ms=prototype.build_ms
		var fixture_ui:=UiData.new(); fixture_ui.text=text
		var creator:=Creator.new(); creator.connection=1; creator.draft_scope=1; creator.phase="editing"; creator.ui=fixture_ui; creator.rules.tables=text.tables; creator.rules.catalog=catalog; creator.rules.initialize()
		creator.rules.draft.raceId=6; creator.rules.select_class(10); creator.rules.creation_point_budget=30; creator.rules.record_ability_points(30)
		creator.rules.record_skill_points(30); var identity: Array=creator.summary_identity()
		measure("creation_attributes_model",func():return creator.attribute_source_model(identity))
		measure("creation_skills_model",func():return creator.skill_source_model(identity))
		measure("creation_ability_draft_up_down",func():var up: bool=creator.rules.change_ability(0,1); var down: bool=creator.rules.change_ability(0,-1); return [up,down,creator.rules.draft.abilities.duplicate(),creator.rules.point_balance()])
		var game:=Game.new(); game.text=text
		measure("record_six_abilities",func():return Values.abilities([12,14,14,16,8,10],[0,0,0,0,0,0],0,text.tables))
		measure("six_metamagic_costs",func():return meta_costs(game))
		var desktop:=DesktopData.new(); desktop.owner_ui=fixture_ui; desktop.rules=game; var level:=Level.new(); level.desktop=desktop; level.rules=game
		var ranks: Array=[]; ranks.resize(text.tables.skills.get("orderedRows",[]).size()); ranks.fill(0)
		level.snapshot={"classes":[{"id":10,"level":17}],"baseAbilities":[12,14,14,16,8,10],"race":6,"fieldDC6":0,"skills":ranks.duplicate()}; level.draft={"classId":10,"ability":6,"skills":ranks,"feats":[]}
		measure("level_up_skill_balance",func():return level.balance())
		measure("client_private_hp_constructor",func():return preload("res://systems/native_data/client_presentation_hp.gd").constructor(text.tables))
		if not creator.attribute_source_model(identity).get("ready",false) or not creator.skill_source_model(identity).get("ready",false): report.failures.append("Actual draft owner source is not ready: "+str(current_case.source))
		creator.phase="closed"; creator.free(); text.close(); core_owner.retire()
	report.success=report.failures.is_empty(); var output:=FileAccess.open(args.report,FileAccess.WRITE); output.store_string(JSON.stringify(report,"  ")+"\n"); output.close(); quit(0 if report.success else 1)
