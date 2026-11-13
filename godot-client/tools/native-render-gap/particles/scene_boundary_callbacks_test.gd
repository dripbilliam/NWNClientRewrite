extends "res://tests/native_particle_presentation_test.gd"
func boundary_owner(pose: Node3D,source: Node3D) -> RefCounted:
	var seed: Dictionary=make_owner(false,"fountain",0,false,false);seed.state.birthRate=0.0
	var owner: RefCounted=ClassDB.instantiate("NwnParticleOwner")
	check(not owner.call("dispatch",0,{"state":seed.state,"update":"fountain","compactRecords":true,"typedEmitter":true,"poseId":pose.get_instance_id(),"sourceId":source.get_instance_id()},{}).has("error"),"Live boundary owner configures")
	seed.providers.clear();return owner
func run() -> void:
	var report: String=""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):report=arg.substr(9)
	if report.is_empty() or FileAccess.file_exists(report):quit(2);return
	var scene: Node3D=Node3D.new();root.add_child(scene)
	var first: Node3D=Node3D.new();scene.add_child(first);first.process_mode=Node.PROCESS_MODE_ALWAYS
	var parent: Node3D=Node3D.new();scene.add_child(parent)
	var alternate: Node3D=Node3D.new();scene.add_child(alternate);alternate.position=Vector3(17,9,4)
	var pose: Node3D=Node3D.new();parent.add_child(pose)
	var emitter: Node3D=Node3D.new();pose.add_child(emitter)
	var source: Node3D=Node3D.new();scene.add_child(source)
	var context: Dictionary={"frame":0,"source":source,"second_clocks":0,"first_clocks":0}
	var presentation: RefCounted=ClassDB.instantiate("NwnParticlePresentation")
	var owners: Array[RefCounted]=[boundary_owner(first,first),boundary_owner(pose,source)]
	var providers: Dictionary={"random":func() -> int:return 1,"cosineDouble":func(value: float) -> float:return cos(value)}
	var first_clock: Callable=func() -> Dictionary:
		context.first_clocks+=1
		match int(context.frame):
			0:parent.position=Vector3(2,3,4)
			1:parent.hide()
			2:parent.show();emitter.process_mode=Node.PROCESS_MODE_DISABLED
			3:emitter.process_mode=Node.PROCESS_MODE_ALWAYS;paused=true
			4:paused=false;pose.reparent(alternate,false)
			5:context.source.free();context.source=null
			8:alternate.remove_child(pose)
			9:alternate.add_child(pose)
		return {"clip":"","time":float(context.frame)*0.03}
	var second_clock: Callable=func() -> Dictionary:
		context.second_clocks+=1;pose.position=Vector3(float(context.frame),0.2,0.3)
		if int(context.frame)==10:context.source.free();context.source=null
		else:context.source.position=Vector3(float(context.frame)+0.4,0.5,-0.6)
		return {"clip":"","time":float(context.frame)*0.03}
	check(not presentation.call("dispatch",0,{"id":first.get_instance_id(),"owner":owners[0],"providers":providers,"culling":false,"clock":first_clock}).has("error"),"First mutating clock registers")
	check(not presentation.call("dispatch",0,{"id":emitter.get_instance_id(),"owner":owners[1],"providers":providers,"culling":false,"clock":second_clock}).has("error"),"Later live consumer registers")
	for frame: int in 12:
		context.frame=frame
		if frame==6:
			var replacement: Node3D=Node3D.new();scene.add_child(replacement);context.source=replacement
		if frame==7:
			var previous: WeakRef=weakref(owners[1]);presentation.call("dispatch",3,{"id":emitter.get_instance_id()})
			owners[1]=boundary_owner(pose,context.source)
			check(previous.get_ref()==null,"Same-ID re-add releases previous native owner")
			check(not presentation.call("dispatch",0,{"id":emitter.get_instance_id(),"owner":owners[1],"providers":providers,"culling":false,"clock":second_clock}).has("error"),"Same emitter ID binds a fresh source owner")
		var output: Dictionary=presentation.call("dispatch",1,{"delta":0.016,"view":view_packet(17000000+frame,false)})
		if frame==10:
			check(str(output.get("error","")).contains("pose owner is absent"),"Clock-free after source precheck fails at the original fresh pose boundary")
			continue
		var admitted: bool=frame in [0,3,4,7,9]
		check(not output.has("error") and int(output.prepared)==(2 if admitted else 1),"Later eligibility/source read sees earlier same-frame mutation "+str(frame))
		if admitted:
			var state: Dictionary=owners[1].call("dispatch",2,{},{});var expected: Vector3=context.source.global_position
			check(same(state.source50.position,[expected.x,-expected.z,expected.y]).is_empty(),"Later clock pose mutation is consumed live "+str(frame))
	check(context.first_clocks==12 and context.second_clocks==6,"No hidden clock invocation or missed required clock")
	var boundary: Dictionary=presentation.call("dispatch",13,{})
	check(bool(boundary.enabled)==OS.get_cmdline_user_args().has("--particle-scene-boundary=native"),"Requested exact-boundary route")
	if boundary.enabled:check(int(boundary.pose_failures)==1 and int(boundary.eligibility_reads)>0 and int(boundary.pose_reads)>0,"Successful typed reads plus exact same-frame missing pose failure witnessed")
	paused=false;presentation.call("dispatch",5,{});presentation=null;owners.clear();providers.clear();first_clock=Callable();second_clock=Callable();context.clear();scene.free()
	await process_frame;await process_frame
	var file: FileAccess=FileAccess.open(report,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"boundary":boundary,"network_connections":0,"gpu_execution":false,"scope":"Earlier clock mutates later eligibility/ancestry/process/pause/source lifetime; later clock mutates current pose or frees its source after source precheck; same-ID re-add and replacement lifetimes"},"\t"));file.close();quit(0 if failures.is_empty() else 1)
