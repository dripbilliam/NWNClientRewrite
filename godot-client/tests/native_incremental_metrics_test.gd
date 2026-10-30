extends "res://tests/native_particle_admission_test.gd"
const LiveWorld=preload("res://systems/native_render/live_world.gd")
func audit(world: Node3D) -> Dictionary:
	var sums: Dictionary={"emitters":0,"active":0,"vertices":0,"failed":0,"simulated":0,"culled_frames":0,"culling_checks":0,"culled_emitters":0,"currently_culled":0,"constant_channel_hits":0,"sampled_channels":0}
	for emitter in get_nodes_in_group("native_original_particle_emitters"):
		if not world.is_ancestor_of(emitter) or emitter.retired: continue
		var sample: Dictionary=emitter.snapshot(); sums.emitters+=1
		for key in ["active","vertices","culled_frames","culling_checks"]: sums[key]+=int(sample[key])
		sums.failed+=int(not str(sample.failure).is_empty()); sums.simulated+=int(sample.frames>0); sums.culled_emitters+=int(sample.culled_frames>0); sums.currently_culled+=int(sample.culled)
		sums.constant_channel_hits+=int(sample.channel_cache.constant_hits); sums.sampled_channels+=int(sample.channel_cache.sampled_channels)
	return sums
func compare(world: Node3D,label: String) -> void:
	var actual: Dictionary=world.particle_metrics.snapshot(); var expected:=audit(world)
	for key in expected: check(actual[key]==expected[key],label+" "+str(key))
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("report") or FileAccess.file_exists(args.report): quit(2); return
	var world:=LiveWorld.new(); root.add_child(world); world.set_process(false)
	var camera:=Camera3D.new(); world.add_child(camera); camera.position=Vector3(0,1,10); camera.look_at(Vector3.ZERO); camera.current=true
	var a=create_emitter(world); var b=create_emitter(world); compare(world,"Registered")
	for frame in 120: a.tick(1.0/60.0); b.tick(1.0/60.0)
	compare(world,"Simulated"); camera.position=Vector3(2000,1,10); camera.look_at(Vector3(2000,0,0)); a.tick(0.1); b.tick(0.1); compare(world,"Culled")
	b.fail("Authored metrics failure"); compare(world,"Failed")
	check(world.particle_metrics.snapshot().reason_counts.get("Authored metrics failure",0)==1,"Failure counter registered once")
	b.retire(); compare(world,"Retired failed emitter")
	# Retired nodes leave the group only on deletion. The old scan sees their
	# cleared state until deletion; test the production ownership boundary.
	b.queue_free(); await process_frame; compare(world,"Deleted failed emitter")
	check(not world.particle_metrics.snapshot().reason_counts.has("Authored metrics failure"),"Removed failures do not remain in diagnostics")
	var previous: Array=world.stats.errors.duplicate()
	world.stats.batches=[{"large":"retained diagnostic history"}]
	var lite: Dictionary=world.snapshot(false); var full: Dictionary=world.snapshot()
	check(not lite.has("batches") and full.batches.size()==1,"HUD snapshots omit historical deep-copy work")
	check(lite.native_particles.active==full.native_particles.active and world.stats.errors==previous,"Light/full diagnostics retain current counters without mutating history")
	world.close(); check(world.particle_metrics.entries.is_empty(),"World close releases counter entries without retaining emitters")
	world.queue_free(); await process_frame; await process_frame
	var file:=FileAccess.open(args.report,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Actual native emitter registration/simulation/culling/failure/retirement and independent legacy scan agreement; lightweight current-world diagnostics; no network or clean benchmark."},"\t")); file.close(); quit(0 if failures.is_empty() else 1)
