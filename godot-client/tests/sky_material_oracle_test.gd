extends SceneTree
const SkyOwner = preload("res://systems/area_sky.gd")
var failures: Array = []
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var output := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output = arg.substr(9)
	if output.is_empty() or FileAccess.file_exists(output): quit(2); return
	var oracle: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/native-sky-material-v1.json"))
	if oracle.target != "3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a" or oracle.blendTable.slice(0,4).map(func(v):return int(v)) != [770,771,1,0]: quit(2); return
	var host := Node3D.new();root.add_child(host)
	var environment := WorldEnvironment.new();environment.environment = Environment.new();environment.environment.background_mode = Environment.BG_COLOR;environment.environment.background_color = Color.BLACK;environment.environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR;host.add_child(environment)
	var camera := Camera3D.new();host.add_child(camera);camera.projection = Camera3D.PROJECTION_ORTHOGONAL;camera.size = 4;camera.current = true
	var actual := MeshInstance3D.new();actual.mesh = QuadMesh.new();host.add_child(actual);actual.position = Vector3(-1,0,-2)
	var material := ShaderMaterial.new();material.shader = SkyOwner._shader();actual.material_override = material
	var expected := MeshInstance3D.new();expected.mesh = QuadMesh.new();host.add_child(expected);expected.position = Vector3(1,0,-2)
	var reference := StandardMaterial3D.new();reference.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED;reference.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA;reference.disable_fog = true;expected.material_override = reference
	var cases := 0
	var maximum := 0.0
	for row in oracle.rows:
		var c: Dictionary = row.case
		# These are the actual sky/fade roles. Ordinary world mesh flags 0/0
		# use another material owner and are intentionally outside this shader.
		if c.sky == 0 and c.fade == 0: continue
		var call: Dictionary = row.calls.filter(func(v):return v.kind == "color")[0]
		material.set_shader_parameter("original_color",Color(.1,.8,.4,c.alpha))
		material.set_shader_parameter("sky_weight",1.0 if c.fade == 1 else c.weight)
		material.set_shader_parameter("horizon",c.fade == 1)
		material.set_shader_parameter("horizon_color",Color(oracle.fog[0],oracle.fog[1],oracle.fog[2]))
		reference.albedo_color = Color(call.value[0],call.value[1],call.value[2],call.value[3])
		await process_frame;await process_frame;await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		var p := camera.unproject_position(actual.global_position);var q := camera.unproject_position(expected.global_position)
		var a := image.get_pixel(int(p.x),int(p.y));var b := image.get_pixel(int(q.x),int(q.y))
		var delta := maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b)))
		maximum = maxf(maximum,delta);cases += 1
		if delta > .005: failures.append({"case":c,"nativeColor":call.value,"actual":[a.r,a.g,a.b],"expected":[b.r,b.g,b.b],"delta":delta})
		if c.sky == 1 and c.fade == 0 and row.calls.filter(func(v):return v.kind == "blend" and v.value.map(func(n):return int(n)) == [0,1]).size() != 1: failures.append({"case":c,"missing":"Native normal-alpha blend request"})
	host.free();await process_frame;await process_frame
	var file := FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify({"passed":failures.is_empty() and cases == 24,"nativeCases":cases,"maximumPixelDelta":maximum,"failures":failures,"scope":"Actual production sky shader vs standard materials using original instruction color/alpha outputs; synthetic geometry, no complete native GPU parity claim"},"\t"));file.close()
	print("SKY_MATERIAL_ORACLE ",cases," cases; ",failures.size()," failures")
	quit(0 if failures.is_empty() and cases == 24 else 1)
