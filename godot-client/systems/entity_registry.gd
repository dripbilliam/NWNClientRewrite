extends Node3D
const NativeSurface=preload("res://systems/native_data/tile_surface.gd")
const NameplateAnchor=preload("res://systems/native_data/nameplate_anchor.gd")
const WALK_LAYER:=1
const TARGET_LAYER:=2

var entities: Dictionary = {}
var parts: Dictionary = {}
var entity_nodes: Dictionary = {}
var bounds: Dictionary = {}
var meshes_by_name: Dictionary = {}
var marked: Dictionary = {}
var legacy_marked: Dictionary={}
var whole_character_highlight_enabled:=OS.get_cmdline_user_args().has("--highlight=whole-character")
var native_highlight_enabled:=whole_character_highlight_enabled or OS.get_cmdline_user_args().has("--highlight=native-bounds")
var native_highlight
var highlight_camera: Camera3D
func configure_highlights(view: Camera3D) -> void:
	highlight_camera=view
	if native_highlight_enabled:_ensure_native_highlight()
func configure_highlight_assets(assets: Node,catalog,pool: RefCounted) -> void:
	if not native_highlight_enabled:return
	_ensure_native_highlight();native_highlight.configure_assets(assets,catalog,pool)
func _ensure_native_highlight() -> void:
	if native_highlight!=null:return
	native_highlight=(preload("res://tools/native_parity/highlighting/whole_character_selection.gd").new() if whole_character_highlight_enabled else preload("res://systems/native_render/selection_highlight.gd").new());add_child(native_highlight)
	if is_instance_valid(highlight_camera):native_highlight.configure(highlight_camera)
func _register_highlight(id: int,row: Dictionary,instance) -> void:
	if not native_highlight_enabled:return
	_ensure_native_highlight();native_highlight.register_entity(id,row,instance)
var overlays: Dictionary = {}
var original_overlays: Dictionary = {}
var cpu_faces: Dictionary = {}
var native_owners: Dictionary = {}
var native_bounds: Dictionary = {}
var native_bodies: Dictionary={}
var stats := {"entities": 0, "bound_meshes": 0, "particle_materials": 0, "colliders": 0, "target_colliders":0,"walkmesh_colliders":0,"native_shape_builds":0,"native_shape_hits":0,"missing_bindings": 0, "particle_errors": 0, "importer_geometries": 0, "runtime_geometry_reads": 0, "preparation_ms": 0.0}

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

func forget_entity(id: int) -> bool:
	if native_highlight!=null:native_highlight.forget(id)
	if not entities.has(id): return false
	var was_native:=native_owners.has(id)
	if was_native:
		stats.bound_meshes-=parts.get(id,[]).size()
		stats.colliders-=native_bodies.get(id,[]).size()
		stats.target_colliders-=native_bodies.get(id,[]).size()
		for body in native_bodies.get(id,[]):
			if is_instance_valid(body): body.collision_layer=0; body.collision_mask=0; body.queue_free()
	for mesh in entity_nodes.get(id, []):
		if mesh is MeshInstance3D:
			if original_overlays.has(mesh): mesh.material_overlay=original_overlays[mesh]
			if was_native: mesh.remove_meta("collision_body")
			meshes_by_name.erase(str(mesh.get_meta("native_registry_key",mesh.name)))
			original_overlays.erase(mesh)
	for collection in [entities, parts, entity_nodes, bounds, marked, legacy_marked, overlays]:
		collection.erase(id)
	native_owners.erase(id); native_bounds.erase(id); native_bodies.erase(id)
	if was_native: stats.entities=entities.size()
	else: _refresh_active_counts()
	return true

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

func _collision(mesh: MeshInstance3D, id: int,layer: int=WALK_LAYER) -> void:
	if mesh.has_meta("native_pick_shape"):
		# Native source arrays already produced this shared shape before GPU
		# upload. A local body follows its physical part without mesh readback.
		var shape: Shape3D=mesh.get_meta("native_pick_shape")
		var body:=StaticBody3D.new(); body.collision_layer=layer; body.collision_mask=0; body.set_meta("entity_id",id)
		var collider:=CollisionShape3D.new(); collider.shape=shape; body.add_child(collider)
		var anchor: Node3D=mesh.get_meta("native_pick_anchor",mesh); anchor.add_child(body); mesh.set_meta("collision_body",body); stats.colliders+=1
		return
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
	body.collision_layer = layer
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
	if native_owners.has(id) and is_instance_valid(native_owners[id]): bounds[id]=native_owners[id].global_transform*native_bounds[id]
	var box: AABB = bounds.get(id, AABB())
	return Vector3(box.get_center().x, box.end.y + 0.25, box.get_center().z)

func nameplate_position(id: int,camera_position: Vector3) -> Vector3:
	var owner: Node3D=native_owners.get(id)
	if int(entities.get(id,{}).get("type",-1))==5 and is_instance_valid(owner) and owner.has_meta("native_nameplate_height"):
		return NameplateAnchor.lift(owner.to_global(Vector3(0,float(owner.get_meta("native_nameplate_height")),0)),camera_position)
	return label_position(id)

func register_native(id: int,row: Dictionary,instance) -> bool:
	# Master replication/render state stays in live_world. This native registry
	# owns only current selection targets; scenery gets no per-mesh bodies/maps.
	if id<0 or not row.get("eligible",false): return forget_entity(id) if id>=0 else false
	if native_owners.get(id)==instance:
		var changed: bool=entities[id]!=row; entities[id]=row
		if changed:_register_highlight(id,row,instance)
		return changed
	forget_entity(id); entities[id]=row; parts[id]=[]; entity_nodes[id]=[]; native_owners[id]=instance; native_bodies[id]=[]
	var local_box:=AABB(); var has_box:=false
	var surfaces: Array=instance.meshes.duplicate(); var hidden: Variant=instance.get("pick_surfaces")
	if hidden is Array: surfaces.append_array(hidden)
	for surface in surfaces:
		var mesh:=surface as MeshInstance3D
		if mesh!=null and not mesh.visible: continue
		var geometry: Resource=surface.get_meta("native_pick_geometry") if surface.has_meta("native_pick_geometry") else null
		var shape: Shape3D=surface.get_meta("native_pick_shape") if surface.has_meta("native_pick_shape") else null
		var local_bounds:=AABB()
		if geometry!=null:
			var before: int=geometry.builds
			shape=geometry.get_shape(); local_bounds=geometry.bounds
			if shape!=null:
				if int(geometry.builds)>before: stats.native_shape_builds+=1
				else: stats.native_shape_hits+=1
			else: stats.missing_bindings+=1; push_warning(geometry.failure)
		elif mesh!=null: local_bounds=mesh.get_aabb()
		if shape==null: continue
		var anchor: Node3D=surface.get_meta("native_pick_anchor",surface)
		var body:=StaticBody3D.new(); body.collision_layer=TARGET_LAYER; body.collision_mask=0; body.set_meta("entity_id",id)
		var collider:=CollisionShape3D.new(); collider.shape=shape; body.add_child(collider); anchor.add_child(body); native_bodies[id].append(body); stats.colliders+=1; stats.target_colliders+=1
		if mesh!=null:
			mesh.set_meta("entity_id",id); mesh.set_meta("collision_body",body)
			var key:="native_"+str(id)+"_"+str(mesh.get_instance_id()); mesh.set_meta("native_registry_key",key)
			parts[id].append(mesh); entity_nodes[id].append(mesh); meshes_by_name[key]=mesh; stats.bound_meshes+=1
		var box: AABB=instance.global_transform.affine_inverse()*anchor.global_transform*surface.get_meta("native_pick_bounds",local_bounds)
		local_box=local_box.merge(box) if has_box else box; has_box=true
	if id>=0 and has_box: native_bounds[id]=local_box; bounds[id]=instance.global_transform*local_box
	stats.entities=entities.size()
	_register_highlight(id,row,instance)
	return true

func register_walkmesh(surface) -> void:
	# Floor selection uses original walkable WOK faces, never roof/wall render
	# triangles. Shared CPU source shapes require no GPU geometry readback.
	var shapes: Dictionary={}
	for tile in surface.definition.tiles:
		var model:=str(tile.model)
		if not shapes.has(model):
			var mesh: Dictionary=surface.meshes[model]; var faces:=PackedVector3Array()
			for index in mesh.faces.size():
				if not NativeSurface.walkable(surface.table,int(mesh.materials[index])): continue
				for vertex in mesh.faces[index]:
					var point: Array=mesh.vertices[vertex]; faces.append(Vector3(point[0]-5,point[2],5-point[1]))
			if faces.is_empty(): shapes[model]=null
			else:
				var shape:=ConcavePolygonShape3D.new(); shape.set_faces(faces); shape.backface_collision=true; shapes[model]=shape
		if shapes[model]==null: continue
		var body:=StaticBody3D.new(); body.collision_layer=WALK_LAYER; body.collision_mask=0; body.set_meta("entity_id",-1)
		var collider:=CollisionShape3D.new(); collider.shape=shapes[model]; body.add_child(collider); add_child(body)
		body.position=tile.position; body.rotation.y=float(tile.get("rotation_y",int(tile.orientation)*PI/2)); stats.colliders+=1; stats.walkmesh_colliders+=1

func mark(ids: Array,hovered: int=-1,tab_active: bool=true) -> void:
	if not native_highlight_enabled:
		_mark_mesh_overlays(ids);marked=legacy_marked;return
	_ensure_native_highlight()
	native_highlight.mark(ids,hovered,tab_active)
	# Model-less trigger surfaces retain their separate region-presentation
	# path. Native actor/door failures never fall back to coincident mesh replay.
	var legacy: Array=[];var desired: Dictionary={}
	for id in ids:
		if not entities.has(id) or not entities[id].get("eligible",false):continue
		desired[id]=true
		if not native_owners.has(id) or int(entities[id].get("type",-1))==7:legacy.append(id)
	_mark_mesh_overlays(legacy);marked=desired
func _mark_mesh_overlays(ids: Array) -> void:
	var desired: Dictionary = {}
	for id in ids:
		if entities.has(id) and entities[id].get("eligible", false):
			desired[id] = true
	for id in legacy_marked:
		if not desired.has(id):
			for mesh in parts.get(id, []):
				mesh.material_overlay = original_overlays.get(mesh)
	for id in desired:
		if legacy_marked.has(id):
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
	legacy_marked = desired
func highlight_snapshot() -> Dictionary:
	return native_highlight.snapshot() if native_highlight!=null else {"enabled":false,"legacy":true}

func pick(camera: Camera3D, screen: Vector2) -> Dictionary:
	var origin := camera.project_ray_origin(screen)
	var query := PhysicsRayQueryParameters3D.create(origin, origin + camera.project_ray_normal(screen) * camera.far, TARGET_LAYER)
	query.hit_back_faces = true
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		query.collision_mask=WALK_LAYER; hit=get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return {}
	var id := int(hit.collider.get_meta("entity_id", -1))
	return {"id": id, "position": hit.position, "entity": entities.get(id, {})}
