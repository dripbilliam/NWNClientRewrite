extends SceneTree
const Cache=preload("res://systems/native_data/source_bytes_cache.gd")
const Store=preload("res://systems/native_data/nwsync_store.gd")
const Residency=preload("res://systems/native_data/resource_residency.gd")
const Writes=preload("res://systems/native_data/prepared_write_queue.gd")
var checks:=0
var failures: Array=[]
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label); print("FAIL: ",label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("fixture") or not args.has("report") or FileAccess.file_exists(args.report): quit(2); return
	var fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(args.fixture))
	var directory:=str(fixture.root).path_join("raw-cache")
	var cache:=Cache.new(); check(cache.configure(directory),"Content cache accepts private runtime path")
	var forbidden:=Cache.new(); check(not forbidden.configure("res://reports/raw-cache"),"Original bytes cannot be cached in source workspace")
	var bytes:="Exact authored source bytes".to_utf8_buffer(); var identity:=Store.sha1(bytes)
	check(cache.read(identity,bytes.size()).is_empty(),"Cold content cache misses without a guessed payload")
	check(not cache.save("0".repeat(40),bytes),"Writes require authoritative digest identity")
	check(cache.save(identity,bytes) and cache.read(identity,bytes.size()).bytes==bytes,"Verified decompressed bytes persist exactly")
	check(cache.read(identity,bytes.size()+1).is_empty() and cache.filename("../escape").is_empty(),"Size mismatch and path-like identities are rejected")
	var file:=FileAccess.open(cache.filename(identity),FileAccess.READ_WRITE); file.store_8(0); file.close()
	check(cache.read(identity,bytes.size()).is_empty(),"Same-length corruption is rejected before reuse")
	check(cache.save(identity,bytes) and cache.read(identity,-1).bytes==bytes,"Corrupt cache entry rebuilds from verified source")
	var tasks: Array=[]; var passed: Dictionary={}; var mutex:=Mutex.new()
	for index in 12:
		tasks.append(WorkerThreadPool.add_task(func():
			var ok:=cache.save(identity,bytes)
			var saved:=cache.read(identity,bytes.size())
			# Competing Windows rename/delete can create a transient miss; never
			# return corrupt bytes. A final complete winner is checked below.
			mutex.lock(); passed[index]=ok and (saved.is_empty() or saved.bytes==bytes); mutex.unlock()))
	while tasks.any(func(task):return not WorkerThreadPool.is_task_completed(task)): await process_frame
	for task in tasks: WorkerThreadPool.wait_for_task_completion(task)
	check(passed.size()==12 and passed.values().all(func(ok):return ok) and cache.read(identity,-1).bytes==bytes,"Concurrent writers publish a complete content entry")
	var raw:=FileAccess.get_file_as_bytes(str(fixture.root).path_join("raw"))
	Writes.acquire()
	var source:=Store.new(); check(source.configure(fixture.cache,"","",directory),"Real NWSync resource path enables raw-byte cache")
	var entry:={"hash":fixture.resource,"size":raw.size()}
	var first:=source.resource(entry); check(not first.has("error") and first.bytes==raw,"Canonical compressed source populates verified raw cache")
	var second:=source.resource(entry); check(not second.has("error") and second.bytes==raw and second.timings.memory_source_hit,"Second native resource read bypasses source I/O and decompression")
	var again:=Store.new(); again.configure(fixture.cache,"","",directory)
	Writes.release(); Writes.acquire() # Join optional publication before testing the independent disk tier.
	Residency.synced_bytes.clear() # Explicitly cold RAM to exercise the independent disk tier.
	check(again.resource(entry).timings.raw_cache_hit,"New resource owner reuses disk bytes by content identity")
	file=FileAccess.open(cache.filename(fixture.resource),FileAccess.READ_WRITE); file.store_8(0); file.close()
	Residency.synced_bytes.clear() # A valid resident copy may correctly outlive corrupt disk bytes.
	var repaired:=again.resource(entry)
	check(not repaired.has("error") and repaired.bytes==raw and not repaired.timings.get("raw_cache_hit",false),"Poisoned disk bytes cause canonical-source fallback and repair")
	Writes.release()
	cache.maximum_disk_bytes=1; cache.prune()
	check(cache.read(identity,-1).is_empty() and cache.read(fixture.resource,-1).is_empty(),"Owned content retention respects configured disk budget")
	source.close(); again.close()
	file=FileAccess.open(args.report,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"publicConnections":0})); file.close()
	quit(0 if failures.is_empty() else 1)
