extends Resource
# Immutable original collision faces, distinct from optimized GPU draw lists.
const Polygon=preload("res://systems/native_data/polygon_hit.gd")
const Kernel=preload("res://systems/native_render/particle_kernel.gd")
var native_geometry: RefCounted
var native_attempted:=false
# Support-only immutable view. Never replace the canonical masked owner.
var native_support_geometry: RefCounted
var native_support_attempted:=false
var native_support_preparations:=0
var native_support_reason:=""
@export var vertices:=PackedFloat32Array()
@export var indices:=PackedInt32Array()
@export var planes:=PackedFloat32Array()
@export var surface_types:=PackedInt32Array()
@export var bounds:=AABB()
func configure(data: Dictionary,prepared: Dictionary={}) -> void:
	native_geometry=null; native_attempted=false; bounds=AABB()
	native_support_geometry=null; native_support_attempted=false
	native_support_preparations=0; native_support_reason=""
	vertices=data.vertices; indices=data.get("collision_indices",data.indices); planes=data.get("native_planes",PackedFloat32Array()); surface_types=data.get("native_surface_types",PackedInt32Array())
	if not prepared.is_empty(): bounds=prepared.source_bounds; planes=prepared.planes; return
	var has_bounds:=false
	for i in range(0,vertices.size(),3):
		var p:=Vector3(vertices[i],vertices[i+1],vertices[i+2]); bounds=bounds.expand(p) if has_bounds else AABB(p,Vector3.ZERO); has_bounds=true
	# Conservative rejection only: transformed f32 coordinates must reach the
	# original polygon predicate at grazing edges. Do not add a hit epsilon.
	bounds=bounds.grow(maxf(1.0,maxf(bounds.position.abs().length(),bounds.end.abs().length()))*0.000003814697265625)
	if planes.is_empty():
		for at in range(0,indices.size(),3):
			var p:=Polygon.plane(face(at)); planes.append_array(PackedFloat32Array([p.normal[0],p.normal[1],p.normal[2],p.constant]))
func face(at: int) -> Array:
	var output: Array=[]
	for corner in 3:
		var i:=int(indices[at+corner])*3; output.append([vertices[i],vertices[i+1],vertices[i+2]])
	return output
func prepare_native() -> RefCounted:
	if not native_attempted:
		native_attempted=true
		if Kernel.enabled() and not OS.get_cmdline_user_args().has("--scene-geometry=gd") and Kernel.available():
			native_geometry=ClassDB.instantiate("NwnSceneGeometry")
			var setup: Variant=native_geometry.call("dispatch",0,{"vertices":vertices,"indices":indices,"planes":planes,"types":surface_types})
			if setup is Dictionary and setup.has("error"): push_error(str(setup.error)); native_geometry=null
	return native_geometry
func prepare_native_unmasked_support() -> RefCounted:
	# Cold, per-configuration preparation; original arrays/materials stay intact.
	if not native_support_attempted:
		native_support_attempted=true
		native_support_reason="Compiled unmasked support geometry unavailable"
		if Kernel.enabled() and not OS.get_cmdline_user_args().has("--scene-geometry=gd") and Kernel.available() and ClassDB.class_exists("NwnSceneGeometry"):
			native_support_geometry=ClassDB.instantiate("NwnSceneGeometry")
			native_support_preparations+=1
			var setup: Variant=native_support_geometry.call("dispatch",0,{"vertices":vertices,"indices":indices,"planes":planes,"types":PackedInt32Array()})
			if setup is Dictionary and setup.has("error"):
				native_support_reason=str(setup.error)
				push_error(native_support_reason);native_support_geometry=null
			else:native_support_reason=""
	return native_support_geometry

func nearest(start: Array,end: Array,details: bool=false,compiled: bool=true) -> Variant:
	var low:=Vector3(minf(start[0],end[0]),minf(start[1],end[1]),minf(start[2],end[2])); var high:=Vector3(maxf(start[0],end[0]),maxf(start[1],end[1]),maxf(start[2],end[2]))
	if high.x<bounds.position.x or high.y<bounds.position.y or high.z<bounds.position.z or low.x>bounds.end.x or low.y>bounds.end.y or low.z>bounds.end.z: return null
	if compiled:
		prepare_native()
		if native_geometry!=null:
			var result: Variant=native_geometry.call("dispatch",1,{"start":start,"end":end})
			if result==null: return null
			if not result.has("error"): return result if details else result.position
			push_error(str(result.error)); return null
	var limit: Array=end; var best: Variant=null; var normal: Array=[]
	for at in range(0,indices.size(),3):
		var index:=at/3
		if index<surface_types.size() and (int(surface_types[index])&63)==30: continue
		var plane:=index*4; var result: Variant=Polygon.hit(face(at),[planes[plane],planes[plane+1],planes[plane+2]],planes[plane+3],start,limit)
		if result!=null:
			best=result; limit=result; normal=[planes[plane],planes[plane+1],planes[plane+2]]
	return {"position":best,"normal":normal} if details and best!=null else best
