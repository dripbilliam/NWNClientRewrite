extends SceneTree
# Deterministic wire proof, not a CPU-load or FPS benchmark. One tiny32-item
# weighted packet per4 frames; only one outstanding pool task, no sleeps/spins.
class PacketJob extends RefCounted:
	var seed: int
	var result: int=0
	var caller_id: int=0
	func smoke_worker_task()->void:
		caller_id=OS.get_thread_caller_id()
		var total: int=0
		for index in 32:total+=(seed+index)*(index+1)
		result=total

const MAXIMUM_ACTIVE_MS:=20000
const TASK_PERIOD_FRAMES:=4
var ready_path:=""
var stop_path:=""
var report_path:=""
var nonce:=""
var ready_at_ms:=0
var main_thread_id:=0
var main_frames:=0
var main_checksum:=0
var submitted:=0
var completed:=0
var worker_thread_ids: Dictionary={}
var task_id: int=-1
var task_job: PacketJob
var stop_requested:=false
var stop_reason:=""
var stop_at_ms:=0
var failures: Array[String]=[]
var report_written:=false
var native: RefCounted
var native_frames:=0
var native_summary: Dictionary={}
var connected_seen:=false
var bridge_samples:=0
var final_bridge: Dictionary={}

func bridge_snapshot()->Dictionary:
	var info: Dictionary=native.call("dispatch",65000,{})
	bridge_samples+=1
	if info.has("error") or info.get("abi")!=1 or info.get("bytes")!=72 or info.get("bound")!=true:
		failures.append("Private engine/native bridge ABI/binding failed")
	else:
		connected_seen=connected_seen or info.get("connected",false)
		if int(info.get("overflow",-1))!=0 or int(info.get("invalid_token",-1))!=0 or int(info.get("live_scopes",-1))!=0:failures.append("Private bridge token/scope failure at cold boundary")
	return info

func smoke_native_frame()->void:
	var planes:=PackedFloat32Array();planes.resize(24)
	native_summary=native.call("dispatch",1,{"delta":0.016,"profile":false,"view":{"stamp":main_frames,"position":[0,0,0],"camera":[1,0,0,0],"planes":planes.to_byte_array()}})
	native_frames+=1
	if native_summary.has("error") or native_summary.has("phases") or int(native_summary.get("registered",-1))!=0 or int(native_summary.get("prepared",-1))!=0 or int(native_summary.get("vertices",-1))!=0:failures.append("Empty native profile-off frame contract differs")

func write_atomic(file_path: String,value: Dictionary)->bool:
	if FileAccess.file_exists(file_path) or FileAccess.file_exists(file_path+".tmp"):return false
	var file:=FileAccess.open(file_path+".tmp",FileAccess.WRITE)
	if file==null:return false
	file.store_string(JSON.stringify(value));file.close()
	return DirAccess.rename_absolute(file_path+".tmp",file_path)==OK

func _initialize()->void:
	Engine.max_fps=60
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--smoke-ready="):ready_path=arg.trim_prefix("--smoke-ready=")
		elif arg.begins_with("--smoke-stop="):stop_path=arg.trim_prefix("--smoke-stop=")
		elif arg.begins_with("--smoke-report="):report_path=arg.trim_prefix("--smoke-report=")
		elif arg.begins_with("--smoke-nonce="):nonce=arg.trim_prefix("--smoke-nonce=")
	if ready_path.is_empty() or stop_path.is_empty() or report_path.is_empty() or nonce.length()<16:
		push_error("Private Tracy smoke requires fresh marker paths and nonce");quit(2);return
	if FileAccess.file_exists(stop_path) or FileAccess.file_exists(report_path):
		push_error("Private Tracy smoke refuses old marker/report");quit(2);return
	main_thread_id=OS.get_thread_caller_id()
	if not ClassDB.class_exists("NwnParticlePresentation") or not ClassDB.can_instantiate("NwnParticlePresentation"):
		push_error("Private particle presentation plugin missing");quit(2);return
	native=ClassDB.instantiate("NwnParticlePresentation")
	var initial_bridge:=bridge_snapshot()
	if not failures.is_empty():push_error("Private engine/particle bridge unavailable");native=null;quit(2);return
	var executable:=OS.get_executable_path()
	var engine_sha:=FileAccess.get_sha256(executable)
	ready_at_ms=Time.get_ticks_msec()
	var ready:={"version":1,"kind":"private-tracy-smoke-ready","pid":OS.get_process_id(),"nonce":nonce,"executable":executable,"engine_sha256":engine_sha,"main_thread":main_thread_id==OS.get_main_thread_id(),"main_thread_id":main_thread_id,"display":DisplayServer.get_name(),"maximum_fps":Engine.max_fps,"ready_at_ms":ready_at_ms,"maximum_active_ms":MAXIMUM_ACTIVE_MS,"worker_period_frames":TASK_PERIOD_FRAMES,"nwn_frame_probe_available":ClassDB.class_exists(&"NwnFrameProbe"),"initial_bridge":initial_bridge,"loaded_extensions":Array(GDExtensionManager.get_loaded_extensions())}
	if not ready.main_thread or not write_atomic(ready_path,ready):
		push_error("Private Tracy smoke failed atomic ready publication");quit(2)

func smoke_main_tick()->void:
	# A deterministic scalar update proves repeated script-function scopes on main.
	main_checksum=(main_checksum+main_frames*17+3)%1000000007

func collect_completed_job()->void:
	if task_id<0 or not WorkerThreadPool.is_task_completed(task_id):return
	# Join only AFTER completion; this gives a synchronization boundary before
	# main reads fields written solely by the worker. No shared unsynchronized reads.
	WorkerThreadPool.wait_for_task_completion(task_id)
	if task_job.result!=task_job.seed*528+10912:failures.append("Worker weighted packet result differs")
	if task_job.caller_id==0 or task_job.caller_id==main_thread_id:failures.append("Task did not execute on a separate Godot thread")
	worker_thread_ids[str(task_job.caller_id)]=true
	completed+=1;task_id=-1;task_job=null

func request_stop(reason: String)->void:
	if stop_requested:return
	stop_requested=true;stop_reason=reason;stop_at_ms=Time.get_ticks_msec()
	if reason!="owned-stop-marker":failures.append(reason)

func finish_smoke()->void:
	if report_written:return
	report_written=true
	if submitted!=completed or task_id>=0:failures.append("Worker tasks did not retire")
	if main_frames<120 or completed<20:failures.append("Insufficient repeated main/worker activity for smoke")
	if native!=null:
		native.call("dispatch",5,{})
		final_bridge=bridge_snapshot()
		native=null
	if not connected_seen or int(final_bridge.get("begun",0))<=0 or final_bridge.get("begun")!=final_bridge.get("ended"):failures.append("Connected native scopes not proved balanced")
	var report:={"version":1,"kind":"private-tracy-smoke-result","success":failures.is_empty(),"pid":OS.get_process_id(),"nonce":nonce,"display":DisplayServer.get_name(),"maximum_fps":Engine.max_fps,"main_frames":main_frames,"main_checksum":main_checksum,"main_thread_id":main_thread_id,"worker_thread_ids":worker_thread_ids.keys(),"submitted":submitted,"completed":completed,"active_ms":Time.get_ticks_msec()-ready_at_ms,"stop_reason":stop_reason,"remaining_task":task_id,"native_frames":native_frames,"native_empty_summary":native_summary,"connected_seen":connected_seen,"bridge_samples":bridge_samples,"final_bridge":final_bridge,"failures":failures,"scope":"Deterministic CPU main/worker +empty native-particle bridge/activity and natural-stop proof only. Godot logical thread IDs differ from Tracy OS thread IDs. No assets/server/live particle population/GPU/FPS claim."}
	if not write_atomic(report_path,report):push_error("Private smoke failed atomic report publication");quit(2);return
	quit(0 if report.success else 2)

func _process(_delta: float)->bool:
	if ready_at_ms<=0 or report_written:return false
	main_frames+=1
	smoke_main_tick()
	smoke_native_frame()
	collect_completed_job()
	if main_frames%60==0:bridge_snapshot()
	if not stop_requested and FileAccess.file_exists(stop_path):
		var marker: Variant=JSON.parse_string(FileAccess.get_file_as_string(stop_path))
		if marker is Dictionary and marker.get("pid")==OS.get_process_id() and marker.get("nonce")==nonce:request_stop("owned-stop-marker")
		else:request_stop("Invalid stop marker")
	if not stop_requested and Time.get_ticks_msec()-ready_at_ms>=MAXIMUM_ACTIVE_MS:request_stop("Smoke20second marker deadline exceeded")
	if not stop_requested and not failures.is_empty():request_stop("Smoke activity failed")
	if stop_requested:
		if task_id<0:finish_smoke()
		elif Time.get_ticks_msec()-stop_at_ms>1000:failures.append("Completed-task retirement deadline exceeded");finish_smoke()
		return false
	if task_id<0 and main_frames%TASK_PERIOD_FRAMES==0:
		task_job=PacketJob.new();task_job.seed=main_frames
		task_id=WorkerThreadPool.add_task(task_job.smoke_worker_task,false,"Tracy deterministic packet smoke")
		submitted+=1
	return false
