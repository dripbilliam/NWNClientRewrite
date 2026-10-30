extends Node
const Timing=preload("res://systems/native_render/frame_profile.gd")
# Main-thread retirement owner. Worlds keep their existing parent: reparenting
# would invoke their _exit_tree close while data workers are still running.
var worlds: Array=[]
var maximum_retained:=2
var closed:=false
var stats:={"retired":0,"released":0,"forced_drains":0,"peak_worlds":0,"peak_workers":0,"begin_ms":0.0,"max_begin_ms":0.0,"max_hide_ms":0.0,"max_disable_processing_ms":0.0}
func retire(world) -> void:
	if not is_instance_valid(world) or worlds.has(world): return
	if closed: world.close(); world.queue_free(); return
	# A bounded overflow is drained safely rather than retaining unlimited areas.
	while worlds.size()>=maxi(1,maximum_retained):
		stats.forced_drains+=1; release_world(worlds[0])
	var began:=Time.get_ticks_usec()
	world.begin_retirement(); worlds.append(world); stats.retired+=1
	var disable_timings: Variant=world.get("retirement_disable_timings")
	if disable_timings is Dictionary:
		stats.max_hide_ms=maxf(float(stats.max_hide_ms),float(disable_timings.get("hide_ms",0)))
		stats.max_disable_processing_ms=maxf(float(stats.max_disable_processing_ms),float(disable_timings.get("processing_ms",0)))
	stats.peak_worlds=maxi(int(stats.peak_worlds),worlds.size())
	stats.peak_workers=maxi(int(stats.peak_workers),pending_workers())
	var elapsed:=(Time.get_ticks_usec()-began)/1000.0
	stats.begin_ms+=elapsed; stats.max_begin_ms=maxf(float(stats.max_begin_ms),elapsed)
	poll()
func pending_workers() -> int:
	var count:=0
	for world in worlds:
		if not is_instance_valid(world): continue
		for task in world.worker_tasks():
			if not WorkerThreadPool.is_task_completed(int(task)): count+=1
	return count
func release_world(world) -> void:
	worlds.erase(world)
	if is_instance_valid(world):
		var began:=Timing.begin(); world.close(); Timing.finish("retirement_final_close",began)
		world.queue_free()
	stats.released+=1
func poll() -> void:
	for world in worlds.duplicate():
		if not is_instance_valid(world): worlds.erase(world); continue
		if world.worker_tasks().all(func(task):return WorkerThreadPool.is_task_completed(int(task))):
			var began:=Timing.begin()
			var ready: bool=not world.has_method("retirement_step") or world.retirement_step(2.0)
			Timing.finish("retirement_incremental_step",began)
			if not ready: continue
			release_world(world)
func _process(_delta: float) -> void:
	var began:=Timing.begin()
	_profile_process(_delta)
	Timing.finish("callback_retirement",began)
func _profile_process(_delta: float) -> void:
	if not closed: poll()
func snapshot() -> Dictionary:
	var value:=stats.duplicate(true); value.pending_worlds=worlds.size(); value.pending_workers=pending_workers(); return value
func close() -> void:
	if closed: return
	closed=true
	for world in worlds.duplicate(): release_world(world)
func _exit_tree() -> void: close()
