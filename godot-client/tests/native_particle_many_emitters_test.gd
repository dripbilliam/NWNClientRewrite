extends "res://tests/native_particle_typed_pose_test.gd"
# A high emitter count with one particle each tests the workload missing from
# the earlier low-emitter/high-particle Heal benchmark. No GPU/server is used.
func distribution(samples: Array) -> Dictionary:
	var values:=samples.duplicate(); values.sort(); var total:=0.0
	for value in values: total+=float(value)
	return {"samples":values.size(),"mean_ms":total/maxi(1,values.size()),"p95_ms":values[int((values.size()-1)*0.95)] if not values.is_empty() else 0,"max_ms":values.back() if not values.is_empty() else 0}
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("report") or FileAccess.file_exists(args.report): quit(2); return
	var count:=1506; var frames:=96
	var scene:=Node3D.new(); root.add_child(scene)
	var poses: Array[Node3D]=[]; var sources: Array[Node3D]=[]
	for index in count:
		if index%2==0:
			var source:=Node3D.new(); scene.add_child(source); source.position=Vector3(sin(index*0.1),0,cos(index*0.13)); sources.append(source)
		var pose_node:=Node3D.new(); sources.back().add_child(pose_node); pose_node.position=Vector3(0.05*(index%2),0.1,0); poses.append(pose_node)
	var seed_owner:=make_owner(false,"single",0,false,false); var e: Dictionary=seed_owner.state
	e.merge({"renderMode1a8":0,"lifeExp":1.0,"birthRate":1.0,"xSize":0.0,"ySize":0.0,"spread":0.0,"randomVelocity":0.0,"velocity":0.0,"mass":0.0,"particleRot":0.0,"frameStart":0.0,"frameEnd":0.0,"fps":0.0},true)
	var owner_groups: Array=[[],[]]
	for slot in 2:
		for index in count:
			var owner: RefCounted=ClassDB.instantiate("NwnParticleOwner")
			var result: Dictionary=owner.call("dispatch",0,{"state":e,"update":"single","compactRecords":true,"typedEmitter":bool(slot),"poseId":poses[index].get_instance_id(),"sourceId":sources[int(index/2)].get_instance_id()},{})
			check(not result.has("error"),"High-count owner configures "+str(slot)+"/"+str(index))
			owner_groups[slot].append(owner)
	var timing: Array=[[],[]]; var output_groups: Array=[[],[]]; var input: Dictionary={}
	var peak:=0
	for frame in frames:
		input={"clip":"","time":frame/60.0,"delta":1.0/60.0,"capacity":0 if frame==0 else 96,"source_flags":0,"culling":true,"profile":false,"view":view_packet(frame,false)}
		for turn in 2:
			var slot: int=(turn+frame)%2; var results: Array=[]
			var began:=Time.get_ticks_usec()
			for owner: RefCounted in owner_groups[slot]: results.append(owner.call("dispatch",1,input,{}))
			var elapsed:=(Time.get_ticks_usec()-began)/1000.0
			if frame>=16: timing[slot].append(elapsed)
			output_groups[slot]=results
		for index in count:
			var a: Dictionary=output_groups[0][index]; var b: Dictionary=output_groups[1][index]
			check(not a.has("error") and not b.has("error"),"High-count owners remain valid "+str(frame)+"/"+str(index)+" "+str(a.get("error",""))+" / "+str(b.get("error","")))
			if a.has("error") or b.has("error"): continue
			check(not a.typed_emitter and b.typed_emitter and a.count==6 and b.count==6,"Both paths retain every single-particle emitter "+str(frame)+"/"+str(index))
			check(a.positions==b.positions and a.attributes==b.attributes,"Exact high-count particle geometry "+str(frame)+"/"+str(index))
			peak=maxi(peak,int(b.active)*count)
		if frame%24==0 or frame==frames-1:
			for index in range(0,count,97):
				var difference:=same(owner_groups[0][index].call("dispatch",2,{},{}),owner_groups[1][index].call("dispatch",2,{},{}))
				check(difference.is_empty(),"Retained high-count state "+str(frame)+"/"+str(index)+" "+difference)
		if not failures.is_empty(): break
		if frame%8==0: await process_frame
	check(peak==count,"The test retains all 1506 active particles")
	owner_groups.clear(); seed_owner.providers.clear(); scene.queue_free(); await process_frame; await process_frame
	var file:=FileAccess.open(args.report,FileAccess.WRITE)
	file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"emitter_count":count,"peak_active_particles":peak,"timing":[{"typed_emitter":false,"dispatch":distribution(timing[0])},{"typed_emitter":true,"dispatch":distribution(timing[1])}],"network_connections":0,"scope":"Headless paired 1506 native single-particle emitters, same native source/part transforms, reverse call order each frame, exact packet bytes and sampled retained-state checks. Dispatch-only CPU measurements exclude production GDScript callbacks, upload, metrics and GPU; not gameplay/FPS acceptance."},"\t")); file.close(); quit(0 if failures.is_empty() else 1)
