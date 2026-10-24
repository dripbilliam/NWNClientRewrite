extends "res://systems/visual_model.gd"

# Retain the effect model's strict validation. Only this private creator class
# accepts the separate body/part preview envelope.
func _valid_metadata(value: Dictionary) -> bool:
	if value.get("kind") != "creation-preview" or not value.get("creationAppearance") is Dictionary or int(value.get("counts", {}).get("meshes", 0)) < 1: return false
	var bounds: Dictionary = value.get("bounds", {})
	for key in ["min", "max"]:
		var vector = bounds.get(key)
		if not vector is Array or vector.size() != 3: return false
		for component in vector:
			if not (component is float or component is int) or not is_finite(float(component)): return false
	var compatible := value.duplicate(false); compatible["kind"] = "visual-model"
	return super._valid_metadata(compatible)

func prepare_bytes(bytes: PackedByteArray, value: Dictionary) -> bool:
	if not _valid_metadata(value): return _fail("Invalid private creator model metadata")
	var document := GLTFDocument.new(); var state := GLTFState.new()
	if document.append_from_buffer(bytes, "", state) != OK: return _fail("Creator GLB import failed")
	var room := document.generate_scene(state)
	if room == null: return _fail("Creator model scene generation failed")
	return install(room, value)
