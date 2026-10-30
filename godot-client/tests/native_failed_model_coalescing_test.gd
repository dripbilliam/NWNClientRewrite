extends SceneTree
const Assets=preload("res://systems/native_data/asset_service.gd")
const Store=preload("res://systems/native_data/preparation_store.gd")
class HeldDecoder:
	extends Assets
	var entered:=Semaphore.new()
	var release:=Semaphore.new()
	func decode_uncached(bytes: PackedByteArray,type: int,decoder: String,cache_path: String,known_sha: String="",defer_write: bool=false) -> Dictionary:
		entered.post(); release.wait(); return super.decode_uncached(bytes,type,decoder,cache_path,known_sha,defer_write)
var checks:=0
var failures: Array=[]
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label); print("FAIL: ",label)
func call_decode(service,bytes: PackedByteArray,store) -> Dictionary: return service.decode(bytes,2002,"mdl-actor-packed-v3","",store)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var report:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): report=arg.substr(9)
	if report.is_empty() or FileAccess.file_exists(report): quit(2); return
	for raw in ["invalid authored model\n".to_utf8_buffer(),PackedByteArray([0,0,0,0,1,2,3,4])]:
		var store:=Store.new(); var service:=HeldDecoder.new(); root.add_child(service); service.set_process(false)
		var threads: Array=[]; var first:=Thread.new(); first.start(call_decode.bind(service,raw,store)); threads.append(first); service.entered.wait()
		for index in 3:
			var follower:=Thread.new(); follower.start(call_decode.bind(service,raw,store)); threads.append(follower)
		var deadline:=Time.get_ticks_msec()+5000
		while store.snapshot().coalesced<3 and Time.get_ticks_msec()<deadline: await process_frame
		check(store.snapshot().coalesced==3,"Three actual model decoders wait on one failed original-source parse")
		service.release.post(); var results: Array=[]
		for thread in threads: results.append(thread.wait_to_finish())
		check(results.all(func(result):return not str(result.error).is_empty() and result.error==results[0].error),"All immutable-source followers retain the precise parse failure")
		check(results.all(func(result):return result.value.is_empty()),"Failed sources never become fabricated partial actor models")
		check(results.filter(func(result):return result.memory_decode_hit).size()==3,"Shared error delivery is observed without re-decoding")
		check(store.snapshot().inflight==0 and store.snapshot().entries==0,"Error flights drain and invalid sources do not enter the resident cache")
		service.close(); service.queue_free(); await process_frame; await process_frame
	var file:=FileAccess.open(report,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"publicConnections":0,"scope":"Concurrent actual ASCII/binary actor parse failures and immutable decoded-source followers; verifies error propagation without invalid animation access or worker survivors"})); file.close(); quit(0 if failures.is_empty() else 1)
