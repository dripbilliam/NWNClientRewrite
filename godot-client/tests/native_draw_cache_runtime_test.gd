extends SceneTree
const Assets=preload("res://systems/native_data/asset_service.gd")
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Pool=preload("res://systems/native_render/resource_pool.gd")
const Instance=preload("res://systems/native_render/model_instance.gd")
const Runtime=preload("res://systems/native_render/native_draw_cache_runtime.gd")
var checks:=0
var failures: Array=[]
var packets: Dictionary={}
var options: Dictionary={}
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);print("FAIL ",label)
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:options[pair[0]]=pair[1]
	call_deferred("run")
func authored_model(offset: float=0.0) -> String:
	var lines:=PackedStringArray(["newmodel cache_probe","beginmodelgeom cache_probe","node trimesh body","parent NULL","bitmap NULL","render 1","shadow 1","verts 6000"])
	for triangle in 2000:
		var x:=float(triangle%100)+offset;var y:=float(triangle/100)
		lines.append("%f %f 0"%[x,y]);lines.append("%f %f 0"%[x+0.75,y]);lines.append("%f %f 0"%[x,y+0.75])
	lines.append("faces 2000")
	for triangle in 2000:
		var i:=triangle*3;lines.append("%d %d %d 1 0 0 0 0"%[i,i+1,i+2])
	lines.append("endnode");lines.append("endmodelgeom cache_probe");return "\n".join(lines)+"\n"
func write_model(folder: String,offset: float=0.0) -> void:
	DirAccess.make_dir_recursive_absolute(folder)
	var file:=FileAccess.open(folder.path_join("cache_probe.mdl"),FileAccess.WRITE);file.store_string(authored_model(offset));file.close()
func receive(id: int,result: Dictionary) -> void:packets[id]=result
func request(service) -> Dictionary:
	packets.clear();var id: int=service.request("cache_probe",2002,"static-model")
	var deadline:=Time.get_ticks_msec()+20000
	while not packets.has(id) and Time.get_ticks_msec()<deadline:await process_frame
	return packets.get(id,{"error":"Asset request timed out"})
func settle() -> bool:
	var deadline:=Time.get_ticks_msec()+10000
	while Time.get_ticks_msec()<deadline:
		Runtime.poll()
		var state:=Runtime.snapshot();var pending:=0
		for owner in state.owners:pending+=int(owner.pending_writes)
		if pending==0:return true
		await process_frame
	return false
func run() -> void:
	if not options.has("report") or not options.has("cache-root") or FileAccess.file_exists(options.report):quit(2);return
	check(Runtime.enabled(),"Explicit cache flag is active")
	check(Runtime.budget_bytes()==25*1024*1024*1024,"Default budget is 25 GiB without allocating it")
	var folder:=str(options["cache-root"]);write_model(folder.path_join("raw-a"))
	var source:=Catalog.new();check(source.mount_directory(folder.path_join("raw-a")),"Original authored model catalog mounts")
	var service:=Assets.new();root.add_child(service);service.configure(source);service.cache_directory=folder.path_join("prepared");service.completed.connect(receive)
	var cold: Dictionary=await request(service)
	check(str(cold.get("error","failed")).is_empty(),"Cold actual asset worker prepares original model")
	check(cold.get("native_draw_cache",{}).get("state")=="missing","Cold native artifact is explicitly missing")
	var pool:=Pool.new();var first:=Instance.new();root.add_child(first)
	check(first.install(cold,pool),"Cold original model installs through actual resource pool")
	check(pool.native_draw_captures.is_empty(),"Completed installer does not retain a capture")
	check(await settle(),"Cold complete-cohort writer drains")
	var cache_state:=Runtime.snapshot();var writes:=0
	for owner in cache_state.owners:writes+=int(owner.stats.writes_completed)
	check(writes==1,"One model cohort publishes one artifact")
	var warm: Dictionary=await request(service)
	check(warm.get("native_draw_cache",{}).get("state")=="hit","Second actual asset request loads native artifact")
	check(warm.get("memory_cache_hit",false),"Native buffers coexist with existing complete-bundle cache")
	var warm_pool:=Pool.new();var second:=Instance.new();root.add_child(second)
	check(second.install(warm,warm_pool),"Warm original model installs through actual resource pool")
	check(int(warm_pool.stats.get("native_draw_buffer_hits",0))==1,"Warm pool restores packed buffers rather than add_surface_from_arrays")
	if not first.meshes.is_empty() and not second.meshes.is_empty():
		check(first.meshes[0].mesh.get("_surfaces")==second.meshes[0].mesh.get("_surfaces"),"Real native packed draw streams match cold geometry exactly")
		check(second.meshes[0].mesh.has_meta("native_pick_geometry") and second.meshes[0].mesh.has_meta("native_scene_geometry"),"Warm native geometry retains original pick and collision metadata")
		check(first.meshes[0].mesh!=second.meshes[0].mesh,"Different pools own distinct live mesh resources")
		var original: PackedByteArray=first.meshes[0].mesh.get("_surfaces")[0].vertex_data
		warm.value.nodes[0].mesh.native_draw_buffers.surfaces[0].vertex_data[0]^=1
		check(first.meshes[0].mesh.get("_surfaces")[0].vertex_data==original,"Consumer buffer mutation does not alter earlier live mesh")
	var third: Dictionary=await request(service)
	check(third.get("native_draw_cache",{}).get("state")=="hit","Repeated load survives prior consumer metadata mutation")
	check(not cold.value.nodes[0].mesh.has("native_draw_buffers"),"Warm attachments never mutate earlier decoded owner graphs")
	var persistable: Dictionary=service.bundle_content(third)
	check(not persistable.has("native_draw_cache"),"Runtime scope binding is not a persisted bundle field")
	check(persistable.value.nodes.all(func(row):return not row.get("mesh",{}).has("native_draw_buffers")),"Delivered native buffers are stripped from later generic persistence")
	check(third.value.nodes[0].mesh.has("native_draw_buffers"),"Stripping a persistence view does not mutate delivered model")
	var old_key:=str(cold.get("native_draw_cache",{}).get("descriptor",{}).get("key",""))
	write_model(folder.path_join("raw-b"),5.0);var changed:=Catalog.new();check(changed.mount_directory(folder.path_join("raw-b")),"Changed source has an independent original catalog")
	service.configure(changed);var replacement: Dictionary=await request(service)
	check(str(replacement.get("error","failed")).is_empty() and replacement.get("native_draw_cache",{}).get("state")=="missing","Changed original bytes do not reuse prior native draw artifact")
	check(str(replacement.get("native_draw_cache",{}).get("descriptor",{}).get("key",""))!=old_key,"Source identity changes the artifact key")
	var bad_folder:=folder.path_join("raw-corrupt-texture");DirAccess.make_dir_recursive_absolute(bad_folder)
	var bad_file:=FileAccess.open(bad_folder.path_join("cache_probe.mdl"),FileAccess.WRITE);bad_file.store_string(authored_model(9.0).replace("bitmap NULL","bitmap broken_probe"));bad_file.close()
	bad_file=FileAccess.open(bad_folder.path_join("broken_probe.tga"),FileAccess.WRITE);bad_file.store_buffer(PackedByteArray([1,2]));bad_file.close()
	var missing_texture:=Catalog.new();check(missing_texture.mount_directory(bad_folder),"Actual present-but-corrupt texture catalog mounts")
	service.configure(missing_texture);var failed: Dictionary=await request(service)
	check(not str(failed.get("error","")).is_empty(),"Later original texture corruption remains an explicit failure")
	check(Runtime.snapshot().pending_overlap_reads==0,"A later texture failure joins its already-started native read")
	check(not failed.has("native_draw_cache"),"Failed original model does not gain a displayable cache attachment")
	var main_id:=OS.get_main_thread_id()
	check(Runtime.snapshot().owners.all(func(row):return not row.stats.read_threads.is_empty() and not row.stats.read_threads.has(main_id) and not row.stats.write_threads.has(main_id)),"Native read/write observations report worker thread IDs")
	first.retire();second.retire();await process_frame;pool.clear();warm_pool.clear()
	service.close();service.queue_free();await process_frame
	check(Runtime.snapshot().users==0 and Runtime.snapshot().owners.is_empty() and Runtime.snapshot().pending_overlap_reads==0,"Last native asset service releases owners after joining all read tasks")
	check(Runtime.worker_tasks().is_empty(),"No hidden cache task survives service shutdown")
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"cold":cold.get("phases",{}).get("native_draw_cache",{}),"warm":warm.get("phases",{}).get("native_draw_cache",{}),"cache":cache_state,"network_connections":0,"scope":"Actual native worker/pool model-cache integration, authored one-model source, no representative FPS acceptance"}
	packets.clear();cold.clear();warm.clear();third.clear();replacement.clear();persistable.clear();failed.clear();source=null;changed=null;missing_texture=null
	var file:=FileAccess.open(options.report,FileAccess.WRITE);file.store_string(JSON.stringify(result,"\t"));file.close();print("NATIVE_DRAW_RUNTIME ",checks," checks, ",failures.size()," failures");quit(0 if failures.is_empty() else 1)
