extends SceneTree

const Registry = preload("res://systems/entity_registry.gd")
const Rigs = preload("res://systems/model_rigs.gd")
const Connection = preload("res://systems/local_connection.gd")
class Owner:
	extends RefCounted
	var registry
var failures: Array[String] = []
var checks := 0
var output := ""

func _initialize() -> void:
	call_deferred("run")

func expect(value: bool, name: String) -> void:
	checks += 1
	if not value:
		failures.append(name)

func transform(values: Array) -> Transform3D:
	return Transform3D(Basis(Vector3(values[0], values[1], values[2]), Vector3(values[4], values[5], values[6]), Vector3(values[8], values[9], values[10])), Vector3(values[12], values[13], values[14]))

func vector(values: Array, at: int) -> Vector3:
	return Vector3(float(values[at]), float(values[at + 1]), float(values[at + 2]))

func run() -> void:
	var oracle_path := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--oracle="):
			oracle_path = arg.substr(9)
		elif arg.begins_with("--report="):
			output = arg.substr(9)
	var oracle: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(oracle_path))
	var host := Node3D.new()
	root.add_child(host)
	var camera := Camera3D.new()
	host.add_child(camera)
	camera.position = Vector3(5, 4, 8)
	camera.look_at(Vector3(1, 0.5, 0))
	camera.current = true
	var room := Node3D.new()
	host.add_child(room)
	for source in oracle.meshes:
		var mesh := MeshInstance3D.new()
		mesh.name = source.name
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		var positions := PackedVector3Array()
		var normals := PackedVector3Array()
		var uvs := PackedVector2Array()
		for index in range(0, source.position.size(), 3):
			positions.append(vector(source.position, index))
			normals.append(vector(source.normal, index))
		for index in range(0, source.uv.size(), 2):
			uvs.append(Vector2(source.uv[index], source.uv[index + 1]))
		arrays[Mesh.ARRAY_VERTEX] = positions
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_TEX_UV] = uvs
		if source.index is Array:
			arrays[Mesh.ARRAY_INDEX] = PackedInt32Array(source.index)
		var geometry := ArrayMesh.new()
		geometry.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		material.albedo_color = Color(0.7, 0.8, 0.9)
		geometry.surface_set_material(0, material)
		mesh.mesh = geometry
		room.add_child(mesh)
		mesh.transform = transform(source.matrix)
	var registry := Registry.new()
	host.add_child(registry)
	registry.configure(room, oracle.metadata)
	var pivot := Node3D.new()
	registry.add_child(pivot)
	for mesh in registry.parts[1]:
		mesh.reparent(pivot, true)
	var rigs := Rigs.new()
	registry.add_child(rigs)
	rigs.configure(registry, {1: pivot}, oracle.metadata)
	rigs.set_process(false)
	expect(rigs.stats.failures.is_empty(), "Native physical rig and skin preparation succeeds")
	expect(rigs.stats.skin_meshes == 1 and rigs.stats.skin_vertices == 3, "Original sparse skin and zero-weight vertex reach the native skeleton")
	var skin: Dictionary = rigs.entities[1].skins[0]
	var mesh: MeshInstance3D = skin.mesh
	var rigid_name := ""
	var held_name := ""
	var first_model: Dictionary = oracle.metadata.rigs.entities[0].models[0]
	var held_model: Dictionary = oracle.metadata.rigs.entities[0].models[1] if oracle.metadata.rigs.entities[0].models.size() > 1 else {}
	for row in oracle.metadata.meshes:
		if row.has("rigNode") and int(row.rigNode) == int(first_model.parts[1]) and not row.has("skin"):
			rigid_name = str(row.name)
		if not held_model.is_empty() and row.has("rigNode") and int(row.rigNode) == int(held_model.parts[0]):
			held_name = str(row.name)
	var rigid: MeshInstance3D = registry.meshes_by_name[rigid_name]
	var held: MeshInstance3D = registry.meshes_by_name.get(held_name)
	var model: Dictionary = rigs.entities[1].models[0]
	var maximum_error := 0.0
	var maximum_rigid_error := 0.0
	var gpu := DisplayServer.get_name() != "headless"
	for sample in oracle.samples:
		rigs._play(model, sample.clip, false, 1.0)
		model.player.seek(float(sample.time), true)
		rigs._update(0)
		var expected := transform(sample.rigidMatrix)
		var rigid_error := maxf(rigid.global_transform.origin.distance_to(expected.origin), maxf(rigid.global_basis.x.distance_to(expected.basis.x), maxf(rigid.global_basis.y.distance_to(expected.basis.y), rigid.global_basis.z.distance_to(expected.basis.z))))
		maximum_rigid_error = maxf(maximum_rigid_error, rigid_error)
		expect(rigid_error < 0.0004, "Rigid attachment follows source pose %s/%s (error %s)" % [sample.clip, sample.time, rigid_error])
		if held != null:
			expect(held.global_transform.is_equal_approx(transform(sample.heldMatrix)), "Held item follows source anchor without inheriting its scale %s/%s" % [sample.clip, sample.time])
		if gpu:
			await process_frame
			await RenderingServer.frame_post_draw
			var baked := mesh.bake_mesh_from_current_skeleton_pose()
			var vertices: PackedVector3Array = baked.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
			var error := 0.0
			for index in vertices.size():
				error = maxf(error, vertices[index].distance_to(vector(sample.skin, index * 3)))
			maximum_error = maxf(maximum_error, error)
			expect(error < 0.0004, "Native GPU skin agrees with original weighted source arithmetic %s/%s (error %s)" % [sample.clip, sample.time, error])
		else:
			expect(skin.skeleton.get_bone_count() == 65, "Headless fixture validates only hierarchy/skin setup, not GPU deformation")
	var connection := Connection.new()
	var owner := Owner.new()
	owner.registry = registry
	connection.owner_scene = owner
	connection.connection = 1
	connection.generation = 1
	connection.area_id = 2
	connection.controlled_id = 1
	connection.world_scope.reset(1)
	var admitted := {"connection": 1, "generation": 1, "areaId": 2, "transferId": 1}
	expect(connection.world_scope.begin(admitted) and connection.world_scope.admit(admitted), "Collider regression uses a genuinely admitted native area scope")
	connection.pivots = {1: pivot}
	connection.source_eligibility = {1: true}
	var bodies: Array = []
	for part in registry.parts[1]:
		bodies.append(part.get_meta("collision_body"))
	connection.entity_colliders = {1: bodies}
	connection.receive({"kind": "poses", "connection": 1, "generation": 1, "areaId": 2, "transferId": 1, "controlledId": 1, "poses": [{"id": 1, "position": [0, 0, 0], "rotation": 0, "removed": true}]})
	expect(not pivot.visible and bodies.all(func(body): return body.collision_layer == 0), "Removal disables every collider after rigid parts move into the animation hierarchy")
	connection.receive({"kind": "poses", "connection": 1, "generation": 1, "areaId": 2, "transferId": 1, "controlledId": 1, "poses": [{"id": 1, "position": [0, 0, 0], "rotation": 0, "removed": false}]})
	expect(pivot.visible and bodies.all(func(body): return body.collision_layer == 1), "Reappearance restores every animated part collider")
	connection.free()
	var result := {"passed": failures.is_empty(), "checks": checks, "failures": failures, "gpu_skin_readback": gpu, "maximum_position_error": maximum_error, "maximum_rigid_error": maximum_rigid_error, "stats": rigs.stats, "scope": "Authored model nodes, native linear/quaternion/Bezier tracks and sparse/zero/nonunit skin against original JS arithmetic; no game content or FPS acceptance"}
	host.free()
	if not output.is_empty():
		var file := FileAccess.open(output, FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(result, "\t") + "\n")
	print(JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)
