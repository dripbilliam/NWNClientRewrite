extends SceneTree
const Cache=preload("res://systems/native_render/native_draw_bundle_cache.gd")
const Store=preload("res://systems/native_data/prepared_resource_store.gd")
var options: Dictionary={}
var output: Dictionary={}
var checks:=0
var failures: Array=[]
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label)
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--") and "=" in arg:var pair:=arg.substr(2).split("=",true,1);options[pair[0]]=pair[1]
	call_deferred("run")
func noop() -> int:return 1
func resource_many(path: String,count: int) -> Dictionary:
	var times: Array=[];var successes:=0
	for index in count:
		var began:=Time.get_ticks_usec();var value: Resource=ResourceLoader.load(path,"Resource",ResourceLoader.CACHE_MODE_IGNORE);times.append(Time.get_ticks_usec()-began)
		if value!=null and value.get_class()=="Resource":successes+=1
	return {"times_us":times,"successes":successes,"thread":OS.get_thread_caller_id()}
func worker(cache,descriptor: Dictionary,scope: Dictionary,path: String,missing_reads: bool=false) -> void:
	var empty: Array=[]
	for index in 30:
		var began:=Time.get_ticks_usec();var thread:=Thread.new()
		if thread.start(noop)==OK:thread.wait_to_finish()
		empty.append(Time.get_ticks_usec()-began)
	var persistent:=Thread.new();var parse: Dictionary={}
	if persistent.start(resource_many.bind(path,16))==OK:parse=persistent.wait_to_finish()
	var full: Array=[];var phases: Array=[];var successes:=0
	for index in 16:
		var wanted: Dictionary=cache.descriptor("%064x"%(index+100),[[0,false]]) if missing_reads else descriptor
		var began:=Time.get_ticks_usec();var value: Dictionary=cache.load_bundle(wanted,scope,1024*1024);full.append(Time.get_ticks_usec()-began)
		phases.append(value.get("phases_us",{}))
		if value.state==("missing" if missing_reads else "hit"):successes+=1
	output={"empty_thread_roundtrip_us":empty,"persistent_plain_thread_resource_load":parse,"full_grouped_facade_us":full,"full_phases_us":phases,"full_hits":successes,"missing_reads":missing_reads,"worker_thread":OS.get_thread_caller_id()}
func summary(values: Array) -> Dictionary:
	var sorted:=values.duplicate();sorted.sort();var total:=0
	for value in sorted:total+=int(value)
	return {"count":sorted.size(),"mean_us":float(total)/maxi(1,sorted.size()),"median_us":sorted[sorted.size()/2] if not sorted.is_empty() else null,"p95_us":sorted[mini(sorted.size()-1,int(ceil(sorted.size()*0.95))-1)] if not sorted.is_empty() else null,"maximum_us":sorted.back() if not sorted.is_empty() else null}
func run() -> void:
	if not options.has("root") or not options.has("report") or FileAccess.file_exists(str(options.report)):quit(2);return
	var store:=Store.new();check(store.configure(str(options.root)),"Store configures")
	var cache:=Cache.new();check(cache.configure(store,str(options.get("engine-sha","")),{"minimum_draw_bytes":0}),"Facade configures")
	var scope: Dictionary=cache.new_scope();var descriptor: Dictionary=cache.descriptor("7".repeat(64),[[0,false]])
	var arrays: Array=[];arrays.resize(Mesh.ARRAY_MAX);var positions:=PackedVector3Array();var normals:=PackedVector3Array();var indices:=PackedInt32Array()
	for triangle in 5000:
		var x:=float(triangle%100);var z:=float(triangle/100)
		positions.append_array(PackedVector3Array([Vector3(x,0,z),Vector3(x+0.75,0,z),Vector3(x,0,z+0.75)]));normals.append_array(PackedVector3Array([Vector3.UP,Vector3.UP,Vector3.UP]));indices.append_array(PackedInt32Array([triangle*3,triangle*3+2,triangle*3+1]))
	arrays[Mesh.ARRAY_VERTEX]=positions;arrays[Mesh.ARRAY_NORMAL]=normals;arrays[Mesh.ARRAY_INDEX]=indices
	var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var ticket: Dictionary=cache.begin_capture(descriptor,scope);check(cache.capture_mesh(ticket,0,false,mesh)=="queued","One authored grouped draw artifact queues")
	var deadline:=Time.get_ticks_msec()+10000
	while not cache.poll() and Time.get_ticks_msec()<deadline:await process_frame;OS.delay_msec(1)
	check(cache.snapshot().stats.writes_completed==1,"Grouped artifact commits")
	var path:=store.lookup(descriptor.key);check(not path.is_empty(),"Artifact exists")
	var bytes:=0
	if not path.is_empty():var file:=FileAccess.open(path,FileAccess.READ);bytes=file.get_length();file.close()
	var task:=WorkerThreadPool.add_task(worker.bind(cache,descriptor,scope,path,options.get("missing","")=="true"),false,"Measure owned plain loader overhead")
	deadline=Time.get_ticks_msec()+10000
	while not WorkerThreadPool.is_task_completed(task) and Time.get_ticks_msec()<deadline:await process_frame;OS.delay_msec(1)
	check(WorkerThreadPool.is_task_completed(task),"Worker comparison completes")
	if WorkerThreadPool.is_task_completed(task):WorkerThreadPool.wait_for_task_completion(task)
	check(output.get("full_hits")==16 and output.get("persistent_plain_thread_resource_load",{}).get("successes")==16,"Every real Resource parse and requested hit/missing outcome succeeds")
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"artifact_bytes":bytes,"triangles":5000,"summary":{"thread_create_join":summary(output.get("empty_thread_roundtrip_us",[])),"resource_parse_on_one_plain_thread":summary(output.get("persistent_plain_thread_resource_load",{}).get("times_us",[])),"lease_thread_load_validate_detached_release":summary(output.get("full_grouped_facade_us",[]))},"raw":output,"facade":cache.snapshot(),"store":store.snapshot(),"scope":"Warm authored one-model CPU/IO microbenchmark only. Thread creation, parsing and full facade are separate paths, not additive GPU/FPS or NWN loading claims."}
	check(cache.close() and store.close(),"All prototype owners close")
	result.success=failures.is_empty();result.checks=checks;result.failures=failures
	var report:=FileAccess.open(str(options.report),FileAccess.WRITE);report.store_string(JSON.stringify(result,"\t"));report.close();print("DRAW_BUNDLE_LOADER_OVERHEAD ",checks," checks ",failures.size()," failures");quit(0 if failures.is_empty() else 1)
