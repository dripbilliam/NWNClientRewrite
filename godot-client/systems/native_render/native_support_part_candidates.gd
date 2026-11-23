extends RefCounted
# Fixed tile placements can retain the exact Part traversal order per vertical
# column. Geometry without conservative bounds stays in every column.
const MAX_PARTS := 64
const MAX_COLUMN_REFERENCE_COUNT := 4096
const MAX_CELL_COORDINATE := 1000000.0
const AuthoredBox = preload("res://systems/native_data/native_support_authored_box.gd")

var valid := false
var pose: Transform3D
var parts: Array
var part_count := 0
var columns: Dictionary
var fallback: Array
var world_boxes: Dictionary
var native_batch: RefCounted
var native_masks: Dictionary
var native_fallback_mask := 0

static func cell(point: Vector3) -> Vector2i:
	return Vector2i(floori(point.x), floori(point.z))

static func supported_point(point: Vector3) -> bool:
	return point.is_finite() and absf(point.x) < MAX_CELL_COORDINATE and absf(point.z) < MAX_CELL_COORDINATE

static func withdraw(tile: Node3D) -> void:
	tile.remove_meta("native_support_fixed_parts")
	if tile.has_meta("native_support_part_candidates"):
		tile.get_meta("native_support_part_candidates").invalidate()
	tile.remove_meta("native_scene_parts")

func prepare(source: Array, root_pose: Transform3D, ordinary_bounds: Callable, compile_batch: bool = false) -> bool:
	if source.is_empty() or source.size() > MAX_PARTS:
		return false
	var cells: Dictionary = {}
	var unbounded := []
	var bounded_nodes: Dictionary = {}
	var references := 0
	for index in source.size():
		var part: Dictionary = source[index]
		if not is_instance_valid(part.node) or part.node.is_queued_for_deletion():
			return false
		var provenance: Variant = part.node.get_meta("native_mesh_source") if part.node.has_meta("native_mesh_source") else null
		var bounds: Variant = ordinary_bounds.call(part, provenance, part.node.global_transform) if provenance is Dictionary else null
		if not bounds is AABB or not supported_point(bounds.position) or not supported_point(bounds.end):
			unbounded.append(index)
			continue
		var first := cell(bounds.position)
		var last := cell(bounds.end)
		var count := (last.x - first.x + 1) * (last.y - first.y + 1)
		if count > MAX_COLUMN_REFERENCE_COUNT - references:
			unbounded.append(index)
			continue
		if bounded_nodes.has(part.node):
			return false
		bounded_nodes[part.node] = bounds
		references += count
		for x in range(first.x, last.x + 1):
			for z in range(first.y, last.y + 1):
				var key := Vector2i(x, z)
				if not cells.has(key):
					cells[key] = []
				cells[key].append(index)
	if cells.is_empty() or references + cells.size() * unbounded.size() > MAX_COLUMN_REFERENCE_COUNT:
		return false
	for key: Vector2i in cells:
		var indices: Array = cells[key]
		indices.append_array(unbounded)
		indices.sort()
		if compile_batch:
			var mask := 0
			for index: int in indices:
				mask |= 1 << index
			native_masks[key] = mask
		for index in indices.size():
			indices[index] = source[indices[index]]
	columns = cells
	fallback = unbounded.map(func(index): return source[index])
	world_boxes = bounded_nodes
	parts = source
	part_count = source.size()
	pose = root_pose
	# Part exit is also an invalidation, even if a tool removed the node
	# outside of the fixed placement owner's normal retirement flow.
	for node in bounded_nodes:
		node.tree_exiting.connect(invalidate, CONNECT_ONE_SHOT)
	valid = true
	if compile_batch:
		for index: int in unbounded:
			native_fallback_mask |= 1 << index
		_prepare_native_batch()
	return true

func _prepare_native_batch() -> void:
	var rows: Array = []
	for part: Dictionary in parts:
		var node: Node3D = part.node
		var source: Variant = node.get_meta("native_mesh_source") if node.has_meta("native_mesh_source") else null
		if not source is Dictionary or not source.get("node_is_aabb") is bool \
				or source.get("native_tilefade_available") != true or not source.get("native_tilefade") is int:
			return
		var excluded: bool = int(source.native_tilefade) in [2, 4]
		var row := {"node": node.get_instance_id(), "excluded": excluded}
		rows.append(row)
		if excluded:
			continue
		var aabb: bool = source.node_is_aabb
		if not aabb:
			if source.get("native_bounds_available") != true or source.get("native_bounds_valid") != true \
					or not source.get("native_bounds") is Dictionary:
				return
			var low: Variant = AuthoredBox.vector(source.native_bounds.get("min"))
			var high: Variant = AuthoredBox.vector(source.native_bounds.get("max"))
			if low == null or high == null or low.x > high.x or low.y > high.y or low.z > high.z:
				return
			row.authored_low = [low.x, low.y, low.z]
			row.authored_high = [high.x, high.y, high.z]
		var data: Resource = part.data
		if aabb and data.surface_types.size() != data.indices.size() / 3:
			return
		var local: AABB = data.bounds
		if not local.position.is_finite() or not local.end.is_finite():
			return
		var geometry: RefCounted = data.prepare_native() if aabb or data.surface_types.is_empty() else data.prepare_native_unmasked_support()
		if geometry == null:
			return
		var token: Variant = geometry.call("dispatch", 2, {})
		if not token is int:
			return
		row.merge({
			"aabb": aabb, "bounded": world_boxes.has(node), "geometry": token,
			"geometry_owner": geometry,
			"local_low": [local.position.x, local.position.y, local.position.z],
			"local_high": [local.end.x, local.end.y, local.end.z]
		})
		if row.bounded:
			var world: AABB = world_boxes[node]
			row.world_low = [world.position.x, world.position.y, world.position.z]
			row.world_high = [world.end.x, world.end.y, world.end.z]
	var batch: RefCounted = ClassDB.instantiate("NwnFixedTerrainSupport")
	if batch != null and batch.call("dispatch", 0, {"parts": rows}) == null:
		native_batch = batch

func invalidate() -> void:
	valid = false
	parts = []
	columns.clear()
	fallback.clear()
	world_boxes.clear()
	native_batch = null
	native_masks.clear()
	native_fallback_mask = 0
