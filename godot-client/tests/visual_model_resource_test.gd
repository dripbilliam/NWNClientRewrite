extends SceneTree

const VisualModel = preload("res://systems/visual_model.gd")
var failures: Array = []
var checks := 0
var output := ""

func _initialize() -> void:
	call_deferred("run")

func expect(value: bool, name: String) -> void:
	checks += 1
	if not value:
		failures.append(name)

func run() -> void:
	var source_path := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--source-report="):
			source_path = arg.substr(16)
		elif arg.begins_with("--report="):
			output = arg.substr(9)
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(source_path))
	var resource: Dictionary = source.get("visualResource", {})
	var host := Node3D.new()
	root.add_child(host)
	var model := VisualModel.new()
	host.add_child(model)
	expect(source.get("success", false) and resource.get("model") == "c_golstone", "Original installed model was exported during a real owned-local session")
	expect(model.prepare(str(resource.get("scene", "")), str(resource.get("metadataSha256", ""))), "Native private instance loads the exact authenticated external model bundle")
	if not model.installed:
		failures.append(model.error)
		finish(host, {})
		return
	model.rigs.set_process(false)
	expect(model.metadata.modelResources[0] == "c_golstone" and model.metadata.entities.is_empty(), "Original resource name survives without a canonical entity")
	expect(model.find_children("*", "CollisionObject3D", true, false).is_empty(), "Installed visual resource creates no interaction or collision objects")
	var textures := {}
	var bound := AABB()
	var initialized := false
	for mesh in model.meshes.meshes_by_name.values():
		var box: AABB = mesh.global_transform * mesh.mesh.get_aabb()
		bound = bound.merge(box) if initialized else box
		initialized = true
		for index in mesh.mesh.get_surface_count():
			var material: Material = mesh.get_active_material(index)
			if material is BaseMaterial3D and material.albedo_texture != null:
				textures[material.albedo_texture.get_rid()] = true
	expect(not textures.is_empty(), "Original installed bitmap data reaches native materials")
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color(0.02, 0.02, 0.02)
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color.WHITE
	settings.ambient_light_energy = 1.0
	environment.environment = settings
	host.add_child(environment)
	var camera := Camera3D.new()
	host.add_child(camera)
	var extent := maxf(2.0, bound.get_longest_axis_size())
	camera.position = bound.get_center() + Vector3(1.0, 0.6, 1.4).normalized() * extent * 1.8
	camera.look_at(bound.get_center())
	camera.current = true
	var names: Dictionary = model.rigs.entities[0].models[0].names
	var clip := "walk" if names.has("walk") else (str(names.keys()[0]) if not names.is_empty() else "")
	expect(not clip.is_empty() and model.play_clip(0, clip, true), "Installed original animation is available through native playback")
	await process_frame
	await RenderingServer.frame_post_draw
	var before: Dictionary = model.rigs.diagnostic_sample()
	model.rigs._update(0.25)
	await process_frame
	await RenderingServer.frame_post_draw
	var comparison: Dictionary = model.rigs.compare_samples(before, model.rigs.diagnostic_sample())
	expect(int(comparison.get("changed_local_parts", 0)) > 0 or float(comparison.get("maximum_local_skin_vertex_delta", 0)) > 0.0001, "Installed native model pose actually changes")
	var active := root.get_texture().get_image()
	model.visible = false
	await process_frame
	await RenderingServer.frame_post_draw
	var hidden := root.get_texture().get_image()
	var pixels := 0
	for y in active.get_height():
		for x in active.get_width():
			if active.get_pixel(x, y) != hidden.get_pixel(x, y):
				pixels += 1
	expect(pixels > 500, "Original textured model reaches actual Vulkan pixels")
	active.save_png(output.get_basename() + "-active.png")
	var id := model.get_instance_id()
	model.retire()
	await process_frame
	await process_frame
	expect(not is_instance_id_valid(id), "Installed resource instance retires after drawing")
	finish(host, {"model": resource.model, "texture_resources": textures.size(), "clip": clip, "pose_change": comparison, "changed_pixels": pixels})

func finish(host: Node, details: Dictionary) -> void:
	var file := FileAccess.open(output, FileAccess.WRITE)
	file.store_string(JSON.stringify({"scope": "Original installed model asset through private staging/import/render/retirement; not actual server transient effects or performance parity", "passed": failures.is_empty(), "checks": checks, "failures": failures, "details": details}, "\t"))
	file.close()
	host.free()
	quit(0 if failures.is_empty() else 1)
