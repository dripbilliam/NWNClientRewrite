extends RefCounted
# Native PlayerInfo mask0x200 -> CNWCTile850120 ordered setter kernel.
# Caller owns received tile state, scope, delivery serial and existing callbacks.
# No map store, local exploration, visibility query, timer or rendering policy.
const MAX_TILES := 65536
const MAX_OPERATIONS := 131072
const MAX_SAFE_SERIAL := 9007199254740991

static func _integer(value: Variant, minimum: int, maximum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value >= minimum and value <= maximum and float(value) == floor(float(value))

static func _flag(value: Variant) -> Variant:
	if value is bool: return int(value)
	if (value is int or value is float) and is_finite(float(value)) and (value == 0 or value == 1): return 0 if value == 0 else 1
	return null

static func _sequence(value: Variant) -> bool:
	return value is Array or value is PackedByteArray

static func _unavailable(reason: String, field: String) -> Dictionary:
	return {"available": false, "reason": reason, "field": field, "states": null, "operations": [], "warnings": [], "delivery": null}

static func _append_set(states: Array, operations: Array, warnings: Array, width: int, height: int, x: int, y: int, value: int, suppress: int, point_index: Variant = null) -> void:
	if x >= width or y >= height:
		warnings.append({"code": "missing-tile", "x": x, "y": y, "point_index": point_index})
		return
	var index := y * width + x
	var old: int = states[index]
	var changed := old != value
	operations.append({"sequence": operations.size(), "tile_index": index, "x": x, "y": y, "previous": old, "new_state": value, "suppress_object_updates": suppress, "changed": changed, "notify_objects": changed and suppress == 0})
	if changed: states[index] = value

static func project(input: Variant) -> Dictionary:
	if not input is Dictionary: return _unavailable("missing-input", "input")
	var width: Variant = input.get("width")
	var height: Variant = input.get("height")
	if not _integer(width, 1, MAX_TILES) or not _integer(height, 1, MAX_TILES) or width * height > MAX_TILES: return _unavailable("invalid-dimensions", "width/height")
	var size := int(width) * int(height)
	var previous: Variant = input.get("previous")
	if not _sequence(previous) or previous.size() != size: return _unavailable("missing-current-tile-state", "previous")
	for index in size:
		if not _integer(previous[index], -2147483648, 2147483647): return _unavailable("invalid-current-tile-state", "previous[%d]" % index)
	var change: Variant = input.get("change")
	if not change is Dictionary or not change.get("mode") is Array or change.mode.size() != 2: return _unavailable("missing-mode", "change.mode")
	var first: Variant = _flag(change.mode[0])
	var second: Variant = _flag(change.mode[1])
	if first == null or second == null: return _unavailable("invalid-mode", "change.mode")
	var delivery: Variant = null
	if input.has("delivery"):
		var value: Variant = input.delivery
		if not value is Dictionary or not value.get("scope") is String or value.scope.is_empty() or not _integer(value.get("serial"), 0, MAX_SAFE_SERIAL): return _unavailable("invalid-delivery", "delivery")
		delivery = {"scope": value.scope, "serial": int(value.serial)}
	# Validate all supplied decoded data before producing any partial operation.
	if second != 0:
		if not _sequence(change.get("bytes")) or change.bytes.size() > 255: return _unavailable("missing-or-invalid-packed-bytes", "change.bytes")
		for index in change.bytes.size():
			if not _integer(change.bytes[index], 0, 255): return _unavailable("invalid-packed-byte", "change.bytes[%d]" % index)
	else:
		if not change.get("points") is Array: return _unavailable("missing-points", "change.points")
		if change.points.size() + (size if first != 0 else 0) > MAX_OPERATIONS: return _unavailable("operation-limit", "change.points")
		for index in change.points.size():
			var point: Variant = change.points[index]
			if not point is Dictionary or not _integer(point.get("x"), 0, 255) or not _integer(point.get("y"), 0, 255): return _unavailable("invalid-point", "change.points[%d]" % index)
			if first == 0 and _flag(point.get("state")) == null: return _unavailable("missing-or-invalid-point-state", "change.points[%d].state" % index)
	var states: Array = []
	for value in previous: states.append(int(value))
	var operations: Array = []
	var warnings: Array = []
	if second != 0:
		for byte_index in change.bytes.size():
			for bit in 8:
				var index: int = byte_index * 8 + bit
				if index >= size: continue
				var value: int = (int(change.bytes[byte_index]) >> bit) & 1
				_append_set(states, operations, warnings, int(width), int(height), index % int(width), floori(float(index) / float(width)), value, 1 - value)
	elif first != 0:
		var value := 1 if change.points.is_empty() else 0
		for x in int(width):
			for y in int(height): _append_set(states, operations, warnings, int(width), int(height), x, y, value, 1 - value)
		for index in change.points.size():
			var point: Dictionary = change.points[index]
			_append_set(states, operations, warnings, int(width), int(height), int(point.x), int(point.y), 1, 0, index)
	else:
		for index in change.points.size():
			var point: Dictionary = change.points[index]
			var value: int = _flag(point.state)
			_append_set(states, operations, warnings, int(width), int(height), int(point.x), int(point.y), value, 1 - value, index)
	return {"available": true, "reason": null, "field": null, "states": states, "operations": operations, "warnings": warnings, "delivery": delivery}

static func _current(callback: Callable) -> bool:
	var value: Variant = callback.call()
	return value is bool and value

# Apply ONE validated ordered operation to a caller-owned canonical Array. No
# scan/copy of the full map. Read old state NOW; projected previous/changed are
# evidence only and cannot override reentrant/current canonical state.
# options: objects(Callable), fog_enabled(bool), fog(Callable), is_current(Callable).
# callbacks receive detached scalar event dictionaries. Objects run first when
# unsuppressed, then optional fog, then the original unconditional final store.
# A scope guard may retire the operation between callbacks; it never resolves a
# new area or retargets the caller's old Array. Missing required callback fails
# before any side effect. Caller controls once-only delivery and ownership.
static func apply_operation(states: Variant, operation: Variant, options: Dictionary = {}) -> Dictionary:
	var result := {"available": false, "reason": "invalid-setter-input", "changed": false, "stored": false, "cancelled": false, "objects_called": false, "fog_called": false, "old_state": null, "new_state": null}
	if not states is Array or states.size() > MAX_TILES or not operation is Dictionary: return result
	if not _integer(operation.get("tile_index"), 0, states.size() - 1) or not _integer(operation.get("x"), 0, MAX_TILES - 1) or not _integer(operation.get("y"), 0, MAX_TILES - 1): return result
	var value: Variant = _flag(operation.get("new_state"))
	var suppress: Variant = _flag(operation.get("suppress_object_updates"))
	if value == null or suppress == null: return result
	var index := int(operation.tile_index)
	if not _integer(states[index], -2147483648, 2147483647): result.reason = "current-tile-state-unavailable"; return result
	var guard: Variant = options.get("is_current")
	if options.has("is_current") and (not guard is Callable or not guard.is_valid()): result.reason = "scope-guard-unavailable"; return result
	if guard is Callable and not _current(guard): result.reason = "scope-changed"; result.cancelled = true; return result
	var old := int(states[index])
	result.old_state = old
	result.new_state = int(value)
	result.changed = old != value
	result.available = true
	result.reason = "native-tile-setter"
	if old == value: return result
	var objects: Variant = options.get("objects")
	var fog: Variant = options.get("fog")
	var fog_enabled: Variant = options.get("fog_enabled")
	if not fog_enabled is bool: result.available = false; result.reason = "fog-admission-unavailable"; return result
	if suppress == 0 and (not objects is Callable or not objects.is_valid()): result.available = false; result.reason = "object-callback-unavailable"; return result
	if fog_enabled and (not fog is Callable or not fog.is_valid()): result.available = false; result.reason = "fog-callback-unavailable"; return result
	var event := {"tile_index": index, "x": int(operation.x), "y": int(operation.y), "previous": old, "new_state": int(value), "suppress_object_updates": int(suppress), "revealed": value != 0, "fogged": value == 0}
	if suppress == 0:
		objects.call(event.duplicate(true))
		result.objects_called = true
	if guard is Callable and not _current(guard): result.available = false; result.reason = "scope-changed"; result.cancelled = true; return result
	if fog_enabled:
		fog.call(event.duplicate(true))
		result.fog_called = true
	if guard is Callable and not _current(guard): result.available = false; result.reason = "scope-changed"; result.cancelled = true; return result
	if index >= states.size(): result.available = false; result.reason = "current-tile-retired"; return result
	states[index] = int(value)
	result.stored = true
	return result

static func _f32(value: float) -> float:
	return PackedFloat32Array([value])[0]

# Native XY inputs only, not Godot XZ. Z is deliberately never read. Bounds are
# inclusive original f32 center +/-5.0001. Nonfinite/missing positions are
# unavailable, not fabricated outside/hidden positions.
static func contains_native_xy(center: Variant, position: Variant) -> Dictionary:
	var result := {"available": false, "contains": null, "minimum_native_xy": null, "maximum_native_xy": null, "reason": "native-xy-unavailable"}
	if not center is Array or center.size() < 2 or not position is Array or position.size() < 2: return result
	var c: Array = []
	var p: Array = []
	for axis in 2:
		for value in [center[axis], position[axis]]:
			if not (value is int or value is float) or not is_finite(float(value)): return result
		c.append(_f32(float(center[axis])))
		p.append(_f32(float(position[axis])))
		if not is_finite(c[axis]) or not is_finite(p[axis]): return result
	var half := _f32(5.0001)
	var minimum: Array = [_f32(c[0] - half), _f32(c[1] - half)]
	var maximum: Array = [_f32(c[0] + half), _f32(c[1] + half)]
	return {"available": true, "contains": p[0] >= minimum[0] and p[0] <= maximum[0] and p[1] >= minimum[1] and p[1] <= maximum[1], "minimum_native_xy": minimum, "maximum_native_xy": maximum, "reason": "native-inclusive-xy"}
