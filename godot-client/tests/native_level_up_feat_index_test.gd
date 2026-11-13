extends SceneTree
# Copied-only before/after operation context. No production State import change.
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Parser=preload("res://systems/native_data/two_da.gd")
const Metadata=preload("res://systems/native_data/level_up_class_metadata.gd")
const Tables=preload("res://systems/native_data/creation_feat_tables.gd")
const SkillTables=preload("res://systems/native_data/pregame_skills.gd")
const State=preload("res://systems/native_data/level_up_feat_state.gd")
const Index=preload("res://systems/native_data/creation_feat_context.gd")
const Loop=preload("res://systems/native_data/level_up_feat_recommendations.gd")
const Plan=preload("res://systems/native_data/level_up_recommendation_plan.gd")
const Text=preload("res://systems/native_data/talk_text.gd")
const DirectSnapshot=preload("res://systems/native_data/level_up_feat_snapshot.gd")
class OperationState extends State:
	const PreparedContext=preload("res://systems/native_data/creation_feat_context.gd")
	var use_index:=false
	var trace: Array=[]
	func snapshot(rules,text) -> Dictionary:
		var value: Dictionary=super.snapshot(rules,text)
		if value.get("ready",false):
			if use_index:
				if not value.source.has(PreparedContext.KEY):value.source=PreparedContext.prepare(value.source)
			else:
				# After production integration, reconstruct only the former raw
				# policy view. No metadata, choice or actor field is substituted.
				value.source=value.source.duplicate();value.source.erase(PreparedContext.KEY)
		return value
	func candidate(source: Dictionary,id: int) -> Dictionary:
		var answer: Dictionary=super.candidate(source,id)
		trace.append([id,bool(answer.get("ready",false)),bool(answer.get("allowed",false))]);return answer
var checks:=0
var failures: Array=[]
var observations: Array=[]
func sha256(bytes: PackedByteArray) -> String:
	var context:=HashingContext.new();context.start(HashingContext.HASH_SHA256);context.update(bytes);return context.finish().hex_encode()
func _initialize() -> void:run.call_deferred()
func check(value: bool,label: String,detail: Variant=null) -> bool:
	checks+=1
	if not value:failures.append({"label":label,"detail":detail})
	return value
func read(catalog,name: String,tables: Dictionary,reads: Array) -> void:
	if name.is_empty() or name=="****" or tables.has(name):return
	var bytes: PackedByteArray=catalog.get_resource(name,2017);var parser:=Parser.new();var table:=parser.parse(bytes.get_string_from_ascii())
	tables[name]=table if parser.failure.is_empty() else {};reads.append({"name":name,"bytes":bytes.size(),"sha256":sha256(bytes),"error":parser.failure})
func find_label(table: Dictionary,label: String) -> int:
	for at in table.get("orderedRows",[]).size():
		var cell:=Tables.cell(table,at,"Label")
		if cell.found and str(cell.text).to_lower()==label:return at
	return -1
func verdicts(state,source: Dictionary) -> Dictionary:
	var started:=Time.get_ticks_usec();var ordered: Array=[]
	for id in source.definitions.size():
		var answer: Dictionary=state.candidate(source,id)
		if not answer.get("ready",false):return {"ready":false,"id":id,"answer":answer}
		ordered.append([id,bool(answer.allowed)])
	return {"ready":true,"ordered":ordered,"usec":Time.get_ticks_usec()-started}
func operation_pair(received: Dictionary,class_id: int,ranks: Array,tables: Dictionary,text,kind: String) -> Dictionary:
	var plain:=OperationState.new();var indexed:=OperationState.new();indexed.use_index=true
	var observations: Dictionary={};var context: Dictionary={"baseFortitude":3}
	plain.configure(received,class_id,-1,ranks,context);indexed.configure(received,class_id,-1,ranks,context)
	for operation in ["cold_model","cached_model","reentry_model","validate"]:
		if operation=="reentry_model":
			plain.configure(received,class_id,-1,ranks,context);indexed.configure(received,class_id,-1,ranks,context)
		plain.trace.clear();indexed.trace.clear()
		var began:=Time.get_ticks_usec();var first: Dictionary=plain.validate(tables,text) if operation=="validate" else plain.model(tables,text);var plain_usec:=Time.get_ticks_usec()-began
		began=Time.get_ticks_usec();var second: Dictionary=indexed.validate(tables,text) if operation=="validate" else indexed.model(tables,text);var indexed_usec:=Time.get_ticks_usec()-began
		check(first.get("ready",false) and second.get("ready",false) and first==second,"Whole operation result matches "+kind+"/"+operation)
		check(plain.trace==indexed.trace,"Whole operation candidate verdict/order matches "+kind+"/"+operation)
		observations[operation]={"plainUsec":plain_usec,"indexedUsec":indexed_usec,"candidateTrace":plain.trace.duplicate(true),"resultSha256":sha256(JSON.stringify(first).to_utf8_buffer()),"plainDefinitionBuilds":plain.builds,"indexedDefinitionBuilds":indexed.builds,"plainModelBuilds":plain.model_builds,"indexedModelBuilds":indexed.model_builds}
	return observations
func direct_pair(received: Dictionary,class_id: int,ranks: Array,tables: Dictionary,kind: String) -> Dictionary:
	# The real no-Feat route uses compose directly. Indexing candidates cannot
	# speed a branch that never invokes State or its candidate evaluator.
	var context: Dictionary={"baseFortitude":3};var began:=Time.get_ticks_usec()
	var first:=DirectSnapshot.compose(received,class_id,-1,ranks,tables,context);var default_usec:=Time.get_ticks_usec()-began
	began=Time.get_ticks_usec();var decoded:=Tables.decode(tables.feat);var decode_usec:=Time.get_ticks_usec()-began
	began=Time.get_ticks_usec();var second:=DirectSnapshot.compose(received,class_id,-1,ranks,tables,context,[],decoded);var prepared_usec:=Time.get_ticks_usec()-began
	check(first.get("ready",false) and second.get("ready",false) and first==second,"Default decode and caller-prepared whole Snapshot results exactly match "+kind)
	began=Time.get_ticks_usec();var raw_first:=DirectSnapshot.compose(received,class_id,-1,ranks,tables,context);var raw_second:=DirectSnapshot.compose(received,class_id,-1,ranks,tables,context);var two_raw_usec:=Time.get_ticks_usec()-began
	began=Time.get_ticks_usec();var fast_first:=DirectSnapshot.compose(received,class_id,-1,ranks,tables,context,[],decoded);var fast_second:=DirectSnapshot.compose(received,class_id,-1,ranks,tables,context,[],decoded);var two_prepared_usec:=Time.get_ticks_usec()-began
	check(raw_first.get("ready",false) and fast_first.get("ready",false) and raw_first==fast_first and raw_second==fast_second,"Two-call no-Feat callback data reproduction is byte-for-value equal "+kind)
	return {"defaultUsec":default_usec,"decodeUsec":decode_usec,"preparedUsec":prepared_usec,"twoDefaultCallsUsec":two_raw_usec,"twoPreparedCallsUsec":two_prepared_usec,"sourceSha256":sha256(JSON.stringify(first).to_utf8_buffer()),"normal":first.get("source",{}).get("normal"),"bonus":first.get("source",{}).get("bonus"),"noProductionCacheChange":true}
func profile(catalog,text,kind: String,class_label: String,prior_class_label: String="",class_level: int=2) -> void:
	print("LEVEL_UP_FEAT_PROFILE begin "+kind)
	var tables: Dictionary={};var reads: Array=[]
	for name in ["classes","racialtypes","ruleset","skills","feat","masterfeats","packages"]:read(catalog,name,tables,reads)
	var class_id:=find_label(tables.classes,class_label);var race_id:=find_label(tables.racialtypes,"human")
	if not check(class_id>=0 and race_id>=0,"Actual active labels resolve physical mode1 class/race "+kind):return
	var compiled:=Metadata.compile(tables.classes)
	if not check(compiled.ready,"Native private mode1 class compilation is ready "+kind,compiled.get("unknown",[])):return
	var raw:=tables.duplicate(true);tables=tables.duplicate();tables.classes=compiled.table
	var class_ids: Array=[]
	if not prior_class_label.is_empty():
		var prior:=find_label(tables.classes,prior_class_label)
		if not check(prior>=0,"Actual active prior multiclass record resolves "+kind):return
		class_ids.append(prior)
	class_ids.append(class_id)
	for id in class_ids:
		var cls: Dictionary=tables.classes.orderedRows[id]
		for field in ["SkillsTable","FeatsTable","StatGainTable","AttackBonusTable","BonusFeatsTable","SpellGainTable","SpellKnownTable"]:read(catalog,SkillTables.table_name(cls,field),tables,reads)
	var race: Dictionary=tables.racialtypes.orderedRows[race_id];read(catalog,SkillTables.table_name(race,"FeatsTable"),tables,reads)
	var package:=Tables.integer(tables.classes,class_id,"Package")
	if not check(package.ready and package.ok,"Profile receives an explicit active class Package for authored mode1 context "+kind):return
	var ranks: Array=[];ranks.resize(tables.skills.orderedRows.size()&255);ranks.fill(0)
	var received:={"actorId":42,"race":race_id,"classes":class_ids.map(func(id):return {"id":id,"level":class_level,"school":0}),"baseAbilities":[14,14,14,14,14,14],"feats":[],"skills":ranks.duplicate(),"fieldD4":int(package.value)};var before:=received.duplicate(true)
	# This is an explicitly authored advanced mode1 disclosure. It is not an
	# inferred first-level creature or proof of a specific server actor's feats.
	var state:=State.new();state.configure(received,class_id,-1,ranks,{"baseFortitude":3});state.view.tables=tables
	var began:=Time.get_ticks_usec();var current:=state.snapshot(state.view,text);var snapshot_usec:=Time.get_ticks_usec()-began
	if not check(current.get("ready",false),"Actual advanced mode1 snapshot/current context is ready "+kind,current):return
	var expected_production_index: bool=OS.get_cmdline_user_args().has("--production-index=true")
	if expected_production_index:check(current.source.has(Index.KEY),"Actual production mode1 Snapshot prepares its operation index "+kind)
	var source: Dictionary=current.source.duplicate();source.erase(Index.KEY);var source_before:=source.duplicate(true);var plain:=verdicts(state,source);began=Time.get_ticks_usec();var indexed:=Index.prepare(source);var index_usec:=Time.get_ticks_usec()-began;var optimized:=verdicts(state,indexed)
	if expected_production_index:check(current.source[Index.KEY]==indexed[Index.KEY],"Production index preserves exact first-match class flags "+kind)
	check(plain.ready and optimized.ready and plain.ordered==optimized.ordered,"Every physical candidate verdict and order matches the raw class-record policy "+kind)
	var plan:=Plan.feats(received,class_id,tables);var preference: Dictionary={}
	if plan.get("pending",false):
		for name in plan.get("dependencies",[]):read(catalog,str(name),tables,reads)
		plan=Plan.feats(received,class_id,tables)
	if check(plan.get("ready",false) and plan.get("invoked",false),"Actual active mode1 preference context is available "+kind,plan):
		var preferences: Dictionary=tables.get(str(plan.name),{});began=Time.get_ticks_usec();var first:=Loop.apply(source,preferences,bool(plan.loaded),state.candidate);var first_usec:=Time.get_ticks_usec()-began
		began=Time.get_ticks_usec();var second:=Loop.apply(indexed,preferences,bool(plan.loaded),state.candidate);var second_usec:=Time.get_ticks_usec()-began
		check(first.get("ready",false) and second.get("ready",false) and first==second,"Original preference-only selection/order/remaining/reads match before and after indexing "+kind,{"plain":first,"indexed":second})
		preference={"plan":plan,"plain":first,"indexed":second,"plainUsec":first_usec,"indexedUsec":second_usec}
	check(received==before and source==source_before and raw.classes!=tables.classes,"Operation index preserves borrowed received/source state and raw active classes "+kind)
	var operations:=operation_pair(received,class_id,ranks,tables,text,kind);var direct:=direct_pair(received,class_id,ranks,tables,kind)
	check(received==before and raw.classes!=tables.classes,"Whole-operation probes preserve received/raw classes "+kind)
	observations.append({"kind":kind,"classId":class_id,"raceId":race_id,"authoredReceived":received,"definitions":source.definitions.size(),"classRecords":source.classes[source.current].feats.size(),"snapshotUsec":snapshot_usec,"plainCandidatesUsec":plain.get("usec"),"indexUsec":index_usec,"indexedCandidatesUsec":optimized.get("usec"),"allowed":plain.get("ordered",[]).filter(func(row):return row[1]).size(),"candidateVerdicts":plain.get("ordered",[]),"preference":preference,"operations":operations,"directSnapshot":direct,"reads":reads})
	print("LEVEL_UP_FEAT_PROFILE complete "+kind+" checks="+str(checks))
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has_all(["install","fixture","report"]) or FileAccess.file_exists(args.report):quit(2);return
	var base:=Catalog.new();var custom:=Catalog.new();var fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(str(args.fixture).path_join("fixture.json")))
	check(base.mount_install(args.install) and custom.mount_install(args.install) and custom.mount_nwsync(str(fixture.manifest),str(args.fixture).path_join("nwsync"),"","",100000001),"Actual base and full captured custom namespace mount read-only without helper/network")
	var base_text:=Text.new();var custom_text:=Text.new();check(base_text.base.open_file(str(args.install).path_join("lang/en/data/dialog.tlk")) and custom_text.base.open_file(str(args.install).path_join("lang/en/data/dialog.tlk")) and custom_text.custom.open_file(str(args.fixture).path_join("resources/arelith.tlk")),"Original and exact captured custom TLK supply native names")
	profile(base,base_text,"installed_fighter","fighter");profile(custom,custom_text,"captured_warlock","warlock");profile(custom,custom_text,"captured_multiclass_warlock","warlock","fighter")
	profile(base,base_text,"installed_wizard_level16","wizard","",15)
	base_text.close();custom_text.close();base=null;custom=null
	var file:=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"observations":observations,"productionIndexExpected":OS.get_cmdline_user_args().has("--production-index=true"),"rawReferenceRemovesOnlyIndex":true,"serverConnections":0,"gpu":false,"scope":"Candidate CPU/context comparison using actual installed and sealed cached custom active tables/TLK plus explicitly authored advanced mode1 received snapshots. Every physical verdict/order, whole model/validation and preference result compared against the raw class-record policy. After integration, raw-reference whole-operation timing includes the production index construction before discarding its key; historical before79 remains the uncontaminated pre-index timing. Not actual input latency/server actor/pixel/FPS acceptance."},"\t"));file.close();quit(0 if failures.is_empty() else 1)
