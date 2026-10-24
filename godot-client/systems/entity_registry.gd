extends Node3D

var entities: Dictionary = {}
var parts: Dictionary = {}
var entity_nodes: Dictionary = {}
var bounds: Dictionary = {}
var meshes_by_name: Dictionary = {}
var marked: Dictionary = {}
var overlays: Dictionary = {}
var original_overlays: Dictionary = {}
var cpu_faces: Dictionary = {}
var stats := {"entities": 0, "bound_meshes": 0, "particle_materials": 0, "colliders": 0, "missing_bindings": 0, "particle_errors": 0, "importer_geometries": 0, "runtime_geometry_reads": 0, "preparation_ms": 0.0}

func configure(room: Node, metadata: Dictionary, state: GLTFState = null) -> void:
	var began := Time.get_ticks_usec()
	_index(room)
	if state != null:
		_import_faces(state)
	for row in metadata.get("entities", []):
		var id := int(row["id"])
		entities[id] = row
		parts[id] = []
		entity_nodes[id] = []
	for row in metadata.get("meshes", []):
		var mesh: MeshInstance3D = meshes_by_name.get(str(row["name"]))
		if mesh == null:
			stats.missing_bindings += 1
			push_error("Transferred mesh binding is missing: " + str(row["name"]))
			continue
		var id := -1 if row.get("objectId") == null else int(row["objectId"])
		if entities.has(id):
			entity_nodes[id].append(mesh)
		if row.get("particle", false):
			_fix_particle(mesh, row)
			continue
		mesh.set_meta("entity_id", id)
		if entities.has(id):
			parts[id].append(mesh)
			var box := mesh.global_transform * mesh.get_aabb()
			bounds[id] = bounds[id].merge(box) if bounds.has(id) else box
			stats.bound_meshes += 1
		_collision(mesh, id)
	for row in metadata.get("lights", []):
		var id := -1 if row.get("objectId") == null else int(row.objectId)
		var light := room.find_child(str(row.name), true, false)
		if entities.has(id) and light is Light3D:
			entity_nodes[id].append(light)
	stats.entities = entities.size()
	stats.preparation_ms = (Time.get_ticks_usec() - began) / 1000.0
	cpu_faces.clear()

func forget_entity(id: int) -> void:
	for mesh in entity_nodes.get(id, []):
		if mesh is MeshInstance3D:
			meshes_by_name.erase(str(mesh.name))
			original_overlays.erase(mesh)
	for collection in [entities, parts, entity_nodes, bounds, marked, overlays]:
		collection.erase(id)
	_refresh_active_counts()

func adopt_entities(source, ids: Array) -> void:
	for id in ids:
		entities[id] = source.entities[id]
		parts[id] = source.parts[id]
		entity_nodes[id] = source.entity_nodes[id]
		if source.bounds.has(id):
			bounds[id] = source.bounds[id]
		for mesh in entity_nodes[id]:
			if mesh is MeshInstance3D:
				meshes_by_name[str(mesh.name)] = mesh
	_refresh_active_counts()

func _refresh_active_counts() -> void:
	stats.entities = entities.size()
	stats.bound_meshes = 0
	stats.colliders = 0
	for id in parts:
		stats.bound_meshes += parts[id].size()
		for mesh in parts[id]:
			if is_instance_valid(mesh.get_meta("collision_body", null)):
				stats.colliders += 1
	for child in get_children():
		if child is StaticBody3D and int(child.get_meta("entity_id", -1)) == -1:
			stats.colliders += 1

func _import_faces(state: GLTFState) -> void:
	# Importer arrays are still CPU-resident. Reading thousands of uploaded
	# ArrayMeshes back from the renderer made full-room picking setup stall.
	var cached: Dictionary = {}
	var source_meshes := state.get_meshes()
	for node in state.json.get("nodes", []):
		if not node.has("mesh"):
			continue
		var index := int(node.mesh)
		if not cached.has(index):
			var imported: ImporterMesh = source_meshes[index].mesh
			var faces := PackedVector3Array()
			for surface in imported.get_surface_count():
				if imported.get_surface_primitive_type(surface) != Mesh.PRIMITIVE_TRIANGLES:
					continue
				var arrays := imported.get_surface_arrays(surface)
				var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var indices = arrays[Mesh.ARRAY_INDEX]
				if indices == null or indices.is_empty():
					faces.append_array(vertices)
				else:
					for vertex in indices:
						faces.append(vertices[vertex])
			cached[index] = faces
		cpu_faces[str(node.get("name", ""))] = cached[index]
	stats.importer_geometries = cached.size()

func _index(node: Node) -> void:
	if node is MeshInstance3D:
		meshes_by_name[str(node.name)] = node
	for child in node.get_children():
		_index(child)

func _fix_particle(mesh: MeshInstance3D, row: Dictionary) -> void:
	for surface in mesh.mesh.get_surface_count():
		var source := mesh.get_active_material(surface)
		if not source is BaseMaterial3D:
			stats.particle_errors += 1
			push_error("Particle has an unsupported native material")
			continue
		var copy: BaseMaterial3D = source.duplicate()
		copy.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		copy.vertex_color_use_as_albedo = true
		copy.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		copy.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if row.get("blend") == "additive" else BaseMaterial3D.BLEND_MODE_MIX
		copy.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		copy.no_depth_test = not row.get("depthTest", true)
		mesh.set_surface_override_material(surface, copy)
		stats.particle_materials += 1

func _collision(mesh: MeshInstance3D, id: int) -> void:
	# Bake the imported world pose once. This preserves mirrored/nonuniform
	# source geometry without physics-node scale approximations. No mesh edits.
	var faces: PackedVector3Array
	if cpu_faces.has(str(mesh.name)):
		faces = cpu_faces[str(mesh.name)]
	else:
		faces = mesh.mesh.get_faces()
		stats.runtime_geometry_reads += 1
	if faces.is_empty():
		return
	for i in faces.size():
		faces[i] = mesh.global_transform * faces[i]
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	shape.backface_collision = true
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.set_meta("entity_id", id)
	var collider := CollisionShape3D.new()
	collider.shape = shape
	body.add_child(collider)
	add_child(body)
	mesh.set_meta("collision_body", body)
	stats.colliders += 1

func eligible_ids() -> Array:
	return entities.keys().filter(func(id): return entities[id].get("eligible", false) and bounds.has(id))

func label_position(id: int) -> Vector3:
	var box: AABB = bounds.get(id, AABB())
	return Vector3(box.get_center().x, box.end.y + 0.25, box.get_center().z)

func mark(ids: Array) -> void:
	var desired: Dictionary = {}
	for id in ids:
		if entities.has(id) and entities[id].get("eligible", false):
			desired[id] = true
	for id in marked:
		if not desired.has(id):
			for mesh in parts.get(id, []):
				mesh.material_overlay = original_overlays.get(mesh)
	for id in desired:
		if marked.has(id):
			continue
		if not overlays.has(id):
			var material := StandardMaterial3D.new()
			material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			material.albedo_color = Color.from_string(str(entities[id].get("color", "#00ffff")), Color.CYAN)
			material.albedo_color.a = 0.28
			material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
			overlays[id] = material
		for mesh in parts.get(id, []):
			if not original_overlays.has(mesh):
				original_overlays[mesh] = mesh.material_overlay
			mesh.material_overlay = overlays[id]
	marked = desired

func pick(camera: Camera3D, screen: Vector2) -> Dictionary:
	var origin := camera.project_ray_origin(screen)
	var query := PhysicsRayQueryParameters3D.create(origin, origin + camera.project_ray_normal(screen) * camera.far, 1)
	query.hit_back_faces = true
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return {}
	var id := int(hit.collider.get_meta("entity_id", -1))
	return {"id": id, "position": hit.position, "entity": entities.get(id, {})}
