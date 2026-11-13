extends "res://tests/native_particle_presentation_test.gd"
class DormantClock:
	extends RefCounted
class ActivatedClock:
	extends RefCounted
	func sample() -> Dictionary:
		var context: Dictionary=get_meta("context")
		context.events.append(["clock",context.frame]);context.common.animating=true
		var denied: Dictionary=context.presentation.call("dispatch",15,{"enabled":false})
		context.events.append(["timing_reconfigure_rejected",denied.has("error")])
		var nested: Dictionary=context.presentation.call("dispatch",1,context.common)
		context.events.append(["nested_frame_rejected",nested.has("error")])
		return {"clip":"","time":float(context.frame)*0.125}
func small_owner(node: Node3D) -> RefCounted:
	var source: Dictionary=make_owner(false,"fountain",32,false,false);source.state.birthRate=12.0
	var owner: RefCounted=ClassDB.instantiate("NwnParticleOwner")
	check(not owner.call("dispatch",0,{"state":source.state,"update":"fountain","compactRecords":true,"typedEmitter":true,"poseId":node.get_instance_id(),"sourceId":node.get_instance_id()},{}).has("error"),"Setup owner configures")
	source.providers.clear();return owner
func scenario(bound: bool) -> Dictionary:
	var scene: Node3D=Node3D.new();root.add_child(scene)
	var nodes: Array[Node3D]=[]
	for index: int in 4:
		var node: Node3D=Node3D.new();scene.add_child(node);nodes.append(node)
	var presentation: RefCounted=ClassDB.instantiate("NwnParticlePresentation")
	check(not presentation.call("dispatch",15,{"enabled":true,"stride":1,"setup_boundary":bound,"reset":true}).has("error"),"Whole-frame sampler and exact mode configure")
	var context: Dictionary={"frame":0,"common":{},"events":[],"presentation":presentation}
	var fallback: Callable=func(_delta: float) -> void:
		context.events.append(["fallback",context.frame])
		if int(context.frame)==2:context.common.animating=null
		elif int(context.frame) in [1,4,5]:context.common.animating=false
		else:context.common.erase("animating")
	check(not presentation.call("dispatch",0,{"id":nodes[0].get_instance_id(),"fallback":fallback}).has("error"),"Earlier opaque fallback remains synchronous")
	var target: RefCounted=DormantClock.new();target.set_meta("context",context)
	var standard: Callable=Callable(target,"sample")
	check(not standard.is_valid() and not standard.is_null(),"Nonempty initially invalid standard clock")
	var resource: RefCounted=RefCounted.new();var resource_weak: WeakRef=weakref(resource)
	var owners: Array[RefCounted]=[];var rngs: Array=[];var providers: Array=[]
	for index: int in 3:
		var owner: RefCounted=small_owner(nodes[index+1]);owners.append(owner)
		var rng: RefCounted=Random.new();rng.seed_value(440+index);rngs.append(rng)
		var service: Dictionary={"cosineDouble":func(value: float) -> float:return cos(value)}
		service.random=func() -> int:
			context.events.append(["random",index,context.frame])
			if index==1:context.common.erase("animating")
			else:context.common.animating=false
			return rng.next()
		providers.append(service)
		var clock: Variant=standard if index==0 else Callable() if index==1 else resource
		check(not presentation.call("dispatch",0,{"id":nodes[index+1].get_instance_id(),"owner":owner,"providers":service,"clock":clock,"clip_length":0.5,"culling":false}).has("error"),"Immutable clock route registers "+str(index))
		clock=null
	resource=null
	check(resource_weak.get_ref()!=null,"Non-Callable clock retains its existing resource lifetime")
	var snapshots: Array=[]
	for frame: int in 6:
		context.frame=frame;context.common={"delta":0.1,"view":view_packet(23000000+frame,false),"profile":frame==5}
		if frame==1:target.set_script(ActivatedClock)
		if frame==3:target=null
		if frame==4:
			var custom: Callable=func() -> Dictionary:
				context.events.append(["custom_clock",context.frame]);context.common.animating=true
				return {"clip":"","time":-0.125}
			presentation.call("dispatch",4,{"id":nodes[1].get_instance_id(),"clock":custom})
			presentation.call("dispatch",4,{"id":nodes[3].get_instance_id(),"clock":Callable()})
			check(resource_weak.get_ref()==null,"Clock replacement releases resource at the same boundary")
		var output: Dictionary=presentation.call("dispatch",1,context.common)
		check(output.has("error")==bool(frame==2),"Present nil animating error and recovery order "+str(frame))
		output.erase("phases")
		var row: Dictionary={"output":output,"states":[],"clocks":[],"rngs":[],"events":context.events.duplicate(true)}
		for index: int in owners.size():
			row.states.append(without_ids(owners[index].call("dispatch",2,{},{})))
			var info: Dictionary=presentation.call("dispatch",10,{"id":nodes[index+1].get_instance_id()});row.clocks.append(info.elapsed)
			row.rngs.append([rngs[index].state,rngs[index].draws])
		snapshots.append(row)
	var timing: Dictionary=presentation.call("dispatch",16,{})
	check(timing.samples==5 and timing.successes==4 and timing.errors==1 and timing.excluded_detailed_samples==1 and timing.unclassified_samples==1,"Only profile-OFF calls recorded; nested failure context is isolated")
	check(timing.scheduled_clock_pairs==7 and timing.records.size()==5,"Exactly two clock reads per scheduled call, with bounded retained records")
	check(is_finite(float(timing.success_mean_ms)) and float(timing.success_mean_ms)>=0.0,"Wall-domain mean is finite")
	if bound:
		check(int(timing.animating_key_binds)>0 and int(timing.static_null_callable_uses)>0 and int(timing.static_noncallable_uses)>0,"Actual bound-key/null/noncallable route use counters")
	else:check(timing.animating_key_binds==0 and timing.static_null_callable_uses==0 and timing.static_noncallable_uses==0,"Ordinary route remains unchanged")
	check(timing.compiled_null_callable_entries==2 and timing.live_callable_entries==1,"Custom and invalid/expired nonempty targets never become static null routes")
	presentation.call("dispatch",5,{})
	check(presentation.call("dispatch",15,{"enabled":true}).has("error"),"Closed sampler cannot reopen a presentation owner")
	check(presentation.call("dispatch",16,{}).samples==5,"Cold timing survives close without borrowing scene state")
	for service: Dictionary in providers:service.clear()
	owners.clear();rngs.clear();providers.clear();fallback=Callable();standard=Callable();presentation=null;context.clear();scene.free()
	return {"snapshots":snapshots,"clock_validity_dispatches":timing.clock_validity_dispatches}
func sampler_bounds() -> void:
	var owner: RefCounted=ClassDB.instantiate("NwnParticlePresentation")
	check(not owner.call("dispatch",15,{"enabled":true,"stride":2,"reset":true}).has("error"),"Stride configures")
	for frame: int in 5:owner.call("dispatch",1,{"delta":0.0,"view":view_packet(24000000+frame,false)})
	check(owner.call("dispatch",16,{}).samples==3,"Stride2 retains only calls1,3,5")
	check(owner.call("dispatch",15,{"enabled":false,"stride":0,"setup_boundary":true}).has("error"),"Invalid sampler config rejects before any mode mutation")
	check(owner.call("dispatch",16,{}).enabled and not owner.call("dispatch",16,{}).setup_boundary,"Failed config does not disable/change setup mode")
	owner.call("dispatch",15,{"enabled":true,"stride":1,"min_members":1,"reset":true})
	for frame: int in 3:owner.call("dispatch",1,{"delta":0.0,"view":view_packet(25000000+frame,false)})
	check(owner.call("dispatch",16,{}).samples==0,"Startup below member threshold takes no clock pair")
	owner.call("dispatch",15,{"enabled":true,"stride":1,"min_members":0,"reset":true})
	for frame: int in 300:owner.call("dispatch",1,{"delta":0.0,"view":view_packet(26000000+frame,false)})
	var result: Dictionary=owner.call("dispatch",16,{})
	check(result.samples==300 and result.records.size()==256 and result.records[0].call==45 and result.records[-1].call==300,"Ring storage is strictly bounded; total counts retain their meaning")
	owner.call("dispatch",15,{"enabled":false})
	owner.call("dispatch",1,{"delta":0.0,"view":view_packet(27000000,false)})
	check(owner.call("dispatch",16,{}).samples==300,"Disabling preserves cold readback and adds no sample")
	owner.call("dispatch",5,{});owner=null
func run() -> void:
	var report: String=""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):report=arg.substr(9)
	if report.is_empty() or FileAccess.file_exists(report):quit(2);return
	var ordinary: Dictionary=scenario(false);var bound: Dictionary=scenario(true)
	check(same(ordinary.snapshots,bound.snapshots).is_empty(),"Bound setup preserves exact state/RNG/common mutation/callback/clock/error observations "+same(ordinary.snapshots,bound.snapshots))
	check(int(bound.clock_validity_dispatches)<int(ordinary.clock_validity_dispatches),"Avoided clock validation dispatches are actually observed")
	sampler_bounds();await process_frame;await process_frame
	var file: FileAccess=FileAccess.open(report,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Same-DLL ordinary/bound setup: live common.animating mutations, mutable/expired/custom/null/noncallable clocks and resource lifetime; sparse profile-OFF wall sampling, reentrancy/error exclusion, strides/member gate/ring cap; no FPS claim"},"\t"));file.close();quit(0 if failures.is_empty() else 1)
