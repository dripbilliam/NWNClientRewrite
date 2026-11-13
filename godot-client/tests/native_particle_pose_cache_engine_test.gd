extends "res://tests/native_particle_typed_pose_test.gd"
# Actual Godot Transform3D reads and particle state/geometry, with a private
# candidate DLL. The uncached owner is the oracle in the same engine process.
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("report") or FileAccess.file_exists(args.report): quit(2); return
	check(Kernel.available() and ClassDB.class_exists("NwnParticleOwner"),"Private native extension loads")
	var scene:=Node3D.new(); root.add_child(scene)
	var parent_a:=Node3D.new(); var parent_b:=Node3D.new(); scene.add_child(parent_a); scene.add_child(parent_b)
	var pose_node:=Node3D.new(); var source:=Node3D.new(); parent_a.add_child(pose_node); parent_a.add_child(source)
	var source_id:=source.get_instance_id()
	var seed_owner:=make_owner(false,"fountain",32|128|256,false,false)
	var channel_owner:=Channels.new(); channel_owner.configure(channel_asset(),0)
	var owners: Array[RefCounted]=[]; var rngs: Array=[]; var callbacks: Array=[]
	for cached in [false,true]:
		var owner: RefCounted=ClassDB.instantiate("NwnParticleOwner")
		var configured: Dictionary=owner.call("dispatch",0,{"state":seed_owner.state,"update":"fountain","compactRecords":true,"typedEmitter":true,"poseId":pose_node.get_instance_id(),"sourceId":source_id,"cacheEnginePose":cached,"clips":channel_owner.clips},{})
		check(not configured.has("error"),"Native cache selection configures "+str(cached))
		owners.append(owner); var rng:=Random.new(); rng.seed_value(321); rngs.append(rng)
		callbacks.append({"random":rng.next,"cosineDouble":func(angle):return cos(angle),"addPointSourceWind":func(_p,_r,_l,_f):pass})
	var capacities: Array[int]=[0,0]; var accepted:=0; var rejected:=0
	for frame in 300:
		# Five stable frames for each changed value; parent movement, source-only
		# movement, local movement, nonuniform and reflected scales all participate.
		if frame%5==0:
			parent_a.position=Vector3(sin(frame*0.03),0.1,cos(frame*0.02))
			parent_a.rotation=Vector3(0.02,frame*0.002,0.03)
			parent_b.position=Vector3(-0.2,0.1,0.3); parent_b.rotation=Vector3(0.1,-0.2,0.3)
			source.position=Vector3(0.1,sin(frame*0.04)*0.2,0.3)
			source.rotation=Vector3(0.1,frame*0.01,-0.1)
			pose_node.position=Vector3(0.2,0.4,0.1); pose_node.rotation=Vector3(frame*0.002,0.2,-0.3)
			pose_node.scale=Vector3(1,2,3) if frame%40<20 else Vector3(-1,-2,-3)
			source.scale=Vector3(2,1.5,0.8) if frame%40<20 else Vector3.ONE
		if frame in [100,200]:
			var next_parent:=parent_b if frame==100 else parent_a
			source.reparent(next_parent,false); pose_node.reparent(next_parent,false)
		var input:={"clip":["constant","linear","bezier","empty"][int(frame/30)%4],"time":fmod(frame/60.0,2.0),"delta":1.0/60.0,"view":view_packet(frame+5000,frame%60<15),"source_flags":0,"culling":true,"profile":frame%13==0,"detonate":frame%30==1}
		if frame%30==0: input.patch={"flags":32|128|256,"birthRate":3.25}
		var results: Array=[]
		for slot in 2:
			input.capacity=capacities[slot]
			var result: Dictionary=owners[slot].call("dispatch",1,input,callbacks[slot]); results.append(result)
			check(not result.has("error"),"Actual pose frame "+str(frame)+"/"+str(slot)+" "+str(result.get("error","")))
			if result.has("capacity"): capacities[slot]=int(result.capacity)
		if results.any(func(value):return value.has("error")): break
		if results[0].culled: rejected+=1
		else: accepted+=1
		check(results[0].get("positions")==results[1].get("positions") and results[0].get("attributes")==results[1].get("attributes") and results[0].get("count")==results[1].get("count"),"Exact cached pose geometry "+str(frame))
		check(results[0].culled==results[1].culled and results[0].radius==results[1].radius,"Exact cached admission radius "+str(frame))
		var a: Dictionary=owners[0].call("dispatch",2,{},{}); var b: Dictionary=owners[1].call("dispatch",2,{},{})
		var difference:=same(without_ids(a),without_ids(b))
		check(difference.is_empty(),"Exact simulation/recycling/source pose "+str(frame)+" "+difference)
		check(rngs[0].state==rngs[1].state and rngs[0].draws==rngs[1].draws,"Exact RNG order "+str(frame))
	var cached: Dictionary=owners[1].call("dispatch",8,{},{}); var uncached: Dictionary=owners[0].call("dispatch",8,{},{})
	check(cached.get("enabled")==true and int(cached.get("hits",0))>300 and int(cached.get("conversions",0))>50,"Actual cache reuses stable inputs and converts changes")
	check(uncached.get("enabled")==false and int(uncached.get("hits",-1))==0,"Uncached oracle remains uncached")
	check(accepted>0 and rejected>0,"Visible and culled poses both checked")
	# A hit must still resolve its original live ID. A replacement at the same
	# transform cannot make the old owner valid, and a freed endpoint must error.
	source.free(); var replacement:=Node3D.new(); parent_a.add_child(replacement)
	check(replacement.get_instance_id()!=source_id,"Engine replacement has a distinct lifetime")
	for slot in 2:
		var invalid: Dictionary=owners[slot].call("dispatch",1,{"clip":"","time":0.0,"delta":0.0,"view":view_packet(99999,false),"source_flags":0,"culling":true},callbacks[slot])
		check(str(invalid.get("error","")).contains("pose owner is absent"),"Freed cached endpoint does not resolve replacement "+str(slot))
	for p in callbacks: p.clear()
	owners.clear(); rngs.clear(); seed_owner.providers.clear(); scene.free()
	var file:=FileAccess.open(args.report,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"cache":cached,"oracle":uncached,"accepted":accepted,"rejected":rejected,"network_connections":0,"scope":"Native cached versus uncached Transform3D conversion,300 frames: byte-identical geometry, admission, simulation/RNG, parent/local/source changes, reflected/nonuniform scale, reparenting and freed-ID validation. No GPU/FPS acceptance."},"\t")); file.close()
	print("NATIVE_POSE_CACHE_ENGINE ",checks," checks, ",failures.size()," failures"); quit(0 if failures.is_empty() else 1)
