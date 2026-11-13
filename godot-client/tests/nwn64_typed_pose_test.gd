extends "res://tests/nwn64_resident_test.gd"
func view_packet(frame: int,far: bool) -> Dictionary:
	var center:=2000.0 if far else 0.0
	var numbers:=PackedFloat32Array([1,0,0,center+3,-1,0,0,-center+3,0,1,0,3,0,-1,0,3,0,0,1,3,0,0,-1,3])
	return {"stamp":frame+100000,"position":[center,2,8],"camera":[0.70710677,0.70710677,0,0],"planes":numbers.to_byte_array()}
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("report") or FileAccess.file_exists(args.report): quit(2); return
	var scene:=Node3D.new(); root.add_child(scene)
	var source:=Node3D.new(); scene.add_child(source)
	var pose_node:=Node3D.new(); scene.add_child(pose_node)
	var seed_owner:=make_owner(false,"fountain",32|128|256,false,false)
	var channel_owner:=Channels.new(); channel_owner.configure(channel_asset(),0)
	var owners: Array[RefCounted]=[]; var rngs: Array=[]; var callbacks: Array=[]
	for typed in [false,true]:
		var owner: RefCounted=ClassDB.instantiate("NwnParticleOwner")
		var configured: Dictionary=owner.call("dispatch",0,{"state":seed_owner.state,"update":"fountain","compactRecords":true,"typedEmitter":typed,"poseId":pose_node.get_instance_id(),"sourceId":source.get_instance_id(),"clips":channel_owner.clips},{})
		check(not configured.has("error"),"Pose owner configures "+str(typed))
		owners.append(owner); var rng:=Random.new(); rng.seed_value(321); rngs.append(rng)
		callbacks.append({"random":rng.next,"cosineDouble":func(angle):return cos(angle),"addPointSourceWind":func(_p,_r,_l,_f):pass})
	var before_a: Dictionary=owners[0].call("dispatch",2,{},{}); var before_b: Dictionary=owners[1].call("dispatch",2,{},{})
	var initial_difference:=same(before_a,before_b)
	check(initial_difference.is_empty(),"Configure-only snapshots preserve absent fields "+initial_difference)
	var capacities: Array[int]=[0,0]; var admitted:=0; var rejected:=0
	for frame in 240:
		source.position=Vector3(sin(frame*0.04),0.2,cos(frame*0.03)); source.rotation=Vector3(frame*0.001,frame*0.02,-frame*0.001)
		pose_node.position=source.position+Vector3(0.1,0.2,0.3); pose_node.rotation=source.rotation+Vector3(0.1,-0.2,0.3)
		source.scale=Vector3(2,1.5,0.8) if frame%40<20 else Vector3.ONE; pose_node.scale=Vector3(1,2,3)
		var far:=frame%60<15
		var input:={"clip":["constant","linear","bezier","empty"][int(frame/30)%4],"time":fmod(frame/60.0,2.0),"delta":1.0/60.0,"view":view_packet(frame,far),"source_flags":0,"culling":true,"profile":false,"detonate":frame%30==1}
		if frame%30==0:
			input.patch={"flags":32|128|256,"source50":{"position":[0,0,0],"quaternion":[1,0,0,0],"adjustedScale":1.0,"opacity108":0.8,"instance":{"fade":1.0,"height50":0.5,"opacity70":0.6}},"instance100":{"fade":0.7 if frame%60==0 else 1.0,"height50":0.3,"opacity70":0.6}}
		var results: Array=[]
		for slot in 2:
			input.capacity=capacities[slot]
			var result: Dictionary=owners[slot].call("dispatch",1,input,callbacks[slot]); results.append(result)
			check(not result.has("error"),"Native transform frame "+str(frame)+"/"+str(slot)+" "+str(result.get("error","")))
			if result.has("error"): break
			check(bool(result.typed_emitter)==bool(slot),"Actual typed-frame selection "+str(frame)+"/"+str(slot))
			if result.has("capacity"): capacities[slot]=int(result.capacity)
		if results.size()!=2 or results.any(func(value):return value.has("error")): break
		if results[0].culled: rejected+=1
		else: admitted+=1
		check(results[0].get("positions")==results[1].get("positions") and results[0].get("attributes")==results[1].get("attributes") and results[0].get("count")==results[1].get("count"),"Native pose/culling GPU packet bytes "+str(frame))
		check(results[0].culled==results[1].culled and results[0].radius==results[1].radius,"Exact native admission and radius "+str(frame))
		var a: Dictionary=owners[0].call("dispatch",2,{},{}); var b: Dictionary=owners[1].call("dispatch",2,{},{})
		var difference:=same(a,b); check(difference.is_empty(),"Exact cold snapshot after transform/culling/controller changes "+str(frame)+" "+difference)
		check(rngs[0].state==rngs[1].state and rngs[0].draws==rngs[1].draws,"Native pose shared RNG order "+str(frame))
		if frame%30==0: await process_frame
	check(admitted>0 and rejected>0,"Both visible simulation and culled pose-only updates reached")
	var exposed: Dictionary=owners[1].call("dispatch",2,{},{}); exposed.source50.position=[999,999,999]; exposed.position1e0=[999,999,999]
	check(same(owners[0].call("dispatch",2,{},{}),owners[1].call("dispatch",2,{},{})).is_empty(),"Cold snapshots do not mutate primary typed state")
	for callback in callbacks: callback.clear()
	seed_owner.providers.clear(); scene.queue_free(); await process_frame; await process_frame
	for owner in owners:
		var stale: Dictionary=owner.call("dispatch",1,{"clip":"","time":0},{})
		check(str(stale.get("error","")).contains("pose owner is absent"),"Freed native pose identities remain guarded")
	var file:=FileAccess.open(args.report,FileAccess.WRITE)
	file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"network_connections":0,"scope":"Headless real Node3D transforms with distinct source/emitter poses and scale, controller/opacity patches, initially culled frames, exact packet bytes/RNG/cold snapshots and retired pose identities. No actual GPU rendering or FPS acceptance."},"\t")); file.close(); quit(0 if failures.is_empty() else 1)
