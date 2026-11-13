extends "res://tests/nwn64_typed_pose_test.gd"
# Source-heavy shared CPU component. No renderer, frame scheduling or FPS.
func quantiles(values: Array) -> Dictionary:
	values.sort();var total:=0.0
	for value in values:total+=float(value)
	return {"samples":values.size(),"median_us":values[int(ceil(values.size()*0.5))-1],"p95_us":values[int(ceil(values.size()*0.95))-1],"mean_us":total/values.size()}
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has("report") or FileAccess.file_exists(args.report):quit(2);return
	check(Kernel.available(),"Private source-heavy kernel loads")
	var scene:=Node3D.new();root.add_child(scene)
	var rig: Node=load("res://systems/model_rigs.gd").new();scene.add_child(rig)
	var model_refs: Array=[];var entities: Dictionary={}
	var presentation: RefCounted=ClassDB.instantiate("NwnParticlePresentation")
	presentation.call("dispatch",15,{"enabled":false,"setup_boundary":OS.get_cmdline_user_args().has("--particle-setup-boundary=bound")})
	var rng:=Random.new();rng.seed_value(321)
	var callbacks:={"random":rng.next,"cosineDouble":func(angle):return cos(angle)}
	var channels:=Channels.new();channels.configure(channel_asset(),0)
	var dynamic: Array=[];var source_count:=1750;var far_count:=960;var singles:=660
	for index in source_count:
		var node:=Node3D.new();scene.add_child(node);node.position=Vector3(1000 if index<far_count else float(index%17-8)*0.1,0,float(index%13-6)*0.1)
		if index>=far_count and index%16==0:dynamic.append(node)
		var kind: String="single" if index<far_count+singles else "fountain"
		var seed_owner:=make_owner(false,kind,32,false,false)
		seed_owner.state.birthRate=1.0 if kind=="single" else 8.0;seed_owner.state.lifeExp=0.6;seed_owner.state.mass=0.0;seed_owner.state.velocity=0.0;seed_owner.state.randomVelocity=0.0;seed_owner.state.spread=0.0
		seed_owner.state.renderMode1a8=0 if kind=="single" else index%7;seed_owner.state.accumulator198=float(index%8)/60.0
		var config:={"state":seed_owner.state,"update":kind,"compactRecords":true,"typedEmitter":true,"poseId":node.get_instance_id(),"sourceId":node.get_instance_id()}
		if index%7==0:config.clips=channels.clips
		var owner: RefCounted=ClassDB.instantiate("NwnParticleOwner");check(not owner.call("dispatch",0,config,{}).has("error"),"Sparse native source configures "+str(index))
		var entry:={"id":node.get_instance_id(),"owner":owner,"providers":callbacks,"source_flags":0,"clip":"linear","clip_length":1.0,"culling":true}
		if index%5==0:
			var model:={"clip":"linear","last_time":0.0,"play_serial":1};entities[index]={"models":[model]};model_refs.append(model)
			entry.clock=Callable(rig,"playback_state").bind(index,0)
		check(not presentation.call("dispatch",0,entry).has("error"),"Shared native source registers "+str(index));seed_owner.providers.clear()
		if args.has("progress") and index%250==0:print("NWN64_PROGRESS source ",index)
	rig.set("entities",entities)
	var benchmark: bool=args.get("benchmark","")=="on";var diagnostic: bool=args.get("diagnostic","")=="on";var frames:=240 if benchmark else 120
	var wall: Array=[];var phases: Dictionary={};var phase_packets:=0;var last: Dictionary={}
	for frame in frames:
		if args.has("progress") and frame%10==0:print("NWN64_PROGRESS frame ",frame)
		for model in model_refs:model.last_time=fmod(frame/60.0,1.0)
		for node in dynamic:node.rotation.y=frame*0.002
		var common:={"delta":1.0/60.0,"view":view_packet(frame+7000000,false),"profile":diagnostic,"native_surface_output":true,"animating":true}
		var began:=Time.get_ticks_usec() if benchmark else 0;last=presentation.call("dispatch",1,common)
		if benchmark and frame>=80:wall.append(Time.get_ticks_usec()-began)
		check(not last.has("error"),"Shared sparse clock frame "+str(frame)+" "+str(last.get("error","")))
		if last.has("error"):break
		phase_packets+=int(last.has("phases"))
		if diagnostic and frame>=80:
			for name in last.get("phases",{}):
				if not phases.has(name):phases[name]=[]
				phases[name].append(float(last.phases[name])*1000.0)
	check(phase_packets==(frames if diagnostic else 0),"Normal throughput has no diagnostic phase packets")
	check(int(last.get("registered",0))==source_count and int(last.get("prepared",0))==source_count and int(last.get("culled",0))==far_count,"Actual source-heavy population/culling matches fixture")
	var info: Dictionary=presentation.call("dispatch",16,{})
	if args.get("expect-native","")=="on":check(int(info.get("native_clock_bindings",0))==350 and int(info.get("native_clock_reads",0))==350*frames and int(info.get("native_clock_fallbacks",0))==0,"All350canonical clock sources engage on each original boundary")
	var packet: Dictionary=presentation.call("dispatch",2,{});var digest: String=packet.get("buffer",PackedByteArray()).hex_encode().sha256_text()
	var phase_summaries: Dictionary={}
	for name in phases:phase_summaries[name]=quantiles(phases[name])
	var scalar_last: Dictionary=last.duplicate();scalar_last.erase("phases")
	presentation.call("dispatch",5,{});presentation=null;callbacks.clear();scene.free();await process_frame
	var report:={"issue":"NWN-64","success":failures.is_empty(),"checks":checks,"failures":failures,"sources":source_count,"far_sources":far_count,"controller_sources":250,"canonical_clock_sources":350,"frames":frames,"actual_phase_packets":phase_packets,"rng_draws":rng.draws,"rng_state":rng.state,"last":scalar_last,"packet_digest":digest,"clock_info":info,"component_call_us":quantiles(wall) if not wall.is_empty() else {},"separate_diagnostic_phase_us":phase_summaries,"scope":"Synthetic source-heavy shared native CPU component:1750native-pose sources,960culled,250controllers,350canonical rig-clock sources and sparse visible particles. Calls actual shared packet path. profile=false except explicit separate --diagnostic=on. No renderer, live recording, whole-frame or FPS claim."}
	var file:=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close();print("NWN64_SHARED_CLOCK ",checks," checks; ",failures.size()," failures");quit(0 if failures.is_empty() else 1)
