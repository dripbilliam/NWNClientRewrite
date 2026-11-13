extends RefCounted
# Small detached identity guard. Never serializes Nodes/Resources/RIDs into a
# group key or substitutes a spatial cell for original physical TileData.
static func is_data(value: Variant,depth: int=0) -> bool:
	if depth>8:return false
	if value is Array:
		for item in value:
			if not is_data(item,depth+1):return false
		return true
	return value==null or value is bool or value is int or value is String or value is float and is_finite(value)
