extends RefCounted
# Optional process-owned cache front end. Asset workers do all filesystem work;
# the resource pool still owns live meshes, picking, collision and materials.
const Store=preload("res://systems/native_data/prepared_resource_store.gd")
const Bundles=preload("res://systems/native_render/native_draw_bundle_cache.gd")
const MeshPreparation=preload("res://systems/native_data/mesh_preparation.gd")
const Drain=preload("res://systems/native_render/native_draw_cache_drain.gd")
const REVISION:="native-draw-runtime-static-v1"
static var _gate:=Mutex.new()
static var _initialization:=Mutex.new() # Workers only; never acquired by presentation.
static var _users:=0
static var _owners: Dictionary={}
static var _fingerprint:=""
static var _polled_frame:=-1
static var _retired: Array=[]
static var _driver: Node
static var _stopping:=false
static var _overlap_reads:=0

static func enabled() -> bool:
	return OS.get_cmdline_user_args().has("--native-draw-cache=prepared")
static func budget_bytes() -> int:
	var gib:=25
	for arg in OS.get_cmdline_user_args():
		if not arg.begins_with("--native-draw-cache-gib="):continue
		var raw:=arg.trim_prefix("--native-draw-cache-gib=")
		if raw.is_valid_int():gib=clampi(raw.to_int(),25,1024)
	return gib*1024*1024*1024
static func acquire() -> void:
	if not enabled():return
	_gate.lock();_users+=1;_gate.unlock()
	if OS.get_thread_caller_id()==OS.get_main_thread_id() and not is_instance_valid(_driver) and Engine.get_main_loop() is SceneTree and not _stopping:
		var driver:=Drain.new();driver.name="NativeDrawCacheRetirement";driver.process_mode=Node.PROCESS_MODE_ALWAYS;driver.tick=poll;driver.stopping=driver_stopping
		_driver=driver;Engine.get_main_loop().root.add_child(driver)
static func _owner_on_worker(root: String) -> Dictionary:
	if OS.get_thread_caller_id()==OS.get_main_thread_id() or root.is_empty():return {}
	_gate.lock()
	if _users<=0 or _retired.size()>=4:_gate.unlock();return {}
	if _owners.has(root):
		var existing: Dictionary=_owners[root];_gate.unlock();return existing
	_gate.unlock()
	_initialization.lock()
	_gate.lock()
	if _owners.has(root):
		var existing: Dictionary=_owners[root];_gate.unlock();_initialization.unlock();return existing
	if _owners.size()>=4:_gate.unlock();_initialization.unlock();return {}
	_gate.unlock()
	# Once per process, not once per mesh. Custom engines report hash="unknown".
	# No presentation-facing lock spans hashing, directory/index recovery or IO.
	if _fingerprint.is_empty():_fingerprint=FileAccess.get_sha256(OS.get_executable_path())
	var store:=Store.new();var owner: Dictionary={}
	if store.configure(root,budget_bytes()):
		var facade:=Bundles.new()
		if facade.configure(store,_fingerprint):
			var scope: Dictionary=facade.new_scope()
			if not scope.is_empty():owner={"facade":facade,"store":store,"scope":scope}
	_gate.lock();_owners[root]=owner;_gate.unlock();_initialization.unlock();return owner
static func _resident_owner(root: String) -> Dictionary:
	_gate.lock();var result: Dictionary=_owners.get(root,{});_gate.unlock();return result

static func _cohort(model: Dictionary) -> Dictionary:
	var slots: Array=[];var estimate:=0
	for index in model.get("nodes",[]).size():
		var node: Dictionary=model.nodes[index];var mesh: Dictionary=node.get("mesh",{})
		if not mesh.get("render",false) or mesh.get("indices",PackedInt32Array()).is_empty():continue
		if node.has("skin") or node.get("features",[]).any(func(feature):return feature in ["skin","animated-mesh","dangly"]):continue
		var vertices: PackedFloat32Array=mesh.get("vertices",PackedFloat32Array())
		if vertices.is_empty():continue
		slots.append([index,false]);estimate+=vertices.size()/3*(48 if not mesh.get("vertex_colors",PackedByteArray()).is_empty() else 32)+mesh.indices.size()*4
	return {"slots":slots,"estimated_bytes":estimate}

static func begin_on_worker(job: Dictionary,result: Dictionary) -> void:
	if not enabled() or job.get("status_only",false) or job.get("decoder")!="static-model" or not str(result.get("error","")).is_empty() or not result.get("value") is Dictionary:return
	if job.has("native_draw_read"):return
	var cohort:=_cohort(result.value)
	if cohort.slots.is_empty() or int(cohort.estimated_bytes)<int(Bundles.DEFAULT_LIMITS.minimum_draw_bytes):return
	_gate.lock()
	if _overlap_reads>=8:_gate.unlock();return
	_overlap_reads+=1;_gate.unlock()
	var thread:=Thread.new();var began:=Time.get_ticks_usec()
	var input:={"source_sha":str(result.get("sha256","")),"root":str(job.get("cache_directory","")),"slots":cohort.slots,"estimated_bytes":cohort.estimated_bytes}
	if thread.start(load_on_thread.bind(input))!=OK:
		_gate.lock();_overlap_reads-=1;_gate.unlock();return
	job.native_draw_read={"thread":thread,"started_us":began,"source_sha":input.source_sha}
static func load_on_thread(input: Dictionary) -> Dictionary:
	var began:=Time.get_ticks_usec();var root: String=input.root
	var owner:=_owner_on_worker(root)
	if owner.is_empty():return {}
	var facade=owner.facade
	var descriptor: Dictionary=facade.descriptor(input.source_sha,input.slots,MeshPreparation.REVISION,{"runtime":REVISION,"mesh_worker":MeshPreparation.configured_enabled()})
	if descriptor.is_empty():return {}
	var loaded: Dictionary=facade.load_bundle(descriptor,owner.scope,int(input.estimated_bytes))
	return {"root":root,"descriptor":descriptor,"loaded":loaded,"estimated_bytes":input.estimated_bytes,"total_us":Time.get_ticks_usec()-began}
static func attach_on_worker(job: Dictionary,result: Dictionary) -> void:
	if not job.has("native_draw_read"):begin_on_worker(job,result)
	if not job.has("native_draw_read"):return
	# Always join this owned read, even when a later texture/prework step failed.
	# The main thread owns only the enclosing AssetService task, never this wait.
	var pending: Dictionary=job.native_draw_read;var began:=Time.get_ticks_usec()
	var packet: Variant=pending.thread.wait_to_finish();var wait_us:=Time.get_ticks_usec()-began
	job.erase("native_draw_read");_gate.lock();_overlap_reads-=1;_gate.unlock()
	if not packet is Dictionary or packet.is_empty() or str(result.get("sha256",""))!=str(pending.source_sha) or not str(result.get("error","")).is_empty():return
	var descriptor: Dictionary=packet.descriptor;var loaded: Dictionary=packet.loaded;var cohort:=_cohort(result.value)
	if descriptor.cohort!=cohort.slots:return
	result.native_draw_cache={"root":packet.root,"descriptor":descriptor,"state":loaded.get("state","unavailable"),"estimated_bytes":packet.estimated_bytes}
	var phases: Dictionary=result.get("phases",{}).duplicate()
	phases.native_draw_cache={"state":loaded.get("state","unavailable"),"reason":loaded.get("reason",""),"worker_us":loaded.get("worker_us",0),"phases_us":loaded.get("phases_us",{}),"read_total_us":packet.total_us,"remaining_wait_us":wait_us,"overlapped_us":maxi(0,int(packet.total_us)-wait_us),"estimated_bytes":cohort.estimated_bytes,"slots":cohort.slots.size()};result.phases=phases
	if loaded.get("state")!="hit":return
	# Never add runtime bindings to decoded/prework/memory-store-owned graphs.
	var model: Dictionary=result.value.duplicate();var nodes: Array=model.nodes.duplicate();model.nodes=nodes
	for slot in cohort.slots:
		var buffers: Dictionary=Bundles.buffers_for(loaded,int(slot[0]),false)
		if buffers.is_empty():continue
		var row: Dictionary=nodes[slot[0]].duplicate();var mesh: Dictionary=row.mesh.duplicate()
		mesh.native_draw_buffers=buffers;row.mesh=mesh;nodes[slot[0]]=row
	result.value=model

static func begin_model(bundle: Dictionary) -> Dictionary:
	if not enabled():return {}
	var hint: Dictionary=bundle.get("native_draw_cache",{})
	if hint.is_empty() or hint.get("state") in ["hit","bypassed","retired","unavailable","capacity"]:return {}
	var owner:=_resident_owner(str(hint.get("root","")))
	if owner.is_empty():return {}
	var ticket: Dictionary=owner.facade.begin_capture(hint.get("descriptor",{}),owner.scope)
	return {"facade":owner.facade,"ticket":ticket,"source":str(bundle.get("sha256","")),"cohort":hint.descriptor.cohort} if not ticket.is_empty() else {}
static func capture(context: Dictionary,source: String,index: int,rigid: bool,mesh: ArrayMesh) -> void:
	if context.is_empty() or context.source!=source or not context.cohort.has([index,rigid]):return
	context.facade.capture_mesh(context.ticket,index,rigid,mesh)
static func end_model(context: Dictionary) -> void:
	if not context.is_empty():context.facade.cancel_capture(context.ticket)
static func poll() -> void:
	if not enabled() or OS.get_thread_caller_id()!=OS.get_main_thread_id():return
	var frame:=int(Engine.get_process_frames())
	if frame==_polled_frame:return
	_polled_frame=frame
	_gate.lock();var owners:=_owners.values();_gate.unlock()
	for owner in owners:
		if not owner.is_empty():owner.facade.poll()
	_drain_retired(false)
static func worker_tasks() -> Array:
	_gate.lock();var owners:=_owners.values();owners.append_array(_retired);_gate.unlock();var result: Array=[]
	for owner in owners:
		if not owner.is_empty():result.append_array(owner.facade.worker_tasks())
	return result
static func release() -> void:
	if not enabled():return
	_gate.lock();_users-=1
	if _users>0:_gate.unlock();return
	assert(_users==0,"Native draw-cache owner lease underflow")
	var owners:=_owners.values();_owners={};_gate.unlock()
	# Asset reads already joined. Retire optional writes asynchronously, rather
	# than stalling a transition/disconnect on ResourceSaver or publication IO.
	for owner in owners:
		if owner.is_empty():continue
		owner.facade.retire_scope(owner.scope);_gate.lock();_retired.append(owner);_gate.unlock()
	_drain_retired(_stopping or not is_instance_valid(_driver))
static func _drain_retired(wait: bool) -> void:
	for index in range(_retired.size()-1,-1,-1):
		var owner: Dictionary=_retired[index]
		if wait:
			while not owner.facade.close():
				for task in owner.facade.worker_tasks():WorkerThreadPool.wait_for_task_completion(int(task))
				owner.facade.poll()
		if owner.facade.close():
			owner.store.close();_gate.lock();_retired.remove_at(index);_gate.unlock()
static func driver_stopping() -> void:
	# The engine is quitting; exact remaining writer tasks must finish before
	# native ResourceSaver/worker teardown. Active services release afterward.
	_stopping=true;_driver=null;_drain_retired(true)
static func snapshot() -> Dictionary:
	_gate.lock();var owners:=_owners.duplicate();var users:=_users;var retiring:=_retired.size();var overlaps:=_overlap_reads;_gate.unlock();var states: Array=[]
	for root in owners:
		if not owners[root].is_empty():states.append(owners[root].facade.snapshot())
	return {"enabled":enabled(),"revision":REVISION,"budget_bytes":budget_bytes(),"users":users,"owners":states,"retiring_owners":retiring,"pending_overlap_reads":overlaps,"policy":"Optional static model cohorts only; worker disk reads and complete-cohort writes; original collision/materials remain authoritative"}
