extends Node
# Catalog and optional cached-source verification run off the presentation thread.
signal completed(catalog: RefCounted,error: String,stats: Dictionary)
const Catalog=preload("res://systems/native_data/capture_catalog.gd")
var task:=-1
var generation:=0
var result: Dictionary={}
var mutex:=Mutex.new()
func start(input: Dictionary,source_path: String="",source_sha256: String="") -> void:
	close(); generation+=1; var own_generation:=generation; var owned:=input.duplicate(true)
	task=WorkerThreadPool.add_task(func():
		var began:=Time.get_ticks_usec(); var catalog:=Catalog.new(); var error:=""
		if not catalog.mount(str(owned.capture),str(owned.context),owned.get("supplements",[])): error=catalog.failure
		elif catalog.events_sha256!=owned.get("eventsSha256"): error="Decoded input belongs to another capture"
		if error.is_empty() and not source_path.is_empty():
			var file:=FileAccess.open(source_path,FileAccess.READ)
			var bytes:=PackedByteArray()
			if file!=null and file.get_length()<=1024*1024: bytes=file.get_buffer(file.get_length())
			if not catalog.digest_valid(source_sha256) or file==null or file.get_length()>1024*1024 or preload("res://systems/native_data/prepared_cache.gd").digest(bytes)!=source_sha256: error="Cached source descriptor checksum/bound differs"
			else:
				var descriptor: Variant=JSON.parse_string(bytes.get_string_from_utf8())
				if not descriptor is Dictionary or not catalog.mount_cached_source(descriptor): error=catalog.failure if not catalog.failure.is_empty() else "Invalid cached source descriptor"
		var stats:={"prepare_ms":(Time.get_ticks_usec()-began)/1000.0,"worker_thread":OS.get_thread_caller_id(),"source_sha256":source_sha256,"source":catalog.source_cache.evidence.duplicate(true) if catalog.source_cache!=null else {},"rendering_prepared":false}
		if not error.is_empty(): catalog.close_sources()
		mutex.lock(); result={"generation":own_generation,"catalog":catalog,"error":error,"stats":stats}; mutex.unlock(),false,"Native captured resource catalog")
func _process(_delta: float) -> void:
	if task<0 or not WorkerThreadPool.is_task_completed(task): return
	WorkerThreadPool.wait_for_task_completion(task); task=-1
	mutex.lock(); var prepared:=result; result={}; mutex.unlock()
	if int(prepared.get("generation",-1))!=generation: return
	completed.emit(prepared.catalog,str(prepared.error),prepared.stats)
func close() -> void:
	generation+=1
	if task>=0: WorkerThreadPool.wait_for_task_completion(task); task=-1
	mutex.lock()
	if result.has("catalog"): result.catalog.close_sources()
	result.clear(); mutex.unlock()
func _exit_tree() -> void: close()
