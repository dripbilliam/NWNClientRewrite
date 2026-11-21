extends Node3D
const NativeSurface=preload("res://systems/native_data/tile_surface.gd")
const NameplateAnchor=preload("res://systems/native_data/nameplate_anchor.gd")
const WorldHighlight=preload("res://systems/native_data/world_highlight.gd")
const GpuSkinPickShapes=preload("res://systems/native_render/gpu_skin_pick_shapes.gd")
const WALK_LAYER:=1
const TARGET_LAYER:=2
const SCENERY_LAYER:=4

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
var world_highlight_renderer
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
func _ensure_world_highlight_renderer() -> void:
	if world_highlight_renderer!=null:return
	world_highlight_renderer=preload("res://systems/native_render/world_highlight_renderer.gd").new()
	add_child(world_highlight_renderer)
func _register_highlight(id: int,row: Dictionary,instance) -> void:
	if not native_highlight_enabled:return
	_ensure_native_highlight();native_highlight.register_entity(id,row,instance)
var overlays: Dictionary = {}
var original_overlays: Dictionary = {}
var cpu_faces: Dictionary = {}
var native_owners: Dictionary = {}
var native_bounds: Dictionary = {}
var native_bodies: Dictionary={}
var native_surfaces: Dictionary={}
var scenery_bodies: Dictionary={}
var scenery_shapes: Dictionary={}
var scenery_owners: Dictionary={}
var scenery_body_count:=0
var _pick_frame_active:=false
var _pick_frame_key: Array=[]
var _pick_frame_target_hit: Dictionary={}
var _pick_frame_scenery_hit: Dictionary={}
var gpu_skin_pick=GpuSkinPickShapes.new() if ("--gpu-skin-pick=on-demand" in OS.get_cmdline_user_args() or "--cpu-skin-pick=on-demand" in OS.get_cmdline_user_args()) else null
var stats := {"entities": 0, "bound_meshes": 0, "particle_materials": 0, "colliders": 0, "target_colliders":0,"walkmesh_colliders":0,"native_shape_builds":0,"native_shape_hits":0,"missing_bindings": 0, "particle_errors": 0, "importer_geometries": 0, "runtime_geometry_reads": 0, "preparation_ms": 0.0}

func begin_pick_frame() -> void:
	_pick_frame_active=true
	_pick_frame_key.clear()
	_pick_frame_target_hit.clear()
	_pick_frame_scenery_hit.clear()

func end_pick_frame() -> void:
	_pick_frame_active=false
	_pick_frame_key.clear()
	_pick_frame_target_hit.clear()
	_pick_frame_scenery_hit.clear()

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
	forget_scenery("object:"+str(id))
	if native_highlight!=null:native_highlight.forget(id)
	if not entities.has(id): return false
	var was_native:=native_owners.has(id)
	if was_native:
		stats.bound_meshes-=parts.get(id,[]).size()
		stats.colliders-=native_bodies.get(id,[]).size()
		stats.target_colliders-=native_bodies.get(id,[]).size()
		for body in native_bodies.get(id,[]):
			if not is_instance_valid(body):continue
			if gpu_skin_pick!=null:gpu_skin_pick.forget_body(body,"target")
			body.collision_layer=0;body.collision_mask=0;body.queue_free()
	for mesh in entity_nodes.get(id, []):
		if mesh is MeshInstance3D:
			if original_overlays.has(mesh): mesh.material_overlay=original_overlays[mesh]
			if was_native: mesh.remove_meta("collision_body")
			meshes_by_name.erase(str(mesh.get_meta("native_registry_key",mesh.name)))
			original_overlays.erase(mesh)
	for collection in [entities, parts, entity_nodes, bounds, marked, legacy_marked, overlays]:
		collection.erase(id)
	native_owners.erase(id); native_bounds.erase(id); native_bodies.erase(id); native_surfaces.erase(id)
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
		if mesh.has_meta("native_pick_geometry"):
			GpuSkinPickShapes.keep_cpu_refit_eager(mesh.get_meta("native_pick_geometry"))
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
func highlight_ids() -> Array:
	return entities.keys().filter(func(id): return entities[id].get("eligible",false))

func label_position(id: int) -> Vector3:
	if native_owners.has(id) and is_instance_valid(native_owners[id]):
		_refresh_native_skin_bounds(id)
		bounds[id]=native_owners[id].global_transform*native_bounds[id]
	var box: AABB = bounds.get(id, AABB())
	return Vector3(box.get_center().x, box.end.y + 0.25, box.get_center().z)

func _refresh_native_skin_bounds(id: int) -> void:
	var rows: Array=native_surfaces.get(id,[])
	var dynamic:=false
	for row in rows:
		var surface: Node3D=row.surface.get_ref()
		if is_instance_valid(surface) and surface.get_meta("native_cpu_skin",false):dynamic=true;break
	if not dynamic:return
	var instance: Node3D=native_owners.get(id)
	var box:=AABB();var has_box:=false
	for row in rows:
		var surface: Node3D=row.surface.get_ref()
		var anchor: Node3D=row.anchor.get_ref()
		if not is_instance_valid(surface) or not is_instance_valid(anchor):continue
		var geometry: Resource=surface.get_meta("native_pick_geometry",null)
		var local: AABB=surface.get_meta("native_pick_bounds",geometry.bounds if geometry!=null else AABB())
		var transformed: AABB=instance.global_transform.affine_inverse()*anchor.global_transform*local
		box=box.merge(transformed) if has_box else transformed;has_box=true
	if has_box:native_bounds[id]=box

func nameplate_position(id: int,camera_position: Vector3) -> Vector3:
	var owner: Node3D=native_owners.get(id)
	if int(entities.get(id,{}).get("type",-1))==5 and is_instance_valid(owner) and owner.has_meta("native_nameplate_height"):
		return NameplateAnchor.lift(owner.to_global(Vector3(0,float(owner.get_meta("native_nameplate_height")),0)),camera_position)
	return label_position(id)

func _placeable_usable_for_hidden_hit(row: Dictionary) -> bool:
	if int(row.get("type",-1))!=9:return false
	var source: Dictionary=row.get("source",{})
	if source.get("replicationRemoved",false):return false
	var replicated: Dictionary=source.get("replicated",{})
	# src/placeable_hit_mesh.js::placeableUsable uses nullish precedence, not
	# a union of all four fields. A received false wins over authored true.
	for value in [replicated.get("field264"),source.get("nativeUseable264"),source.get("usable"),source.get("authored",{}).get("Useable")]:
		if value!=null:return bool(value)
	return false

func _refresh_hidden_placeable_hit_bodies(id: int,row: Dictionary) -> void:
	var active:=_placeable_usable_for_hidden_hit(row)
	for body in native_bodies.get(id,[]):
		if is_instance_valid(body) and body.get_meta("native_object_hit_mesh",false):
			body.collision_layer=TARGET_LAYER if active else 0

func register_native(id: int,row: Dictionary,instance) -> bool:
	# Master replication/render state stays in live_world. This registry owns
	# current selection targets and the published visual meshes used for picking.
	if id<0 or not row.get("eligible",false): return forget_entity(id) if id>=0 else false
	if native_owners.get(id)==instance:
		var changed: bool=entities[id]!=row; entities[id]=row
		if changed:_refresh_hidden_placeable_hit_bodies(id,row)
		if changed:_register_highlight(id,row,instance)
		return changed
	forget_entity(id); entities[id]=row; parts[id]=[]; entity_nodes[id]=[]; native_owners[id]=instance; native_bodies[id]=[]; native_surfaces[id]=[]
	var local_box:=AABB(); var has_box:=false
	var surfaces: Array=instance.meshes.duplicate(); var hidden: Variant=instance.get("pick_surfaces")
	if int(row.get("type",-1))==9 and hidden is Array: surfaces.append_array(hidden)
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
		if gpu_skin_pick!=null:shape=gpu_skin_pick.shape_for(mesh,shape)
		var anchor: Node3D=surface.get_meta("native_pick_anchor",surface)
		native_surfaces[id].append({"surface":weakref(surface),"anchor":weakref(anchor)})
		var body:=StaticBody3D.new(); body.collision_layer=TARGET_LAYER; body.collision_mask=0; body.set_meta("entity_id",id)
		if surface.get_meta("native_object_hit_mesh",false):
			body.set_meta("native_object_hit_mesh",true)
			if not _placeable_usable_for_hidden_hit(row):body.collision_layer=0
		var collider:=CollisionShape3D.new(); collider.shape=shape; body.add_child(collider); anchor.add_child(body); native_bodies[id].append(body); stats.colliders+=1; stats.target_colliders+=1
		if gpu_skin_pick!=null:gpu_skin_pick.track_body(mesh,body,"target")
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

func mark(ids: Array,hovered: int=-1,tab_active: bool=true,player_id: int=-1) -> void:
	if not native_highlight_enabled:
		_ensure_world_highlight_renderer()
		var entries: Array=[]
		var desired: Dictionary={}
		for id in ids:
			if not id is int or not entities.has(id) or not entities[id].get("eligible",false):continue
			var root: Node3D=native_owners.get(id)
			var candidates: Array=[]
			if is_instance_valid(root):candidates=world_highlight_renderer.meshes(root)
			else:
				var parts_for_id: Array=parts.get(id,[])
				if not parts_for_id.is_empty() and parts_for_id[0] is Node3D:
					root=parts_for_id[0]
					candidates=parts_for_id
			if not is_instance_valid(root):continue
			var object: Dictionary=entities[id].get("source",entities[id])
			entries.append({"id":id,"root":root,"meshes":candidates,"color":WorldHighlight.color(object,player_id)})
			desired[id]=true
		world_highlight_renderer.update(entries,float(Time.get_ticks_msec()))
		marked=desired
		return
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
	if native_highlight!=null:return native_highlight.snapshot()
	if world_highlight_renderer!=null:return {"enabled":true,"parts":world_highlight_renderer.parts,"objects":world_highlight_renderer.entry_bounds.keys()}
	return {"enabled":false,"parts":0,"objects":[]}

func forget_scenery(key: String) -> void:
	scenery_body_count-=scenery_bodies.get(key,[]).size()
	for body in scenery_bodies.get(key,[]):
		if not is_instance_valid(body):continue
		if gpu_skin_pick!=null:gpu_skin_pick.forget_body(body,"scenery")
		body.collision_layer=0;body.queue_free()
	scenery_bodies.erase(key);scenery_owners.erase(key)
func register_scenery(key: String,instance: Node3D,id: int=-1) -> void:
	if is_instance_valid(instance) and is_same(scenery_owners.get(key),instance):return
	forget_scenery(key)
	if not is_instance_valid(instance) or not instance.get("meshes") is Array:return
	var bodies: Array=[]
	for source in instance.meshes:
		var mesh:=source as MeshInstance3D
		if mesh==null or mesh.mesh==null or mesh.has_meta("native_invisible_pick"):continue
		var mesh_key:=mesh.mesh.get_instance_id()
		if not scenery_shapes.has(mesh_key):
			var geometry: Variant=mesh.get_meta("native_pick_geometry",null)
			scenery_shapes[mesh_key]=geometry.get_shape() if geometry!=null and geometry.has_method("get_shape") else mesh.mesh.create_trimesh_shape()
		var shape: Shape3D=scenery_shapes[mesh_key]
		if shape==null:continue
		if gpu_skin_pick!=null:shape=gpu_skin_pick.shape_for(mesh,shape)
		var body:=StaticBody3D.new();body.collision_layer=SCENERY_LAYER;body.collision_mask=0;body.set_meta("entity_id",id);body.set_meta("scenery_mesh",mesh)
		var collider:=CollisionShape3D.new();collider.shape=shape;body.add_child(collider);mesh.add_child(body);bodies.append(body)
		if gpu_skin_pick!=null:gpu_skin_pick.track_body(mesh,body,"scenery")
	scenery_bodies[key]=bodies;scenery_owners[key]=instance;scenery_body_count+=bodies.size()
func scenery_hit_material(mesh: MeshInstance3D,face: int) -> Material:
	if mesh.material_override!=null:return mesh.material_override
	var surface:=0
	if face>=0 and mesh.mesh.get_surface_count()>1:
		var first_face:=0
		for index in mesh.mesh.get_surface_count():
			var arrays: Array=mesh.mesh.surface_get_arrays(index)
			var indices: Variant=arrays[Mesh.ARRAY_INDEX]
			var vertices: Variant=arrays[Mesh.ARRAY_VERTEX]
			var count: int=indices.size() if indices!=null and not indices.is_empty() else vertices.size()
			if face<first_face+count/3:surface=index;break
			first_face+=count/3
	return mesh.get_active_material(surface)
func scenery_material_visible(material: Material) -> bool:
	if material==null:return true
	if bool(material.get_meta("native_invisible_pick",false)):return false
	var color: Variant=material.get("albedo_color")
	if color is Color:return color.a>0.01
	if material is ShaderMaterial:
		var alpha: Variant=material.get_shader_parameter("native_alpha")
		if alpha is float:return alpha>0.01
	return true
func scenery_hit(origin: Vector3,finish: Vector3,exclude_player: bool,player_id: int,excluded: Array[RID]=[]) -> Dictionary:
	var query:=PhysicsRayQueryParameters3D.create(origin,finish,SCENERY_LAYER)
	query.hit_back_faces=true
	if exclude_player and player_id>=0:
		for body in scenery_bodies.get("object:"+str(player_id),[]):
			if is_instance_valid(body):excluded.append(body.get_rid())
	for attempt in range(scenery_body_count+1):
		query.exclude=excluded
		var hit: Dictionary=get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty():return {}
		var body: StaticBody3D=hit.collider
		var mesh: Variant=body.get_meta("scenery_mesh")
		var visible: bool=is_instance_valid(mesh) and mesh.is_visible_in_tree() and not bool(mesh.get_meta("ignoreWorldPicking",false))
		if visible:visible=scenery_material_visible(scenery_hit_material(mesh,int(hit.get("face_index",-1))))
		if visible:return {"id":int(body.get_meta("entity_id",-1)),"position":hit.position,"distance":origin.distance_to(hit.position)}
		excluded.append(body.get_rid())
	return {}
func door_region_hit(origin: Vector3,finish: Vector3,nearest_distance: float) -> Dictionary:
	var region: Dictionary={}
	for id in native_owners:
		var owner: Variant=native_owners[id]
		if int(entities.get(id,{}).get("type",-1))!=10 or not is_instance_valid(owner) or not owner.has_method("legacy_dwk_pick"):continue
		var candidate: Dictionary=owner.legacy_dwk_pick(origin,finish)
		if candidate.is_empty() or float(candidate.distance)>nearest_distance+0.08 or not region.is_empty() and float(candidate.distance)>=float(region.distance):continue
		region={"id":int(id),"position":candidate.position,"distance":candidate.distance}
	return region
func pick(camera: Camera3D, screen: Vector2, include_player: bool=false, objects_only: bool=false, player_id: int=-1) -> Dictionary:
	var origin := camera.project_ray_origin(screen)
	var finish:=origin+camera.project_ray_normal(screen)*camera.far
	var lazy_skins: bool=gpu_skin_pick!=null and not gpu_skin_pick.surfaces.is_empty()
	# GPU pose providers keep their per-ray route. CPU publications stamp
	# the original same-frame pointer cache so a changed pose is queried.
	var reuse_frame_pick: bool=_pick_frame_active and (not lazy_skins or gpu_skin_pick.gpu_surfaces==0)
	var key: Array=[camera.get_instance_id(),origin,finish,camera.near,camera.far,include_player,player_id] if reuse_frame_pick else []
	if reuse_frame_pick and lazy_skins:key.append(gpu_skin_pick.cpu_generation)
	var query := PhysicsRayQueryParameters3D.create(origin,finish,TARGET_LAYER)
	query.hit_back_faces = true
	var hit: Dictionary
	var nearest: Dictionary
	if reuse_frame_pick and _pick_frame_key==key:
		hit=_pick_frame_target_hit
		nearest=_pick_frame_scenery_hit
	else:
		var excluded: Array[RID]=[]
		var excluded_scenery: Array[RID]=[]
		if lazy_skins:
			var stale: Dictionary=gpu_skin_pick.prepare_ray(origin,finish)
			excluded=stale.target
			excluded_scenery=stale.scenery
		if not include_player and player_id>=0:
			for body in native_bodies.get(player_id,[]):
				if is_instance_valid(body):excluded.append(body.get_rid())
		if not excluded.is_empty():query.exclude=excluded
		hit=get_world_3d().direct_space_state.intersect_ray(query)
		nearest=scenery_hit(origin,finish,not include_player,player_id,excluded_scenery)
		if reuse_frame_pick:
			_pick_frame_key=key
			_pick_frame_target_hit=hit
			_pick_frame_scenery_hit=nearest
	if not hit.is_empty():
		var target_distance: float=origin.distance_to(hit.position)
		var target_id: int=int(hit.collider.get_meta("entity_id",-1))
		var trigger_seam: float=0.01 if int(entities.get(target_id,{}).get("type",-1))==7 else 0.0
		if nearest.is_empty() or target_distance<=float(nearest.distance)+trigger_seam:nearest={"id":target_id,"position":hit.position,"distance":target_distance}
	var region: Dictionary=door_region_hit(origin,finish,float(nearest.distance) if not nearest.is_empty() else INF)
	if not region.is_empty():return {"id":int(region.id),"position":region.position,"entity":entities.get(int(region.id),{})}
	if not nearest.is_empty():
		if int(nearest.id)>=0:return {"id":int(nearest.id),"position":nearest.position,"entity":entities.get(int(nearest.id),{})}
		if objects_only:return {}
		query.collision_mask=WALK_LAYER
		var ground: Dictionary=get_world_3d().direct_space_state.intersect_ray(query)
		if ground.is_empty() or float(nearest.distance)+0.05<origin.distance_to(ground.position) and absf(nearest.position.y-ground.position.y)>0.4:return {}
		return {"id":-1,"position":ground.position,"entity":{}}
	if objects_only:return {}
	query.collision_mask=WALK_LAYER;hit=get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():return {}
	return {"id":-1,"position":hit.position,"entity":{}}
