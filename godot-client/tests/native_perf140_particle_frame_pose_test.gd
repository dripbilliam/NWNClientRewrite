extends "res://tests/native_particle_presentation_test.gd"
# Exact source/state/geometry oracle in an actual scheduled SceneTree. Both
# groups use ordinary per-owner conversion caching; only frame sharing differs.
class Tick extends Node:
	var invoke: Callable
	func _process(_delta: float) -> void:invoke.call()
var context:={"frame":0,"completed":0,"cache_hits":0,"cache_reads":0}
var groups: Array=[]
func owner_for(pose_node: Node3D,source: Node3D,reuse: bool) -> RefCounted:
	var seed_owner:=make_owner(false,"single",0,false,false)
	seed_owner.state.birthRate=1.0;seed_owner.state.lifeExp=2.5;seed_owner.state.velocity=0.5;seed_owner.state.mass=0.1;seed_owner.state.renderMode1a8=0
	var owner: RefCounted=ClassDB.instantiate("NwnParticleOwner")
	var result: Dictionary=owner.call("dispatch",0,{"state":seed_owner.state,"update":"single","compactRecords":true,"typedEmitter":true,"poseId":pose_node.get_instance_id(),"sourceId":source.get_instance_id(),"cacheEnginePose":true,"reuseFramePose":reuse},{})
	check(not result.has("error"),"Exact typed owner configures "+str(reuse))
	seed_owner.providers.clear();return owner
func create_group(scene: Node3D,reuse: bool) -> Dictionary:
	var mount_a:=Node3D.new();var mount_b:=Node3D.new();scene.add_child(mount_a);scene.add_child(mount_b)
	mount_b.position=Vector3(0.5,0.2,-0.3);mount_b.rotation=Vector3(0.1,0.2,-0.1)
	var source:=Node3D.new();mount_a.add_child(source)
	var presentation: RefCounted=ClassDB.instantiate("NwnParticlePresentation")
	var rng:=Random.new();rng.seed_value(851)
	var group:={"a":mount_a,"b":mount_b,"source":source,"presentation":presentation,"rng":rng,"owners":[],"poses":[],"nodes":[],"callbacks":[],"random_mutations":0,"fallback_mutations":0,"clock_mutations":0,"ready_mutations":0}
	for index in 8:
		var pose_node:=Node3D.new();source.add_child(pose_node);pose_node.position=Vector3(index*0.3,0.1,index*0.2)
		var node:=Node3D.new();pose_node.add_child(node)
		var owner:=owner_for(pose_node,source,reuse);group.owners.append(owner);group.poses.append(pose_node);group.nodes.append(node)
		var services:={"random":func():
			if index==3:
				source.position+=Vector3(0.03125,0,0);group.random_mutations+=1
			return rng.next(),"cosineDouble":func(angle):return cos(angle)}
		group.callbacks.append(services)
		var config:={"id":node.get_instance_id(),"owner":owner,"providers":services,"culling":true,"source_flags":0,"source_key":12345,"node_order":index}
		if index==4:config.clock=func():
			source.rotation+=Vector3(0,0.015625,0);group.clock_mutations+=1
			return {"clip":"","time":context.frame/60.0}
		if index==5:config.ready=func():
			source.position+=Vector3(0,0.015625,0);group.ready_mutations+=1
			return context.frame>=3
		check(not presentation.call("dispatch",0,config).has("error"),"Scheduled group registers "+str(index))
		if index==1:
			var fallback:=Node3D.new();source.add_child(fallback);group.nodes.append(fallback)
			check(not presentation.call("dispatch",0,{"id":fallback.get_instance_id(),"fallback":func(_delta):
				if context.frame%7==0:source.position+=Vector3(0,0,0.03125);group.fallback_mutations+=1
			}).has("error"),"Opaque fallback is interleaved with sources")
	return group
func before_tick() -> void:
	context.frame+=1
	for group: Dictionary in groups:
		var source: Node3D=group.source
		if context.frame in [30,60]:source.reparent(group.b if context.frame==30 else group.a,false)
		source.position=Vector3(sin(context.frame*0.017),0.3,cos(context.frame*0.023))
		source.rotation=Vector3(0.02,context.frame*0.001,0.01)
		source.scale=Vector3(1.2,0.8,1.1) if context.frame%40<20 else Vector3(-1,-1,-1)
		source.visible=context.frame not in [45,46,47]
		group.poses[2].process_mode=Node.PROCESS_MODE_DISABLED if context.frame%17==0 else Node.PROCESS_MODE_INHERIT
		group.poses[6].position=Vector3(context.frame*0.0001,0.1,0.3)
func compare_tick(second: bool=false) -> void:
	var results: Array=[]
	for group: Dictionary in groups:
		results.append(group.presentation.call("dispatch",1,{"delta":1.0/120.0,"view":view_packet(context.frame+8000000+(1000 if second else 0),context.frame%40<7),"profile":context.frame%5==0}))
	for slot in 2:check(not results[slot].has("error"),"Scheduled frame executes "+str(context.frame)+"/"+str(slot)+" "+str(results[slot].get("error","")))
	if results.any(func(v):return v.has("error")):context.completed=120;return
	for field in ["prepared","fallbacks","culled","active","vertices","draws"]:check(results[0][field]==results[1][field],"Exact admission/count "+field+" "+str(context.frame))
	var a: Dictionary=groups[0].presentation.call("dispatch",2,{})
	var b: Dictionary=groups[1].presentation.call("dispatch",2,{})
	check(a.buffer==b.buffer,"Byte-identical geometry with synchronous mutations "+str(context.frame))
	check(a.frame_pose_reuse.hits==0,"Disabled sharing oracle keeps original live reads")
	context.cache_hits+=int(b.frame_pose_reuse.hits);context.cache_reads+=int(b.frame_pose_reuse.reads)
	for index in 8:
		var expected: Dictionary=groups[0].owners[index].call("dispatch",2,{},{})
		var actual: Dictionary=groups[1].owners[index].call("dispatch",2,{},{})
		var difference:=same(without_ids(expected),without_ids(actual))
		check(difference.is_empty(),"Exact private simulation/source pose "+str(context.frame)+"/"+str(index)+" "+difference)
	check(groups[0].rng.state==groups[1].rng.state and groups[0].rng.draws==groups[1].rng.draws,"Exact shared RNG ordering "+str(context.frame))
func frame_tick() -> void:
	compare_tick()
	context.completed+=1
func after_tick() -> void:
	# This mutation occurs after the entire shared frame. Reuse must never carry
	# it over into another presentation call, even within one engine frame.
	for group: Dictionary in groups:group.source.position+=Vector3(0.0625,-0.03125,0.015625)
	# A second complete call within the SAME SceneTree frame is a new scope.
	# An engine-frame-stamped cache would incorrectly miss this mutation.
	if failures.is_empty():compare_tick(true)
func lifetime_edges(scene: Node3D) -> void:
	for reuse in [false,true]:
		var source:=Node3D.new();scene.add_child(source);var node:=Node3D.new();scene.add_child(node)
		var owner:=owner_for(node,source,reuse);var presentation: RefCounted=ClassDB.instantiate("NwnParticlePresentation")
		var services:={"random":func():return 1,"cosineDouble":func(angle):return cos(angle)}
		var old_id:=source.get_instance_id()
		check(not presentation.call("dispatch",0,{"id":node.get_instance_id(),"owner":owner,"providers":services,"culling":false,"clock":func():
			if is_instance_valid(source):source.free()
			return {}
		}).has("error"),"Removal-in-clock fixture registers")
		check(presentation.call("dispatch",1,{"delta":0.01,"view":view_packet(9000000+int(reuse),false)}).has("error"),"A clock cannot hide a freed source lifetime")
		var replacement:=Node3D.new();scene.add_child(replacement);check(replacement.get_instance_id()!=old_id,"Replacement has a distinct full engine lifetime")
		check(presentation.call("dispatch",1,{"delta":0.01,"view":view_packet(9000010+int(reuse),false)}).get("prepared",-1)==0,"A subsequent frame skips the original freed identity")
		presentation.call("dispatch",5,{})
		check(presentation.call("dispatch",2,{}).frame_pose_reuse.retained==0,"Closing retires transient source/pose storage even after an error")
		services.clear();node.free();replacement.free()
func run() -> void:
	var args: Dictionary={}
	for value in OS.get_cmdline_user_args():
		var pair:=value.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has("report") or FileAccess.file_exists(args.report):quit(2);return
	var scene:=Node3D.new();root.add_child(scene)
	groups=[create_group(scene,false),create_group(scene,true)]
	var early:=Tick.new();early.process_priority=-100;early.invoke=before_tick;root.add_child(early)
	var tick:=Tick.new();tick.process_priority=110;tick.invoke=frame_tick;root.add_child(tick)
	var late:=Tick.new();late.process_priority=200;late.invoke=after_tick;root.add_child(late)
	while context.completed<120 and failures.is_empty():await process_frame
	early.free();tick.free();late.free()
	check(context.completed==120 and context.cache_hits>100,"Sharing actually occurs without crossing frame/callback boundaries")
	for field in ["random_mutations","fallback_mutations","clock_mutations","ready_mutations"]:check(groups[0][field]>0 and groups[0][field]==groups[1][field],"Mutation barrier exercised "+field)
	for group: Dictionary in groups:
		for node: Node3D in group.nodes:group.presentation.call("dispatch",3,{"id":node.get_instance_id()})
		check(group.presentation.call("dispatch",2,{}).frame_pose_reuse.retained==0,"Membership removal evicts pose/source read values")
		group.presentation.call("dispatch",5,{})
		for services: Dictionary in group.callbacks:services.clear()
		group.presentation=null;group.owners.clear()
	lifetime_edges(scene);groups.clear();scene.free()
	await process_frame;await process_frame
	var report:={"success":failures.is_empty(),"checks":checks,"failures":failures,"cache":context,"network_connections":0,"gpu_execution":false,"scope":"Actual scheduled SceneTree owners before/after presentation; opaque random/fallback/readiness/clock mutations, reparent/reflected scales/hide/show/process disable, freed identity, exact native state and geometry/RNG. No FPS or graphics acceptance."}
	var file:=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close();quit(0 if failures.is_empty() else 1)
