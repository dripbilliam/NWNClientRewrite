extends SceneTree
const Assets=preload("res://systems/native_data/asset_service.gd")
const Store=preload("res://systems/native_data/preparation_store.gd")
const Cache=preload("res://systems/native_data/prepared_cache.gd")
const Pool=preload("res://systems/native_render/resource_pool.gd")
const Prepare=preload("res://systems/native_data/mesh_preparation.gd")
var checks:=0
var failures: Array=[]
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label); print("FAIL: ",label)
func same(a: Variant,b: Variant) -> bool: return Cache.digest(var_to_bytes(a))==Cache.digest(var_to_bytes(b))
func _initialize() -> void: call_deferred("run")
func source() -> PackedByteArray: return "newmodel authored\nbeginmodelgeom authored\nnode trimesh root\nparent NULL\nverts 3\n0 0 0\n1 0 0\n0 0 1\ntverts 3\n0 0 0\n1 0 0\n0 1 0\nfaces 1\n0 1 2 1 0 1 2 0\nendnode\nendmodelgeom authored\n".to_utf8_buffer()
func decode(service,bytes: PackedByteArray,path: String,store) -> Dictionary: return service.decode(bytes,2002,"mdl-actor-packed-v3",path,store)
func decoded(service,bytes: PackedByteArray,path: String,store) -> Dictionary:
	var thread:=Thread.new(); thread.start(decode.bind(service,bytes,path,store)); return thread.wait_to_finish()
func run() -> void:
	var report:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): report=arg.substr(9)
	if report.is_empty() or FileAccess.file_exists(report): quit(2); return
	var folder:=OS.get_temp_dir().path_join("nwn-native-mesh-cache-"+str(OS.get_process_id())+"-"+str(Time.get_ticks_usec())); DirAccess.make_dir_recursive_absolute(folder)
	var main:=Assets.new(); root.add_child(main); main.set_process(false); main.mesh_preparation_enabled=false
	var worker:=Assets.new(); root.add_child(worker); worker.set_process(false); worker.mesh_preparation_enabled=true
	var store:=Store.new(); var bytes:=source(); var raw_sha:=Cache.digest(bytes)
	var legacy:=decoded(main,bytes,folder,store); var cold:=decoded(worker,bytes,folder,store)
	check(str(legacy.error).is_empty() and str(cold.error).is_empty(),"Actual legacy/worker source decoding succeeds")
	check(not legacy.value.nodes[0].mesh.has("native_upload") and cold.value.nodes[0].mesh.native_upload.revision==Prepare.REVISION,"Mode-separated source flights cannot return the wrong derived-data schema")
	check(not legacy.cache_hit and not cold.cache_hit and not cold.memory_decode_hit,"Both modes get a distinct first disk/memory entry")
	check(cold.timings.mesh_preparation.thread!=OS.get_main_thread_id() and cold.timings.mesh_preparation.meshes==1,"Upload arrays are prepared inside an actual source worker")
	var stripped: Dictionary=cold.value.duplicate(true); stripped.nodes[0].mesh.erase("native_upload")
	check(same(stripped,legacy.value),"Only data derivatives are added; original hierarchy/geometry/animation fields remain exact")
	var shared:=decoded(worker,bytes,folder,store)
	check(shared.memory_decode_hit and same(shared.value,cold.value),"Worker source derivatives coalesce/reuse the decoded memory tier")
	var warm:=decoded(worker,bytes,folder,Store.new()); var legacy_warm:=decoded(main,bytes,folder,Store.new())
	check(warm.cache_hit and not warm.memory_decode_hit and not warm.timings.has("mesh_preparation") and same(warm.value,cold.value),"Fresh source owner reloads verified arrays/bounds/planes without recomputing them")
	check(legacy_warm.cache_hit and not legacy_warm.value.nodes[0].mesh.has("native_upload"),"Prepared disk entries cannot alias the legacy model schema")
	var pool:=Pool.new(); pool.use_prepared_geometry=true
	var mesh=pool.geometry(raw_sha,0,warm.value.nodes[0].mesh)
	check(mesh!=null and pool.stats.prepared_mesh_uses==1 and pool.stats.main_mesh_preparations==0,"Fresh disk data reaches real main-thread ArrayMesh publication")
	var fallback:=Pool.new(); fallback.use_prepared_geometry=true; var old_mesh=fallback.geometry(raw_sha,0,legacy_warm.value.nodes[0].mesh)
	check(old_mesh!=null and fallback.stats.main_mesh_preparations==1 and same(mesh.surface_get_arrays(0),old_mesh.surface_get_arrays(0)),"Legacy in-memory consumers retain exact compatible publication fallback")
	var cache:=Cache.new(); cache.configure(folder); var worker_file:=""
	for file in DirAccess.get_files_at(folder):
		var value:=cache.load_data(file.get_basename(),raw_sha,"mdl-actor-packed-v3")
		if not value.is_empty() and value.nodes[0].mesh.has("native_upload"): worker_file=folder.path_join(file)
	check(not worker_file.is_empty(),"Actual persisted worker file is located by verified contents")
	if not worker_file.is_empty():
		var file:=FileAccess.open(worker_file,FileAccess.READ_WRITE); file.seek(file.get_length()-1); var last:=file.get_8(); file.seek(file.get_length()-1); file.store_8(last^1); file.close()
	var repaired:=decoded(worker,bytes,folder,Store.new())
	check(not repaired.cache_hit and str(repaired.error).is_empty() and same(repaired.value,cold.value),"Corrupt derived bytes fail checksum verification and rebuild exact model data")
	var edited:=source().get_string_from_utf8().replace("1 0 0","2 0 0").to_utf8_buffer(); var changed:=decoded(worker,edited,folder,store)
	check(changed.sha256!=cold.sha256 and not changed.memory_decode_hit and not changed.cache_hit and not same(changed.value.nodes[0].mesh.native_upload.positions,cold.value.nodes[0].mesh.native_upload.positions),"Source content changes invalidate both derived tiers and produce new vertex data")
	pool.clear(); fallback.clear(); mesh=null; old_mesh=null
	main.close(); worker.close(); main.queue_free(); worker.queue_free(); await process_frame; await process_frame
	var cleaned:=0
	for file in DirAccess.get_files_at(folder):
		if file.ends_with(".bin") and file.get_basename().length()==64 and file.get_basename().is_valid_hex_number(false): DirAccess.remove_absolute(folder.path_join(file)); cleaned+=1
	check(cleaned==3 and DirAccess.get_files_at(folder).is_empty(),"Only three owned derived/legacy source cache files are created and removed")
	DirAccess.remove_absolute(folder)
	var output:=FileAccess.open(report,FileAccess.WRITE); output.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"publicConnections":0,"scope":"Actual native worker source service, distinct schema identities/flights, verified disk reload, corruption repair, changed-source invalidation and real ArrayMesh publication; no whole-world latency/FPS acceptance"},"\t")); output.close(); quit(0 if failures.is_empty() else 1)
