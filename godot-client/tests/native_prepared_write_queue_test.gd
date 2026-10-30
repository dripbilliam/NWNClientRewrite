extends SceneTree
const Writes=preload("res://systems/native_data/prepared_write_queue.gd")
const Cache=preload("res://systems/native_data/prepared_cache.gd")
const Assets=preload("res://systems/native_data/asset_service.gd")
const Store=preload("res://systems/native_data/preparation_store.gd")
class Held:
	extends Writes.State
	var entered:=Semaphore.new()
	var release:=Semaphore.new()
	var observed: Dictionary={}
	func save(packet: Dictionary) -> Dictionary:
		mutex.lock(); observed={"directory":packet.directory,"key":packet.key,"source_sha":packet.source_sha,"decoder":packet.decoder}; mutex.unlock()
		entered.post(); release.wait(); return super.save(packet)
class Catalog:
	extends RefCounted
	var bytes:=PackedByteArray()
	var failure:=""
	var store:=Store.new()
	func fork():
		var result:=Catalog.new(); result.bytes=bytes; result.store=store; return result
	func get_resource(_name: String,_type: int) -> PackedByteArray: failure=""; return bytes
	func preparation_cache(): return store
	func decoded_cache(): return store
	func raster_location(_name: String) -> Dictionary: return {}
	func has_resource(_name: String,_type: int) -> bool: return false
class HeldClose:
	extends Writes.State
	var entered:=Semaphore.new()
	var release:=Semaphore.new()
	func close() -> void:
		entered.post(); release.wait(); super.close()
var checks:=0
var failures: Array=[]
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label); print("FAIL: ",label)
func _initialize() -> void: call_deferred("run")
func wait_entered(state) -> bool:
	var deadline:=Time.get_ticks_msec()+5000
	while Time.get_ticks_msec()<deadline:
		if state.entered.try_wait(): return true
		await process_frame
	return false
func run() -> void:
	var report:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): report=arg.substr(9)
	if report.is_empty() or FileAccess.file_exists(report): quit(2); return
	check(Writes.configured_enabled(),"Fixture explicitly enables deferred cache publication")
	var directory:=OS.get_environment("TEMP").path_join("nwn-native-prepared-writes-"+str(OS.get_process_id())+"-"+str(Time.get_ticks_usec()))
	var cache:=Cache.new(); check(cache.configure(directory),"Private native cache fixture is outside source")
	var value:={"nodes":[{"position":PackedFloat32Array([1.25,-0.0,3.0]),"name":"authored"}],"keys":PackedFloat64Array([1.000000000000001,2.0])}
	var digest:=Cache.digest(var_to_bytes(value)); var key:=Cache.key(digest,"authored-writer")
	var state:=Held.new(); state.maximum_packets=2; state.maximum_bytes=8192
	check(state.enqueue(directory,key,digest,"authored-writer",value,4096),"Immutable source packet is accepted")
	check(await wait_entered(state),"Actual low-priority native writer reaches a deliberately held cache operation")
	check(state.enqueue(directory,key,digest,"authored-writer",value,4096) and state.snapshot().coalesced==1,"Active content identity coalesces without another retained packet")
	var second_key:=Cache.key(digest,"authored-second")
	check(state.enqueue(directory,second_key,digest,"authored-second",value,4096),"One additional bounded packet queues while the first write is held")
	check(not state.enqueue(directory,Cache.key(digest,"overflow"),digest,"overflow",value,1),"Full packet/byte budget skips optional cache work without blocking")
	var held: Dictionary=state.snapshot()
	check(held.pending==2 and held.estimated_bytes==8192 and held.peak_packets==2 and held.skipped_full==1,"Budget includes the active packet as well as the queue")
	for frame in 3: await process_frame
	check(state.snapshot().completed==0 and Cache.digest(var_to_bytes(value))==digest,"Main frames and immutable source remain usable while cache IO is held")
	value.added_later="private outer metadata"
	state.release.post(); state.release.post(); state.close(); state.close()
	var finished: Dictionary=state.snapshot()
	check(finished.closed and finished.pending==0 and finished.estimated_bytes==0 and finished.completed==2,"Idempotent close drains every queued packet and releases charged references")
	check(finished.failed==0 and finished.threads.size()==1 and finished.threads[0]!=OS.get_main_thread_id(),"All actual cache saves use exactly one worker and preserve native cache integrity")
	var saved: Dictionary=cache.load_data(key,digest,"authored-writer")
	check(not saved.has("added_later") and Cache.digest(var_to_bytes(saved))==digest,"Queued root snapshot is byte-exact and excludes later private header metadata")
	check(Cache.digest(var_to_bytes(cache.load_data(second_key,digest,"authored-second")))==digest,"Second queued cache reload preserves typed values/doubles")
	check(not state.enqueue(directory,key,digest,"authored-writer",value,4096) and state.snapshot().skipped_closed==1,"Closed writer rejects new work without leaking it")
	var bad:=Writes.State.new()
	check(bad.enqueue(ProjectSettings.globalize_path("res://"),key,digest,"authored-writer",value,4096),"Optional bad cache destination can be diagnosed by its worker")
	bad.close(); check(bad.snapshot().failed==1 and bad.snapshot().pending==0 and not bad.snapshot().errors.is_empty(),"Publication failure is explicit, drained and never a world/model error")
	# Exercise the actual asset-service lease, immutable decoder store and model
	# delivery while the global writer is held. No scene/GPU data enters its job.
	var shared:=Held.new(); shared.owners=1; Writes.service_mutex.lock(); Writes.shared=shared; Writes.service_mutex.unlock()
	var catalog:=Catalog.new(); catalog.bytes=("newmodel authored\nsetsupermodel authored NULL\nbeginmodelgeom authored\nnode dummy root\nparent NULL\nendnode\nendmodelgeom authored\n").to_utf8_buffer()
	var service:=Assets.new(); root.add_child(service); service.configure(catalog); service.cache_directory=directory
	var other:=Assets.new(); root.add_child(other); other.configure(catalog); other.cache_directory=directory
	Writes.release() # Retire the fixture's setup lease after both actual services acquire theirs.
	check(Writes.snapshot().owners==2,"Configured asset services share one writer lifetime with two leases")
	var delivered: Dictionary={}; service.completed.connect(func(_id,result):delivered.merge(result,true))
	check(service.request("authored",2002,"actor-model")>=0,"Real native actor-model request starts")
	check(await wait_entered(shared),"Real immutable decoded model reaches the held writer")
	var deadline:=Time.get_ticks_msec()+5000
	while delivered.is_empty() and Time.get_ticks_msec()<deadline: await process_frame
	check(not delivered.is_empty() and delivered.get("error","missing")=="" and shared.snapshot().completed==0,"Asset completion does not await disk serialization/publication")
	check(delivered.get("timings",{}).get("cache_write_deferred",false) and not delivered.get("timings",{}).get("cache_write_skipped",true),"Delivered source records actual accepted deferred publication")
	service.close(); check(Writes.snapshot().owners==1 and Writes.snapshot().pending==1,"Closing one service never waits for or closes another owner's pending cache writer")
	shared.release.post(); other.close()
	check(Writes.snapshot().owners==0 and Writes.snapshot().closed and Writes.snapshot().pending==0 and Writes.snapshot().completed==1,"Last native asset owner drains and joins its writer")
	shared.mutex.lock(); var original: Dictionary=shared.observed.duplicate(); shared.mutex.unlock()
	var model: Dictionary=cache.load_data(original.key,original.source_sha,original.decoder)
	check(model.get("name","")=="authored" and not model.has("rig_asset"),"Persistent decoded source keeps its original schema while the private live model gains rig metadata")
	var warm_catalog:=Catalog.new(); warm_catalog.bytes=catalog.bytes
	var warm:=Assets.new(); root.add_child(warm); warm.configure(warm_catalog); warm.cache_directory=directory
	var warm_result: Dictionary={}; warm.completed.connect(func(_id,result):warm_result.merge(result,true)); warm.request("authored",2002,"actor-model")
	deadline=Time.get_ticks_msec()+5000
	while warm_result.is_empty() and Time.get_ticks_msec()<deadline: await process_frame
	check(not warm_result.is_empty() and warm_result.get("cache_hit",false) and warm_result.get("error","missing")=="","Fresh decoded-store warm load reuses the verified disk entry")
	warm.close(); check(Writes.snapshot().pending==0 and Writes.snapshot().submitted==0,"Warm source/rig hits need no additional deferred writes")
	var retiring:=HeldClose.new(); retiring.owners=1
	Writes.service_mutex.lock(); Writes.shared=retiring; Writes.service_mutex.unlock()
	var retirement:=Thread.new(); var started:=retirement.start(func():Writes.release())
	check(started==OK,"A real writer-lifetime handoff starts on another thread")
	check(await wait_entered(retiring),"The previous last owner reaches a held close after releasing the service lock")
	Writes.acquire()
	check(Writes.shared!=retiring and Writes.snapshot().owners==1 and not Writes.snapshot().closed,"A new owner receives a fresh state while the old zero-owner writer is retiring")
	retiring.release.post(); retirement.wait_to_finish()
	check(Writes.snapshot().owners==1 and not Writes.snapshot().closed,"Finishing the old close cannot close the new owner's writer")
	Writes.release()
	service.queue_free(); other.queue_free(); warm.queue_free(); await process_frame; await process_frame
	var files:=DirAccess.get_files_at(directory); var only_entries:=true
	for name in files:
		if not str(name).ends_with(".bin"): only_entries=false
		DirAccess.remove_absolute(directory.path_join(name))
	var prework:=directory.path_join("saved-prework-v1")
	if DirAccess.dir_exists_absolute(prework): only_entries=DirAccess.remove_absolute(prework)==OK and only_entries
	check(only_entries and DirAccess.remove_absolute(directory)==OK,"Atomic publication leaves no temporary files; owned fixture directory is cleaned")
	var file:=FileAccess.open(report,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"bounded_writer":finished,"asset_writer":shared.snapshot(),"public_connections":0,"scope":"Actual held native thread, bounded/coalesced packets, exact typed cache roundtrip, failure/close handling, asset delivery before disk completion, shared lease drain, private rig metadata and fresh-store warm cache reuse. Not GPU/FPS or complete-world timing acceptance."},"\t")); file.close(); print("NATIVE_PREPARED_WRITE_QUEUE ",checks," checks"); quit(0 if failures.is_empty() else 1)
