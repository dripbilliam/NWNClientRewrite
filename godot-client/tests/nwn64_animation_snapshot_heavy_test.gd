extends "res://tests/nwn64_animation_snapshot_test.gd"
# Source-heavy exact output comparison. No wall clock or FPS measurement.

func one_leg(scene: Node3D, snapshot: bool) -> Dictionary:
	var holder:=Node3D.new();scene.add_child(holder)
	var presentation: RefCounted=ClassDB.instantiate("NwnParticlePresentation")
	var rng:=Random.new();rng.seed_value(333)
	var providers:={"random":rng.next,"cosineDouble":func(angle):return cos(angle)}
	var owners: Array=[];var nodes: Array=[]
	for index in 1750:
		var node:=Node3D.new();holder.add_child(node);nodes.append(node)
		node.position=Vector3(1000 if index<960 else float(index%17-8)*0.1,0,float(index%13-6)*0.1)
		var kind: String="single" if index<960 else "fountain"
		var seed:=make_owner(false,kind,32|128,false,false)
		seed.state.birthRate=40.0 if kind=="fountain" else 0.0
		seed.state.lifeExp=0.6;seed.state.mass=0.0;seed.state.velocity=0.0;seed.state.randomVelocity=0.0;seed.state.spread=0.0
		var owner: RefCounted=ClassDB.instantiate("NwnParticleOwner")
		var configured: Dictionary=owner.call("dispatch",0,{"state":seed.state,"update":kind,"compactRecords":true,"typedEmitter":true,"poseId":node.get_instance_id(),"sourceId":node.get_instance_id()}, {})
		check(not configured.has("error"),"Heavy configure "+str(index))
		var entry:={"id":node.get_instance_id(),"owner":owner,"providers":providers,"source_flags":0,"culling":true,"clip":""}
		if index%5==0:entry.clock=func():return {"clip":"","time":0.25}
		var added: Dictionary=presentation.call("dispatch",0,entry)
		check(not added.has("error"),"Heavy register "+str(index))
		owners.append(owner);seed.providers.clear()
	var last: Dictionary={};var packet: Dictionary={};var reads:=0
	for number in 3:
		var input:={"delta":1.0/60.0,"view":view_packet(number+8900000,false),"animating":true}
		if snapshot:input.animation_snapshot=true
		last=presentation.call("dispatch",1,input)
		check(not last.has("error"),"Heavy frame "+str(number)+": "+str(last.get("error","")))
		if last.has("error"):break
		reads+=int(last.get("animation_snapshot_reads",0))
		packet=presentation.call("dispatch",2,{})
	var result:={"registered":last.get("registered",-1),"prepared":last.get("prepared",-1),"culled":last.get("culled",-1),"active":last.get("active",-1),"vertices":last.get("vertices",-1),"draws":last.get("draws",-1),"rng_draws":rng.draws,"rng_state":rng.state,"packet_digest":packet.get("buffer",PackedByteArray()).hex_encode().sha256_text(),"snapshot_reads":reads}
	presentation.call("dispatch",5,{});holder.free();owners.clear();nodes.clear()
	return result

func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has("report") or FileAccess.file_exists(args.report):quit(2);return
	var scene:=Node3D.new();root.add_child(scene)
	var a:=one_leg(scene,false);await process_frame
	var b:=one_leg(scene,true);await process_frame
	for key in ["registered","prepared","culled","active","vertices","draws","rng_draws","rng_state","packet_digest"]:
		check(a[key]==b[key],"Heavy exact "+key)
	check(int(a.registered)==1750 and int(a.prepared)==1750 and int(a.culled)==960,"Source-heavy population and culling")
	check(int(a.active)>0 and int(a.vertices)>0,"Source-heavy simulation and geometry active")
	check(int(a.snapshot_reads)==0 and int(b.snapshot_reads)==3,"One opted-in animation read per source-heavy frame")
	scene.free();await process_frame
	var report:={"issue":"NWN-64","success":failures.is_empty(),"checks":checks,"failures":failures,"source_count":1750,"culled_count":960,"frames_per_leg":3,"default":a,"snapshot":b,"scope":"Private 1,750-source native simulation and packet comparison. No wall clock, renderer, FPS, original scene or Arelith claim."}
	var file:=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print(JSON.stringify({"success":report.success,"checks":checks,"failures":failures,"prepared":b.prepared,"culled":b.culled,"snapshot_reads":b.snapshot_reads}));quit(0 if failures.is_empty() else 1)
