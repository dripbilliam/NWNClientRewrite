extends "res://tests/native_creation_character_names_test.gd"
const Service=preload("res://systems/native_character_names.gd")
const Recorded=preload("res://systems/native_data/recorded_catalog.gd")
var replies:Array=[]
func wait_for(test:Callable,seconds:float=10.0)->bool:
	var end:=Time.get_ticks_msec()+int(seconds*1000)
	while Time.get_ticks_msec()<end:
		if test.call():return true
		await process_frame
	return false
func write_file(path:String,bytes:PackedByteArray)->void:
	var file:=FileAccess.open(path,FileAccess.WRITE);file.store_buffer(bytes);file.close()
func run()->void:
	var args:Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has_all(["install","report"]) or FileAccess.file_exists(args.report):quit(2);return
	var catalog:=Catalog.new();check(catalog.mount_install(args.install),"Installed resource catalog mounts privately")
	var prepared:=Names.plan({"status":"ready","value":table("human","elf")},6,1)
	var names:=Service.new();root.add_child(names);names.names_ready.connect(func(id,value):replies.append({"id":id,"value":value.duplicate(true)}))
	var duplicate_plan:=prepared.duplicate(true);duplicate_plan.resources.append(duplicate_plan.resources[0]);names.configure(catalog,[1],duplicate_plan)
	check(not names.failure.is_empty() and names.requests.is_empty() and names.request_names([1])<0,"An oversized/duplicate resource plan cannot create an unbounded preparation queue")
	names.configure(catalog,[100,1,7],prepared)
	prepared.resources.clear();check(names.plan.resources.size()==4,"The owner takes a detached current resource plan")
	check(names.request_names([100,1,7])<0,"No random request precedes current resource and filter preparation")
	var ready:bool=await wait_for(func():return names.resources_ready or not names.failure.is_empty())
	check(ready and names.resources_ready,"All four active original letter tables prepare through actual native asset workers: "+names.failure)
	if names.resources_ready:
		check(names.diagnostics.letters.size()==4 and names.diagnostics.letters.values().all(func(row):return int(row.thread)!=OS.get_main_thread_id() and str(row.sha256).length()==64),"Every table is decoded off the UI thread with source byte provenance")
		var id:=names.request_names([100,1,7]);check(id>0 and names.request_names([100,1,7])<0 and names.request_names([100,1,8])<0,"One job globally; duplicate and stale-context requests are rejected")
		check(await wait_for(func():return replies.size()==1) and replies[0].id==id and replies[0].value.ready,"One scoped first/last result is published asynchronously")
		check(int(names.diagnostics.generationWorkerThread)!=OS.get_main_thread_id(),"Probability generation runs on a real native worker")
		replies[0].value.scope.append("caller mutation");check(names.scope==[100,1,7],"A result cannot mutate owner scope")
		id=names.request_names([100,1,7]);var next_plan:=Names.plan({"status":"ready","value":table("dwarf","")},0,0)
		names.configure(catalog,[101,1,7],next_plan)
		check(id>0 and names.request_names([101,1,7])<0 and not names.job.is_empty(),"Replacing context keeps at most the one draining retired worker")
		check(await wait_for(func():return names.resources_ready and names.job.is_empty()) and replies.size()==1,"A completed old generation never publishes into a replacement scope")
		id=names.request_names([101,1,7]);check(id>0 and await wait_for(func():return replies.size()==2) and replies[1].value.resources==["dwarfm","dwarfl"],"Replacement active names use their new prepared resources")
		names.configure(catalog,[102,1,7],next_plan)
		check(await wait_for(func():return names.resources_ready) and names.diagnostics.letters.values().all(func(row):return row.cacheHit),"Reopening unchanged source content reuses existing decoded resource cache")
	var directory:=str(args.report)+".bad-filter";DirAccess.make_dir_recursive_absolute(directory)
	write_file(directory.path_join("namefilter.2da"),"invalid optional NameFilter".to_ascii_buffer())
	var bad:=Catalog.new();check(bad.mount_install(args.install) and bad.mount_directory(directory,100000001),"Private active filter override mounts separately")
	var plan:=Names.plan({"status":"ready","value":table("human","")},6,0)
	names.configure(bad,[200,1],plan)
	check(await wait_for(func():return names.resources_ready or not names.failure.is_empty()) and names.resources_ready and names.filters_known and names.filters.is_empty() and names.diagnostics.get("filterLoadFailed",false),"A known optional NameFilter parse/load failure preserves the original unfiltered path")
	var gap_directory:=str(args.report)+".capture-gap";DirAccess.make_dir_recursive_absolute(gap_directory.path_join("objects"))
	var bytes:PackedByteArray=catalog.get_resource("humanm",2036);var sha:=preload("res://systems/native_data/prepared_cache.gd").digest(bytes)
	write_file(gap_directory.path_join("objects").path_join(sha),bytes)
	var manifest:Dictionary={"version":2,"complete":true,"availability":{"humanm:2036":1,"humanl:2036":1,"namefilter:2017":1},"resources":{"humanm:2036":{"sha256":sha,"bytes":bytes.size()},"humanl:2036":{"sha256":sha,"bytes":bytes.size()}}}
	write_file(gap_directory.path_join("manifest.json"),JSON.stringify(manifest).to_utf8_buffer())
	var gap:=Recorded.new();check(gap.mount(gap_directory),"Closed-world missing capture fixture mounts")
	names.configure(gap,[300,1],plan)
	check(await wait_for(func():return not names.failure.is_empty()) and not names.resources_ready and names.request_names([300,1])<0,"Missing NameFilter bytes are unavailable, never confused with an optional native load failure")
	names.configure(catalog,[400,1],plan)
	if await wait_for(func():return names.resources_ready):
		var before:=replies.size();var id:=names.request_names([400,1]);names.close();await process_frame
		check(id>0 and names.job.is_empty() and names.assets.running.is_empty() and replies.size()==before,"Close drains both resource and generation workers and suppresses the final stale reply")
	names.close();check(names.request_names([400,1])<0 and not names.available([400,1]),"Closed owner cannot be revived by an old request")
	names.free();await process_frame
	var file:=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"gpu":false,"serverConnections":0,"scope":"Staged name-pair service using actual installed LTR/resource workers, generation workers, source cache, explicit filter parse failure versus capture gap, detached scope/plan, replacement/duplicate/stale/close. No creator UI/draft/BIC/runtime integration."},"\t")+"\n");file.close();quit(0 if failures.is_empty() else 1)
