extends SceneTree
const Cache = preload("res://systems/native_data/prepared_cache.gd")
var checks := 0
var failures: Array = []
var mutex := Mutex.new()
var worker_results: Array = []
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message)
func concurrent_save(directory: String, identity: String, sha: String, data: Dictionary) -> void:
	var cache := Cache.new(); var ok := cache.configure(directory) and cache.save_data(identity,sha,"authored",data)
	mutex.lock(); worker_results.append({"ok":ok,"thread":OS.get_thread_caller_id(),"error":cache.failure}); mutex.unlock()
func run() -> void:
	var output := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
	if output.is_empty() or FileAccess.file_exists(output): quit(2); return
	var directory := OS.get_temp_dir().path_join("nwn-native-cache-test-"+str(OS.get_process_id())+"-"+str(Time.get_ticks_usec()))
	var cache := Cache.new(); check(cache.configure(directory),"Prepared data cache uses an external runtime directory")
	var source := PackedByteArray([1,2,3,4]); var sha := Cache.digest(source); var identity := Cache.key(sha,"authored")
	var data := {"vertices":PackedFloat32Array([1.25,-2.5,3.75]),"indices":PackedInt32Array([0,2,1]),"pixels":PackedByteArray([0,128,255]),"parts":[{"name":"authored","unsigned64_low":4294967295,"unsigned64_high":4294967295}]}
	check(cache.load_data(identity,sha,"authored").is_empty() and cache.failure.is_empty(),"A cold miss is distinct from corrupt cached data")
	check(cache.save_data(identity,sha,"authored",data),"Native prepared streams are stored without serialized objects")
	var loaded := cache.load_data(identity,sha,"authored")
	check(loaded.vertices is PackedFloat32Array and loaded.vertices.to_byte_array()==data.vertices.to_byte_array() and loaded.indices==data.indices and loaded.pixels==data.pixels,"Native cache preserves exact typed geometry/index/pixel streams")
	check(loaded.parts[0].unsigned64_high==4294967295,"Native cache retains 64-bit word metadata without JSON conversion")
	check(Cache.key(Cache.digest(PackedByteArray([1,2,3,5])),"authored")!=identity and Cache.key(sha,"other-decoder")!=identity,"Actual byte changes and decoder versions produce different content identities")
	check(cache.load_data(identity,sha,"other-decoder").is_empty() and not cache.failure.is_empty(),"A cached payload cannot cross decoder identity")
	var path := cache.filename(identity); var file := FileAccess.open(path,FileAccess.READ_WRITE); file.seek(49); file.store_8(file.get_8() ^ 255); file.close()
	check(cache.load_data(identity,sha,"authored").is_empty() and not cache.failure.is_empty(),"Checksum verification rejects corrupted native payloads before Variant decoding")
	check(cache.save_data(identity,sha,"authored",data) and not cache.load_data(identity,sha,"authored").is_empty(),"A corrupt cache is rebuilt from the original prepared data")
	file=FileAccess.open(path,FileAccess.WRITE); file.store_buffer("NWNC".to_ascii_buffer()); file.close()
	check(cache.load_data(identity,sha,"authored").is_empty() and not cache.failure.is_empty(),"Truncated cache metadata is rejected")
	var tasks: Array = []
	for index in 8: tasks.append(WorkerThreadPool.add_task(concurrent_save.bind(directory,identity,sha,data)))
	# Await completed jobs before joining. A direct wait can execute an
	# unstarted task on the caller, defeating this background-worker probe.
	while tasks.any(func(task): return not WorkerThreadPool.is_task_completed(int(task))): await process_frame
	for task in tasks: WorkerThreadPool.wait_for_task_completion(int(task))
	check(worker_results.size()==8 and worker_results.all(func(row):return row.ok and int(row.thread)!=OS.get_main_thread_id()),"Concurrent native workers publish one content entry safely")
	check(not cache.load_data(identity,sha,"authored").is_empty() and cache.failure.is_empty(),"Concurrent publication leaves a complete verified entry")
	var forbidden := Cache.new(); check(not forbidden.configure("res://reports/native-cache-forbidden"),"Original asset caches cannot be written inside the source workspace")
	check(cache.filename("../escape").is_empty(),"Cache identities cannot escape the configured directory")
	for filename in DirAccess.get_files_at(directory):
		check(filename==identity+".bin","Concurrent cache writers leave no temporary files")
		if filename==identity+".bin": DirAccess.remove_absolute(directory.path_join(filename))
	DirAccess.remove_absolute(directory)
	var report := {"passed":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Authored native persistent-cache integrity/concurrency; no proprietary data or renderer","sourceSha256":FileAccess.get_sha256("res://systems/native_data/prepared_cache.gd")}
	file=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify(report,"\t")); file.close(); quit(0 if failures.is_empty() else 1)
