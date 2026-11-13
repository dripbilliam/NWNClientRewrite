extends "res://tests/nwn64_typed_pose_test.gd"
# Source-heavy shared-presentation diagnostic, not a live recording or FPS test.
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
	check(Kernel.available(),"Private accepted/control kernel loads")
	var scene:=Node3D.new();root.add_child(scene)
	var presentation: RefCounted=ClassDB.instantiate("NwnParticlePresentation")
	var rng:=Random.new();rng.seed_value(321)
	var callbacks:={"random":rng.next,"cosineDouble":func(angle):return cos(angle)}
	var channels:=Channels.new();channels.configure(channel_asset(),0)
	var clock_state:={"time":0.0,"calls":0}
	var actor_clock:=func():clock_state.calls+=1;return {"clip":"linear","time":clock_state.time}
	var nodes: Array=[];var dynamic: Array=[]
	var source_count:=1750;var far_count:=960;var singles:=660
	for index in source_count:
		var node:=Node3D.new();scene.add_child(node);node.position=Vector3(1000 if index<far_count else float(index%17-8)*0.1,0,float(index%13-6)*0.1);nodes.append(node)
		if index>=far_count and index%16==0:dynamic.append(node)
		var kind: String="single" if index<far_count+singles else "fountain"
		var seed_owner:=make_owner(false,kind,32,false,false)
		seed_owner.state.birthRate=1.0 if kind=="single" else 8.0;seed_owner.state.lifeExp=0.6;seed_owner.state.mass=0.0;seed_owner.state.velocity=0.0;seed_owner.state.randomVelocity=0.0;seed_owner.state.spread=0.0
		seed_owner.state.renderMode1a8=0 if kind=="single" else index%7
		seed_owner.state.accumulator198=float(index%8)/60.0
		var config:={"state":seed_owner.state,"update":kind,"compactRecords":true,"typedEmitter":true,"poseId":node.get_instance_id(),"sourceId":node.get_instance_id()}
		if index%7==0:config.clips=channels.clips
		var owner: RefCounted=ClassDB.instantiate("NwnParticleOwner");var configured: Dictionary=owner.call("dispatch",0,config,{})
		check(not configured.has("error"),"Source-heavy private owner configures "+str(index))
		var entry:={"id":node.get_instance_id(),"owner":owner,"providers":callbacks,"source_flags":0,"clip":"linear","clip_length":1.0,"culling":true}
		if index%5==0:entry.clock=actor_clock
		check(not presentation.call("dispatch",0,entry).has("error"),"Shared native source registers "+str(index))
		seed_owner.providers.clear()
	var phases: Dictionary={};var wall: Array=[];var phase_sums: Array=[];var residuals: Array=[];var last: Dictionary={};var samples:=0
	var disjoint: Array=["particle_native_eligibility_clock_ms","particle_native_controls_ms","particle_native_pose_ms","particle_native_admission_ms","particle_native_simulation_ms","particle_native_geometry_ms","particle_native_pack_sort_ms","particle_native_counters_summary_ms"]
	for frame in 120:
		clock_state.time=fmod(frame/60.0,1.0)
		for node in dynamic:node.rotation.y=frame*0.002
		var common:={"delta":1.0/60.0,"view":view_packet(frame+7000000,false),"profile":true,"native_surface_output":true,"animating":true}
		var began:=Time.get_ticks_usec();last=presentation.call("dispatch",1,common);var elapsed:=Time.get_ticks_usec()-began
		check(not last.has("error"),"Shared source-heavy diagnostic frame "+str(frame)+" "+str(last.get("error","")))
		if last.has("error"):break
		if frame>=80:
			check(last.has("phases"),"Separate diagnostic phase packet observed")
			var phase_sum:=0.0
			for name in last.phases:
				if not phases.has(name):phases[name]=[]
				phases[name].append(float(last.phases[name])*1000.0)
				if name in disjoint:phase_sum+=float(last.phases[name])*1000.0
			wall.append(elapsed);phase_sums.append(phase_sum);residuals.append(float(elapsed)-phase_sum);samples+=1
	var summaries: Dictionary={}
	for name in phases:summaries[name]=quantiles(phases[name])
	check(int(last.get("registered",0))==source_count and int(last.get("prepared",0))==source_count and int(last.get("culled",0))==far_count,"Population and cull count match source-heavy scenario")
	var scalar_last: Dictionary=last.duplicate();scalar_last.erase("phases")
	presentation.call("dispatch",5,{});presentation=null;callbacks.clear();scene.free();await process_frame
	var report:={"issue":"NWN-64","success":failures.is_empty(),"checks":checks,"failures":failures,"sources":source_count,"configured_far_sources":far_count,"controller_sources":250,"actor_clock_sources":350,"actor_clock_calls":clock_state.calls,"rng_draws":rng.draws,"last":scalar_last,"diagnostic_samples":samples,"diagnostic_phase_us":summaries,"diagnostic_call_wall_us":quantiles(wall) if not wall.is_empty() else {},"disjoint_phase_sum_us":quantiles(phase_sums) if not phase_sums.is_empty() else {},"diagnostic_residual_us":quantiles(residuals) if not residuals.is_empty() else {},"scope":"Synthetic source-heavy native shared-presentation diagnostic:1750native-pose sources,960culled, sparse small particle populations,250controller sources and350actor-clock callbacks. Uses actual shared native packet path with native color carrier; profile=true instrumentation changes eligibility route. No live recording, normal-throughput, renderer/FPS/loading claim."}
	var file:=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close();print("NWN64_SHARED_PHASE ",checks," checks; ",failures.size()," failures");quit(0 if failures.is_empty() else 1)
