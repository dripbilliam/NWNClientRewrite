extends RefCounted

const PackedKeys = preload("res://systems/native_data/packed_animation_keys.gd")
const MAX_RESIDENT_ROWS := 4096

# Main-thread preparation only. Each destination owns its paths and tracks.
# Detached templates carry values alone and are never registered with a player.
static var entries: Dictionary = {}
static var order: Array[PackedByteArray] = []
static var resident_rows := 0

static func _packed_key(channel: Dictionary, track_type: int) -> PackedByteArray:
	if not channel.has("native_keys"):
		return PackedByteArray()
	var data: Dictionary = channel.native_keys
	var count := int(data.rows)
	var values: Variant = data.values
	if count < 3 or count > 256 or not (values is PackedFloat32Array or values is PackedFloat64Array):
		return PackedByteArray()
	var start := int(data.first)
	var stride := int(data.components) * (3 if data.bezier else 1)
	var end := start + count * stride
	if start < 0 or end > values.size():
		return PackedByteArray()
	var time_values: Variant = data.get("time_values", values)
	var time_start := 0 if data.has("time_values") else int(data.times)
	if not (time_values is PackedFloat32Array or time_values is PackedFloat64Array) or time_start < 0 or time_start + count > time_values.size():
		return PackedByteArray()
	# Match the complete normalization input, including precision, tangents,
	# and inherited position scale. The actual track binding is actor-owned.
	return var_to_bytes([
		track_type, channel.property, channel.source_property, float(channel.get("position_scale", 1.0)),
		int(data.components), bool(data.bezier), bool(data.get("ascii_axis_angle", false)),
		bool(data.get("axis_angle_converted", false)), values.slice(start, end),
		time_values.slice(time_start, time_start + count),
	])
static func _remember(key: PackedByteArray, value: Variant, count: int) -> void:
	while resident_rows + count > MAX_RESIDENT_ROWS:
		var expired: PackedByteArray = order.pop_front()
		resident_rows -= int(entries[expired][1])
		entries.erase(expired)
	entries[key] = [value, count]
	order.append(key)
	resident_rows += count

static func keys(channel: Dictionary) -> Array:
	var key := _packed_key(channel, -1)
	if key.is_empty():
		return PackedKeys.keys(channel)
	var saved: Variant = entries.get(key)
	if saved != null:
		return saved[0]
	var decoded := PackedKeys.keys(channel)
	decoded.make_read_only()
	_remember(key, decoded, int(channel.native_keys.rows))
	return decoded

static func append_transform(destination: Animation, path: NodePath, type: int, channel: Dictionary) -> void:
	var key := _packed_key(channel, type)
	if key.is_empty():
		var track := destination.add_track(type)
		destination.track_set_path(track, path)
		_insert_keys(destination, track, type, PackedKeys.keys(channel))
		return
	var saved: Variant = entries.get(key)
	var template: Animation
	if saved == null:
		template = Animation.new()
		template.add_track(type)
		_insert_keys(template, 0, type, PackedKeys.keys(channel))
		_remember(key, template, int(channel.native_keys.rows))
	else:
		template = saved[0]
	var track := destination.get_track_count()
	template.copy_track(0, destination)
	destination.track_set_path(track, path)

static func _insert_keys(animation: Animation, track: int, type: int, rows: Array) -> void:
	for row in rows:
		var value: Array = row.value
		var time := float(row.time)
		if type == Animation.TYPE_ROTATION_3D:
			animation.rotation_track_insert_key(track, time, Quaternion(float(value[0]), float(value[1]), float(value[2]), float(value[3])))
		else:
			var vector := Vector3(float(value[0]), float(value[1]), float(value[2]))
			if type == Animation.TYPE_POSITION_3D:
				animation.position_track_insert_key(track, time, vector)
			else:
				animation.scale_track_insert_key(track, time, vector)
