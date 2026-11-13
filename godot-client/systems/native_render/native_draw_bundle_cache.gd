extends RefCounted
# Prototype only. One immutable material-free draw artifact per complete model
# cohort. Existing AssetService/Pool owners are deliberately not wired here.
const Codec=preload("res://systems/native_render/native_mesh_resource_cache.gd")
const Preparation=preload("res://systems/native_data/mesh_preparation.gd")
const REVISION:="native-model-draw-bundle-v1"
const METADATA:="nwn_native_model_draw_bundle"
const MAX_SLOTS:=4096
const DEFAULT_LIMITS:={"captures":8,"writes":4,"reads":8,"scopes":64,"bundle_bytes":64*1024*1024,"resident_bytes":128*1024*1024,"minimum_draw_bytes":128*1024,"commit_retries":8}
const READ_PHASES:={"io_gate_wait":0,"lease_acquire":0,"resource_parse":0,"reader_thread_overhead":0,"schema_validation":0,"detached_copy":0,"lease_release":0,"artifact_invalidation":0}
var backend
var engine_fingerprint:=""
var limits: Dictionary=DEFAULT_LIMITS.duplicate()
var failure:=""
var _gate:=Mutex.new()
var _io:=Mutex.new() # Dedicated store instance; serialize its mutable failure field.
var _scopes: Dictionary={}
var _captures: Dictionary={}
var _jobs: Dictionary={}
var _results: Dictionary={}
var _next_scope:=0
var _next_capture:=0
var _epoch:=0
var _active_reads:=0
var _resident_bytes:=0
var _closing:=false
var _closed:=false
var _stats:={"loads":0,"hits":0,"misses":0,"busy":0,"rejected":0,"invalidations":0,"invalidation_deferred":0,"stale_reads":0,"bypassed":0,"captures":0,"snapshots":0,"capture_discards":0,"writes_queued":0,"writes_completed":0,"writes_failed":0,"write_retries":0,"stale_writes":0,"read_worker_us":0,"write_worker_us":0,"snapshot_us":0,"poll_us":0,"read_threads":[],"loader_threads":[],"write_threads":[]}
var _read_phases:=READ_PHASES.duplicate()

static func digest(bytes: PackedByteArray) -> String:
	var h:=HashingContext.new();h.start(HashingContext.HASH_SHA256);h.update(bytes);return h.finish().hex_encode()
static func valid_sha(value: String) -> bool:return value.length()==64 and value==value.to_lower() and value.is_valid_hex_number(false)
static func engine_identity(fingerprint: String) -> Array:
	# Custom engine builds can report hash="unknown". The caller supplies the
	# executable/build fingerprint once; no per-model executable hashing occurs.
	if not valid_sha(fingerprint):return []
	var version:=Engine.get_version_info();var rows: Array=[];var keys:=version.keys();keys.sort()
	for key in keys:
		var value: Variant=version[key]
		if not (value is String or value is int):return []
		rows.append([str(key),value])
	return [fingerprint,rows]
static func slot_key(node: int,rigid: bool=false) -> String:return str(node)+(":rigid" if rigid else ":draw")
static func _cohort(value: Array) -> Array:
	if value.is_empty() or value.size()>MAX_SLOTS:return []
	var result: Array=[];var seen: Dictionary={}
	for row in value:
		if not row is Array or row.size()!=2 or not row[0] is int or row[0]<0 or row[0]>65535 or not row[1] is bool:return []
		var key:=slot_key(row[0],row[1])
		if seen.has(key):return []
		seen[key]=true;result.append([row[0],row[1]])
	result.sort_custom(func(a,b):return a[0]<b[0] or (a[0]==b[0] and not a[1] and b[1]))
	return result
static func descriptor_for(source_sha: String,cohort: Array,fingerprint: String,mesh_revision: String=Preparation.REVISION,flags: Dictionary={},dependencies: Array=[]) -> Dictionary:
	if not valid_sha(source_sha) or mesh_revision.is_empty() or mesh_revision.length()>256 or flags.size()>32 or dependencies.size()>256:return {}
	var engine:=engine_identity(fingerprint);var slots:=_cohort(cohort)
	if engine.is_empty() or slots.is_empty():return {}
	var flag_keys:=flags.keys();var flag_rows: Array=[]
	for key in flag_keys:
		if not key is String or key.length()>128:return {}
	flag_keys.sort()
	for key in flag_keys:
		var item: Variant=flags[key]
		if not (item is bool or item is int or item is String or item is float and is_finite(item)) or item is String and item.length()>256:return {}
		flag_rows.append([key,item])
	var dependency_rows: Array=[]
	for item in dependencies:
		if not item is String or not valid_sha(item):return {}
		if not dependency_rows.has(item):dependency_rows.append(item)
	dependency_rows.sort()
	var result:={"revision":REVISION,"source_sha":source_sha,"mesh_revision":mesh_revision,"engine":engine,"cohort":slots,"flags":flag_rows,"dependencies":dependency_rows}
	result.key=digest(var_to_bytes([REVISION,source_sha,mesh_revision,engine,slots,flag_rows,dependency_rows]))
	return result
static func valid_descriptor(value: Dictionary,fingerprint: String) -> bool:
	if value.size()!=8 or value.get("revision")!=REVISION or not value.get("source_sha") is String or not value.get("mesh_revision") is String or not value.get("cohort") is Array or not value.get("flags") is Array or not value.get("dependencies") is Array:return false
	var flags: Dictionary={}
	for row in value.flags:
		if not row is Array or row.size()!=2 or not row[0] is String or flags.has(row[0]):return false
		flags[row[0]]=row[1]
	var canonical:=descriptor_for(value.source_sha,value.cohort,fingerprint,value.mesh_revision,flags,value.dependencies)
	return not canonical.is_empty() and canonical==value
func configure(store,fingerprint: String,options: Dictionary={}) -> bool:
	if backend!=null or _closing or _closed or not valid_sha(fingerprint):return false
	for method in ["acquire_read","release_read","begin_write","commit_write","cancel_write"]:
		if store==null or not store.has_method(method):return false
	var configured:=DEFAULT_LIMITS.duplicate()
	for key in options:
		if not configured.has(key) or not options[key] is int or options[key]<0:return false
		configured[key]=options[key]
	if configured.captures<1 or configured.captures>64 or configured.writes<1 or configured.writes>16 or configured.reads<1 or configured.reads>64 or configured.scopes<1 or configured.scopes>256 or configured.bundle_bytes<1 or configured.bundle_bytes>128*1024*1024 or configured.resident_bytes<configured.bundle_bytes or configured.resident_bytes>512*1024*1024 or configured.minimum_draw_bytes>configured.bundle_bytes or configured.commit_retries>32:return false
	backend=store;engine_fingerprint=fingerprint;limits=configured;return true
func descriptor(source_sha: String,cohort: Array,mesh_revision: String=Preparation.REVISION,flags: Dictionary={},dependencies: Array=[]) -> Dictionary:
	return descriptor_for(source_sha,cohort,engine_fingerprint,mesh_revision,flags,dependencies)
func new_scope() -> Dictionary:
	_gate.lock();var result: Dictionary={}
	if backend!=null and not _closing and not _closed and _scopes.size()<int(limits.scopes):
		_next_scope+=1;var nonce:=Crypto.new().generate_random_bytes(16).hex_encode()
		result={"owner":get_instance_id(),"epoch":_epoch,"serial":_next_scope,"nonce":nonce};_scopes[_next_scope]=result.duplicate()
	_gate.unlock();return result
func _current_unlocked(scope: Dictionary) -> bool:
	return not _closing and not _closed and scope.size()==4 and scope.get("owner")==get_instance_id() and scope.get("epoch")==_epoch and _scopes.get(scope.get("serial",-1),{})==scope
func current(scope: Dictionary) -> bool:
	_gate.lock();var result:=_current_unlocked(scope);_gate.unlock();return result
func retire_scope(scope: Dictionary) -> bool:
	_gate.lock()
	if not _current_unlocked(scope):_gate.unlock();return false
	_scopes.erase(scope.serial)
	for id in _captures.keys():
		if _captures[id].scope==scope:_discard_capture_unlocked(id)
	_gate.unlock();return true
func _stat(name: String,amount: int=1) -> void:
	_gate.lock();_stats[name]=int(_stats.get(name,0))+amount;_gate.unlock()
func _thread_stat(name: String) -> void:
	_gate.lock();var id:=OS.get_thread_caller_id()
	if not _stats[name].has(id):_stats[name].append(id)
	_gate.unlock()
func _result(state: String,key: String="",reason: String="") -> Dictionary:return {"state":state,"key":key,"reason":reason,"entries":{}}
func _plain_thread_load(path: String) -> Dictionary:
	_thread_stat("loader_threads")
	var began:=Time.get_ticks_usec();var resource: Resource=ResourceLoader.load(path,"Resource",ResourceLoader.CACHE_MODE_IGNORE)
	return {"resource":resource,"parse_us":Time.get_ticks_usec()-began}

# Called inside an existing AssetService worker before texture requests. It is
# intentionally synchronous there: no render-thread disk call or nested worker
# wait, and one lease amortizes all of a model's draw slots.
func load_bundle(value: Dictionary,scope: Dictionary,estimated_draw_bytes: int=-1) -> Dictionary:
	if OS.get_thread_caller_id()==OS.get_main_thread_id():return _result("unavailable","","worker-required")
	value=value.duplicate(true);scope=scope.duplicate()
	if not valid_descriptor(value,engine_fingerprint):return _result("unavailable","","invalid-descriptor")
	var key: String=value.key
	_gate.lock()
	if not _current_unlocked(scope):_gate.unlock();return _result("retired",key)
	if estimated_draw_bytes<0 or estimated_draw_bytes<int(limits.minimum_draw_bytes):_stats.bypassed+=1;_gate.unlock();return _result("bypassed",key,"unknown-or-small-cohort")
	if estimated_draw_bytes>int(limits.bundle_bytes) or _active_reads>=int(limits.reads):_gate.unlock();return _result("capacity",key)
	_active_reads+=1;_stats.loads+=1;_gate.unlock();_thread_stat("read_threads")
	var began:=Time.get_ticks_usec();var phases:=READ_PHASES.duplicate()
	var phase_began:=Time.get_ticks_usec();_io.lock();phases.io_gate_wait+=Time.get_ticks_usec()-phase_began;phase_began=Time.get_ticks_usec()
	var lease: Dictionary=backend.acquire_read(key);var store_failure:=str(backend.get("failure"));phases.lease_acquire=Time.get_ticks_usec()-phase_began;_io.unlock()
	var result:=_result("busy" if store_failure=="busy" else "missing",key)
	if not lease.is_empty():
		# ResourceLoader.load inside a WorkerThreadPool task spawns another pool
		# task in this engine. Its LoadToken cleanup leaked in focused tests and
		# IGNORE could return an unfinished unregistered result. A bounded plain
		# Thread executes the synchronous loader directly. Only this existing
		# asset worker joins it; neither the render thread nor another pool task
		# is required to make progress. active_reads bounds these OS threads.
		var loader:=Thread.new();var resource: Resource=null
		phase_began=Time.get_ticks_usec()
		if loader.start(_plain_thread_load.bind(str(lease.path)))==OK:
			var loaded: Dictionary=loader.wait_to_finish();resource=loaded.get("resource");phases.resource_parse=int(loaded.get("parse_us",0))
		phases.reader_thread_overhead=maxi(0,Time.get_ticks_usec()-phase_began-int(phases.resource_parse));phase_began=Time.get_ticks_usec()
		if resource!=null and resource.get_class()=="Resource" and resource.get_script()==null and resource.get_meta_list().size()==1 and resource.has_meta(METADATA):
			var payload: Variant=resource.get_meta(METADATA)
			if payload is Dictionary and valid_payload(payload,value,int(limits.bundle_bytes)):
				phases.schema_validation=Time.get_ticks_usec()-phase_began;phase_began=Time.get_ticks_usec()
				result={"state":"hit","key":key,"reason":"","entries":payload.entries.duplicate(true)}
				phases.detached_copy=Time.get_ticks_usec()-phase_began
			else:result=_result("rejected",key,"draw-bundle-schema")
		else:result=_result("rejected",key,"draw-bundle-resource:"+("null" if resource==null else str(resource.get_class())+":"+str(resource.get_meta_list())+":script="+str(resource.get_script()!=null)))
		if result.state!="hit":phases.schema_validation=Time.get_ticks_usec()-phase_began
		phase_began=Time.get_ticks_usec();_io.lock();phases.io_gate_wait+=Time.get_ticks_usec()-phase_began;phase_began=Time.get_ticks_usec();backend.release_read(lease);phases.lease_release=Time.get_ticks_usec()-phase_began;_io.unlock()
		# A corrupt derivative must not permanently win same-key deduplication
		# over the next complete original rebuild. The store fences other leases
		# and deletes only its own indexed artifact; contention just defers this.
		if result.state=="rejected" and current(scope) and backend.has_method("invalidate"):
			phase_began=Time.get_ticks_usec();_io.lock();phases.io_gate_wait+=Time.get_ticks_usec()-phase_began;phase_began=Time.get_ticks_usec();var invalidated: bool=backend.invalidate(key);phases.artifact_invalidation=Time.get_ticks_usec()-phase_began;_io.unlock()
			_stat("invalidations" if invalidated else "invalidation_deferred")
	var elapsed:=Time.get_ticks_usec()-began
	_gate.lock();_active_reads-=1;_stats.read_worker_us+=elapsed
	for field in phases:_read_phases[field]+=int(phases[field])
	if not _current_unlocked(scope):_stats.stale_reads+=1;result=_result("retired",key)
	else:
		var counter: String={"hit":"hits","missing":"misses","busy":"busy","rejected":"rejected"}.get(str(result.state),"rejected")
		_stats[counter]+=1
	_gate.unlock();result.worker_us=elapsed;result.phases_us=phases;return result
static func buffers_for(result: Dictionary,node: int,rigid: bool=false) -> Dictionary:
	if result.get("state")!="hit":return {}
	var row: Dictionary=result.get("entries",{}).get(slot_key(node,rigid),{})
	return row.get("buffers",{}).duplicate(true)

static func _bytes(value: Variant,depth: int=0) -> int:
	if depth>24 or value is Object or value is Callable or value is Signal:return -1
	if value is PackedByteArray:return value.size()
	if value is PackedInt32Array or value is PackedFloat32Array:return value.size()*4
	if value is PackedInt64Array or value is PackedFloat64Array:return value.size()*8
	if value is PackedVector2Array:return value.size()*8
	if value is PackedVector3Array:return value.size()*12
	if value is PackedVector4Array or value is PackedColorArray:return value.size()*16
	if value is String or value is StringName:return str(value).length()*4+16
	if value is float and not is_finite(value):return -1
	if value is Array or value is Dictionary:
		var total:=32
		for key in value:
			var amount:=_bytes(key,depth+1)
			if amount<0:return -1
			total+=amount+16
			if value is Dictionary:
				amount=_bytes(value[key],depth+1)
				if amount<0:return -1
				total+=amount
		return total
	if value is AABB and (not value.position.is_finite() or not value.end.is_finite()):return -1
	return 64
static func valid_payload(payload: Dictionary,value: Dictionary,maximum_bytes: int) -> bool:
	if payload.size()!=3 or payload.get("revision")!=REVISION or payload.get("descriptor")!=value or not payload.get("entries") is Dictionary or payload.entries.size()!=value.cohort.size():return false
	for slot in value.cohort:
		var row: Variant=payload.entries.get(slot_key(slot[0],slot[1]))
		if not row is Dictionary or row.size()!=3 or row.get("node")!=slot[0] or row.get("rigid")!=slot[1] or not row.get("buffers") is Dictionary or not Codec.valid_buffers(row.buffers):return false
	var size:=_bytes(payload)
	return size>0 and size<=maximum_bytes

# Render-thread capture performs no filesystem work and creates no second
# ArrayMesh. Snapshot only already-published meshes; partial cohorts never save.
func begin_capture(value: Dictionary,scope: Dictionary) -> Dictionary:
	if OS.get_thread_caller_id()!=OS.get_main_thread_id() or not valid_descriptor(value,engine_fingerprint):return {}
	_gate.lock()
	var descriptor_bytes:=_bytes(value)+256
	if not _current_unlocked(scope) or _captures.size()>=int(limits.captures) or _jobs.size()>=int(limits.writes) or descriptor_bytes>int(limits.bundle_bytes) or _resident_bytes+descriptor_bytes>int(limits.resident_bytes):_gate.unlock();return {}
	_next_capture+=1
	var ticket:={"owner":get_instance_id(),"id":_next_capture,"key":value.key,"scope":scope.duplicate()}
	_captures[_next_capture]={"ticket":ticket.duplicate(true),"descriptor":value.duplicate(true),"scope":scope.duplicate(),"entries":{},"bytes":descriptor_bytes};_resident_bytes+=descriptor_bytes;_stats.captures+=1
	_gate.unlock();return ticket
func _discard_capture_unlocked(id: int) -> void:
	if not _captures.has(id):return
	_resident_bytes-=int(_captures[id].bytes);_captures.erase(id);_stats.capture_discards+=1
func cancel_capture(ticket: Dictionary) -> bool:
	_gate.lock();var entry: Dictionary=_captures.get(ticket.get("id",-1),{})
	if entry.is_empty() or entry.ticket!=ticket:_gate.unlock();return false
	_discard_capture_unlocked(int(ticket.id));_gate.unlock();return true
func capture_mesh(ticket: Dictionary,node: int,rigid: bool,mesh: ArrayMesh) -> String:
	if OS.get_thread_caller_id()!=OS.get_main_thread_id():return "main-thread-required"
	_gate.lock();var entry: Dictionary=_captures.get(ticket.get("id",-1),{})
	if entry.is_empty() or entry.ticket!=ticket or not _current_unlocked(entry.scope):_gate.unlock();return "retired"
	var slot:=slot_key(node,rigid)
	if not entry.descriptor.cohort.has([node,rigid]):_gate.unlock();return "unexpected-slot"
	if entry.entries.has(slot):_gate.unlock();return "duplicate-slot"
	_gate.unlock()
	var began:=Time.get_ticks_usec();var codec:=Codec.new();var buffers: Dictionary=codec.snapshot_draw_buffers(mesh)
	var bytes:=_bytes({"node":node,"rigid":rigid,"buffers":buffers})+_bytes(slot);var elapsed:=Time.get_ticks_usec()-began
	if buffers.is_empty() or not Codec.valid_buffers(buffers) or bytes<0:return "unsupported"
	_gate.lock();entry=_captures.get(ticket.get("id",-1),{})
	if entry.is_empty() or entry.ticket!=ticket or not _current_unlocked(entry.scope):_gate.unlock();return "retired"
	_stats.snapshots+=1;_stats.snapshot_us+=elapsed
	if int(entry.bytes)+bytes+4096>int(limits.bundle_bytes) or _resident_bytes+bytes>int(limits.resident_bytes):_discard_capture_unlocked(int(ticket.id));_gate.unlock();return "capacity"
	entry.entries[slot]={"node":node,"rigid":rigid,"buffers":buffers};entry.bytes+=bytes;_resident_bytes+=bytes
	if entry.entries.size()!=entry.descriptor.cohort.size():_gate.unlock();return "collecting"
	if int(entry.bytes)<int(limits.minimum_draw_bytes):_discard_capture_unlocked(int(ticket.id));_stats.bypassed+=1;_gate.unlock();return "bypassed"
	if _jobs.size()>=int(limits.writes):_discard_capture_unlocked(int(ticket.id));_gate.unlock();return "capacity"
	var payload:={"revision":REVISION,"descriptor":entry.descriptor,"entries":entry.entries}
	if not valid_payload(payload,entry.descriptor,int(limits.bundle_bytes)):_discard_capture_unlocked(int(ticket.id));_gate.unlock();return "capacity"
	var job:={"id":int(ticket.id),"key":str(ticket.key),"scope":entry.scope,"payload":payload,"bytes":int(entry.bytes),"attempts":0}
	_captures.erase(int(ticket.id));_jobs[int(ticket.id)]=job
	var task:=WorkerThreadPool.add_task(_save_worker.bind(job.duplicate()),false,"Save complete native model draw bundle")
	if task<0:_jobs.erase(int(ticket.id));_resident_bytes-=int(job.bytes);_gate.unlock();return "worker-unavailable"
	job.task=task;_stats.writes_queued+=1;_gate.unlock();return "queued"
func _publish_result(id: int,result: Dictionary) -> void:
	_gate.lock();_results[id]=result;_gate.unlock()
func _cancel(ticket: Dictionary) -> void:
	if ticket.is_empty():return
	_io.lock();backend.cancel_write(ticket);_io.unlock()
func _save_worker(job: Dictionary) -> void:
	_thread_stat("write_threads");var began:=Time.get_ticks_usec()
	if not current(job.scope):_publish_result(job.id,{"phase":"stale","us":0});return
	_io.lock();var ticket: Dictionary=backend.begin_write(job.key);var error:=str(backend.get("failure"));_io.unlock()
	if ticket.is_empty():_publish_result(job.id,{"phase":"retry-begin" if error=="busy" else "failed","reason":error,"us":Time.get_ticks_usec()-began});return
	var resource:=Resource.new();resource.set_meta(METADATA,job.payload)
	var saved:=ResourceSaver.save(resource,str(ticket.path),ResourceSaver.FLAG_COMPRESS)
	if saved!=OK:_cancel(ticket);_publish_result(job.id,{"phase":"failed","reason":"resource-save","us":Time.get_ticks_usec()-began});return
	_commit_worker(job,ticket,began)
func _commit_worker(job: Dictionary,ticket: Dictionary,began: int=0) -> void:
	_thread_stat("write_threads")
	if began==0:began=Time.get_ticks_usec()
	if not current(job.scope):_cancel(ticket);_publish_result(job.id,{"phase":"stale","us":Time.get_ticks_usec()-began});return
	_io.lock();var committed: bool=backend.commit_write(ticket);var error:=str(backend.get("failure"));_io.unlock()
	if not committed and error!="busy":_cancel(ticket)
	_publish_result(job.id,{"phase":"done" if committed else "retry-commit" if error=="busy" else "failed","reason":error,"ticket":ticket,"us":Time.get_ticks_usec()-began})
func _cancel_worker(job: Dictionary,ticket: Dictionary) -> void:
	_cancel(ticket);_publish_result(job.id,{"phase":"stale","us":0})
func poll(maximum: int=2,budget_ms: float=0.5) -> bool:
	if OS.get_thread_caller_id()!=OS.get_main_thread_id():return false
	var began:=Time.get_ticks_usec();var finished:=0
	_gate.lock();var ids:=_jobs.keys();_gate.unlock()
	for id in ids:
		if finished>=maxi(0,maximum) or finished>0 and (Time.get_ticks_usec()-began)/1000.0>=budget_ms:break
		_gate.lock();var job: Dictionary=_jobs.get(id,{});var task: int=int(job.get("task",-1));_gate.unlock()
		if task<0 or not WorkerThreadPool.is_task_completed(task):continue
		WorkerThreadPool.wait_for_task_completion(task)
		_gate.lock();var result: Dictionary=_results.get(id,{"phase":"failed"});_results.erase(id);_stats.write_worker_us+=int(result.get("us",0))
		var phase:=str(result.phase)
		if phase in ["retry-begin","retry-commit"]:
			job.attempts+=1;_stats.write_retries+=1
			if not _current_unlocked(job.scope) or int(job.attempts)>int(limits.commit_retries):
				if phase=="retry-commit":job.task=WorkerThreadPool.add_task(_cancel_worker.bind(job.duplicate(),result.ticket),false,"Cancel retired native model bundle")
				else:_resident_bytes-=int(job.bytes);_jobs.erase(id);_stats.stale_writes+=1
			elif phase=="retry-commit":job.task=WorkerThreadPool.add_task(_commit_worker.bind(job.duplicate(),result.ticket),false,"Publish native model bundle")
			else:job.task=WorkerThreadPool.add_task(_save_worker.bind(job.duplicate()),false,"Retry native model bundle")
		else:
			_resident_bytes-=int(job.bytes);_jobs.erase(id)
			if phase=="done":_stats.writes_completed+=1
			elif phase=="stale":_stats.stale_writes+=1
			else:_stats.writes_failed+=1;failure=str(result.get("reason","worker-result"))
		finished+=1;_gate.unlock()
	_gate.lock();_stats.poll_us+=Time.get_ticks_usec()-began
	if _closing:_closed=_jobs.is_empty() and _active_reads==0
	var idle:=_jobs.is_empty() and _active_reads==0;_gate.unlock();return idle
func worker_tasks() -> Array:
	_gate.lock();var result: Array=[]
	for job in _jobs.values():
		if int(job.get("task",-1))>=0:result.append(int(job.task))
	_gate.unlock();return result
func close() -> bool:
	_gate.lock()
	if not _closing:
		_closing=true;_epoch+=1;_scopes.clear()
		for id in _captures.keys():_discard_capture_unlocked(id)
	_gate.unlock();poll();_gate.lock();var result:=_closed;_gate.unlock();return result
func snapshot() -> Dictionary:
	# Deliberately no backend.snapshot(): that method inspects staged files.
	_gate.lock();var result:={"revision":REVISION,"configured":backend!=null,"closing":_closing,"closed":_closed,"scopes":_scopes.size(),"captures":_captures.size(),"pending_writes":_jobs.size(),"active_reads":_active_reads,"resident_bytes":_resident_bytes,"limits":limits.duplicate(),"stats":_stats.duplicate(true),"read_phases_us":_read_phases.duplicate(),"failure":failure,"scope":"Complete-model draw-only prototype; no live runtime integration or FPS acceptance"};_gate.unlock();return result
