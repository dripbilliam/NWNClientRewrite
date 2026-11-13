extends RefCounted
# Ordinary PartTriMesh::HitCheckGeom905b0 first calls BoxIntersect22b400
# with its authored model bounds. This finite gate is separate from the
# existing geometry's conservative vertex bounds and from AABB tree policy.
const Box=preload("res://tools/native_parity/doors/native_box_hit.gd")

static func unavailable(reason: String) -> Dictionary:
	return {"available":false,"reason":reason}

static func vector(value: Variant) -> Variant:
	if not (value is Array or value is PackedFloat32Array) or value.size()!=3:return null
	for component in value:
		if not (component is int or component is float) or not is_finite(float(component)):return null
	var result:=Vector3(value[0],value[1],value[2])
	return result if result.is_finite() else null

static func admit(source: Dictionary,start: Array,end: Array) -> Dictionary:
	if not source.get("node_is_aabb") is bool:return unavailable("Native support Part subtype unavailable")
	if source.get("native_tilefade_available")!=true or not source.get("native_tilefade") is int:return unavailable("Native static support tilefade provenance unavailable")
	# SpawnTile::ProcessStaticParts removes these two lists before synchronous
	# SceneBSPAddTileData. Drawing/fading them does not make them support Parts.
	if int(source.native_tilefade) in [2,4]:return {"available":true,"admit":false,"route":"static-tilefade-excluded"}
	# This successor does not pretend that the ordinary mesh's box rule is an
	# AABB-tree rule. Its independently proven mask path remains unchanged.
	if source.node_is_aabb:return {"available":true,"admit":true,"route":"aabb-existing"}
	if source.get("native_bounds_available")!=true or source.get("native_bounds_valid")!=true:return unavailable("Authored ordinary support bounds unavailable")
	var bounds: Variant=source.get("native_bounds")
	if not bounds is Dictionary:return unavailable("Malformed authored ordinary support bounds")
	var low: Variant=vector(bounds.get("min"));var high: Variant=vector(bounds.get("max"))
	var a: Variant=vector(start);var b: Variant=vector(end)
	if low==null or high==null or a==null or b==null:return unavailable("Nonfinite or malformed authored support box input")
	var result: Dictionary=Box.hit(a,b,low,high)
	if not result.available:return result
	# Four-argument BoxIntersect never writes the ray endpoint. Its return code
	# alone gates the unchanged original face walk (inside -1 is admitted).
	return {"available":true,"admit":int(result.face)!=0,"route":"ordinary-authored-box","face":int(result.face)}
