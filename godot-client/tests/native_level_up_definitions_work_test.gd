extends SceneTree
const DefinitionWork=preload("res://systems/native_level_up_definitions_work.gd")
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const TwoDa=preload("res://systems/native_data/two_da.gd")
const Tables=preload("res://systems/native_data/creation_feat_tables.gd")
const SourceOwner=preload("res://systems/native_data/level_up_source_owner.gd")
var checks:=0
var failures: Array=[]
var observations: Array=[]
func _initialize() -> void:run.call_deferred()
func check(value: bool,label: String,detail: Variant=null) -> bool:
	checks+=1
	if not value:failures.append({"label":label,"detail":detail})
	return value
func wait_for(predicate: Callable) -> bool:
	var until:=Time.get_ticks_msec()+10000
	while Time.get_ticks_msec()<until:
		if predicate.call():return true
		await process_frame
	return false
func run() -> void:
	var args: Dictionary={}
	for argument in OS.get_cmdline_user_args():
		var pair:=argument.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has_all(["install","report"]) or FileAccess.file_exists(args.report):quit(2);return
	var catalog:=Catalog.new();check(catalog.mount_install(args.install),"Original feat table mounts read-only")
	var parser:=TwoDa.new();var table:=parser.parse(catalog.get_resource("feat",2017).get_string_from_ascii());var raw:=table.duplicate(true)
	check(parser.failure.is_empty() and not table.orderedRows.is_empty(),"Actual physical feat metadata parses without authored definitions")
	var began:=Time.get_ticks_usec();var expected:=Tables.decode(table);var oracle_usec:=Time.get_ticks_usec()-began
	check(expected.ready,"Plain original-backed synchronous oracle is available")
	var work:=DefinitionWork.new();root.add_child(work);var scope: Array=[10,7,42,1];var main_thread:=OS.get_thread_caller_id()
	began=Time.get_ticks_usec();var first:=work.warm(scope,catalog,0,table);var request_usec:=Time.get_ticks_usec()-began
	check(work.view(scope,catalog,0,table).get("pending",false) and work.task>=0,"Warm only schedules work; no decoded metadata is synchronously admitted")
	check(work.warm(scope,catalog,0,table)==first and int(work.stats.submitted)==1,"Identical current requests share the one active plain decode")
	if check(await wait_for(func():return work.view(scope,catalog,0,table).get("ready",false)),"Background plain decode completes under its exact current scope"):
		var decoded:=work.view(scope,catalog,0,table)
		check(decoded==expected,"Actual full decoded definitions equal the plain original-backed oracle")
		check(int(work.stats.lastThread)!=main_thread and int(work.stats.lastThread)!=0,"Tables.decode executes on a data worker rather than the input thread")
		check(is_same(decoded,work.view(scope,catalog,0,table)),"Repeated current reads borrow the same immutable decoded dictionary")
		var submitted:=int(work.stats.submitted);work.warm(scope,catalog,0,table)
		check(int(work.stats.submitted)==submitted,"Current ready definitions never decode again on ordinary reads")
	observations.append({"kind":"actual-installed-definitions","rows":table.orderedRows.size(),"oracleUsec":oracle_usec,"requestUsec":request_usec,"worker":work.snapshot(),"mainThread":main_thread})
	work.set_process(false)
	var older: Array=[10,7,42,2];var latest: Array=[10,7,42,4];work.warm(older,catalog,0,table)
	var old_task:=work.task;work.warm([10,7,42,3],catalog,0,table);work.warm(latest,catalog,1,table)
	check(work.task==old_task and not work.pending.is_empty() and int(work.stats.peakActive)==1,"Replacement requests retain one active decode and only the latest pending request")
	check(not work.view(older,catalog,0,table).get("ready",false),"An old transaction cannot borrow prior accepted definitions")
	work.set_process(true)
	if check(await wait_for(func():return work.view(latest,catalog,1,table).get("ready",false)),"The latest scope and same-object catalog generation complete"):
		check(int(work.stats.stale)>=1 and int(work.stats.coalesced)>=1,"Old completion and replaced pending request are explicitly retired")
		check(work.view(latest,catalog,1,table)==expected,"Coalescing changes ownership only, never the decoded physical values")
	var replacement: Dictionary=table.duplicate(true);var current: Array=[10,7,42,5]
	work.warm(current,catalog,1,replacement)
	check(not work.view(current,catalog,1,table).get("ready",false),"Equal table contents with a different physical publication do not alias ownership")
	check(await wait_for(func():return work.view(current,catalog,1,replacement).get("ready",false)),"A new exact table identity gets its own decode")
	var next: Array=[10,7,42,6];work.set_process(false);work.warm(next,catalog,1,table);var retired_task:=work.task
	began=Time.get_ticks_usec();work.retire();var retire_usec:=Time.get_ticks_usec()-began
	check(work.task==retired_task and not work.view(next,catalog,1,table).get("ready",false) and int(work.stats.closeUsec)==0,"Normal retirement invalidates immediately without joining the uncompleted task")
	work.set_process(true);check(await wait_for(func():return work.task<0),"Retired data task and cleanup are reaped after completion")
	var broken:={"orderedRows":[{"Feat":"0xZ"}],"defaultValue":"****"};var bad_scope: Array=[10,7,42,7]
	work.warm(bad_scope,catalog,1,broken)
	if check(await wait_for(func():return not work.view(bad_scope,catalog,1,broken).get("pending",false)),"Malformed native integer decoding completes as an explicit failure"):
		var failure:=work.view(bad_scope,catalog,1,broken);check(not failure.ready and not str(failure.get("reason","")).is_empty(),"A decode failure cannot become accepted empty feat definitions")
	var late_scope: Array=[10,7,42,8];work.warm(late_scope,catalog,1,null)
	check(work.view(late_scope,catalog,1,null).get("pending",false),"A missing table remains explicitly pending without a guessed empty table")
	work.warm(late_scope,catalog,1,table);check(await wait_for(func():return work.view(late_scope,catalog,1,table).get("ready",false)),"Accepted late physical metadata unblocks the same current owner")
	var foreign:=RefCounted.new();check(not work.view(late_scope,foreign,1,table).get("ready",false),"A replacement catalog cannot consume an old decoded dictionary")
	var unconfigured:=SourceOwner.new();check(unconfigured.feat_definitions().get("pending",false) and unconfigured.snapshot().get("pending",false),"An unconfigured source owner stays pending and has no synchronous decode fallback")
	if args.has("custom-feat"):
		var custom_parser:=TwoDa.new();var custom:=custom_parser.parse(FileAccess.get_file_as_string(args["custom-feat"]));var custom_before:=custom.duplicate(true);var custom_expected:=Tables.decode(custom);var custom_scope: Array=[10,7,42,10]
		check(custom_parser.failure.is_empty() and custom_expected.ready,"Exact captured active custom feat table parses and has an original-backed oracle")
		work.warm(custom_scope,catalog,1,custom)
		if check(await wait_for(func():return work.view(custom_scope,catalog,1,custom).get("ready",false)),"Actual cached custom metadata is decoded on the same scoped data worker"):
			check(work.view(custom_scope,catalog,1,custom)==custom_expected and custom==custom_before,"Every custom physical definition/value is preserved without default stock substitution or raw mutation")
			observations.append({"kind":"captured-active-custom-definitions","rows":custom.orderedRows.size(),"worker":work.snapshot()})
	work.warm([10,7,42,9],catalog,1,replacement);work.close()
	check(work.closed and work.task<0 and work.active==null,"Actual close drains only this owner's single CPU task")
	observations.append({"kind":"retirement","retireUsec":retire_usec,"close":work.snapshot()})
	check(table==raw,"Worker decode and all ownership transitions preserve raw active feat metadata")
	work.queue_free();await process_frame
	var file:=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"observations":observations,"scope":"Actual installed plain Tables.decode on one private WorkerThreadPool task, exact graph equality and thread identity, one-active/latest coalescing, scope/catalog/generation/physical-table guards, late/malformed metadata, nonblocking retirement and bounded owned close. No game peer, candidate model or graphics acceptance."},"\t"));file.close();quit(0 if failures.is_empty() else 1)
