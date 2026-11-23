extends Node
# Precipitation uses the static layer. Sun fits can add a separate layer for
# moving cast shadows. The two layers share a scenario and fit matrices.
const BaseScenery=preload("res://systems/native_render/base_world_scenery.gd")
const Profile=preload("res://systems/native_render/frame_profile.gd")
const ActorShadowMesh=preload("res://systems/native_render/actor_shadow_mesh.gd")
const BATCH_FRAMES:=30
const MAP_SIZE:=512
const STATIC_LAYER:=1
const MOVING_LAYER:=2

class Capture extends CompositorEffect:
	var lock:=Mutex.new()
	var current: Dictionary={}
	func _init() -> void:
		effect_callback_type=EFFECT_CALLBACK_TYPE_POST_TRANSPARENT
	func _render_callback(stage: int,data: RenderData) -> void:
		if stage!=EFFECT_CALLBACK_TYPE_POST_TRANSPARENT: return
		var buffers:=data.get_render_scene_buffers() as RenderSceneBuffersRD
		var scene:=data.get_render_scene_data()
		if buffers==null or scene==null: return
		var depth:=buffers.get_depth_layer(0,false)
		if not depth.is_valid(): return
		var matrix:=scene.get_view_projection(0)*Projection(scene.get_cam_transform().affine_inverse())
		lock.lock()
		current={"depth":depth,"matrix":matrix,"bakes":int(current.get("bakes",0))+1}
		lock.unlock()
	func snapshot() -> Dictionary:
		lock.lock()
		var result:=current
		lock.unlock()
		return result

class MovingCaster extends RefCounted:
	# Godot Nodes remain owned by the scene tree. Keeping their typed handles
	# here avoids resolving one WeakRef per caster every frame.
	var node: GeometryInstance3D
	var mesh_node: MeshInstance3D
	var multimesh_node: MultiMeshInstance3D
	var geometry: Resource
	var rid: RID
	var transform: Transform3D
	var visible: bool
	var material: Material
	var skeleton: RID
	var on_input_changed: Callable

	func _init(source: GeometryInstance3D) -> void:
		node=source
		mesh_node=source as MeshInstance3D
		multimesh_node=source as MultiMeshInstance3D

var world: Node3D
var caster_world: World3D
var radii: PackedFloat32Array
var slacks: PackedFloat32Array
var shadows_only: bool
var viewports: Array[SubViewport]=[]
var cameras: Array[Camera3D]=[]
var captures: Array[CompositorEffect]=[]
var moving_views: Array[SubViewport]=[]
var moving_cameras: Array[Camera3D]=[]
var moving_captures: Array[CompositorEffect]=[]
var empty_fits: Array[CompositorEffect]=[]
var centres: Array[Vector3]=[]
var direction:=Vector3.ZERO
var last_bake_frame:=-BATCH_FRAMES
var dirty:=true
var invalidated:=false
var renderables: Dictionary={}
var static_places: Dictionary={}
var moving_roots: Dictionary={}
var moving_root_ids: Dictionary={}
var moving_root_meshes: Dictionary={}
var moving_root_changes: Dictionary={}
var moving_meshes: Dictionary[int, MovingCaster]={}
var moving_polled: Dictionary[int, MovingCaster]={}
var moving_changed: Dictionary[int, bool]={}
var moving_observed_visible: Dictionary[int, bool]={}
var moving_polled_active:=false
var moving_fit_mask:=0
var moving_dirty:=false
var moving_active:=false
var moving_baked_mask:=0
var moving_pending_mask:=0
var watched_skeletons: Dictionary={}
var terrain: Node
var terrain_signal:=Callable()

func configure(owner: Node3D,fit_radii: PackedFloat32Array,fit_slacks: PackedFloat32Array,shadow_casters_only: bool=false) -> void:
	world=owner
	radii=fit_radii
	slacks=fit_slacks
	shadows_only=shadow_casters_only
	centres.resize(radii.size())
	centres.fill(Vector3.INF)
	world.instance_ready.connect(_instance_ready)
	world.instance_removed.connect(_instance_removed)
	if shadows_only: world.instance_state_changed.connect(_instance_state_changed)
	if is_instance_valid(world.references): world.references.published.connect(_reference_published)
	for id in world.instances:
		var row: Dictionary=world.desired.get(id,{}).get("object",{})
		_instance_ready(id,row,world.instances[id])

func _instance_ready(id: int,source: Dictionary,instance: Node3D) -> void:
	var placement: bool=BaseScenery.classify(source,world.area_id).base
	var animated:=false
	if shadows_only and placement:
		animated=preload("res://systems/native_render/placeable_instance.gd").requires_animation(source.get("replicated",{}))
	if placement and not animated:
		static_places[id]=weakref(instance)
		dirty=true
		_remove_moving_root(id)
	else:
		if static_places.erase(id): invalidated=true
		if shadows_only:
			_remove_moving_root(id)
			moving_roots[id]=weakref(instance)
			moving_root_ids[instance.get_instance_id()]=id
			moving_root_changes[id]=true

func _instance_state_changed(id: int,source: Dictionary) -> void:
	if int(source.get("objectType",0))!=9 or not world.instances.has(id): return
	var placement: bool=BaseScenery.classify(source,world.area_id).base
	var animated:=placement and preload("res://systems/native_render/placeable_instance.gd").requires_animation(source.get("replicated",{}))
	if static_places.has(id)==(placement and not animated): return
	_instance_ready(id,source,world.instances[id])

func _instance_removed(id: int) -> void:
	if static_places.erase(id): invalidated=true
	_remove_moving_root(id)

func _remove_moving_root(id: int) -> void:
	var reference: WeakRef=moving_roots.get(id)
	if reference==null: return
	var instance: Node=reference.get_ref()
	if is_instance_valid(instance): moving_root_ids.erase(instance.get_instance_id())
	moving_roots.erase(id)
	moving_root_changes[id]=true

func _reference_published(reference: Node, _model: Node) -> void:
	var ancestor:=reference.get_parent()
	while ancestor!=null and ancestor!=world:
		var instance_id:=ancestor.get_instance_id()
		if moving_root_ids.has(instance_id):
			moving_root_changes[moving_root_ids[instance_id]]=true
			return
		ancestor=ancestor.get_parent()
	dirty=true

func _terrain_progress(_state: Dictionary) -> void: dirty=true
func _caster_visibility() -> void: invalidated=true

func _observe_terrain() -> void:
	var target: Node=world.terrain
	if target==terrain: return
	if is_instance_valid(terrain) and terrain.progress.is_connected(terrain_signal): terrain.progress.disconnect(terrain_signal)
	terrain=target
	terrain_signal=_terrain_progress
	if is_instance_valid(terrain): terrain.progress.connect(terrain_signal)
	invalidated=true

func _add_view(radius: float,layer: int) -> void:
	var viewport:=SubViewport.new()
	viewport.size=Vector2i(MAP_SIZE,MAP_SIZE)
	viewport.world_3d=caster_world
	viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
	RenderingServer.viewport_set_disable_2d(viewport.get_viewport_rid(),true)
	viewport.positional_shadow_atlas_size=0
	add_child(viewport)
	var camera:=Camera3D.new()
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.size=radius*2.0
	camera.near=0.05
	camera.far=radius*4.0
	camera.cull_mask=layer
	var capture:=Capture.new()
	camera.compositor=Compositor.new()
	camera.compositor.compositor_effects=[capture]
	viewport.add_child(camera)
	camera.make_current()
	if layer==STATIC_LAYER:
		viewports.append(viewport)
		cameras.append(camera)
		captures.append(capture)
	else:
		moving_views.append(viewport)
		moving_cameras.append(camera)
		moving_captures.append(capture)

func update(focus: Vector3,fall: Vector3) -> Array[CompositorEffect]:
	var phase:=Profile.begin() if shadows_only else 0
	_observe_terrain()
	var frame:=Engine.get_process_frames()
	var outer:=radii.size()-1
	var inspection_due:=invalidated or dirty and frame-last_bake_frame>=BATCH_FRAMES
	var recheck:=inspection_due
	var recapture:=recheck or not direction.is_equal_approx(fall)
	var bake_mask:=0
	for i in radii.size():
		var moved:=not centres[i].is_finite() or focus.distance_squared_to(centres[i])>slacks[i]*slacks[i]
		if moved:
			centres[i]=focus
			if i==outer: recheck=true
		if moved or recapture: bake_mask|=1<<i
	if bake_mask!=0: direction=fall
	Profile.finish("particle_cx_shadow_fit_ms",phase)
	if recheck:
		phase=Profile.begin() if shadows_only else 0
		var casters_changed:=_rebuild(centres[outer],radii[outer])
		Profile.finish("particle_cx_shadow_static_ms",phase)
		last_bake_frame=frame
		# A camera-only refit leaves the other maps valid when the retained
		# proxies are unchanged. Explicit content notifications can also
		# modify mesh data behind a stable resource, so redraw all fits then.
		if inspection_due or casters_changed: bake_mask=(1<<radii.size())-1
	var moving_mask:=0
	if shadows_only:
		if not moving_root_changes.is_empty():
			phase=Profile.begin()
			_sync_moving_roots()
			Profile.finish("particle_cx_shadow_roots_ms",phase)
		phase=Profile.begin()
		var changed:=_sync_moving_meshes()
		Profile.finish("particle_cx_shadow_casters_ms",phase)
		phase=Profile.begin()
		moving_fit_mask=bake_mask
		moving_mask=_take_moving_bakes(frame,bake_mask,changed)
	else:
		phase=0
	if bake_mask|moving_mask:
		var up:=Vector3.RIGHT if absf(fall.dot(Vector3.UP))>0.99 else Vector3.UP
		var basis:=Basis.looking_at(fall,up)
		for i in radii.size():
			var pose:=Transform3D(basis,centres[i]-fall*(radii[i]*2.0))
			if bake_mask&(1<<i) and not renderables.is_empty():
				cameras[i].global_transform=pose
				viewports[i].render_target_update_mode=SubViewport.UPDATE_ONCE
			if moving_mask&(1<<i) and moving_active:
				_schedule_moving_capture(i,pose)
	# This is CPU scheduling. The render-thread/GPU work runs later.
	Profile.finish("particle_cx_shadow_schedule_ms",phase)
	return static_fits()

func _take_moving_bakes(frame: int, bake_mask: int, changed: bool) -> int:
	if not moving_active:
		moving_baked_mask=0
		moving_pending_mask=0
		return 0
	if changed: moving_pending_mask|=(1<<radii.size())-1
	moving_pending_mask|=bake_mask
	var mask:=moving_pending_mask
	var outer_bit:=1<<(radii.size()-1)
	# Hold the far moving map for one frame only at an unchanged fit.
	if frame&1 and moving_baked_mask&outer_bit and not bake_mask&outer_bit:
		mask&=~outer_bit
	moving_pending_mask&=~mask
	moving_baked_mask|=mask
	return mask

func _schedule_moving_capture(index: int, pose: Transform3D) -> void:
	var camera:=moving_cameras[index]
	# Caster motion generally leaves the fit camera unchanged.
	if camera.global_transform!=pose or camera.is_physics_interpolated_and_enabled():
		camera.global_transform=pose
	moving_views[index].render_target_update_mode=SubViewport.UPDATE_ONCE

func static_fits() -> Array[CompositorEffect]:
	return captures if not renderables.is_empty() else empty_fits

func moving_fits() -> Array[CompositorEffect]:
	return moving_captures if moving_active else empty_fits

func flush_observed_movers() -> bool:
	if moving_changed.is_empty(): return false
	var phase:=Profile.begin()
	var was_active:=moving_active
	_reconcile_moving_changes(watched_skeletons)
	var changed:=_finish_moving_sync()
	Profile.finish("particle_cx_shadow_casters_ms",phase)
	if changed:
		var mask:=_take_moving_bakes(Engine.get_process_frames(),moving_fit_mask,true)
		if mask!=0:
			var up:=Vector3.RIGHT if absf(direction.dot(Vector3.UP))>0.99 else Vector3.UP
			var basis:=Basis.looking_at(direction,up)
			for i in radii.size():
				if mask&(1<<i) and moving_views[i].render_target_update_mode!=SubViewport.UPDATE_ONCE:
					_schedule_moving_capture(i,Transform3D(basis,centres[i]-direction*(radii[i]*2.0)))
	return was_active!=moving_active

func _sync_moving_roots() -> void:
	for root_id in moving_root_changes:
		var source: WeakRef=moving_roots.get(root_id)
		var root: Node=source.get_ref() if source!=null else null
		var current: Dictionary={}
		if is_instance_valid(root):
			var pending: Array[Node]=[root]
			while not pending.is_empty():
				var node: Node=pending.pop_back()
				if node.is_queued_for_deletion(): continue
				if node is MeshInstance3D or node is MultiMeshInstance3D:
					var id:=node.get_instance_id()
					current[id]=true
					if not moving_meshes.has(id): _register_moving_mesh(id,node as GeometryInstance3D)
				pending.append_array(node.get_children())
		for id in moving_root_meshes.get(root_id,{}):
			if current.has(id): continue
			_remove_moving_mesh(id)
		if current.is_empty(): moving_root_meshes.erase(root_id)
		else: moving_root_meshes[root_id]=current
	moving_root_changes.clear()

func _register_moving_mesh(id: int, node: GeometryInstance3D) -> void:
	var row := MovingCaster.new(node)
	moving_meshes[id] = row
	# Actor mesh publishers invalidate non-transform inputs explicitly.
	# Other meshes, and skin bindings with an independently changing pose,
	# still reconcile their inputs through the same row updater.
	if node is ActorShadowMesh and node.get_skin_reference() == null:
		node.set_notify_transform(true)
		row.on_input_changed = _mark_moving_input.bind(id)
		node.shadow_input_changed.connect(row.on_input_changed)
		moving_changed[id] = true
	else:
		moving_polled[id] = row

func _mark_moving_input(state_changed: bool, id: int) -> void:
	if state_changed:
		moving_changed[id] = true
	elif not moving_changed.has(id) and moving_meshes[id].rid.is_valid():
		moving_changed[id] = false

func _stop_observing(row: MovingCaster) -> void:
	if not is_instance_valid(row.node): return
	var node := row.node as ActorShadowMesh
	if is_instance_valid(node) and node.shadow_input_changed.is_connected(row.on_input_changed):
		node.shadow_input_changed.disconnect(row.on_input_changed)

func _remove_moving_mesh(id: int) -> void:
	var row := moving_meshes[id]
	if row.on_input_changed.is_valid():
		_stop_observing(row)
	moving_changed.erase(id)
	moving_polled.erase(id)
	moving_observed_visible.erase(id)
	_free_moving_proxy(row)
	moving_meshes.erase(id)

func _moving_pose_updated() -> void:
	moving_dirty=true

func _free_moving_proxy(row: MovingCaster) -> void:
	if not row.rid.is_valid(): return
	RenderingServer.free_rid(row.rid)
	row.rid=RID()
	row.geometry=null
	row.material=null
	row.skeleton=RID()
	moving_dirty=true

func _sync_moving_meshes() -> bool:
	if Profile.enabled:
		Profile.count("count_cx_shadow_registered_rows",moving_meshes.size())
		Profile.count("count_cx_shadow_polled_rows",moving_polled.size())
	moving_polled_active=false
	var skeletons: Dictionary={}
	for id in moving_polled:
		if _sync_moving_row(moving_polled[id],skeletons): moving_polled_active=true
	_reconcile_moving_changes(skeletons)
	if not watched_skeletons.is_empty(): _disconnect_inactive_skeletons(skeletons)
	watched_skeletons=skeletons
	return _finish_moving_sync()

func _reconcile_moving_changes(skeletons: Dictionary) -> void:
	if Profile.enabled: Profile.count("count_cx_shadow_changed_rows",moving_changed.size())
	for id in moving_changed:
		var row := moving_meshes[id]
		if not moving_changed[id]:
			_sync_moving_transform(row)
			continue
		var visible := _sync_moving_row(row,skeletons)
		if is_instance_valid(row.mesh_node) and row.mesh_node.get_skin_reference()!=null:
			_stop_observing(row)
			row.on_input_changed = Callable()
			moving_observed_visible.erase(id)
			moving_polled[id] = row
			moving_polled_active = moving_polled_active or visible
		elif visible:
			moving_observed_visible[id] = true
		else:
			moving_observed_visible.erase(id)
	moving_changed.clear()

func _finish_moving_sync() -> bool:
	var active:=moving_polled_active or not moving_observed_visible.is_empty()
	var changed:=moving_dirty or active!=moving_active
	moving_dirty=false
	moving_active=active
	return changed

func _sync_moving_row(row: MovingCaster,skeletons: Dictionary) -> bool:
	var node:=row.node
	var geometry: Resource
	if is_instance_valid(node) and node.is_inside_tree() and node.cast_shadow!=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF and node.layers!=0:
		geometry=row.mesh_node.mesh if row.mesh_node!=null else row.multimesh_node.multimesh
	if geometry==null:
		if row.geometry!=null: _free_moving_proxy(row)
		return false

	var new_proxy:=row.geometry!=geometry
	if new_proxy:
		_free_moving_proxy(row)
		if caster_world==null: caster_world=World3D.new()
		if moving_views.is_empty():
			for radius in radii: _add_view(radius,MOVING_LAYER)
		row.rid=_create_proxy(geometry,MOVING_LAYER)
		row.geometry=geometry
		moving_dirty=true

	_sync_moving_transform(row,new_proxy)
	var visible:=node.is_visible_in_tree()
	if new_proxy or row.visible!=visible:
		RenderingServer.instance_set_visible(row.rid,visible)
		row.visible=visible
		moving_dirty=true
	var material:=node.material_override
	if row.material!=material:
		RenderingServer.instance_geometry_set_material_override(row.rid,material.get_rid() if material!=null else RID())
		row.material=material
		moving_dirty=true
	if not visible: return false

	var mesh:=row.mesh_node
	if mesh==null: return true
	var skin:=mesh.get_skin_reference()
	var skeleton_rid:=skin.get_skeleton() if skin!=null else RID()
	if row.skeleton!=skeleton_rid:
		RenderingServer.instance_attach_skeleton(row.rid,skeleton_rid)
		row.skeleton=skeleton_rid
		moving_dirty=true
	if skin!=null:
		var skeleton:=mesh.get_node_or_null(mesh.skeleton) as Skeleton3D
		if is_instance_valid(skeleton):
			var id:=skeleton.get_instance_id()
			if not skeletons.has(id):
				var watcher: WeakRef=watched_skeletons.get(id)
				if watcher==null:
					watcher=weakref(skeleton)
					skeleton.skeleton_updated.connect(_moving_pose_updated)
				skeletons[id]=watcher
	return true

func _sync_moving_transform(row: MovingCaster, force: bool = false) -> void:
	var transform := row.node.global_transform
	if force or row.transform != transform:
		RenderingServer.instance_set_transform(row.rid,transform)
		row.transform=transform
		moving_dirty=true

func _disconnect_inactive_skeletons(current: Dictionary) -> void:
	for id in watched_skeletons:
		if current.has(id): continue
		var skeleton: Skeleton3D=watched_skeletons[id].get_ref()
		if is_instance_valid(skeleton): skeleton.skeleton_updated.disconnect(_moving_pose_updated)

func _rebuild(centre: Vector3,radius: float) -> bool:
	dirty=false
	invalidated=false
	var roots: Array[Node]=[]
	if is_instance_valid(terrain): roots.append(terrain)
	if is_instance_valid(world.base_draw_merge): roots.append(world.base_draw_merge)
	for reference: WeakRef in static_places.values():
		var place: Node=reference.get_ref()
		if is_instance_valid(place): roots.append(place)
	var current: Dictionary={}
	var changed:=false
	# Conservative world AABB for the tilted orthographic box.
	var extent:=Vector3.ONE*(radius*sqrt(6.0))
	var bounds:=AABB(centre-extent,extent*2.0)
	while not roots.is_empty():
		var root: Node=roots.pop_back()
		if root.is_queued_for_deletion(): continue
		if root is GeometryInstance3D and _collect(root,bounds,current): changed=true
		roots.append_array(root.get_children())
	for id in renderables.keys():
		if not current.has(id):
			_free_caster(renderables[id])
			renderables.erase(id)
			changed=true
	return changed

func _collect(node: GeometryInstance3D,bounds: AABB,current: Dictionary) -> bool:
	if shadows_only and node.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF: return false
	var transform:=node.global_transform
	if node.layers==0 or not (transform*node.get_aabb()).intersects(bounds): return false
	var geometry: Resource
	if node is MeshInstance3D:
		if node.skin!=null: return false
		geometry=node.mesh
	elif node is MultiMeshInstance3D: geometry=node.multimesh
	if geometry==null: return false
	if caster_world==null: caster_world=World3D.new()
	if viewports.is_empty():
		for radius in radii: _add_view(radius,STATIC_LAYER)
	var id:=node.get_instance_id()
	if current.has(id): return false
	current[id]=true
	var row: Dictionary=renderables.get(id,{})
	var replaced: bool=row.is_empty() or row.geometry!=geometry
	if replaced:
		if not row.is_empty(): _free_caster(row)
		row={"node":weakref(node),"geometry":geometry,"rid":_create_proxy(geometry,STATIC_LAYER)}
		node.visibility_changed.connect(_caster_visibility)
		node.tree_exiting.connect(_caster_visibility)
		renderables[id]=row
	return _sync_proxy(row,node,transform) or replaced

func _create_proxy(geometry: Resource,layer: int) -> RID:
	var rid:=RenderingServer.instance_create2(geometry.get_rid(),caster_world.scenario)
	RenderingServer.instance_set_layer_mask(rid,layer)
	RenderingServer.instance_geometry_set_cast_shadows_setting(rid,RenderingServer.SHADOW_CASTING_SETTING_OFF)
	return rid

func _sync_proxy(row: Dictionary,node: GeometryInstance3D,transform: Transform3D) -> bool:
	var changed:=false
	if not row.has("transform") or row.transform!=transform:
		RenderingServer.instance_set_transform(row.rid,transform)
		row.transform=transform
		changed=true
	var visible:=node.is_visible_in_tree()
	if not row.has("visible") or row.visible!=visible:
		RenderingServer.instance_set_visible(row.rid,visible)
		row.visible=visible
		changed=true
	var material:=node.material_override
	if row.get("material")!=material:
		row.material=material
		RenderingServer.instance_geometry_set_material_override(row.rid,material.get_rid() if material!=null else RID())
		changed=true
	return changed

func _free_caster(row: Dictionary) -> void:
	var node: Node=row.node.get_ref()
	if is_instance_valid(node):
		if node.visibility_changed.is_connected(_caster_visibility): node.visibility_changed.disconnect(_caster_visibility)
		if node.tree_exiting.is_connected(_caster_visibility): node.tree_exiting.disconnect(_caster_visibility)
	RenderingServer.free_rid(row.rid)

func _exit_tree() -> void:
	_disconnect_inactive_skeletons({})
	for id in moving_meshes.keys(): _remove_moving_mesh(id)
	for row in renderables.values(): _free_caster(row)
	renderables.clear()
