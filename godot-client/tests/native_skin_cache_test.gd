extends SceneTree
const Assets=preload("res://systems/native_data/asset_service.gd")
const Store=preload("res://systems/native_data/preparation_store.gd")
const Prepare=preload("res://systems/native_data/skin_preparation.gd")
const Cache=preload("res://systems/native_data/prepared_cache.gd")
var checks:=0
var failures: Array=[]
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label); print("FAIL: ",label)
func same(a: Variant,b: Variant) -> bool: return Cache.digest(var_to_bytes(a))==Cache.digest(var_to_bytes(b))
func _initialize() -> void: call_deferred("run")
func source() -> PackedByteArray:
	return ("newmodel authored\nsetsupermodel authored NULL\nbeginmodelgeom authored\nnode dummy root\nparent NULL\nendnode\nnode dummy hip\nparent root\nposition 0 0 1\nendnode\nnode skin cloth\nparent root\nverts 3\n0 0 0\n1 0 0\n0 0 1\ntverts 3\n0 0 0\n1 0 0\n0 1 0\nfaces 1\n0 1 2 1 0 1 2 0\nweights 3\nhip 0.7 root 0.3\nhip 1\nroot 0\nendnode\nendmodelgeom authored\n").to_utf8_buffer()
func decoded(service,bytes: PackedByteArray,directory: String,store) -> Dictionary:
	var thread:=Thread.new(); thread.start(service.decode.bind(bytes,2002,"mdl-actor-packed-v3",directory,store))
	while thread.is_alive(): await process_frame
	return thread.wait_to_finish()
func skin(model: Dictionary) -> Dictionary:
	for node in model.nodes:
		if node.has("skin"): return node.skin
	return {}
func run() -> void:
	var report:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): report=arg.substr(9)
	if report.is_empty() or FileAccess.file_exists(report): quit(2); return
	var directory:=OS.get_environment("TEMP").path_join("nwn-native-skin-cache-"+str(OS.get_process_id())+"-"+str(Time.get_ticks_usec()))
	var reference:=Assets.new(); root.add_child(reference); reference.set_process(false); reference.skin_preparation_enabled=false
	var worker:=Assets.new(); root.add_child(worker); worker.set_process(false); worker.skin_preparation_enabled=true
	var bytes:=source(); var sha:=Cache.digest(bytes); var store:=Store.new()
	var legacy: Dictionary=await decoded(reference,bytes,directory,store); var cold: Dictionary=await decoded(worker,bytes,directory,store)
	check(str(legacy.error).is_empty() and str(cold.error).is_empty(),"Both actual worker decoder modes accept authored original skin data")
	check(not skin(legacy.value).has("native_upload") and skin(cold.value).native_upload.revision==Prepare.REVISION,"Same source bytes never alias legacy/worker skin schemas in memory or disk")
	check(not legacy.cache_hit and not cold.cache_hit and not cold.memory_decode_hit,"Both distinct derived schemas are cold on first use")
	check(cold.timings.mesh_preparation.skins==1 and cold.timings.mesh_preparation.skin_vertices==3 and cold.timings.mesh_preparation.skin_fallbacks.is_empty() and cold.timings.mesh_preparation.thread!=OS.get_main_thread_id(),"Skin streams are created by an actual source worker with no preparation fallback")
	var stripped: Dictionary=cold.value.duplicate(true); skin(stripped).erase("native_upload")
	check(same(stripped,legacy.value),"Removing only the derivative restores the exact original parsed model graph")
	var shared: Dictionary=await decoded(worker,bytes,directory,store)
	check(shared.memory_decode_hit and same(shared.value,cold.value),"Immutable skin streams reuse/coalesce through the existing source memory tier")
	var warm: Dictionary=await decoded(worker,bytes,directory,Store.new()); var legacy_warm: Dictionary=await decoded(reference,bytes,directory,Store.new())
	check(warm.cache_hit and not warm.memory_decode_hit and not warm.timings.has("mesh_preparation") and same(warm.value,cold.value),"Fresh source owner reloads verified typed skin streams without repeating calculations")
	check(legacy_warm.cache_hit and not skin(legacy_warm.value).has("native_upload"),"Legacy warm cache cannot receive the worker schema")
	var cache:=Cache.new(); cache.configure(directory); var prepared_path:=""
	for file in DirAccess.get_files_at(directory):
		var value:=cache.load_data(file.get_basename(),sha,"mdl-actor-packed-v3")
		if not value.is_empty() and skin(value).has("native_upload"): prepared_path=directory.path_join(file)
	check(not prepared_path.is_empty(),"Persisted skin file is located by verified source identity and derivative schema")
	if not prepared_path.is_empty():
		var file:=FileAccess.open(prepared_path,FileAccess.READ_WRITE); file.seek(file.get_length()-1); var last:=file.get_8(); file.seek(file.get_length()-1); file.store_8(last^1); file.close()
	var repaired: Dictionary=await decoded(worker,bytes,directory,Store.new())
	check(not repaired.cache_hit and str(repaired.error).is_empty() and same(repaired.value,cold.value),"Corrupted skin cache bytes rebuild the exact original derivative")
	var edited:=source().get_string_from_utf8().replace("1 0 0","2 0 0").to_utf8_buffer(); var changed: Dictionary=await decoded(worker,edited,directory,store)
	check(changed.sha256!=cold.sha256 and not changed.memory_decode_hit and not changed.cache_hit and not same(skin(changed.value).native_upload.positions,skin(cold.value).native_upload.positions),"Changed source geometry invalidates both immutable skin tiers")
	reference.close(); worker.close(); reference.queue_free(); worker.queue_free(); await process_frame; await process_frame
	var count:=0
	for file in DirAccess.get_files_at(directory):
		if str(file).ends_with(".bin") and str(file).get_basename().is_valid_hex_number(false): DirAccess.remove_absolute(directory.path_join(file)); count+=1
	check(count==3 and DirAccess.get_files_at(directory).is_empty() and DirAccess.remove_absolute(directory)==OK,"Only three owned cache entries are published atomically and cleaned")
	var output:=FileAccess.open(report,FileAccess.WRITE); output.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"public_connections":0,"scope":"Actual source workers, distinct skin derivative schema identities/flights, byte-exact original fields, memory reuse, verified fresh-owner warm disk reload, corruption repair and edited-source invalidation. No world/FPS acceptance."},"\t")); output.close(); print("NATIVE_SKIN_CACHE ",checks," checks"); quit(0 if failures.is_empty() else 1)
