extends RefCounted
# Exact finite native area7daef0 tile-state query. Caller owns canonical tiles.
const Tiles = preload("res://systems/native_data/native_tile_visibility.gd")
static func _f32(value: float) -> float: return PackedFloat32Array([value])[0]
static func _tile(width: int, height: int, x: int, y: int) -> int:
	return y * width + x if x >= 0 and y >= 0 and x < width and y < height else -1
static func read(flags: Variant, width: Variant, height: Variant, states: Variant, native_position: Variant) -> Dictionary:
	var unavailable := {"available":false,"revealed":null,"tile_index":null,"neighbor_index":null,"reason":"native-tile-query-unavailable"}
	if not Tiles._integer(flags, -2147483648, 4294967295): return unavailable
	if (int(flags) & 3) == 0: return {"available":true,"revealed":true,"tile_index":null,"neighbor_index":null,"reason":"native-area-flag-bypass"}
	if not Tiles._integer(width,1,Tiles.MAX_TILES) or not Tiles._integer(height,1,Tiles.MAX_TILES) or width * height > Tiles.MAX_TILES: return unavailable
	if not states is Array or states.size() != int(width) * int(height) or not native_position is Array or native_position.size() < 2: return unavailable
	var point: Array = []
	for axis in 2:
		var value: Variant = native_position[axis]
		if not (value is int or value is float) or not is_finite(float(value)): return unavailable
		point.append(_f32(float(value)))
		if not is_finite(point[axis]): return unavailable
	var qx := _f32(point[0] / 10.0)
	var qy := _f32(point[1] / 10.0)
	# CVTTSS2SI overflow/NaN exceptional inputs are not invented as valid tiles.
	if qx < -2147483648.0 or qx >= 2147483648.0 or qy < -2147483648.0 or qy >= 2147483648.0: return unavailable
	var x := int(qx)
	var y := int(qy)
	var fx := _f32(point[0] - _f32(float(x) * 10.0))
	var fy := _f32(point[1] - _f32(float(y) * 10.0))
	var low := _f32(0.0001)
	var high := _f32(9.9999)
	var neighbor := -1
	# Original chooses at most ONE seam neighbor, X before Y.
	if fx <= low and x >= 1: neighbor = _tile(int(width),int(height),x - 1,y)
	elif fx >= high and x < int(width): neighbor = _tile(int(width),int(height),x + 1,y)
	elif fy <= low and y >= 1: neighbor = _tile(int(width),int(height),x,y - 1)
	elif fy >= high and y < int(height): neighbor = _tile(int(width),int(height),x,y + 1)
	var current := _tile(int(width),int(height),x,y)
	if current < 0: return {"available":true,"revealed":true,"tile_index":null,"neighbor_index":neighbor if neighbor >= 0 else null,"reason":"native-invalid-current-tile-bypass"}
	if not Tiles._integer(states[current],-2147483648,2147483647): return unavailable
	var revealed: bool = int(states[current]) != 0
	if not revealed and neighbor >= 0:
		if not Tiles._integer(states[neighbor],-2147483648,2147483647): return unavailable
		revealed = int(states[neighbor]) != 0
	return {"available":true,"revealed":revealed,"tile_index":current,"neighbor_index":neighbor if neighbor >= 0 else null,"reason":"native-current-and-one-seam-tile"}
