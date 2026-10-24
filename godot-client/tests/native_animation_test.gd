extends "res://tests/visual_model_test.gd"

const Values = preload("res://tests/oracle_values.gd")
var maximum_pose_error := 0.0

func run() -> void:
	var oracle_path := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--oracle="): oracle_path = arg.substr(9)
		elif arg.begins_with("--report="): output = arg.substr(9)
	var oracle: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(oracle_path))
	var directory := OS.get_environment("TEMP").path_join("nwn-native-animation-%s-%s" % [OS.get_process_id(), Time.get_ticks_usec()])
	expect(DirAccess.make_dir_absolute(directory) == OK, "Authored bundle uses external temporary storage")
	var room := Node3D.new()
	for row in oracle.meshes:
		var mesh := geometry(row)
		room.add_child(mesh)
		mesh.owner = room
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	expect(document.append_from_scene(room, state) == OK, "Authored geometry serializes")
	var path := directory.path_join("model.glb")
	expect(document.write_to_filesystem(state, path) == OK, "Authored GLB is external")
	room.free()
	var metadata: Dictionary = oracle.metadata
	metadata.sha256 = FileAccess.get_sha256(path)
	var file := FileAccess.open(path.get_basename() + ".json", FileAccess.WRITE)
	file.store_string(JSON.stringify(metadata)); file.close()
	var host := Node3D.new()
	root.add_child(host)
	var model := VisualModel.new()
	var sibling := VisualModel.new()
	host.add_child(model); host.add_child(sibling)
	var digest := FileAccess.get_sha256(path.get_basename() + ".json")
	expect(model.prepare(path, digest) and sibling.prepare(path, digest), "Native controller resources create independent private instances")
	model.rigs.set_process(false); sibling.rigs.set_process(false)
	var events: Array = []
	model.rigs.model_event.connect(func(_id, _index, name, _serial): events.append(name))
	var maximum_runs := 0
	for frame in Values.decode(oracle.frames):
		var operation: Dictionary = frame.operation
		if operation.has("play"):
			var p: Array = operation.play
			expect(model.play_effect_clip(p[0], p[1], int(p[2]), p[3]) == frame.result, "Native play/reuse/queue/clear result")
		else: model.rigs._update(float(operation.delta))
		var owner = model.rigs.entities[0].models[0].native_owner
		expect(Values.equal_values(events, frame.events), "Start/done/authored events preserve original order")
		var runs: Array = owner.gob.runsE0.map(func(run): return {"name": run.clip0.name, "time": run.time14, "weight": run.weight18, "flags": run.flagsC, "done": run.done24})
		maximum_runs = maxi(maximum_runs, runs.size())
		expect(Values.equal_values(runs, frame.runs), "Native graph playback retains exact original run fields")
		for index in frame.parts.size():
			var part: Dictionary = owner.pose.parts[index]
			var fields := {"position": owner.pose.read(part, 16, 3), "quaternion": owner.pose.read(part, 28, 4), "scale": owner.pose.read(part, 44, 1)}
			if part.source.type == "trimesh":
				fields.alpha = owner.pose.read(part, 168, 1); fields.selfillum = owner.pose.read(part, 128, 3)
				for row in part.materials: expect(absf(row.material.albedo_color.a - float(fields.alpha[0])) < 0.000001, "Native mesh alpha reaches its own material")
			elif part.source.type == "emitter":
				fields.birthrate = owner.pose.read(part, 116, 1); fields.velocity = owner.pose.read(part, 220, 1); fields.colorstart = owner.pose.read(part, 136, 3)
				var properties: Dictionary = owner.pose.emitter_properties(int(owner.pose.binding.parts[index]))
				expect(Values.equal_values([properties.birthrate, properties.velocity, properties.colorstart], [fields.birthrate[0], fields.velocity[0], fields.colorstart]), "Emitter workers receive the native blended fields")
			expect(Values.equal_values(fields, frame.parts[index]), "Every native Part field matches original-derived ordered controller writes")
			var expected: Dictionary = frame.local[index]
			var p_error: float = part.object.position.distance_to(vector(expected.position))
			var s_error: float = part.object.scale.distance_to(vector(expected.scale))
			maximum_pose_error = maxf(maximum_pose_error, maxf(p_error, s_error))
			expect(p_error < 0.00001 and s_error < 0.00001, "Original controller fields reach native local transforms")
			var rotation := Quaternion(float(expected.quaternion[0]), float(expected.quaternion[1]), float(expected.quaternion[2]), float(expected.quaternion[3]))
			expect(absf(part.object.quaternion.dot(rotation)) > 0.99999, "Original quaternion basis conversion reaches native orientation")
	expect(maximum_runs >= 2, "Actual graph test exercises simultaneous native animation runs")
	expect(sibling.rigs.entities[0].models[0].get("native_owner") == null, "Sibling has independent run/pose ownership")
	var sibling_mesh: MeshInstance3D = sibling.meshes.meshes_by_name.values()[0]
	var first_material: Material = model.rigs.entities[0].models[0].native_owner.pose.parts[2].materials[0].material
	expect(first_material != sibling_mesh.get_active_material(0) and sibling_mesh.get_active_material(0).albedo_color.a == 1, "Controller material changes cannot affect another instance")
	expect(sibling.set_part_local_pose("root", [7, 8, 9], [1, 0, 0, 0]), "Manual native root may be placed before lazy playback initialization")
	sibling.play_effect_clip("duration", 1, 0, 0)
	sibling.rigs._update(0.2)
	expect(sibling.node_for(0, "root").position.is_equal_approx(Vector3(7, 9, -8)), "Lazy native controller initialization preserves manual placement")
	var sibling_owner = sibling.rigs.entities[0].models[0].native_owner
	expect(Values.equal_values(sibling_owner.pose.read(sibling_owner.pose.root_part, 16, 3), [7, 8, 9]), "Native manual fields retain the same placement as the scene node")
	var child_position: Vector3 = sibling.node_for(0, "emitter").position
	sibling.set_part_local_pose("root", [1, 2, 3], [1, 0, 0, 0])
	sibling.rigs._update(0.2)
	expect(sibling.node_for(0, "root").position.is_equal_approx(Vector3(1, 3, -2)) and not sibling.node_for(0, "emitter").position.is_equal_approx(child_position), "Late manual root writes suppress only that part and retain descendant control")
	sibling_owner = null
	var camera := Camera3D.new()
	host.add_child(camera); camera.position = Vector3(4, 3, 6); camera.look_at(Vector3.ZERO); camera.current = true
	model.play_effect_clip("duration", 1, 3, 0.4); model.rigs._update(0.1)
	sibling.visible = false
	var pixels := 0
	if DisplayServer.get_name() != "headless":
		await process_frame; await RenderingServer.frame_post_draw
		var active := root.get_texture().get_image()
		model.visible = false
		await process_frame; await RenderingServer.frame_post_draw
		var hidden := root.get_texture().get_image()
		for y in active.get_height():
			for x in active.get_width():
				if active.get_pixel(x, y) != hidden.get_pixel(x, y): pixels += 1
		expect(pixels > 32, "Native-run-controlled original geometry reaches Vulkan")
		active.save_png(output.get_basename() + "-active.png")
	var native_owner = model.rigs.entities[0].models[0].native_owner
	var weak: WeakRef = weakref(native_owner)
	model.retire(); sibling.retire()
	expect(native_owner.closed and native_owner.entry.is_empty() and native_owner.providers.is_empty(), "Retirement breaks run/provider/entry ownership cycles")
	native_owner = null
	await process_frame; await process_frame
	expect(weak.get_ref() == null, "Retired native animation owner is actually released")
	DirAccess.remove_absolute(path); DirAccess.remove_absolute(path.get_basename() + ".json"); DirAccess.remove_absolute(directory)
	file = FileAccess.open(output, FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed": failures.is_empty(), "checks": checks, "failures": failures, "frames": oracle.frames.size(), "maximumRuns": maximum_runs, "maximumPoseError": maximum_pose_error, "changedPixels": pixels, "scope": "Authored complete run/controller/private graph integration against original-derived JS; not full effect/scene parity"}, "\t")); file.close()
	host.free()
	quit(0 if failures.is_empty() else 1)
