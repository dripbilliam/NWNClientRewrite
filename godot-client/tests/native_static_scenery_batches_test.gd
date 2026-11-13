extends SceneTree
const Batches=preload("res://systems/native_render/static_scenery_batches.gd")
const NativeMaterial=preload("res://systems/native_render/native_model_material.gd")
const Geometry=preload("res://systems/native_render/scene_geometry.gd")
const Query=preload("res://systems/native_render/projectile_scene.gd")
class Tile:
	extends Node3D
	var meshes: Array=[]
	var pick_surfaces: Array=[]
	var limitations: Array=[]
var checks:=0
var failures: Array=[]
var receipt:=""
var captured: Dictionary={}
var graphics:=false
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label)
func _initialize() -> void:call_deferred("run")
func material() -> ShaderMaterial:
	var value:=NativeMaterial.new();value.configure(StandardMaterial3D.new(),[1.0,1.0,1.0],[0.0,0.0,0.0]);return value
func mesh_resource() -> ArrayMesh:
	var geometry:=Geometry.new();geometry.configure({"vertices":PackedFloat32Array([0,0,0,2,0,0,0,2,0]),"indices":PackedInt32Array([0,1,2]),"native_planes":PackedFloat32Array([0,0,1,0]),"native_surface_types":PackedInt32Array([0])})
	var data: Array=[];data.resize(Mesh.ARRAY_MAX);data[Mesh.ARRAY_VERTEX]=PackedVector3Array([Vector3.ZERO,Vector3(2,0,0),Vector3(0,0,-2)]);data[Mesh.ARRAY_NORMAL]=PackedVector3Array([Vector3.UP,Vector3.UP,Vector3.UP]);data[Mesh.ARRAY_INDEX]=PackedInt32Array([0,2,1])
	var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,data);mesh.set_meta("native_scene_geometry",geometry);return mesh
func tile(parent: Node,id: int,position_value: Vector3,mesh: Mesh,mat: Material) -> Tile:
	var value:=Tile.new();value.position=position_value;value.set_meta("native_tile_index",id);parent.add_child(value)
	var shape:=MeshInstance3D.new();shape.mesh=mesh;shape.material_override=mat;shape.set_meta("native_mesh_source",{"parsed_render":true,"native_tilefade_available":true,"native_tilefade":0});shape.set_meta("native_part_index",3);value.add_child(shape);value.meshes=[shape]
	return value
func flush_all(owner: Node) -> void:
	for _index in 200:
		if owner.dirty.is_empty():return
		owner.flush(100.0,100)
	check(false,"Dirty group queue is bounded and drains")
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):receipt=arg.substr(9)
		if arg=="--require-vulkan":graphics=true
	if receipt.is_empty() or FileAccess.file_exists(receipt):quit(2);return
	var scope:=Node3D.new();root.add_child(scope)
	if graphics:
		Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
		var camera:=Camera3D.new();scope.add_child(camera);camera.position=Vector3(10,20,20);camera.look_at(Vector3(10,0,0));camera.current=true
		var sun:=DirectionalLight3D.new();scope.add_child(sun);sun.rotation_degrees=Vector3(-50,-30,0)
		check(RenderingServer.get_current_rendering_method()=="forward_plus" and RenderingServer.get_current_rendering_driver_name()=="vulkan","Actual renderer is Vulkan Forward+")
		check(DisplayServer.window_get_current_screen()!=DisplayServer.get_primary_screen() and DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS) and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"Graphical check opens unfocused on secondary monitor with visible mouse")
	var batch:=Batches.new();scope.add_child(batch)
	var mesh:=mesh_resource();var mat:=material()
	var first:=tile(scope,0,Vector3(1,0,1),mesh,mat);var second:=tile(scope,1,Vector3(11,0,1),mesh,mat)
	var light:=OmniLight3D.new();first.add_child(light);light.light_color=Color.ORANGE;light.omni_range=8.0
	var first_pose: Transform3D=first.meshes[0].global_transform
	var first_hit: Variant=Query.model_hit(first,[1.5,-0.5,3.0],[1.5,-0.5,-3.0],true,false)
	check(first_hit!=null,"Actual original collision predicate hits before batching")
	check(batch.eligibility(first,first.meshes[0]).is_empty(),"Opaque native static surface is eligible")
	batch.consider_tile(0,first);batch.consider_tile(1,second)
	check(batch.members.size()==2 and batch.groups.size()==1,"Shared mesh and material in same spatial cell share one group")
	check(first.meshes[0].layers==1 and second.meshes[0].layers==1,"Original draws remain until replacement publication")
	flush_all(batch)
	var group: Dictionary=batch.groups.values()[0];var draw: MultiMeshInstance3D=group.geometry
	check(is_instance_valid(draw) and draw.multimesh.instance_count==2,"Actual MultiMesh draw contains both placements")
	check(first.meshes[0].layers==1 and second.meshes[0].layers==1 and first.meshes[0].get_meta("native_static_batch_draw",false) and second.meshes[0].get_meta("native_static_batch_draw",false),"Published replacement owns native drawing while preserving original layers")
	check(first.meshes[0].visible and second.meshes[0].visible,"Physical source visibility stays unchanged")
	check(first.meshes[0].global_transform==first_pose,"Original physical transform remains exact")
	check(draw.multimesh.mesh==mesh and draw.material_override==mat,"Original immutable mesh and native material resources are shared")
	# Pinned headless renderer's MultiMesh get_transform returns identity. Verify
	# the exact staged input here; real Vulkan readback/appearance is a separate gate.
	check(group.rows[0].pose==batch.global_transform.affine_inverse()*first_pose,"Staged instance world transform matches original source")
	check(Query.model_hit(first,[1.5,-0.5,3.0],[1.5,-0.5,-3.0],true,false)==first_hit,"Original polygon hit and normal remain equal after drawing replacement")
	check(light.get_parent()==first and light.light_color==Color.ORANGE and light.omni_range==8.0,"Original active light remains privately owned and unchanged")
	check(first.meshes[0].get_meta("native_part_index")==3 and first.meshes[0].mesh.get_meta("native_scene_geometry")!=null,"Part identity and collision geometry remain on original source")
	check(batch.snapshot().nominal_instance_reduction==1,"Two source instances become one explicit group in a cell")
	if graphics:
		await process_frame;await process_frame
		check(draw.multimesh.get_instance_transform(0)==batch.global_transform.affine_inverse()*first_pose,"Actual Vulkan MultiMesh readback matches original world transform")
		captured.vulkan_transform=str(draw.multimesh.get_instance_transform(0))
		var image:=root.get_texture().get_image();check(not image.is_empty(),"Vulkan viewport produced an actual image")
		image.save_png(receipt.get_basename()+".png")
	var combined: AABB=draw.multimesh.custom_aabb
	check(combined.encloses(first_pose*mesh.get_aabb()) and combined.encloses(second.meshes[0].global_transform*mesh.get_aabb()),"Cell bounds conservatively include both actual mesh bounds")
	var outside:=tile(scope,2,Vector3(31,0,1),mesh,mat);batch.consider_tile(2,outside);flush_all(batch)
	check(batch.groups.size()==2 and outside.meshes[0].layers==1,"A separate spatial cell stays independent and singletons keep normal drawing")
	var distinct_material:=material();var distinct:=tile(scope,3,Vector3(12,0,2),mesh,distinct_material);batch.consider_tile(3,distinct);flush_all(batch)
	check(batch.groups.size()==3 and distinct.meshes[0].layers==1,"Different material identity is not merged")
	var transformed:=tile(scope,4,Vector3(4,0,4),mesh,mat);transformed.rotation.y=PI*0.5;transformed.scale=Vector3.ONE*2.0
	check(batch.eligibility(transformed,transformed.meshes[0]).is_empty(),"Positive uniform rotated/scaled placements are eligible")
	batch.consider_tile(4,transformed);flush_all(batch)
	check(batch.snapshot().active_batched_surfaces==3 and batch.snapshot().nominal_instance_reduction==2,"Later same-cell placement replenishes a live group")
	check(draw!=group.geometry and group.geometry.multimesh.instance_count==3,"Dirty group replacement contains exactly current members")
	var rejected:=tile(scope,5,Vector3.ZERO,mesh,mat)
	for feature in ["skin","animated-mesh","dangly","reference","emitter"]:
		rejected.limitations=[feature];check(batch.eligibility(rejected,rejected.meshes[0])=="dynamic-model-"+feature,"Dynamic "+feature+" keeps existing model renderer")
	rejected.limitations=[]
	var source: MeshInstance3D=rejected.meshes[0]
	source.hide();check(batch.eligibility(rejected,source)=="source-not-visible","Invisible source is not resurrected");source.show()
	source.layers=0;check(batch.eligibility(rejected,source)=="source-render-layers-empty","Intentionally empty render layers remain empty");source.layers=1
	source.material_overlay=mat;check(batch.eligibility(rejected,source)=="overlay-or-instance-transparency","Overlay keeps individual renderer");source.material_overlay=null
	source.transparency=0.25;check(batch.eligibility(rejected,source)=="overlay-or-instance-transparency","Per-instance transparency keeps individual renderer");source.transparency=0.0
	source.visibility_range_end=50.0;check(batch.eligibility(rejected,source)=="custom-visibility-or-sorting","Visibility range keeps individual renderer");source.visibility_range_end=0.0
	source.sorting_offset=0.1;check(batch.eligibility(rejected,source)=="custom-visibility-or-sorting","Special sorting keeps individual renderer");source.sorting_offset=0.0
	source.material_override=StandardMaterial3D.new();check(batch.eligibility(rejected,source)=="material-not-native-static","Unknown shader semantics keep individual renderer");source.material_override=mat
	var provenance: Dictionary=source.get_meta("native_mesh_source");provenance.native_tilefade=2
	check(batch.eligibility(rejected,source)=="authored-render-or-tilefade","Native authored tilefade2 keeps individual renderer")
	provenance.native_tilefade=4;check(batch.eligibility(rejected,source)=="authored-render-or-tilefade","Native authored tilefade4 keeps individual renderer")
	provenance.erase("native_tilefade");check(batch.eligibility(rejected,source)=="authored-render-or-tilefade","Missing authored flags stay explicit")
	provenance.native_tilefade=0
	rejected.scale=Vector3(-1,1,1);check(batch.eligibility(rejected,source)=="mirrored-sheared-or-singular-transform","Mirrored front-face behavior stays on original renderer")
	rejected.scale=Vector3(2,1,1);check(batch.eligibility(rejected,source)=="mirrored-sheared-or-singular-transform","Nonuniform transform stays on original renderer")
	rejected.scale=Vector3.ONE
	var fog_mat:=material();fog_mat.native_surface_output=true;fog_mat.native_tile_fog_enabled=true;source.material_override=fog_mat
	check(batch.eligibility(rejected,source)=="dynamic-per-tile-fog","Dynamic per-tile uniform semantics retain individual renderer")
	fog_mat.native_tile_fog_enabled=false;fog_mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	check(batch.eligibility(rejected,source)=="blended-material","Blended sorting retains individual renderer")
	fog_mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	check(batch.eligibility(rejected,source).is_empty(),"Native alpha-scissor semantics support instancing")
	fog_mat.next_pass=mat;check(batch.eligibility(rejected,source)=="material-pass-order","Material next pass retains individual renderer");fog_mat.next_pass=null
	source.material_override=mat
	var prior_members:=batch.members.size();batch.consider_tile(99,rejected)
	check(batch.members.size()==prior_members,"Mismatched authored tile identity is not enrolled")
	var original_group: Dictionary=batch.groups.values()[0]
	first.hide()
	check(first.meshes[0].layers==1 and not first.visible,"Hiding source owner immediately withdraws its draw and restores original layers")
	check(batch.snapshot().withdrawn_surfaces>=1,"Visibility event updates sparse membership")
	flush_all(batch)
	first.show();check(first.meshes[0].layers==1,"Re-entry uses intact original renderer without resurrecting a stale batch slot")
	second.meshes[0].hide();check(second.meshes[0].layers==1,"Individual source hide is detected without a world scan")
	flush_all(batch)
	check(transformed.meshes[0].layers==1,"A remaining singleton falls back to its exact original draw")
	second.meshes[0].show()
	batch.clear();check(batch.members.is_empty() and batch.groups.is_empty() and batch.dirty.is_empty(),"Area retirement clears all draw membership")
	check(first.meshes[0].layers==1 and second.meshes[0].layers==1 and transformed.meshes[0].layers==1,"Area retirement restores all source draw layers")
	batch.consider_tile(0,first);batch.consider_tile(1,second);flush_all(batch)
	check(batch.snapshot().active_batched_surfaces==2,"A fresh scope can reuse unchanged original model owners")
	batch.withdraw_model(first,"native-fog-or-authored-transform-change")
	first.position.y=2.0;first.meshes[0].layers=2;first.meshes[0].material_override=distinct_material
	check(first.meshes[0].layers==2 and not batch.members.has(first.meshes[0].get_instance_id()),"Explicit authored state boundary withdraws before mesh/material/layer/transform changes")
	flush_all(batch);check(second.meshes[0].layers==1,"State-boundary withdrawal restores the other singleton")
	first.position.y=0.0;first.meshes[0].layers=1;first.meshes[0].material_override=mat
	batch.clear();batch.consider_tile(0,first);batch.consider_tile(1,second);flush_all(batch)
	mat.emit_changed()
	check(first.meshes[0].layers==1 and second.meshes[0].layers==1 and batch.members.is_empty(),"Material mutation immediately withdraws dependent draws and preserves new material semantics")
	flush_all(batch);check(batch.snapshot().active_batches==0,"Changed material leaves no stale replacement draw")
	var fresh:=Batches.new();scope.add_child(fresh);var lifetime_a:=tile(scope,10,Vector3(3,0,3),mesh,distinct_material);var lifetime_b:=tile(scope,11,Vector3(13,0,3),mesh,distinct_material)
	fresh.consider_tile(10,lifetime_a);fresh.consider_tile(11,lifetime_b);flush_all(fresh)
	var weak:=weakref(lifetime_a);lifetime_a.free()
	check(weak.get_ref()==null and fresh.members.size()==1,"Owner removal retains no strong model reference")
	flush_all(fresh);check(lifetime_b.meshes[0].layers==1 and fresh.snapshot().active_batches==0,"Removal retires exact old lifetime and restores remaining singleton")
	check(first.meshes[0].global_transform==first_pose,"Full event sequence preserves original physical transform")
	var earlier:=captured;captured=batch.snapshot();captured.merge(earlier);captured.remaining=fresh.snapshot();captured.actual_renderer=RenderingServer.get_current_rendering_method();captured.actual_driver=RenderingServer.get_current_rendering_driver_name();fresh.close();batch.close();scope.free()
	await process_frame
	var output:=FileAccess.open(receipt,FileAccess.WRITE);output.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"state":captured,"scope":"Authored actual MeshInstance3D/MultiMesh lifetime and original polygon checks; "+("Vulkan transform readback and viewport image" if graphics else "headless CPU only")+"; no server or representative FPS claim","limitations":["Representative captured-room eligibility, visible equivalence and actual draw-call/FPS comparison remain separate acceptance"] if graphics else ["Headless dummy MultiMesh stores no per-instance transforms; staged input checked, real Vulkan transform/readback remains required"]},"\t")+"\n");output.close()
	print("NATIVE_STATIC_SCENERY_BATCHES ",checks," checks ",failures.size()," failures");quit(0 if failures.is_empty() else 1)
