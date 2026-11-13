extends RefCounted
# Standalone native draw-mesh cache prototype. The resource pool remains the
# owner of live draw meshes, original picking/collision and material bindings.
# No area/entity state, downloaded archives, textures or live metadata is saved.
const REVISION:="native-draw-resource-v3"
const BUFFER_METADATA:="nwn_native_draw_buffers"
const MAX_REQUESTS:=32
const MAX_READY:=32
const MAX_WRITES:=8
var backend
var payload_mode:="packed-buffers"
var engine_fingerprint:=""
var failure:=""
var reads: Dictionary={}
var ready: Dictionary={}
var ready_order: Array[String]=[]
var writes: Dictionary={}
var states: Dictionary={}
var closing:=false
var closed:=false
var epoch:=0
var write_results: Dictionary={}
var read_results: Dictionary={}
var write_gate:=Mutex.new()
var stats:={"prefetches":0,"prefetch_misses":0,"loads_started":0,"loads_completed":0,"loads_failed":0,"resources_rejected":0,"taken":0,"ready_evictions":0,"stale_reads_discarded":0,"private_copies":0,"buffer_snapshots":0,"save_gpu_meshes_created":0,"take_gpu_meshes_created":0,"take_build_us":0,"copy_us":0,"writes_queued":0,"writes_completed":0,"writes_failed":0,"write_busy_retries":0,"worker_save_us":0,"poll_us":0,"maximum_poll_us":0,"lease_lookup_us":0,"header_read_us":0,"load_request_us":0,"status_poll_us":0,"completed_get_us":0,"validation_us":0,"release_read_us":0,"invalidate_us":0,"begin_write_us":0,"commit_write_us":0,"prefetch_worker_threads":[],"write_worker_threads":[]}

static func digest(bytes: PackedByteArray) -> String:
	var hashing:=HashingContext.new();hashing.start(HashingContext.HASH_SHA256);hashing.update(bytes);return hashing.finish().hex_encode()
static func valid_key(value: String) -> bool:return value.length()==64 and value==value.to_lower() and value.is_valid_hex_number()
static func _flag_view(value: Dictionary) -> Array:
	var keys: Array=value.keys();var result: Array=[]
	for key in keys:
		if not key is String:return []
	keys.sort()
	for key in keys:
		var item: Variant=value[key]
		if not (item is bool or item is int or item is String or item is float and is_finite(item)):return []
		result.append([key,item])
	return result
static func engine_identity(binary_fingerprint: String="",version: Dictionary={}) -> Array:
	# Custom engines may report hash='unknown'. Retain the full version tuple,
	# plus an optional exact executable hash supplied once by the owning service.
	var info: Dictionary=Engine.get_version_info() if version.is_empty() else version
	return [REVISION,int(info.get("major",-1)),int(info.get("minor",-1)),int(info.get("patch",-1)),str(info.get("status","")),str(info.get("build","")),str(info.get("hash","")),binary_fingerprint]
static func key_for(source_sha: String,part: int,converter_revision: String,flags: Dictionary={},dependencies: Array=[],mode: String="packed-buffers",binary_fingerprint: String="",engine_version: Dictionary={}) -> String:
	if not valid_key(source_sha) or part<0 or part>65535 or converter_revision.is_empty() or mode not in ["packed-buffers","array-mesh"] or not binary_fingerprint.is_empty() and not valid_key(binary_fingerprint):return ""
	var flag_rows:=_flag_view(flags)
	if flag_rows.size()!=flags.size():return ""
	var dependency_rows: Array=[]
	for value in dependencies:
		if not value is String or not valid_key(value):return ""
		if not dependency_rows.has(value):dependency_rows.append(value)
	dependency_rows.sort()
	return digest(var_to_bytes([REVISION,mode,engine_identity(binary_fingerprint,engine_version),source_sha,part,converter_revision,flag_rows,dependency_rows]))

func configure(store,mode: String="packed-buffers",binary_fingerprint: String="") -> bool:
	if backend!=null or closing or closed or mode not in ["packed-buffers","array-mesh"] or not binary_fingerprint.is_empty() and not valid_key(binary_fingerprint):return false
	for method in ["acquire_read","release_read","begin_write","commit_write","cancel_write","snapshot"]:
		if store==null or not store.has_method(method):failure="Prepared resource store interface is unavailable";return false
	backend=store;payload_mode=mode;engine_fingerprint=binary_fingerprint;return true

static func _data_only(value: Variant,depth: int=0) -> bool:
	if depth>32:return false
	if value is Object or value is Callable or value is Signal:return false
	if value is Array:
		for item in value:
			if not _data_only(item,depth+1):return false
	elif value is Dictionary:
		for key in value:
			if not _data_only(key,depth+1) or not _data_only(value[key],depth+1):return false
	return true

static func pure_mesh(mesh: ArrayMesh) -> bool:return _pure_mesh(mesh,{})
static func _pure_mesh(mesh: ArrayMesh,visited: Dictionary) -> bool:
	if mesh==null or mesh.get_class()!="ArrayMesh" or mesh.get_script()!=null or not mesh.get_meta_list().is_empty() or mesh.get_surface_count()<1:return false
	if visited.has(mesh.get_instance_id()):return false
	visited[mesh.get_instance_id()]=true
	for index in mesh.get_surface_count():
		if mesh.surface_get_material(index)!=null:return false
	if mesh.shadow_mesh!=null and not _pure_mesh(mesh.shadow_mesh,visited):return false
	return true

func snapshot_draw_buffers(source: ArrayMesh) -> Dictionary:return _snapshot_draw_buffers(source,{},0)
func _snapshot_draw_buffers(source: ArrayMesh,visited: Dictionary,depth: int) -> Dictionary:
	# Resource.duplicate first attaches the original Script and can clone large
	# metadata graphs. Construct a private built-in duplicate from the native
	# serialized draw buffers instead. No source Script or metadata is touched.
	if source==null or source.get_surface_count()<1 or depth>4 or visited.has(source.get_instance_id()):failure="Unsupported or cyclic native mesh resource";return {}
	if not source.get_aabb().position.is_finite() or not source.get_aabb().end.is_finite() or not source.custom_aabb.position.is_finite() or not source.custom_aabb.end.is_finite():failure="Invalid native mesh bounds";return {}
	visited[source.get_instance_id()]=true
	var surfaces: Variant=source.get("_surfaces")
	if not surfaces is Array or surfaces.size()!=source.get_surface_count():failure="Native mesh surface representation unavailable";return {}
	var clean_surfaces: Array=surfaces.duplicate(true)
	for surface in clean_surfaces:
		if not surface is Dictionary:failure="Native mesh surface representation unavailable";return {}
		surface.erase("material")
		if not _data_only(surface):failure="Native mesh contains a non-data draw dependency";return {}
	var names: Array=[]
	for index in source.get_blend_shape_count():names.append(str(source.get_blend_shape_name(index)))
	var result:={"surfaces":clean_surfaces,"blend_shape_names":names,"blend_shape_mode":source.blend_shape_mode,"custom_aabb":source.custom_aabb,"shadow":{}}
	if source.shadow_mesh!=null:
		var shadow:=_snapshot_draw_buffers(source.shadow_mesh,visited,depth+1)
		if shadow.is_empty():return {}
		result.shadow=shadow
	return result

static func valid_buffers(data: Dictionary,depth: int=0) -> bool:
	if depth>4 or not data.get("surfaces") is Array or data.surfaces.is_empty() or data.surfaces.size()>4096 or not data.get("blend_shape_names") is Array or not data.get("blend_shape_mode") is int or not data.get("custom_aabb") is AABB or not data.get("shadow") is Dictionary:return false
	if not data.custom_aabb.position.is_finite() or not data.custom_aabb.end.is_finite():return false
	for name in data.blend_shape_names:
		if not name is String:return false
	for surface in data.surfaces:
		if not surface is Dictionary or surface.has("material") or not surface.get("format") is int or not surface.get("primitive") is int or not surface.get("vertex_count") is int or surface.vertex_count<1 or not surface.get("vertex_data") is PackedByteArray or surface.vertex_data.is_empty() or not surface.get("aabb") is AABB or not _data_only(surface):return false
	return data.shadow.is_empty() or valid_buffers(data.shadow,depth+1)

func restore_draw_buffers(data: Dictionary) -> ArrayMesh:
	if not valid_buffers(data):failure="Native packed draw buffers are unavailable";return null
	var result:=ArrayMesh.new()
	for name in data.blend_shape_names:result.add_blend_shape(name)
	result.blend_shape_mode=data.blend_shape_mode;result.custom_aabb=data.custom_aabb;result.set("_surfaces",data.surfaces)
	if not data.shadow.is_empty():
		var shadow:=restore_draw_buffers(data.shadow)
		if shadow==null:return null
		result.shadow_mesh=shadow
	return result

func private_draw_copy(source: ArrayMesh) -> ArrayMesh:
	var buffers:=snapshot_draw_buffers(source)
	return null if buffers.is_empty() else restore_draw_buffers(buffers)

func _accepted_resource(value: Resource,key: String) -> bool:
	if payload_mode=="array-mesh":return value is ArrayMesh and pure_mesh(value)
	if value==null or value.get_class()!="Resource" or value.get_script()!=null or value.get_meta_list().size()!=1 or not value.has_meta(BUFFER_METADATA):return false
	var data: Variant=value.get_meta(BUFFER_METADATA)
	return data is Dictionary and data.get("revision")==REVISION and data.get("key")==key and data.get("engine")==engine_identity(engine_fingerprint) and data.get("mesh") is Dictionary and valid_buffers(data.mesh)

func _state(key: String,value: String) -> void:
	if states.size()>=1024 and not states.has(key):states.erase(states.keys()[0])
	states[key]=value
func state(key: String) -> String:
	if ready.has(key):return "ready"
	if reads.has(key) and not reads[key].get("releasing",false):return "loading"
	return str(states.get(key,"not-requested"))
func _finish_read_worker(key: String,ticket: Dictionary,invalidate: bool) -> void:
	var began:=Time.get_ticks_usec();backend.release_read(ticket)
	var result:={"release_read_us":Time.get_ticks_usec()-began,"invalidate_us":0}
	if invalidate and backend.has_method("invalidate"):
		began=Time.get_ticks_usec();backend.invalidate(key);result.invalidate_us=Time.get_ticks_usec()-began
	write_gate.lock();read_results[key]=result;write_gate.unlock()
func _finish_read(key: String,entry: Dictionary,invalidate: bool=false) -> void:
	entry.releasing=true;entry.task=WorkerThreadPool.add_task(_finish_read_worker.bind(key,entry.ticket,invalidate),false,"Release native draw artifact lease")
func _prefetch_worker(key: String,request_epoch: int) -> void:
	# Lease filesystem work can take milliseconds even for a warm entry. This
	# worker performs lookup, lease acquisition, bounded header read and request;
	# the presentation thread only checks already-completed results.
	var began:=Time.get_ticks_usec();var ticket: Dictionary=backend.acquire_read(key)
	var result:={"key":key,"epoch":request_epoch,"ticket":ticket,"lease_lookup_us":Time.get_ticks_usec()-began,"header_read_us":0,"load_request_us":0,"release_read_us":0,"state":"missing","error":"","thread":OS.get_thread_caller_id()}
	if ticket.is_empty():
		if str(backend.get("failure"))=="busy":result.state="busy"
	else:
		var path:=str(ticket.get("path",""));result.path=path;began=Time.get_ticks_usec();var file:=FileAccess.open(path,FileAccess.READ)
		var header:=""
		if file!=null:header=file.get_buffer(4).get_string_from_ascii();file.close()
		result.header_read_us=Time.get_ticks_usec()-began
		if header not in ["RSRC","RSCC"]:
			result.state="failed";result.error="Native resource binary header differs"
		else:
			began=Time.get_ticks_usec();var request:=ResourceLoader.load_threaded_request(path,"Resource",false,ResourceLoader.CACHE_MODE_IGNORE);result.load_request_us=Time.get_ticks_usec()-began
			if request==OK:result.state="loading"
			else:result.state="failed";result.error="Native resource threaded request failed"
		if result.state!="loading":
			began=Time.get_ticks_usec();backend.release_read(ticket);result.release_read_us=Time.get_ticks_usec()-began
			if backend.has_method("invalidate"):backend.invalidate(key)
	write_gate.lock();read_results[key]=result;write_gate.unlock()
func prefetch(key: String) -> String:
	failure=""
	if backend==null or closing or closed or not valid_key(key):failure="Native resource prefetch is unavailable";return "unavailable"
	stats.prefetches+=1
	if ready.has(key):return "ready"
	if reads.has(key):return "releasing" if reads[key].get("releasing",false) else "loading"
	if reads.size()>=MAX_REQUESTS:return "capacity"
	var task:=WorkerThreadPool.add_task(_prefetch_worker.bind(key,epoch),false,"Prefetch native draw artifact")
	if task<0:failure="Native resource prefetch worker unavailable";return "unavailable"
	reads[key]={"starting":true,"task":task,"epoch":epoch,"started_us":Time.get_ticks_usec()};_state(key,"loading");return "loading"

func _poll_read(key: String) -> bool:
	var entry: Dictionary=reads[key]
	if entry.get("releasing",false):
		if not WorkerThreadPool.is_task_completed(int(entry.task)):return false
		WorkerThreadPool.wait_for_task_completion(int(entry.task))
		write_gate.lock();var released: Dictionary=read_results.get(key,{});read_results.erase(key);write_gate.unlock()
		stats.release_read_us+=int(released.get("release_read_us",0));stats.invalidate_us+=int(released.get("invalidate_us",0));reads.erase(key);return true
	if entry.get("starting",false):
		if not WorkerThreadPool.is_task_completed(int(entry.task)):return false
		WorkerThreadPool.wait_for_task_completion(int(entry.task))
		write_gate.lock();var start: Dictionary=read_results.get(key,{});read_results.erase(key);write_gate.unlock()
		for field in ["lease_lookup_us","header_read_us","load_request_us","release_read_us"]:stats[field]+=int(start.get(field,0))
		if start.has("thread") and not stats.prefetch_worker_threads.has(start.thread):stats.prefetch_worker_threads.append(start.thread)
		if start.get("state")!="loading":
			reads.erase(key);_state(key,str(start.get("state","failed")))
			if start.get("state")=="missing":stats.prefetch_misses+=1
			elif start.get("state")=="failed":stats.resources_rejected+=1;failure=str(start.get("error","Native resource prefetch failed"))
			return true
		entry.merge(start);entry.starting=false;entry.erase("task");stats.loads_started+=1
	var began:=Time.get_ticks_usec();var status:=ResourceLoader.load_threaded_get_status(entry.path);stats.status_poll_us+=Time.get_ticks_usec()-began
	if status==ResourceLoader.THREAD_LOAD_IN_PROGRESS:return false
	var value: Resource=null
	# Never call get while a request is still in progress: it would block.
	if status in [ResourceLoader.THREAD_LOAD_LOADED,ResourceLoader.THREAD_LOAD_FAILED]:
		began=Time.get_ticks_usec();value=ResourceLoader.load_threaded_get(entry.path);stats.completed_get_us+=Time.get_ticks_usec()-began
	if closing or int(entry.epoch)!=epoch:stats.stale_reads_discarded+=1;_state(key,"retired");_finish_read(key,entry);return true
	began=Time.get_ticks_usec();var accepted:=status==ResourceLoader.THREAD_LOAD_LOADED and _accepted_resource(value,key);stats.validation_us+=Time.get_ticks_usec()-began
	if not accepted:
		stats.loads_failed+=1;failure="Native resource load did not produce the expected clean draw artifact";_state(key,"failed")
		_finish_read(key,entry,true)
		return true
	while ready.size()>=MAX_READY and not ready_order.is_empty():
		var old: String=ready_order.pop_front();ready.erase(old);_state(old,"evicted");stats.ready_evictions+=1
	ready[key]=value;ready_order.append(key);stats.loads_completed+=1;_state(key,"ready");_finish_read(key,entry);return true

func take_ready(key: String) -> ArrayMesh:
	if closing or closed or not ready.has(key):return null
	var resource: Resource=ready[key];ready.erase(key);ready_order.erase(key);_state(key,"taken");stats.taken+=1
	var value: ArrayMesh
	if payload_mode=="packed-buffers":
		var began:=Time.get_ticks_usec();value=restore_draw_buffers(resource.get_meta(BUFFER_METADATA).mesh);stats.take_build_us+=Time.get_ticks_usec()-began
		if value!=null:stats.take_gpu_meshes_created+=1
	else:value=resource
	# Ownership moves to the current resource pool. It may attach fresh original
	# collision/pick metadata there; the immutable file and next load stay clean.
	return value

func queue_save(key: String,source: ArrayMesh) -> bool:
	failure=""
	if backend==null or closing or closed or not valid_key(key) or writes.size()>=MAX_WRITES or writes.has(key):failure="Native resource write is unavailable";return false
	var began:=Time.get_ticks_usec();var clean: Resource
	if payload_mode=="packed-buffers":
		var buffers:=snapshot_draw_buffers(source)
		if not buffers.is_empty():
			clean=Resource.new();clean.set_meta(BUFFER_METADATA,{"revision":REVISION,"engine":engine_identity(engine_fingerprint),"key":key,"mesh":buffers});stats.buffer_snapshots+=1
	else:
		clean=private_draw_copy(source)
		if clean!=null:stats.private_copies+=1;stats.save_gpu_meshes_created+=1
	stats.copy_us+=Time.get_ticks_usec()-began
	if clean==null:return false
	var job:={"key":key,"mesh":clean,"epoch":epoch}
	var task:=WorkerThreadPool.add_task(_save_worker.bind(job),false,"Save native draw mesh resource")
	if task<0:failure="Native resource save worker unavailable";return false
	writes[key]={"task":task,"mesh":clean,"epoch":epoch,"attempts":0};stats.writes_queued+=1;return true

func _record_write(key: String,result: Dictionary) -> void:
	write_gate.lock();write_results[key]=result;write_gate.unlock()

func _commit_worker(key: String,ticket: Dictionary) -> void:
	var began:=Time.get_ticks_usec();var committed: bool=backend.commit_write(ticket)
	var result:={"phase":"done" if committed else "retry-commit" if str(backend.get("failure"))=="busy" else "failed","ticket":ticket,"error":"" if committed else str(backend.get("failure")),"commit_write_us":Time.get_ticks_usec()-began,"thread":OS.get_thread_caller_id()}
	if result.phase=="failed":backend.cancel_write(ticket)
	_record_write(key,result)
func _cancel_worker(key: String,ticket: Dictionary) -> void:
	backend.cancel_write(ticket);_record_write(key,{"phase":"cancelled","thread":OS.get_thread_caller_id()})

func _save_worker(job: Dictionary) -> void:
	var began:=Time.get_ticks_usec()
	var ticket: Dictionary=backend.begin_write(str(job.key));var begin_us:=Time.get_ticks_usec()-began
	if ticket.is_empty():
		_record_write(job.key,{"phase":"retry-begin" if str(backend.get("failure"))=="busy" else "failed","error":str(backend.get("failure")),"begin_write_us":begin_us,"thread":OS.get_thread_caller_id()});return
	# These private built-in resource buffers are immutable after handoff.
	# No live Nodes, materials or source metadata enter this worker.
	began=Time.get_ticks_usec();var error:=ResourceSaver.save(job.mesh,str(ticket.path),ResourceSaver.FLAG_COMPRESS);var save_us:=Time.get_ticks_usec()-began
	if error!=OK:
		backend.cancel_write(ticket);_record_write(job.key,{"phase":"failed","error":"Native resource compressed save failed","begin_write_us":begin_us,"save_us":save_us,"thread":OS.get_thread_caller_id()});return
	began=Time.get_ticks_usec();var committed: bool=backend.commit_write(ticket)
	var result:={"phase":"done" if committed else "retry-commit" if str(backend.get("failure"))=="busy" else "failed","ticket":ticket,"error":"" if committed else str(backend.get("failure")),"begin_write_us":begin_us,"save_us":save_us,"commit_write_us":Time.get_ticks_usec()-began,"thread":OS.get_thread_caller_id()}
	if result.phase=="failed":backend.cancel_write(ticket)
	_record_write(job.key,result)

func _poll_write(key: String) -> bool:
	var entry: Dictionary=writes[key]
	if not WorkerThreadPool.is_task_completed(int(entry.task)):return false
	WorkerThreadPool.wait_for_task_completion(int(entry.task))
	write_gate.lock();var result: Dictionary=write_results.get(key,{});write_results.erase(key);write_gate.unlock()
	stats.worker_save_us+=int(result.get("save_us",0));stats.begin_write_us+=int(result.get("begin_write_us",0));stats.commit_write_us+=int(result.get("commit_write_us",0))
	if result.has("thread") and not stats.write_worker_threads.has(result.thread):stats.write_worker_threads.append(result.thread)
	var phase:=str(result.get("phase","failed"))
	if phase in ["retry-begin","retry-commit"]:
		entry.attempts+=1;stats.write_busy_retries+=1
		if closing or int(entry.epoch)!=epoch or int(entry.attempts)>8:
			if phase=="retry-commit":entry.mesh=null;entry.task=WorkerThreadPool.add_task(_cancel_worker.bind(key,result.ticket),false,"Cancel native draw artifact");return false
			writes.erase(key);return true
		if phase=="retry-commit":entry.mesh=null;entry.task=WorkerThreadPool.add_task(_commit_worker.bind(key,result.ticket),false,"Publish native draw artifact")
		else:entry.task=WorkerThreadPool.add_task(_save_worker.bind({"key":key,"mesh":entry.mesh,"epoch":entry.epoch}),false,"Retry native draw artifact")
		return false
	writes.erase(key)
	if phase=="done":stats.writes_completed+=1
	elif phase!="cancelled":stats.writes_failed+=1;failure=str(result.get("error","Native resource write failed"))
	return true

func poll(maximum: int=8,budget_ms: float=0.75) -> bool:
	if backend==null:return true
	var began:=Time.get_ticks_usec();var finished:=0
	for key in reads.keys():
		if finished>=maximum or finished>0 and (Time.get_ticks_usec()-began)/1000.0>=budget_ms:break
		if _poll_read(str(key)):finished+=1
	for key in writes.keys():
		if finished>=maximum or finished>0 and (Time.get_ticks_usec()-began)/1000.0>=budget_ms:break
		if _poll_write(str(key)):finished+=1
	if closing:
		while not ready_order.is_empty() and finished<maximum:
			if finished>0 and (Time.get_ticks_usec()-began)/1000.0>=budget_ms:break
			ready.erase(ready_order.pop_front());finished+=1
		closed=reads.is_empty() and writes.is_empty() and ready.is_empty()
	var elapsed:=Time.get_ticks_usec()-began;stats.poll_us+=elapsed;stats.maximum_poll_us=maxi(int(stats.maximum_poll_us),elapsed)
	return reads.is_empty() and writes.is_empty()
func close() -> bool:
	if closed:return true
	if backend==null:closing=true;closed=true;return true
	if not closing:closing=true;epoch+=1
	poll();return closed
func snapshot() -> Dictionary:
	return {"revision":REVISION,"payload_mode":payload_mode,"closing":closing,"closed":closed,"epoch":epoch,"pending_reads":reads.size(),"pending_writes":writes.size(),"ready":ready.size(),"states":states.duplicate(),"stats":stats.duplicate(true),"failure":failure,"readiness":"Only completed ResourceLoader requests can be taken; misses use original publisher","store":backend.snapshot() if backend!=null else {},"scope":"Pure native draw artifact prototype; collision/pick/material reconstruction and production integration remain with existing owners"}
