extends SceneTree
const Merge=preload("res://systems/native_render/base_static_draw_merge.gd")
const Proof=preload("res://systems/native_render/base_static_draw_proof.gd")
const Template=preload("res://systems/native_render/model_template.gd")
const NativeMaterial=preload("res://systems/native_render/native_model_material.gd")
const Invalidator=preload("res://systems/native_render/static_draw_invalidation.gd")
class World:
	extends Node3D
	var generation:=4
	var area_id:=9
	var closed:=false
	var retiring:=false
	var desired: Dictionary={}
	var installed: Dictionary={}
	var instances: Dictionary={}
var checks:=0
var failures: Array=[]
var material: NativeMaterial
var graphics:=false
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label)
func _initialize() -> void:call_deferred("run")
func original() -> PackedByteArray:
	var bytes:=PackedByteArray();bytes.resize(244);bytes.encode_u32(4,232);var text:="null".to_ascii_buffer()
	for index in text.size():bytes[180+index]=text[index]
	return bytes
func parsed() -> Dictionary:
	return {"nodes":[{"name":"root","parent":-1,"features":[],"mesh":{}},{"name":"surface","parent":0,"features":[],"alpha":1.0,"mesh":{"render":true}},{"name":"emitter","parent":0,"features":["emitter"],"mesh":{}}]}
func arrays(offset: float=0.0) -> Array:
	var values: Array=[];values.resize(Mesh.ARRAY_MAX);values[Mesh.ARRAY_VERTEX]=PackedVector3Array([Vector3(offset,0,0),Vector3(offset+2,0,0),Vector3(offset,0,-2)]);values[Mesh.ARRAY_NORMAL]=PackedVector3Array([Vector3.UP,Vector3.UP,Vector3.UP]);values[Mesh.ARRAY_TEX_UV]=PackedVector2Array([Vector2.ZERO,Vector2.RIGHT,Vector2.DOWN]);values[Mesh.ARRAY_INDEX]=PackedInt32Array([0,2,1]);return values
func placement(world: World,id: int,position: Vector3,leaf_material: Material=null) -> Template.Placement:
	var owner:=Template.Placement.new();owner.position=position;owner.static_draw_proof=Proof.capture(original(),parsed(),"1".repeat(64));world.add_child(owner)
	var mesh:=ArrayMesh.new();var data:=arrays(float(id)*0.01);mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,data);mesh.set_meta(Merge.CPU_STREAMS,data)
	var leaf:=MeshInstance3D.new();leaf.name="original_draw";leaf.mesh=mesh;leaf.material_override=material if leaf_material==null else leaf_material;leaf.set_meta("native_mesh_source",{"parsed_render":true,"part_index":1,"part_name":"surface","original_alpha":1.0,"native_tilefade_available":true,"native_tilefade":0});owner.add_child(leaf);owner.meshes=[leaf];owner.parts=[leaf]
	# These original physical sibling identities survive every draw substitution.
	var emitter:=Node3D.new();emitter.name="native_emitter";owner.add_child(emitter);owner.parts.append(emitter)
	var light:=OmniLight3D.new();light.name="original_light";light.omni_range=2;owner.add_child(light);owner.parts.append(light)
	var row:={"id":id,"objectType":9,"areaId":world.area_id,"clientKnownLifetime":id,"staticState":{"id":id,"appearance":3,"position":[position.x,-position.z,position.y],"orientation":[0.0,0.0,0.0]},"replicated":{},"authored":{}}
	world.desired[id]={"object":row,"key":"model-"+str(id)};world.installed[id]="model-"+str(id);world.instances[id]=owner
	return owner
func drain(owner) -> bool:
	var until:=Time.get_ticks_msec()+3000
	while owner.has_pending() and Time.get_ticks_msec()<until:owner.flush(100,20);await process_frame
	return not owner.has_pending()
func run() -> void:
	var report:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):report=arg.substr(9)
		if arg=="--require-vulkan":graphics=true
	if report.is_empty() or FileAccess.file_exists(report):quit(2);return
	var proof:=Proof.capture(original(),parsed(),"1".repeat(64));check(proof.available and proof.own_animation_count==0 and proof.parts.keys()==[1],"Original zero-own-animation ordinary mesh is proven even beside an emitter")
	var animated:=original();animated.encode_u32(136,1);check(not Proof.capture(animated,parsed(),"1".repeat(64)).available,"Positive original own-animation count rejects the entire model")
	var inherited:=original();inherited[180]=97;check(not Proof.capture(inherited,parsed(),"1".repeat(64)).available,"Inherited source is conservative fallback")
	check(not Proof.capture(PackedByteArray([0,0,0,0]),parsed(),"1".repeat(64)).available,"Unavailable binary source header is not invented")
	for feature in ["skin","animated-mesh","dangly","reference","aabb","unknown-controller-kind"]:
		var modified:=parsed();modified.nodes[0].features=[feature];check(Proof.capture(original(),modified,"1".repeat(64)).parts.is_empty(),"Unsupported ancestor "+feature+" cannot be batched")
	check(Proof.capture("setsupermodel test null\nnode trimesh test\n".to_utf8_buffer(),parsed(),"1".repeat(64)).available,"ASCII declaration explicitly proves no own clips or inheritance")
	check(not Proof.capture("setsupermodel test null\nnewanim walk test\n".to_utf8_buffer(),parsed(),"1".repeat(64)).available,"ASCII own clip remains in ordinary path")
	material=NativeMaterial.new();material.configure(StandardMaterial3D.new(),[1.0,1.0,1.0],[0.0,0.0,0.0])
	var world:=World.new();root.add_child(world);var helper:=Merge.new();world.add_child(helper);check(helper.configure(world),"Read-only world scope binds")
	var first:=placement(world,10,Vector3.ZERO);var second:=placement(world,11,Vector3(3,0,0));first.limitations=["emitter"]
	var emitter:=first.get_node("native_emitter");var light:=first.get_node("original_light")
	var image: Image;var original_draws: Variant=null;var shadow: OmniLight3D
	if graphics:
		Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
		var camera:=Camera3D.new();world.add_child(camera);camera.position=Vector3(2,8,8);camera.look_at(Vector3(2,0,0));camera.current=true
		shadow=OmniLight3D.new();world.add_child(shadow);shadow.position=Vector3(3,3,1);shadow.omni_range=20;shadow.shadow_enabled=true;shadow.light_cull_mask=1
		check(RenderingServer.get_current_rendering_method()=="forward_plus" and RenderingServer.get_current_rendering_driver_name()=="vulkan","BASE authored fixture uses actual Vulkan Forward+")
		check(DisplayServer.window_get_current_screen()!=DisplayServer.get_primary_screen() and DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS) and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"BASE visual fixture opens unfocused on secondary display with visible mouse")
		await process_frame;await RenderingServer.frame_post_draw
		image=root.get_texture().get_image();image.save_png(report.get_basename()+".individual.png");original_draws=Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	check(helper.consider_instance(10,first) and helper.consider_instance(11,second),"Positive BASE Placement endpoints enroll while emitter siblings remain owned")
	check(helper.groups.size()==1 and helper.members.size()==2,"Different source mesh leaves share material/context/cell")
	check(await drain(helper),"Real data-only merge workers complete")
	var drawing: MeshInstance3D=helper.groups.values()[0].geometry
	check(is_instance_valid(drawing) and drawing.mesh.get_surface_count()==1 and first.meshes[0].get_meta("native_static_batch_draw",false),"Actual merged ArrayMesh is published before source draw suppression")
	check(first.meshes[0].visible and first.meshes[0].layers==1 and first.get_node("native_emitter")==emitter and first.get_node("original_light")==light,"Source Node flags, original emitter and light identities remain unchanged")
	check(first.parts.has(first.meshes[0]) and first.parts.has(emitter) and first.parts.has(light),"Original physical Part ownership remains intact")
	if graphics:
		await process_frame;await RenderingServer.frame_post_draw
		var merged_image:=root.get_texture().get_image();merged_image.save_png(report.get_basename()+".merged.png")
		check(image.get_data()==merged_image.get_data(),"Original and merged BASE authored Vulkan images are byte-identical")
		check(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)<original_draws,"Different source BASE meshes reduce actual draw submissions")
		shadow.free()
		for _frame in 20:await process_frame
		check(is_instance_valid(drawing) and drawing.is_inside_tree(),"BASE layer1 shadow-light teardown remains valid with source draws suppressed")
	Invalidator.withdraw(first,"test-pre-transform");check(not drawing.visible and not first.meshes[0].get_meta("native_static_batch_draw",false),"Synchronous invalidation restores original draws before a pose change")
	first.position.x=1;check(await drain(helper),"Reduced singleton fallback completes")
	check(helper.consider_instance(10,first) and await drain(helper),"Stable current BASE endpoint can re-enter after explicit invalidation")
	for index in 8:
		Invalidator.withdraw(first,"repeated-boundary");helper.consider_instance(10,first)
	check(helper.groups.values()[0].rows.size()==2 and helper.groups.values()[0].vertices==6 and await drain(helper),"Repeated mutation/re-entry does not retain inactive row or geometry streams")
	check(first.set_renderer_alpha(0.5),"Original Placement alpha owner still executes")
	check(not helper.members.has(first.meshes[0].get_instance_id()) and not first.meshes[0].get_meta("native_static_batch_draw",false),"Alpha enrollment withdraws before private material cloning")
	check(not helper.consider_instance(10,first),"Private alpha wrappers are never deduplicated by guessed visual equivalence")
	var unusable:=placement(world,12,Vector3(6,0,0));world.desired[12].object.replicated.field264=1;check(not helper.consider_instance(12,unusable),"Contradictory usability rejects BASE provenance")
	var unknown:=placement(world,13,Vector3(7,0,0));world.desired[13].object.erase("staticState");check(not helper.consider_instance(13,unknown),"Missing received BASE record remains explicit fallback")
	var missing:=placement(world,14,Vector3(8,0,0));missing.static_draw_proof={};check(not helper.consider_instance(14,missing),"Missing original animation/Part proof falls back")
	var gi:=placement(world,15,Vector3(9,0,0));gi.meshes[0].gi_mode=GeometryInstance3D.GI_MODE_DYNAMIC;check(not helper.consider_instance(15,gi),"Unproven per-instance GI context refuses merge")
	var stale:=placement(world,16,Vector3(10,0,0));check(helper.consider_instance(16,stale),"Lifetime fixture enrolls")
	world.desired[16].object.clientKnownLifetime=916;helper.flush();check(await drain(helper) and not stale.meshes[0].get_meta("native_static_batch_draw",false),"Same-ID changed lifetime cannot publish an older pending draw")
	var fog:=NativeMaterial.new();fog.configure(StandardMaterial3D.new(),[1.0,1.0,1.0],[0.0,0.0,0.0]);fog.native_surface_output=true;fog.native_tile_fog_enabled=true
	var fogged:=placement(world,17,Vector3(11,0,0),fog);fogged.meshes[0].set_instance_shader_parameter("nwn_tile_fog_factor",0.75)
	check(not helper.consider_instance(17,fogged),"Native per-instance fog requires an authentic TileData context provider")
	helper.close();check(helper.worker_tasks().is_empty(),"Close joins pending jobs before world disposal")
	var fog_helper:=Merge.new();world.add_child(fog_helper)
	var context:=func(_model,mesh):return {"available":true,"identity":["original-tiledata",4,7],"factor":mesh.get_instance_shader_parameter("nwn_tile_fog_factor")}
	check(fog_helper.configure(world,context) and fog_helper.consider_instance(17,fogged),"Authentic caller-supplied TileData identity and actual factor permit fog endpoint")
	var fog_second:=placement(world,18,Vector3(13,0,0),fog);fog_second.meshes[0].set_instance_shader_parameter("nwn_tile_fog_factor",0.75)
	check(fog_helper.consider_instance(18,fog_second) and await drain(fog_helper),"Same authentic TileData/factor can merge")
	var fog_draw: MeshInstance3D=fog_helper.groups.values()[0].geometry
	check(is_instance_valid(fog_draw) and fog_draw.get_instance_shader_parameter("nwn_tile_fog_factor")==0.75,"Replacement receives the exact native per-instance fog factor")
	Invalidator.withdraw(fogged.meshes[0],"physical-tile-fog-factor");check(not fog_draw.visible and not fogged.meshes[0].get_meta("native_static_batch_draw",false),"Fog boundary withdraws source and full replacement before parameter write")
	fogged.meshes[0].set_instance_shader_parameter("nwn_tile_fog_factor",0.5)
	check(await drain(fog_helper) and fog_helper.consider_instance(17,fogged) and fog_helper.groups.size()==2,"Different current fog factors cannot alias even within one spatial cell")
	check(await drain(fog_helper),"Different-fog singleton groups settle")
	var retiring_a:=placement(world,20,Vector3(1,0,4));var retiring_b:=placement(world,21,Vector3(3,0,4));fog_helper.consider_instance(20,retiring_a);fog_helper.consider_instance(21,retiring_b);fog_helper.flush();var tasks:=fog_helper.worker_tasks()
	check(not tasks.is_empty(),"Retirement owns a real pending worker")
	world.retiring=true;fog_helper.retire_scope();check(fog_helper.worker_tasks()==tasks,"Scope retirement exposes task IDs until actual join")
	fog_helper.close();check(fog_helper.worker_tasks().is_empty() and fog_helper.members.is_empty(),"Retirement finishes without publishing old draw lifetimes")
	var state:=fog_helper.snapshot();world.free();await process_frame
	state.actual_driver=RenderingServer.get_current_rendering_driver_name();state.actual_renderer=RenderingServer.get_current_rendering_method()
	var output:=FileAccess.open(report,FileAccess.WRITE);output.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"state":state,"scope":"Native authored BASE draw-leaf proof/admission, actual worker and ArrayMesh publication, original ownership and pre-mutation invalidation; "+("authored Vulkan pixels/draws" if graphics else "headless")+", no server or FPS claim"},"\t")+"\n");output.close();print("NATIVE_BASE_STATIC_DRAW_MERGE ",checks," checks ",failures.size()," failures");quit(0 if failures.is_empty() else 1)
