extends "res://tests/native_particle_presentation_test.gd"
# One private profile-OFF inner-phase receipt shaped by the 919-emitter census.
# No renderer, original-scene claim, frame interval, or FPS measurement.

func quantiles(values: Array) -> Dictionary:
	values.sort()
	var total:=0.0
	for value in values: total+=float(value)
	return {"count":values.size(),"median_us":values[(values.size()-1)/2],"p95_us":values[int(ceil(values.size()*0.95))-1],"mean_us":total/values.size()}

func one_leg(scene: Node3D, enabled: bool, name: String) -> Dictionary:
	var holder:=Node3D.new();scene.add_child(holder)
	var presentation: RefCounted=ClassDB.instantiate("NwnParticlePresentation")
	var selected: Dictionary=presentation.call("dispatch",15,{"enabled":true,"stride":3,"min_members":900,"coarse_phases":true,"setup_boundary":true})
	check(not selected.has("error"),"Sparse profile-OFF inner sampler configures")
	var owners: Array=[];var poses: Array=[];var sources: Array=[];var rng:=Random.new();rng.seed_value(733)
	var group_sizes: Array=[]
	for i in 207:group_sizes.append(3)
	for i in 54:group_sizes.append(2)
	for i in 190:group_sizes.append(1)
	check(group_sizes.size()==451,"Original source group count")
	var source_index:=0;var in_group:=0
	for index in 919:
		if in_group==0:
			var source:=Node3D.new();holder.add_child(source);sources.append(source)
		var pose:=Node3D.new();holder.add_child(pose);poses.append(pose)
		var emitter:=Node3D.new();pose.add_child(emitter)
		var kind: String="fountain" if index<201 else "explosion"
		var seed:=make_owner(false,kind,32|128,false,false)
		seed.state.birthRate=17.0 if kind=="fountain" else 0.0
		seed.state.lifeExp=0.6;seed.state.renderMode1a8=index%7
		var owner: RefCounted=ClassDB.instantiate("NwnParticleOwner")
		var configured: Dictionary=owner.call("dispatch",0,{"state":seed.state,"update":kind,"compactRecords":true,"typedEmitter":true,"poseId":pose.get_instance_id(),"sourceId":sources[source_index].get_instance_id()}, {})
		check(not configured.has("error"),"Configure "+str(name)+"/"+str(index))
		var entry:={"id":emitter.get_instance_id(),"owner":owner,"providers":{"random":rng.next,"cosineDouble":func(angle):return cos(angle)},"source_flags":0,"culling":false,"clip":""}
		var added: Dictionary=presentation.call("dispatch",0,entry)
		check(not added.has("error"),"Register "+str(name)+"/"+str(index))
		owners.append(owner);seed.providers.clear()
		in_group+=1
		if in_group==group_sizes[source_index]:source_index+=1;in_group=0
	check(source_index==451 and owners.size()==919,"Original emitter/source multiplicity")
	var times: Array=[];var hits:=0;var reads:=0;var invalidations:=0
	var samples: Array=[];var packet_hash:=HashingContext.new();packet_hash.start(HashingContext.HASH_SHA256)
	var initial_memory:=Performance.get_monitor(Performance.MEMORY_STATIC)
	for frame in 76:
		for i in sources.size():sources[i].position=Vector3(sin(frame*0.02)+i*0.01,0.2,cos(frame*0.03))
		for i in poses.size():poses[i].position=Vector3(i*0.01,0.1,0.0)
		var start:=Time.get_ticks_usec()
		var result: Dictionary=presentation.call("dispatch",1,{"delta":1.0/60.0,"view":view_packet(frame+9000000,false),"animating":true,"profile":false})
		var elapsed:=Time.get_ticks_usec()-start
		if result.has("error"):check(false,"Frame "+str(name)+"/"+str(frame)+": "+str(result.error));break
		if frame>=12:times.append(elapsed)
		hits+=int(result.get("source_pose_reuse_hits",0));reads+=int(result.get("source_pose_live_reads",0));invalidations+=int(result.get("source_pose_invalidations",0))
		if frame in [12,43,75]:
			var packet: Dictionary=presentation.call("dispatch",2,{})
			packet_hash.update(packet.buffer)
			samples.append({"frame":frame,"active":result.active,"vertices":result.vertices,"draws":result.draws,"rng_draws":rng.draws})
	var final_memory:=Performance.get_monitor(Performance.MEMORY_STATIC)
	var digest:=packet_hash.finish().hex_encode()
	var sampler: Dictionary=presentation.call("dispatch",16,{})
	presentation.call("dispatch",5,{})
	holder.free();owners.clear();poses.clear();sources.clear();presentation=null
	return {"mode":"diagnostic","name":name,"timing":quantiles(times),"hits":hits,"reads":reads,"invalidations":invalidations,"samples":samples,"packet_sha256":digest,"initial_memory":initial_memory,"final_memory":final_memory,"sampler":sampler}

func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has("report") or FileAccess.file_exists(args.report):quit(2);return
	var scene:=Node3D.new();root.add_child(scene)
	var leg:=one_leg(scene,false,"inner")
	var sampler: Dictionary=leg.sampler
	check(int(sampler.get("inner_success_samples",0))>=20,"At least 20 complete profile-OFF inner receipts")
	check(int(sampler.get("phase_success_samples",0))==int(sampler.get("inner_success_samples",-1)),"Outer and inner receipts select the same frames")
	check(int(sampler.get("excluded_detailed_samples",-1))==0 and int(sampler.get("errors",-1))==0,"No detailed-route or failed-frame samples")
	check(sampler.records.all(func(sample):return bool(sample.get("inner_complete",false)) and int(sample.get("registered",0))==919),"Every sampled frame uses the 919-source profile-OFF route")
	scene.free();await process_frame
	var report:={"issue":"NWN-64","success":failures.is_empty(),"checks":checks,"failures":failures,"leg":leg,"scope":"Private synthetic profile-OFF inner-phase receipt shaped by the original generation4 census: 919 prepared emitters, 451 sources, 468 adjacent duplicates, 201/718 fountain/explosion mix. No renderer, FPS or original-scene claim. Clock/culling distributions differ from live."}
	var file:=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print(JSON.stringify({"success":report.success,"checks":checks,"failures":failures.size(),"sampled_frames":sampler.inner_success_samples,"inner_means":sampler.inner_phase_success_means}));quit(0 if failures.is_empty() else 1)
