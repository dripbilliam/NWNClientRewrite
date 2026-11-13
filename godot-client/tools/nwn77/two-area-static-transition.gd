extends SceneTree

const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Pool=preload("res://systems/native_render/resource_pool.gd")
const AreaStream=preload("res://systems/native_render/area_stream.gd")

var checks:=0
var failures: Array=[]
var observations: Array=[]

func _initialize() -> void: call_deferred("run")
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures.append(label)
func wait_area(stream: Node,timeout_ms: int=45000) -> bool:
	var deadline:=Time.get_ticks_msec()+timeout_ms
	while not stream.done and Time.get_ticks_msec()<deadline: await process_frame
	return stream.done
func wait_static(stream: Node,timeout_ms: int=12000) -> bool:
	var deadline:=Time.get_ticks_msec()+timeout_ms
	while stream.static_scenery_batches.has_pending() and Time.get_ticks_msec()<deadline: await process_frame
	return not stream.static_scenery_batches.has_pending()
func source_ids(owner: Node) -> Array:
	var values: Array=owner.members.keys()
	values.sort()
	return values
func run() -> void:
	var args: Dictionary={}
	for argument in OS.get_cmdline_user_args():
		var pair:=argument.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	var report:=str(args.get("report",""));var fixture_path:=str(args.get("fixture",""))
	if report.is_empty() or fixture_path.is_empty() or FileAccess.file_exists(report):quit(2);return
	var fixture=JSON.parse_string(FileAccess.get_file_as_string(fixture_path))
	if not fixture is Dictionary:quit(2);return
	var catalog:=Catalog.new();var mounted:=catalog.mount_install(str(fixture.install)) and catalog.mount_erf(str(fixture.module),4000000)
	check(mounted,"Pinned original install and local module mount: "+catalog.failure)
	check(FileAccess.get_sha256(str(fixture.module))==str(fixture.moduleSha256),"Local original module bytes match fixture")
	var host:=Node3D.new();root.add_child(host)
	var pool:=Pool.new();var stream:=AreaStream.new();host.add_child(stream)
	stream.maximum_tiles_per_frame=3
	check(stream.static_scenery_mode=="merged" and OS.get_cmdline_user_args().has("--static-scenery=merged"),"Actual opt-in merged route selected by command line")
	var cache_path:=OS.get_temp_dir().path_join("nwn77-two-area-"+str(OS.get_process_id())+"-"+str(Time.get_ticks_usec()))
	var previous_ids: Array=[];var old_model: WeakRef;var old_draw: WeakRef;var previous_generation:=-1
	for name in ["dense_a","dense_b"]:
		stream.open_area(catalog,name,pool,cache_path)
		var initial=stream.static_scenery_batches.snapshot()
		if name=="dense_b":
			check(int(initial.active_batches)==0 and int(initial.active_batched_surfaces)==0 and int(initial.pending_workers)==0,"Area B starts without A's active groups, suppressed draws or worker IDs")
			check(stream.static_scenery_batches.members.is_empty() and stream.static_scenery_batches.groups.is_empty(),"Area B owns no stale A source IDs at scope start")
			check(old_model==null or old_model.get_ref()==null or old_model.get_ref().is_queued_for_deletion(),"A original model retired at B start")
			check(old_draw==null or old_draw.get_ref()==null or old_draw.get_ref().is_queued_for_deletion(),"A merged draw retired at B start")
		check(await wait_area(stream),"Area "+name+" definition/model publication finishes")
		check(await wait_static(stream),"Area "+name+" merged draw workers and publication drain")
		var state: Dictionary=stream.snapshot();var static_state: Dictionary=state.static_scenery
		observations.append({"name":name,"generation":stream.generation,"area":state,"active_source_ids":source_ids(stream.static_scenery_batches)})
		check(bool(state.success) and int(state.rendered_tiles)==100 and int(state.failed_tiles)==0 and stream.instances.size()==100,"Area "+name+" publishes all original local tiles")
		check(bool(static_state.enabled) and str(static_state.mode)=="material-cell-merged","Area "+name+" uses the actual merged owner")
		check(int(static_state.pending_groups)==0 and int(static_state.pending_workers)==0,"Area "+name+" static merge is settled")
		check(int(static_state.active_batched_surfaces)>0 and int(static_state.active_batches)>0 and int(static_state.source_draws_replaced)>0,"Area "+name+" actually replaces source draws")
		check(stream.generation>previous_generation,"Area "+name+" has a fresh scope generation")
		var ids:=source_ids(stream.static_scenery_batches)
		if name=="dense_b":
			var shared: Array=[]
			for id in ids:
				if previous_ids.has(id):shared.append(id)
			check(shared.is_empty(),"Area B merged membership has no A source IDs")
			for _frame in 3:await process_frame
			check(old_model==null or old_model.get_ref()==null,"A model releases after B settles")
			check(old_draw==null or old_draw.get_ref()==null,"A merged draw releases after B settles")
		else:
			previous_ids=ids
			if stream.instances.has(0):old_model=weakref(stream.instances[0])
			for group in stream.static_scenery_batches.groups.values():
				if is_instance_valid(group.get("geometry")):
					old_draw=weakref(group.geometry);break
		previous_generation=stream.generation
	stream.close()
	check(stream.static_scenery_batches.members.is_empty() and stream.static_scenery_batches.groups.is_empty() and stream.static_scenery_batches.worker_tasks().is_empty(),"Close joins B workers and clears replacement ownership")
	check(stream.instances.is_empty() and stream.definition_task==-1 and stream.assets.running.is_empty(),"Close drains B original model and definition owners")
	host.free();pool.clear()
	for _frame in 2:await process_frame
	var hashes: Dictionary={}
	for name in ["systems/native_render/area_stream.gd","systems/native_render/static_scenery_batches.gd","systems/native_render/static_scenery_merge.gd","systems/native_render/static_scenery_merge_data.gd","tools/nwn77/two-area-static-transition.gd"]:
		hashes[name]=FileAccess.get_sha256("res://"+name)
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Two distinct original local ARE areas, real AreaStream opt-in static merge, source/draw/worker scope retirement; headless correctness only, no FPS or live-server visual acceptance","fixture":fixture_path,"fixture_sha256":FileAccess.get_sha256(fixture_path),"areas":observations,"source_sha256":hashes}
	var file:=FileAccess.open(report,FileAccess.WRITE)
	if file!=null:file.store_string(JSON.stringify(result,"\t")+"\n");file.close()
	print("NWN77_TWO_AREA ",checks," checks ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
