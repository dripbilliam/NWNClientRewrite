extends SceneTree
# Actual reported server MDLs/PWKs through native preparation, animation and
# prediction geometry. No public login, area renderer or FPS measurement.
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Assets=preload("res://systems/native_data/asset_service.gd")
const Pool=preload("res://systems/native_render/resource_pool.gd")
const Placeable=preload("res://systems/native_render/placeable_instance.gd")
const Helper=preload("res://systems/native_data/blocker_helper.gd")
const Walkmesh=preload("res://systems/native_data/object_surface.gd")
const Collision=preload("res://systems/native_render/drive_collision.gd")
var checks:=0
var failures: Array=[]
var results: Dictionary={}
var observations: Array=[]
var report_path:=""
var retained_extension: Resource
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label);print("FAIL ",label)
func _initialize() -> void:run.call_deferred()
func await_job(service: Node,id: int) -> Dictionary:
	var deadline:=Time.get_ticks_msec()+15000
	while not results.has(id) and Time.get_ticks_msec()<deadline:await process_frame
	return results.get(id,{"error":"Original resource worker did not complete"})
func collision_hit(shape: Dictionary) -> bool:
	# Exercise the same production obstacle narrow phase on a source PWK face.
	for triangle in shape.get("triangles",[]):
		var middle: Vector3=(triangle.a+triangle.b+triangle.c)/3.0
		var normal: Vector2=Vector2(triangle.b.y-triangle.a.y,triangle.a.x-triangle.b.x).normalized()
		if normal.length_squared()==0.0:continue
		if Collision.hits(Vector2(middle.x,middle.y)-normal,Vector2(middle.x,middle.y)+normal,triangle,0.05,shape.min.z-0.1,shape.max.z+0.1):return true
	return false
func run() -> void:
	var manifest_path:="";var cache:=""
	for value in OS.get_cmdline_user_args():
		if value.begins_with("--assets-manifest="):manifest_path=value.substr(18)
		elif value.begins_with("--report="):report_path=value.substr(9)
		elif value.begins_with("--cache="):cache=value.substr(8)
		elif value=="--existing-kernel":retained_extension=load("res://native/particle_kernel.gdextension")
	if manifest_path.is_empty() or report_path.is_empty() or FileAccess.file_exists(report_path):quit(2);return
	var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	var catalog:=Catalog.new()
	check(catalog.mount_install("C:/Users/Niflheim/Desktop/Tools/Local Tools/FullDecomp/NwnRootInstall"),"Original installed fallback providers mount read-only")
	check(catalog.mount_directory(manifest.files[0].file.get_base_dir(),10000000),"Exact retained server model/table/PWK fixture mounts")
	var service:=Assets.new();root.add_child(service);service.configure(catalog);service.cache_directory=cache;service.maximum_workers=1
	service.completed.connect(func(id,result):results[id]=result)
	var pool:=Pool.new();pool.unshaded=true
	var collision:=Collision.new();root.add_child(collision);collision.set_process(false)
	for entry in manifest.selected:
		var id: int=entry.observed[0].id;var model: String=entry.model
		var bundle: Dictionary=await await_job(service,service.request(model,2002,"actor-model",{"relevant_tracks":true}))
		check(str(bundle.get("error","missing")).is_empty(),model+": actual native model preparation")
		if not str(bundle.get("error","missing")).is_empty():continue
		check(bundle.sha256==entry.model_sha256,model+": exact received-table resource identity")
		var original_bundle:=var_to_bytes(bundle.value)
		var state: Dictionary=entry.observed[0].duplicate(true);state.appearance=entry.appearance;state.erase("id");state.erase("name")
		var original_state:=state.duplicate(true)
		var instance:=Placeable.new();root.add_child(instance)
		check(instance.install_placeable(bundle,pool,id,state),model+": real placeable physical rig installs received OFF74")
		if instance.rigs==null:instance.retire();continue
		instance.rigs.set_process(false);instance.rigs._update(0.0)
		var part: Node3D=instance.rigs.node_for(id,0,"visible")
		check(is_instance_valid(part),model+": original authored visible Part resolves")
		if not is_instance_valid(part):instance.retire();continue
		check(absf(part.position.y+10.95)<0.00001,model+": authored OFF places helper below scene at nativeZ-10.95")
		check(instance.identified_blocker,model+": exact helper category includes reported server asset")
		var walkmesh:=Walkmesh.new();var pwk_file:=""
		for file in manifest.files:
			if file.name==model and int(file.type)==2053:pwk_file=file.file
		var pwk: Dictionary=walkmesh.parse(FileAccess.get_file_as_bytes(pwk_file)) if not pwk_file.is_empty() else {}
		check(not pwk.is_empty() and walkmesh.failure.is_empty() and not pwk.states[0].faces.is_empty(),model+": original independent PWK collision loads")
		if pwk.is_empty():instance.retire();continue
		var original_walkmesh:=var_to_bytes(pwk)
		collision.models[model+":placeable"]=pwk
		var object:={"id":id,"objectType":9,"replicated":state}
		var spec:={"model":model,"door":false,"state":0}
		var shape:=collision.obstacle(id,object,spec)
		check(not shape.is_empty() and collision_hit(shape),model+": production collision narrow phase blocks source walkmesh before toggle")
		var shape_bytes:=var_to_bytes(shape)
		instance.set_show_blockers(true);instance.rigs._update(0.0)
		check(absf(part.position.y-0.05)<0.00001 and instance.received_animation==74,model+": saved diagnostic can reveal identified helper without editing received OFF")
		check(is_same(shape,collision.obstacle(id,object,spec)) and collision_hit(shape) and var_to_bytes(shape)==shape_bytes,model+": diagnostic keeps same active production collision object")
		instance.set_show_blockers(false);instance.rigs._update(0.0)
		check(absf(part.position.y+10.95)<0.00001 and collision_hit(collision.obstacle(id,object,spec)),model+": diagnostic off restores native OFF while collision still blocks")
		check(state==original_state and var_to_bytes(pwk)==original_walkmesh and var_to_bytes(bundle.value)==original_bundle,model+": received state and original render/collision source data remain unchanged")
		var changed:=bundle.duplicate();changed.sha256="unidentified-server-content"
		check(not Helper.identified(changed),model+": resource name alone cannot classify modified content")
		observations.append({"model":model,"sha256":bundle.sha256,"native_lifetime":id,"off_local_z":part.position.y,"collision_triangles":shape.triangles.size(),"received_animation":instance.received_animation,"diagnostic_category":instance.identified_blocker})
		instance.retire();await process_frame
	check(not Helper.identified({"resource_name":"white_cube","sha256":manifest.selected[0].model_sha256}),"Unrelated white/untextured asset is not classified")
	service.close();service.free();collision.free();pool.clear();await process_frame;await process_frame
	var report:={"success":failures.is_empty(),"checks":checks,"failures":failures,"observations":observations,"server_connections":0,"gpu_claim":false,"scope":"Actual reported MDLs/PWKs through existing preparation/rig/collision; no claim of public-server visual comparison"}
	FileAccess.open(report_path,FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("NATIVE_LIVE_BLOCKERS ",checks," checks ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
