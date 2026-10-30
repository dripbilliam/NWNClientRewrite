extends SceneTree
const Cache=preload("res://systems/native_data/prepared_cache.gd")
const World=preload("res://systems/native_render/live_world.gd")
const Retirement=preload("res://systems/native_render/world_retirement.gd")
class BlockedValidation extends Cache:
	var entered:=Semaphore.new()
	var release:=Semaphore.new()
	var paused:=false
	func load_data(identity: String,source_sha: String,decoder: String) -> Dictionary:
		if not paused:
			paused=true; entered.post()
			var deadline:=Time.get_ticks_msec()+5000
			while not release.try_wait() and Time.get_ticks_msec()<deadline: OS.delay_msec(1)
		return super.load_data(identity,source_sha,decoder)
class Body extends Node3D:
	func retire() -> void: queue_free()
var checks:=0
var failures: Array=[]
var results: Dictionary={}
var result_mutex:=Mutex.new()
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label); print("FAIL: ",label)
func save(cache,key: String,sha: String,label: String) -> void:
	var ok: bool=cache.save_data(key,sha,"authored",{"label":label})
	result_mutex.lock(); results[label]={"ok":ok,"thread":OS.get_thread_caller_id()}; result_mutex.unlock()
func run() -> void:
	var output:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
	if output.is_empty() or FileAccess.file_exists(output): quit(2); return
	var directory:=OS.get_temp_dir().path_join("nwn-cache-contention-"+str(OS.get_process_id())+"-"+str(Time.get_ticks_usec()))
	var a:=BlockedValidation.new(); var b:=Cache.new()
	check(a.configure(directory) and b.configure(directory),"Isolated authored cache fixtures configure outside the project")
	var sha_a:=Cache.digest(PackedByteArray([1])); var sha_b:=Cache.digest(PackedByteArray([2])); var key_a:=Cache.key(sha_a,"authored"); var key_b:=Cache.key(sha_b,"authored")
	check(a.save_data(key_a,sha_a,"authored",{"label":"a"}),"Existing first resource has a complete persistent entry")
	Cache.publication_mutex.lock(); Cache.verified_publications.erase(a.filename(key_a)); Cache.publication_mutex.unlock()
	var task_a:=WorkerThreadPool.add_task(save.bind(a,key_a,sha_a,"a"),false,"Parked original cache validation")
	var deadline:=Time.get_ticks_msec()+10000; var parked:=false
	while not parked and Time.get_ticks_msec()<deadline:
		parked=a.entered.try_wait()
		if not parked: await process_frame
	check(parked and not WorkerThreadPool.is_task_completed(task_a),"A real cache worker is paused inside existing-entry validation")
	var task_b:=WorkerThreadPool.add_task(save.bind(b,key_b,sha_b,"b"),false,"Independent cache publication")
	deadline=Time.get_ticks_msec()+1000
	while not WorkerThreadPool.is_task_completed(task_b) and Time.get_ticks_msec()<deadline: await process_frame
	check(WorkerThreadPool.is_task_completed(task_b) and not WorkerThreadPool.is_task_completed(task_a),"Another resource publishes completely while the first validation is still held; no global decoded-graph serialization")
	a.release.post()
	while not WorkerThreadPool.is_task_completed(task_a) or not WorkerThreadPool.is_task_completed(task_b): await process_frame
	WorkerThreadPool.wait_for_task_completion(task_a); WorkerThreadPool.wait_for_task_completion(task_b)
	check(results.size()==2 and results.values().all(func(value):return value.ok and int(value.thread)!=OS.get_main_thread_id()),"Both real worker publications succeed off the presentation thread")
	check(a.load_data(key_a,sha_a,"authored").label=="a" and b.load_data(key_b,sha_b,"authored").label=="b","The parked validation and independent publication retain exact payload identities")
	for filename in DirAccess.get_files_at(directory):
		check(filename in [key_a+".bin",key_b+".bin"],"Concurrent publication leaves no partial temporary file")
		DirAccess.remove_absolute(directory.path_join(filename))
	DirAccess.remove_absolute(directory)
	var retirement:=Retirement.new(); root.add_child(retirement); retirement.set_process(false)
	var world:=World.new(); root.add_child(world); world.set_process(false)
	for id in 20:
		var body:=Body.new(); world.add_child(body); world.instances[id]=body
	var weak: WeakRef=weakref(world); retirement.retire(world)
	check(world.instances.size()==16,"Actual world retirement releases only four physical owners in its first step")
	retirement.poll(); check(world.instances.size()==12,"A second retirement step makes bounded progress instead of destroying the remaining area at once")
	for _step in 8:
		retirement.poll(); await process_frame
	check(weak.get_ref()==null and retirement.worlds.is_empty(),"Bounded retirement eventually releases the actual world and its callback/resource owners")
	retirement.close(); retirement.free(); await process_frame
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"workers":results,"scope":"Actual independent cache publication while another worker's validation is held; bounded real-world physical-owner retirement. Authored data/no server/GPU performance acceptance."},"\t")); file.close(); print("NATIVE_LOADING_CONTENTION ",checks," checks"); quit(0 if failures.is_empty() else 1)
