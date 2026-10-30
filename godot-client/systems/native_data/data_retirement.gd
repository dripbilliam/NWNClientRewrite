extends Node
# Only detached parser/decoded Variant graphs belong here. Scene nodes, GPU
# resources and live mutable state remain on the presentation thread.
const Timing=preload("res://systems/native_render/frame_profile.gd")
var tasks: Array=[]
var deferred: Array=[]
var results: Array=[]
var mutex:=Mutex.new()
var maximum_pending:=12
var closed:=false
var stats:={"submitted":0,"completed":0,"peak_pending":0,"forced_drains":0,"deferred":0,"peak_deferred":0,"deferred_overflows":0,"worker_ms":0.0,"max_worker_ms":0.0,"threads":[]}
func _enter_tree() -> void: get_parent().set_meta("native_data_retirement",self)
func defer_release(payload: Dictionary) -> void:
	if payload.is_empty(): return
	if closed: payload.clear(); return
	poll()
	# queue_free releases physical owners at frame end. Keep their CPU source
	# references through two complete frame boundaries before dropping the last
	# data-only reference on a worker, rather than racing those scene releases.
	if deferred.size()>=maximum_pending:
		stats.deferred_overflows+=1; retire(payload); return
	deferred.append({"frame":Engine.get_process_frames()+2,"payload":payload})
	stats.deferred+=1; stats.peak_deferred=maxi(int(stats.peak_deferred),deferred.size())
func retire(payload: Dictionary) -> void:
	if payload.is_empty(): return
	if closed: payload.clear(); return
	poll()
	# Bounds retained CPU data during repeated rapid area changes. Normal
	# disposal runs on the low-priority pool, never on a render-resource worker.
	while tasks.size()>=maximum_pending:
		stats.forced_drains+=1; WorkerThreadPool.wait_for_task_completion(int(tasks.pop_front())); poll()
	tasks.append(WorkerThreadPool.add_task(_release.bind(payload),false,"Release native decoded data")); stats.submitted+=1; stats.peak_pending=maxi(stats.peak_pending,tasks.size())
func _release(payload: Dictionary) -> void:
	var began:=Time.get_ticks_usec(); payload.clear()
	var result:={"ms":(Time.get_ticks_usec()-began)/1000.0,"thread":OS.get_thread_caller_id()}
	mutex.lock(); results.append(result); mutex.unlock()
func poll() -> void:
	var ready: Array=[]
	while not deferred.is_empty() and Engine.get_process_frames()>=int(deferred[0].frame): ready.append(deferred.pop_front().payload)
	for payload in ready: retire(payload)
	for task in tasks.duplicate():
		if WorkerThreadPool.is_task_completed(int(task)): WorkerThreadPool.wait_for_task_completion(int(task)); tasks.erase(task)
	mutex.lock(); var finished:=results; results=[]; mutex.unlock()
	for result in finished:
		stats.completed+=1; stats.worker_ms+=float(result.ms); stats.max_worker_ms=maxf(stats.max_worker_ms,float(result.ms))
		if not stats.threads.has(result.thread): stats.threads.append(result.thread)
func _process(_delta: float) -> void:
	var began:=Timing.begin(); poll(); Timing.finish("callback_data_retirement",began)
func snapshot() -> Dictionary:
	var result:=stats.duplicate(true); result.pending=tasks.size()+deferred.size(); result.waiting_frames=deferred.size(); return result
func close() -> void:
	if closed: return
	closed=true
	# Shutdown has no gameplay frame budget. Drain every retained CPU packet;
	# normal live retirement takes the frame-fenced route above.
	for entry in deferred:
		tasks.append(WorkerThreadPool.add_task(_release.bind(entry.payload),false,"Release final native decoded data")); stats.submitted+=1
	deferred.clear()
	for task in tasks: WorkerThreadPool.wait_for_task_completion(int(task))
	tasks.clear()
	poll()
func _exit_tree() -> void:
	close()
	if is_instance_valid(get_parent()) and get_parent().get_meta("native_data_retirement",null)==self: get_parent().remove_meta("native_data_retirement")
