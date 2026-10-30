extends Node
# User-invoked, bounded parallel preparation. GPU/UI image access stays on the
# main thread; workers own data-only model processing and independent disk saves.
signal changed(state: Dictionary)
signal diagnostic_event(event: Dictionary)
const Assets=preload("res://systems/native_data/asset_service.gd")
const Store=preload("res://systems/native_data/prework_store.gd")
const Sources=preload("res://systems/native_data/session_catalog.gd")
var service
var source_loader
var owned_catalog
var store:=Store.new()
var task:=-1
var task_result: Dictionary={}
var task_mutex:=Mutex.new()
var worker_setting:=0
var worker_count:=automatic_workers()
var icon_tasks: Dictionary={}
var icon_results: Dictionary={}
var icon_serial:=0
var icon_capture_frame:=-1
var prepared_directory:=""
var started_usec:=0
var published_ms:=0
var worker_threads: Dictionary={}
var active_jobs: Dictionary={}
var folder_opener: Callable=func(path: String) -> int: return OS.shell_open(path)
var state:={"active":false,"completed":0,"total":0,"saved":0,"reused":0,"failed":0,"message":"Choose installed or downloaded content, then prepare its assets."}
var names: Array=[]
var variants: Array=[]
var icons: Array=[]
var cursor:=0
var stopping:=false
var clearing:=false
var ticket:=0
var extra_variants: Array=[]
var packet_files: Array=[]
var model_limit:=0
static func automatic_workers() -> int: return clampi(OS.get_processor_count()-1,1,4)
func set_workers(value: int) -> void:
	worker_setting=value if value in [0,1,2,4,8] else 0
	worker_count=automatic_workers() if worker_setting==0 else worker_setting
	if is_instance_valid(service): service.maximum_workers=worker_count; service.maximum_pending=worker_count
	state.workers=worker_count; pump_workers(); publish(true)
func view_saved_files(cache_path: String) -> bool:
	var location:=Store.new()
	if not location.configure(cache_path): state.message=location.failure; publish(true); return false
	var error: int=folder_opener.call(location.directory)
	if error!=OK: state.message="Could not open the saved prework folder."; publish(true)
	return error==OK
func start_sources(sources: Dictionary,cache_path: String,all_models: bool=true) -> bool:
	if state.active or task>=0 or source_loader!=null: return false
	if not store.configure(cache_path): state.message=store.failure; changed.emit(state.duplicate()); return false
	stopping=false; clearing=false
	state={"active":true,"completed":0,"total":0,"saved":0,"reused":0,"failed":0,"message":"Indexing selected local content…"}
	source_loader=Sources.new(); add_child(source_loader)
	source_loader.completed.connect(func(_serial: int,prepared: RefCounted,error: String,_stats: Dictionary):
		var loader=source_loader; source_loader=null; loader.queue_free()
		if clearing: release_catalog(prepared); return
		if stopping: release_catalog(prepared); finish("Preparation cancelled; completed work remains saved."); return
		if not error.is_empty(): release_catalog(prepared); finish("Cannot prepare selected content: "+error); return
		state.active=false
		if start(prepared,cache_path,all_models): owned_catalog=prepared
		else: release_catalog(prepared))
	source_loader.start(sources); changed.emit(state.duplicate()); return true
func start(catalog,cache_path: String,all_models: bool=true) -> bool:
	if state.active or task>=0: return false
	if not store.configure(cache_path): state.message=store.failure; changed.emit(state.duplicate()); return false
	close_service()
	names=catalog.resource_names(2002) if all_models else []; names.sort()
	if model_limit>0: names=names.slice(0,mini(model_limit,names.size()))
	variants=Store.known_requests(catalog)+extra_variants; icons=[]; cursor=0; stopping=false; clearing=false; ticket=store.generation()
	for owner in get_tree().get_nodes_in_group("native_prework_icons"):
		if not owner.closed and owner.cache_directory==cache_path:
			for key in owner.prework_records: icons.append({"owner":weakref(owner),"key":key})
	Store.diagnostics_enabled=true
	service=preload("res://systems/native_prework_assets.gd").new(); add_child(service); service.maximum_workers=worker_count; service.maximum_pending=worker_count; service.cache_directory=cache_path; service.prework_write=true; service.status_only=true; service.configure(catalog); service.completed.connect(completed)
	prepared_directory=cache_path; started_usec=Time.get_ticks_usec(); worker_threads={}; active_jobs={}; icon_capture_frame=-1
	state={"active":true,"completed":0,"total":names.size()*2+variants.size()+icons.size()+packet_files.size(),"saved":0,"reused":0,"failed":0,"rejection_hits":0,"workers":worker_count,"peak_running":0,"issues":[],"slow_jobs":[],"message":"Preparing models and opened UI artwork…"}
	pump_workers(); publish(true); return true
func cancel() -> void:
	if not state.active or clearing: return
	if is_instance_valid(source_loader): source_loader.cancel()
	stopping=true; state.message="Stopping after active workers finish…"; publish(true)
func clear_saved(cache_path: String) -> bool:
	if clearing: return false
	var target:=Store.new()
	if not target.configure(cache_path): state.message=target.failure; changed.emit(state.duplicate()); return false
	if state.active:
		if target.directory!=store.directory: return false
	else: store=target
	stopping=true; clearing=true; state.active=true; state.message="Clearing saved prework…"
	if is_instance_valid(source_loader): source_loader.cancel()
	# If a save is already in flight, clear runs immediately after that task.
	# Asset jobs carry generation tickets, so late publication is rejected too.
	changed.emit(state.duplicate()); return true
func _process(_delta: float) -> void:
	if source_loader!=null: return
	for id in icon_tasks.keys():
		var icon_task: int=icon_tasks[id]
		if not WorkerThreadPool.is_task_completed(icon_task): continue
		WorkerThreadPool.wait_for_task_completion(icon_task); icon_tasks.erase(id)
		task_mutex.lock(); var result: Dictionary=icon_results.get(id,{}); icon_results.erase(id); task_mutex.unlock()
		count_result(result)
	if task>=0:
		if not WorkerThreadPool.is_task_completed(task): publish(); return
		WorkerThreadPool.wait_for_task_completion(task); task=-1
		task_mutex.lock(); var result:=task_result; task_result={}; task_mutex.unlock()
		if result.has("cleared"):
			clearing=false; var message:="Cleared %d saved files (%.1f MiB). Loaded assets remain available."%[int(result.cleared.get("removed",0)),int(result.cleared.get("bytes",0))/1048576.0]
			if not result.cleared.get("errors",[]).is_empty(): message+=" Some files could not be removed."
			finish(message); return
	if not state.active: return
	if stopping or clearing:
		if inflight()>0: publish(); return
	if clearing:
		# Every controller save and model job has now drained. No work is queued
		# after this operation until the user explicitly starts another run.
		task=WorkerThreadPool.add_task(func():
			var result:=store.clear(); task_mutex.lock(); task_result={"cleared":result}; task_mutex.unlock(),false,"Clear saved native prework")
		return
	if stopping: finish("Preparation cancelled; completed work remains saved."); return
	pump_workers()
	if icons.is_empty() and packet_files.is_empty() and variants.is_empty() and cursor>=names.size()*2 and inflight()==0:
		finish("Preparation complete. Saved work will be reused in later sessions."); return
	publish()
func inflight() -> int:
	return icon_tasks.size()+(service.running.size()+service.pending.size() if is_instance_valid(service) else 0)
func pump_workers() -> void:
	if not state.active or stopping or clearing or source_loader!=null or not is_instance_valid(service): return
	while inflight()<worker_count:
		if not packet_files.is_empty():
			icon_serial+=1; var id:=icon_serial; var packet_path:=str(packet_files.pop_front())
			icon_tasks[id]=WorkerThreadPool.add_task(save_packet_file.bind(id,packet_path,prepared_directory,ticket),false,"Save isolated UI prework")
		elif not icons.is_empty() and icon_capture_frame!=Engine.get_process_frames():
			icon_capture_frame=Engine.get_process_frames()
			var row: Dictionary=icons.pop_front(); var owner=row.owner.get_ref()
			var packet: Dictionary=owner.prework_packet(str(row.key)) if is_instance_valid(owner) and not owner.closed else {}
			if packet.is_empty(): count_result({"error":"UI artwork is no longer available"}); continue
			icon_serial+=1; var id:=icon_serial
			icon_tasks[id]=WorkerThreadPool.add_task(save_icon.bind(id,packet,prepared_directory,ticket),false,"Save native UI prework")
		else:
			var job: Dictionary={}
			if not variants.is_empty(): job=variants.pop_front()
			elif cursor<names.size()*2:
				var name:=str(names[cursor/2]); var actor:=cursor%2==1; cursor+=1
				job={"name":name,"type":2002,"decoder":"actor-model" if actor else "static-model","options":{"relevant_tracks":true} if actor else {}}
			else: break
			state.current=str(job.name); state.message="Preparing "+str(job.name)+"…"
			var id: int=service.request(str(job.name),int(job.type),str(job.decoder),job.options)
			if id<0: count_result({"resource_name":job.name,"prework_route":job.decoder,"error":service.failure})
			else: active_jobs[id]={"model":str(job.name),"route":str(job.decoder),"started_ms":Time.get_ticks_msec()}
		state.peak_running=maxi(int(state.get("peak_running",0)),inflight())
func save_icon(id: int,packet: Dictionary,path: String,epoch_ticket: int) -> void:
	var writer:=Store.new()
	var ok:=writer.configure(path) and writer.save_entry(str(packet.key),packet.inputs,packet.data,epoch_ticket)
	task_mutex.lock(); icon_results[id]={"saved":ok,"error":writer.failure,"thread":OS.get_thread_caller_id()}; task_mutex.unlock()
func save_packet_file(id: int,filename: String,path: String,epoch_ticket: int) -> void:
	var value: Variant=bytes_to_var(FileAccess.get_file_as_bytes(filename))
	if value is Dictionary and value.has("key") and value.has("inputs") and value.has("data"): save_icon(id,value,path,epoch_ticket)
	else:
		task_mutex.lock(); icon_results[id]={"saved":false,"error":"Invalid isolated artwork packet"}; task_mutex.unlock()
func completed(_id: int,result: Dictionary) -> void:
	active_jobs.erase(_id); count_result(result); pump_workers()
func count_result(result: Dictionary) -> void:
	state.completed+=1
	if result.get("prework_hit",false): state.reused+=1
	elif result.get("prework_saved",false) or result.get("saved",false): state.saved+=1
	else:
		state.failed+=1; state.last_error=str(result.get("prework_error",result.get("error","Asset was not saved")))
		state.last_error_model=str(result.get("resource_name","UI artwork")); state.last_error_route=str(result.get("prework_route",""))
		if result.get("rejection_hit",false): state.rejection_hits=int(state.get("rejection_hits",0))+1
	var event:={"model":str(result.get("resource_name","UI artwork")),"route":str(result.get("prework_route","")),"worker_ms":float(result.get("worker_ms",0.0)),"error":str(result.get("prework_error",result.get("error",""))),"rejection_hit":bool(result.get("rejection_hit",false)),"phases":result.get("prework_phases",{})}
	if not event.error.is_empty():
		state.issues.append(event)
		if state.issues.size()>16: state.issues.pop_front()
	if event.worker_ms>=1000.0:
		state.slow_jobs.append(event); state.slow_jobs.sort_custom(func(a,b):return float(a.worker_ms)>float(b.worker_ms))
		if state.slow_jobs.size()>16: state.slow_jobs.resize(16)
	if not event.error.is_empty() or event.worker_ms>=1000.0: diagnostic_event.emit(event)
	if result.has("thread"): worker_threads[int(result.thread)]=true
func publish(force: bool=false) -> void:
	if not force and Time.get_ticks_msec()-published_ms<100: return
	published_ms=Time.get_ticks_msec(); state.workers=worker_count; state.running=inflight(); state.threads=worker_threads.keys()
	var active: Array=[]
	for job in active_jobs.values(): active.append({"model":job.model,"route":job.route,"elapsed_ms":Time.get_ticks_msec()-int(job.started_ms)})
	active.sort_custom(func(a,b):return int(a.elapsed_ms)>int(b.elapsed_ms)); state.active_jobs=active
	if state.active and not stopping and not clearing and not active.is_empty():
		state.message="Preparing %d models · longest: %s (%.1f s)"%[active.size(),str(active[0].model),int(active[0].elapsed_ms)/1000.0]
	if started_usec>0:
		state.elapsed_ms=(Time.get_ticks_usec()-started_usec)/1000.0
		state.items_per_second=int(state.completed)*1000.0/maxf(1.0,float(state.elapsed_ms))
	changed.emit(state.duplicate())
func finish(message: String) -> void:
	state.active=false; state.message=message; names=[]; icons=[]; variants=[]; active_jobs={}; close_service(); release_catalog(owned_catalog); owned_catalog=null; publish(true)
func release_catalog(value) -> void:
	if value==null: return
	for layer in value.layers:
		if layer.get("kind","")=="nwsync": layer.store.close()
func close_service() -> void:
	if is_instance_valid(service): service.close(); service.queue_free(); service=null
func close() -> void:
	stopping=true
	if source_loader!=null: source_loader.close(); source_loader.queue_free(); source_loader=null
	if task>=0: WorkerThreadPool.wait_for_task_completion(task); task=-1
	for icon_task in icon_tasks.values(): WorkerThreadPool.wait_for_task_completion(int(icon_task))
	icon_tasks.clear(); task_mutex.lock(); icon_results.clear(); task_mutex.unlock()
	close_service()
	active_jobs={}
	release_catalog(owned_catalog); owned_catalog=null
	if state.active: state.message="Preparation stopped. Completed work remains saved."
	state.active=false; names=[]; icons=[]; variants=[]; stopping=false; clearing=false
	publish(true)
func _exit_tree() -> void: close()
