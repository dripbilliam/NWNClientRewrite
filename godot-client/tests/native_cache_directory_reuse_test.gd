extends SceneTree
const Cache=preload("res://systems/native_data/prepared_cache.gd")
class Observed:
	extends Cache
	var creations:=0
	var deny_creation:=false
	func create_directory(path: String) -> bool:
		creations+=1
		return false if deny_creation else super.create_directory(path)
var checks:=0
var failures: Array=[]
var gate:=Mutex.new()
var results: Array=[]
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label); print("FAIL: ",label)
func _initialize() -> void: call_deferred("run")
func worker(directory: String) -> void:
	var cache:=Observed.new(); var ok:=cache.configure(directory); var initial:=cache.creations
	for iteration in 32: ok=cache.configure(directory) and ok
	gate.lock(); results.append({"ok":ok,"creations":cache.creations,"warm_creations":cache.creations-initial,"thread":OS.get_thread_caller_id()}); gate.unlock()
func run() -> void:
	var output:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
	if output.is_empty() or FileAccess.file_exists(output): quit(2); return
	var base:=OS.get_temp_dir().path_join("nwn-cache-directory-"+str(OS.get_process_id())+"-"+str(Time.get_ticks_usec()))
	var directory:=base.path_join("prepared/deep")
	var cache:=Observed.new()
	check(cache.configure(directory) and cache.creations==1 and DirAccess.dir_exists_absolute(directory),"Cold cache creates its missing ancestors once")
	for iteration in 128: check(cache.configure(directory),"Warm cache configuration succeeds "+str(iteration))
	check(cache.creations==1,"Repeated warm configurations never invoke recursive creation")
	var fresh_creations:=0
	for iteration in 128:
		var fresh:=Observed.new(); check(fresh.configure(directory),"Fresh decoder cache reuses existing directory "+str(iteration)); fresh_creations+=fresh.creations
	check(fresh_creations==0,"Recreated per-resource cache objects also avoid recursive creation")
	check(DirAccess.remove_absolute(directory)==OK and cache.configure(directory) and cache.creations==2,"Reconfiguration detects an externally removed directory")
	var source_sha:=Cache.digest(PackedByteArray([1,2,3])); var identity:=Cache.key(source_sha,"directory-recovery")
	var data:={"vertices":PackedFloat64Array([1.25,-0.0,1.000000000000001]),"pixels":PackedByteArray([0,128,255])}
	check(cache.save_data(identity,source_sha,"directory-recovery",data),"Initial typed payload publishes normally")
	check(DirAccess.remove_absolute(cache.filename(identity))==OK and DirAccess.remove_absolute(directory)==OK,"Owned cache directory is removed after successful configuration")
	check(cache.save_data(identity,source_sha,"directory-recovery",data) and cache.creations==3,"Save recreates a directory removed since configuration and retries once")
	check(Cache.digest(var_to_bytes(cache.load_data(identity,source_sha,"directory-recovery")))==Cache.digest(var_to_bytes(data)),"Recovered publication retains exact typed payload and checksum")
	check(DirAccess.get_files_at(directory)==PackedStringArray([identity+".bin"]),"Recovery leaves only the complete cache entry")
	var blocked_path:=base.path_join("blocked")
	var file:=FileAccess.open(blocked_path,FileAccess.WRITE); file.store_string("owned blocker"); file.close()
	var blocked:=Observed.new()
	check(not blocked.configure(blocked_path) and blocked.directory.is_empty() and not blocked.failure.is_empty(),"A regular file cannot masquerade as a cache directory")
	var forbidden:=Observed.new(); check(forbidden.configure(directory),"Configure-once fixture begins with a usable cache")
	check(not forbidden.configure("res://reports/cache-directory-forbidden") and forbidden.directory.is_empty() and forbidden.filename(identity).is_empty(),"Rejected reconfiguration clears the old writable destination")
	var denied_path:=base.path_join("denied"); var denied:=Observed.new()
	check(denied.configure(denied_path) and DirAccess.remove_absolute(denied_path)==OK,"Bounded failed-recovery fixture starts with a removed directory")
	denied.deny_creation=true
	check(not denied.save_data(identity,source_sha,"directory-recovery",data) and denied.creations==2 and not denied.failure.is_empty(),"Failed directory recovery is explicit and attempted only once")
	var shared:=base.path_join("shared/deep"); var threads: Array=[]
	for iteration in 8:
		var thread:=Thread.new(); check(thread.start(worker.bind(shared))==OK,"Concurrent cold directory worker starts "+str(iteration)); threads.append(thread)
	for thread in threads: thread.wait_to_finish()
	check(results.size()==8 and results.all(func(row):return row.ok and row.warm_creations==0 and row.thread!=OS.get_main_thread_id()),"Concurrent first-use creation succeeds without adding recursive checks to warm worker calls")
	check(FileAccess.get_file_as_string(blocked_path)=="owned blocker","Failed cache configuration preserves the blocking file")
	check(DirAccess.remove_absolute(cache.filename(identity))==OK and DirAccess.remove_absolute(directory)==OK,"Recovered cache entry and directory cleanly retire")
	check(DirAccess.remove_absolute(shared)==OK and DirAccess.remove_absolute(base.path_join("shared"))==OK,"Concurrent fixture directories cleanly retire")
	check(DirAccess.remove_absolute(blocked_path)==OK and DirAccess.remove_absolute(base.path_join("prepared"))==OK and DirAccess.remove_absolute(base)==OK,"All fixture-owned files and directories are removed")
	var report:={"success":failures.is_empty(),"checks":checks,"failures":failures,"warm_configurations":256,"warm_recursive_creations":fresh_creations,"cold_and_recovery_creations":cache.creations,"workers":results,"scope":"Real native filesystem and threads: no recursive creation on existing directories, cold/racing setup, external deletion recovery, bounded failed retry, typed payload integrity, workspace rejection and cleanup. No FPS claim."}
	file=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify(report,"\t")); file.close(); print("NATIVE_CACHE_DIRECTORY_REUSE ",checks," checks"); quit(0 if failures.is_empty() else 1)
