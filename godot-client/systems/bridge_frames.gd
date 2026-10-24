extends RefCounted

const MAX_JSON := 1048576
const MAX_BINARY := 8388608
var pending := PackedByteArray()
var failure := ""

func reject(reason: String) -> Array:
	failure = reason
	pending.clear()
	return []

func feed(bytes: PackedByteArray) -> Array:
	if not failure.is_empty():
		return []
	pending.append_array(bytes)
	var frames: Array = []
	while not pending.is_empty():
		if pending[0] == 0x89:
			if pending.size() < 8:
				break
			if pending[1] != 0x50 or pending[2] != 0x41 or pending[3] != 0x52:
				return reject("Invalid binary bridge magic")
			var length := int(pending.decode_u32(4))
			if length < 4 or length > MAX_BINARY:
				return reject("Oversized binary bridge frame")
			if pending.size() < 8 + length:
				break
			var payload := pending.slice(8, 8 + length)
			pending = pending.slice(8 + length)
			var size := int(payload.decode_u32(0))
			if size < 2 or size > 65536 or size + 4 > payload.size():
				return reject("Invalid binary metadata length")
			var metadata: Variant = JSON.parse_string(payload.slice(4, 4 + size).get_string_from_utf8())
			if not metadata is Dictionary or metadata.get("kind") != "particle-stream" or not metadata.get("emitters") is Array or metadata.emitters.size() > 128:
				return reject("Invalid binary particle metadata")
			for key in ["connection", "areaId", "generation", "transferId", "epoch", "sequence"]:
				if not _integer(metadata.get(key)):
					return reject("Invalid binary particle scope")
			var offset := size + 4
			var streams: Array = []
			var ids := {}
			for row in metadata.emitters:
				if not row is Dictionary or not _integer(row.get("id")) or ids.has(int(row.id)) or not _integer(row.get("count")) or not _integer(row.get("capacity")):
					return reject("Invalid particle stream identity/count")
				ids[int(row.id)] = true
				var count := int(row.count)
				var capacity := int(row.capacity)
				if capacity > 196608 or count > capacity or count % 6 != 0 or capacity % 6 != 0 or not _integer(row.get("positionBytes")) or not _integer(row.get("attributeBytes")) or int(row.positionBytes) != capacity * 12 or int(row.attributeBytes) != capacity * 12 or offset + capacity * 24 > payload.size():
					return reject("Invalid particle stream boundaries")
				if count > 0 and not _bounds(row.get("bounds")):
					return reject("Invalid particle bounds")
				streams.append({"row": row, "positions": payload.slice(offset, offset + capacity * 12), "attributes": payload.slice(offset + capacity * 12, offset + capacity * 24)})
				offset += capacity * 24
			if offset != payload.size():
				return reject("Trailing particle stream bytes")
			metadata["streams"] = streams
			frames.append(metadata)
		else:
			var end := pending.find(10)
			if end < 0:
				if pending.size() > MAX_JSON:
					return reject("Oversized partial JSON bridge frame")
				break
			if end > MAX_JSON:
				return reject("Oversized JSON bridge frame")
			var value: Variant = JSON.parse_string(pending.slice(0, end).get_string_from_utf8())
			if not value is Dictionary:
				return reject("Invalid JSON bridge frame")
			if value.get("kind") == "particle-stream":
				return reject("Particle streams require binary framing")
			pending = pending.slice(end + 1)
			frames.append(value)
	return frames

func _integer(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= 0 and float(value) <= 9007199254740991.0 and float(value) == floor(float(value))

func _bounds(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	for key in ["min", "max"]:
		if not value.get(key) is Array or value[key].size() != 3:
			return false
		for scalar in value[key]:
			if not (scalar is float or scalar is int) or not is_finite(float(scalar)):
				return false
	return value.max[0] >= value.min[0] and value.max[1] >= value.min[1] and value.max[2] >= value.min[2]
