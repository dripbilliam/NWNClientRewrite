extends SceneTree

var report_path := ""

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):
			report_path = arg.substr(9)
	if report_path.is_empty():
		push_error("Missing report path")
		quit(1)
		return
	var view := SubViewport.new()
	view.size = Vector2i(320, 240)
	view.own_world_3d = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var world := Node3D.new()
	view.add_child(world)
	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.08, 0.12, 0.2)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.4, 0.5, 0.7)
	environment_node.environment = environment
	world.add_child(environment_node)
	var camera := Camera3D.new()
	camera.position = Vector3(4, 5, 9)
	world.add_child(camera)
	camera.look_at(Vector3.ZERO, Vector3.UP)
	camera.current = true
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.8, 0.25, 0.1)
	for i in 8:
		var box := MeshInstance3D.new()
		box.mesh = BoxMesh.new()
		box.material_override = material
		box.position = Vector3((i % 4 - 1.5) * 2, 0, (i / 4 - 0.5) * 2)
		world.add_child(box)
	var sun := DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.rotation_degrees = Vector3(-45, 20, 0)
	world.add_child(sun)
	var draws: Array[int] = []
	for ignored in 24:
		await process_frame
		draws.append(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
	var image := view.get_texture().get_image()
	var pixel_sha256 := ""
	var png := report_path.trim_suffix(".json") + ".png"
	var png_ok := false
	if image != null:
		var context := HashingContext.new()
		context.start(HashingContext.HASH_SHA256)
		context.update(image.get_data())
		pixel_sha256 = context.finish().hex_encode()
		png_ok = image.save_png(png) == OK
	var max_draws := 0
	for count in draws:
		max_draws = maxi(max_draws, count)
	var passed := max_draws > 0 and png_ok and image != null and image.get_width() == 320 and image.get_height() == 240
	var result := {"issue":"NWN-74", "scope":"Private 24-frame Vulkan draw correctness; no FPS", "passed":passed, "draws":draws, "max_draws":max_draws, "pixel_sha256":pixel_sha256, "png":png, "png_ok":png_ok}
	var file := FileAccess.open(report_path, FileAccess.WRITE)
	if file == null:
		push_error("Cannot write report")
		quit(1)
		return
	file.store_string(JSON.stringify(result, "  ") + "\n")
	file.close()
	view.queue_free()
	quit(0 if passed else 1)
