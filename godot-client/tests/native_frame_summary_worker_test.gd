extends SceneTree
const Job=preload("res://systems/native_render/frame_summary_job.gd")
const Profile=preload("res://systems/native_render/frame_profile.gd")
const Cache=preload("res://systems/native_data/prepared_cache.gd")
var checks:=0
var failures: Array=[]
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label); print("FAIL: ",label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var report:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): report=arg.substr(9)
	if report.is_empty() or FileAccess.file_exists(report): quit(2); return
	var baseline_orphans:=int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	var archive:="res://backups/native-goal2-engine-frame-timing-v1.zip"; var zip:=ZIPReader.new()
	check(FileAccess.get_sha256(archive)=="f8f4201aa1549d0ff427618543348abbf65c6caa8879d9ee6adc2dd0a58c204a","Pre-worker authored checkpoint identity is pinned")
	check(zip.open(archive)==OK,"Pre-worker summary oracle opens")
	var code:=zip.read_file("systems/native_render/frame_profile.gd"); zip.close()
	check(Cache.digest(code)=="0a87c3e72d51bb2b36805e2e834df067a2f50ea1eb857b27977522fc3606b1ce","Exact unchanged original summary implementation is pinned")
	var oracle_script:=GDScript.new(); oracle_script.source_code=code.get_string_from_utf8(); check(oracle_script.reload()==OK,"Unchanged summary oracle compiles")
	var oracle=oracle_script.new(); oracle.set_enabled(true)
	var datasets: Array=[[],[{"wall_ms":1.0,"value":0.0}],[{"wall_ms":1.0,"value":-4.0},{"wall_ms":2.0},{"wall_ms":2.0,"value":2.0}]]
	datasets.append([{"wall_ms":0.1,"decimal":0.1,"cancellation":1.0e16},{"wall_ms":0.01,"decimal":0.2,"cancellation":1.0},{"wall_ms":0.1,"decimal":-0.3,"cancellation":-1.0e16},{"wall_ms":0.001,"decimal":0.0000001}])
	for count in [2,19,20,21,239,240]:
		var frames: Array=[]
		for index in count:
			var row:={"wall_ms":float(index%7),"count":index,"zero":0.0,"negative":float(-index)}
			if index%3==0: row.sparse=float(index)*0.125
			if index==count-1: row.last_only=99.25
			frames.append(row)
		datasets.append(frames)
	var large: Array=[]
	for index in 240:
		var row:={"wall_ms":float(index%13)+0.125}
		for field in 160:
			if (index+field)%5!=0: row["phase_"+str(field)]=float((index*31+field*17)%997)/1000.0
		large.append(row)
	datasets.append(large)
	for index in datasets.size():
		var rows: Array=datasets[index]; var digest:=Cache.digest(var_to_bytes(rows))
		oracle.rows=rows; oracle.last_summary={}; oracle.summary_at=0
		var expected: Dictionary=oracle.snapshot(); var computed:=Job.calculate(rows)
		check(Cache.digest(var_to_bytes(computed.metrics))==Cache.digest(var_to_bytes(expected.metrics)),"Exact original numeric summaries: "+str(index))
		check(Cache.digest(var_to_bytes(computed.worst_frame))==Cache.digest(var_to_bytes(expected.worst_frame)),"Exact original tie/empty worst frame: "+str(index))
		check(computed.frames==rows.size() and Cache.digest(var_to_bytes(rows))==digest,"Original window size and immutable caller input: "+str(index))
	var original_sha:=Cache.digest(var_to_bytes(large)); var packet:=large.duplicate(); var job:=Job.new()
	var task:=WorkerThreadPool.add_task(job.run.bind(packet,7),false,"Test numeric summary")
	var deadline:=Time.get_ticks_msec()+10000
	while not WorkerThreadPool.is_task_completed(task) and Time.get_ticks_msec()<deadline: await process_frame
	check(WorkerThreadPool.is_task_completed(task),"Real bounded worker summary completes")
	WorkerThreadPool.wait_for_task_completion(task)
	check(job.result.generation==7 and int(job.result.thread)!=OS.get_main_thread_id(),"Worker runs on another thread and preserves generation")
	check(packet.is_empty() and Cache.digest(var_to_bytes(large))==original_sha,"Worker releases only its copied input window")
	oracle.rows=large; oracle.last_summary={}; oracle.summary_at=0
	check(Cache.digest(var_to_bytes(job.result.metrics))==Cache.digest(var_to_bytes(oracle.snapshot().metrics)),"Real worker output remains exactly equal to the previous algorithm")
	var worker_ms: float=job.result.worker_ms; job=null
	var profile:=Profile.new(); root.add_child(profile); profile.configure(root); profile.set_process(false); profile.worker_statistics=true; profile.rows=large.duplicate(true)
	var began:=Time.get_ticks_usec(); var initial: Dictionary=profile.snapshot(); var enqueue_ms:=(Time.get_ticks_usec()-began)/1000.0
	check(initial.get("pending",false) and profile.summary_task>=0,"First asynchronous snapshot exposes pending state without waiting for statistics")
	profile.set_enabled(false)
	check(profile.snapshot()=={"enabled":false},"Disabling does not expose an in-flight old summary")
	profile.set_enabled(true); profile.rows=[{"wall_ms":2.0,"new_epoch":123.0},{"wall_ms":3.0},{"wall_ms":1.0}]
	var adopted: Dictionary={}; deadline=Time.get_ticks_msec()+10000
	while Time.get_ticks_msec()<deadline:
		adopted=profile.snapshot()
		if not adopted.get("pending",false) and int(adopted.get("frames",0))==3: break
		await process_frame
	check(adopted.get("frames",0)==3 and adopted.metrics.has("new_epoch") and not adopted.metrics.has("phase_0"),"Reenabled owner adopts only its current-generation window")
	check(profile.summary_stats.stale>=1 and profile.summary_stats.completed>=2,"Completed old generation is rejected and all task handles joined")
	check(profile.summary_stats.peak_pending==1 and profile.summary_stats.pending==0 and adopted.summary_policy=="worker","At most one worker packet is live per profiler")
	check(int(profile.summary_stats.last_thread)!=OS.get_main_thread_id(),"Runtime summary completion is off the frame thread")
	profile.rows=large.duplicate(true); profile.last_summary={}; profile.summary_at=0; profile.snapshot()
	var lifetime: Dictionary=profile.summary_stats
	check(profile.summary_task>=0,"Shutdown coverage begins with an owned task")
	profile.free(); await process_frame
	check(lifetime.closed and lifetime.pending==0 and lifetime.completed==lifetime.submitted,"Profiler destruction drains its owned summary before releasing the packet")
	check(Cache.digest(var_to_bytes(large))==original_sha,"Invalidation and shutdown preserve original numeric input")
	var standalone:=Profile.new(); standalone.worker_statistics=true; standalone.set_enabled(true); standalone.rows=large.duplicate(true); standalone.snapshot()
	var detached_lifetime: Dictionary=standalone.summary_stats
	standalone.free()
	check(detached_lifetime.closed and detached_lifetime.pending==0 and detached_lifetime.completed==detached_lifetime.submitted,"Profiler freed outside the SceneTree also joins its owned job")
	oracle.free(); await process_frame
	check(int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))==baseline_orphans,"All numeric owners and profiler nodes release without orphans")
	var out:=FileAccess.open(report,FileAccess.WRITE)
	out.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"diagnostic":{"enqueue_ms":enqueue_ms,"worker_ms":worker_ms,"lifetime":lifetime},"public_connections":0,"scope":"Pinned unchanged numeric oracle, real data-only worker output, bounded enqueue, disabled/reenabled generation rejection and in-flight shutdown. Synthetic diagnostics, not game FPS acceptance."},"\t")); out.close(); quit(0 if failures.is_empty() else 1)
