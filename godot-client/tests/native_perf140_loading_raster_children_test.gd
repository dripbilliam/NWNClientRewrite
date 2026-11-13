extends SceneTree
const Child=preload("res://systems/native_data/prework_raster_children.gd")
const Prework=preload("res://systems/native_data/prework_store.gd")
const Cache=preload("res://systems/native_data/prepared_cache.gd")
const Store=preload("res://systems/native_data/preparation_store.gd")
var checks:=0
var failures: Array=[]
var results_gate:=Mutex.new()
var threaded_results: Array=[]
class Reader:
	extends RefCounted
	var failure:=""
	var bytes:=PackedByteArray([1,2,3])
	var store:=Store.new()
	func decoded_cache(): return store
	func get_resource(_name: String,_type: int) -> PackedByteArray: return bytes.duplicate()
class HeldStore extends "res://systems/native_data/preparation_store.gd":
	var entered:=Semaphore.new()
	var release:=Semaphore.new()
	var hold_gate:=Mutex.new()
	var held:=false
	func begin_data(request: String,expected: int,private_graph: bool=true) -> Dictionary:
		var lease:=super.begin_data(request,expected,private_graph)
		if bool(lease.owner):
			hold_gate.lock(); var wait:=not held; held=true; hold_gate.unlock()
			if wait: entered.post(); release.wait()
		return lease
func argument(prefix: String) -> String:
	for value in OS.get_cmdline_user_args():
		if value.begins_with(prefix): return value.trim_prefix(prefix)
	return ""
func check(value: bool,message: String) -> void:
	checks+=1
	if not value: failures.append(message)
func _initialize() -> void: call_deferred("run")
func image() -> Dictionary:
	var flags: Array[int]=[1,2,3]
	return {"width":2,"height":1,"pixels":PackedByteArray([1,2,3,4,5,6,7,8]),"format":"rgba8","custom":{"alpha":"straight","flags":flags}}
func data() -> Dictionary:
	var packet:={"value":image(),"sha256":"a".repeat(64),"cache_hit":false,"timings":{"decode_ms":1.25},"custom_descriptor":{"type":3,"sampler":"linear"}}
	var alias:=packet.duplicate(true); alias.cache_hit=true; alias.timings.decode_ms=2.5
	return {"value":{"nodes":[{"name":"original","position":[0.0,1.0,2.0]}]},"textures":{"one":packet,"alias":alias,"flat-plt":{"pixels":PackedByteArray([9,8,7,6]),"width":1,"height":1}},"emitter_textures":{"emitter":packet.duplicate(true)},"dependencies":[{"name":"original","type":3,"cache_hit":false,"timings":{"decode_ms":0.5}}]}
func bytes_at(path: String) -> PackedByteArray:
	var file:=FileAccess.open(path,FileAccess.READ)
	if file==null: return PackedByteArray()
	var value:=file.get_buffer(file.get_length()); file.close(); return value
func threaded_read(parent: String,envelope: Dictionary,reader) -> void:
	var loader:=Child.new(); loader.configure(parent); var result:=loader.unpack(envelope,reader)
	results_gate.lock(); threaded_results.append(result); results_gate.unlock()
func coalesced_checks(parent: String,original: Dictionary) -> void:
	var single:={"value":original.value,"textures":{"one":original.textures.one}}
	var writer:=Child.new(); writer.configure(parent); var packed:=writer.pack(single)
	check(packed.success,"single-reference concurrent fixture publishes through the same owner")
	var reader:=Reader.new(); var store:=HeldStore.new(); reader.store=store
	var tasks: Array=[]; var before:=Child.snapshot()
	tasks.append(WorkerThreadPool.add_task(threaded_read.bind(parent,packed.data,reader)))
	store.entered.wait()
	for ignored in 3: tasks.append(WorkerThreadPool.add_task(threaded_read.bind(parent,packed.data,reader)))
	var deadline:=Time.get_ticks_msec()+2000
	while int(store.snapshot().coalesced)<3 and Time.get_ticks_msec()<deadline: OS.delay_msec(1)
	check(int(store.snapshot().coalesced)==3,"same-image readers coalesce before disk validation")
	store.clear(); store.release.post()
	for task in tasks: WorkerThreadPool.wait_for_task_completion(task)
	check(threaded_results.size()==4 and threaded_results.all(func(row):return row.success and row.data==single),"all followers receive complete detached original data after an epoch change")
	check(store.snapshot().entries==0 and store.snapshot().inflight==0,"old-generation owner/followers cannot populate a cleared decoded store")
	check(int(Child.snapshot().reads)-int(before.reads)==1,"coalesced readers perform one physical child read")
	threaded_results.clear()
func run() -> void:
	var enabled:=Child.enabled(); var integrated:=argument("--expect-integration=")=="true"
	var directory:=argument("--cache-root=")
	var child:=Child.new(); child.configure(directory.path_join("direct"))
	var reader:=Reader.new(); var original:=data(); var original_bytes:=var_to_bytes(original)
	var before:=Child.snapshot()
	var metadata:=child.pack({"textures":{"metadata":{"value":{"width":1,"height":1}}}})
	check(metadata.success and not metadata.data.has("format"),"metadata-only descriptor stays flat")
	check(Child.snapshot()==before,"metadata-only pack performs no child filesystem access")
	var packed:=child.pack(original)
	check(packed.success,"standard image pack succeeds")
	check(var_to_bytes(original)==original_bytes,"publication does not mutate producer packets")
	if not enabled:
		check(packed.data==original,"disabled mode preserves complete original data")
		check(child.unpack(packed.data,reader).data==original,"disabled flat load is unchanged")
		check(child.read_child("a".repeat(64),12).is_empty(),"disabled direct read refuses optional child access")
		check(Child.snapshot()==before,"disabled pack/load/configure/read perform zero child-store I/O")
	else:
		check(packed.data.format==Child.FORMAT and packed.data.references.size()==3,"three standard raster references share separate values")
		check(int(Child.snapshot().writes)-int(before.writes)==1,"different diagnostics still publish exactly one image child")
		var reference: Dictionary=packed.data.references[0]
		var path:=child.cache.filename(Child.child_key(reference.sha256))
		check(FileAccess.file_exists(path),"published child exists before a parent can reference it")
		var read_before:=Child.snapshot()
		var unpacked:=child.unpack(packed.data,reader)
		check(unpacked.success and unpacked.data==original,"all descriptors, packet metadata and diagnostics roundtrip exactly")
		check(int(Child.snapshot().reads)-int(read_before.reads)==1,"one owner reads the repeated image once")
		check(int(Child.snapshot().memory_hits)-int(read_before.memory_hits)==2,"other references reuse the existing decoded owner")
		check(unpacked.data.textures.one.value.custom.flags.is_typed() and unpacked.data.textures.one.value.custom.flags.get_typed_builtin()==TYPE_INT,"typed descriptor arrays retain their type")
		unpacked.data.textures.one.value.width=9; unpacked.data.textures.one.value.pixels[0]=99; unpacked.data.textures.one.value.custom.flags[0]=99
		check(unpacked.data.textures.alias.value.width==2 and unpacked.data.textures.alias.value.pixels[0]==1 and unpacked.data.textures.alias.value.custom.flags[0]==1,"consumer dictionaries/packed buffers/typed arrays are isolated")
		check(child.unpack(packed.data,reader).data==original,"consumer mutation cannot alter the decoded child cache or producer")
		for variant in ["sha","bytes","field","target","duplicate"]:
			var bad: Dictionary=packed.data.duplicate(true)
			match variant:
				"sha": bad.references[0].sha256="../../outside"
				"bytes": bad.references[0].bytes=Cache.MAX_BYTES+1
				"field": bad.references[0].field="arbitrary"
				"target": bad.references[0].name="absent"
				"duplicate": bad.references.append(bad.references[0].duplicate())
			var stats:=Child.snapshot()
			check(not child.unpack(bad,reader).success,"malformed child reference rejected: "+variant)
			check(Child.snapshot()==stats,"malformed reference has no child filesystem access: "+variant)
		reader.store.clear()
		check(DirAccess.remove_absolute(path)==OK,"owned child can be removed for the missing-sidecar fixture")
		check(not child.unpack(packed.data,reader).success,"missing child is a whole-parent cache miss")
		check(child.pack(original).success and child.unpack(packed.data,reader).success,"ordinary source preparation repairs a missing child")
		reader.store.clear()
		check(DirAccess.remove_absolute(path)==OK,"owned child cleared before self-consistent wrong-value fixture")
		var wrong:=image(); wrong.width=19
		check(child.cache.save_data(Child.child_key(reference.sha256),reference.sha256,Child.FORMAT,wrong),"syntactically valid wrong-value child written only in owned test directory")
		check(not child.unpack(packed.data,reader).success,"valid header/checksum cannot hide wrong actual child content")
		check(child.pack(original).success and child.unpack(packed.data,reader).data==original,"wrong-content child is repaired before reuse")
		reader.store.clear()
		var corrupt:=FileAccess.open(path,FileAccess.READ_WRITE); corrupt.seek(49); var byte:=corrupt.get_8(); corrupt.seek(49); corrupt.store_8(byte^1); corrupt.close()
		check(not child.unpack(packed.data,reader).success,"prepared checksum corruption also makes a whole-parent miss")
		check(child.pack(original).success and child.unpack(packed.data,reader).data==original,"checksum corruption repairs through original source value")
		coalesced_checks(child.parent_directory,original)
	var saved:=Prework.new(); check(saved.configure(directory.path_join("parent")),"owned parent prework cache configures")
	var key:="7".repeat(64); var inputs:=[{"operation":"bytes","name":"root","type":2002,"sha256":Cache.digest(reader.bytes)}]
	var ticket:=saved.generation(); check(saved.save_entry(key,inputs,original,ticket),"actual parent owner saves a complete artifact")
	check(saved.load_entry(key,reader)==original,"actual parent owner returns the complete original packet contract")
	var on_disk:=saved.cache.load_data(key,key,Prework.REVISION)
	check((on_disk.data.get("format")==Child.FORMAT)==integrated,"only the wired opt-in candidate changes the storage envelope")
	if integrated:
		var parent_path:=saved.cache.filename(key); var parent_bytes:=bytes_at(parent_path)
		var changed:=original.duplicate(true); changed.textures.one.value.pixels[0]=77
		var changed_inputs:=inputs.duplicate(true); changed_inputs[0].sha256="b".repeat(64)
		saved.raster_children.ready=true; saved.raster_children.cache.directory="" # Owned failure injection.
		check(not saved.save_entry(key,changed_inputs,changed,ticket),"child publication failure prevents parent replacement")
		check(bytes_at(parent_path)==parent_bytes,"old complete parent remains intact after child write failure")
		saved.raster_children.configure(saved.directory)
		check(saved.load_entry(key,reader)==original,"old parent remains usable after optional publication failure")
		var ref: Dictionary=on_disk.data.references[0]; var child_path:=saved.directory.path_join(Child.DIRECTORY).path_join(Child.child_key(ref.sha256)+".bin")
		reader.store.clear(); check(DirAccess.remove_absolute(child_path)==OK,"actual parent child removed in owned fixture")
		check(saved.load_entry(key,reader).is_empty(),"parent load never returns a partial missing-image model")
		check(saved.save_entry(key,inputs,original,ticket),"matching input early path repairs children before success")
		reader.store.clear(); check(saved.load_entry(key,reader)==original,"repaired parent roundtrips complete data")
		var orphan:=original.duplicate(true); orphan.textures.one.value.pixels[0]=66
		check(saved.raster_children.pack(orphan).success,"owned orphan sidecar fixture published")
		var keep_path:=saved.directory.path_join(Child.DIRECTORY).path_join("keep.txt"); var keep:=FileAccess.open(keep_path,FileAccess.WRITE); keep.store_string("preserve unrelated names"); keep.close()
		var cleared:=saved.clear()
		check(int(cleared.raster_children_removed)>=2 and cleared.errors.is_empty(),"explicit clear removes referenced and orphan generated sidecars")
		check(FileAccess.file_exists(keep_path),"clear preserves unrelated child-directory files")
		check(not saved.save_entry(key,inputs,original,ticket),"old generation cannot publish new children/parent after clear")
		check(Prework.publication_snapshot().entries==0 and Child.snapshot().active_writers==0,"all publication leases release after success/failure/clear")
	reader.store.clear()
	var proof:={"success":failures.is_empty(),"checks":checks,"failures":failures,"enabled":enabled,"integrated":integrated,"child_stats":Child.snapshot(),"scope":"Headless content-addressed raster child correctness; no graphics/server/FPS evidence"}
	var report:=FileAccess.open(argument("--report="),FileAccess.WRITE); report.store_string(JSON.stringify(proof)); report.close(); print(JSON.stringify(proof)); quit(0 if proof.success else 1)
