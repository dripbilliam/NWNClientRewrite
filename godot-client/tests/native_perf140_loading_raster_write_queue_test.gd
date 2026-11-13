extends SceneTree
const Assets=preload("res://systems/native_data/asset_service.gd")
const Writes=preload("res://systems/native_data/prepared_write_queue.gd")
const Cache=preload("res://systems/native_data/prepared_cache.gd")
const Store=preload("res://systems/native_data/preparation_store.gd")
const Raster=preload("res://systems/native_data/texture_data.gd")
const Prework=preload("res://systems/native_data/prework_store.gd")
class Catalog:
	extends RefCounted
	var store:=Store.new()
	func fork(): return self
	func preparation_cache(): return store
	func decoded_cache(): return store
class GateWriter:
	extends Writes.State
	var reached:=Semaphore.new()
	var resume:=Semaphore.new()
	var once:=true
	var saved: Array=[]
	func save(packet: Dictionary) -> Dictionary:
		if once:
			once=false; reached.post(); resume.wait()
		var result: Dictionary=super.save(packet)
		mutex.lock(); saved.append({"key":packet.key,"sha256":packet.source_sha,"decoder":packet.decoder,"value":packet.value.duplicate(true),"success":result.success}); mutex.unlock()
		return result
var checks:=0
var failures: Array=[]
func check(value: bool,message: String) -> void:
	checks+=1
	if not value: failures.append(message)
func arg(prefix: String) -> String:
	for text in OS.get_cmdline_user_args():
		if text.begins_with(prefix): return text.trim_prefix(prefix)
	return ""
func _initialize() -> void: call_deferred("run")
func tga(seed: int) -> PackedByteArray:
	var bytes:=PackedByteArray(); bytes.resize(18+4*4*4); bytes[2]=2; bytes.encode_u16(12,4); bytes.encode_u16(14,4); bytes[16]=32
	for index in 64: bytes[18+index]=posmod(seed+index,256)
	return bytes
func run() -> void:
	var mode:=arg("--mode="); var asynchronous:=mode=="deferred"; var catalog:=Catalog.new(); var gate: GateWriter
	check(Writes.shared==null,"isolated writer has no preexisting owner")
	if asynchronous:
		gate=GateWriter.new(); gate.owners=1; gate.maximum_packets=2; Writes.shared=gate
	var a:=Assets.new(); var b:=Assets.new(); root.add_child(a); root.add_child(b); a.configure(catalog); b.configure(catalog)
	var first:=tga(1); var original:=Raster.new().parse(first,3); var digest:=Cache.digest(first)
	var result: Dictionary=a.decode(first,3,"raster",arg("--cache-root="),catalog.store)
	check(str(result.error).is_empty() and result.value==original,"ordinary raster data is original in "+mode)
	check(bool(result.timings.get("cache_write_deferred",false))==asynchronous,"only opt-in ordinary runtime defers raster publication")
	var writes_before:=Writes.snapshot()
	var source_copy:=first.duplicate(); first.fill(0)
	result.value.width=999; result.value.mips[0].width=999; result.value.mips[0].data[0]=199; result.value.mips.append({"consumer_only":true})
	result.consumer_header={"mutable":true}
	var independent: Dictionary=b.decode(source_copy,3,"raster",arg("--cache-root="),catalog.store)
	check(independent.value==original,"nested dictionaries, arrays, packed bytes and source mutation cannot alter another consumer")
	check(bool(independent.get("memory_decode_hit",false)),"same source follows the existing decoded owner")
	var before_error:=int(Writes.snapshot().get("submitted",0)); var malformed: Dictionary=b.decode(PackedByteArray([1]),3,"raster",arg("--cache-root="),catalog.store)
	check(not str(malformed.get("error","")).is_empty() and not malformed.timings.get("cache_write_deferred",false),"invalid original raster errors never enter the optional writer")
	check(int(Writes.snapshot().get("submitted",0))==before_error,"failed raster parse cannot publish or enqueue a cache artifact")
	if asynchronous:
		gate.reached.wait()
		check(int(Writes.snapshot().submitted)==1,"same-key decode admits exactly one background packet")
		var duplicate_key:=str(Writes.shared.identities.keys()[0]).trim_prefix(arg("--cache-root=")+":")
		check(Writes.enqueue(arg("--cache-root="),duplicate_key,digest,"raster",original,1024),"same queued identity coalesces")
		check(int(Writes.snapshot().coalesced)==1,"existing queue records identity coalescing")
		var second:=tga(2); var second_expected:=Raster.new().parse(second,3); var second_result: Dictionary=b.decode(second,3,"raster",arg("--cache-root="),catalog.store)
		check(bool(second_result.timings.get("cache_write_deferred",false)),"second live service retains its own writer admission")
		var third:=tga(3); var third_expected:=Raster.new().parse(third,3); var rejected: Dictionary=b.decode(third,3,"raster",arg("--cache-root="),catalog.store)
		check(bool(rejected.timings.get("cache_write_skipped",false)) and rejected.value==third_expected,"full optional queue skips publication while preserving usable raster")
		check(int(Writes.snapshot().skipped_full)==1,"bounded queue rejection is visible")
		var generation:=catalog.store.generation(); catalog.store.clear()
		check(catalog.store.generation()==generation+1 and int(catalog.store.snapshot().entries)==0,"memory-generation clear detaches original producer residency")
		a.close(); a.free(); check(int(Writes.snapshot().owners)==2,"closing one service preserves another and the fixture writer lease")
		second_result.value.mips[0].data[1]=200; second_result.value.mips.clear(); rejected.value.clear(); independent.value.clear()
		gate.resume.post(); b.close(); b.free(); Writes.release()
		check(bool(Writes.snapshot().closed) and int(Writes.snapshot().pending)==0 and Writes.shared.thread==null,"last writer owner drains and joins without thread leaks")
		check(gate.saved.size()==2 and gate.saved.all(func(row):return row.success),"only admitted packets publish successfully")
		for row in gate.saved:
			var expected: Dictionary=original if row.sha256==digest else second_expected
			check(row.value==expected,"writer-held producer graph survives all external nested mutations and memory clear")
			var cache:=Cache.new(); check(cache.configure(arg("--cache-root=")),"private saved cache configures")
			check(cache.load_data(row.key,row.sha256,"raster")==expected,"complete persisted raster equals original producer output")
		check(int(catalog.store.snapshot().entries)==0,"finishing disk writes never republishes retired-generation memory")
	else:
		check(not bool(result.timings.get("cache_write_deferred",false)),"nondeferred path publishes synchronously or retains configured disabled writes")
		check(int(writes_before.get("submitted",0))==0,"nondeferred raster never enters the writer queue")
		check(bool(result.timings.get("cache_write_phases",{}).get("skipped",false))==(mode=="disabled"),"write-disabled policy stays authoritative")
		a.close(); b.close(); a.free(); b.free()
	catalog.store.clear(); Writes.shared=null
	var proof:={"success":failures.is_empty(),"checks":checks,"mode":mode,"failures":failures,"snapshot":writes_before,"scope":"Native headless writer ownership, nested mutation/COW, bounded queue, source identity, memory generation and close/drain oracle. No GPU/server/latency claim."}
	var file:=FileAccess.open(arg("--report="),FileAccess.WRITE); file.store_string(JSON.stringify(proof)); file.close(); print(JSON.stringify({"success":proof.success,"checks":checks,"mode":mode,"failures":failures})); quit(0 if proof.success else 1)
