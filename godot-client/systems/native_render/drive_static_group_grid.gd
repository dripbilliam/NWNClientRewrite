extends RefCounted

const MAX_CELL_COORDINATE := (1 << 30) - 1
const MAX_GROUP_CELLS := 64
const MAX_QUERY_CELLS := 256


class Group:
	var key: String
	var order: int
	var sequence: int
	var min_x: float
	var min_y: float
	var max_x: float
	var max_y: float
	var cells: Vector4i
	var overflow := false
	var last_query := 0


var _cell_width := 0
var _groups: Dictionary = {}
var _buckets: Dictionary = {}
var _overflow: Dictionary = {}
var _invalid_groups: Dictionary = {}
var _next_sequence := 0
var _query_serial := 0


func configure(cell_width: int) -> void:
	if _cell_width == cell_width:
		return
	clear()
	_cell_width = cell_width


func clear() -> void:
	_groups.clear()
	_buckets.clear()
	_overflow.clear()
	_invalid_groups.clear()
	_next_sequence = 0
	_query_serial = 0


func upsert(key: String, order: int, min_x: float, min_y: float, max_x: float, max_y: float) -> void:
	if _cell_width <= 0:
		return
	if not _valid_bounds(min_x, min_y, max_x, max_y):
		erase(key)
		_invalid_groups[key] = true
		return
	_invalid_groups.erase(key)

	var group: Group = _groups.get(key)
	if group == null:
		group = Group.new()
		group.key = key
		group.sequence = _next_sequence
		_next_sequence += 1
		_groups[key] = group
	else:
		if group.min_x == min_x and group.min_y == min_y and group.max_x == max_x and group.max_y == max_y:
			group.order = order
			return
		_remove_membership(group)
	group.order = order
	group.min_x = min_x
	group.min_y = min_y
	group.max_x = max_x
	group.max_y = max_y

	var cells: Variant = _coverage(min_x, min_y, max_x, max_y)
	group.overflow = cells == null or _cell_count(cells) > MAX_GROUP_CELLS
	if group.overflow:
		_overflow[key] = group
		return
	group.cells = cells
	for y in range(group.cells.y, group.cells.w + 1):
		for x in range(group.cells.x, group.cells.z + 1):
			var cell := Vector2i(x, y)
			var bucket: Dictionary = _buckets.get(cell, {})
			if bucket.is_empty():
				_buckets[cell] = bucket
			bucket[key] = group


func erase(key: String) -> void:
	_invalid_groups.erase(key)
	var group: Group = _groups.get(key)
	if group != null:
		_remove_membership(group)
		_groups.erase(key)


func query(min_x: float, min_y: float, max_x: float, max_y: float) -> Dictionary:
	var keys: Array[String] = []
	var result := {"ready": false, "keys": keys, "visited_cells": 0, "tested_groups": 0}
	if _cell_width <= 0 or not _invalid_groups.is_empty() or not _valid_bounds(min_x, min_y, max_x, max_y):
		return result
	var coverage: Variant = _coverage(min_x, min_y, max_x, max_y)
	if coverage == null or _cell_count(coverage) > MAX_QUERY_CELLS:
		return result

	var cells: Vector4i = coverage
	var found: Array[Group] = []
	_query_serial += 1
	var tested := _visit_bucket(_overflow, found, min_x, min_y, max_x, max_y)
	for y in range(cells.y, cells.w + 1):
		for x in range(cells.x, cells.z + 1):
			var bucket: Variant = _buckets.get(Vector2i(x, y))
			if bucket != null:
				tested += _visit_bucket(bucket, found, min_x, min_y, max_x, max_y)
	found.sort_custom(_before)
	for group in found:
		keys.append(group.key)
	result.ready = true
	result.visited_cells = _cell_count(cells)
	result.tested_groups = tested
	return result


func _remove_membership(group: Group) -> void:
	if group.overflow:
		_overflow.erase(group.key)
		return
	for y in range(group.cells.y, group.cells.w + 1):
		for x in range(group.cells.x, group.cells.z + 1):
			var cell := Vector2i(x, y)
			var bucket: Dictionary = _buckets[cell]
			bucket.erase(group.key)
			if bucket.is_empty():
				_buckets.erase(cell)


func _visit_bucket(bucket: Dictionary, found: Array[Group], min_x: float, min_y: float, max_x: float, max_y: float) -> int:
	var tested := 0
	for key in bucket:
		var group: Group = bucket[key]
		if group.last_query == _query_serial:
			continue
		group.last_query = _query_serial
		tested += 1
		if group.min_x <= max_x and group.min_y <= max_y and group.max_x >= min_x and group.max_y >= min_y:
			found.append(group)
	return tested


func _coverage(min_x: float, min_y: float, max_x: float, max_y: float) -> Variant:
	# Keep the caller's doubles through the floor and range check. Vector2/4
	# components can be float32 even though GDScript's scalar float is double.
	var first_x := floorf(min_x / _cell_width)
	var first_y := floorf(min_y / _cell_width)
	var last_x := floorf(max_x / _cell_width)
	var last_y := floorf(max_y / _cell_width)
	if first_x < -MAX_CELL_COORDINATE or first_y < -MAX_CELL_COORDINATE:
		return null
	if last_x > MAX_CELL_COORDINATE or last_y > MAX_CELL_COORDINATE:
		return null
	return Vector4i(int(first_x), int(first_y), int(last_x), int(last_y))


static func _valid_bounds(min_x: float, min_y: float, max_x: float, max_y: float) -> bool:
	return is_finite(min_x) and is_finite(min_y) and is_finite(max_x) and is_finite(max_y) and min_x <= max_x and min_y <= max_y


static func _cell_count(cells: Vector4i) -> int:
	return (cells.z - cells.x + 1) * (cells.w - cells.y + 1)


static func _before(left: Group, right: Group) -> bool:
	return left.order < right.order or (left.order == right.order and left.sequence < right.sequence)
