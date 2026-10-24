extends Node3D

const Surface = preload("res://systems/particle_surface.gd")
var client
var rigs
var rows: Dictionary = {}
var surfaces: Dictionary = {}
var epoch := -1
var sequence := 0
var waiting := -1
var elapsed := 0.0
var worker_ready := false
var start_requested := false
var diagnostic_hidden := false
var active_ids: Dictionary = {}
var visual_watches: Dictionary = {}
var stats := {"emitters": 0, "frames": 0, "visible": 0, "vertices": 0, "failures": 0, "failed_emitters": 0, "canceled": 0}

func configure(owner_client, metadata: Dictionary, registry, model_rigs) -> void:
	client = owner_client
	rigs = model_rigs
	rigs.model_event.connect(_model_event)
	epoch = int(metadata.get("particles", {}).get("epoch", -1))
	process_priority = 100
	adopt(metadata, registry)
	_request_start()

func _request_start() -> void:
	if rows.is_empty() or epoch < 0:
		return
	if start_requested:
		return
	start_requested = true
	var probe := Surface.new()
	probe.configure(null, epoch)
	if not probe._allocate(6):
		push_error("Unsupported native particle buffer layout")
		probe.free()
		return
	var layout: Dictionary = probe.stream_layout.duplicate()
	probe.free()
	call_deferred("_start", layout)

func _start(layout: Dictionary) -> void:
	if is_instance_valid(client) and client.particles == self and client.world_scope.admitted and epoch >= 0:
		client.command({"kind": "particles-start", "epoch": epoch, "transferId":client.world_scope.ticket, "layout": layout})

func adopt(metadata: Dictionary, registry) -> void:
	for source in metadata.get("particles", {}).get("emitters", []):
		var row: Dictionary = source.duplicate(true)
		var id := int(row.id)
		if rows.has(id):
			continue
		var template: MeshInstance3D = registry.meshes_by_name.get(str(row.textureMesh))
		if template == null:
			stats.failures += 1
			continue
		template.hide()
		var material := template.get_active_material(0) as BaseMaterial3D
		var surface := Surface.new()
		if row.has("weatherModel"): surface.layers = 2
		add_child(surface)
		var double_sided: Variant = row.properties.get("twosidedtex", false)
		surface.configure(material.albedo_texture if material != null else null, epoch, row.properties.get("blend") != "Normal", str(double_sided).to_lower() in ["true", "1"], row.get("engineLighting",false))
		surfaces[id] = surface
		rows[id] = row
		# A content addition is already admitted by the backend patch before the
		# native content packet is sent. Reference-target gaps remain explicit.
		active_ids[id] = true
	stats.emitters = rows.size()
	if is_instance_valid(client) and client.world_scope.admitted:
		_request_start()

func forget_entity(object_id: int) -> void:
	for id in rows.keys():
		if rows[id].get("objectId") != null and int(rows[id].objectId) == object_id:
			surfaces[id].retire()
			surfaces[id].queue_free()
			surfaces.erase(id)
			rows.erase(id)
			active_ids.erase(id)
	stats.emitters = rows.size()

func receive(message: Dictionary) -> void:
	if int(message.get("epoch", -1)) != epoch:
		return
	match message.get("kind"):
		"particles-ready":
			active_ids.clear()
			for id in message.ids:
				if rows.has(int(id)):
					active_ids[int(id)] = true
			worker_ready = true
		"particle-stream":
			if int(message.sequence) != waiting:
				return
			for stream in message.streams:
				var row: Dictionary = stream.row
				var id := int(row.id)
				if not surfaces.has(id):
					continue
				var bounds := AABB()
				if int(row.count) > 0:
					if not row.get("bounds") is Dictionary or not row.bounds.get("min") is Array or not row.bounds.get("max") is Array or row.bounds.min.size() != 3 or row.bounds.max.size() != 3:
						stats.failures += 1
						continue
					bounds = AABB(_vec(row.bounds.min), _vec(row.bounds.max) - _vec(row.bounds.min))
				if not surfaces[id].apply_frame(epoch, waiting, int(row.count), int(row.capacity), stream.positions, stream.attributes, bounds):
					stats.failures += 1
		"particle-complete":
			if int(message.sequence) != waiting:
				return
			waiting = -1
			if message.get("canceled", false):
				stats.canceled += 1
				return
			stats.frames += 1
			stats.failed_emitters = int(message.get("failed", 0))
			stats.vertices = int(message.get("vertices", 0))
			stats.visible = surfaces.values().filter(func(surface): return surface.visible).size()
			if message.has("error"):
				worker_ready = false
				stats.failures += 1

func _model_event(object_id: int, model_index: int, event: String, _serial: int) -> void:
	if event.to_lower() != "detonate":
		return
	for row in rows.values():
		var binding: Variant = row.get("nativeParent")
		if binding is Dictionary and not binding.has("visualModel") and not binding.has("weatherModel") and int(binding.objectId) == object_id and int(binding.modelIndex) == model_index and row.properties.get("update") == "Explosion":
			row["detonate"] = true

func _process(delta: float) -> void:
	for id in rows:
		var object_id: int = -1 if rows[id].objectId == null else int(rows[id].objectId)
		var owner_visible: bool = not is_instance_valid(client) or not client.pivots.has(object_id) or client.pivots[object_id].visible
		if rows[id].has("visualModel"):
			var model = client.effects.model_for(int(rows[id].visualModel)) if is_instance_valid(client.effects) else null
			owner_visible = model != null and model.is_visible_in_tree()
		elif rows[id].has("weatherModel"):
			var model = _private_model({"weatherModel":rows[id].weatherModel})
			owner_visible = model != null and model.is_visible_in_tree()
		surfaces[id].visible = worker_ready and surfaces[id].vertex_count > 0 and owner_visible and not diagnostic_hidden
	if not worker_ready or not is_instance_valid(client) or client.generation < 0:
		return
	for row in rows.values():
		if row.get("nativeParent") != null or not row.get("clock", {}).get("playing", false):
			continue
		var clock: Dictionary = row.clock
		var length: float = float(row.get("clips", {}).get(str(clock.clip), {}).get("length", 0.0))
		var time: float = PackedFloat32Array([float(clock.time) + float(clock.speed) * delta])[0]
		if time > length and clock.speed >= 0:
			time = minf(time - length, length) if clock.loop else length
		elif time < 0 and clock.speed <= 0:
			time = maxf(time + length, 0.0) if clock.loop else 0.0
		if row.properties.get("update") == "Explosion":
			var events: Array = row.get("clips", {}).get(str(clock.clip), {}).get("events", [])
			if rigs.model_events(events, float(clock.time), time, 1 if clock.speed < 0 else 0).any(func(event): return str(event).to_lower() == "detonate"):
				row["detonate"] = true
		clock.time = time
	elapsed += delta
	if waiting >= 0 or elapsed < 1.0 / 60.0 or active_ids.is_empty():
		return
	var poses: Array = []
	for id in active_ids:
		if not rows.has(id):
			continue
		var row: Dictionary = rows[id]
		var pose := {"id": id, "matrix": _pose(row.get("nativeParent"), row.matrix), "rootMatrix": _pose(row.get("nativeRoot"), row.rootMatrix)}
		if row.get("referenceTarget") is Dictionary:
			pose["referenceMatrix"] = _reference_pose(row.referenceTarget)
		if row.get("detonate", false):
			pose["detonate"] = true
			row["detonate"] = false
		var binding: Variant = row.get("nativeParent")
		var animated: Dictionary = _bound_model(binding)
		if not animated.is_empty():
			var player: AnimationPlayer = animated.player
			if animated.has("native_owner"):
				pose["properties"] = animated.native_owner.pose.emitter_properties(int(binding.rigNode))
			elif player != null and not str(animated.clip).is_empty():
				pose["animation"] = {"clip": animated.clip, "time": player.current_animation_position if player.is_playing() and not player.current_animation.is_empty() else float(animated.get("last_time", 0.0))}
		elif row.get("clock", {}).get("clip", "") != "":
			pose["animation"] = {"clip": row.clock.clip, "time": row.clock.time}
		poses.append(pose)
	waiting = sequence
	sequence += 1
	client.command({"kind": "particle-frame", "epoch": epoch, "transferId":client.world_scope.ticket, "sequence": waiting, "delta": minf(elapsed, 10.0), "camera": _matrix(client.owner_scene.camera.global_transform), "poses": poses})
	elapsed = 0.0

func _pose(binding: Variant, fallback: Array) -> Array:
	var node = _bound_node(binding)
	if node != null:
		return _matrix(node.global_transform)
	return fallback

func _valid_owner(binding: Dictionary) -> bool:
	if binding.has("weatherModel"): return _private_model(binding) != null
	if binding.has("visualModel"):
		return is_instance_valid(client.effects) and client.effects.model_for(int(binding.visualModel)) != null
	var id := int(binding.get("objectId", -1))
	if binding.has("revision") and int(client.content_revisions.get(id, -1)) != int(binding.revision):
		return false
	return not client.removed_states.get(id, false)

func _bound_node(binding: Variant):
	if binding is Dictionary and (binding.has("visualModel") or binding.has("weatherModel")):
		var model = _private_model(binding)
		if model != null:
			var nodes: Array = model.rigs.entities[0].nodes
			var index := int(binding.rigNode)
			if index >= 0 and index < nodes.size(): return nodes[index]
		return null
	if binding is Dictionary and _valid_owner(binding) and rigs.entities.has(int(binding.objectId)):
		var nodes: Array = rigs.entities[int(binding.objectId)].nodes
		if int(binding.rigNode) >= 0 and int(binding.rigNode) < nodes.size():
			return nodes[int(binding.rigNode)]
	return null

func _bound_model(binding: Variant) -> Dictionary:
	if not binding is Dictionary: return {}
	var source = rigs
	var id := int(binding.objectId)
	if binding.has("visualModel") or binding.has("weatherModel"):
		var model = _private_model(binding)
		if model == null: return {}
		source = model.rigs
		id = 0
	if not source.entities.has(id): return {}
	var index := int(binding.modelIndex)
	return source.entities[id].models[index] if index >= 0 and index < source.entities[id].models.size() else {}

func _private_model(binding: Dictionary):
	if binding.has("visualModel"): return client.effects.model_for(int(binding.visualModel)) if is_instance_valid(client.effects) else null
	if binding.has("weatherModel") and is_instance_valid(client.owner_scene.environment_owner) and is_instance_valid(client.owner_scene.environment_owner.weather_world): return client.owner_scene.environment_owner.weather_world.model_for(int(binding.weatherModel))
	return null

func watch_visual_model(id: int, source) -> void:
	if visual_watches.has(id): return
	var callback := func(_object, model_index, name, _serial):
		if str(name).to_lower() != "detonate": return
		for row in rows.values():
			var binding: Variant = row.get("nativeParent")
			if binding is Dictionary and int(binding.get("visualModel", -1)) == id and int(binding.modelIndex) == model_index and row.properties.get("update") == "Explosion": row["detonate"] = true
	source.model_event.connect(callback)
	visual_watches[id] = {"source": source, "callback": callback}

func unwatch_visual_model(id: int, source) -> void:
	if not visual_watches.has(id): return
	var callback: Callable = visual_watches[id].callback
	if is_instance_valid(source) and source.model_event.is_connected(callback): source.model_event.disconnect(callback)
	visual_watches.erase(id)

func _reference_pose(endpoint: Dictionary) -> Variant:
	if endpoint.get("nativeRoot") is Dictionary:
		var node = _bound_node(endpoint.nativeRoot)
		return _matrix(node.global_transform) if node != null else null
	var attachment: Variant = endpoint.get("attachment")
	if attachment is Dictionary:
		var anchor: Variant = null
		if attachment.get("binding") is Dictionary:
			var node = _bound_node(attachment.binding)
			if node != null:
				anchor = node.global_transform
		elif attachment.get("fallback") is Dictionary:
			var binding: Dictionary = attachment.fallback
			if _valid_owner(binding) and client.pivots.has(int(binding.objectId)):
				anchor = client.pivots[int(binding.objectId)].global_transform * _transform(binding.matrix)
		if anchor == null:
			# An unbound static reference may still have a valid captured pose.
			# A lost/replaced canonical binding must not use that stale fallback.
			return endpoint.matrix if attachment.get("binding") == null and attachment.get("fallback") == null else null
		var original := _transform(endpoint.matrix)
		var rotation: Basis = original.basis if int(attachment.get("flags", 0)) == 3 else Basis(anchor.basis.orthonormalized().get_rotation_quaternion()).scaled(original.basis.get_scale())
		return _matrix(Transform3D(rotation, anchor.origin))
	return endpoint.matrix

func _transform(value: Array) -> Transform3D:
	return Transform3D(Basis(Vector3(value[0], value[1], value[2]), Vector3(value[4], value[5], value[6]), Vector3(value[8], value[9], value[10])), Vector3(value[12], value[13], value[14]))

func _matrix(value: Transform3D) -> Array:
	return [value.basis.x.x, value.basis.x.y, value.basis.x.z, 0, value.basis.y.x, value.basis.y.y, value.basis.y.z, 0, value.basis.z.x, value.basis.z.y, value.basis.z.z, 0, value.origin.x, value.origin.y, value.origin.z, 1]

func _vec(value: Array) -> Vector3:
	return Vector3(value[0], value[1], value[2])

func retire() -> void:
	worker_ready = false
	epoch = -1
	if is_instance_valid(rigs) and rigs.model_event.is_connected(_model_event):
		rigs.model_event.disconnect(_model_event)
	for id in visual_watches.keys(): unwatch_visual_model(id, visual_watches[id].source)
	for surface in surfaces.values():
		surface.retire()
	rows.clear()
	surfaces.clear()
	active_ids.clear()

func diagnostic_sample() -> Dictionary:
	var result := {}
	for id in surfaces:
		var surface = surfaces[id]
		if surface.vertex_count <= 0 or surface.mesh == null:
			continue
		var vertices: PackedVector3Array = surface.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var sample: Array = []
		for index in mini(surface.vertex_count, 12):
			sample.append([vertices[index].x, vertices[index].y, vertices[index].z])
		result[str(id)] = sample
		if result.size() >= 4:
			break
	return result
