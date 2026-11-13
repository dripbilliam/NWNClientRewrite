extends RefCounted
# Support-only narrow phase. Ordinary PartTriMesh905b0 does not consult face
# materials; PartAABB90170 applies maskBFFFFFFF to (material &63). Never infer
# the original subtype from draw visibility, opacity, texture or node name.
const Polygon=preload("res://systems/native_data/polygon_hit.gd")
const Kernel=preload("res://systems/native_render/particle_kernel.gd")

static func unavailable(reason: String) -> Dictionary:
	return {"available":false,"reason":reason,"triangle_tests":0}

static func nearest(geometry,start: Array,end: Array,source: Dictionary) -> Dictionary:
	if not source.get("node_is_aabb") is bool: return unavailable("Native support Part subtype unavailable")
	if start.size()!=3 or end.size()!=3: return unavailable("Malformed support segment")
	for point in [start,end]:
		for value in point:
			if not (value is int or value is float) or not is_finite(float(value)): return unavailable("Nonfinite support segment")
	if geometry==null or not geometry.get("vertices") is PackedFloat32Array or not geometry.get("indices") is PackedInt32Array or not geometry.get("planes") is PackedFloat32Array:
		return unavailable("Original support face data unavailable")
	var indices: PackedInt32Array=geometry.indices
	var planes: PackedFloat32Array=geometry.planes
	var types: PackedInt32Array=geometry.surface_types
	if indices.size()%3!=0 or planes.size()!=indices.size()/3*4: return unavailable("Malformed original support face planes")
	var aabb: bool=source.node_is_aabb
	if aabb and types.size()!=indices.size()/3: return unavailable("Native AABB material provenance unavailable")
	var low:=Vector3(minf(start[0],end[0]),minf(start[1],end[1]),minf(start[2],end[2]))
	var high:=Vector3(maxf(start[0],end[0]),maxf(start[1],end[1]),maxf(start[2],end[2]))
	var bounds: AABB=geometry.bounds
	if high.x<bounds.position.x or high.y<bounds.position.y or high.z<bounds.position.z or low.x>bounds.end.x or low.y>bounds.end.y or low.z>bounds.end.z:
		return {"available":true,"hit":false,"triangle_tests":0,"route":"bounds"}
	# AABB retains its canonical fixed mask. Ordinary material-bearing Parts
	# use a distinct native owner with all original faces, including 30/94.
	# If that optional preparation is unavailable, keep the exact GD fallback.
	if not OS.get_cmdline_user_args().has("--scene-geometry=gd") and Kernel.enabled():
		var owner: RefCounted=null
		if aabb or types.is_empty():owner=geometry.prepare_native()
		elif geometry.has_method("prepare_native_unmasked_support"):owner=geometry.prepare_native_unmasked_support()
		if owner!=null:
			var hit: Variant=owner.call("dispatch",1,{"start":start,"end":end})
			if hit==null:return {"available":true,"hit":false,"triangle_tests":0,"route":"compiled-raw"}
			if not hit is Dictionary or hit.has("error"):return unavailable(str(hit.get("error","Malformed native support query")) if hit is Dictionary else "Malformed native support query")
			return {"available":true,"hit":true,"position":hit.position,"normal":hit.normal,"triangle_tests":0,"route":"compiled-raw"}
	var best: Variant=null; var limit: Array=end; var normal: Array=[]; var tested:=0
	for at in range(0,indices.size(),3):
		var face:=at/3
		if aabb and (int(types[face])&63)==30:continue
		var plane:=face*4; tested+=1
		var hit: Variant=Polygon.hit(geometry.face(at),[planes[plane],planes[plane+1],planes[plane+2]],planes[plane+3],start,limit)
		if hit!=null:best=hit;limit=hit;normal=[planes[plane],planes[plane+1],planes[plane+2]]
	return {"available":true,"hit":best!=null,"position":best,"normal":normal,"triangle_tests":tested,"route":"gd-aabb-mask" if aabb else "gd-unmasked-trimesh"}
