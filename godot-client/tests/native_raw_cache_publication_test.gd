extends SceneTree
const Writes=preload("res://systems/native_data/prepared_write_queue.gd")
const Store=preload("res://systems/native_data/nwsync_store.gd")
const Cache=preload("res://systems/native_data/source_bytes_cache.gd")
const Residency=preload("res://systems/native_data/resource_residency.gd")
class GatedWriter:
	extends Writes.State
	var gate:=Semaphore.new()
	var entered:=false
	func save(packet: Dictionary) -> Dictionary:
		mutex.lock(); entered=true; mutex.unlock(); gate.wait()
		return super.save(packet)
	func waiting() -> bool:
		mutex.lock(); var value:=entered; mutex.unlock(); return value
class HeldMaintenance:
	extends Cache
	var entered:=false
	func prune(cancel: Callable=Callable()) -> bool:
		metadata_mutex.lock(); entered=true; metadata_mutex.unlock()
		while cancel.is_valid() and not cancel.call(): OS.delay_usec(1000)
		return false
	func waiting() -> bool:
		metadata_mutex.lock(); var value:=entered; metadata_mutex.unlock(); return value
var checks:=0
var failures: Array=[]
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label); print("FAIL ",label)
func _initialize() -> void: call_deferred("run")
func write(path: String,bytes: PackedByteArray) -> void:
	var file:=FileAccess.open(path,FileAccess.WRITE); file.store_buffer(bytes); file.close()
func blob(bytes: PackedByteArray) -> PackedByteArray:
	var value:="NSYC".to_ascii_buffer(); value.resize(16); value.encode_u32(4,3); value.encode_u32(12,bytes.size()); value.append_array(bytes); return value
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("fixture") or not args.has("report") or FileAccess.file_exists(args.report): quit(2); return
	var fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(args.fixture))
	var folder:=OS.get_temp_dir().path_join("nwn-raw-publication-"+str(OS.get_process_id())+"-"+str(Time.get_ticks_usec()))
	var cache:=Cache.new(); check(cache.configure(folder),"Publication uses an isolated generated cache root")
	var writer:=GatedWriter.new(); writer.owners=1; Writes.shared=writer
	var maintenance:=HeldMaintenance.new(); maintenance.configure(folder); writer.raw_caches[folder]=maintenance
	var source:=Store.new(); check(source.configure(fixture.cache,"","",folder),"Canonical authored NWSync source opens")
	Residency.synced_bytes.clear()
	var raw:=FileAccess.get_file_as_bytes(str(fixture.root).path_join("raw")); var entry:={"hash":fixture.resource,"size":raw.size()}
	var result:=source.resource(entry)
	check(not result.has("error") and result.bytes==raw and result.timings.cache_save_queued,"Actual resource demand returns exact verified bytes while publication is queued")
	var deadline:=Time.get_ticks_msec()+5000
	while not writer.waiting() and Time.get_ticks_msec()<deadline: await process_frame
	check(writer.waiting() and not FileAccess.file_exists(cache.filename(fixture.resource)),"A gated disk writer cannot hold up resource readiness")
	var private_bytes: PackedByteArray=result.bytes; private_bytes[0]=0
	check(Writes.enqueue_raw(folder,fixture.resource,raw,cache.maximum_disk_bytes,cache.maximum_entry_bytes) and int(writer.snapshot().coalesced)==1,"Duplicate pending raw publications coalesce by directory and content identity")
	writer.maximum_packets=1
	var second:=("queue full "+folder).to_utf8_buffer(); var second_hash:=Store.sha1(second); var second_path:=str(fixture.cache).path_join("objects").path_join(second_hash); write(second_path,blob(second))
	var full:=source.resource({"hash":second_hash,"size":second.size()})
	check(not full.has("error") and full.bytes==second and full.timings.cache_save_skipped,"A full optional write queue skips disk publication without withholding the resource")
	writer.gate.post()
	deadline=Time.get_ticks_msec()+5000
	while not maintenance.waiting() and Time.get_ticks_msec()<deadline: await process_frame
	check(maintenance.waiting() and writer.snapshot().pending==0,"Cleanup starts only after pending cache data writes finish")
	Writes.release()
	var saved:=cache.read(fixture.resource,raw.size())
	check(saved.get("bytes")==raw,"Queued publication owns immutable bytes even when the caller edits its returned buffer")
	var state:=writer.snapshot()
	check(state.closed and state.pending==0 and state.raw_completed==1 and state.failed==0,"Last-owner release drains data writes and joins the low-priority worker")
	check(Store.sha1(PackedByteArray())=="da39a3ee5e6b4b0d3255bfef95601890afd80709","Empty resource bytes have the correct canonical identity without engine errors")
	check(cache.save(Store.sha1(PackedByteArray()),PackedByteArray()) and cache.read(Store.sha1(PackedByteArray()),0).get("bytes")==PackedByteArray(),"Direct cache publication also preserves a valid zero-length resource")
	var absent:=("no writer "+folder).to_utf8_buffer(); var absent_hash:=Store.sha1(absent); var absent_path:=str(fixture.cache).path_join("objects").path_join(absent_hash); write(absent_path,blob(absent))
	var standalone:=source.resource({"hash":absent_hash,"size":absent.size()})
	check(not standalone.has("error") and standalone.bytes==absent and standalone.timings.cache_save_skipped,"A standalone reader without a writer still returns canonical data without synchronous maintenance")
	source.close()
	for owned in [cache.filename(fixture.resource),cache.filename(Store.sha1(PackedByteArray())),second_path,absent_path]: DirAccess.remove_absolute(owned)
	check(DirAccess.remove_absolute(folder)==OK,"Only exact owned fixture files and the empty generated directory are removed")
	var file:=FileAccess.open(args.report,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"writer":state,"publicConnections":0,"scope":"Real native NWSync demand with a gated disk writer; readiness, private buffer ownership, coalescing, bounded queue overflow, zero-length content, no-writer behavior and joined shutdown. No public or game-server connection."},"  ")+"\n"); file.close(); quit(0 if failures.is_empty() else 1)
