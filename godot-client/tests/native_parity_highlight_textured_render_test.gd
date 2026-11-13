extends SceneTree
const Bounds=preload("res://tools/native_parity/highlighting/native_highlight_bounds_textured.gd")
const Owner=preload("res://tools/native_parity/ui/actor-alpha-owner.gd")
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Raster=preload("res://systems/native_data/texture_data.gd")
const Pool=preload("res://systems/native_render/resource_pool.gd")
const Sampler=preload("res://systems/native_data/gui_texture_info.gd")
var checks:=0
var failures: Array=[]
func _initialize() -> void:run.call_deferred()
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label);print("FAIL ",label)
func wait_draw() -> void:
	for frame in 4:await process_frame
	await RenderingServer.frame_post_draw
func material(color: Color) -> StandardMaterial3D:
	var value:=StandardMaterial3D.new();value.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;value.albedo_color=color;return value
func sample(image: Image,camera: Camera3D,point: Vector3) -> Color:
	var pixel:=camera.unproject_position(point);return image.get_pixel(int(pixel.x),int(pixel.y))
func run() -> void:
	var output:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):output=arg.substr(9)
	if output.is_empty() or FileAccess.file_exists(output):quit(2);return
	var window:={"screen":root.current_screen,"primary":DisplayServer.get_primary_screen(),"focused":root.has_focus(),"unfocusable":root.unfocusable,"mouse_mode":Input.get_mouse_mode()}
	check(window.screen==2 and window.screen!=window.primary and not window.focused and window.unfocusable and window.mouse_mode==Input.MOUSE_MODE_VISIBLE,"Highlight functional check stays secondary/unfocused without mouse capture")
	var world:=Node3D.new();root.add_child(world)
	var env:=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color(0.02,0.03,0.04);world.add_child(env)
	var camera:=Camera3D.new();world.add_child(camera);camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=5.0;camera.position=Vector3(0,0,10);camera.current=true
	var body:=MeshInstance3D.new();body.mesh=QuadMesh.new();body.mesh.size=Vector2(1.5,1.5);body.position=Vector3(-1.5,0,0);body.material_override=material(Color(0.5,0.2,0.1,0.8));world.add_child(body)
	var actor:=Owner.new();actor.enroll(body,0);actor.set_alpha(0.25)
	var door:=MeshInstance3D.new();door.mesh=QuadMesh.new();door.mesh.size=Vector2(1.5,1.5);door.position=Vector3(1.5,0,0);door.material_override=material(Color(1,1,1,0));door.visible=false;world.add_child(door)
	var occluder:=MeshInstance3D.new();occluder.mesh=QuadMesh.new();occluder.mesh.size=Vector2(1.7,0.6);occluder.position=Vector3(-1.5,0.5,1);occluder.material_override=material(Color(0.03,0.05,0.8));world.add_child(occluder)
	var highlight:=Bounds.new();world.add_child(highlight)
	var catalog:=Catalog.new();check(catalog.mount_install("C:/Users/Niflheim/Desktop/Tools/Local Tools/FullDecomp/NwnRootInstall") and catalog.mount_directory("C:/Users/Niflheim/Documents/Neverwinter Nights.0/override",10000000),"Original active-profile texture catalog mounts read-only")
	var location:=catalog.raster_location("fxpa_dot02");var original_bytes:=catalog.get_resource("fxpa_dot02",int(location.type));var decoder:=Raster.new();var data:=decoder.parse(original_bytes,int(location.type));var pool:=Pool.new()
	var texture:=pool.texture({"sha256":preload("res://systems/native_data/prepared_cache.gd").digest(original_bytes),"value":data})
	check(texture!=null and decoder.failure.is_empty() and highlight.configure_texture(texture,Sampler.read(catalog,"fxpa_dot02"),false),"Original fxpa_dot02 DDS+TXI enables textured bounds in ordinary component output mode")
	var authored:={"min":[-0.75,-0.25,-0.75],"max":[0.75,0.25,0.75]}
	highlight.register_entity(1,body,[1],[{"anchor":body,"native_bounds":authored,"is_skin":false,"subtree_enabled":true}],Color.GREEN,func(_model):return 0.25)
	highlight.register_entity(2,door,[1],[{"anchor":door,"native_bounds":authored,"is_skin":false,"subtree_enabled":true}],Color.GREEN,func(_model):return 1.0)
	await wait_draw();var baseline:=root.get_texture().get_image();baseline.save_png(output.trim_suffix(".json")+"-baseline.png")
	var raw_alpha: float=body.material_override.actor_part_color.a;var effective_alpha: float=body.material_override.albedo_color.a
	highlight.mark([1,2]);check(highlight.tick(camera,2.5,0.3),"Current physical bounds publish retained GPU vertex/color buffers")
	await wait_draw();var marked:=root.get_texture().get_image();marked.save_png(output.trim_suffix(".json")+"-marked.png")
	check(highlight.stats.vertices==36 and body.material_overlay==null and door.material_overlay==null,"Two selected physical boxes use36 vertices and no duplicate model overlay passes")
	check(not door.visible and body.material_override.actor_part_color.a==raw_alpha and body.material_override.albedo_color.a==effective_alpha,"Bounds pass cannot reset translucent actor alpha or reveal ordinary alpha-zero door")
	var open_point:=door.global_position+Vector3(0.2,0,0);var door_before:=sample(baseline,camera,open_point);var door_after:=sample(marked,camera,open_point)
	check(door_after.g>door_before.g+0.1,"Authored alpha-zero physical doorway has visible separate native bounds pixels")
	var edge:=door.global_position+Vector3(1.70,0.1,0);var edge_delta:=sample(marked,camera,edge).g-sample(baseline,camera,edge).g
	check(edge_delta<(door_after.g-door_before.g)*0.4,"Original radial RGB texture attenuates authored-box edges instead of solid additive rectangles")
	check(sample(marked,camera,occluder.global_position).is_equal_approx(sample(baseline,camera,occluder.global_position)),"Opaque foreground pixels occlude bounds because native depth test remains enabled")
	check(sample(marked,camera,body.global_position+Vector3(0.2,-0.2,0)).g>sample(baseline,camera,body.global_position+Vector3(0.2,-0.2,0)).g+0.02,"Transparent actor receives additive bounds pixels without replacing its base pass")
	var stable:=true
	for frame in 8:
		highlight.tick(camera,2.5,0.3);await wait_draw()
		if root.get_texture().get_image().get_data()!=marked.get_data():stable=false
	check(stable,"Repeated same-pose transparent frames have exact stable pixels with retained region uploads")
	highlight.mark([]);highlight.tick(camera,2.5,0.3);await wait_draw();var unmarked:=root.get_texture().get_image();unmarked.save_png(output.trim_suffix(".json")+"-unmarked.png")
	check(unmarked.get_data()==baseline.get_data(),"Unmark restores original pixels without touching actor materials")
	body.position.x+=500;door.position.x+=500;occluder.position.x+=500;camera.position.x+=500
	highlight.mark([1,2]);highlight.tick(camera,2.5,0.3);await wait_draw();var shifted:=root.get_texture().get_image();shifted.save_png(output.trim_suffix(".json")+"-offset.png")
	check(sample(shifted,camera,door.global_position+Vector3(0.2,0,0)).g>door_before.g+0.1 and highlight.batch.custom_aabb.position.x>490,"Truthful customAABB keeps bounds visible far from world origin")
	check(highlight.surface.get_surface_count()==1 and highlight.stats.membership_rebuilds==3,"Held highlight updates retain one batch; rebuilds occur only for membership changes")
	check(highlight.configure_texture(texture,Sampler.read(catalog,"fxpa_dot02"),true) and highlight.tick(camera,2.5,0.3),"Established native-surface carrier shader variant also configures and draws")
	await wait_draw();var native_carrier:=root.get_texture().get_image();native_carrier.save_png(output.trim_suffix(".json")+"-native-carrier.png")
	check(highlight.textured_material.get_meta("native_surface_output") and sample(native_carrier,camera,door.global_position+Vector3(0.2,0,0)).g>door_before.g+0.1,"Native output variant renders original textured highlight before its external compositor")
	highlight.close();actor.close();pool.clear();world.free();await process_frame;await process_frame
	var file:=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"window":window,"nativeBuilds":0,"serverConnections":0,"performanceClaim":false,"scope":"Component pixels: original fxpa_dot02 DDS/TXI texture+UV and native transfer, additive authored box buffers, translucent base isolation, alpha0 doorway, depth occlusion, repeated-frame stability, unmark and world-offset culling; actual Registry integration separately required."},"  ")+"\n");file.close();quit(0 if failures.is_empty() else 1)
