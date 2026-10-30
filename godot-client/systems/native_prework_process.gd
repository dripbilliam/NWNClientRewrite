extends "res://systems/native_asset_prework.gd"
# Model/texture preparation lives in a separate headless engine. The client
# receives JSON counters only, never worker-owned model graphs or native handles.
var child_pid:=-1
var job_directory:=""
var request: Dictionary={}
var captures: Array=[]
var control_serial:=0
var stop_requested:=false
var pending_clear:=false
var local_clear:=false
var polling_at:=0
var remote_active:=false
var heartbeat_at:=0
static func write_json(path: String,value: Dictionary) -> bool:
	var temporary:=path+".next"; var file:=FileAccess.open(temporary,FileAccess.WRITE)
	if file==null: return false
	file.store_string(JSON.stringify(value)); file.flush(); file.close()
	if FileAccess.file_exists(path) and DirAccess.remove_absolute(path)!=OK: return false
	return DirAccess.rename_absolute(temporary,path)==OK
static func read_json(path: String) -> Dictionary:
	var file:=FileAccess.open(path,FileAccess.READ)
	if file==null or file.get_length()>1024*1024: return {}
	var text:=file.get_as_text(); file.close(); var value: Variant=JSON.parse_string(text)
	return value if value is Dictionary else {}
func set_workers(value: int) -> void:
	worker_setting=value if value in [0,1,2,4,8] else 0
	worker_count=automatic_workers() if worker_setting==0 else worker_setting
	state.workers=worker_count; send_control(); publish(true)
func start_sources(sources: Dictionary,cache_path: String,all_models: bool=true) -> bool:
	if state.active or remote_active or local_clear: return false
	if not store.configure(cache_path): state.message=store.failure; publish(true); return false
	job_directory=OS.get_temp_dir().path_join("nwn-prework-job-"+str(OS.get_process_id())+"-"+str(Time.get_ticks_usec()))
	if DirAccess.make_dir_recursive_absolute(job_directory)!=OK: state.message="Cannot create preparation job directory."; publish(true); return false
	prepared_directory=cache_path; control_serial=0; stop_requested=false; pending_clear=false; remote_active=true; child_pid=-1; captures=[]
	var variants_file:=job_directory.path_join("variants.bin"); var variants_output:=FileAccess.open(variants_file,FileAccess.WRITE)
	if variants_output==null: remote_active=false; state.message="Cannot save the preparation request."; publish(true); return false
	variants_output.store_buffer(var_to_bytes(extra_variants)); variants_output.close()
	request={"version":1,"parent":OS.get_process_id(),"sources":sources.duplicate(true),"cache":cache_path,"all_models":all_models,"workers":worker_setting,"variants_file":variants_file,"icons":[],"model_limit":model_limit}
	for owner in get_tree().get_nodes_in_group("native_prework_icons"):
		if not owner.closed and owner.cache_directory==cache_path:
			for key in owner.prework_records: captures.append({"owner":weakref(owner),"key":key})
	state={"active":true,"completed":0,"total":0,"saved":0,"reused":0,"failed":0,"running":0,"workers":worker_count,"phase":"starting","message":"Starting background preparation…","worker_log":job_directory.path_join("engine.log")}
	publish(true); return true
func send_control() -> void:
	if not remote_active or job_directory.is_empty(): return
	control_serial+=1
	write_json(job_directory.path_join("control.json"),{"serial":control_serial,"workers":worker_setting,"cancel":stop_requested})
func cancel() -> void:
	if local_clear: super.cancel(); return
	if not remote_active: return
	stop_requested=true; state.message="Stopping background preparation…"; send_control(); publish(true)
func clear_saved(cache_path: String) -> bool:
	if remote_active:
		pending_clear=true; clearing=true; cancel(); state.message="Clearing saved prework after workers finish…"; publish(true); return true
	local_clear=super.clear_saved(cache_path); return local_clear
func _process(delta: float) -> void:
	if local_clear:
		super._process(delta)
		if not state.active: local_clear=false
		return
	if not remote_active: return
	if child_pid<0:
		if stop_requested: finish_remote(false,true); return
		if not captures.is_empty():
			var row: Dictionary=captures.pop_front(); var owner=row.owner.get_ref()
			var packet: Dictionary=owner.prework_packet(str(row.key)) if is_instance_valid(owner) and not owner.closed else {}
			if not packet.is_empty():
				var path:=job_directory.path_join("icon-"+str(request.icons.size())+".bin"); var file:=FileAccess.open(path,FileAccess.WRITE)
				if file!=null: file.store_buffer(var_to_bytes(packet)); file.close(); request.icons.append(path)
			return
		if not write_json(job_directory.path_join("request.json"),request): finish_remote(true,false); return
		var args:=PackedStringArray(["--headless","--path",ProjectSettings.globalize_path("res://"),"--log-file",job_directory.path_join("engine.log"),"--script","res://tools/native_prework_worker.gd","--","--job="+job_directory])
		child_pid=OS.create_process(OS.get_executable_path(),args,false)
		if child_pid<0: finish_remote(true,false); return
		request.clear(); send_control(); state.worker_pid=child_pid; publish(true); return
	if Time.get_ticks_msec()-polling_at<100: return
	polling_at=Time.get_ticks_msec()
	if polling_at-heartbeat_at>=1000: heartbeat_at=polling_at; send_control()
	var status:=read_json(job_directory.path_join("status.json"))
	if status.get("state") is Dictionary:
		state=status.state; state.active=true; state.worker_pid=child_pid; state.worker_log=job_directory.path_join("engine.log")
		if pending_clear: state.message="Clearing saved prework after workers finish…"
		elif stop_requested: state.message="Stopping background preparation…"
		publish(true)
	if not OS.is_process_running(child_pid):
		finish_remote(not bool(status.get("done",false)),bool(status.get("cancelled",stop_requested)))
func finish_remote(failed: bool,cancelled: bool) -> void:
	remote_active=false; child_pid=-1; state.active=false; state.running=0; captures=[]; request={}
	state.worker_failed=failed
	cleanup_packets()
	if pending_clear:
		pending_clear=false; clearing=false; local_clear=super.clear_saved(prepared_directory); return
	if failed: state.message="The preparation worker stopped unexpectedly. The client is still running; completed work is saved."
	elif cancelled: state.message="Preparation cancelled; completed work remains saved."
	publish(true)
func cleanup_packets() -> void:
	if not job_directory.is_absolute_path() or not job_directory.get_file().begins_with("nwn-prework-job-"+str(OS.get_process_id())+"-"): return
	for filename in DirAccess.get_files_at(job_directory):
		if filename in ["request.json","control.json","control.json.next","variants.bin"] or filename.begins_with("icon-") and filename.ends_with(".bin") and filename.trim_prefix("icon-").trim_suffix(".bin").is_valid_int(): DirAccess.remove_absolute(job_directory.path_join(filename))
func publish(_force: bool=false) -> void: changed.emit(state.duplicate(true))
func close() -> void:
	if remote_active:
		stop_requested=true; send_control()
		var deadline:=Time.get_ticks_msec()+1000
		while child_pid>0 and OS.is_process_running(child_pid) and Time.get_ticks_msec()<deadline: OS.delay_msec(10)
		if child_pid>0 and OS.is_process_running(child_pid): OS.kill(child_pid)
	remote_active=false; child_pid=-1; captures=[]; request={}; pending_clear=false
	cleanup_packets()
	super.close(); local_clear=false
