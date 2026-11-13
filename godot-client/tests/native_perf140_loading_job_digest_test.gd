extends SceneTree
const Assets=preload("res://systems/native_data/asset_service.gd")
const Prework=preload("res://systems/native_data/prework_store.gd")
const Cache=preload("res://systems/native_data/prepared_cache.gd")
const Store=preload("res://systems/native_data/preparation_store.gd")
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
var checks:=0
var failures: Array=[]
var args: Dictionary={}
var reuse:=false
var packets: Array=[]
class Reader:
	extends RefCounted
	var records: Dictionary={}
	var failure:=""
	var stats: Dictionary={}
	func get_resource(name: String,type: int) -> PackedByteArray:
		var key:=name.to_lower()+":"+str(type);failure="" if records.has(key) else "missing"
		return records[key].duplicate() if failure.is_empty() else PackedByteArray()
func check(value: bool,message: String) -> void:
	checks+=1
	if not value:failures.append(message)
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	reuse=args.get("expect-reuse","false")=="true";call_deferred("run")
func table(value: int=17) -> PackedByteArray:return ("2DA V2.0\n\nValue\n0 "+str(value)+"\n").to_utf8_buffer()
func model() -> PackedByteArray:
	return "newmodel auth_digest\nbeginmodelgeom auth_digest\nnode trimesh root\nparent NULL\nverts 3\n0 0 0\n1 0 0\n0 0 1\ntverts 3\n0 0 0\n1 0 0\n0 1 0\nfaces 1\n0 1 2 1 0 1 2 0\nendnode\nendmodelgeom auth_digest\n".to_utf8_buffer()
func raster() -> PackedByteArray:
	var bytes:=PackedByteArray();bytes.resize(21);bytes.fill(0);bytes[2]=2;bytes[12]=1;bytes[14]=1;bytes[16]=24;bytes[17]=32;bytes[18]=20;bytes[19]=40;bytes[20]=80;return bytes
func decode(service,bytes: PackedByteArray,type: int,decoder: String,path: String,store,sha: String) -> Dictionary:
	return service.call("decode",bytes,type,decoder,path,store,false,sha) if reuse else service.decode(bytes,type,decoder,path,store)
func source_record_checks(service) -> void:
	var raw:=table();var reader:=Reader.new();reader.records["root:2017"]=raw
	var inputs:=Prework.Inputs.new(reader)
	if reuse:inputs.call("remember","root",2017,raw,Cache.digest(raw))
	else:inputs.remember("root",2017,raw)
	check(inputs.snapshot()[0].sha256==Cache.digest(raw),"Remembered root identity stays byte-exact")
	if reuse:
		check(inputs.fingerprint_hint_hits==1 and inputs.fingerprint_computations==0,"A supplied root digest avoids a second hash")
		check(service.known_source_digest(inputs,"ROOT",2017,raw)==Cache.digest(raw),"Just-read proof handles canonical case")
		check(inputs.last_resource_digest("other",2017,raw.size()).is_empty() and inputs.last_resource_digest("root",3,raw.size()).is_empty() and inputs.last_resource_digest("root",2017,raw.size()+1).is_empty(),"Name/type/byte-count mismatches never reuse a digest")
	var read: PackedByteArray=inputs.get_resource("root",2017)
	check(read==raw and inputs.snapshot()[0].sha256==Cache.digest(raw),"Tracked dependency read retains original source proof")
	if reuse:check(inputs.fingerprint_computations==1 and inputs.fingerprint_hint_hits==1,"A dependency computes its proof once")
	read[0]=0
	check(reader.records["root:2017"]==raw,"Mutating a returned packed input cannot alter the provider's bytes")
	var changed:=table(18);reader.records["root:2017"]=changed
	var next: PackedByteArray=inputs.get_resource("root",2017)
	check(inputs.snapshot()[0].sha256==Cache.digest(changed),"A repeated same-size dependency read replaces the proof from actual bytes")
	if reuse:
		check(service.known_source_digest(inputs,"root",2017,next)==Cache.digest(changed),"Decode sees the new same-size dependency digest")
		inputs.get_resource("missing",2017)
		check(inputs.last_resource_digest("root",2017,next.size()).is_empty(),"Failed read invalidates the just-read proof")
		inputs.call("remember","root",2017,changed,"not-a-sha")
		check(inputs.last_resource_digest("root",2017,changed.size())==Cache.digest(changed),"Malformed hints fall back to hashing the real bytes")
func decode_checks(service) -> void:
	for row in [{"bytes":table(),"type":2017,"decoder":"2da"},{"bytes":model(),"type":2002,"decoder":"mdl-actor-v2"},{"bytes":raster(),"type":3,"decoder":"raster"}]:
		var sha:=Cache.digest(row.bytes);var store:=Store.new()
		var first:=decode(service,row.bytes,row.type,row.decoder,"",store,sha)
		var second:=decode(service,row.bytes,row.type,row.decoder,"",store,sha)
		check(first.error.is_empty() and second.error.is_empty() and second.memory_decode_hit,"Actual decoder and warm memory path accept original source")
		check(first.sha256==sha and second.sha256==sha and first.value==second.value,"Reused fingerprint preserves decoded data and identity")
		if reuse:check(first.timings.source_digest_reused and second.timings.source_digest_reused,"Both decoded source paths reuse the supplied digest")
		var malformed:=decode(service,row.bytes,row.type,row.decoder,"",null,"UPPERCASE/INVALID")
		check(malformed.sha256==sha and malformed.value==first.value,"Malformed decoder hint never changes actual content identity")
		store.clear()
	var bytes:=raster();var sha:=Cache.digest(bytes);var path: String=args["cache-root"]
	var cold:=decode(service,bytes,3,"raster",path,null,sha);var warm:=decode(service,bytes,3,"raster",path,null,sha)
	check(cold.error.is_empty() and warm.cache_hit and warm.value==cold.value,"Owned prepared-disk reuse still validates/loads original data")
	var cache:=Cache.new();check(cache.configure(path),"Owned prepared cache configures")
	var file:=FileAccess.open(cache.filename(Cache.key(sha,"raster:3")),FileAccess.READ_WRITE)
	check(file!=null,"Expected original identity locates the prepared entry")
	if file!=null:file.seek(48);var byte:=file.get_8();file.seek(48);file.store_8(byte^1);file.close()
	var repaired:=decode(service,bytes,3,"raster",path,null,sha)
	check(repaired.error.is_empty() and not repaired.cache_hit and repaired.value==cold.value,"Known source digest never bypasses prepared-payload checksum validation/repair")
func write(path: String,bytes: PackedByteArray) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir());var file:=FileAccess.open(path,FileAccess.WRITE);file.store_buffer(bytes);file.close()
func request(service,name: String,type: int,decoder: String) -> Dictionary:
	var id: int=service.request(name,type,decoder);check(id>0,"Worker request admitted")
	var deadline:=Time.get_ticks_msec()+10000
	while packets.is_empty() and Time.get_ticks_msec()<deadline:await process_frame
	check(not packets.is_empty(),"Worker result completes")
	return packets.pop_front() if not packets.is_empty() else {"error":"timeout"}
func actual_job_checks() -> void:
	var path:=ProjectSettings.globalize_path("res://digest-fixtures/first");var other:=ProjectSettings.globalize_path("res://digest-fixtures/other")
	var textured:=model().get_string_from_utf8().replace("parent NULL\n","parent NULL\nbitmap auth_image\n").to_utf8_buffer()
	var changed_raster:=raster();changed_raster[20]=120
	write(path.path_join("auth_digest.mdl"),textured);write(path.path_join("auth_table.2da"),table());write(path.path_join("auth_image.tga"),raster());write(other.path_join("auth_table.2da"),table(18));write(other.path_join("auth_image.tga"),changed_raster)
	var catalog:=Catalog.new();check(catalog.mount_directory(path),"Raw original-data fixture catalog mounts")
	var service:=Assets.new();root.add_child(service);service.maximum_workers=1;service.configure(catalog);service.completed.connect(func(_id,result):packets.append(result))
	var original_model: Dictionary={}
	for row in [["auth_digest",2002,"static-model"],["auth_digest",2002,"actor-model"],["auth_table",2017,"2da"],["auth_image",3,"raster"]]:
		var result: Dictionary=await request(service,row[0],row[1],row[2]);check(result.error.is_empty(),"Actual worker decoder succeeds: "+row[2])
		if row[2]=="static-model":original_model=result
		check(result.sha256==Cache.digest(catalog.get_resource(row[0],row[1])),"Actual worker identity matches authoritative returned bytes: "+row[2])
		if reuse:check(result.timings.get("source_digest_reused",false),"Root worker decode reuses its job digest: "+row[2])
	var old_fork=catalog.fork();var old: PackedByteArray=old_fork.get_resource("auth_table",2017)
	check(catalog.mount_directory(other,20000000),"Higher-priority override mounts")
	var updated: Dictionary=await request(service,"auth_table",2017,"2da")
	check(updated.sha256==Cache.digest(table(18)) and updated.value.orderedRows[0].Value=="18","Catalog override cannot reuse a stale job digest")
	var updated_model: Dictionary=await request(service,"auth_digest",2002,"static-model")
	check(updated_model.error.is_empty() and updated_model.sha256==original_model.sha256 and updated_model.textures.auth_image.sha256==Cache.digest(changed_raster) and updated_model.textures.auth_image.sha256!=original_model.textures.auth_image.sha256,"Dependency override invalidates prepared bundles even when root model bytes are unchanged")
	check(old_fork.get_resource("auth_table",2017)==old,"Old fork retains its original source scope")
	var missing: Dictionary=await request(service,"does_not_exist",2017,"2da")
	check(not missing.error.is_empty(),"Missing data remains an error without a stale fingerprint")
	service.close();service.free();catalog.preparation_cache().clear()
func run() -> void:
	var service:=Assets.new();source_record_checks(service);decode_checks(service);service.free();await actual_job_checks()
	var proof:={"success":failures.is_empty(),"checks":checks,"failures":failures,"expect_reuse":reuse,"scope":"Headless source-fingerprint identity, input tracking, same-size changes, decoder memory/disk checksums, immutable job input reuse and catalog/fork lifecycle; no server/graphics/FPS acceptance"}
	var file:=FileAccess.open(str(args.report),FileAccess.WRITE);file.store_string(JSON.stringify(proof));file.close();print(JSON.stringify(proof));quit(0 if failures.is_empty() else 1)
