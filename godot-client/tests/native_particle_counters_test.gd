extends "res://tests/native_particle_schedule_test.gd"
const Metrics=preload("res://systems/native_render/particle_metrics.gd")
const Profile=preload("res://systems/native_render/frame_profile.gd")
class MockSurface extends RefCounted:
	var vertex_count:=0
class MockChannels extends RefCounted:
	var constant_hits:=0
	var sampled_channels:=0
class MockEmitter extends Node:
	var source_model_flags:=0
	var frames:=0
	var surface:=MockSurface.new()
	var failure:=""
	var fused_dispatch:=true
	var native_parameter_transfer:=true
	var channels:=MockChannels.new()
	var culling_checks:=0
	var culled_frames:=0
	var last_culled:=false
	var culling_fallbacks:=0
	var active:=0
	func active_count() -> int: return active
func native_api() -> void:
	var owner: RefCounted=ClassDB.instantiate("NwnParticleCounters")
	var values:=PackedInt64Array(); values.resize(15)
	check(owner.call("register_id",10) and owner.call("register_id",20),"Native counters register distinct IDs")
	check(not owner.call("register_id",10),"Duplicate registration preserves the previous record")
	for n in 15: values[n]=n+1
	check(owner.call("update",10,values),"Native fixed record update succeeds")
	var snapshot: PackedInt64Array=owner.call("snapshot")
	check(snapshot==values,"Native counter totals match the exact integer record")
	values[0]=999; check(owner.call("snapshot")[0]==1,"Applied counters retain values without borrowing the caller's array")
	snapshot[1]=999; check(owner.call("snapshot")[1]==2,"Published counter snapshots cannot mutate retained totals")
	check(owner.call("update",20,values),"Second independent counter record updates")
	var expected:=values.duplicate()
	for n in 15: expected[n]+=n+1
	check(owner.call("snapshot")==expected,"Counters accumulate all registered records")
	check(owner.call("remove_id",10) and owner.call("snapshot")==values,"Removal subtracts the exact last record")
	check(not owner.call("remove_id",10),"Duplicate removal cannot subtract twice")
	var invalid:=PackedInt64Array(); invalid.resize(14)
	check(not owner.call("update",20,invalid) and owner.call("error")==1203 and owner.call("snapshot")==values,"Malformed counter records are rejected before changing sums")
	owner.call("close"); var zero:=PackedInt64Array(); zero.resize(15)
	check(owner.call("snapshot")==zero and not owner.call("register_id",30) and not owner.call("update",20,values),"Closed counters release records and reject later updates")
	owner=null
func phase_collection() -> Dictionary:
	var packets: Array=[]
	for index in 1506: packets.append({"native_particle_resident_controls":float(index%3)*0.001,"native_particle_channels_pose":float(index%7)*0.003,"native_particle_admission":float(index%5)*0.004,"native_particle_simulation":float(index%11)*0.002,"native_particle_vertices":float(index%13)*0.003})
	var timings: Array=[]
	for postdraw in [false,true]:
		var results: Array=[]
		for batch in [false,true]:
			Profile.enabled=true; Profile.phase_frame=-1; Profile.phases={}; Profile.postdraw_phases={}; Profile.collected_frame=Engine.get_process_frames() if postdraw else -1
			var began:=Time.get_ticks_usec()
			for packet: Dictionary in packets:
				if batch: Profile.record_batch(packet)
				else:
					for name in packet: Profile.record(str(name),float(packet[name]))
			timings.append({"batch":batch,"postdraw":postdraw,"milliseconds":(Time.get_ticks_usec()-began)/1000.0})
			results.append((Profile.postdraw_phases if postdraw else Profile.phases).duplicate())
		check(same(results[0],results[1]).is_empty(),"Batched profiler values retain exact sum/order and postdraw routing "+str(postdraw))
	Profile.enabled=false; Profile.phases={}; Profile.postdraw_phases={}; Profile.phase_frame=-1; Profile.collected_frame=-1
	return {"emitter_count":1506,"timing":timings}
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("report") or FileAccess.file_exists(args.report): quit(2); return
	check(ClassDB.class_exists("NwnParticleCounters"),"Native world counter class registered")
	if not ClassDB.class_exists("NwnParticleCounters"): quit(1); return
	native_api()
	var a:=Metrics.new(false); var b:=Metrics.new(true)
	var emitters: Array[MockEmitter]=[]
	for index in 1506:
		var emitter:=MockEmitter.new(); root.add_child(emitter); emitter.source_model_flags=[0,2,4,8][index%4]
		emitters.append(emitter); a.register(emitter); b.register(emitter)
	var timing: Array=[[],[]]
	for frame in 32:
		for index in emitters.size():
			var emitter:=emitters[index]; emitter.frames=frame; emitter.active=(frame+index)%3; emitter.surface.vertex_count=emitter.active*6
			emitter.fused_dispatch=index%3!=0; emitter.native_parameter_transfer=index%5!=0; emitter.channels.constant_hits=frame*5+index; emitter.channels.sampled_channels=frame
			emitter.culling_checks=frame; emitter.culled_frames=int(frame/3); emitter.last_culled=(frame+index)%4==0; emitter.culling_fallbacks=int(frame/5)
			if index%301==0: emitter.failure="authored failure" if frame%10<5 else ""
		for turn in 2:
			var slot: int=(turn+frame)%2; var metrics: RefCounted=a if slot==0 else b; var began:=Time.get_ticks_usec()
			for emitter in emitters: metrics.update(emitter)
			if frame>=8: timing[slot].append((Time.get_ticks_usec()-began)/1000.0)
		var difference:=same(a.snapshot(),b.snapshot()); check(difference.is_empty(),"Exact full world counters/reasons/classifications "+str(frame)+" "+difference)
	for index in range(0,emitters.size(),7): a.unregister(emitters[index]); b.unregister(emitters[index])
	check(same(a.snapshot(),b.snapshot()).is_empty(),"Native/GD removal preserves totals and diagnostics")
	a.close(); b.close(); check(same(a.snapshot(),b.snapshot()).is_empty(),"Native/GD world retirement clears all totals")
	for emitter in emitters: emitter.queue_free()
	emitters.clear(); await process_frame; await process_frame
	var phase_result:=phase_collection()
	var file:=FileAccess.open(args.report,FileAccess.WRITE)
	file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"metrics_samples_ms":{"gd":timing[0],"native":timing[1]},"phases":phase_result,"network_connections":0,"scope":"Headless native counter ABI/ownership/bounds/lifecycle and 1506 mock emitter counters matching full existing diagnostics; exact batched profiler sums and postdraw routing. Bookkeeping-only timing excludes actual simulation, scene drawing and gameplay; no FPS acceptance."},"\t")); file.close(); quit(0 if failures.is_empty() else 1)
