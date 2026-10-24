extends RefCounted

var triangles: Array = []
var cells: Dictionary = {}
var overflow: Array = []
var fallback := false

func configure(source: Array) -> void:
	triangles = source
	cells.clear()
	overflow.clear()
	fallback = false
	var references := 0
	for index in source.size():
		var t: Array = source[index]
		var a: Array = t[0]
		var b: Array = t[1]
		var c: Array = t[2]
		var min_x := minf(a[0], minf(b[0], c[0]))
		var max_x := maxf(a[0], maxf(b[0], c[0]))
		var min_z := minf(a[2], minf(b[2], c[2]))
		var max_z := maxf(a[2], maxf(b[2], c[2]))
		var extent := maxf(max_x - min_x, max_z - min_z)
		var magnitude := maxf(maxf(absf(min_x), absf(max_x)), maxf(absf(min_z), absf(max_z)))
		var u: float = (b[2] - c[2]) * (a[0] - c[0])
		var v: float = (c[0] - b[0]) * (a[2] - c[2])
		var denominator := u + v
		if absf(denominator) < 1e-8:
			continue
		if magnitude > 1e8 or absf(denominator) < maxf(maxf(absf(u), absf(v)), extent * extent) * 1e-8:
			overflow.append(index)
			continue
		var margin := 3e-5 * extent + 64 * 2.220446049250313e-16 * maxf(1, magnitude)
		var left := int(floor((min_x - margin) / 10))
		var right := int(floor((max_x + margin) / 10))
		var bottom := int(floor((min_z - margin) / 10))
		var top := int(floor((max_z + margin) / 10))
		var count := (right - left + 1) * (top - bottom + 1)
		if count > 4096:
			overflow.append(index)
			continue
		if references + count > 1000000:
			fallback = true
			break
		for x in range(left, right + 1):
			for z in range(bottom, top + 1):
				var key := Vector2i(x, z)
				if not cells.has(key):
					cells[key] = []
				cells[key].append(index)
				references += 1

func height(point: Vector3, previous: float) -> float:
	var candidates: Array
	if fallback or absf(point.x) > 1e8 or absf(point.y) > 1e8:
		candidates = range(triangles.size())
	else:
		candidates = cells.get(Vector2i(int(floor(point.x / 10)), int(floor(-point.y / 10))), []).duplicate()
		candidates.append_array(overflow)
		candidates.sort() # Preserve original tie order across indexed/overflow faces.
	var best := INF
	var result := previous
	for index in candidates:
		var t: Array = triangles[index]
		var a: Array = t[0]
		var b: Array = t[1]
		var c: Array = t[2]
		var denominator: float = (b[2] - c[2]) * (a[0] - c[0]) + (c[0] - b[0]) * (a[2] - c[2])
		if absf(denominator) < 1e-8:
			continue
		var wa: float = ((b[2] - c[2]) * (point.x - c[0]) + (c[0] - b[0]) * (-point.y - c[2])) / denominator
		var wb: float = ((c[2] - a[2]) * (point.x - c[0]) + (a[0] - c[0]) * (-point.y - c[2])) / denominator
		var wc := 1 - wa - wb
		if minf(wa, minf(wb, wc)) < -1e-5:
			continue
		var y: float = wa * a[1] + wb * b[1] + wc * c[1]
		var distance := absf(y - previous)
		if distance < best:
			result = y
			best = distance
	return result
