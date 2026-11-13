extends SceneTree
const Actor=preload("res://systems/native_render/actor_instance.gd")
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Assets=preload("res://systems/native_data/asset_service.gd")
const Pool=preload("res://systems/native_render/resource_pool.gd")
const Source=preload("res://systems/native_render/selection_highlight_source.gd")
const Bounds=preload("res://tools/native_parity/highlighting/native_highlight_bounds_textured.gd")
var extension: Resource
var completed: Dictionary={}
var checks:=0
var failures: Array=[]
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label)
func xyz(value: Vector3) -> Array:return [value.x,value.y,value.z]
func native_point(value: Vector3) -> Array:return [value.x,-value.z,value.y]
func pose(value: Transform3D) -> Dictionary:return {"x":xyz(value.basis.x),"y":xyz(value.basis.y),"z":xyz(value.basis.z),"origin":xyz(value.origin),"determinant":value.basis.determinant()}
func box(value: AABB) -> Dictionary:return {"min":xyz(value.position),"max":xyz(value.end),"size":xyz(value.size)}
func mesh_for(actor: Node3D,index: int) -> Variant:
	for mesh in actor.meshes:
		if mesh.get_meta("native_source_part_index",-1)==index:return mesh
	return null
func matrix_delta(a: Transform3D,b: Transform3D) -> float:
	return maxf(maxf((a.basis.x-b.basis.x).length(),(a.basis.y-b.basis.y).length()),maxf((a.basis.z-b.basis.z).length(),a.origin.distance_to(b.origin)))
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var output:="";var install:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):output=arg.substr(9)
		elif arg.begins_with("--install="):install=arg.substr(10)
	if output.is_empty() or install.is_empty() or FileAccess.file_exists(output):quit(2);return
	extension=load("res://native/particle_kernel.gdextension")
	check(extension!=null and ClassDB.class_exists("NwnModelPoseStorage"),"Approved original pose storage loads without new build")
	var catalog:=Catalog.new();check(catalog.mount_install(install) and catalog.mount_directory("C:/Users/Niflheim/Documents/Neverwinter Nights.0/override",10000000),"Original/profile catalog mounts read-only")
	var service:=Assets.new();root.add_child(service);service.configure(catalog);service.maximum_workers=1;service.cache_directory=output.get_base_dir().path_join("asset-cache");service.completed.connect(func(id,result):completed[id]=result)
	var request:=service.request("c_goldem",2002,"actor-model",{"relevant_tracks":true});var deadline:=Time.get_ticks_msec()+30000
	while not completed.has(request) and Time.get_ticks_msec()<deadline:await process_frame
	var bundle: Dictionary=completed.get(request,{})
	check(not bundle.is_empty() and str(bundle.get("error","unfinished")).is_empty() and bundle.get("sha256")=="2a930d200205e26ae7ddbf0f875c3dc2d73637dc7fc174684ccfe3e2e9ab2082","Exact historical original model prepares")
	if bundle.is_empty() or not str(bundle.get("error","")).is_empty():service.close();service.free();quit(1);return
	var world:=Node3D.new();root.add_child(world);var actor:=Actor.new();actor.actor_alpha_enabled=true;world.add_child(actor);var pool:=Pool.new();pool.native_lighting=true;pool.native_surface_output=true
	check(actor.install([{"bundle":bundle}],pool,2147620731,{},0),"Actual historical Actor installs")
	check(actor.meshes.size()==29,"Actual model has29 physical draw meshes")
	actor.rigs.set_process(false);actor.position=Vector3(-3.5,0,0)
	check(actor.rigs.play_native(actor.object_id,0,"cpause1",1.,0,0.),"Exact retained idle clip is selected")
	actor.rigs._update(0.)
	var camera:=Camera3D.new();world.add_child(camera);camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=16;camera.position=Vector3(9,11,18);camera.look_at(Vector3(0,2,0));camera.current=true
	var gathered:=Source.collect(actor)
	check(gathered.available,"Current production Source.collect runs against actual physical Parts")
	var eligible: Dictionary={}
	for descriptor in gathered.parts:eligible[descriptor.anchor.get_instance_id()]=descriptor
	var rows: Array=[];var original_tree: Array=[];var mismatches: Array=[]
	var parts: Array=actor.rigs.entities[actor.object_id].model_parts[0]
	var pulse:=Bounds.pulse_step(0.,0.,.5,1.,2.5)
	for index in bundle.value.nodes.size():
		var source: Dictionary=bundle.value.nodes[index];var anchor: Node3D=actor.rigs.node_at(actor.object_id,int(parts[index]));var mesh: Variant=mesh_for(actor,index)
		var local: Transform3D=anchor.transform;var rotation:=local.basis.orthonormalized().get_rotation_quaternion()
		var entry:={"index":index,"name":source.name,"parent":source.parent,"mdl_flags":source.flags,"features":source.features,"source_position":source.position,"source_orientation":source.orientation,"source_scale":source.scale,"local_pose":pose(local),"global_pose":pose(anchor.global_transform),"native_local_position":native_point(local.origin),"native_local_quaternion_wxyz":[rotation.w,rotation.x,-rotation.z,rotation.y],"local_scale":xyz(anchor.scale),"current_source_eligible":eligible.has(anchor.get_instance_id()),"runtime_part34":null,"native_runtime_kind":null,"runtime_field_status":"Not observed in original running client; MDL/provenance metadata only"}
		if not source.mesh.is_empty():
			entry.authored_bounds=source.mesh.get("native_bounds");entry.bounds_offset=source.mesh.get("native_bounds_offset");entry.bounds_valid=source.mesh.get("native_bounds_valid");entry.render=source.mesh.get("render");entry.source_alpha=source.get("alpha")
		if mesh!=null:
			entry.mesh_pose=pose(mesh.global_transform);entry.mesh_local_aabb=box(mesh.mesh.get_aabb());entry.mesh_world_aabb=box(mesh.global_transform*mesh.mesh.get_aabb());entry.anchor_mesh_matrix_delta=matrix_delta(anchor.global_transform,mesh.global_transform)
			if entry.anchor_mesh_matrix_delta>0.00001:mismatches.append(index)
		if eligible.has(anchor.get_instance_id()):
			var projection:=Bounds.project(source.mesh.native_bounds,anchor.global_transform,camera.global_position,float(pulse.size),.3,Color.GREEN,.5)
			entry.projected_available=projection.available
			if projection.available:
				var emitted:=AABB(projection.vertices[0],Vector3.ZERO)
				for point in projection.vertices:emitted=emitted.expand(point)
				entry.emitted_world_aabb=box(emitted);entry.emitted_extent=emitted.size.length();entry.projected_vertices=[]
				for point in projection.vertices:entry.projected_vertices.append(xyz(point))
		rows.append(entry)
		original_tree.append({"index":index,"parent":source.parent,"name":source.name,"position":entry.native_local_position,"quaternion_wxyz":entry.native_local_quaternion_wxyz,"scale":anchor.scale.x,"mdl_flags":source.flags,"bounds":source.mesh.get("native_bounds")})
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Private headless actual c_goldem Source.collect input trace. Runtime Part34 and original native conversion/type are explicitly unavailable, never inferred from MDL flags. No scene mutation, screenshot parity, native original execution or performance claim.","model_sha256":bundle.sha256,"source_counts":{"nodes":bundle.value.nodes.size(),"draw_meshes":actor.meshes.size(),"geometry_parts":gathered.geometry_parts,"skin_parts":gathered.skin_parts,"eligible_parts":gathered.parts.size(),"missing":gathered.missing},"camera":{"godot":xyz(camera.global_position),"native":native_point(camera.global_position),"pose":pose(camera.global_transform)},"pulse":pulse,"anchor_mesh_matrix_mismatches":mismatches,"parts":rows,"original_tree_candidate":original_tree}
	actor.retire();service.close();service.free();pool.clear();world.free();await process_frame;await process_frame
	var file:=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify(result,"  ")+"\n");file.close();print(JSON.stringify({"checks":checks,"failures":failures,"source_counts":result.source_counts,"matrix_mismatches":mismatches}));quit(0 if failures.is_empty() else 1)
