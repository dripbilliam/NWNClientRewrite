extends SceneTree

const Surface = preload("res://systems/particle_surface.gd")
var checks := 0
var failures: Array = []
var output := ""

func expect(value: bool, name: String) -> void:
	checks += 1
	if not value:
		failures.append(name)

func _initialize() -> void:
	call_deferred("run")

func vector(value: Array) -> Vector3:
	return Vector3(value[0], value[1], value[2])

func run() -> void:
	var fixture_path := ""
	var gpu := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--fixture="):
			fixture_path = arg.substr(10)
		elif arg.begins_with("--report="):
			output = arg.substr(9)
		elif arg == "--gpu":
			gpu = true
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(fixture_path))
	var host := Node3D.new()
	root.add_child(host)
	var camera := Camera3D.new()
	host.add_child(camera)
	camera.position = Vector3(0, 0, 4)
	camera.current = true
	var image := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	var texture := ImageTexture.create_from_image(image)
	var surfaces := {}
	for id in [1, 2]:
		var surface := Surface.new()
		host.add_child(surface)
		surface.configure(texture, 1, false, false)
		surfaces[id] = surface
	var visible_frames := 0
	var hidden_frames := 0
	var readback_vertices := 0
	var drawn_pixel := Color.BLACK
	var sample_pixel := Vector2i.ZERO
	var captured_pixel := false
	for frame in fixture.frames:
		for row in frame.emitters:
			var surface = surfaces[int(row.id)]
			var positions := FileAccess.get_file_as_bytes(fixture_path.get_base_dir().path_join(row.positionFile))
			var attributes := FileAccess.get_file_as_bytes(fixture_path.get_base_dir().path_join(row.attributeFile))
			var bounds := AABB()
			if row.bounds != null:
				bounds = AABB(vector(row.bounds.min), vector(row.bounds.max) - vector(row.bounds.min))
			expect(surface.apply_frame(1, int(frame.sequence), int(row.count), int(row.capacity), positions, attributes, bounds), "Worker frame admitted %s/%s" % [frame.sequence, row.id])
			expect(not surface.stream_layout.is_empty() and fixture.layout.keys().all(func(key): return int(surface.stream_layout.get(key, -1)) == int(fixture.layout[key])), "RenderingServer negotiates expected uncompressed layout")
			expect(surface.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF and surface.transform == Transform3D.IDENTITY, "World-space particles never gain model transforms or shadow passes")
			expect(surface.visible == (int(row.count) > 0), "Zero live particles hide native mesh")
			if row.count > 0:
				visible_frames += 1
			else:
				hidden_frames += 1
			if gpu:
				await process_frame
				await RenderingServer.frame_post_draw
				var arrays: Array = surface.mesh.surface_get_arrays(0)
				var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
				var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
				if int(row.id) == 1 and not captured_pixel and row.count > 0:
					var center := Vector3.ZERO
					for i in 6:
						center += vertices[i] / 6.0
					var screen: Vector2 = camera.unproject_position(center)
					sample_pixel = Vector2i(screen)
					var rendered := root.get_texture().get_image()
					drawn_pixel = rendered.get_pixelv(sample_pixel)
					captured_pixel = true
					if not output.is_empty():
						rendered.save_png(output.get_basename() + "-active.png")
				for i in row.sample.size():
					var sample: Dictionary = row.sample[i]
					expect(vertices[i].distance_to(vector(sample.position)) < 0.00001, "Uploaded worker vertex agrees after native readback")
					expect(colors[i].to_rgba32() == Color(sample.color[0] / 255.0, sample.color[1] / 255.0, sample.color[2] / 255.0, sample.color[3] / 255.0).to_rgba32(), "Uploaded RGBA byte order survives native readback")
					expect(uvs[i].distance_to(Vector2(sample.uv[0], sample.uv[1])) < 0.00001, "Original atlas UV survives native readback")
					readback_vertices += 1
				for i in range(int(row.count), int(row.capacity)):
					expect(vertices[i] == Vector3.ZERO and colors[i].a == 0.0, "Expired native quads are cleared rather than retained")
			var before: int = surface.sequence
			expect(not surface.apply_frame(0, before + 1, 0, 0, PackedByteArray(), PackedByteArray(), AABB()) and surface.sequence == before, "Retired epoch cannot overwrite current particle owner")
			expect(not surface.apply_frame(1, before, 0, 0, PackedByteArray(), PackedByteArray(), AABB()), "Duplicate/out-of-order frame cannot rewind particle pose")
	expect(visible_frames > 0 and hidden_frames > 0, "Actual worker lifetime spans visible births and fully expired emitters")
	if gpu:
		await process_frame
		await RenderingServer.frame_post_draw
		var expired := root.get_texture().get_image()
		var cleared: Color = expired.get_pixelv(sample_pixel)
		expect(captured_pixel and Vector3(drawn_pixel.r, drawn_pixel.g, drawn_pixel.b).distance_to(Vector3(cleared.r, cleared.g, cleared.b)) > 0.1, "Actual Vulkan framebuffer draws worker quads and clears them after expiration")
		if not output.is_empty():
			expired.save_png(output.get_basename() + "-expired.png")
	var surface = surfaces[1]
	var prior: int = surface.sequence
	expect(not surface.apply_frame(1, prior + 1, 6, surface.capacity, PackedByteArray(), PackedByteArray(), AABB()), "Truncated streams cannot enter RenderingServer")
	surface.retire()
	expect(surface.mesh == null and surface.source_texture == null and not surface.visible, "Retirement releases native geometry and texture ownership")
	expect(not surface.apply_frame(1, prior + 1, 0, 0, PackedByteArray(), PackedByteArray(), AABB()), "Late completion cannot revive retired particle mesh")
	surface.configure(texture, 2, true, false)
	expect(not surface.retired and surface.sequence == -1 and surface.capacity == 0 and surface.epoch == 2 and surface.top_level, "Reconfiguration owns a fresh epoch and keeps particle vertices in world space")
	expect(not surface.apply_frame(1, prior + 2, 0, 0, PackedByteArray(), PackedByteArray(), AABB()), "Reconfigured particle owner rejects previous epoch completion")
	var first: Dictionary = fixture.frames[0].emitters[0]
	var first_positions := FileAccess.get_file_as_bytes(fixture_path.get_base_dir().path_join(first.positionFile))
	var first_attributes := FileAccess.get_file_as_bytes(fixture_path.get_base_dir().path_join(first.attributeFile))
	expect(surface.apply_frame(2, 0, int(first.count), int(first.capacity), first_positions, first_attributes, AABB(vector(first.bounds.min), vector(first.bounds.max) - vector(first.bounds.min))), "Reconfigured owner creates and uploads a fresh mesh")
	var material: BaseMaterial3D = surface.mesh.surface_get_material(0)
	expect(material.blend_mode == BaseMaterial3D.BLEND_MODE_ADD and material.cull_mode == BaseMaterial3D.CULL_FRONT and material.albedo_texture == texture and material.depth_draw_mode == BaseMaterial3D.DEPTH_DRAW_DISABLED, "Original blend/front-winding/texture selection is explicit on native particle material")
	host.position = Vector3(10, 2, -4)
	expect(surface.global_transform == Transform3D.IDENTITY, "Moving an owner cannot transform already world-space particle vertices twice")
	var result := {"passed": failures.is_empty(), "checks": checks, "failures": failures, "gpu_readback": gpu, "readback_vertices": readback_vertices, "visible_frames": visible_frames, "hidden_frames": hidden_frames, "scope": "Real worker-authored packed buffers uploaded to native dynamic meshes; no installed art, world integration or performance acceptance"}
	host.free()
	if not output.is_empty():
		var file := FileAccess.open(output, FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(result, "\t") + "\n")
	print(JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)
