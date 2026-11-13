extends "res://tests/nwn64_typed_pose_test.gd"
# Private sampler OFF/ON correctness. No FPS or throughput acceptance.
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has("report") or FileAccess.file_exists(args.report):quit(2);return
	var sources:=clampi(int(args.get("sources",48)),12,2048)
	var frames:=clampi(int(args.get("frames",45)),12,240)
	var stride:=clampi(int(args.get("state-stride",1)),1,240)
	var far_sources:=clampi(int(args.get("far-sources",sources>>1)),0,sources)
	var require_audit: bool=args.get("require-audit","true")=="true"
	var scene:=Node3D.new();root.add_child(scene)
	var nodes: Array[Node3D]=[];var parents: Array[Node3D]=[]
	for group in ceili(sources/8.0):
		var source:=Node3D.new();scene.add_child(source);source.position=Vector3(1000 if group*8<far_sources else 0,0,0);parents.append(source)
	for index in sources:
		var node:=Node3D.new();parents[index>>3].add_child(node);node.position=Vector3((index%7-3)*0.07,0,(index%5-2)*0.05);nodes.append(node)
	var presentations: Array[RefCounted]=[];var owners: Array=[];var providers: Array=[];var rngs: Array=[];var observations: Array=[]
	var channels:=Channels.new();channels.configure(channel_asset(),0)
	for slot in 2:
		var presenter: RefCounted=ClassDB.instantiate("NwnParticlePresentation");presentations.append(presenter)
		presenter.call("dispatch",15,{"enabled":true,"stride":3,"min_members":0,"coarse_phases":true,"preparation_subphases":slot==1,"setup_boundary":true})
		var rng:=Random.new();rng.seed_value(7341);rngs.append(rng)
		var state: Dictionary={"frame":0,"clock":0,"ready":0,"calls":[]};observations.append(state)
		var callback: Dictionary={"random":func():state.calls.append("r");return rng.next(),"cosineDouble":func(value):state.calls.append("c");return cos(value),"addPointSourceWind":func(_p,_r,_l,_f):state.calls.append("w")};providers.append(callback)
		var native: Array[RefCounted]=[];owners.append(native)
		for index in sources:
			var kind: String=["fountain","explosion","single"][index%3]
			var seed_owner:=make_owner(false,kind,32|128,false,false)
			seed_owner.state.birthRate=0.0 if index%11==0 else 1.0 if kind=="single" else 6.0
			seed_owner.state.blastRadius=0.0;seed_owner.state.renderMode1a8=index%7
			seed_owner.state.detonate108=int(kind=="explosion");seed_owner.state.accumulator198=float(index%8)/60.0
			var node: Node3D=nodes[index]
			var config: Dictionary={"state":seed_owner.state,"update":kind,"compactRecords":true,"typedEmitter":true,"poseId":node.get_instance_id(),"sourceId":node.get_parent().get_instance_id()}
			if index%7==0:config.clips=channels.clips
			var owner: RefCounted=ClassDB.instantiate("NwnParticleOwner");native.append(owner)
			check(not owner.call("dispatch",0,config,{}).has("error"),"Preparation owner configures "+str(slot)+"/"+str(index))
			var entry: Dictionary={"id":node.get_instance_id(),"owner":owner,"providers":callback,"source_flags":0,"clip":"linear","clip_length":1.0,"culling":true}
			if index%5==0:entry.clock=func():state.clock+=1;state.calls.append("k");return {"clip":"linear","time":state.frame/60.0}
			if index%17==0:entry.ready=func():state.ready+=1;state.calls.append("q");return state.frame>=2
			check(not presenter.call("dispatch",0,entry).has("error"),"Preparation source registers "+str(slot)+"/"+str(index))
			seed_owner.providers.clear()
	var packet_hash:=HashingContext.new();packet_hash.start(HashingContext.HASH_SHA256)
	var state_hash:=HashingContext.new();state_hash.start(HashingContext.HASH_SHA256)
	var retained: PackedByteArray;var retained_digest: String="";var phase_packets:=0
	for frame in frames:
		for state in observations:state.frame=frame;state.calls.clear()
		for group in parents.size():parents[group].rotation.y=frame*0.001;parents[group].position.z=sin(frame*0.03)*0.1
		var results: Array=[]
		for slot in 2:
			if frame%13==0:
				var index:=frame%sources
				presentations[slot].call("dispatch",4,{"id":nodes[index].get_instance_id(),"patch":{"fps":float(frame%9),"alphaStart":0.75},"detonate":true})
			var common: Dictionary={"delta":[1.0/60.0,0.0,-0.002,0.7][frame%4],"view":view_packet(frame+9100000,frame%19<4),"profile":false,"native_surface_output":true,"animating":frame%23!=0}
			var result: Dictionary=presentations[slot].call("dispatch",1,common);results.append(result)
			check(not result.has("error"),"Preparation sampled frame "+str(frame)+"/"+str(slot)+" "+str(result.get("error","")))
			phase_packets+=int(result.has("phases"))
		check(same(results[0],results[1]).is_empty(),"Profile=false results remain byte-for-byte equivalent "+str(frame))
		check(rngs[0].state==rngs[1].state and rngs[0].draws==rngs[1].draws,"World RNG sequence preserved "+str(frame))
		check(observations[0].calls==observations[1].calls and observations[0].clock==observations[1].clock and observations[0].ready==observations[1].ready,"Readiness/clock/RNG callback order preserved "+str(frame))
		var a: Dictionary=presentations[0].call("dispatch",2,{});var b: Dictionary=presentations[1].call("dispatch",2,{})
		check(a.get("buffer")==b.get("buffer") and same(a.get("ranges",[]),b.get("ranges",[])).is_empty(),"Exact sorted geometry and bounds "+str(frame))
		var packet_bytes: PackedByteArray=a.get("buffer",PackedByteArray())
		if not packet_bytes.is_empty():packet_hash.update(packet_bytes)
		if retained.is_empty() and not a.get("buffer",PackedByteArray()).is_empty():retained=a.buffer;retained_digest=retained.hex_encode().sha256_text()
		if frame%stride==0 or frame==frames-1:
			for index in sources:
				var state_a: Dictionary=owners[0][index].call("dispatch",2,{},{});var state_b: Dictionary=owners[1][index].call("dispatch",2,{},{})
				check(same(state_a,state_b).is_empty(),"Exact emitter/active/free state "+str(frame)+"/"+str(index))
				state_hash.update(var_to_bytes(state_a))
	check(phase_packets==0,"Public detailed phase packets remain absent on every normal frame")
	check(not retained.is_empty() and retained.hex_encode().sha256_text()==retained_digest,"Retained old packed output remains immutable")
	var before: Array=[];var after: Array=[]
	for slot in 2:
		before.append(presentations[slot].call("dispatch",16,{}))
		presentations[slot].call("dispatch",1,{"delta":0.0,"view":view_packet(9900000,false),"profile":true,"native_surface_output":true,"animating":true})
		after.append(presentations[slot].call("dispatch",16,{}))
		check(int(after[slot].excluded_detailed_samples)==int(before[slot].excluded_detailed_samples)+int(frames%3==0),"Detailed profile is excluded on the sparse schedule "+str(slot))
	if require_audit:
		check(before[1].get("preparation_subphases",false) and not before[0].get("preparation_subphases",true),"Private preparation sampler is explicitly ON/OFF")
		var engaged:=0;var duplicate_source:=0;var callbacks_seen:=0
		for sample in before[1].records:
			if sample.has("preparation_audit"):
				engaged+=1;duplicate_source+=int(sample.preparation_audit.counts.repeated_source_pose_id);callbacks_seen+=int(sample.preparation_audit.counts.live_clock_boundary)
		check(engaged>0 and duplicate_source>0 and callbacks_seen>0,"Actual private subphases, repeated source poses and live-clock census engage")
		check(before[0].records.all(func(sample):return not sample.has("preparation_audit")),"Control sampler adds no preparation record")
	var last_state: Dictionary={"rng_state":rngs[0].state,"rng_draws":rngs[0].draws,"clock_calls":observations[0].clock,"readiness_calls":observations[0].ready}
	var boundary: Dictionary=presentations[0].call("dispatch",13,{})
	for slot in 2:presentations[slot].call("dispatch",5,{});providers[slot].clear()
	presentations.clear();owners.clear();scene.free();await process_frame
	var report: Dictionary={"issue":"NWN-64/NWN-73","success":failures.is_empty(),"checks":checks,"failures":failures,"sources":sources,"far_sources_requested":far_sources,"frames":frames,"state_stride":stride,"require_audit":require_audit,"public_profile_false_frames":frames*2,"public_phase_packets":phase_packets,"packet_digest":packet_hash.finish().hex_encode(),"state_digest":state_hash.finish().hex_encode(),"state":last_state,"boundary":boundary,"samplers":before,"scope":"Pure private native component correctness and sparse diagnostic census; callback order, full selected-frame states, immutable exact sorted packet and profile=false sampler OFF/ON. Synthetic source hierarchy, no original-scene, renderer, timing or FPS acceptance."}
	var file:=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close();print("NWN64_PREPARATION ",checks," checks; ",failures.size()," failures");quit(0 if failures.is_empty() else 1)
