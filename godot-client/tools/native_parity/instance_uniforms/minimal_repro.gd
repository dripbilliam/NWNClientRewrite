extends SceneTree
# PREPARED ONLY while the user's live session is active. Future explicit
# reservation must select Forward+, nonprimary and unfocused before launch.
# Synthetic shared meshes/shaders; no NWN/server/native libraries or assets.
var nodes: Array[MeshInstance3D]=[]
var checks:=0
var failures: Array=[]
func _initialize() -> void:run.call_deferred()
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label)
func shader_code(instance_uniform: bool,variant: int) -> String:
	return "shader_type spatial;render_mode unshaded,cull_disabled;\n"+("instance " if instance_uniform else "")+"uniform float nwn_tile_fog_factor=1.0;\nvoid fragment(){ALBEDO=vec3(0.2,0.8,"+str(.2+variant*.05)+")*nwn_tile_fog_factor;}\n"
func run() -> void:
	var report:="";var mode:="";var expected_screen:=-1
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):report=arg.substr(9)
		elif arg.begins_with("--mode="):mode=arg.substr(7)
		elif arg.begins_with("--screen="):expected_screen=int(arg.substr(9))
	if report.is_empty() or FileAccess.file_exists(report) or mode not in ["instance-capacity","instance-below-limit","material-uniform-control"]:quit(2);return
	if DisplayServer.get_name()=="headless" or RenderingServer.get_current_rendering_method()!="forward_plus" or expected_screen<0 or root.current_screen!=expected_screen or root.current_screen==DisplayServer.get_primary_screen() or root.has_focus() or not root.unfocusable:quit(3);return
	var slots: int=ProjectSettings.get_setting("rendering/limits/global_shader_variables/buffer_size",65536)
	if slots!=4096:quit(4);return
	var instance_uniform:=mode!="material-uniform-control";var count:=128 if mode=="instance-below-limit" else 260
	var world:=Node3D.new();root.add_child(world);var camera:=Camera3D.new();world.add_child(camera);camera.position=Vector3(7.5,8,24);camera.current=true;camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=19
	var mesh:=QuadMesh.new();mesh.size=Vector2(.75,.75);var material:=ShaderMaterial.new();var shader:=Shader.new();shader.code=shader_code(instance_uniform,0);material.shader=shader
	for index in count:
		var node:=MeshInstance3D.new();node.mesh=mesh;node.material_override=material;node.position=Vector3(index%16,index/16,0);world.add_child(node);nodes.append(node)
	await RenderingServer.frame_post_draw;await RenderingServer.frame_post_draw
	check(nodes.size()==count,"All synthetic physical geometry RIDs are current")
	# No set_instance_shader_parameter is called. Declaration/default alone
	# should enroll each physical geometry; retry comes from shader dependency.
	shader.code=shader_code(instance_uniform,1)
	await RenderingServer.frame_post_draw;await RenderingServer.frame_post_draw
	if mode=="instance-capacity":
		for index in 128:nodes[index].free()
		shader.code=shader_code(true,2)
		await RenderingServer.frame_post_draw;await RenderingServer.frame_post_draw
		shader.code=shader_code(false,3)
		await RenderingServer.frame_post_draw;await RenderingServer.frame_post_draw
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"mode":mode,"slots":slots,"geometry_created":count,"renderer":RenderingServer.get_current_rendering_method(),"shader_declaration":instance_uniform,"explicit_instance_parameter_sets":0,"expected_log":"capacity then duplicate at2028" if mode=="instance-capacity" else "no allocator errors","server_connections":0,"native_builds":0,"scope":"Synthetic prepared renderer repro; inspect captured engine log separately. No whole-game/NWN pixel claim."}
	world.free();await process_frame;await process_frame
	var file:=FileAccess.open(report,FileAccess.WRITE);file.store_string(JSON.stringify(result,"\t")+"\n");file.close();quit(0 if failures.is_empty() else 1)
