extends RefCounted

# One admitted world's immutable model resources. GLB import happens once per
# resource; every use still creates fresh nodes/AnimationPlayers/skeletons.
const VisualModel = preload("res://systems/visual_model.gd")
var scope: Dictionary = {}
var entries: Dictionary = {}
var error := ""
var stats := {"imports": 0, "cache_hits": 0, "instances": 0, "definitions": 0}

func configure(value: Dictionary) -> void:
	assert(scope.is_empty(), "Visual resource scope cannot be rebound")
	scope = value.duplicate(true)

func _external(path: String) -> bool:
	var project := ProjectSettings.globalize_path("res://").replace("\\", "/").to_lower().trim_suffix("/") + "/"
	return path.is_absolute_path() and not path.replace("\\", "/").to_lower().begins_with(project)

func prepare_resource(key: String, envelope: Dictionary) -> bool:
	error = ""
	if key.is_empty() or not _external(str(envelope.get("scene", ""))) or str(envelope.get("metadataSha256", "")).length() != 64 or str(envelope.get("sha256", "")).length() != 64:
		return _fail("Invalid external visual resource envelope")
	if entries.has(key):
		if entries[key].metadata_sha != envelope.metadataSha256 or entries[key].sha != envelope.sha256:
			return _fail("Visual resource changed inside its immutable world scope")
		stats.cache_hits += 1
		return true
	var scene_path := str(envelope.scene)
	var metadata_path := scene_path.get_basename() + ".json"
	if FileAccess.get_sha256(metadata_path) != envelope.metadataSha256 or FileAccess.get_sha256(scene_path) != envelope.sha256:
		return _fail("Visual resource digest mismatch")
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(metadata_path))
	if not parsed is Dictionary or parsed.get("sha256") != envelope.sha256:
		return _fail("Invalid visual resource metadata")
	var validator := VisualModel.new()
	var valid: bool = validator._valid_metadata(parsed)
	validator.free()
	if not valid:
		return _fail("Visual resource has invalid private rig ownership")
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	if document.append_from_file(scene_path, state) != OK:
		return _fail("Visual resource GLB import failed")
	var room := document.generate_scene(state)
	if room == null:
		return _fail("Visual resource scene generation failed")
	var packed := PackedScene.new()
	var result := packed.pack(room)
	room.free()
	if result != OK:
		return _fail("Visual resource packing failed")
	entries[key] = {"packed": packed, "metadata": parsed, "metadata_sha": envelope.metadataSha256, "sha": envelope.sha256}
	stats.imports += 1
	return true

func instantiate_model(key: String, parent: Node3D):
	error = ""
	if not entries.has(key) or not is_instance_valid(parent) or not parent.is_inside_tree():
		_fail("Visual instance requires a prepared resource and live native parent")
		return null
	var room: Node3D = entries[key].packed.instantiate()
	var instance := VisualModel.new()
	parent.add_child(instance)
	if not instance.install(room, entries[key].metadata):
		_fail(instance.error)
		instance.free()
		return null
	stats.instances += 1
	return instance

func prepare_definition(file: String, sha: String) -> Dictionary:
	error = ""
	if scope.is_empty() or not _external(file) or sha.length() != 64 or FileAccess.get_sha256(file) != sha:
		_fail("Invalid scoped visual definition digest")
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(file))
	if not parsed is Dictionary or parsed.get("version") != 1 or parsed.get("kind") not in ["visual-definition","area-visual-definition"] or not parsed.get("state") is Dictionary or not parsed.get("resources") is Dictionary:
		_fail("Invalid visual definition metadata")
		return {}
	for field in ["connection", "areaId", "generation", "transferId"]:
		if not scope.has(field) or parsed.get("live", {}).get(field) != scope[field]:
			_fail("Visual definition belongs to a retired native world")
			return {}
	var area: bool = parsed.kind == "area-visual-definition"
	if parsed.resources.size() > (1 if area else 32) or (not area and parsed.state.get("models88", []).size() != 3):
		_fail("Visual definition model limits are invalid")
		return {}
	for model in ([parsed.state.get("model")] if area else parsed.state.models88):
		if model != null and (not model is Dictionary or not parsed.resources.has(model.get("resource", ""))):
			_fail("Visual definition references an unavailable geometry resource")
			return {}
	for program in parsed.get("programs", {}).values():
		if program.get("resource") != null and not parsed.resources.has(program.resource):
			_fail("Visual definition references an unavailable program resource")
			return {}
	for key in parsed.resources:
		if not prepare_resource(str(key), parsed.resources[key]):
			return {}
	stats.definitions += 1
	return parsed

func clear() -> void:
	# Existing instances retain their own resource references. The outer effect
	# list owns those nodes and must retire them when the world is destroyed.
	entries.clear()

func _fail(reason: String) -> bool:
	error = reason
	return false
