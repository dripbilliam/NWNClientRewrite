extends SceneTree

var report_path := ""
var view: SubViewport
var last_frame := -1
var samples: Array[Dictionary] = []

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):
			report_path = arg.substr(9)
	if report_path.is_empty() or not ClassDB.class_exists("NwnFrameProbe"):
		push_error("Missing private report path or frame probe")
		quit(1)
		return
	view = SubViewport.new()
	view.size = Vector2i(320, 240)
	view.own_world_3d = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var world := Node3D.new()
	view.add_child(world)
	var camera := Camera3D.new()
	camera.position = Vector3(0, 8, 17)
	world.add_child(camera)
	camera.look_at(Vector3.ZERO, Vector3.UP)
	camera.current = true
	var material_a := StandardMaterial3D.new()
	material_a.albedo_color = Color(0.75, 0.3, 0.15)
	var material_b := StandardMaterial3D.new()
	material_b.albedo_color = Color(0.15, 0.4, 0.75)
	for index in 24:
		var box := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		box.mesh = mesh
		box.material_override = material_a if index % 2 == 0 else material_b
		box.position = Vector3((index % 6 - 2.5) * 2, 0, (index / 6 - 1.5) * 2)
		world.add_child(box)
	var sun := DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.rotation_degrees = Vector3(-45, 20, 0)
	world.add_child(sun)
	ClassDB.class_call_static("NwnFrameProbe", "set_enabled", true)
	for ignored in 24:
		await process_frame
		var data: Dictionary = ClassDB.class_call_static("NwnFrameProbe", "completed_frame")
		var frame_id := int(data.get("frame_id", -1))
		if bool(data.get("available", false)) and frame_id > last_frame:
			last_frame = frame_id
			samples.append(data)
	ClassDB.class_call_static("NwnFrameProbe", "set_enabled", false)
	var keys := ["forward_elements", "forward_draw_calls", "forward_color_draws", "forward_shadow_draws", "forward_depth_draws", "forward_vertex_lookups", "forward_pipeline_hashes", "forward_pipeline_lookups", "forward_pipeline_reuses", "forward_pipeline_binds", "forward_material_used_calls", "forward_material_binds", "forward_repeat_skipped"]
	var means := {}
	for key in keys:
		var total := 0
		for data in samples:
			total += int(data.get(key, 0))
		means[key] = float(total) / max(1, samples.size())
	var passed: bool = samples.size() > 0 and means.forward_draw_calls > 0 and means.forward_color_draws > 0 and means.forward_elements >= means.forward_draw_calls and means.forward_vertex_lookups >= means.forward_pipeline_hashes and means.forward_pipeline_lookups <= means.forward_pipeline_hashes and means.forward_pipeline_binds <= means.forward_pipeline_lookups and means.forward_color_draws + means.forward_shadow_draws + means.forward_depth_draws == means.forward_draw_calls
	var image := view.get_texture().get_image()
	passed = passed and image != null and image.get_width() == 320 and image.get_height() == 240
	var pixel_sha256 := ""
	var png_path := report_path.trim_suffix(".json") + ".png"
	if image != null:
		var context := HashingContext.new()
		context.start(HashingContext.HASH_SHA256)
		context.update(image.get_data())
		pixel_sha256 = context.finish().hex_encode()
		passed = passed and image.save_png(png_path) == OK
	var result := {"issue":"NWN-74", "scope":"Private small Vulkan Forward+ probe correctness; no FPS claim", "passed":passed, "samples":samples.size(), "last_frame":last_frame, "means":means, "pixel_sha256":pixel_sha256, "png":png_path}
	var file := FileAccess.open(report_path, FileAccess.WRITE)
	if file == null:
		push_error("Cannot write census report")
		quit(1)
		return
	file.store_string(JSON.stringify(result, "  ") + "\n")
	file.close()
	view.queue_free()
	quit(0 if passed else 1)
