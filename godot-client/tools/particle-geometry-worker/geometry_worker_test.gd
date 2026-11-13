extends "res://tests/native_particle_resident_test.gd"

func seed_particles(count: int,index: int) -> Array:
	var out: Array=[]
	for n in count:
		var position:=[float(index)*0.25,float(n%17)*0.02,float(n%29)*0.01]
		out.append({"position10":position,"trail64":position.duplicate(),"quaternion34":[1.0,0.0,0.0,0.0],"direction4c":[0.0,0.0,1.0],"rotation1c":float(n%13)*0.05,"age":float(n%101)*0.01,"field48":0.0,"frame44":n%8,"stopped70":0,"inheritedSpeed20":0.0,"inheritedDirection24":[0.0,0.0,0.0],"velocity58":[0.0,0.0,0.0]})
	return out

func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("report") or FileAccess.file_exists(args.report): quit(2); return
	var scene_mode:=str(args.get("scene","off"))=="on"
	var particle_count:=int(args.get("count","250"))
	if particle_count<1 or particle_count>250: quit(2); return
	var scene:=Node3D.new(); root.add_child(scene)
	var shared_texture: ImageTexture
	if scene_mode:
		var image:=Image.create(2,2,false,Image.FORMAT_RGBA8);image.fill(Color.WHITE)
		shared_texture=ImageTexture.create_from_image(image)
	var presentations: Array=[]; var owners: Array=[[],[]]
	for slot in 2:
		var presentation: RefCounted=ClassDB.instantiate("NwnParticlePresentation")
		presentations.append(presentation)
		for index in 16:
			var pose_node:=Node3D.new(); scene.add_child(pose_node)
			pose_node.position=Vector3(float(index)*0.3,0.0,0.0)
			var initial:=make_owner(false,"fountain",0,false,false)
			initial.state.birthRate=0.0; initial.state.lifeExp=10.0; initial.state.velocity=0.0; initial.state.randomVelocity=0.0; initial.state.mass=0.0; initial.state.particleRot=0.0
			initial.state.renderMode1a8=index%7; initial.state.initialized208=1
			var particles:=seed_particles(particle_count,index)
			initial.state.active188={"records":particles,"capacity":particles.size()}
			var owner: RefCounted=ClassDB.instantiate("NwnParticleOwner")
			var configured: Dictionary=owner.call("dispatch",0,{"state":initial.state,"update":"fountain","compactRecords":true,"typedEmitter":true,"poseId":pose_node.get_instance_id(),"sourceId":pose_node.get_instance_id()}, {})
			check(not configured.has("error"),"Typed particle owner configures "+str(slot)+"/"+str(index)+" "+str(configured.get("error","")))
			owners[slot].append(owner)
			var config:={"id":pose_node.get_instance_id(),"owner":owner,"providers":{},"source_flags":0,"culling":false}
			if scene_mode:
				config.texture=shared_texture
				config.lighting=index%2==0
			var added: Dictionary=presentation.call("dispatch",0,config)
			check(not added.has("error"),"Particle presentation registers "+str(slot)+"/"+str(index)+" "+str(added.get("error","")))
			initial.providers.clear()
	var planes:=PackedFloat32Array([1,0,0,100,-1,0,0,100,0,0,-1,100,0,0,1,100,0,1,0,100,0,-1,0,100])
	var view:={"stamp":10000000,"position":[0.0,0.0,0.0],"camera":[1.0,0.0,0.0,0.0],"planes":planes.to_byte_array()}
	var samples: Array=[[],[]]; var compared:=0
	for frame in 100:
		var packets: Array=[{},{}];var scene_packets: Array=[{},{}]
		var sequence: Array=[0,1] if frame%4<2 else [1,0]
		for slot in sequence:
			var began:=Time.get_ticks_usec()
			var result: Dictionary=presentations[slot].call("dispatch",1,{"delta":1.0/60.0,"view":view,"geometry_worker":slot==1,"scene_instances":scene_mode,"profile":frame==99})
			var elapsed:=Time.get_ticks_usec()-began
			check(not result.has("error"),"Worker comparison frame "+str(frame)+"/"+str(slot)+" "+str(result.get("error","")))
			if result.has("error"): break
			if frame==99 and slot==1:
				check(result.phases.has("particle_native_geometry_cpu_ms") and float(result.phases.particle_native_geometry_ms)>0.0 and float(result.phases.particle_native_pack_sort_ms)>=0.0,"Worker profile separates geometry wall and CPU time")
			if frame>=20: samples[slot].append(elapsed)
			packets[slot]=presentations[slot].call("dispatch",2,{})
			if scene_mode: scene_packets[slot]=presentations[slot].call("dispatch",9,{})
		if not failures.is_empty(): break
		check(packets[0].buffer==packets[1].buffer,"Exact shared particle geometry bytes "+str(frame))
		check(int(packets[0].vertices)==int(packets[1].vertices),"Equal active geometry vertex count "+str(frame))
		check(packets[0].ranges.size()==packets[1].ranges.size(),"Equal draw range count "+str(frame))
		for index in packets[0].ranges.size():
			var left: Dictionary=packets[0].ranges[index];var right: Dictionary=packets[1].ranges[index]
			check(left.first==right.first and left.count==right.count and left.bounds==right.bounds,"Equal draw range and bounds "+str(frame)+"/"+str(index))
		if scene_mode:
			check(scene_packets[0].batches.size()==scene_packets[1].batches.size() and not scene_packets[0].batches.is_empty(),"Equal populated scene batch count "+str(frame))
			for index in mini(scene_packets[0].batches.size(),scene_packets[1].batches.size()):
				var left: Dictionary=scene_packets[0].batches[index];var right: Dictionary=scene_packets[1].batches[index]
				check(left.buffer==right.buffer and left.bounds==right.bounds and left.count==right.count and left.material_key==right.material_key,"Exact scene instance batch and bounds "+str(frame)+"/"+str(index))
		compared+=1
		if not failures.is_empty(): break
	var stats: Dictionary=presentations[1].call("dispatch",7,{})
	check(compared==100,"Complete paired particle window")
	check(int(stats.get("geometry_worker_frames",0))>0,"Real geometry worker executed")
	for presentation in presentations: presentation.call("dispatch",5,{})
	presentations.clear();owners.clear();scene.free()
	await process_frame; await process_frame
	var file:=FileAccess.open(args.report,FileAccess.WRITE)
	file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"frames":compared,"worker_frames":stats.get("geometry_worker_frames",0),"worker_vertices":stats.get("geometry_worker_vertices",0),"serial_us":samples[0],"worker_us":samples[1],"scene_mode":scene_mode,"particle_count":particle_count,"scope":"Private paired geometry worker oracle; no GPU/FPS claim"},"\t"));file.close()
	quit(0 if failures.is_empty() else 1)
