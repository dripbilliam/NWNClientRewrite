extends SceneTree

var report_path := ""
var scene_view: SubViewport
var source_view: SubViewport
var source_rect: ColorRect

func _initialize() -> void:
	call_deferred("run")

func hash_bytes(data: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(data)
	return context.finish().hex_encode()

func build_scene() -> void:
	source_view = SubViewport.new()
	source_view.size = Vector2i(64, 64)
	source_view.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	root.add_child(source_view)
	source_rect = ColorRect.new()
	source_rect.size = Vector2(64, 64)
	source_rect.color = Color(0.9, 0.15, 0.1)
	source_view.add_child(source_rect)
	scene_view = SubViewport.new()
	scene_view.size = Vector2i(320, 240)
	scene_view.own_world_3d = true
	scene_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(scene_view)
	var world := Node3D.new()
	scene_view.add_child(world)
	var camera := Camera3D.new()
	camera.position = Vector3(0, 8, 17)
	world.add_child(camera)
	camera.look_at(Vector3.ZERO, Vector3.UP)
	camera.current = true
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_texture = source_view.get_texture()
	for index in 24:
		var box := MeshInstance3D.new()
		box.mesh = BoxMesh.new()
		box.material_override = material
		box.position = Vector3((index % 6 - 2.5) * 2, 0, (index / 6 - 1.5) * 2)
		world.add_child(box)
	var sun := DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.rotation_degrees = Vector3(-45, 20, 0)
	world.add_child(sun)

func snapshot(label: String) -> Dictionary:
	for ignored in 32:
		await process_frame
	var image := scene_view.get_texture().get_image()
	if image == null:
		return {"valid":false}
	var png := report_path.trim_suffix(".json") + "-" + label + ".png"
	var status := image.save_png(png)
	return {"valid":status == OK and image.get_width() == 320 and image.get_height() == 240, "sha256":hash_bytes(image.get_data()), "png":png}

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):
			report_path = arg.substr(9)
	if report_path.is_empty():
		push_error("Explicit report path required")
		quit(1)
		return
	build_scene()
	var red := await snapshot("red")
	source_rect.color = Color(0.1, 0.85, 0.2)
	var green := await snapshot("green")
	var passed: bool = bool(red.get("valid", false)) and bool(green.get("valid", false)) and red.get("sha256") != green.get("sha256")
	var report := {"issue":"NWN-74", "scope":"Small Vulkan Forward+ live ViewportTexture material; no FPS claim", "passed":passed, "red":red, "green":green}
	var file := FileAccess.open(report_path, FileAccess.WRITE)
	if file == null:
		push_error("Cannot write report")
		quit(1)
		return
	file.store_string(JSON.stringify(report, "  ") + "\n")
	file.close()
	source_view.queue_free()
	scene_view.queue_free()
	quit(0 if passed else 1)
