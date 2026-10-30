extends SceneTree
const Cache=preload("res://systems/native_data/prepared_cache.gd")
class Probe:
	extends Cache
	var entered:=Semaphore.new()
	func publish_locked(temporary: String,path: String,identity: String,source_sha: String,decoder: String,global_gate: bool) -> bool:
		entered.post(); return super.publish_locked(temporary,path,identity,source_sha,decoder,global_gate)
class Hold:
	extends Probe
	var release:=Semaphore.new()
	func publish_locked(temporary: String,path: String,identity: String,source_sha: String,decoder: String,global_gate: bool) -> bool:
		entered.post(); release.wait(); return super.publish_locked(temporary,path,identity,source_sha,decoder,global_gate)
var checks:=0
var failures: Array=[]
var mutex:=Mutex.new()
var results: Dictionary={}
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label); print("FAIL: ",label)
func _initialize() -> void: call_deferred("run")
func work(cache,key: String,sha: String,value: Dictionary,label: String) -> void:
	var ok: bool=cache.save_data(key,sha,"authored-path",value)
	mutex.lock(); results[label]={"success":ok,"error":cache.failure,"thread":OS.get_thread_caller_id()}; mutex.unlock()
func ready(label: String) -> bool:
	mutex.lock(); var found:=results.has(label); mutex.unlock(); return found
func run() -> void:
	var report:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): report=arg.substr(9)
	if report.is_empty() or FileAccess.file_exists(report): quit(2); return
	var directory:=OS.get_environment("TEMP").path_join("nwn-native-cache-paths-"+str(OS.get_process_id())+"-"+str(Time.get_ticks_usec()))
	var first:=Hold.new(); var same:=Probe.new(); var unrelated:=Probe.new()
	check(first.configure(directory) and same.configure(directory) and unrelated.configure(directory),"All cache operations use an owned private directory")
	for cache in [first,same,unrelated]: cache.path_publication=true
	var a:={"position":PackedFloat64Array([1.0,-0.0,1.000000000000001])}; var b:={"position":PackedFloat64Array([2.0,3.0,4.0])}
	var sha_a:=Cache.digest(var_to_bytes(a)); var sha_b:=Cache.digest(var_to_bytes(b)); var key_a:=Cache.key(sha_a,"authored-path"); var key_b:=Cache.key(sha_b,"authored-path")
	var t1:=Thread.new(); check(t1.start(work.bind(first,key_a,sha_a,a,"first"))==OK,"First native writer starts")
	var deadline:=Time.get_ticks_msec()+5000; var held:=false
	while not held and Time.get_ticks_msec()<deadline:
		held=first.entered.try_wait()
		if not held: await process_frame
	check(held and not FileAccess.file_exists(first.filename(key_a)),"First path is held before atomic destination publication")
	var t2:=Thread.new(); var t3:=Thread.new()
	check(t2.start(work.bind(same,key_a,sha_a,a,"same"))==OK and t3.start(work.bind(unrelated,key_b,sha_b,b,"unrelated"))==OK,"Same-path waiter and independent destination writers start")
	deadline=Time.get_ticks_msec()+5000; var two_users:=false
	while Time.get_ticks_msec()<deadline and (not ready("unrelated") or not two_users):
		Cache.publication_mutex.lock(); two_users=Cache.path_publications.has(first.filename(key_a)) and int(Cache.path_publications[first.filename(key_a)].users)==2; Cache.publication_mutex.unlock()
		await process_frame
	check(ready("unrelated") and not ready("first") and not ready("same"),"Unrelated file finishes while the original path and its waiter remain held")
	check(two_users and not same.entered.try_wait(),"Same destination shares one refcounted gate and cannot enter repair/rename concurrently")
	check(Cache.digest(var_to_bytes(unrelated.load_data(key_b,sha_b,"authored-path")))==sha_b,"Independent committed payload is fully checksummed and byte-exact before first-path release")
	first.release.post(); t1.wait_to_finish(); t2.wait_to_finish(); t3.wait_to_finish()
	check(results.size()==3 and results.values().all(func(row):return row.success and row.error.is_empty() and row.thread!=OS.get_main_thread_id()),"All real native writers finish successfully outside presentation")
	check(Cache.digest(var_to_bytes(same.load_data(key_a,sha_a,"authored-path")))==sha_a,"Serialized same-key publication preserves exact typed payload")
	Cache.publication_mutex.lock(); var drained:=Cache.path_publications.is_empty(); Cache.publication_mutex.unlock()
	check(drained,"Per-path lease metadata is removed after all waiters release")
	var path:=first.filename(key_a); var bytes:=FileAccess.get_file_as_bytes(path); bytes[bytes.size()-1]^=1
	var bad:=FileAccess.open(path,FileAccess.WRITE); bad.store_buffer(bytes); bad.close()
	check(same.load_data(key_a,sha_a,"authored-path").is_empty(),"Same-length corruption is rejected even after an earlier verified publication")
	check(same.save_data(key_a,sha_a,"authored-path",a) and Cache.digest(var_to_bytes(same.load_data(key_a,sha_a,"authored-path")))==sha_a,"Path-scoped repair restores a corrupted entry and verified source identity")
	var files:=DirAccess.get_files_at(directory); var clean:=files.size()==2
	for name in files:
		clean=clean and str(name).ends_with(".bin"); DirAccess.remove_absolute(directory.path_join(name))
	check(clean and DirAccess.remove_absolute(directory)==OK,"Both destinations commit atomically without orphan temporary files; owned fixture is cleaned")
	var file:=FileAccess.open(report,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"threads":results,"public_connections":0,"scope":"Actual native threads with one path held, same-path exclusion/refcounted waiters, unrelated-path progress, byte-exact typed caches, same-length corruption/repair and clean lease/temp shutdown. Not IO throughput/FPS or external-writer full filesystem atomicity acceptance."},"\t")); file.close(); print("NATIVE_CACHE_PUBLICATION_PATHS ",checks," checks"); quit(0 if failures.is_empty() else 1)
