extends SceneTree

const VisualModel = preload("res://systems/visual_model.gd")
var checks := 0
var failures: Array = []
var output := ""
var maximum_skin_error := 0.0
var maximum_reference_error := 0.0

func _initialize() -> void:
	call_deferred("run")

func expect(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)

func vector(values: Array, at: int = 0) -> Vector3:
	return Vector3(float(values[at]), float(values[at + 1]), float(values[at + 2]))

func matrix(values: Array) -> Transform3D:
	return Transform3D(Basis(vector(values), vector(values, 4), vector(values, 8)), vector(values, 12))

func geometry(row: Dictionary) -> MeshInstance3D:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	for index in range(0, row.position.size(), 3):
		vertices.append(vector(row.position, index))
		normals.append(vector(row.normal, index))
	for index in range(0, row.uv.size(), 2):
		uvs.append(Vector2(row.uv[index], row.uv[index + 1]))
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	if row.index is Array:
		arrays[Mesh.ARRAY_INDEX] = PackedInt32Array(row.index)
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = Color(0.7, 0.8, 0.9)
	mesh.surface_set_material(0, material)
	var instance := MeshInstance3D.new()
	instance.name = row.name
	instance.mesh = mesh
	instance.transform = matrix(row.matrix)
	return instance

func descendants(node: Node) -> Array:
	var result: Array = [node.get_instance_id()]
	for child in node.get_children():
		result.append_array(descendants(child))
	return result

func run() -> void:
	var oracle_path := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--oracle="):
			oracle_path = arg.substr(9)
		elif arg.begins_with("--report="):
			output = arg.substr(9)
	var oracle: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(oracle_path))
	var directory := OS.get_environment("TEMP").path_join("nwn-godot-visual-test-%s-%s" % [OS.get_process_id(), Time.get_ticks_usec()])
	expect(DirAccess.make_dir_absolute(directory) == OK, "Authored fixture directory is external")
	var room := Node3D.new()
	for row in oracle.meshes:
		var mesh := geometry(row)
		room.add_child(mesh)
		mesh.owner = room
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	expect(document.append_from_scene(room, state) == OK, "Authored resource serializes as actual GLB")
	var scene_path := directory.path_join("visual.glb")
	expect(document.write_to_filesystem(state, scene_path) == OK, "GLB stays outside workspace")
	room.free()
	var metadata: Dictionary = oracle.metadata.duplicate(true)
	metadata.sha256 = FileAccess.get_sha256(scene_path)
	var metadata_path := scene_path.get_basename() + ".json"
	var file := FileAccess.open(metadata_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(metadata))
	file.close()
	var sha := FileAccess.get_sha256(metadata_path)
	var host := Node3D.new()
	root.add_child(host)
	var camera := Camera3D.new()
	host.add_child(camera)
	camera.position = Vector3(5, 4, 8)
	camera.look_at(Vector3(1, 0.5, 0))
	camera.current = true
	var first := VisualModel.new()
	var second := VisualModel.new()
	host.add_child(first)
	host.add_child(second)
	expect(first.prepare(scene_path, sha), "Private visual resource imports native rig and skin")
	expect(second.prepare(scene_path, sha), "One resource creates a second independent render instance")
	if not first.installed or not second.installed:
		failures.append(first.error + " / " + second.error)
		finish(host, false, 0)
		return
	first.rigs.set_process(false)
	second.rigs.set_process(false)
	expect(first.rigs.entities.size() == 1 and metadata.entities.is_empty(), "Private handle has no canonical gameplay entity")
	expect(first.find_children("*", "CollisionObject3D", true, false).is_empty(), "Effect geometry does not create physics or picking bodies")
	expect(first.rigs.entities[0].models[0].player != second.rigs.entities[0].models[0].player, "AnimationPlayer owners are independent")
	expect(first.rigs.entities[0].skins[0].skeleton != second.rigs.entities[0].skins[0].skeleton, "Skeleton owners are independent")
	expect(first.node_for(1, "root") == first.node_for(1, "CHILD_BASE"), "Physical root alias and case-insensitive part name resolve")
	expect(not first.play_clip(0, "absent", false) and not first.play_clip(0, "pause1", false, NAN), "Unknown clips and invalid speeds do not mutate playback")
	var gpu := DisplayServer.get_name() != "headless"
	for sample in oracle.samples:
		first.rigs.entities[0].attachments[0].flags = int(sample.flags)
		if float(sample.time) == 0:
			first.model_root(1).quaternion = Quaternion.IDENTITY
		expect(first.play_clip(0, "pause1", false, 1.0, float(sample.time)), "Original named clip is available")
		first.rigs._update(0)
		var actual: Transform3D = first.model_root(1).global_transform
		var expected := matrix(sample.referenceMatrix)
		var distance := maxf(actual.origin.distance_to(expected.origin), maxf(actual.basis.x.distance_to(expected.basis.x), maxf(actual.basis.y.distance_to(expected.basis.y), actual.basis.z.distance_to(expected.basis.z))))
		maximum_reference_error = maxf(maximum_reference_error, distance)
		expect(distance < 0.0004, "Reference P/Q and no-scale flags agree at %s/%s" % [sample.flags, sample.time])
		if gpu:
			await process_frame
			await RenderingServer.frame_post_draw
			var baked: ArrayMesh = first.rigs.entities[0].skins[0].mesh.bake_mesh_from_current_skeleton_pose()
			var vertices: PackedVector3Array = baked.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
			for index in vertices.size():
				var error := vertices[index].distance_to(vector(sample.skin, index * 3))
				maximum_skin_error = maxf(maximum_skin_error, error)
				expect(error < 0.0004, "Private native skeleton matches independent source deformation")
	expect(second.rigs.entities[0].models[0].player.current_animation_position == 0, "Playing one resource does not advance its sibling")
	var anchor := Node3D.new()
	host.add_child(anchor)
	anchor.position = Vector3(3, 2, -1)
	anchor.scale = Vector3(4, 3, 2)
	first.scale = Vector3.ONE * 0.75
	expect(first.attach_to(anchor), "Effect attaches to an actual native anchor")
	anchor.rotation.y = 0.6
	first._process(0)
	expect(first.global_position.is_equal_approx(anchor.global_position) and first.global_basis.get_scale().is_equal_approx(Vector3.ONE * 0.75), "External attachment copies position/rotation without anchor scale")
	var rotation := first.global_basis.get_rotation_quaternion()
	first.quaternion = Quaternion(Vector3.UP, -0.7)
	expect(first.attach_to(anchor, 3), "No-orientation attachment mode is supported")
	expect(first.global_basis.get_rotation_quaternion().is_equal_approx(rotation), "Flags 3 initially copies anchor orientation even when the prior orientation differs")
	anchor.rotation.y = 1.1
	first._process(0)
	expect(first.global_basis.get_rotation_quaternion().is_equal_approx(rotation), "Flags 3 retains current world orientation")
	first.detach()
	var detached := first.global_transform
	anchor.position += Vector3.ONE
	first._process(0)
	expect(first.global_transform.is_equal_approx(detached), "Detaching retains the current world pose")
	var gated := first.node_for(0, "root")
	var frozen_scale := gated.scale
	expect(first.set_part_local_pose("root", [7, 8, 9], [1, 0, 0, 0]), "Manual part placement admits the original native quaternion order")
	first.play_clip(0, "pause1", false, 1.0, 0.25)
	first.rigs._update(0)
	expect(gated.position.is_equal_approx(Vector3(7, 9, -8)) and gated.quaternion.is_equal_approx(Quaternion.IDENTITY) and gated.scale.is_equal_approx(frozen_scale), "Manual root P/Q/scale survive animation advancement")
	var child_before := first.node_for(0, "hand").transform
	first.play_clip(0, "pause1", false, 1.0, 0.75)
	first.rigs._update(0)
	expect(not first.node_for(0, "hand").transform.is_equal_approx(child_before), "Manual root gate leaves descendant animation active")
	first.rigs.entities[0].manual_poses.clear()
	var beam := VisualModel.new();host.add_child(beam)
	expect(beam.prepare(scene_path,sha),"Reference-aware private resource imports physical reattachment metadata")
	beam.rigs.set_process(false)
	var source := Node3D.new();host.add_child(source);source.position = Vector3(-2,1,0);source.rotation.y = 0.3;source.scale = Vector3(3,4,5)
	var destination := Node3D.new();host.add_child(destination);destination.position = Vector3(4,2,-3);destination.rotation.x = 0.4;destination.scale = Vector3(5,6,7)
	expect(beam.attach_to(source) and beam.reattach_references(destination),"Beam base binds source while reattachable reference child binds target")
	expect(beam.global_position.distance_to(source.global_position) < 0.00001 and beam.model_root(1).global_position.distance_to(destination.global_position) < 0.00001,"Source/target positions remain independent actual native nodes")
	expect(beam.model_root(1).global_basis.get_scale().distance_to(Vector3.ONE*2) < 0.00001,"External reference copies target P/Q without inheriting target scale")
	expect(beam.global_basis.y.normalized().dot((destination.global_position-source.global_position).normalized()) > 0.9999,"Original reference rotation arc aligns native forward with target delta")
	destination.position += Vector3(2,1,-1);destination.rotation.z += 0.6;beam.rigs._update(0)
	expect(beam.model_root(1).global_position.distance_to(destination.global_position) < 0.00001,"Animated/external target changes update the existing reference model")
	expect(beam.model_root(1).global_basis.orthonormalized().get_rotation_quaternion().angle_to(destination.global_basis.orthonormalized().get_rotation_quaternion()) < 0.0001,"Reference orientation follows target independently of base")
	destination.queue_free();beam.rigs._update(0)
	expect(not beam.model_root(1).visible,"Queued target removal hides reference without reading a stale transform")
	await process_frame;beam.rigs._update(0)
	expect(not beam.model_root(1).visible and not beam.retired,"Freed target leaves private effect recoverable until legitimate rebind")
	var replacement := Node3D.new();host.add_child(replacement);replacement.position = Vector3(-1,4,3)
	expect(beam.reattach_references(replacement) and beam.model_root(1).visible and beam.model_root(1).global_position.distance_to(replacement.global_position) < 0.00001,"Legitimate target replacement restores original reference child without new gameplay identity")
	beam.retire()
	var rejected := VisualModel.new()
	host.add_child(rejected)
	expect(not rejected.prepare(scene_path, "0".repeat(64)) and rejected.get_child_count() == 0, "Bad metadata hash cannot allocate a render instance")
	var changed_pixels := 0
	var reordered := VisualModel.new()
	host.add_child(reordered)
	var defaults := {"position": [0, 0, 0], "quaternion": [0, 0, 0, 1], "scale": [1, 1, 1]}
	var ordered_nodes: Array = []
	for index in 4:
		ordered_nodes.append(dict_merge(defaults, {"name": "part%s" % index, "parent": index - 1}))
	var order_metadata := {"version": 1, "kind": "visual-model", "entities": [], "meshes": [], "counts": {"meshes": 0}, "modelResources": ["authored_order"], "rigs": {"version": 1, "assets": [{"name": "authored_order", "defaults": [defaults, defaults, defaults], "clips": []}], "entities": [{"id": 0, "nodes": ordered_nodes, "models": [{"asset": 0, "root": 0, "rootPart": 2, "parts": [3, 2, 1], "partNames": ["duplicate", "duplicate", "actual_root"]}]}]}}
	expect(reordered.install(Node3D.new(), order_metadata), "Unordered authored node storage imports")
	expect(reordered.node_for(0, "root") == reordered.rigs.entities[0].nodes[1], "Root alias selects physical root instead of first stored node")
	expect(reordered.node_for(0, "duplicate") == reordered.rigs.entities[0].nodes[2], "Duplicate part names preserve first physical DFS match")
	var invalid := order_metadata.duplicate(true)
	invalid.rigs.entities[0].models[0].rootPart = 99
	expect(not rejected.install(Node3D.new(), invalid) and rejected.get_child_count() == 0, "Out-of-range physical roots are rejected before native allocation")
	reordered.retire()
	if gpu:
		first.position = Vector3.ZERO
		second.visible = false
		await process_frame
		await RenderingServer.frame_post_draw
		var active := root.get_texture().get_image()
		first.visible = false
		await process_frame
		await RenderingServer.frame_post_draw
		var hidden := root.get_texture().get_image()
		for y in active.get_height():
			for x in active.get_width():
				if active.get_pixel(x, y) != hidden.get_pixel(x, y):
					changed_pixels += 1
		expect(changed_pixels > 50, "Private original geometry reaches the Vulkan drawing path")
		active.save_png(output.get_basename() + "-active.png")
	var owned := descendants(first) + descendants(second)
	first.retire()
	first.retire()
	second.attach_to(anchor)
	anchor.free()
	second._process(0)
	await process_frame
	await process_frame
	expect(owned.all(func(id): return not is_instance_id_valid(id)), "Explicit removal and missing-anchor retirement free all model/skin/player owners")
	DirAccess.remove_absolute(scene_path)
	DirAccess.remove_absolute(metadata_path)
	DirAccess.remove_absolute(directory)
	finish(host, gpu, changed_pixels)

func finish(host: Node, gpu: bool, changed_pixels: int) -> void:
	var report := {"scope": "Authored private visual model resource, actual external GLB and native rendering; no server effect lifecycle acceptance", "passed": failures.is_empty(), "checks": checks, "failures": failures, "gpu": gpu, "changed_pixels": changed_pixels, "maximum_skin_error": maximum_skin_error, "maximum_reference_error": maximum_reference_error}
	var file := FileAccess.open(output, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	host.free()
	quit(0 if failures.is_empty() else 1)

func dict_merge(first: Dictionary, second: Dictionary) -> Dictionary:
	var result := first.duplicate(true)
	result.merge(second, true)
	return result
