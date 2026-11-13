extends "res://tests/native_name_generation_test.gd"
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Service=preload("res://systems/native_associate_names.gd")
var replies: Array=[]
func wait_for(test: Callable,seconds: float=10.0) -> bool:
	var end:=Time.get_ticks_msec()+int(seconds*1000)
	while Time.get_ticks_msec()<end:
		if test.call():return true
		await process_frame
	return false
func write_file(path: String,data: PackedByteArray) -> void:
	var file:=FileAccess.open(path,FileAccess.WRITE);file.store_buffer(data);file.close()
func mounted(install: String,directory: String=""):
	var catalog:=Catalog.new()
	if not catalog.mount_install(install):return null
	if not directory.is_empty() and not catalog.mount_directory(directory,100000001):return null
	return catalog
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has_all(["install","report"]) or FileAccess.file_exists(args.report):quit(2);return
	var catalog=mounted(args.install);check(catalog!=null,"Original catalog mounts read-only")
	var names:=Service.new();root.add_child(names);names.name_ready.connect(func(id,result):replies.append({"id":id,"result":result.duplicate(true)}))
	var installed: Dictionary={};var input_samples: Array=[]
	if catalog!=null:
		names.configure(catalog,[1,1]);check(names.request_name([1,1])<0,"Preparation never fabricates a name before resources arrive")
		if check(await wait_for(func():return names.resources_ready or not names.failure.is_empty()) and names.resources_ready,"Original familiar LTR/filter resources prepare through actual native assets: "+names.failure):
			var raw: PackedByteArray=catalog.get_resource("familiar",2036);installed={"sha256":digest(raw),"bytes":raw.size(),"letters":names.table.count,"filters":names.filters.duplicate(),"workerThread":names.diagnostics.workerThread}
			check(names.diagnostics.letterSha256==installed.sha256 and int(names.diagnostics.workerThread)!=OS.get_main_thread_id(),"Original LTR decoding runs on an actual native asset worker")
			write_file(str(args.report)+".familiar.ltr",raw)
			var id:=names.request_name([1,1]);check(id>0 and names.request_name([1,1])<0 and names.request_name([9,9])<0,"One current generation request is admitted; duplicate/stale scope requests are rejected")
			check(await wait_for(func():return replies.size()==1) and replies[0].id==id and replies[0].result.ready and replies[0].result.name.length()>=4,"Installed LTR generates an actual scoped name asynchronously")
			check(int(names.diagnostics.generationWorkerThread)!=OS.get_main_thread_id(),"Probability generation itself runs on a native worker rather than the UI thread")
			var detached: Dictionary=replies[0].result;detached.scope.append("caller mutation");check(names.scope==[1,1],"Emitted results cannot mutate the live owner scope")
			var stale:=names.request_name([1,1]);names.configure(catalog,[1,2])
			check(await wait_for(func():return names.resources_ready) and names.diagnostics.decodeCacheHit,"Reopening the same content reuses the existing native decoded cache")
			await process_frame;await process_frame;check(replies.size()==1 and stale>0,"A generation completed after context replacement cannot emit into the next scope")
			for turn in 8:
				var began:=Time.get_ticks_usec();id=names.request_name([1,2]);input_samples.append((Time.get_ticks_usec()-began)/1000.0)
				check(id>0 and await wait_for(func():return replies.size()==turn+2) and replies[-1].result.ready,"Repeated native name request completes "+str(turn))
			check(input_samples.max()<50.0,"Dispatching generation avoids synchronous probability work: "+str(input_samples))
	var fixture:=str(args.report)+".override";DirAccess.make_dir_recursive_absolute(fixture)
	var fixture_bytes:=content(3);write_file(fixture.path_join("familiar.ltr"),fixture_bytes)
	var expected_seed:=RandomNumberGenerator.new();expected_seed.seed=1;var work_seed:=expected_seed.randi();var expected_rng:=RandomNumberGenerator.new();expected_rng.seed=work_seed
	var banned: Dictionary=Generator.new().generate(Letters.decode(fixture_bytes),func():return expected_rng.randi_range(0,32767),[])
	write_file(fixture.path_join("namefilter.2da"),("2DA V2.0\nName\n0 "+str(banned.name).to_lower()+"\n").to_ascii_buffer())
	var active=mounted(args.install,fixture);check(active!=null,"Authored active override catalog mounts separately")
	if active!=null:
		names.configure(active,[2,1])
		if check(await wait_for(func():return names.resources_ready or not names.failure.is_empty()) and names.resources_ready,"Active override LTR and NameFilter prepare"):
			check(names.table.count==3 and names.filters==[str(banned.name).to_lower()] and names.diagnostics.letterSha256==digest(fixture_bytes),"Active catalog overrides select their own probabilities and filters: "+str({"letters":names.table.count,"filters":names.filters,"expectedFilter":str(banned.name).to_lower(),"sha256":names.diagnostics.letterSha256,"expectedSha256":digest(fixture_bytes)}))
			names.random.seed=1;var before:=replies.size();var id:=names.request_name([2,1]);check(await wait_for(func():return replies.size()>before) and replies[-1].id==id and replies[-1].result.ready and str(replies[-1].result.name).to_lower()!=str(banned.name).to_lower(),"Actual worker rejects the filtered first candidate using the active override")
	var bad:=str(args.report)+".bad-filter";DirAccess.make_dir_recursive_absolute(bad);write_file(bad.path_join("familiar.ltr"),fixture_bytes);write_file(bad.path_join("namefilter.2da"),"not a 2DA".to_ascii_buffer())
	var invalid=mounted(args.install,bad)
	if invalid!=null:
		names.configure(invalid,[3,1]);check(await wait_for(func():return names.resources_ready or not names.failure.is_empty()) and names.resources_ready and names.filters.is_empty() and names.diagnostics.get("filterLoadFailed",false),"An actual optional NameFilter parse/load failure preserves original no-filter admission")
	var gap_dir:=str(args.report)+".capture-gap";DirAccess.make_dir_recursive_absolute(gap_dir.path_join("objects"));var fixture_sha:=digest(fixture_bytes);write_file(gap_dir.path_join("objects").path_join(fixture_sha),fixture_bytes)
	var manifest:={"version":2,"complete":true,"availability":{"familiar:2036":1,"namefilter:2017":1},"resources":{"familiar:2036":{"sha256":fixture_sha,"bytes":fixture_bytes.size()}}};write_file(gap_dir.path_join("manifest.json"),JSON.stringify(manifest).to_utf8_buffer())
	var gap=preload("res://systems/native_data/recorded_catalog.gd").new();check(gap.mount(gap_dir),"Authored closed-world capture-gap fixture mounts")
	names.configure(gap,[4,1]);check(await wait_for(func():return not names.failure.is_empty()) and not names.resources_ready and names.request_name([4,1])<0,"Missing recorded filter bytes remain unavailable instead of pretending an original optional load failure")
	if active!=null:
		names.configure(active,[5,1]);await wait_for(func():return names.resources_ready);var before:=replies.size();var id:=names.request_name([5,1]);names.close();await process_frame
		check(id>0 and replies.size()==before and names.jobs.is_empty() and names.assets.running.is_empty(),"Close drains generation/assets without publishing a late scoped result")
	names.free();await process_frame
	var file:=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"installed":installed,"requestDispatchMs":input_samples,"scope":"Actual native asset worker/decoded cache and asynchronous scoped generation using installed familiar LTR, active override/filter, stale/duplicate/cancel/close and optional parse failure versus capture gap. No actual creator UI/draft/BIC/server/upload/GPU/pixel acceptance.","gpu":false,"serverConnections":0},"\t"));file.close();quit(0 if failures.is_empty() else 1)
