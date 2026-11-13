extends SceneTree
const Cache=preload("res://systems/native_render/native_draw_bundle_cache.gd")
const Store=preload("res://systems/native_data/prepared_resource_store.gd")
const Codec=preload("res://systems/native_render/native_mesh_resource_cache.gd")
class ObservedStore:
	extends RefCounted
	var inner
	var failure:=""
	var threads: Array=[]
	var gate:=Mutex.new()
	var hold_read:=false
	var read_started:=Semaphore.new()
	var read_resume:=Semaphore.new()
	var busy_commits:=0
	var acquisitions:=0
	var releases:=0
	var commits:=0
	func note() -> void:
		gate.lock();threads.append(OS.get_thread_caller_id());gate.unlock()
	func acquire_read(key: String) -> Dictionary:
		note()
		if hold_read:read_started.post();read_resume.wait()
		acquisitions+=1;var value: Dictionary=inner.acquire_read(key);failure=inner.failure;return value
	func release_read(ticket: Dictionary) -> void:
		note();inner.release_read(ticket);failure=inner.failure;releases+=1
	func begin_write(key: String) -> Dictionary:
		note();var value: Dictionary=inner.begin_write(key);failure=inner.failure;return value
	func commit_write(ticket: Dictionary) -> bool:
		note();commits+=1
		if busy_commits>0:busy_commits-=1;failure="busy";return false
		var value: bool=inner.commit_write(ticket);failure=inner.failure;return value
	func cancel_write(ticket: Dictionary) -> void:note();inner.cancel_write(ticket);failure=inner.failure
	func invalidate(key: String) -> bool:
		note();var result: bool=inner.invalidate(key);failure=inner.failure;return result
class ScriptedMesh:
	extends ArrayMesh
	var marker:=99
var args: Dictionary={}
var checks:=0
var failures: Array=[]
var outputs: Dictionary={}
var observations: Array=[]
var gate:=Mutex.new()
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label);print("FAIL ",label)
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--") and "=" in arg:var parts:=arg.substr(2).split("=",true,1);args[parts[0]]=parts[1]
	call_deferred("run")
func source_mesh() -> ArrayMesh:
	var mesh:=ScriptedMesh.new();var arrays: Array=[];arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=PackedVector3Array([Vector3.ZERO,Vector3.RIGHT,Vector3.FORWARD]);arrays[Mesh.ARRAY_NORMAL]=PackedVector3Array([Vector3.UP,Vector3.UP,Vector3.UP]);arrays[Mesh.ARRAY_INDEX]=PackedInt32Array([0,2,1]);mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	mesh.surface_set_material(0,StandardMaterial3D.new());mesh.set_meta("original_pick",{"token":45});return mesh
func _read(cache,descriptor: Dictionary,scope: Dictionary,name: String,estimate: int=1024) -> void:
	var result: Dictionary=cache.load_bundle(descriptor,scope,estimate);gate.lock();outputs[name]=result;gate.unlock()
func read(cache,descriptor: Dictionary,scope: Dictionary,name: String,estimate: int=1024) -> Dictionary:
	var task:=WorkerThreadPool.add_task(_read.bind(cache,descriptor,scope,name,estimate),false,"Test grouped draw worker read")
	var deadline:=Time.get_ticks_msec()+5000
	while not WorkerThreadPool.is_task_completed(task) and Time.get_ticks_msec()<deadline:await process_frame;OS.delay_msec(1)
	check(WorkerThreadPool.is_task_completed(task),"Read worker completes: "+name)
	if not WorkerThreadPool.is_task_completed(task):return {}
	WorkerThreadPool.wait_for_task_completion(task);gate.lock();var result: Dictionary=outputs.get(name,{});outputs.erase(name);gate.unlock();observations.append({"name":name,"state":result.get("state"),"reason":result.get("reason"),"entries":result.get("entries",{}).size()});return result
func drain(cache) -> bool:
	var deadline:=Time.get_ticks_msec()+5000
	while Time.get_ticks_msec()<deadline:
		if cache.poll() and cache.worker_tasks().is_empty():return true
		await process_frame;OS.delay_msec(1)
	return false
func fixture(cache,key: String,payload: Variant) -> bool:
	var ticket: Dictionary=cache.backend.inner.begin_write(key)
	if ticket.is_empty():return false
	var resource:=Resource.new();resource.set_meta(Cache.METADATA,payload)
	return ResourceSaver.save(resource,str(ticket.path),ResourceSaver.FLAG_COMPRESS)==OK and cache.backend.inner.commit_write(ticket)
func run() -> void:
	var root: String=str(args.get("root",""));var report: String=str(args.get("report",""));var fingerprint: String=str(args.get("engine-sha",""))
	if root.is_empty() or report.is_empty() or FileAccess.file_exists(report):quit(2);return
	var store:=Store.new();check(store.configure(root),"Real bounded store configures")
	check(store.snapshot().budget_bytes==25*1024*1024*1024,"Default backend budget is25GiB without allocation")
	var observed:=ObservedStore.new();observed.inner=store
	var cache:=Cache.new();check(cache.configure(observed,fingerprint,{"minimum_draw_bytes":0}),"Facade configures without disk work")
	var scope: Dictionary=cache.new_scope();var source_sha:="1".repeat(64)
	var descriptor: Dictionary=cache.descriptor(source_sha,[[4,true],[1,false]],"test-converter",{"compress":false},["2".repeat(64)])
	check(not descriptor.is_empty() and descriptor.cohort==[[1,false],[4,true]],"Complete node/rigid cohort is canonical")
	check(Cache.valid_descriptor(descriptor,fingerprint),"Descriptor verifies exact current version and build fingerprint")
	check(not Cache.descriptor_for(source_sha,[[1,false]],"unknown").has("key"),"Unknown engine executable fingerprint is explicit unavailable")
	check(cache.descriptor(source_sha,[[1,false],[1,false]]).is_empty(),"Duplicate slots cannot poison whole-model identity")
	check(cache.descriptor(source_sha,[[1,0]]).is_empty(),"Rigid role is an exact boolean")
	check(descriptor.key!=cache.descriptor(source_sha,[[1,false],[4,false]],"test-converter",{"compress":false},["2".repeat(64)]).key,"Rigid role changes key")
	check(descriptor.key!=cache.descriptor(source_sha,[[1,false]],"test-converter",{"compress":false},["2".repeat(64)]).key,"Complete cohort changes key")
	check(descriptor.key!=cache.descriptor(source_sha,[[1,false],[4,true]],"other-converter",{"compress":false},["2".repeat(64)]).key,"Converter revision changes key")
	check(descriptor.key!=Cache.descriptor_for(source_sha,[[1,false],[4,true]],"a".repeat(64),"test-converter",{"compress":false},["2".repeat(64)]).key,"Exact engine executable changes key even with identical Engine.hash")
	check(cache.load_bundle(descriptor,scope,1024).reason=="worker-required" and observed.threads.is_empty(),"Main-thread read is refused before filesystem access")
	var missing:=await read(cache,descriptor,scope,"missing");check(missing.state=="missing" and missing.entries.is_empty(),"Missing bundle is explicit fallback")
	var mesh:=source_mesh();var material:=mesh.surface_get_material(0);var script: Script=mesh.get_script();var original: Variant=mesh.get_meta("original_pick")
	var ticket: Dictionary=cache.begin_capture(descriptor,scope)
	check(not ticket.is_empty(),"Main begins a complete model capture without disk calls")
	check(cache.capture_mesh(ticket,1,false,mesh)=="collecting" and cache.worker_tasks().is_empty(),"Incomplete model never writes a partial artifact")
	check(cache.capture_mesh(ticket,1,false,mesh)=="duplicate-slot","Duplicate admission does not complete a cohort")
	check(cache.capture_mesh(ticket,4,false,mesh)=="unexpected-slot","Wrong rigid role cannot fill the expected slot")
	var copied:=ticket.duplicate(true);copied.scope.nonce="invalid";check(not cache.cancel_capture(copied),"Mutated capture ticket cannot cancel a live cohort")
	observed.busy_commits=1
	check(cache.capture_mesh(ticket,4,true,mesh)=="queued","Last distinct slot queues one model artifact")
	check(await drain(cache),"Single grouped compressed save and nonblocking commit retry drain")
	check(cache.snapshot().stats.writes_completed==1 and cache.snapshot().stats.write_retries==1 and observed.commits==2,"Busy commit reuses the exact staged artifact")
	check(store.snapshot().committed_entries==1 and store.snapshot().active_reads==0,"Only one complete model artifact is committed")
	check(mesh.get_script()==script and mesh.surface_get_material(0)==material and mesh.get_meta("original_pick")==original,"Draw snapshot leaves live script/material/pick ownership intact")
	var before_acquires:=observed.acquisitions
	var loaded:=await read(cache,descriptor,scope,"hit")
	check(loaded.state=="hit" and loaded.entries.size()==2 and observed.acquisitions==before_acquires+1,"One worker lease loads every model slot")
	var buffers:=Cache.buffers_for(loaded,1,false)
	check(Codec.valid_buffers(buffers) and not buffers.surfaces[0].has("material"),"Worker returns only clean packed native draw buffers")
	check(Cache.buffers_for(loaded,4,false).is_empty(),"Missing rigid variant remains explicitly unavailable")
	var first_surface: Dictionary=buffers.surfaces[0];first_surface.vertex_data[0]^=1
	check(first_surface!=loaded.entries["1:draw"].buffers.surfaces[0],"Per-consumer buffer view is detached")
	loaded.entries.clear();var reloaded:=await read(cache,descriptor,scope,"mutation-isolation")
	check(reloaded.state=="hit" and reloaded.entries.size()==2,"Consumer mutation cannot alter immutable artifact")
	check(store.snapshot().active_reads==0 and observed.acquisitions-1==observed.releases,"Every acquired non-missing worker lease is released")
	var bad:=cache.descriptor("3".repeat(64),[[1,false]])
	check(fixture(cache,bad.key,{"revision":Cache.REVISION,"descriptor":bad,"entries":{}}),"Authored valid-resource malformed-cohort fixture publishes")
	var rejected:=await read(cache,bad,scope,"bad-cohort")
	check(rejected.state=="rejected" and rejected.entries.is_empty() and store.snapshot().active_reads==0,"Partial/corrupt cohort falls back without publishing geometry or leaking lease")
	check(store.lookup(bad.key).is_empty() and cache.snapshot().stats.invalidations==1,"Rejected derivative cannot poison all future same-key complete writes")
	var repaired_ticket: Dictionary=cache.begin_capture(bad,scope)
	check(cache.capture_mesh(repaired_ticket,1,false,mesh)=="queued" and await drain(cache),"Original complete cohort repairs the rejected key")
	check((await read(cache,bad,scope,"repaired")).state=="hit","Repaired same-key artifact can be consumed normally")
	var default_cache:=Cache.new();check(default_cache.configure(observed,fingerprint),"Normal conservative threshold configures")
	var other_scope: Dictionary=default_cache.new_scope();var tiny: Dictionary=default_cache.descriptor(source_sha,[[1,false]])
	before_acquires=observed.acquisitions;var bypass:=await read(default_cache,tiny,other_scope,"tiny",100)
	check(bypass.state=="bypassed" and observed.acquisitions==before_acquires,"Tiny model bypass occurs before filesystem lease work")
	var bounded:=Cache.new();check(bounded.configure(observed,fingerprint,{"minimum_draw_bytes":0,"captures":1,"writes":1,"reads":1,"scopes":1}),"Explicit small scheduling limits configure")
	var bounded_scope: Dictionary=bounded.new_scope();check(not bounded_scope.is_empty() and bounded.new_scope().is_empty(),"Scope capacity is enforced")
	var bounded_descriptor: Dictionary=bounded.descriptor(source_sha,[[1,false]])
	var bounded_ticket: Dictionary=bounded.begin_capture(bounded_descriptor,bounded_scope)
	check(not bounded_ticket.is_empty() and bounded.begin_capture(bounded_descriptor,bounded_scope).is_empty(),"Partial capture capacity is enforced")
	check(bounded.cancel_capture(bounded_ticket) and bounded.snapshot().resident_bytes==0,"Cancelling a partial capture releases its complete accounting")
	bounded_ticket=bounded.begin_capture(bounded_descriptor,bounded_scope)
	check(bounded.capture_mesh(bounded_ticket,1,false,mesh)=="queued" and bounded.begin_capture(bounded_descriptor,bounded_scope).is_empty(),"Writer capacity rejects another cohort while one task is owned")
	check(await drain(bounded),"Bounded write drains")
	observed.hold_read=true
	var bounded_task:=WorkerThreadPool.add_task(_read.bind(bounded,bounded_descriptor,bounded_scope,"bounded-held",1024),false,"Bounded read fixture")
	var bounded_deadline:=Time.get_ticks_msec()+5000
	while not observed.read_started.try_wait() and Time.get_ticks_msec()<bounded_deadline:await process_frame;OS.delay_msec(1)
	before_acquires=observed.acquisitions
	check((await read(bounded,bounded_descriptor,bounded_scope,"read-capacity")).state=="capacity" and observed.acquisitions==before_acquires,"Concurrent read capacity returns before starting another lease or OS thread")
	observed.read_resume.post();observed.hold_read=false
	while not WorkerThreadPool.is_task_completed(bounded_task) and Time.get_ticks_msec()<bounded_deadline:await process_frame;OS.delay_msec(1)
	check(WorkerThreadPool.is_task_completed(bounded_task),"Held capacity fixture finishes")
	if WorkerThreadPool.is_task_completed(bounded_task):WorkerThreadPool.wait_for_task_completion(bounded_task)
	check(bounded.close() and bounded.snapshot().resident_bytes==0,"Bounded facade closes without retained captures/tasks")
	var no_memory:=Cache.new();check(no_memory.configure(observed,fingerprint,{"minimum_draw_bytes":0,"bundle_bytes":1,"resident_bytes":1}),"Tiny explicit byte budget configures")
	var no_memory_scope: Dictionary=no_memory.new_scope();var no_memory_descriptor: Dictionary=no_memory.descriptor(source_sha,[[1,false]])
	check(no_memory.begin_capture(no_memory_descriptor,no_memory_scope).is_empty() and no_memory.snapshot().resident_bytes==0,"Descriptor alone cannot exceed a byte budget")
	check(no_memory.close(),"Byte-limited owner closes cleanly")
	var partial: Dictionary=cache.begin_capture(descriptor,scope);check(cache.capture_mesh(partial,1,false,mesh)=="collecting","Second incomplete cohort is resident only")
	check(cache.retire_scope(scope) and not cache.current(scope) and cache.snapshot().captures==0,"Retirement discards incomplete captures without saving")
	var scope2: Dictionary=cache.new_scope();check(scope2!=scope and cache.begin_capture(descriptor,scope).is_empty(),"Retired scope cannot resolve after new ownership")
	observed.hold_read=true
	var task:=WorkerThreadPool.add_task(_read.bind(cache,descriptor,scope2,"stale-worker",1024),false,"Blocked fixture read")
	var deadline:=Time.get_ticks_msec()+5000
	while not observed.read_started.try_wait() and Time.get_ticks_msec()<deadline:await process_frame;OS.delay_msec(1)
	check(cache.snapshot().active_reads==1 and not cache.close(),"Close preserves ownership of an active external AssetService worker")
	observed.read_resume.post()
	while not WorkerThreadPool.is_task_completed(task) and Time.get_ticks_msec()<deadline:await process_frame;OS.delay_msec(1)
	check(WorkerThreadPool.is_task_completed(task),"Retired read worker finishes")
	if WorkerThreadPool.is_task_completed(task):WorkerThreadPool.wait_for_task_completion(task)
	gate.lock();var stale: Dictionary=outputs.get("stale-worker",{});gate.unlock()
	check(stale.get("state")=="retired" and stale.get("entries",{}).is_empty(),"Retired worker drops its loaded POD instead of publishing to a new scope")
	check(cache.close() and cache.worker_tasks().is_empty() and cache.snapshot().resident_bytes==0,"Facade closes only after asynchronous ownership drains")
	check(store.snapshot().active_reads==0 and store.snapshot().pending_writes==0,"Close leaves no backend lease or staged ticket")
	check(observed.threads.all(func(id):return id!=OS.get_main_thread_id()),"Every facade backend operation actually ran on a worker")
	var view: Dictionary=cache.snapshot();view.stats.hits=-99;check(cache.snapshot().stats.hits>=2,"Diagnostic snapshot is detached and does not query the backend")
	check(default_cache.close() and store.close(),"Shared logical facade and dedicated backend close cleanly")
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"snapshot":cache.snapshot(),"observations":observations,"acquires":observed.acquisitions,"releases":observed.releases,"scope":"Isolated native grouped draw cache correctness. Tiny authored meshes and real bounded store; no server, production integration, GPU visual or FPS claim."}
	var file:=FileAccess.open(report,FileAccess.WRITE);file.store_string(JSON.stringify(result,"\t"));file.close();print("DRAW_BUNDLE_CACHE ",checks," checks ",failures.size()," failures");quit(0 if failures.is_empty() else 1)
