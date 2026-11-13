extends "res://tests/native_particle_typed_pose_test.gd"
func interleave(packet: Dictionary) -> PackedByteArray:
	var count:=int(packet.get("count",0)); var out:=PackedByteArray(); out.resize(count*24)
	for vertex in count:
		var source:=vertex*12; var target:=vertex*24
		for byte in 4: out[target+byte]=packet.attributes[source+byte]
		for byte in 12: out[target+4+byte]=packet.positions[source+byte]
		for byte in 8: out[target+16+byte]=packet.attributes[source+4+byte]
	return out
func callbacks(rng: RefCounted,events: Array,index: int) -> Dictionary:
	return {"random":func():events.append(["random",index]); return rng.next(),"cosineDouble":func(angle):return cos(angle),
		"collide":func(_old,goal,out,hit):
			hit.normal=[0.0,0.0,1.0]
			if goal[2]>=0: return false
			out.assign([goal[0],goal[1],0.0]); events.append(["collision",index]); return true,
		"addPointSourceWind":func(_p,_r,_l,_f):events.append(["wind",index])}
func chunks(events: Array) -> Dictionary:
	var serial:={"next":0}
	return {"createChunkModel":func(_name):serial.next+=1; return "private"+str(serial.next),
		"chunkScene":func(_child,_attached):pass,"chunkScale":func(_child,_scale,_kind):pass,"chunkPlay":func(_child,_name,_speed,_flags,_time):pass,
		"chunkPosition":func(child,position):events.append(["chunk_position",child,position.duplicate()]),
		"chunkOrientation":func(child,q):events.append(["chunk_orientation",child,q.duplicate()]),
		"detachChunk":func(_child,_scene):pass,
		"destroyChunkModel":func(child,_flag):events.append(["chunk_destroy",child]),
		"resetIgnoredHits":func(_hit):pass,"addIgnoredHit":func(_hit,_child):pass}
func main_frames() -> Dictionary:
	var scene:=Node3D.new(); root.add_child(scene)
	var presentation: RefCounted=ClassDB.instantiate("NwnParticlePresentation")
	var rngs: Array=[]; var traces: Array=[[],[]]; var callbacks_by_slot: Array=[[],[]]; var owners: Array=[[],[]]
	for slot in 2:
		var rng:=Random.new(); rng.seed_value(884); rngs.append(rng)
	var channel_owner:=Channels.new(); channel_owner.configure(channel_asset(),0)
	var nodes: Array[Node3D]=[]; var sources: Array[Node3D]=[]; var capacities: Array[int]=[]; var clocks: Array=[]
	for index in 8:
		var source:=Node3D.new(); scene.add_child(source); sources.append(source)
		var pose_node:=Node3D.new(); scene.add_child(pose_node); nodes.append(pose_node); capacities.append(0)
		var clock:={"clip":"linear","time":0.0}; clocks.append(clock)
		var kind: String=["fountain","explosion","single"][index%3]
		var seed_owner:=make_owner(false,kind,32|128|16,false,false)
		seed_owner.state.renderMode1a8=maxi(index-1,0)
		if index==0: seed_owner.state.chunkName="private_test_chunk"
		for slot in 2:
			var owner: RefCounted=ClassDB.instantiate("NwnParticleOwner")
			var configured: Dictionary=owner.call("dispatch",0,{"state":seed_owner.state,"update":kind,"compactRecords":true,"typedEmitter":true,"poseId":pose_node.get_instance_id(),"sourceId":source.get_instance_id(),"clips":channel_owner.clips},{})
			check(not configured.has("error"),"Presentation comparison typed owner configures "+str(slot)+"/"+str(index))
			owners[slot].append(owner); var providers:=callbacks(rngs[slot],traces[slot],index)
			if index==0: providers.merge(chunks(traces[slot]),true)
			callbacks_by_slot[slot].append(providers)
		var config:={"id":pose_node.get_instance_id(),"owner":owners[1][index],"providers":callbacks_by_slot[1][index],"source_flags":0,"clip":"constant","clip_length":3.0,"culling":true}
		if index==3: config.clock=func():return clock
		var added: Dictionary=presentation.call("dispatch",0,config)
		check(not added.has("error"),"Presentation owns typed emitter "+str(index)+" "+str(added.get("error","")))
		seed_owner.providers.clear()
	var elapsed: Array[float]=[]; elapsed.resize(8); elapsed.fill(0.0)
	var enabled: Array[bool]=[]; enabled.resize(8); enabled.fill(true)
	var retained: PackedByteArray; var retained_copy: PackedByteArray; var phase_separation_observed:=false
	var samples:=0
	for frame in 180:
		var delta: float=[1.0/60,1.0/40,0.0,-0.002,0.7][frame%5]
		var view:=view_packet(frame+1000,frame%60<10)
		var expected: Dictionary={}; traces[0].clear(); traces[1].clear()
		for index in 8:
			sources[index].position=Vector3(sin(frame*0.04)+index*0.4,0.3,cos(frame*0.03)); sources[index].rotation=Vector3(0.1,frame*0.02,0.3)
			nodes[index].position=sources[index].position+Vector3(0.2,0.1,0.4); nodes[index].rotation=sources[index].rotation+Vector3(0.1,-0.2,0.3)
			sources[index].scale=Vector3(1.2,0.8,1.1) if frame%40<20 else Vector3.ONE
			clocks[index].time=fmod(frame/60.0,2.0)
			if frame==80 and index==3: presentation.call("dispatch",4,{"id":nodes[index].get_instance_id(),"clock":Callable()})
			if frame in [50,60] and index==5:
				enabled[index]=frame==60; presentation.call("dispatch",4,{"id":nodes[index].get_instance_id(),"enabled":enabled[index]})
			if not enabled[index]: continue
			elapsed[index]+=delta
			var input:={"clip":"linear" if index==3 and frame<80 else "constant","time":clocks[index].time if index==3 and frame<80 else fposmod(elapsed[index],3.0),"delta":delta,"view":view,"capacity":capacities[index],"source_flags":0,"culling":true}
			if frame%25==0:
				input.patch={"flags":32|128|16,"birthRate":17.0}; input.detonate=index%3==1
				presentation.call("dispatch",4,{"id":nodes[index].get_instance_id(),"patch":input.patch,"detonate":input.detonate})
			var packet: Dictionary=owners[0][index].call("dispatch",1,input,callbacks_by_slot[0][index])
			check(not packet.has("error"),"Existing complete native frame "+str(frame)+"/"+str(index)+" "+str(packet.get("error","")))
			if packet.has("capacity"): capacities[index]=int(packet.capacity)
			expected[nodes[index].get_instance_id()]=packet
		var result: Dictionary=presentation.call("dispatch",1,{"delta":delta,"view":view})
		check(not result.has("error"),"Separate native scene update and geometry passes "+str(frame)+" "+str(result.get("error","")))
		if result.has("error"): break
		var actual: Dictionary=presentation.call("dispatch",2,{})
		check(actual.buffer.size()==int(actual.vertices)*24,"Shared frame packet contains only active vertices "+str(frame))
		var seen: Dictionary={}
		for range_data: Dictionary in actual.ranges:
			var packet: Dictionary=expected.get(int(range_data.id),{})
			var bytes:=interleave(packet); var begin:=int(range_data.first)*24; var end:=begin+int(range_data.count)*24
			check(actual.buffer.slice(begin,end)==bytes and int(range_data.count)==int(packet.get("count",0)),"Exact active shared geometry range "+str(frame)+"/"+str(range_data.id))
			seen[int(range_data.id)]=true
		for id in expected:
			if int(expected[id].get("count",0))>0: check(seen.has(id),"No visible effect omitted by active-only scene packing "+str(frame)+"/"+str(id))
		for index in 8:
			var difference:=same(without_ids(owners[0][index].call("dispatch",2,{},{})),without_ids(owners[1][index].call("dispatch",2,{},{})))
			check(difference.is_empty(),"Exact state/recycling/atlas after phase separation "+str(frame)+"/"+str(index)+" "+difference)
		check(rngs[0].state==rngs[1].state and rngs[0].draws==rngs[1].draws,"Shared RNG order preserved across all update passes "+str(frame))
		for diagnostic: Dictionary in actual.emitters:
			check(diagnostic.legacy_position_bytes==0 and diagnostic.legacy_attribute_bytes==0,"Shared native path never allocates per-emitter capacity arrays "+str(frame)+"/"+str(diagnostic.id))
		if frame==20: retained=actual.buffer; retained_copy=retained.duplicate()
		if frame>20: check(retained==retained_copy,"A later scene frame cannot mutate an already published byte packet "+str(frame))
		var last_random:=-1; var first_chunk_pose:=-1
		for event in traces[1].size():
			if traces[1][event][0]=="random": last_random=event
			if traces[1][event][0]=="chunk_position" and first_chunk_pose<0: first_chunk_pose=event
		if first_chunk_pose>=0 and last_random>=0:
			check(first_chunk_pose>last_random,"Original scene update pass completes before private chunk rendering "+str(frame)); phase_separation_observed=true
		samples+=1
		if not failures.is_empty(): break
	check(samples==180 and phase_separation_observed,"Complete moving/culling/controller/collision/chunk phase-separation window reached")
	var stats: Dictionary=presentation.call("dispatch",7,{})
	presentation.call("dispatch",5,{})
	check(presentation.call("dispatch",1,{"delta":0.01,"view":view_packet(9999,false)}).has("error"),"Closed native scene rejects another frame")
	check(retained==retained_copy,"Retiring a scene keeps previously published packet ownership intact")
	for group in callbacks_by_slot:
		for callback in group: callback.clear()
	owners.clear(); presentation=null; scene.free()
	return {"frames":samples,"last":stats,"phase_separation":phase_separation_observed}
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("report") or FileAccess.file_exists(args.report): quit(2); return
	check(ClassDB.class_exists("NwnParticlePresentation"),"Experimental native scene presentation class registers")
	if not ClassDB.class_exists("NwnParticlePresentation"): quit(1); return
	var frames:=main_frames()
	await process_frame; await process_frame
	var file:=FileAccess.open(args.report,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"frames":frames,"network_connections":0,"gpu_execution":false,"scope":"Headless prototype: eight typed moving emitters share one active-only immutable packet, compared with complete existing native state/geometry/RNG across 180 varied-delta frames, all seven quad modes, collisions, chunks, culling, clocks and pause controls. Original-instruction geometry and native sort/admission corpora have separate tests. No actual GPU or whole-scene FPS acceptance."},"\t")); file.close(); quit(0 if failures.is_empty() else 1)
