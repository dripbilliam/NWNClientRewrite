extends "res://tests/nwn64_animation_snapshot_test.gd"
# Private, profile-off component timing with the same 1,750-source population.
# Measures dispatch only, after ten warmup frames; not client FPS.

func statistics(values: Array) -> Dictionary:
	values.sort()
	return {"count":values.size(),"median_us":values[values.size()/2],"p95_us":values[mini(values.size()-1,int(ceil(values.size()*0.95))-1)],"max_us":values[-1]}

func one_leg(scene: Node3D,snapshot: Variant) -> Dictionary:
	var holder:=Node3D.new();scene.add_child(holder)
	var presentation: RefCounted=ClassDB.instantiate("NwnParticlePresentation")
	var rng:=Random.new();rng.seed_value(333)
	var providers:={"random":rng.next,"cosineDouble":func(angle):return cos(angle)}
	var owners: Array=[]
	for index in 1750:
		var node:=Node3D.new();holder.add_child(node)
		node.position=Vector3(1000 if index<960 else float(index%17-8)*0.1,0,float(index%13-6)*0.1)
		var kind: String="single" if index<960 else "fountain"
		var seed:=make_owner(false,kind,32|128,false,false)
		seed.state.birthRate=40.0 if kind=="fountain" else 0.0
		seed.state.lifeExp=0.6;seed.state.mass=0.0;seed.state.velocity=0.0;seed.state.randomVelocity=0.0;seed.state.spread=0.0
		var owner: RefCounted=ClassDB.instantiate("NwnParticleOwner")
		var configured: Dictionary=owner.call("dispatch",0,{"state":seed.state,"update":kind,"compactRecords":true,"typedEmitter":true,"poseId":node.get_instance_id(),"sourceId":node.get_instance_id()}, {})
		check(not configured.has("error"),"Configure timing owner "+str(index))
		var entry:={"id":node.get_instance_id(),"owner":owner,"providers":providers,"source_flags":0,"culling":true,"clip":""}
		if index%5==0:entry.clock=func():return {"clip":"","time":0.25}
		var added: Dictionary=presentation.call("dispatch",0,entry)
		check(not added.has("error"),"Register timing owner "+str(index))
		owners.append(owner);seed.providers.clear()
	var samples: Array=[];var mixed_off: Array=[];var mixed_on: Array=[];var last: Dictionary={};var packet: Dictionary={};var reads:=0
	var frames:=300 if snapshot==null else 90
	for number in frames:
		var input:={"delta":1.0/60.0,"view":view_packet(number+8900000,false),"animating":true}
		var use_snapshot: bool=(number%4==1 or number%4==2) if snapshot==null else snapshot
		if use_snapshot:input.animation_snapshot=true
		var began:=Time.get_ticks_usec()
		last=presentation.call("dispatch",1,input)
		var elapsed:=Time.get_ticks_usec()-began
		if number>=20 and snapshot==null:
			if use_snapshot:mixed_on.append(elapsed)
			else:mixed_off.append(elapsed)
		elif number>=10 and snapshot!=null:samples.append(elapsed)
		if last.has("error"):failures.append("Frame %d: %s"%[number,str(last.error)]);break
		reads+=int(last.get("animation_snapshot_reads",0))
		if number==frames-1:packet=presentation.call("dispatch",2,{})
	var timing: Dictionary={"off":statistics(mixed_off),"on":statistics(mixed_on)} if snapshot==null else statistics(samples)
	var result:={"timing":timing,"prepared":last.get("prepared",-1),"culled":last.get("culled",-1),"active":last.get("active",-1),"vertices":last.get("vertices",-1),"draws":last.get("draws",-1),"rng_draws":rng.draws,"rng_state":rng.state,"packet_digest":packet.get("buffer",PackedByteArray()).hex_encode().sha256_text(),"snapshot_reads":reads}
	presentation.call("dispatch",5,{});holder.free();owners.clear()
	return result

func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has("report") or FileAccess.file_exists(args.report):quit(2);return
	var scene:=Node3D.new();root.add_child(scene)
	if args.has("interleaved"):
		var mixed: Dictionary=one_leg(scene,null)
		check(mixed.timing.off.count==140 and mixed.timing.on.count==140,"Balanced interleaved samples")
		check(mixed.snapshot_reads==150 and mixed.prepared==1750 and mixed.culled==960,"Interleaved work/read population")
		scene.free();await process_frame
		var mixed_report:={"issue":"NWN-64","success":failures.is_empty(),"checks":checks,"failures":failures,"source_count":1750,"culled_count":960,"warmup_frames":20,"timed_frames_per_mode":140,"order":"off/on/on/off repeating on one presentation","timing":mixed.timing,"scope":"Same private DLL and persistent source-heavy owner, interleaved opt-in dispatch. Preliminary component CPU only; no normal-client FPS or Arelith claim."}
		var mixed_file:=FileAccess.open(args.report,FileAccess.WRITE);mixed_file.store_string(JSON.stringify(mixed_report,"\t"));mixed_file.close()
		print(JSON.stringify({"success":mixed_report.success,"checks":checks,"timing":mixed.timing}));quit(0 if failures.is_empty() else 1);return
	var legs: Array=[]
	for snapshot in [false,true,true,false]:
		var result:=one_leg(scene,snapshot);result.snapshot=snapshot;legs.append(result)
		await process_frame
	for leg in legs:
		check(leg.timing.count==80 and leg.prepared==1750 and leg.culled==960,"Complete source-heavy timing leg")
		check(leg.snapshot_reads==(90 if leg.snapshot else 0),"Exact snapshot read count")
	for index in range(1,legs.size()):
		for key in ["active","vertices","draws","rng_draws","rng_state","packet_digest"]:check(legs[index][key]==legs[0][key],"Exact final "+key+" leg "+str(index))
	scene.free();await process_frame
	var report:={"issue":"NWN-64","success":failures.is_empty(),"checks":checks,"failures":failures,"source_count":1750,"culled_count":960,"warmup_frames":10,"timed_frames_per_leg":80,"order":"off/on/on/off","legs":legs,"scope":"Same private DLL, profile-off source-heavy native frame dispatch only; excludes construction and packet read. No normal-client FPS or Arelith claim."}
	var file:=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print(JSON.stringify({"success":report.success,"checks":checks,"failures":failures,"timing":legs.map(func(leg):return leg.timing)}));quit(0 if failures.is_empty() else 1)
