extends RefCounted
# CalculateRadius140061710 and SphereAbovePlane14022e360. Data-level helpers
# retain original f32 grouping. The live adapter adds conservative particle/
# spawn/scale coverage and declines unknown targets/chunks/services.
const M=preload("res://systems/native_render/particle_math.gd")
const FIELDS=["mass","lifeexp","velocity","randvel","sizestart","sizeend","sizemid","sizestart_y","sizeend_y","sizemid_y"]
static var view_frame:=-1
static var view_camera:=0
static var view_transform:=Transform3D()
static var view_projection:=Projection()
static var view_planes: Array[Plane]=[]
static var native_packet: Dictionary={}
static var native_stamp:=0
static var native_frame:=-1
static var native_camera:=0
var signature: Array=[]
var cached_radius:=0.0
static func magnitude(v: Array) -> float:
	return M.f(sqrt(M.f(M.f(M.f(M.f(v[0])*M.f(v[0]))+M.f(M.f(v[1])*M.f(v[1])))+M.f(M.f(v[2])*M.f(v[2])))))
static func calculate(parameters: Dictionary,source_flags: int=0,wind: Array=[0.0,0.0,0.0],origin: Array=[0.0,0.0,0.0],target: Variant=null,chunks: Array=[]) -> Dictionary:
	if source_flags&1: return {"radius":1000.0,"acceleration":0.0}
	if target is Array: return {"radius":magnitude(M.subtract(target,origin)),"acceleration":0.0}
	var acceleration:=M.f(absf(M.f(float(parameters.get("mass",0.0)))*-9.81))
	var life:=M.f(float(parameters.get("lifeexp",0.0)))
	var travel:=M.f(M.f(M.f(M.f(float(parameters.get("velocity",0.0)))+M.f(float(parameters.get("randvel",0.0))))+magnitude(wind))*life)
	travel=M.f(travel+M.f(M.f(M.f(acceleration*0.5)*life)*life))
	var half_x:=M.f(maxf(maxf(M.f(float(parameters.get("sizestart",0.0))),M.f(float(parameters.get("sizeend",0.0)))),M.f(float(parameters.get("sizemid",0.0))))*0.5)
	var half_y:=M.f(maxf(maxf(M.f(float(parameters.get("sizestart_y",0.0))),M.f(float(parameters.get("sizeend_y",0.0)))),M.f(float(parameters.get("sizemid_y",0.0))))*0.5)
	if half_y<=0: half_y=half_x
	var radius:=M.f(M.f(sqrt(M.f(M.f(half_x*half_x)+M.f(half_y*half_y))))+travel)
	for chunk in chunks:
		# Null particle view terminates the original loop; null child skips it.
		if not chunk.get("view",true): break
		if chunk.get("child")==null: continue
		var child: Array=chunk.child
		radius=maxf(radius,M.f(magnitude(M.subtract(child.slice(0,3),origin))+M.f(child[3])))
	return {"radius":radius,"acceleration":acceleration}
static func above_plane(point: Array,radius: float,plane: Array) -> float:
	var distance:=M.f(M.f(M.f(point[0])*M.f(plane[0]))+M.f(plane[3]))
	distance=M.f(distance+M.f(M.f(point[1])*M.f(plane[1])))
	distance=M.f(distance+M.f(M.f(point[2])*M.f(plane[2])))
	return M.f(distance-M.f(radius))
func radius_for(parameters: Dictionary,source_flags: int,wind: Array=[0.0,0.0,0.0]) -> float:
	if source_flags&1: return 1000.0
	var next: Array=[source_flags]
	for name in FIELDS: next.append(parameters.get(name,0.0))
	next.append_array(wind)
	if next!=signature:
		signature=next; cached_radius=float(calculate(parameters,source_flags,wind).radius)
	return cached_radius
static func planes_for(camera: Camera3D) -> Array[Plane]:
	var frame:=Engine.get_process_frames(); var id:=camera.get_instance_id()
	var transform:=camera.get_camera_transform(); var projection:=camera.get_camera_projection()
	if frame!=view_frame or id!=view_camera or transform!=view_transform or projection!=view_projection:
		view_frame=frame; view_camera=id; view_transform=transform; view_projection=projection; view_planes=camera.get_frustum()
		native_packet.clear()
	return view_planes
static func native_view(camera: Camera3D,revalidate: bool=true) -> Dictionary:
	# Automatic emitters run after camera controllers. Match one camera/frustum
	# publication per render frame instead of rebuilding/querying the projection
	# for every emitter. Explicit/manual ticks retain same-frame revalidation.
	var frame:=Engine.get_process_frames(); var id:=camera.get_instance_id()
	if not revalidate and frame==native_frame and id==native_camera and not native_packet.is_empty(): return native_packet
	var planes:=planes_for(camera)
	if native_packet.is_empty():
		var packed:=PackedFloat32Array()
		for plane in planes: packed.append_array(PackedFloat32Array([plane.normal.x,plane.normal.y,plane.normal.z,plane.d]))
		var transform:=camera.global_transform; var q:=Quaternion(Vector3.RIGHT,PI/2)*transform.basis.orthonormalized().get_rotation_quaternion()
		native_stamp+=1; native_packet={"stamp":native_stamp,"planes":packed.to_byte_array(),"position":[transform.origin.x,-transform.origin.z,transform.origin.y],"camera":[q.w,q.x,q.y,q.z]}
	native_frame=frame; native_camera=id
	return native_packet
static func outside(camera: Camera3D,center: Vector3,radius: float) -> bool:
	if not center.is_finite() or not is_finite(radius) or radius<0: return false
	for plane in planes_for(camera):
		# Godot uses n.dot(p)-d. Native uses n.dot(p)+D. A small outward
		# margin prevents changing a boundary result through basis/rounding.
		if plane.distance_to(center)>radius+0.001: return true
	return false
