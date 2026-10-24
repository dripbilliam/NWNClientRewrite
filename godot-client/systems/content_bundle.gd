extends Node3D

# Prepare a replacement off screen, including native rigs and physics, before
# retiring any existing content. Only complete, scoped bundles are adopted.
const Registry = preload("res://systems/entity_registry.gd")
const Rigs = preload("res://systems/model_rigs.gd")
var registry
var rigs
var pivots: Dictionary = {}
var metadata: Dictionary = {}
var error := ""

func prepare(scene_path: String, metadata_sha: String, scope: Dictionary, upserts: Array) -> bool:
	visible = false
	set_process(false)
	if not scene_path.is_absolute_path() or scene_path.begins_with(ProjectSettings.globalize_path("res://")):
		return _fail("Content must use an external runtime bundle")
	var metadata_path := scene_path.get_basename() + ".json"
	if metadata_sha.length() != 64 or FileAccess.get_sha256(metadata_path) != metadata_sha:
		return _fail("Content metadata hash mismatch")
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(metadata_path))
	if not parsed is Dictionary:
		return _fail("Invalid content metadata")
	metadata = parsed
	if metadata.get("version") != 1 or metadata.get("kind") != "entity-content" or FileAccess.get_sha256(scene_path) != metadata.get("sha256", ""):
		return _fail("Content GLB hash or version mismatch")
	for key in ["connection", "areaId", "generation"]:
		if metadata.get("live", {}).get(key) != scope.get(key):
			return _fail("Content belongs to a retired world")
	var revisions: Array = metadata.get("content", [])
	if revisions.size() != upserts.size():
		return _fail("Content revisions do not match the bridge envelope")
	for index in revisions.size():
		if int(revisions[index].id) != int(upserts[index].id) or int(revisions[index].revision) != int(upserts[index].revision):
			return _fail("Content revisions do not match the bridge envelope")
	var ids := upserts.map(func(row): return int(row.id))
	if ids.size() != metadata.get("entities", []).size():
		return _fail("Content entity count mismatch")
	for row in metadata.get("entities", []):
		if not ids.has(int(row.id)) or not row.has("pose"):
			return _fail("Unowned entity or missing pose in content")
	for row in metadata.get("meshes", []) + metadata.get("lights", []):
		if not ids.has(int(row.get("objectId", -1) if row.get("objectId") != null else -1)):
			return _fail("Unowned geometry or light in content")
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	if document.append_from_file(scene_path, state) != OK:
		return _fail("Content GLB import failed")
	var room := document.generate_scene(state)
	if room == null:
		return _fail("Content scene generation failed")
	add_child(room)
	registry = Registry.new()
	add_child(registry)
	registry.configure(room, metadata, state)
	if registry.meshes_by_name.size() != int(metadata.get("counts", {}).get("meshes", -1)) or registry.stats.missing_bindings > 0 or registry.stats.particle_errors > 0:
		return _fail("Content mesh/material binding failed")
	for row in metadata.entities:
		var id := int(row.id)
		var pivot := Node3D.new()
		registry.add_child(pivot)
		pivot.global_transform = Transform3D(Basis(Vector3.UP, float(row.pose.rotation)), _vec(row.pose.position))
		pivots[id] = pivot
		for node in registry.entity_nodes[id]:
			node.reparent(pivot, true)
	for body in registry.get_children():
		if body is StaticBody3D:
			var id := int(body.get_meta("entity_id", -1))
			if pivots.has(id):
				body.reparent(pivots[id], true)
	rigs = Rigs.new()
	registry.add_child(rigs)
	rigs.configure(registry, pivots, metadata)
	rigs.set_process(false)
	if not rigs.stats.failures.is_empty():
		return _fail("Content native rig/skin preparation failed")
	return true

func _vec(value: Array) -> Vector3:
	return Vector3(float(value[0]), float(value[1]), float(value[2]))

func _fail(reason: String) -> bool:
	error = reason
	return false
