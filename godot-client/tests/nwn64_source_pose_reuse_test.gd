extends "res://tests/native_particle_presentation_test.gd"
# Private candidate oracle: adjacent source-pose reuse must preserve every
# emitter's own state, packet bytes, callback order, RNG and retirement.

func make_group(scene: Node3D, reuse: bool) -> Dictionary:
	var holder:=Node3D.new();scene.add_child(holder)
	var source:=Node3D.new();holder.add_child(source)
	var rng:=Random.new();rng.seed_value(901)
	var events: Array=[]
	var presentation: RefCounted=ClassDB.instantiate("NwnParticlePresentation")
	var owners: Array=[]
	var poses: Array=[]
	for index in 5:
		var pose:=Node3D.new();holder.add_child(pose);poses.append(pose)
		var emitter:=Node3D.new();pose.add_child(emitter)
		var kind: String="fountain" if index==3 else "explosion"
		var seed_owner:=make_owner(false,kind,32|128,false,false)
		seed_owner.state.birthRate=60.0 if index==3 else 0.0
		seed_owner.state.lifeExp=1.0;seed_owner.state.velocity=0.0
		seed_owner.state.randomVelocity=0.0;seed_owner.state.spread=0.0
		var owner: RefCounted=ClassDB.instantiate("NwnParticleOwner")
		var config:={"state":seed_owner.state,"update":kind,"compactRecords":true,"typedEmitter":true,"poseId":pose.get_instance_id(),"sourceId":source.get_instance_id()}
		var configured: Dictionary=owner.call("dispatch",0,config,{})
		check(not configured.has("error"),"Private owner configures "+str(index))
		owners.append(owner)
		var providers:={"random":func():events.append(["random",index]);source.position.y+=0.001;return rng.next(),"cosineDouble":func(angle):return cos(angle)}
		var entry:={"id":emitter.get_instance_id(),"owner":owner,"providers":providers,"source_flags":0,"culling":false,"clip":""}
		if index==2:
			entry.clock=func():events.append(["clock",index]);source.position.x+=0.125;return {"clip":"","time":0.25}
		var added: Dictionary=presentation.call("dispatch",0,entry)
		check(not added.has("error"),"Private emitter registers "+str(index))
		seed_owner.providers.clear()
	return {"holder":holder,"source":source,"rng":rng,"events":events,"presentation":presentation,"owners":owners,"poses":poses,"reuse":reuse}

func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has("report") or FileAccess.file_exists(args.report):quit(2);return
	var scene:=Node3D.new();root.add_child(scene)
	var groups: Array=[make_group(scene,false),make_group(scene,true)]
	var total_hits:=0;var total_invalidations:=0;var total_reads:=0
	for frame in 48:
		var outputs: Array=[];var packets: Array=[]
		for group: Dictionary in groups:
			group.events.clear()
			group.source.position=Vector3(sin(frame*0.02),0.25,cos(frame*0.015))
			group.source.rotation=Vector3(0.01,frame*0.005,0.02)
			for index in 5:
				group.poses[index].position=Vector3(index*0.1,0.05,0.0)
				group.poses[index].rotation=Vector3(0.0,frame*0.003,0.0)
			var output: Dictionary=group.presentation.call("dispatch",1,{"delta":1.0/60.0,"view":view_packet(frame+8300000,false),"animating":true,"source_pose_reuse":group.reuse})
			check(not output.has("error"),"Frame succeeds "+str(frame)+"/"+str(group.reuse)+" "+str(output.get("error","")))
			outputs.append(output)
			packets.append(group.presentation.call("dispatch",2,{}))
		if outputs.any(func(value):return value.has("error")):break
		for field in ["prepared","active","vertices","culled","draws"]:
			check(outputs[0].get(field)==outputs[1].get(field),"Exact shared output "+field+" "+str(frame))
		check(packets[0].buffer==packets[1].buffer,"Exact geometry packet bytes "+str(frame))
		check(groups[0].events==groups[1].events,"Clock and RNG callback order "+str(frame))
		check(groups[0].rng.state==groups[1].rng.state and groups[0].rng.draws==groups[1].rng.draws,"Shared visual RNG "+str(frame))
		check(groups[0].source.global_transform==groups[1].source.global_transform,"Clock/random source mutation "+str(frame))
		for index in 5:
			var a: Dictionary=without_ids(groups[0].owners[index].call("dispatch",2,{},{}))
			var b: Dictionary=without_ids(groups[1].owners[index].call("dispatch",2,{},{}))
			check(same(a,b).is_empty(),"Exact private emitter state "+str(frame)+"/"+str(index))
		total_hits+=int(outputs[1].get("source_pose_reuse_hits",0))
		total_reads+=int(outputs[1].get("source_pose_live_reads",0))
		total_invalidations+=int(outputs[1].get("source_pose_invalidations",0))
	check(total_hits>0 and total_reads>0 and total_reads<48*5,"Adjacent route engaged and retains live reads")
	check(total_invalidations>0,"Clock and RNG boundaries invalidate prior source pose")
	for group: Dictionary in groups:group.source.free()
	await process_frame
	for group: Dictionary in groups:
		var after: Dictionary=group.presentation.call("dispatch",1,{"delta":1.0/60.0,"view":view_packet(8400000,false),"source_pose_reuse":group.reuse})
		check(not after.has("error") and int(after.get("prepared",-1))==0,"Retired source is not reused")
		group.presentation.call("dispatch",5,{})
	scene.free();await process_frame
	var report:={"success":failures.is_empty(),"checks":checks,"failures":failures,"frames":48,"source_pose_reuse_hits":total_hits,"source_pose_live_reads":total_reads,"source_pose_invalidations":total_invalidations,"scope":"Private same-binary OFF/ON source pose candidate, real Node3D mutation from actor clock and RNG callbacks; exact native snapshots, packet bytes, callback order, RNG, and retired source. Synthetic, no original scene or performance claim."}
	var file:=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print(JSON.stringify({"success":report.success,"checks":checks,"failures":failures.size(),"hits":total_hits,"reads":total_reads,"invalidations":total_invalidations}));quit(0 if failures.is_empty() else 1)
