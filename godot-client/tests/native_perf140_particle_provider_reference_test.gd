extends "res://tests/native_particle_presentation_test.gd"
# Paired same-DLL provider ownership paths. Mutable callback contents remain
# the same Dictionary; only redundant retained Variant copies are omitted.
var oracle_context:={"frame":0,"serial":0,"clock_rejections":0}
var experiment_mode:="borrow_providers"
var experiment_scope:="Explicit Entry-owned provider reference versus ordinary Step-owned copy. Exact native state, geometry, RNG, callbacks, pending patch/detonation, clock failure/retry, disable/re-enable, static/actor clocks and shared common mutation. No graphical or FPS acceptance."
func mode_fields() -> PackedStringArray:return PackedStringArray([experiment_mode])
func owner_options(_reuse: bool) -> Dictionary:return {}
func inspect_pair(_a: Dictionary,_b: Dictionary) -> void:pass
func check_frame_output(_group: Dictionary,_output: Dictionary) -> void:pass
func finish_experiment(groups: Array) -> void:
	check(groups[0].provider_replacements>0 and groups[0].provider_replacements==groups[1].provider_replacements,"Both modes actually replace their provider callback during simulation")
	check(groups[0].provider_consumptions>0 and groups[0].provider_consumptions==groups[1].provider_consumptions,"Both modes actually invoke the replacement callback through the same live provider Dictionary")
func controls_group(scene: Node3D,reuse: bool) -> Dictionary:
	var source:=Node3D.new();scene.add_child(source)
	var presentation: RefCounted=ClassDB.instantiate("NwnParticlePresentation")
	var rng:=Random.new();rng.seed_value(9709)
	var channels:=Channels.new();channels.configure(channel_asset(),0)
	var group:={"presentation":presentation,"source":source,"owners":[],"nodes":[],"services":[],"rng":rng,"events":[],"common":{},"bad_clock":false,"clock":Callable(),"rejections":0,"reuse":reuse,"provider_replacements":0,"provider_consumptions":0}
	for index in 4:
		var node:=Node3D.new();source.add_child(node);node.position=Vector3(index*0.2,0.1,0.15)
		var kind: String=["fountain","explosion","single","fountain"][index]
		var seed_owner:=make_owner(false,kind,32|128|16,false,false)
		var owner: RefCounted=ClassDB.instantiate("NwnParticleOwner")
		var owner_config:={"state":seed_owner.state,"update":kind,"compactRecords":true,"typedEmitter":true,"poseId":node.get_instance_id(),"sourceId":source.get_instance_id(),"clips":channels.clips}
		owner_config.merge(owner_options(reuse),true)
		check(not owner.call("dispatch",0,owner_config,{}).has("error"),"Controls oracle owner configures "+str(index))
		seed_owner.providers.clear();group.owners.append(owner);group.nodes.append(node)
		var services:={"random":func():
			var observation: Dictionary=presentation.call("dispatch",10,{"id":node.get_instance_id()})
			group.events.append([index,observation.get("pending_patch"),observation.get("pending_detonate"),observation.get("elapsed"),observation.get("frames")])
			group.services[index]["cosineDouble"]=func(angle):group.events.append(["live_replaced_cosine",index,angle]);return cos(angle)
			group.provider_replacements+=1
			group.services[index]["random"]=func():group.provider_consumptions+=1;group.events.append(["live_replaced_random",index]);return rng.next()
			group.services[index]["private_scratch"]=oracle_context.frame
			return rng.next(),"cosineDouble":func(angle):return cos(angle),"addPointSourceWind":func(_p,_r,_l,_f):pass,"collide":func(_old,goal,out,hit):
			hit.normal=[0.0,0.0,1.0]
			if goal[2]>=0:return false
			out.assign([goal[0],goal[1],0.0]);return true}
		group.services.append(services)
		var config:={"id":node.get_instance_id(),"owner":owner,"providers":services,"source_flags":0,"culling":true,"clip":"constant","clip_length":3.0,"source_key":12345,"node_order":index}
		for mode in mode_fields():config[mode]=reuse
		if index==2:
			group.clock=func():
				# Read-only callback observations must still see pending patch and
				# detonation until successful advance consumes them.
				var observation: Dictionary=presentation.call("dispatch",10,{"id":node.get_instance_id()})
				group.events.append(["clock",observation.get("pending_patch"),observation.get("pending_detonate"),observation.get("elapsed")])
				var rejected: Dictionary=presentation.call("dispatch",4,{"id":node.get_instance_id(),"patch":{"birthRate":999.0}})
				if rejected.has("error"):group.rejections+=1
				if group.bad_clock:return 17
				return {"clip":["linear","constant","empty","missing"][int(oracle_context.frame/15)%4],"time":oracle_context.frame/60.0}
			config.clock=group.clock
		check(not presentation.call("dispatch",0,config).has("error"),"Controls oracle registers "+str(index))
		if index==1:
			var fallback:=Node3D.new();source.add_child(fallback);group.nodes.append(fallback)
			var fallback_config:={"id":fallback.get_instance_id(),"fallback":func(_delta):
				if oracle_context.frame%4==0:group.common.animating=false
			}
			for mode in mode_fields():fallback_config[mode]=reuse
			check(not presentation.call("dispatch",0,fallback_config).has("error"),"Fallback can mutate shared frame controls between emitters")
	return group
func common_controls(delta: float) -> Dictionary:
	return {"delta":delta,"view":view_packet(14000000+oracle_context.serial,oracle_context.frame%60<8),"profile":oracle_context.frame%5==0,"animating":oracle_context.frame%7>1}
func compare_controls(groups: Array,delta: float,expect_error: bool=false) -> void:
	oracle_context.serial+=1
	var outputs: Array=[]
	for group: Dictionary in groups:
		group.common=common_controls(delta)
		outputs.append(group.presentation.call("dispatch",1,group.common))
		check_frame_output(group,outputs[-1])
	for output: Dictionary in outputs:check(output.has("error")==expect_error,"Controls frame failure boundary "+str(oracle_context.frame)+" "+str(output.get("error","")))
	if expect_error:check(outputs[0].get("error")==outputs[1].get("error"),"Identical callback failure type")
	var a: Dictionary=groups[0].presentation.call("dispatch",2,{})
	var b: Dictionary=groups[1].presentation.call("dispatch",2,{})
	inspect_pair(a,b)
	for field in ["registered","prepared","fallbacks","culled","active","vertices","draws","generation"]:check(a[field]==b[field],"Controls exact admission/count "+field+" "+str(oracle_context.frame))
	check(a.get("buffer")==b.get("buffer"),"Controls exact active geometry "+str(oracle_context.frame))
	for index in 4:
		var expected: Dictionary=groups[0].owners[index].call("dispatch",2,{},{})
		var actual: Dictionary=groups[1].owners[index].call("dispatch",2,{},{})
		check(same(without_ids(expected),without_ids(actual)).is_empty(),"Controls exact state/recycling "+str(oracle_context.frame)+"/"+str(index))
	# The node array also contains the fallback, whose information is detached.
	for index in groups[0].nodes.size():
		var expected: Dictionary=groups[0].presentation.call("dispatch",10,{"id":groups[0].nodes[index].get_instance_id()})
		var actual: Dictionary=groups[1].presentation.call("dispatch",10,{"id":groups[1].nodes[index].get_instance_id()})
		for mode in mode_fields():
			if expected.get("fast",false):check(expected.get(mode)==false and actual.get(mode)==true,"Independent ordinary/candidate paths are actually selected "+mode)
			expected.erase(mode);actual.erase(mode)
		check(same(without_ids(expected),without_ids(actual)).is_empty(),"Controls exact pending/elapsed/counter views "+str(oracle_context.frame)+"/"+str(index))
	check(groups[0].events==groups[1].events,"Controls callbacks observe the same pending consumption "+str(oracle_context.frame))
	check(groups[0].rng.state==groups[1].rng.state and groups[0].rng.draws==groups[1].rng.draws,"Controls exact shared RNG ordering "+str(oracle_context.frame))

func provider_lifetime_case(scene: Node3D,borrow: bool) -> Dictionary:
	var node:=Node3D.new();scene.add_child(node)
	var seed:=make_owner(false,"single",0,false,false);seed.state.birthRate=1.0;seed.state.velocity=0.0;seed.state.randomVelocity=0.0;seed.state.mass=0.0
	var owner: RefCounted=ClassDB.instantiate("NwnParticleOwner")
	check(not owner.call("dispatch",0,{"state":seed.state,"update":"single","compactRecords":true,"typedEmitter":true,"poseId":node.get_instance_id(),"sourceId":node.get_instance_id()},{}).has("error"),"Lifetime provider owner configures")
	seed.providers.clear()
	var presentation: RefCounted=ClassDB.instantiate("NwnParticlePresentation");var events: Array=[]
	var sentinel:=RefCounted.new();var probe: WeakRef=weakref(sentinel)
	var callbacks: Variant={"sentinel":sentinel,"random":func():
		var commands: Array=[[3,{"id":node.get_instance_id()}],[0,{"id":node.get_instance_id(),"owner":owner,"providers":{}}],[5,{}],[1,{"delta":0.01,"view":view_packet(17000001,false)}],[6,{"ids":[node.get_instance_id()]}],[4,{"id":node.get_instance_id(),"enabled":false}]]
		for command: Array in commands:
			var rejection: Dictionary=presentation.call("dispatch",command[0],command[1]);check(rejection.has("error"),"Current callback cannot delete/reconfigure its Entry");events.append(rejection.get("error"))
		return 1,"cosineDouble":func(angle):return cos(angle)}
	sentinel=null
	check(not presentation.call("dispatch",0,{"id":node.get_instance_id(),"owner":owner,"providers":callbacks,"culling":false,"borrow_providers":borrow}).has("error"),"Entry owns provider Dictionary before either Step path")
	callbacks=null;check(probe.get_ref()!=null,"Entry alone retains provider members after caller releases Dictionary")
	check(presentation.call("dispatch",10,{"id":node.get_instance_id()}).borrow_providers==borrow,"Explicit Entry borrow mode readback is exact")
	var first: Dictionary=presentation.call("dispatch",1,{"delta":0.03125,"view":view_packet(17000002,false)})
	check(not first.has("error") and events.size()>=6,"Arbitrary callback unregister/readd/close/reentry attempts preserve active Entry lifetime")
	var bytes: PackedByteArray=presentation.call("dispatch",2,{}).buffer
	check(not presentation.call("dispatch",3,{"id":node.get_instance_id()}).has("error"),"Native removal proceeds at the next actual frame boundary")
	check(probe.get_ref()==null,"Removal releases final provider members with no lingering Step borrow/copy")
	# A failed provider may have changed particle state before its native error;
	# compare both complete states and error, then retry through a fresh Entry.
	var invalid:={"random":func():return "not a number","cosineDouble":func(angle):return cos(angle)}
	owner=ClassDB.instantiate("NwnParticleOwner")
	check(not owner.call("dispatch",0,{"state":seed.state,"update":"single","compactRecords":true,"typedEmitter":true,"poseId":node.get_instance_id(),"sourceId":node.get_instance_id()},{}).has("error"),"Failure fixture starts with a fresh uninitialized particle owner")
	check(not presentation.call("dispatch",0,{"id":node.get_instance_id(),"owner":owner,"providers":invalid,"culling":false,"borrow_providers":borrow}).has("error"),"Re-add creates a fresh provider binding")
	var failed: Dictionary=presentation.call("dispatch",1,{"delta":0.03125,"view":view_packet(17000003,false)})
	check(failed.has("error"),"Malformed random callback rejects at its original native conversion")
	var bad_state: Dictionary=without_ids(owner.call("dispatch",2,{},{}))
	presentation.call("dispatch",3,{"id":node.get_instance_id()});invalid.clear()
	var replacement:={"random":func():return 1,"cosineDouble":func(angle):return cos(angle)}
	check(not presentation.call("dispatch",0,{"id":node.get_instance_id(),"owner":owner,"providers":replacement,"culling":false,"borrow_providers":borrow}).has("error"),"Boundary replacement discards failed Step services")
	check(not presentation.call("dispatch",1,{"delta":0.03125,"view":view_packet(17000004,false)}).has("error"),"Retry uses the fresh provider binding after failure")
	var final_state: Dictionary=without_ids(owner.call("dispatch",2,{},{}));presentation.call("dispatch",5,{});replacement.clear();presentation=null;node.free()
	return {"events":events,"buffer":bytes,"failure":failed,"failed_state":bad_state,"final_state":final_state}

func run() -> void:
	var args: Dictionary={}
	for value in OS.get_cmdline_user_args():
		var pair:=value.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has("report") or FileAccess.file_exists(args.report):quit(2);return
	var scene:=Node3D.new();root.add_child(scene)
	var lifetime_a:=provider_lifetime_case(scene,false);var lifetime_b:=provider_lifetime_case(scene,true)
	check(same(lifetime_a,lifetime_b).is_empty(),"Owned/borrowed provider lifetime, exceptions, retries and geometry are exact")
	var groups:=[controls_group(scene,false),controls_group(scene,true)]
	for frame in 180:
		oracle_context.frame=frame
		for group: Dictionary in groups:
			group.events.clear();group.source.position=Vector3(sin(frame*0.04),0.3,cos(frame*0.03));group.source.rotation=Vector3(0.01,frame*0.02,0.03);group.source.scale=Vector3(1.2,0.8,1.1) if frame%40<20 else Vector3.ONE
			for index in 4:
				# Fallback is inserted after index1 in the identity array.
				var node: Node3D=group.nodes[index+(1 if index>1 else 0)]
				var control:={"id":node.get_instance_id(),"source_animating":index==0,"draw_enabled":index!=3 or frame%6!=0}
				if frame%11==0:control.merge({"patch":{"birthRate":5.0+index,"flags":32|128|16,"lifeExp":0.5+index*0.1},"detonate":index==1})
				if frame==35 and index==1:control.enabled=false
				if frame==50 and index==1:control.enabled=true
				if index==2 and frame in [40,60]:control.clock=Callable() if frame==40 else group.clock
				if frame in [21,78] and index==2:control.merge({"patch":{"birthRate":7.0},"detonate":true})
				if frame==95 and index==3:control.merge({"patch":{"birthRate":40000.0},"detonate":true})
				check(not group.presentation.call("dispatch",4,control).has("error"),"Controls boundary update "+str(frame)+"/"+str(index))
			group.bad_clock=frame in [21,78]
		compare_controls(groups,[1.0/60.0,1.0/40.0,0.0,-0.002,0.7][frame%5],frame in [21,78,95])
		if frame in [21,78]:
			for group: Dictionary in groups:group.bad_clock=false
			compare_controls(groups,0.01)
		if frame==95:
			for group: Dictionary in groups:group.presentation.call("dispatch",4,{"id":group.nodes[4].get_instance_id(),"patch":{"birthRate":7.0}})
			compare_controls(groups,0.01)
		if not failures.is_empty():break
		if frame%30==0:await process_frame
	check(oracle_context.frame==179,"Controls complete positive/zero/negative/large delta window")
	check(groups[0].rejections>0 and groups[0].rejections==groups[1].rejections,"Reentrant control mutations retain original rejection semantics")
	finish_experiment(groups)
	var provider_coverage: Array=[]
	for group: Dictionary in groups:provider_coverage.append({"borrowed":group.reuse,"replacements":group.provider_replacements,"replacement_invocations":group.provider_consumptions})
	for group: Dictionary in groups:
		group.presentation.call("dispatch",5,{})
		for services: Dictionary in group.services:services.clear()
		group.services.clear();group.owners.clear();group.presentation=null;group.clock=Callable()
	groups.clear();scene.free();await process_frame;await process_frame
	var report:={"success":failures.is_empty(),"checks":checks,"failures":failures,"frames":oracle_context.frame+1,"network_connections":0,"gpu_execution":false,"scope":experiment_scope,"provider_mutation_coverage":provider_coverage}
	var file:=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close();quit(0 if failures.is_empty() else 1)
