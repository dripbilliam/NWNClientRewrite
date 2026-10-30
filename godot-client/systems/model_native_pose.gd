extends RefCounted

const Controls = preload("res://systems/model_controllers.gd")
const ColourScopes=preload("res://systems/native_data/model_colour_scopes.gd")
var colour_scopes:=ColourScopes.create()
var parts: Array = []
var root_part: Dictionary
var metadata: Dictionary
var position_scale := 1.0
var diagnostics: Array = []
var binding: Dictionary
var nodes: Array

func configure(data: Dictionary, source: Dictionary, rig_nodes: Array, manual: Dictionary = {}) -> void:
	metadata = data
	binding = source
	nodes = rig_nodes
	for index in data.parts.size():
		var original: Dictionary = data.parts[index]
		var storage := PackedByteArray()
		storage.resize(0x240)
		storage.fill(0)
		storage.encode_float(28, 1.0)
		storage.encode_float(44, 1.0)
		var fields := {16: 3, 28: 4, 44: 1}
		if original.type == "light":
			for pair in [[104, 3], [116, 1], [124, 1], [128, 1], [168, 1]]: fields[pair[0]] = pair[1]
			storage.encode_float(168, 1.0)
		elif original.type == "trimesh":
			fields[128] = 3; fields[168] = 1
			storage.encode_float(168, 1.0)
		elif original.type == "emitter":
			for key in data.emitterFields: fields[int(key)] = 3 if str(data.emitterFields[key]).begins_with("color") else 1
			storage.encode_float(0xe8, 1.0)
			for offset in [0x224, 0x225, 0x226]: storage[offset] = 255
		var object: Node3D = nodes[int(source.parts[index])]
		var materials: Array = []
		if original.type == "trimesh":
			for child in object.get_children():
				if child is MeshInstance3D:
					# A geometry-wide override wins over surface overrides. Animate
					# a private copy of the binding that is actually drawn; leaving
					# the shared pool override in place hides all controller changes.
					if child.material_override is StandardMaterial3D:
						var unique: StandardMaterial3D=child.material_override.duplicate()
						child.material_override=unique
						materials.append({"material":unique,"color":unique.albedo_color,"hint":original.transparencyHint or unique.transparency!=BaseMaterial3D.TRANSPARENCY_DISABLED})
						continue
					for surface in child.mesh.get_surface_count():
						var material: Material = child.get_active_material(surface)
						if material is StandardMaterial3D:
							var unique: StandardMaterial3D = material.duplicate()
							child.set_surface_override_material(surface, unique)
							materials.append({"material": unique, "color": unique.albedo_color, "hint": original.transparencyHint or unique.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED})
		parts.append({"source": original, "object": object, "id30": original.node.id34, "dirty60": 0, "field8c": int(original.properties.get("isdynamic", 0)), "owner50": null, "children38": [], "childCount40": original.children.size(), "view": storage, "fields": fields, "materials": materials})
	for part in parts:
		for index in part.source.children: part.children38.append(parts[int(index)])
		# Static node controllers initialize their Part before placement.
		control(part.source.node, part, 0, 0, 1)
	root_part = parts[int(data.root)]
	for index in manual:
		set_manual(int(index), manual[index].position, manual[index].quaternion)
	flush(manual)

func part_for(rig_node: int) -> int:
	for index in binding.parts.size():
		if int(binding.parts[index]) == rig_node: return index
	return -1

func set_manual(rig_node: int, position: Vector3, quaternion: Quaternion) -> void:
	var index := part_for(rig_node)
	if index < 0: return
	write(parts[index], 16, [position.x, -position.z, position.y])
	write(parts[index], 28, [quaternion.w, quaternion.x, -quaternion.z, quaternion.y])

func read(part: Dictionary, offset: int, count: int) -> Array:
	assert(part.fields.get(offset) == count, "Native controller field is unavailable")
	var result: Array = []
	for index in count: result.append(part.view.decode_float(offset + index * 4))
	return result

func write(part: Dictionary, offset: int, value: Array) -> void:
	assert(part.fields.get(offset) == value.size(), "Native controller field is unavailable")
	for index in value.size(): part.view.encode_float(offset + index * 4, value[index])

func diagnose(message: String) -> void:
	if not diagnostics.has(message): diagnostics.append(message)

func control(node: Dictionary, part: Dictionary, previous: float, time: float, weight: float) -> void:
	if int(node.flags98) & 0x80:
		diagnose("native animated-vertex solver unavailable")
		return
	Controls.control(node, part, previous, time, weight, {"read": read, "write": write, "positionScale": func(): return position_scale, "activeMotionRun": func(): return false, "motion": func(_c, _p, _n, _from, _to): pass})
	if int(node.flags98) & 256: diagnose("native dangly solver unavailable")

func apply(tree: Dictionary, previous: float, time: float, weight: float, scale_value: float, manual: Dictionary) -> void:
	position_scale = Controls.f(scale_value)
	for index in parts.size(): parts[index].dirty60 = 1 if manual.has(int(binding.parts[index])) else 0
	Controls.hierarchy(root_part, tree, previous, time, weight, {"depth": 0}, {"control": control, "light": func(part): return part if part.source.type == "light" else null,
		"animateStaticLight": func(_owner, _light): diagnose("native static-light invalidation unavailable")})
	flush(manual)

static func srgb(value: float) -> float:
	return value * 0.0773993808 if value < 0.04045 else pow(value * 0.9478672986 + 0.0521327014, 2.4)

func flush(manual: Dictionary = {}) -> void:
	var scoped: Variant=ColourScopes.selected(colour_scopes)
	for index in parts.size():
		var part: Dictionary = parts[index]
		if manual.has(int(binding.parts[index])): continue
		var position := read(part, 16, 3)
		var q := read(part, 28, 4)
		var scale_value: float = read(part, 44, 1)[0]
		var object: Node3D = part.object
		object.position = Vector3(position[0], position[2], -position[1])
		object.quaternion = Quaternion(q[1], q[3], -q[2], q[0])
		object.scale = Vector3.ONE * scale_value
		if part.source.type == "trimesh":
			var alpha := clampf(read(part, 168, 1)[0], 0.0, 1.0)
			var color := read(part, 128, 3)
			if scoped!=null: color=scoped
			for row in part.materials:
				var material: StandardMaterial3D = row.material
				material.albedo_color = Color(scoped[0],scoped[1],scoped[2],alpha) if scoped!=null else Color(row.color.r, row.color.g, row.color.b, alpha)
				material.emission_enabled = color.any(func(value): return value != 0)
				material.emission = Color(srgb(color[0]), srgb(color[1]), srgb(color[2]))
				material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if row.hint or alpha < 1 else BaseMaterial3D.TRANSPARENCY_DISABLED
		elif part.source.type == "light":
			diagnose("native animated-light renderer binding unavailable")

func set_colour_scope(scope: int,rgb: Variant,manual: Dictionary={}) -> bool:
	if not ColourScopes.set_colour(colour_scopes,scope,rgb): return false
	flush(manual); return true

func emitter_properties(rig_node: int) -> Dictionary:
	var part_index := part_for(rig_node)
	if part_index < 0 or parts[part_index].source.type != "emitter": return {}
	var part: Dictionary = parts[part_index]
	var result := {}
	for key in metadata.emitterFields:
		var name := str(metadata.emitterFields[key])
		var offset := int(key)
		if name.begins_with("percent") or name == "detonate": result[name] = int(part.view[offset])
		elif name.begins_with("color"): result[name] = read(part, offset, 3)
		else: result[name] = read(part, offset, 1)[0]
	return result
