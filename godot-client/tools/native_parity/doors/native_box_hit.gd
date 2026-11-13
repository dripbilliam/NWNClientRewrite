extends RefCounted
# Source port of original BoxIntersect14022b7e0's finite ordered-box path.
# X/Y/Z face order and f32 interpolation are intentional. This is not a slab
# approximation or a Godot shape with an implicit minimum thickness. Original
# instruction comparison is still required before selection integration.
const M=preload("res://systems/native_render/particle_math.gd")

static func code(point: Vector3,low: Vector3,high: Vector3) -> int:
	var value:=0
	if point.x<low.x:value|=32
	elif point.x>high.x:value|=16
	if point.y<low.y:value|=8
	elif point.y>high.y:value|=4
	if point.z<low.z:value|=2
	elif point.z>high.z:value|=1
	return value

static func interpolate(start: float,end: float,t: float) -> float:
	return M.f(M.f(M.f(1.0-t)*start)+M.f(end*t))

static func hit(start: Vector3,end: Vector3,low: Vector3,high: Vector3) -> Dictionary:
	if not start.is_finite() or not end.is_finite() or not low.is_finite() or not high.is_finite() or low.x>high.x or low.y>high.y or low.z>high.z:
		return {"available":false,"reason":"Nonfinite or unordered native box input"}
	var first:=code(start,low,high)
	# Native leaves its caller's output untouched for both inside and miss.
	if first==0:return {"available":true,"face":-1,"written":false}
	if first&code(end,low,high):return {"available":true,"face":0,"written":false}
	if first&48:
		var plane:=low.x if first&32 else high.x
		var t:=M.f(M.f(plane-start.x)/M.f(end.x-start.x))
		var y:=interpolate(start.y,end.y,t)
		var z:=interpolate(start.z,end.z,t)
		if y>=low.y and y<=high.y and z>=low.z and z<=high.z:
			return {"available":true,"face":1 if first&32 else 2,"written":true,"point":Vector3(plane,y,z)}
	if first&12:
		var plane:=low.y if first&8 else high.y
		var t:=M.f(M.f(plane-start.y)/M.f(end.y-start.y))
		var x:=interpolate(start.x,end.x,t)
		var z:=interpolate(start.z,end.z,t)
		if x>=low.x and x<=high.x and z>=low.z and z<=high.z:
			return {"available":true,"face":3 if first&8 else 4,"written":true,"point":Vector3(x,plane,z)}
	if first&3:
		var plane:=low.z if first&2 else high.z
		var t:=M.f(M.f(plane-start.z)/M.f(end.z-start.z))
		var x:=interpolate(start.x,end.x,t)
		var y:=interpolate(start.y,end.y,t)
		if x>=low.x and x<=high.x and y>=low.y and y<=high.y:
			return {"available":true,"face":5 if first&2 else 6,"written":true,"point":Vector3(x,y,plane)}
	return {"available":true,"face":0,"written":false}
