extends RefCounted

# A provider describes one committed pose. CPU rigs supply their already
# published faces and bounds. GPU rigs supply them through their pose callback.
const PROVIDER := &"native_gpu_pick_provider"
const SURFACE_ID := &"native_gpu_pick_surface_id"
const CPU_REVISION := &"native_cpu_pick_revision"
const CPU_OWNER := &"native_cpu_pick_owner"

var surfaces: Dictionary = {}
var gpu_surfaces := 0
var cpu_generation := 0
var stats := {"refits": 0, "reuses": 0, "boundsMisses": 0, "unavailable": 0,
	"cpuCommits": 0, "cpuRefits": 0, "cpuReuses": 0}

static func defer_cpu_refit(geometry: Resource) -> bool:
	var owner: WeakRef = geometry.get_meta(CPU_OWNER) if geometry.has_meta(CPU_OWNER) else null
	var registry: RefCounted = owner.get_ref() if owner != null else null
	if registry == null:
		return false
	geometry.set_meta(CPU_REVISION, int(geometry.get_meta(CPU_REVISION)) + 1)
	registry.cpu_generation += 1
	registry.stats.cpuCommits += 1
	return true

static func keep_cpu_refit_eager(geometry: Resource) -> void:
	if geometry == null or not geometry.has_meta(CPU_REVISION):
		return
	geometry.remove_meta(CPU_OWNER)
	geometry.remove_meta(CPU_REVISION)
	if geometry.cached_shape != null:
		geometry.cached_shape.set_faces(geometry.vertices)

func shape_for(mesh: MeshInstance3D, source: Shape3D) -> Shape3D:
	if mesh == null or not source is ConcavePolygonShape3D or mesh.get_meta("native_pick_anchor", mesh) != mesh:
		return source
	var id := mesh.get_instance_id()
	var geometry: Resource = mesh.get_meta("native_pick_geometry", null)
	if geometry != null and geometry.has_meta(CPU_REVISION) and is_same(source, geometry.cached_shape):
		var ownership: WeakRef = geometry.get_meta(CPU_OWNER) if geometry.has_meta(CPU_OWNER) else null
		var owner: RefCounted = ownership.get_ref() if ownership != null else null
		if owner != null and owner != self:
			# An externally shared body cannot be deferred by one registry.
			keep_cpu_refit_eager(geometry)
			return source
		if not surfaces.has(id):
			surfaces[id] = {"mesh": weakref(mesh), "shape": source, "target": {}, "scenery": {},
				"revision": -1, "cpu": weakref(geometry)}
		return source
	if not mesh.has_meta(PROVIDER):
		return source
	var provider: Variant = mesh.get_meta(PROVIDER)
	if not provider is Dictionary or not provider.get("pose") is Callable or not provider.get("faces") is Callable:
		return source
	if not surfaces.has(id):
		var shape := ConcavePolygonShape3D.new()
		shape.backface_collision = source.backface_collision
		shape.set_faces(source.get_faces())
		surfaces[id] = {"mesh": weakref(mesh), "shape": shape, "target": {}, "scenery": {}, "revision": -1}
		gpu_surfaces += 1
	return surfaces[id].shape

func track_body(mesh: MeshInstance3D, body: StaticBody3D, layer: String) -> void:
	if mesh == null or not surfaces.has(mesh.get_instance_id()):
		return
	var id := mesh.get_instance_id()
	var row: Dictionary = surfaces[id]
	row[layer][body.get_rid()] = weakref(body)
	body.set_meta(SURFACE_ID, id)
	if row.has("cpu"):
		var geometry: Resource = row.cpu.get_ref()
		if geometry != null and geometry.has_meta(CPU_REVISION):
			geometry.set_meta(CPU_OWNER, weakref(self))
			cpu_generation += 1

func forget_body(body: StaticBody3D, layer: String) -> void:
	var id: int = body.get_meta(SURFACE_ID, 0)
	if not surfaces.has(id):
		return
	var row: Dictionary = surfaces[id]
	row[layer].erase(body.get_rid())
	# A physics body can already have been freed before the registry retires
	# its sibling layer. Do not keep the pose alive through a dead body entry.
	for bodies in [row.target, row.scenery]:
		for rid in bodies.keys():
			if not is_instance_valid(bodies[rid].get_ref()):
				bodies.erase(rid)
	if row.target.is_empty() and row.scenery.is_empty():
		release_surface(id)

func release_surface(id: int) -> void:
	var row: Dictionary = surfaces[id]
	if row.has("cpu"):
		var geometry: Resource = row.cpu.get_ref()
		if geometry != null and geometry.has_meta(CPU_OWNER):
			var ownership: WeakRef = geometry.get_meta(CPU_OWNER)
			if ownership != null and ownership.get_ref() == self:
				geometry.remove_meta(CPU_OWNER)
		cpu_generation += 1
	else:
		gpu_surfaces -= 1
	surfaces.erase(id)

func prepare_ray(origin: Vector3, finish: Vector3) -> Dictionary:
	var stale_targets: Array[RID] = []
	var stale_scenery: Array[RID] = []
	var released_meshes: Array[int] = []
	for id in surfaces:
		var row: Dictionary = surfaces[id]
		var mesh: MeshInstance3D = row.mesh.get_ref()
		if not is_instance_valid(mesh):
			released_meshes.append(id)
			continue
		if mesh.is_inside_tree() and not mesh.is_queued_for_deletion() and prepare_surface(row, mesh, origin, finish):
			continue
		# Neither layer may resolve a stale pose when the certified bounds miss
		# or the current committed pose is unavailable.
		append_live_rids(stale_targets, row.target)
		append_live_rids(stale_scenery, row.scenery)
	for id in released_meshes:
		release_surface(id)
	return {"target": stale_targets, "scenery": stale_scenery}

func append_live_rids(target: Array[RID], bodies: Dictionary) -> void:
	for rid in bodies:
		var body: StaticBody3D = bodies[rid].get_ref()
		if is_instance_valid(body) and body.is_inside_tree():
			target.append(rid)

func prepare_surface(row: Dictionary, mesh: MeshInstance3D, origin: Vector3, finish: Vector3) -> bool:
	if row.has("cpu"):
		return prepare_cpu_surface(row, mesh, origin, finish)
	var provider: Variant = mesh.get_meta(PROVIDER) if mesh.has_meta(PROVIDER) else null
	if not provider is Dictionary or not provider.get("pose") is Callable or not provider.get("faces") is Callable:
		stats.unavailable += 1
		return false
	var pose: Callable = provider.get("pose", Callable())
	var faces: Callable = provider.get("faces", Callable())
	if not pose.is_valid() or not faces.is_valid():
		stats.unavailable += 1
		return false
	var committed: Variant = pose.call()
	if not committed is Dictionary or not committed.get("revision") is int or int(committed.revision) < 0:
		stats.unavailable += 1
		return false
	var bounds: Variant = committed.get("bounds")
	if bounds is AABB and not bounds_cover_ray(row, mesh, bounds, origin, finish):
		stats.boundsMisses += 1
		return false
	var revision: int = committed.revision
	if row.revision == revision:
		stats.reuses += 1
		return true
	var vertices: Variant = faces.call(revision)
	if not vertices is PackedVector3Array or vertices.size() < 3 or vertices.size() % 3 != 0:
		stats.unavailable += 1
		return false
	row.shape.set_faces(vertices)
	row.revision = revision
	stats.refits += 1
	return true

func prepare_cpu_surface(row: Dictionary, mesh: MeshInstance3D, origin: Vector3, finish: Vector3) -> bool:
	var geometry: Resource = row.cpu.get_ref()
	if geometry == null or not is_same(mesh.get_meta("native_pick_geometry", null), geometry):
		stats.unavailable += 1
		return false
	if not geometry.has_meta(CPU_REVISION):
		return true
	var bounds: AABB = geometry.bounds
	if bounds.position.is_finite() and bounds.size.is_finite() and not bounds_cover_ray(row, mesh, bounds, origin, finish):
		stats.boundsMisses += 1
		return false
	var revision := int(geometry.get_meta(CPU_REVISION))
	if row.revision == revision:
		stats.reuses += 1
		stats.cpuReuses += 1
		return true
	row.shape.set_faces(geometry.vertices)
	row.revision = revision
	stats.refits += 1
	stats.cpuRefits += 1
	return true

func bounds_cover_ray(row: Dictionary, mesh: MeshInstance3D, bounds: AABB, origin: Vector3, finish: Vector3) -> bool:
	if box_covers_ray(mesh.global_transform * bounds, origin, finish):
		return true
	# A pending Node3D transform can differ from the transform currently used
	# by the PhysicsServer. Only prune when the actual bodies also miss.
	for bodies in [row.target, row.scenery]:
		for rid in bodies:
			var body: StaticBody3D = bodies[rid].get_ref()
			if not is_instance_valid(body) or not body.is_inside_tree():
				continue
			var physical: Variant = PhysicsServer3D.body_get_state(rid, PhysicsServer3D.BODY_STATE_TRANSFORM)
			if not physical is Transform3D or box_covers_ray(physical * bounds, origin, finish):
				return true
	return false

func box_covers_ray(box: AABB, origin: Vector3, finish: Vector3) -> bool:
	var expanded:=box.grow(0.0001)
	return expanded.has_point(origin) or expanded.has_point(finish) or expanded.intersects_segment(origin, finish)!=null
