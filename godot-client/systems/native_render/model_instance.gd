extends Node3D
const ModelPointLight=preload("res://systems/native_render/model_point_light.gd")
# Direct original-data scene assembly. Physical parts/instances stay private;
# immutable mesh/texture/material resources are shared by the native pool.
var failure := ""
var parts: Array = []
var meshes: Array = []
var limitations: Array = []
var installed := false
var retired := false
func install(bundle: Dictionary, pool) -> bool:
	if installed or retired: failure = "Native model owner already used"; return false
	if not str(bundle.get("error","")).is_empty(): failure = bundle.error; return false
	var model: Dictionary = bundle.value
	var basis := Quaternion(Vector3.RIGHT,-PI/2)
	for index in model.nodes.size():
		var row: Dictionary = model.nodes[index]; var part := Node3D.new()
		part.name = "part_"+str(index); part.set_meta("native_part_name",row.name); part.set_meta("native_part_index",index)
		var parent := int(row.parent)
		if parent >= index or parent < -1: part.free(); failure = "Invalid physical native model parent"; _clear_parts(); return false
		if parent == -1: add_child(part)
		else: parts[parent].add_child(part)
		parts.append(part)
		part.position = Vector3(row.position[0],row.position[2],-row.position[1])
		var q := Quaternion(row.orientation[0],row.orientation[1],row.orientation[2],row.orientation[3])
		if q.length_squared() < 1e-16: q = Quaternion.IDENTITY
		part.quaternion = basis * q.normalized() * basis.inverse(); part.scale = Vector3.ONE * float(row.scale)
		for feature in row.features:
			if not limitations.has(feature): limitations.append(feature)
		if row.features.has("light") and not row.get("light",{}).is_empty():
			var light:=ModelPointLight.new(); light.configure(row.light); part.add_child(light)
		var data: Dictionary = row.mesh
		if data.is_empty() or not data.render or data.indices.is_empty(): continue
		var mesh = pool.geometry(str(bundle.sha256),index,data)
		if mesh == null: failure = pool.failure; _clear_parts(); return false
		var raster := {}; var texture_names: Array = data.textures
		if not texture_names.is_empty():
			var texture_name := str(texture_names[0]).to_lower()
			if not texture_name.is_empty() and texture_name != "null":
				if not bundle.get("textures",{}).has(texture_name): failure = "Original bitmap not prepared: "+texture_name; _clear_parts(); return false
				raster = bundle.textures[texture_name]
		var material = pool.material(row,raster)
		if material == null: failure = pool.failure; _clear_parts(); return false
		var geometry := MeshInstance3D.new(); geometry.name = "mesh"; geometry.mesh = mesh; geometry.material_override = material
		geometry.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if data.shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		geometry.visible = data.render and float(row.alpha)>0
		part.add_child(geometry); meshes.append(geometry)
	installed = true; return true
func _clear_parts() -> void:
	for part in parts:
		if is_instance_valid(part) and part.get_parent() == self: part.free()
	parts.clear(); meshes.clear()
func retire() -> void:
	if retired: return
	retired = true; _clear_parts(); queue_free()
