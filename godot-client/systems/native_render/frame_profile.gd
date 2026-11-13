extends Node
signal control(command: Dictionary)
const RenderThreadInfo=preload("res://systems/native_render/render_thread_info.gd")
const SummaryJob=preload("res://systems/native_render/frame_summary_job.gd")
# Callback totals are disjoint owners. Detailed child spans, render CPU/GPU,
# physics and profiler self-time overlap and must not be added to that total.
const CALLBACKS=["callback_root","callback_world","callback_rigs","callback_particles","callback_effects","callback_dummies","callback_projectiles","callback_audio","callback_terrain","callback_area_border","callback_objects","callback_creatures","callback_references","callback_reference_poses","callback_wind","callback_lights","callback_light_history","callback_focus_lighting","callback_native_lighting","callback_walkmesh","callback_drive_geometry","callback_retirement","callback_data_retirement","callback_assets","callback_catalog","callback_ui","callback_overhead_text","callback_overhead_layout","callback_script_floating","callback_inventory","callback_icons","callback_fonts","callback_keyboard","callback_selection","callback_mouse_cursor","callback_camera","callback_environment","callback_material_prewarm"]
static var enabled:=false
static var phase_frame:=-1
static var phases: Dictionary={}
static var record_usec:=0
static var collected_frame:=-1
static var postdraw_phases: Dictionary={}
static var postdraw_record_usec:=0
var viewport: Viewport
var rows: Array=[]
var maximum_rows:=240
var previous:=0
var last_summary: Dictionary={}
var summary_at:=0
var frame_started:=0
var started_frame:=-1
var control_file:=""
var control_at:=0
var control_serial:=-1
var mode:="baseline"
var pipeline_monitors: Dictionary={}
var previous_pipeline_counts: Dictionary={}
var render_thread_info:=RenderThreadInfo.new()
var render_started:=0
var render_boundary_count:=0
var worker_statistics:=not OS.get_cmdline_user_args().has("--profile-summary=main")
var summary_generation:=0
var summary_task: int=-1
var summary_job
var summary_capture_ms:=0
var summary_stats:={"submitted":0,"completed":0,"stale":0,"pending":0,"peak_pending":0,"worker_ms":0.0,"max_worker_ms":0.0,"last_thread":0,"closed":false}
static func begin() -> int: return Time.get_ticks_usec() if enabled else 0
static func ensure_frame() -> void:
	var frame:=Engine.get_process_frames()
	if phase_frame!=frame: phase_frame=frame; phases={}; record_usec=0
static func finish(name: String,began: int) -> void:
	if not enabled or began<=0: return
	record(name,(Time.get_ticks_usec()-began)/1000.0)
static func record(name: String,milliseconds: float) -> void:
	if not enabled: return
	var began:=Time.get_ticks_usec(); ensure_frame()
	# frame_post_draw continuations run after this owner's collector. Preserve
	# their spans for the next wall interval instead of clearing them unseen.
	if collected_frame==Engine.get_process_frames():
		postdraw_phases[name]=float(postdraw_phases.get(name,0.0))+milliseconds
		postdraw_record_usec+=Time.get_ticks_usec()-began
	else:
		phases[name]=float(phases.get(name,0.0))+milliseconds
		record_usec+=Time.get_ticks_usec()-began
static func count(name: String,value: int) -> void:
	if not enabled: return
	ensure_frame()
	if collected_frame==Engine.get_process_frames(): postdraw_phases[name]=int(postdraw_phases.get(name,0))+value
	else: phases[name]=int(phases.get(name,0))+value
static func record_batch(batch: Dictionary) -> void:
	if not enabled or batch.is_empty(): return
	var began:=Time.get_ticks_usec(); ensure_frame()
	var after_collection:=collected_frame==Engine.get_process_frames()
	var target: Dictionary=postdraw_phases if after_collection else phases
	for name in batch: target[str(name)]=float(target.get(str(name),0.0))+float(batch[name])
	if after_collection: postdraw_record_usec+=Time.get_ticks_usec()-began
	else: record_usec+=Time.get_ticks_usec()-began
func configure(value: Viewport) -> void:
	viewport=value; process_priority=1000000
	render_thread_info.request()
	var available:=ClassDB.class_get_integer_constant_list("Performance")
	for monitor in available:
		if str(monitor).begins_with("PIPELINE_COMPILATIONS_") or str(monitor).begins_with("RENDER_PIPELINE_COMPILATIONS_"): pipeline_monitors[str(monitor).to_lower()]=ClassDB.class_get_integer_constant("Performance",monitor)
	if not get_tree().process_frame.is_connected(start_frame): get_tree().process_frame.connect(start_frame)
	if not RenderingServer.frame_pre_draw.is_connected(start_render): RenderingServer.frame_pre_draw.connect(start_render)
	if not RenderingServer.frame_post_draw.is_connected(finish_render): RenderingServer.frame_post_draw.connect(finish_render)
	set_enabled(true)
func set_enabled(value: bool) -> void:
	summary_generation+=1
	enabled=value; rows.clear(); last_summary={}; previous=0; frame_started=0; started_frame=-1; summary_at=0; phases={}; phase_frame=-1; record_usec=0
	collected_frame=-1; postdraw_phases={}; postdraw_record_usec=0
	previous_pipeline_counts={}
	render_started=0
	render_boundary_count=0
	if is_instance_valid(viewport): RenderingServer.viewport_set_measure_render_time(viewport.get_viewport_rid(),value)
func start_render() -> void:
	if enabled: render_started=Time.get_ticks_usec()
func finish_render() -> void:
	if not enabled or render_started<=0: return
	var elapsed:=(Time.get_ticks_usec()-render_started)/1000.0
	render_started=0
	render_boundary_count+=1
	# Engine pre/post draw boundaries include render setup and waits. This is
	# wall time, not another additive CPU owner or a forced GPU synchronization.
	record("render_frame_wall_ms",elapsed)
	record("render_boundary_setup_cpu_ms",RenderingServer.get_frame_setup_time_cpu())
	count("count_render_boundaries",1)
func start_frame() -> void:
	if enabled and started_frame!=Engine.get_process_frames():
		ensure_frame(); started_frame=Engine.get_process_frames(); frame_started=Time.get_ticks_usec()
func collect(now: int) -> Dictionary:
	var row: Dictionary=phases.duplicate() if phase_frame==Engine.get_process_frames() else {}
	for name in postdraw_phases: row["postdraw_"+str(name)]=postdraw_phases[name]
	row.postdraw_profiler_record_ms=postdraw_record_usec/1000.0
	postdraw_phases={}; postdraw_record_usec=0; collected_frame=Engine.get_process_frames()
	row.wall_ms=(now-previous)/1000.0 if previous>0 else 0.0; previous=now
	row.callback_envelope_ms=(now-frame_started)/1000.0 if frame_started>0 else 0.0
	var accounted:=0.0
	for name in CALLBACKS: accounted+=float(row.get(name,0.0))
	row.accounted_callback_ms=accounted
	row.unattributed_callback_ms=maxf(0.0,float(row.callback_envelope_ms)-accounted)
	row.callback_overlap_ms=maxf(0.0,accounted-float(row.callback_envelope_ms))
	row.outside_callback_ms=maxf(0.0,float(row.wall_ms)-float(row.callback_envelope_ms))
	row.profiler_record_ms=record_usec/1000.0
	row.process_ms=Performance.get_monitor(Performance.TIME_PROCESS)*1000.0
	row.physics_ms=Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.0
	row.render_cpu_ms=RenderingServer.viewport_get_measured_render_time_cpu(viewport.get_viewport_rid())
	row.render_gpu_ms=RenderingServer.viewport_get_measured_render_time_gpu(viewport.get_viewport_rid())
	row.render_setup_cpu_ms=RenderingServer.get_frame_setup_time_cpu()
	row.draws=Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	row.triangles=Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	row.nodes=Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	row.objects=Performance.get_monitor(Performance.OBJECT_COUNT)
	row.resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
	row.orphan_nodes=Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	row.memory_static_bytes=Performance.get_monitor(Performance.MEMORY_STATIC)
	row.video_memory_bytes=Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)
	row.texture_memory_bytes=Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)
	row.buffer_memory_bytes=Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED)
	for monitor in pipeline_monitors:
		var value:=Performance.get_monitor(int(pipeline_monitors[monitor])); row[monitor]=value
		row[monitor+"_delta"]=maxf(0.0,value-float(previous_pipeline_counts.get(monitor,value)))
		previous_pipeline_counts[monitor]=value
	return row
func _process(_delta: float) -> void:
	poll_summary()
	if not is_instance_valid(viewport): return
	var began:=begin()
	if not control_file.is_empty() and Time.get_ticks_msec()-control_at>=200:
		control_at=Time.get_ticks_msec()
		if FileAccess.file_exists(control_file):
			var command: Variant=JSON.parse_string(FileAccess.get_file_as_string(control_file))
			if command is Dictionary and int(command.get("serial",-1))>control_serial:
				control_serial=int(command.serial); mode=str(command.get("mode","baseline")); summary_generation+=1; rows.clear(); last_summary={}; summary_at=0; control.emit(command)
	if not enabled: return
	var now:=Time.get_ticks_usec(); var row:=collect(now)
	row.profiler_collect_ms=(Time.get_ticks_usec()-began)/1000.0
	rows.append(row)
	if rows.size()>maximum_rows: rows.pop_front()
func snapshot() -> Dictionary:
	poll_summary()
	if not enabled: return {"enabled":false}
	if worker_statistics:
		if summary_task<0 and (Time.get_ticks_msec()-summary_at>=500 or last_summary.is_empty()):
			var began:=begin(); summary_at=Time.get_ticks_msec(); summary_capture_ms=summary_at
			summary_job=SummaryJob.new()
			# Completed rows contain only numbers and are immutable after append.
			# The Array itself is a private copy, with one job maximum per owner.
			summary_task=WorkerThreadPool.add_task(summary_job.run.bind(rows.duplicate(),summary_generation),false,"Frame statistics")
			summary_stats.submitted+=1; summary_stats.pending=1; summary_stats.peak_pending=1; summary_stats.closed=false
			finish("profiler_summary_ms",began)
		if last_summary.is_empty(): return {"enabled":true,"frames":0,"metrics":{},"worst_frame":{},"pending":true,"summary_policy":"worker","mode":mode,"control_serial":control_serial}
		return last_summary
	if Time.get_ticks_msec()-summary_at<500 and not last_summary.is_empty(): return last_summary
	var began:=begin(); summary_at=Time.get_ticks_msec()
	var computed: Dictionary=SummaryJob.calculate(rows)
	last_summary=describe_summary(computed,"main",summary_at)
	finish("profiler_summary_ms",began)
	return last_summary
func describe_summary(computed: Dictionary,policy: String,captured_at: int) -> Dictionary:
	return {"enabled":true,"frames":computed.frames,"mode":mode,"control_serial":control_serial,"metrics":computed.metrics,"worst_frame":computed.worst_frame,"pending":false,"summary_policy":policy,"captured_at_ms":captured_at,"callback_owners":CALLBACKS,"pipeline_monitors":pipeline_monitors.keys(),"render_thread":render_thread_info.snapshot(),"scope":"Callback accounting covers instrumented main-thread owners, not complete engine internals. Child spans/self-time overlap. postdraw_ spans were recorded after the prior collection, belong to the next wall interval and may include asynchronous wall waits; never add them to callback CPU totals. Outside-callback time includes engine, rendering, physics, waits and scheduling; not an attribution to one of them. Pipeline counters are cumulative plus nonnegative per-frame deltas (first sample baseline zero); render counters are asynchronous. Worker summaries describe a completed captured window, not the current frame. Profiling has overhead; not clean FPS acceptance."}
func poll_summary() -> void:
	if summary_task<0 or not WorkerThreadPool.is_task_completed(summary_task): return
	WorkerThreadPool.wait_for_task_completion(summary_task)
	consume_summary()
func consume_summary() -> void:
	var began:=begin()
	var computed: Dictionary=summary_job.result; summary_job=null; summary_task=-1
	summary_stats.completed+=1; summary_stats.pending=0
	summary_stats.worker_ms+=float(computed.worker_ms); summary_stats.max_worker_ms=maxf(float(summary_stats.max_worker_ms),float(computed.worker_ms)); summary_stats.last_thread=int(computed.thread)
	if int(computed.generation)==summary_generation and enabled: last_summary=describe_summary(computed,"worker",summary_capture_ms)
	else: summary_stats.stale+=1
	finish("profiler_summary_poll_ms",began)
func close_summary() -> void:
	if summary_task>=0:
		WorkerThreadPool.wait_for_task_completion(summary_task)
		summary_generation+=1; consume_summary()
	summary_stats.closed=true
func _notification(what: int) -> void:
	if what==NOTIFICATION_PREDELETE: close_summary()
func _exit_tree() -> void:
	close_summary()
	if RenderingServer.frame_pre_draw.is_connected(start_render): RenderingServer.frame_pre_draw.disconnect(start_render)
	if RenderingServer.frame_post_draw.is_connected(finish_render): RenderingServer.frame_post_draw.disconnect(finish_render)
	render_started=0
	if is_instance_valid(viewport): RenderingServer.viewport_set_measure_render_time(viewport.get_viewport_rid(),false)
	enabled=false; phases={}; phase_frame=-1
	collected_frame=-1; postdraw_phases={}; postdraw_record_usec=0
