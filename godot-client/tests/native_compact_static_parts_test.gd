extends SceneTree
const Instance=preload("res://systems/native_render/model_instance.gd")
const Pool=preload("res://systems/native_render/resource_pool.gd")
const Assets=preload("res://systems/native_data/asset_service.gd")
const Recorded=preload("res://systems/native_data/recorded_catalog.gd")
const Cache=preload("res://systems/native_data/prepared_cache.gd")
const Query=preload("res://systems/native_render/projectile_scene.gd")
var checks:=0
var failures: Array=[]
var results: Dictionary={}
var observations: Array=[]
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label); print("FAIL: ",label)
func _initialize() -> void: call_deferred("run")
func values(pose: Transform3D) -> Array:
	var out: Array=[]
	for vector in [pose.basis.x,pose.basis.y,pose.basis.z,pose.origin]:
		for value in [vector.x,vector.y,vector.z]: out.append(0.0 if value==0 else value)
	return out
func relative(node: Node3D,owner: Node3D) -> Transform3D:
	var pose:=Transform3D.IDENTITY; var cursor: Node=node
	while cursor!=owner:
		if cursor is Node3D: pose=cursor.transform*pose
		cursor=cursor.get_parent()
	return pose
func state(owner) -> Dictionary:
	var meshes: Array=[]; var parts: Array=[]
	for part in owner.parts: parts.append([values(part.transform),part.get_meta("native_part_name"),part.get_meta("native_part_parent"),part.get_meta("native_part_area")])
	for mesh in owner.meshes:
		var arrays: Array=[]
		for surface in mesh.mesh.get_surface_count(): arrays.append(mesh.mesh.surface_get_arrays(surface))
		meshes.append([arrays,values(relative(mesh,owner)),mesh.mesh.get_aabb(),mesh.cast_shadow,mesh.visible,mesh.material_override.albedo_color,mesh.material_override.transparency])
	return {"parts":parts,"meshes":meshes,"limitations":owner.limitations}
func image_bytes(instance) -> PackedByteArray:
	var viewport:=SubViewport.new(); viewport.size=Vector2i(320,240); viewport.own_world_3d=true; viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS; root.add_child(viewport); viewport.add_child(instance)
	instance.process_mode=Node.PROCESS_MODE_DISABLED
	var bounds:=AABB(); var valid:=false
	for mesh in instance.meshes:
		var box: AABB=mesh.global_transform*mesh.mesh.get_aabb(); bounds=bounds.merge(box) if valid else box; valid=true
	var camera:=Camera3D.new(); viewport.add_child(camera); camera.near=0.01; camera.far=1000; camera.fov=45
	var extent:=maxf(1.0,bounds.size.length()); var center:=bounds.get_center(); camera.position=center+Vector3(1,0.8,1)*extent; camera.look_at(center); camera.current=true
	await process_frame; await process_frame; await RenderingServer.frame_post_draw
	var pixels:=viewport.get_texture().get_image().get_data(); instance.reparent(root,false); viewport.free(); await process_frame; return pixels
func run() -> void:
	var report:=""; var catalog_path:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): report=arg.substr(9)
		elif arg.begins_with("--catalog="): catalog_path=arg.substr(10)
	if report.is_empty() or catalog_path.is_empty() or FileAccess.file_exists(report) or DisplayServer.get_name()=="headless": quit(2); return
	var archive:="res://backups/native-loading-fine-stream-spans-v1.zip"; var zip:=ZIPReader.new()
	check(FileAccess.get_sha256(archive)=="9678a82fe940655b8d0b33429af995d46d8ca11c5b22619a77ef33c0764a1da9","Authored pre-candidate checkpoint is pinned")
	check(zip.open(archive)==OK,"Pre-candidate original scene implementation opens")
	var code:=zip.read_file("systems/native_render/model_instance.gd"); zip.close()
	check(Cache.digest(code)=="def9a1196a539ad563f59761e4e770af362a39bf90c4b704209e22084ce132a9","Exact previous physical Part implementation is pinned")
	var reference:=GDScript.new(); reference.source_code=code.get_string_from_utf8(); check(reference.reload()==OK,"Unchanged previous implementation compiles")
	var catalog:=Recorded.new(); check(catalog.mount(catalog_path),"Sealed original model/texture catalog mounts without fallback")
	var service:=Assets.new(); root.add_child(service); service.configure(catalog); service.completed.connect(func(id,result):results[id]=result)
	var orphan_baseline:=int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	for name in ["ttu01_m01_04","ttu01_l08_01","ttu01_a02_03"]:
		var id:=service.request(name,2002,"static-model"); var deadline:=Time.get_ticks_msec()+60000
		while not results.has(id) and Time.get_ticks_msec()<deadline: await process_frame
		check(results.has(id),name+": original source worker completes")
		if not results.has(id): continue
		var bundle: Dictionary=results[id]; results.erase(id)
		check(str(bundle.error).is_empty() and not bundle.value.nodes.any(func(row):return row.has("reference") or row.has("emitter")),name+": original geometry is available without nondeterministic effects")
		var source_sha:=Cache.digest(var_to_bytes(bundle)); var pool:=Pool.new(); pool.unshaded=true
		var old=reference.new(); var current:=Instance.new(); pool.compact_static_parts=true
		check(old.install(bundle,pool) and current.install(bundle,pool),name+": both direct source layouts install")
		check(Cache.digest(var_to_bytes(state(old)))==Cache.digest(var_to_bytes(state(current))),name+": exact physical Part poses/metadata and root-space GPU streams/material state")
		var before: int=old.find_children("*","",true,false).size(); var after: int=current.find_children("*","",true,false).size()
		check(after<before and old.parts.size()==current.parts.size() and old.meshes.size()==current.meshes.size(),name+": fewer scene nodes with every physical Part and render surface preserved")
		check(current.meshes.all(func(mesh):return old.meshes.any(func(other):return other.mesh==mesh.mesh and other.material_override==mesh.material_override)),name+": only immutable original mesh/material resources are shared")
		var a: PackedByteArray=await image_bytes(old); var b: PackedByteArray=await image_bytes(current)
		check(not a.is_empty() and a==b,name+": actual textured GPU pixels are byte-exact")
		var hits:=0
		for mesh in old.meshes.slice(0,12):
			var data=mesh.mesh.get_meta("native_scene_geometry"); var face: Array=data.face(0)
			var p:=Query.engine(face[0]); var q:=Query.engine(face[1]); var r:=Query.engine(face[2]); var center: Vector3=mesh.global_transform*((p+q+r)/3.0)
			var normal: Vector3=mesh.global_basis*((q-p).cross(r-p).normalized())
			if normal.length_squared()<0.00001: continue
			var start:=Query.native(center+normal*4); var end:=Query.native(center-normal*4)
			var first: Variant=Query.model_hit(old,start,end,true); var second: Variant=Query.model_hit(current,start,end,true)
			check(JSON.stringify(first)==JSON.stringify(second),name+": original face/normal query agrees across private Part layouts")
			if first!=null: hits+=1
		check(hits>0,name+": query comparison includes actual original polygon hits")
		pool.compact_static_parts=false; var separate=pool.model_template(bundle); pool.compact_static_parts=true; var compact=pool.model_template(bundle)
		check(separate!=compact,name+": template identity isolates node policies")
		var one=compact.create(); var two=compact.create(); root.add_child(one); root.add_child(two)
		check(one.parts.size()==old.parts.size() and one.meshes.size()==old.meshes.size() and one.pick_surfaces.all(func(part):return not one.meshes.has(part)),name+": packed clone preserves Parts without duplicate collision memberships")
		var saved: Vector3=two.parts[-1].position; one.parts[-1].position+=Vector3(1,2,3)
		check(two.parts[-1].position==saved and one.parts[-1]!=two.parts[-1],name+": each packed physical instance stays independent")
		check(Cache.digest(var_to_bytes(bundle))==source_sha,name+": original source remains unchanged")
		observations.append({"model":name,"source":bundle.sha256,"before_nodes":before,"after_nodes":after,"parts":old.parts.size(),"meshes":old.meshes.size(),"physical_hits":hits})
		one.free(); two.free(); old.free(); current.free(); pool.clear(); await process_frame; await process_frame
	service.close(); service.free(); results.clear(); await process_frame; await process_frame
	check(int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))==orphan_baseline,"Workers, private models and packed owners leave no orphan nodes")
	var out:=FileAccess.open(report,FileAccess.WRITE); out.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"observations":observations,"public_connections":0,"scope":"Hash-pinned previous authored Part layout versus optional compact leaf layout using actual sealed original geometry/textures, exact physical/GPU source state, real GPU pixel comparison, polygon queries, packed private ownership and cleanup. No performance claim."},"\t")); out.close(); quit(0 if failures.is_empty() else 1)
