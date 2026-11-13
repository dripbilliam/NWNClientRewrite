extends RefCounted
# Explicit, one-shot, read-only post-measurement diagnostic. Never install this
# in a frame callback. Returned values contain no live Object/Resource handles.
const STATE_PROPERTIES := ["layers", "sorting_offset", "sorting_use_aabb_center", "transparency", "cast_shadow", "extra_cull_margin", "custom_aabb", "lod_bias", "ignore_occlusion_culling", "gi_mode", "gi_lightmap_texel_scale", "visibility_range_begin", "visibility_range_begin_margin", "visibility_range_end", "visibility_range_end_margin", "visibility_range_fade_mode"]

static func capture(world: Node, include_process_tree: bool = true) -> Dictionary:
	var began := Time.get_ticks_usec()
	var result := {"version":1, "read_only":true, "measured_after_performance_window":true, "policy":"diagnostic candidates only; no hiding, merging, culling or mutation", "errors":[], "tiles":0, "tile_mesh_leaves":0, "surface_entries":0, "candidate_leaves":0, "candidate_surface_entries":0, "reasons":{}, "materials":{}, "tuple_groups":[], "spatial_4x4_groups":[], "candidate_rows":[]}
	if not is_instance_valid(world):
		result.errors.append("world missing"); return result
	var terrain: Variant = world.get("terrain")
	if not is_instance_valid(terrain):
		result.errors.append("normal area_stream terrain missing"); return result
	var placements: Variant = terrain.get("instances")
	if not placements is Dictionary:
		result.errors.append("normal tile placement dictionary missing"); return result
	var global_groups := {}; var spatial_groups := {}
	for index in placements:
		var placement: Variant = placements[index]
		if not placement is Node3D or not is_instance_valid(placement):
			_increment(result.reasons,"tile_not_node"); continue
		result.tiles += 1
		var tile_origin: Vector3 = placement.global_position
		var cell := [floori(tile_origin.x / 40.0), floori(tile_origin.z / 40.0)]
		var leaves: Variant = placement.get("meshes")
		if not leaves is Array:
			_increment(result.reasons,"tile_mesh_array_missing"); continue
		for value in leaves:
			if not value is MeshInstance3D or not is_instance_valid(value):
				_increment(result.reasons,"non_mesh_entry"); continue
			var leaf: MeshInstance3D = value
			result.tile_mesh_leaves += 1
			var mesh: Mesh = leaf.mesh
			if mesh == null:
				_increment(result.reasons,"missing_mesh"); continue
			var surface_count := mesh.get_surface_count()
			result.surface_entries += surface_count
			var reasons: Array[String] = []
			if not placement.is_ancestor_of(leaf): reasons.append("outside_direct_tile_owner")
			if not leaf.is_inside_tree(): reasons.append("outside_tree")
			if not leaf.is_visible_in_tree(): reasons.append("currently_hidden")
			if leaf.get_child_count() != 0: reasons.append("mesh_has_children")
			if leaf.get_script() != null: reasons.append("mesh_script")
			if leaf.skin != null: reasons.append("skin")
			if mesh.get_blend_shape_count() != 0: reasons.append("blend_shapes")
			if leaf.material_overlay != null: reasons.append("overlay")
			if leaf.transparency != 0.0: reasons.append("geometry_fade")
			if not leaf.global_transform.is_finite(): reasons.append("nonfinite_transform")
			var basis: Basis = leaf.global_basis
			var scale := basis.get_scale()
			if basis.determinant() <= 0.0 or scale.x <= 0.0 or scale.y <= 0.0 or scale.z <= 0.0: reasons.append("nonpositive_transform")
			if not basis.is_conformal(): reasons.append("nonconformal_transform")
			var material_ids: Array = []; var material_modes: Array = []
			for surface in surface_count:
				var material: Material = leaf.get_active_material(surface)
				var mode := _material_mode(material)
				material_ids.append(material.get_instance_id() if material != null else 0)
				material_modes.append(mode)
				_increment(result.materials, mode)
				if mode not in ["opaque", "scissor"]: reasons.append("material_" + mode)
			var state: Array = []
			for property in STATE_PROPERTIES: state.append(leaf.get(property))
			var instance_uniforms: Array = []
			# GeometryInstance exposes the dynamic uniform list through Object's
			# property API, not a get_instance_shader_parameter_list method.
			for property in leaf.get_property_list():
				var property_name := str(property.name)
				if property_name.begins_with("instance_shader_parameters/"):
					instance_uniforms.append([property_name, leaf.get(property_name)])
			if not instance_uniforms.is_empty(): reasons.append("instance_uniforms_require_mapping")
			var tuple_data := [mesh.get_instance_id(), material_ids, state, instance_uniforms, basis.determinant() < 0.0]
			var tuple_key := _digest(tuple_data)
			var candidate := reasons.is_empty()
			for reason in reasons: _increment(result.reasons, reason)
			var row := {"tile":int(index), "tile_model":str(placement.get_meta("native_model_name", "")), "leaf_id":leaf.get_instance_id(), "mesh_id":mesh.get_instance_id(), "material_ids":material_ids, "material_modes":material_modes, "surface_count":surface_count, "tuple":tuple_key, "cell_4x4":cell, "candidate":candidate, "reasons":reasons, "shadow":int(leaf.cast_shadow), "visible":leaf.is_visible_in_tree(), "world_position":[leaf.global_position.x,leaf.global_position.y,leaf.global_position.z]}
			result.candidate_rows.append(row)
			if not candidate: continue
			result.candidate_leaves += 1; result.candidate_surface_entries += surface_count
			_add_group(global_groups, tuple_key, row)
			_add_group(spatial_groups, str(cell)+":"+tuple_key, row)
	result.tuple_groups = global_groups.values()
	result.spatial_4x4_groups = spatial_groups.values()
	result.tuple_groups.sort_custom(_group_larger)
	result.spatial_4x4_groups.sort_custom(_group_larger)
	result.exact_tuple_summary = _group_summary(result.tuple_groups)
	result.spatial_4x4_summary = _group_summary(result.spatial_4x4_groups)
	result.auto_instancing_note = "Forward+ already repeats identical adjacent sort keys. Group counts are not saved draw calls. A MultiMesh changes cull granularity and must be tested."
	if include_process_tree: result.process_tree = _process_tree(world)
	result.elapsed_ms = (Time.get_ticks_usec()-began)/1000.0
	return result

static func save(world: Node, path: String, include_process_tree: bool = true) -> Dictionary:
	var result := capture(world, include_process_tree)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null: result.errors.append("cannot write census: "+str(FileAccess.get_open_error()))
	else: file.store_string(JSON.stringify(result,"\t")); file.close()
	return result

static func _material_mode(material: Material) -> String:
	if material == null: return "missing"
	if material.next_pass != null: return "next_pass"
	var script: Script = material.get_script()
	var known_native := script != null and script.resource_path == "res://systems/native_render/native_model_material.gd"
	if material is BaseMaterial3D or known_native:
		var transparency := int(material.get("transparency"))
		if transparency == BaseMaterial3D.TRANSPARENCY_DISABLED: return "opaque"
		if transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR: return "scissor"
		return "blended_or_other"
	return "unreviewed_shader"

static func _add_group(groups: Dictionary, key: String, row: Dictionary) -> void:
	if not groups.has(key): groups[key] = {"tuple":row.tuple, "cell_4x4":row.cell_4x4, "leaves":0, "surface_entries":0, "tiles":[], "mesh_id":row.mesh_id, "material_ids":row.material_ids}
	var group: Dictionary = groups[key]
	group.leaves += 1; group.surface_entries += row.surface_count
	if not group.tiles.has(row.tile): group.tiles.append(row.tile)

static func _group_summary(groups: Array) -> Dictionary:
	var summary := {"groups":groups.size(), "repeat_groups":0, "repeat_leaves":0, "surface_entries":0, "instance_slots_removed_if_one_node_per_group":0}
	for group in groups:
		summary.surface_entries += int(group.surface_entries)
		if int(group.leaves) > 1:
			summary.repeat_groups += 1; summary.repeat_leaves += int(group.leaves)
			summary.instance_slots_removed_if_one_node_per_group += int(group.leaves)-1
	return summary

static func _group_larger(a: Dictionary, b: Dictionary) -> bool:
	return int(a.leaves) > int(b.leaves) if a.leaves != b.leaves else str(a.tuple) < str(b.tuple)

static func _process_tree(root: Node) -> Dictionary:
	var result := {"nodes":0, "processing":0, "physics_processing":0, "internal_processing":0, "internal_physics_processing":0, "scripts":{}, "rig_owners":[]}
	var pending: Array[Node] = [root]
	while not pending.is_empty():
		var node: Node = pending.pop_back(); result.nodes += 1
		for child in node.get_children(): pending.append(child)
		var processing := node.is_processing(); var physics := node.is_physics_processing()
		var internal := node.is_processing_internal(); var internal_physics := node.is_physics_processing_internal()
		if processing: result.processing += 1
		if physics: result.physics_processing += 1
		if internal: result.internal_processing += 1
		if internal_physics: result.internal_physics_processing += 1
		var script: Script = node.get_script()
		if script == null: continue
		var path := str(script.resource_path)
		if not result.scripts.has(path): result.scripts[path] = {"nodes":0,"processing":0,"physics_processing":0,"internal_processing":0,"internal_physics_processing":0}
		var bucket: Dictionary = result.scripts[path]; bucket.nodes += 1
		if processing: bucket.processing += 1
		if physics: bucket.physics_processing += 1
		if internal: bucket.internal_processing += 1
		if internal_physics: bucket.internal_physics_processing += 1
		if path in ["res://systems/model_rigs.gd", "res://systems/native_render/skeletal_rigs.gd"]:
			var rig := {"node_id":node.get_instance_id(),"processing":processing,"entities":0,"models":0,"animated_models":0,"native_owners":0,"playing_players":0,"manual_poses":0,"attachments":0,"skins":0}
			var entities: Dictionary = node.get("entities")
			rig.entities = entities.size()
			for entry in entities.values():
				rig.models += entry.models.size(); rig.animated_models += entry.get("animated_models",[]).size()
				rig.manual_poses += entry.get("manual_poses",{}).size(); rig.attachments += entry.get("attachments",[]).size(); rig.skins += entry.get("skins",[]).size()
				for model in entry.models:
					if model.has("native_owner"): rig.native_owners += 1
					if model.get("player") != null and model.player.is_playing(): rig.playing_players += 1
			result.rig_owners.append(rig)
	return result

static func _increment(counts: Dictionary, key: String) -> void:
	counts[key] = int(counts.get(key,0))+1

static func _digest(value: Variant) -> String:
	var hashing := HashingContext.new(); hashing.start(HashingContext.HASH_SHA256)
	hashing.update(var_to_bytes(value)); return hashing.finish().hex_encode()
