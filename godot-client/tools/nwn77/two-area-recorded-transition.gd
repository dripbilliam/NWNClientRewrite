extends "res://tools/nwn77/two-area-static-transition.gd"

const RecordedCatalog=preload("res://systems/native_data/recorded_catalog.gd")

func run() -> void:
	var args: Dictionary={}
	for argument in OS.get_cmdline_user_args():
		var pair:=argument.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	var report:=str(args.get("report",""));var input_path:=str(args.get("capture-areas",""))
	if report.is_empty() or input_path.is_empty() or FileAccess.file_exists(report):quit(2);return
	var input=JSON.parse_string(FileAccess.get_file_as_string(input_path))
	if not input is Dictionary or not input.get("areas") is Array or input.areas.size()!=3:quit(2);return
	check(FileAccess.get_sha256(str(input.catalog).path_join("manifest.json"))==str(input.catalogManifestSha256),"Recorded resource catalog manifest matches source pin")
	var catalog:=RecordedCatalog.new()
	check(catalog.mount(str(input.catalog)),"Saved original-resource catalog mounts: "+catalog.failure)
	var host:=Node3D.new();root.add_child(host)
	var pool:=Pool.new();var stream:=AreaStream.new();host.add_child(stream)
	# The normal saved selection publishes NativeMaterial on this route. Without
	# these flags every original surface falls back as material-not-native-static.
	pool.native_lighting=OS.get_cmdline_user_args().has("--native-lighting=enhanced")
	pool.native_surface_output=OS.get_cmdline_user_args().has("--native-surface-output=true")
	check(pool.native_lighting and pool.native_surface_output,"Saved normal-client native lighting/surface flags reproduced")
	var model_environment=preload("res://systems/native_render/model_environment.gd").new();host.add_child(model_environment)
	model_environment.configure(catalog,pool)
	stream.definition_ready.connect(func(definition):model_environment.receive_definition(definition))
	stream.maximum_tiles_per_frame=3
	check(stream.static_scenery_mode=="merged" and OS.get_cmdline_user_args().has("--static-scenery=merged"),"Actual opt-in merged route selected by command line")
	var cache_path:=OS.get_temp_dir().path_join("nwn77-captured-two-area-"+str(OS.get_process_id())+"-"+str(Time.get_ticks_usec()))
	var first_ids: Array=[];var old_a_model: WeakRef;var old_a_draw: WeakRef;var previous_generation:=-1
	for index in input.areas.size():
		var entry: Dictionary=input.areas[index];var area: Dictionary=entry.area;var name:=str(area.resRef)
		stream.open_network_area(catalog,area,pool,cache_path)
		var fresh: Dictionary=stream.static_scenery_batches.snapshot()
		if index>0:
			check(int(fresh.active_batches)==0 and int(fresh.active_batched_surfaces)==0 and int(fresh.pending_workers)==0,"Transition "+str(index)+" clears previous active batches, draws and worker IDs")
			check(stream.static_scenery_batches.members.is_empty() and stream.static_scenery_batches.groups.is_empty(),"Transition "+str(index)+" starts without old source IDs")
		check(await wait_area(stream,60000),"Recorded area "+name+" definition and model publication finish")
		check(await wait_static(stream,20000),"Recorded area "+name+" merge workers and publication settle")
		var state: Dictionary=stream.snapshot();var stat: Dictionary=state.static_scenery;var ids:=source_ids(stream.static_scenery_batches)
		observations.append({"name":name,"capture_sequence":entry.sequence,"capture_generation":entry.generation,"stream_generation":stream.generation,"area":state,"environment":model_environment.snapshot(),"active_source_ids":ids})
		check(bool(state.success) and int(state.rendered_tiles)==area.tiles.size() and int(state.failed_tiles)==0,"Recorded area "+name+" publishes all original tile placements")
		check(bool(stat.enabled) and str(stat.mode)=="material-cell-merged" and int(stat.pending_workers)==0 and int(stat.pending_groups)==0,"Recorded area "+name+" has a settled merged owner")
		check(stream.generation>previous_generation,"Recorded area "+name+" gets a fresh local scope generation")
		if index==0:
			check(int(stat.active_batched_surfaces)>0 and int(stat.active_batches)>0 and int(stat.source_draws_replaced)>0,"First original area actually suppresses source draws")
			first_ids=ids
			if stream.instances.has(0):old_a_model=weakref(stream.instances[0])
			for group in stream.static_scenery_batches.groups.values():
				if is_instance_valid(group.get("geometry")):
					old_a_draw=weakref(group.geometry);break
			check(old_a_model!=null and old_a_draw!=null,"First original area has both a concrete model and replacement draw to retire")
		elif index==1:
			for _frame in 3:await process_frame
			check(old_a_model==null or old_a_model.get_ref()==null,"First area model releases after loading-area transition")
			check(old_a_draw==null or old_a_draw.get_ref()==null,"First area merged draw releases after loading-area transition")
		elif index==2:
			check(int(stat.active_batched_surfaces)>0 and int(stat.active_batches)>0,"Reentered original area rebuilds real merged draws")
			var shared: Array=[]
			for id in ids:
				if first_ids.has(id):shared.append(id)
			check(shared.is_empty(),"Reentered original area uses no source ID from first lifetime")
			check(int(stat.active_batched_surfaces)==int(observations[0].area.static_scenery.active_batched_surfaces) and int(stat.active_batches)==int(observations[0].area.static_scenery.active_batches),"Reentered original area recovers same active merge coverage")
		previous_generation=stream.generation
	stream.close()
	check(stream.static_scenery_batches.members.is_empty() and stream.static_scenery_batches.groups.is_empty() and stream.static_scenery_batches.worker_tasks().is_empty(),"Final close joins workers and clears source/draw ownership")
	check(stream.instances.is_empty() and stream.definition_task==-1 and stream.assets.running.is_empty(),"Final close drains model and definition owners")
	host.free();pool.clear()
	for _frame in 2:await process_frame
	var hashes: Dictionary={}
	for path in ["systems/native_render/area_stream.gd","systems/native_render/static_scenery_batches.gd","systems/native_render/static_scenery_merge.gd","systems/native_render/static_scenery_merge_data.gd","tools/nwn77/two-area-static-transition.gd","tools/nwn77/two-area-recorded-transition.gd"]:
		hashes[path]=FileAccess.get_sha256("res://"+path)
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Saved original generation-2 225-tile area to distinct generation-1 loading area and back, normal native lighting/surface flags, actual opt-in static merge and lifetime retirement; headless correctness only, no FPS or GPU visual acceptance","capture_areas_sha256":FileAccess.get_sha256(input_path),"recording_sha256":input.recordingSha256,"engine_sha256":FileAccess.get_sha256(OS.get_executable_path()),"flags":OS.get_cmdline_user_args(),"areas":observations,"source_sha256":hashes}
	var file:=FileAccess.open(report,FileAccess.WRITE)
	if file!=null:file.store_string(JSON.stringify(result,"\t")+"\n");file.close()
	print("NWN77_RECORDED_TWO_AREA ",checks," checks ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
