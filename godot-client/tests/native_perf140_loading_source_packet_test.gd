extends SceneTree
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Recorded=preload("res://systems/native_data/recorded_catalog.gd")
const Cache=preload("res://systems/native_data/prepared_cache.gd")
const Prework=preload("res://systems/native_data/prework_store.gd")
var checks:=0
var failures: Array=[]
var args: Dictionary={}
var packets:=false
class PausedCatalog:
	extends "res://systems/native_data/resource_catalog.gd"
	var entered: Semaphore
	var released: Semaphore
	func read_resource(name: String,type: int) -> PackedByteArray:
		entered.post();released.wait();return super.read_resource(name,type)
func check(value: bool,message: String) -> void:
	checks+=1
	if not value:failures.append(message)
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	packets=args.get("expect-packets","false")=="true";call_deferred("run")
func data(value: int=17) -> PackedByteArray:return ("2DA V2.0\n\nValue\n0 "+str(value)+"\n").to_utf8_buffer()
func write(path: String,bytes: PackedByteArray) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir());var file:=FileAccess.open(path,FileAccess.WRITE);file.store_buffer(bytes);file.close()
func proof(reader,name: String,type: int,bytes: PackedByteArray) -> String:
	return reader.last_resource_digest_for_bytes(name,type,bytes) if reader.has_method("last_resource_digest_for_bytes") else Cache.digest(bytes)
func catalog_checks() -> void:
	var path:=ProjectSettings.globalize_path("res://packet-fixtures/first");var other:=ProjectSettings.globalize_path("res://packet-fixtures/other")
	write(path.path_join("a.2da"),data());write(path.path_join("b.2da"),data(19));write(path.path_join("empty.2da"),PackedByteArray());write(other.path_join("a.2da"),data(20))
	var source:=Catalog.new();check(source.mount_directory(path),"Raw fixture catalog mounts")
	var a: PackedByteArray=source.get_resource("a",2017);check(a==data() and proof(source,"A",2017,a)==Cache.digest(a),"First read returns original bytes and matching just-read digest")
	if packets:
		check(source.stats.source_fingerprint_computations==1,"First successful byte admission hashes once")
		check(source.last_resource_digest_for_bytes("wrong",2017,a).is_empty() and source.last_resource_digest_for_bytes("a",3,a).is_empty() and source.last_resource_digest_for_bytes("a",2017,data(123)).is_empty(),"Proof requires matching canonical name, type and actual bytes")
	a[0]=0
	if packets:check(source.last_resource_digest_for_bytes("a",2017,a).is_empty(),"Same-length returned packed-byte mutation invalidates its digest proof")
	var fresh: PackedByteArray=source.get_resource("a",2017)
	check(fresh==data() and proof(source,"a",2017,fresh)==Cache.digest(data()),"Caller packed-byte mutation cannot poison cached bytes/digest")
	if packets:check(source.stats.source_fingerprint_computations==1,"Warm admitted packet reuses its digest without hashing its bytes")
	source.read_resource("a",2017)
	if packets:check(source.last_resource_digest_for_bytes("a",2017,fresh).is_empty(),"Bypass read invalidates old get-resource proof")
	source.get_resource("does_not_exist",2017)
	check(not source.failure.is_empty(),"Missing raw resource stays missing")
	if packets:check(source.last_resource_digest_for_bytes("a",2017,fresh).is_empty(),"Failed read cannot expose the preceding resource's fingerprint")
	# Force eviction, then change the same named/length loose payload.
	source.source_store.clear();source.source_store.maximum_entries=1
	source.get_resource("a",2017);source.get_resource("b",2017);write(path.path_join("a.2da"),data(18))
	var changed: PackedByteArray=source.get_resource("a",2017)
	check(changed==data(18) and proof(source,"a",2017,changed)==Cache.digest(data(18)),"Eviction and same-size file changes cannot leave a separate stale name-to-digest entry")
	var old=source.fork();var old_data: PackedByteArray=old.get_resource("a",2017);var old_store: int=old.source_store.get_instance_id()
	check(source.mount_directory(other,20000000),"Override mounts as a new source scope")
	check(source.source_store.get_instance_id()!=old_store,"Source invalidation replaces byte-store identity")
	if packets:check(source.last_resource_digest_for_bytes("a",2017,old_data).is_empty(),"Provider/store stamp rejects proof across remount")
	var overridden: PackedByteArray=source.get_resource("a",2017)
	check(overridden==data(20) and proof(source,"a",2017,overridden)==Cache.digest(data(20)),"New winning source supplies a new content digest")
	check(old.get_resource("a",2017)==data(18) and proof(old,"a",2017,old_data)==Cache.digest(data(18)),"Old fork retains the old source binding and matching fingerprint")
	source.source_store.clear()
	if packets:check(source.last_resource_digest_for_bytes("a",2017,overridden).is_empty(),"Cleared source-cache generation retires old proof")
	var after_clear: PackedByteArray=source.get_resource("a",2017);check(proof(source,"a",2017,after_clear)==Cache.digest(data(20)),"Post-clear admission has a valid fresh proof")
	var empty: PackedByteArray=source.get_resource("empty",2017)
	check(source.failure.is_empty() and empty.is_empty() and proof(source,"empty",2017,empty)==Cache.digest(empty),"A valid zero-byte resource is distinct from missing data")
	source.source_store.clear();source.source_store.maximum_bytes=1
	var uncached: PackedByteArray=source.get_resource("a",2017)
	check(source.source_store.entries.is_empty() and proof(source,"a",2017,uncached)==Cache.digest(uncached),"Unretained successful reads still have correct job-local digest proofs")
	source.source_store.clear();old.source_store.clear()
func read_thread(reader) -> Dictionary:
	var bytes: PackedByteArray=reader.get_resource("a",2017)
	return {"bytes":bytes,"digest":proof(reader,"a",2017,bytes),"hashes":int(reader.stats.get("source_fingerprint_computations",0))}
func coalesced_checks() -> void:
	var path:=ProjectSettings.globalize_path("res://packet-fixtures/coalesced");write(path.path_join("a.2da"),data())
	var source:=PausedCatalog.new();check(source.mount_directory(path),"Coalesced raw catalog mounts")
	var a=source.fork();var b=source.fork();var entered:=Semaphore.new();var released:=Semaphore.new();a.entered=entered;a.released=released;b.entered=entered;b.released=released
	var first:=Thread.new();var second:=Thread.new();check(first.start(read_thread.bind(a))==OK,"First source reader starts")
	var deadline:=Time.get_ticks_msec()+10000;var paused:=false
	while Time.get_ticks_msec()<deadline:
		if entered.try_wait():paused=true;break
		await process_frame
	check(paused,"First raw read is actually paused before publication")
	if not paused:released.post();first.wait_to_finish();return
	check(second.start(read_thread.bind(b))==OK,"Follower source reader starts")
	deadline=Time.get_ticks_msec()+10000
	while source.source_store.snapshot().coalesced<1 and Time.get_ticks_msec()<deadline:await process_frame
	check(source.source_store.snapshot().coalesced==1,"Follower actually waits on the raw byte flight")
	released.post();released.post();var one: Dictionary=first.wait_to_finish();var two: Dictionary=second.wait_to_finish()
	check(one.bytes==data() and two.bytes==data() and one.digest==Cache.digest(data()) and two.digest==one.digest,"Coalesced readers receive exact bytes and matching digest")
	check(one.hashes+two.hashes==(1 if packets else 0),"Exactly one source-packet hash is computed for coalesced first admission")
	one.bytes[0]=0;check(two.bytes==data(),"Coalesced returned packed buffers are independently mutable")
	if packets:check(proof(a,"a",2017,one.bytes).is_empty() and proof(b,"a",2017,two.bytes)==Cache.digest(data()),"Coalesced packet proofs bind to each reader's actual unmutated bytes")
	source.source_store.clear()
func record_fixture(path: String,bytes: PackedByteArray) -> String:
	var sha:=Cache.digest(bytes);write(path.path_join("objects").path_join(sha),bytes)
	write(path.path_join("manifest.json"),JSON.stringify({"version":2,"complete":true,"availability":{"a:2017":2},"resources":{"a:2017":{"sha256":sha,"bytes":bytes.size()}},"portraitFiles":[]}).to_utf8_buffer());return sha
func recorded_checks() -> void:
	var path:=ProjectSettings.globalize_path("res://packet-fixtures/recorded");var other:=ProjectSettings.globalize_path("res://packet-fixtures/recorded-other")
	var sha:=record_fixture(path,data());record_fixture(other,data(18))
	var source:=Recorded.new();check(source.mount(path),"Owned recorded-catalog fixture mounts")
	var original: PackedByteArray=source.get_resource("a",2017);check(proof(source,"a",2017,original)==sha,"Recorded reader exposes the digest it just verified")
	original[0]=0
	if packets:check(proof(source,"a",2017,original).is_empty(),"Recorded packet proof rejects same-length returned-byte mutation")
	check(source.get_resource("a",2017)==data(),"Mutating returned recorded bytes cannot change the source file")
	var corrupt:=data();corrupt[0]=0;write(path.path_join("objects").path_join(sha),corrupt)
	source.get_resource("a",2017)
	check(not source.failure.is_empty(),"Recorded payload checksum still rejects same-length corruption")
	if packets:check(source.last_resource_digest_for_bytes("a",2017,corrupt).is_empty(),"Rejected recorded read does not advertise a valid digest")
	write(path.path_join("objects").path_join(sha),data());source.get_resource("a",2017);var old=source.fork()
	check(source.mount(other),"Recorded catalog remount succeeds")
	if packets:check(source.last_resource_digest_for_bytes("a",2017,data()).is_empty(),"Recorded remount retires the previous provider-scope proof")
	var current: PackedByteArray=source.get_resource("a",2017);check(current==data(18) and proof(source,"a",2017,current)==Cache.digest(current),"Recorded remount supplies the new validated identity")
	var old_value: PackedByteArray=old.get_resource("a",2017);check(old_value==data() and proof(old,"a",2017,old_value)==sha,"Recorded fork preserves its own original read scope")
	check(not source.mount("relative"),"Invalid recorded mount stays invalid")
	if packets:check(source.last_resource_digest_for_bytes("a",2017,current).is_empty(),"Failed remount clears previous digest proof")
func input_checks() -> void:
	var path:=ProjectSettings.globalize_path("res://packet-fixtures/input");write(path.path_join("a.2da"),data())
	var source:=Catalog.new();check(source.mount_directory(path),"Input reader fixture mounts")
	var inputs:=Prework.Inputs.new(source);var bytes: PackedByteArray=inputs.get_resource("a",2017)
	check(proof(inputs,"a",2017,bytes)==Cache.digest(bytes),"Input reader exposes the just-read byte digest")
	if packets:
		check(inputs.fingerprint_computations==0 and inputs.fingerprint_hint_hits==1,"Input reader reuses the verified provider packet digest")
		bytes[0]=0;check(proof(inputs,"a",2017,bytes).is_empty(),"Input reader rejects same-length packed mutation before decode")
		bytes=inputs.get_resource("a",2017);bytes.append(99);check(proof(inputs,"a",2017,bytes).is_empty(),"Input reader rejects appended packed mutation before decode")
		bytes=inputs.get_resource("a",2017);bytes.set(0,0);check(proof(inputs,"a",2017,bytes).is_empty(),"Input reader rejects set() mutation before decode")
	check(inputs.get_resource("missing",2017).is_empty() and not inputs.failure.is_empty(),"Input reader retains failed-read behavior")
	if packets:check(proof(inputs,"a",2017,data()).is_empty(),"Failed input read retires the prior proof")
	source.source_store.clear()
func run() -> void:
	catalog_checks();await coalesced_checks();recorded_checks();input_checks()
	var proof_value:={"success":failures.is_empty(),"checks":checks,"failures":failures,"expect_packets":packets,"scope":"Headless byte-packet digest binding, source-store generation/eviction/remount/fork/coalescing, packed return isolation and recorded checksum preservation; owned local fixtures, no server/graphics/FPS acceptance"}
	var file:=FileAccess.open(str(args.report),FileAccess.WRITE);file.store_string(JSON.stringify(proof_value));file.close();print(JSON.stringify(proof_value));quit(0 if failures.is_empty() else 1)
