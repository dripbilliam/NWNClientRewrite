extends SceneTree

const Main = preload("res://main.gd")
const Connection = preload("res://systems/local_connection.gd")
const Registry = preload("res://systems/entity_registry.gd")
const Rigs = preload("res://systems/model_rigs.gd")
const Bundle = preload("res://systems/content_bundle.gd")
var checks: Array = []
var output := ""
var directory := ""
var serial := 0
var oracle: Dictionary

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, name: String) -> void:
	checks.append({"name": name, "passed": value})
	if not value:
		push_error(name)

func geometry(row: Dictionary) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.name = row.name
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	var positions := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	for i in range(0, row.position.size(), 3):
		positions.append(Vector3(row.position[i], row.position[i + 1], row.position[i + 2]))
		normals.append(Vector3(row.normal[i], row.normal[i + 1], row.normal[i + 2]))
	for i in range(0, row.uv.size(), 2):
		uvs.append(Vector2(row.uv[i], row.uv[i + 1]))
	arrays[Mesh.ARRAY_VERTEX] = positions
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	if row.index is Array:
		arrays[Mesh.ARRAY_INDEX] = PackedInt32Array(row.index)
	var data := ArrayMesh.new()
	data.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	data.surface_set_material(0, StandardMaterial3D.new())
	mesh.mesh = data
	var m: Array = row.matrix
	mesh.transform = Transform3D(Basis(Vector3(m[0], m[1], m[2]), Vector3(m[4], m[5], m[6]), Vector3(m[8], m[9], m[10])), Vector3(m[12], m[13], m[14]))
	return mesh

func bundle(revision: int) -> Dictionary:
	serial += 1
	var room := Node3D.new()
	room.name = "AuthoredContent"
	for row in oracle.meshes:
		var mesh := geometry(row)
		room.add_child(mesh)
		mesh.owner = room
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	check(doc.append_from_scene(room, state) == OK, "authored GLB serialization")
	var scene := directory.path_join("bundle_%s.glb" % serial)
	check(doc.write_to_filesystem(state, scene) == OK, "authored GLB saved externally")
	room.free()
	var metadata: Dictionary = oracle.metadata.duplicate(true)
	metadata.kind = "entity-content"
	metadata.content = [{"id": 1, "revision": revision}]
	metadata.live = {"connection": 3, "areaId": 5, "generation": 7}
	metadata.sha256 = FileAccess.get_sha256(scene)
	metadata.entities[0].pose = {"position": [0, 0, 0], "rotation": 0}
	var file := FileAccess.open(scene.get_basename() + ".json", FileAccess.WRITE)
	file.store_string(JSON.stringify(metadata))
	file.close()
	return {"kind": "content", "connection": 3, "areaId": 5, "generation": 7, "sequence": revision, "upserts": metadata.content, "remove": [], "scene": scene, "sha256": metadata.sha256, "metadataSha256": FileAccess.get_sha256(scene.get_basename() + ".json")}

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):
			output = arg.substr(9)
		elif arg.begins_with("--oracle="):
			oracle = JSON.parse_string(FileAccess.get_file_as_string(arg.substr(9)))
	if output.is_empty() or FileAccess.file_exists(output) or oracle.is_empty():
		quit(2)
		return
	directory = OS.get_environment("TEMP").path_join("nwn-godot-authored-content-" + str(Time.get_ticks_usec()))
	DirAccess.make_dir_recursive_absolute(directory)
	var host := Main.new()
	root.add_child(host)
	host.registry = Registry.new()
	host.add_child(host.registry)
	var bridge := Connection.new()
	host.add_child(bridge)
	bridge.set_process(false)
	bridge.owner_scene = host
	bridge.connection = 3
	bridge.area_id = 5
	bridge.generation = 7
	bridge.model_rigs = Rigs.new()
	host.registry.add_child(bridge.model_rigs)
	# An unaffected object and camera must retain identity through every swap.
	var untouched := Node3D.new()
	host.registry.add_child(untouched)
	bridge.pivots[99] = untouched
	host.registry.entities[99] = {"id": 99}
	host.registry.parts[99] = []
	host.registry.entity_nodes[99] = []
	var camera := Camera3D.new()
	host.add_child(camera)
	host.camera = camera
	var spawn := bundle(1)
	bridge.apply_content(spawn)
	check(bridge.pivots.has(1) and host.registry.parts[1].size() == 3, "late spawn installs complete body/skin/held geometry")
	check(bridge.model_rigs.stats.skin_meshes == 1 and bridge.model_rigs.stats.players == 1, "late spawn builds native GPU skin and animation")
	var old_mesh = weakref(host.registry.parts[1][0])
	var old_body = weakref(bridge.entity_colliders[1][0])
	bridge.pivots[1].global_position = Vector3(4, 0, 2)
	var replacement := bundle(2)
	bridge.apply_content(replacement)
	check(bridge.pivots[1].global_position == Vector3(4, 0, 2), "replacement retains current interpolated root pose")
	check(bridge.model_rigs.stats.skin_meshes == 1 and bridge.model_rigs.stats.players == 1, "replacement retires previous rig counters")
	await process_frame
	check(old_mesh.get_ref() == null and old_body.get_ref() == null, "retired meshes and nested pick bodies are freed")
	check(host.camera == camera and bridge.pivots[99] == untouched, "camera and unrelated object identities survive replacement")
	var active = bridge.pivots[1]
	for field in ["connection", "areaId", "generation", "sequence"]:
		var stale := replacement.duplicate(true)
		stale[field] = int(stale[field]) - 1
		bridge.apply_content(stale)
		check(bridge.pivots[1] == active and bridge.content_sequence == 2, "stale %s cannot replace current content" % field)
	var corrupt := Bundle.new()
	host.add_child(corrupt)
	check(not corrupt.prepare(str(spawn.scene), "0".repeat(64), {"connection": 3, "areaId": 5, "generation": 7}, spawn.upserts), "metadata tampering is rejected before adoption")
	corrupt.free()
	check(bridge.pivots[1] == active, "failed preparation preserves installed content")
	for cycle in 3:
		var remove := {"connection": 3, "areaId": 5, "generation": 7, "sequence": 3 + cycle * 2, "remove": [1], "upserts": []}
		bridge.apply_content(remove)
		await process_frame
		check(not bridge.pivots.has(1) and not host.registry.entities.has(1) and bridge.model_rigs.stats.skin_meshes == 0 and bridge.model_rigs.stats.players == 0, "remove frees all native ownership cycle %s" % cycle)
		bridge.apply_content(bundle(4 + cycle * 2))
		await process_frame
		check(bridge.pivots.has(1) and bridge.model_rigs.stats.skin_meshes == 1 and host.registry.meshes_by_name.size() == 3, "same-ID recreation has bounded meshes/rigs cycle %s" % cycle)
	host.free()
	var failed := checks.filter(func(row): return not row.passed).size()
	var result := {"scope": "Authored external GLB lifecycle, actual native import/rig/ownership; not server replication or performance acceptance", "passed": checks.size() - failed, "failed": failed, "checks": checks}
	var file := FileAccess.open(output, FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "  "))
	file.close()
	print(JSON.stringify({"passed": result.passed, "failed": failed, "report": output}))
	quit(0 if failed == 0 else 1)
