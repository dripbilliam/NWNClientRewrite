extends "res://tests/native_render_gap_scene_boundary_callbacks_test.gd"

func observe(presentation: RefCounted) -> Dictionary:
	return presentation.call("dispatch",13,{})

func delta(after: Dictionary,before: Dictionary,key: String) -> int:
	return int(after.get(key,0))-int(before.get(key,0))

func short_circuits() -> void:
	var scene:=Node3D.new();root.add_child(scene)
	var pose:=Node3D.new();scene.add_child(pose)
	var emitter:=Node3D.new();pose.add_child(emitter)
	var source:=Node3D.new();scene.add_child(source)
	var owner:=boundary_owner(pose,source)
	var presentation: RefCounted=ClassDB.instantiate("NwnParticlePresentation")
	var clocks:=[0]
	var providers: Dictionary={"random":func():return 1,"cosineDouble":func(value):return cos(value)}
	check(not presentation.call("dispatch",0,{"id":emitter.get_instance_id(),"owner":owner,"providers":providers,"culling":false,"clock":func():clocks[0]+=1;return {"clip":"","time":0.0}}).has("error"),"Short-circuit owner registers")
	pose.hide();source.free()
	var before:=observe(presentation)
	var frame: Dictionary=presentation.call("dispatch",1,{"delta":0.01,"view":view_packet(19000000,false)})
	var after:=observe(presentation)
	check(not frame.has("error") and frame.prepared==0 and clocks[0]==0,"Hidden entry does not reach freed source or clock")
	if bool(after.direct_enabled):
		check(delta(after,before,"direct_eligibility_calls")==1 and delta(after,before,"direct_source_checks")==0 and delta(after,before,"direct_pose_calls")==0,"Failed visibility short-circuits source lookup and all pose reads")
	pose.show();before=after
	frame=presentation.call("dispatch",1,{"delta":0.01,"view":view_packet(19000001,false)})
	after=observe(presentation)
	check(not frame.has("error") and frame.prepared==0 and clocks[0]==0,"Eligible entry sees current dead source before clock")
	if bool(after.direct_enabled):check(delta(after,before,"direct_source_checks")==1 and delta(after,before,"direct_pose_calls")==0,"Live eligibility checks source exactly once without reading a pose")
	presentation.call("dispatch",5,{});presentation=null;owner=null;providers.clear();scene.free()

func callback_failure(first_pose: bool,readiness: bool,index: int) -> void:
	var scene:=Node3D.new();root.add_child(scene)
	var pose:=Node3D.new();scene.add_child(pose)
	var emitter:=Node3D.new();scene.add_child(emitter)
	var source:=Node3D.new();scene.add_child(source)
	var owner:=boundary_owner(pose,source)
	var presentation: RefCounted=ClassDB.instantiate("NwnParticlePresentation")
	var counts:=[0,0]
	var providers: Dictionary={"random":func():return 1,"cosineDouble":func(value):return cos(value)}
	var mutate: Callable=func():
		if first_pose:pose.free()
		else:source.free()
	var config: Dictionary={"id":emitter.get_instance_id(),"owner":owner,"providers":providers,"culling":false,"clock":func():
		counts[0]+=1
		if not readiness:mutate.call()
		return {"clip":"","time":0.0}}
	if readiness:config.ready=func():counts[1]+=1;mutate.call();return true
	check(not presentation.call("dispatch",0,config).has("error"),"Callback-failure owner registers "+str(index))
	var before:=observe(presentation)
	var frame: Dictionary=presentation.call("dispatch",1,{"delta":0.01,"view":view_packet(19000100+index,false)})
	var after:=observe(presentation)
	check(str(frame.get("error","")).contains("pose owner is absent"),"Current post-callback pose failure is retained "+str(index))
	check(counts[0]==1 and counts[1]==(1 if readiness else 0),"Readiness/clock are neither duplicated nor skipped "+str(index))
	check(delta(after,before,"pose_calls")== (1 if first_pose else 2) and delta(after,before,"pose_failures")==1,"First-pose failure prevents later source getter; source failure follows completed emitter conversion "+str(index))
	if bool(after.direct_enabled):check(delta(after,before,"direct_source_checks")==1 and delta(after,before,"direct_pose_calls")== (1 if first_pose else 2),"Actual fused precheck and separate later direct getters witnessed "+str(index))
	presentation.call("dispatch",5,{});presentation=null;owner=null;providers.clear();config.clear();mutate=Callable();scene.free()

func same_endpoint() -> void:
	var scene:=Node3D.new();root.add_child(scene)
	var emitter:=Node3D.new();scene.add_child(emitter)
	var owner:=boundary_owner(emitter,emitter)
	var presentation: RefCounted=ClassDB.instantiate("NwnParticlePresentation")
	var providers: Dictionary={"random":func():return 1,"cosineDouble":func(value):return cos(value)}
	check(not presentation.call("dispatch",0,{"id":emitter.get_instance_id(),"owner":owner,"providers":providers,"culling":false,"clock":func():emitter.position=Vector3(3,4,5);return {"clip":"","time":0.0}}).has("error"),"Shared-endpoint owner registers")
	var before:=observe(presentation)
	var frame: Dictionary=presentation.call("dispatch",1,{"delta":0.01,"view":view_packet(19000200,false)})
	var after:=observe(presentation)
	check(not frame.has("error") and frame.prepared==1,"Shared endpoint consumes current clock pose")
	check(delta(after,before,"pose_calls")==1,"Identical pose/source ID retains the existing single-getter shortcut")
	var state: Dictionary=owner.call("dispatch",2,{},{})
	check(same(state.source50.position,[3.0,-5.0,4.0]).is_empty(),"Current shared pose bytes reach native source state")
	presentation.call("dispatch",5,{});presentation=null;owner=null;providers.clear();scene.free()

func run() -> void:
	var report: String="";var expected: String=""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):report=arg.substr(9)
		if arg.begins_with("--expect-direct="):expected=arg.substr(16)
	if report.is_empty() or FileAccess.file_exists(report):quit(2);return
	var probe: RefCounted=ClassDB.instantiate("NwnParticlePresentation")
	var before:=observe(probe);probe=null
	if expected=="active":check(bool(before.direct_requested) and bool(before.direct_available) and bool(before.direct_enabled),"Direct interface is requested, ABI-compatible and active")
	elif expected=="absent":check(bool(before.direct_requested) and not bool(before.direct_available) and not bool(before.direct_enabled),"Old engine safely keeps established path without optional proc-name query")
	else:check(not bool(before.direct_enabled),"Explicit or default legacy route is retained")
	short_circuits()
	for first: bool in [true,false]:
		for ready: bool in [true,false]:callback_failure(first,ready,(2 if first else 0)+(1 if ready else 0))
	same_endpoint()
	await process_frame;await process_frame
	probe=ClassDB.instantiate("NwnParticlePresentation")
	var after:=observe(probe);probe=null
	var file:=FileAccess.open(report,FileAccess.WRITE)
	file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"before":before,"after":after,"network_connections":0,"gpu_execution":false,"scope":"Exact callback/getter ordering, source-precheck short circuits, separate first-pose failure, readiness mutation, same-ID pose/source shortcut and optional direct-interface fallback"},"\t"));file.close();quit(0 if failures.is_empty() else 1)
