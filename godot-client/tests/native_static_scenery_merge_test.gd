extends SceneTree
const Merge=preload("res://systems/native_render/static_scenery_merge.gd")
const Data=preload("res://systems/native_render/static_scenery_merge_data.gd")
const NativeMaterial=preload("res://systems/native_render/native_model_material.gd")
const Query=preload("res://systems/native_render/projectile_scene.gd")
const Geometry=preload("res://systems/native_render/scene_geometry.gd")
class Tile:
	extends Node3D
	var meshes: Array=[]
	var pick_surfaces: Array=[]
	var limitations: Array=[]
var checks:=0
var failures: Array=[]
var states: Dictionary={}
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label)
func _initialize() -> void:call_deferred("run")
func arrays(offset: float=0.0,color: bool=false) -> Array:
	var result: Array=[];result.resize(Mesh.ARRAY_MAX)
	result[Mesh.ARRAY_VERTEX]=PackedVector3Array([Vector3(offset,0,0),Vector3(offset+2,0,0),Vector3(offset,0,-2)]);result[Mesh.ARRAY_NORMAL]=PackedVector3Array([Vector3.UP,Vector3.UP,Vector3.UP]);result[Mesh.ARRAY_TEX_UV]=PackedVector2Array([Vector2.ZERO,Vector2.RIGHT,Vector2.DOWN]);result[Mesh.ARRAY_INDEX]=PackedInt32Array([0,2,1])
	if color:result[Mesh.ARRAY_COLOR]=PackedColorArray([Color.RED,Color.GREEN,Color.BLUE])
	return result
func mat() -> ShaderMaterial:
	var material:=NativeMaterial.new();material.configure(StandardMaterial3D.new(),[1.0,1.0,1.0],[0.0,0.0,0.0]);return material
func tile(parent: Node,id: int,position: Vector3,data: Array,material: Material) -> Tile:
	var owner:=Tile.new();owner.position=position;owner.set_meta("native_tile_index",id);parent.add_child(owner)
	var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,data);mesh.set_meta(Merge.CPU_STREAMS,data)
	var collision:=Geometry.new();var raw:=PackedFloat32Array()
	for vertex in data[Mesh.ARRAY_VERTEX]:raw.append_array(PackedFloat32Array([vertex.x,-vertex.z,vertex.y]))
	collision.configure({"vertices":raw,"indices":PackedInt32Array([0,1,2]),"native_planes":PackedFloat32Array([0,0,1,0]),"native_surface_types":PackedInt32Array([0])});mesh.set_meta("native_scene_geometry",collision)
	var shape:=MeshInstance3D.new();shape.mesh=mesh;shape.material_override=material;shape.set_meta("native_mesh_source",{"parsed_render":true,"native_tilefade_available":true,"native_tilefade":0});owner.add_child(shape);owner.meshes=[shape];return owner
func drain(owner) -> bool:
	var deadline:=Time.get_ticks_msec()+5000
	while owner.has_pending() and Time.get_ticks_msec()<deadline:
		owner.flush(100.0,20);await process_frame
	return not owner.has_pending()
func run() -> void:
	var report:=""
	var graphics:=false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):report=arg.substr(9)
		if arg=="--require-vulkan":graphics=true
	if report.is_empty() or FileAccess.file_exists(report):quit(2);return
	var a:=arrays();var b:=arrays(1.0)
	check(Data.channel_layout(a)=="positions-normal-uv-index","Prepared source channel layout accepted")
	var result:=Data.bake({"rows":[{"source_id":1,"arrays":a,"pose":Transform3D(Basis.IDENTITY,Vector3(3,0,0))},{"source_id":2,"arrays":b,"pose":Transform3D(Basis(Vector3.UP,PI*0.5),Vector3(11,2,0))}],"epoch":7,"revision":9})
	check(result.error=="" and result.vertices==6 and result.indices==6,"Different source geometry merges into one complete stream")
	check(result.epoch==7 and result.revision==9 and result.ranges.size()==2,"Worker result retains exact scope/revision and source ranges")
	for index in 3:
		check(result.arrays[Mesh.ARRAY_VERTEX][index]==Vector3(3,0,0)+a[Mesh.ARRAY_VERTEX][index],"First source position preserved "+str(index))
		check(result.arrays[Mesh.ARRAY_VERTEX][index+3].is_equal_approx(Transform3D(Basis(Vector3.UP,PI*0.5),Vector3(11,2,0))*b[Mesh.ARRAY_VERTEX][index]),"Second source rotated/elevated position preserved "+str(index))
		check(result.arrays[Mesh.ARRAY_NORMAL][index+3].is_equal_approx(Vector3.UP),"Transformed normal preserved "+str(index))
		check(result.arrays[Mesh.ARRAY_TEX_UV][index+3]==b[Mesh.ARRAY_TEX_UV][index],"Source UV preserved "+str(index))
	check(result.arrays[Mesh.ARRAY_INDEX]==PackedInt32Array([0,2,1,3,5,4]),"Triangle order and winding preserved with vertex offsets")
	var colored:=Data.bake({"rows":[{"arrays":arrays(0,true),"pose":Transform3D.IDENTITY},{"arrays":arrays(1,true),"pose":Transform3D.IDENTITY}],"epoch":1,"revision":1})
	check(colored.error=="" and colored.arrays[Mesh.ARRAY_COLOR]==PackedColorArray([Color.RED,Color.GREEN,Color.BLUE,Color.RED,Color.GREEN,Color.BLUE]),"Vertex colors preserve all source channels")
	var invalid:=arrays();invalid[Mesh.ARRAY_INDEX]=PackedInt32Array([0,9,1])
	check(not str(Data.bake({"rows":[{"arrays":a,"pose":Transform3D.IDENTITY},{"arrays":invalid,"pose":Transform3D.IDENTITY}]}).error).is_empty(),"Out-of-range source triangles reject merge")
	check(not str(Data.bake({"rows":[{"arrays":a,"pose":Transform3D.IDENTITY},{"arrays":arrays(0,true),"pose":Transform3D.IDENTITY}]}).error).is_empty(),"Different channel layouts cannot merge")
	var scope:=Node3D.new();root.add_child(scope);var owner:=Merge.new();scope.add_child(owner);var material:=mat()
	if graphics:
		Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
		var camera:=Camera3D.new();scope.add_child(camera);camera.position=Vector3(10,20,20);camera.look_at(Vector3(10,0,0));camera.current=true
		var sun:=DirectionalLight3D.new();scope.add_child(sun);sun.rotation_degrees=Vector3(-50,-30,0)
		check(RenderingServer.get_current_rendering_method()=="forward_plus" and RenderingServer.get_current_rendering_driver_name()=="vulkan","Actual merged fixture uses Vulkan Forward+")
		check(DisplayServer.window_get_current_screen()!=DisplayServer.get_primary_screen() and DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS) and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"Merged fixture opens unfocused on nonprimary monitor with visible mouse")
	var first:=tile(scope,0,Vector3(1,0,1),a,material);var second:=tile(scope,1,Vector3(11,0,1),b,material);var third:=tile(scope,2,Vector3(5,0,5),arrays(0.5),material)
	var original_image: Image
	var paired_light: OmniLight3D
	if graphics:
		paired_light=OmniLight3D.new();scope.add_child(paired_light);paired_light.position=Vector3(4,3,4);paired_light.omni_range=20.0;paired_light.light_cull_mask=1;paired_light.shadow_enabled=true
		await process_frame;await RenderingServer.frame_post_draw
		original_image=root.get_texture().get_image();original_image.save_png(report.get_basename()+".individual.png")
		states.original_draw_calls=Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	var original_hit: Variant=Query.model_hit(first,[1.5,-0.5,2.0],[1.5,-0.5,-2.0],true,false)
	check(original_hit!=null,"Original physical source is hittable")
	owner.consider_tile(0,first);owner.consider_tile(1,second);owner.consider_tile(2,third)
	check(owner.groups.size()==1 and owner.members.size()==3,"Different Mesh identities share one compatible material/cell group")
	owner.flush();check(owner.worker_tasks().size()==1,"One actual background merge task owns only POD streams")
	check(first.meshes[0].visible and first.meshes[0].layers==1,"Original drawing remains while worker preparation is unfinished")
	check(await drain(owner),"Background jobs and bounded publication drain")
	var group: Dictionary=owner.groups.values()[0];var drawing: MeshInstance3D=group.geometry
	check(is_instance_valid(drawing) and drawing.mesh.get_surface_count()==1,"One actual merged ArrayMesh draw is published")
	check(first.meshes[0].get_meta("native_static_batch_draw",false) and second.meshes[0].get_meta("native_static_batch_draw",false) and third.meshes[0].get_meta("native_static_batch_draw",false),"Complete merged replacement owns exactly three original draws")
	check(first.meshes[0].visible and second.meshes[0].visible and third.meshes[0].visible,"Node visibility remains unchanged for physical consumers")
	check(first.meshes[0].layers==1 and second.meshes[0].layers==1 and third.meshes[0].layers==1,"Original layer masks remain intact for native light-pair lifetime")
	check(drawing.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size()==9,"Published mesh contains every original source vertex")
	check(Query.model_hit(first,[1.5,-0.5,2.0],[1.5,-0.5,-2.0],true,false)==original_hit,"Unchanged original polygon collision survives merged drawing")
	check(owner.snapshot().nominal_instance_reduction==2,"Three different source mesh instances become one explicit draw group")
	check(int(owner.snapshot().merge_worker_us)>=0 and owner.worker_tasks().is_empty(),"Worker duration is reported and task IDs retire only after join")
	if graphics:
		await process_frame;await RenderingServer.frame_post_draw
		var merged_image:=root.get_texture().get_image();merged_image.save_png(report.get_basename()+".merged.png")
		states.merged_draw_calls=Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		check(not original_image.is_empty() and not merged_image.is_empty() and original_image.get_size()==merged_image.get_size(),"Both actual GPU draw paths produce comparable viewport images")
		check(original_image.get_data()==merged_image.get_data(),"Authored individual and merged Vulkan images are byte-identical")
		check(states.merged_draw_calls<states.original_draw_calls,"Actual Vulkan draw count decreases for different source meshes")
		states.image_comparison={"byte_identical":original_image.get_data()==merged_image.get_data(),"dimensions":str(merged_image.get_size())}
		paired_light.free()
		for _frame in 20:await process_frame
		check(is_instance_valid(drawing) and drawing.is_inside_tree(),"Layer1 shadow-light teardown remains valid through20 real render frames with source draws suppressed")
	var outside:=tile(scope,3,Vector3(31,0,1),arrays(0.3),material);owner.consider_tile(3,outside);check(await drain(owner),"Separate spatial singleton drains without a merge job")
	check(outside.meshes[0].visible and outside.meshes[0].layers==1 and owner.groups.size()==2,"Separate cells keep independent culling and normal singleton drawing")
	owner.withdraw_model(first,"authored-transform-change")
	check(first.meshes[0].visible and second.meshes[0].visible and third.meshes[0].visible,"Withdrawal immediately restores all original sources before asynchronous rebuild")
	check(not drawing.visible and drawing.is_queued_for_deletion(),"Resource-event withdrawal hides and defers replacement destruction")
	check(await drain(owner),"Reduced compatible group rebuilds after withdrawal")
	check(second.meshes[0].get_meta("native_static_batch_draw",false) and third.meshes[0].get_meta("native_static_batch_draw",false) and second.meshes[0].visible and third.meshes[0].visible,"Remaining compatible sources republish without changing Node visibility")
	owner.clear();await process_frame
	check(owner.members.is_empty() and owner.groups.is_empty() and owner.worker_tasks().is_empty(),"Scope clear restores originals and joins all workers")
	check(second.meshes[0].visible and third.meshes[0].visible and second.meshes[0].layers==1 and third.meshes[0].layers==1,"Scope clear preserves physical model lifetimes and normal drawing")
	owner.consider_tile(0,first);owner.consider_tile(1,second);owner.consider_tile(2,third);owner.flush()
	check(owner.worker_tasks().size()==1,"Fresh scope starts a real pending worker")
	owner.withdraw_model(first,"lifetime-removal-before-worker-publication")
	check(await drain(owner),"Stale revision result is discarded and current state can settle")
	check(int(owner.snapshot().get("merge_stale_results",0))>=1 and first.meshes[0].visible and first.meshes[0].layers==1,"Old worker cannot re-admit a removed source lifetime")
	owner.clear();owner.consider_tile(0,first);owner.consider_tile(1,second);owner.flush();var tasks:=owner.worker_tasks()
	check(tasks.size()==1,"Retirement fixture begins with an actual held task ID")
	owner.retire_scope();check(owner.worker_tasks()==tasks,"Retirement keeps unfinished/stale task IDs exposed until joined")
	owner.clear();check(owner.worker_tasks().is_empty() and owner.groups.is_empty(),"Final clear joins and releases pending data-only workers")
	var earlier:=states;states=owner.snapshot();states.merge(earlier);states.actual_renderer=RenderingServer.get_current_rendering_method();states.actual_driver=RenderingServer.get_current_rendering_driver_name();owner.close();scope.free();await process_frame
	var output:=FileAccess.open(report,FileAccess.WRITE);output.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"state":states,"scope":"Authored actual background merge workers and ArrayMesh lifetime/collision checks; "+("Vulkan byte-image comparison" if graphics else "headless CPU only")+"; no server or representative performance acceptance"},"\t")+"\n");output.close();print("NATIVE_STATIC_SCENERY_MERGE ",checks," checks ",failures.size()," failures");quit(0 if failures.is_empty() else 1)
