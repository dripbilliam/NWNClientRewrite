extends RefCounted
# One native-gamma world owns fog publication. Old area callbacks cannot replace
# or clear their successor. Raw native fog remains separate from Godot's color
# properties, which must carry different values for its linear background path.
const F=preload("res://systems/area_environment_state.gd")
static var registered:=false
static var active_id:=0
static var active_owner: WeakRef
static var current: Array=[]
static var area_source:=false
static var publications:=0
static var failure:=""
static func ensure() -> void:
	if registered: return
	RenderingServer.global_shader_parameter_add("nwn_native_fog_color",RenderingServer.GLOBAL_VAR_TYPE_VEC3,Vector3.ZERO)
	RenderingServer.global_shader_parameter_add("nwn_native_fog_params",RenderingServer.GLOBAL_VAR_TYPE_VEC3,Vector3.ZERO)
	RenderingServer.global_shader_parameter_add("nwn_native_fog_range",RenderingServer.GLOBAL_VAR_TYPE_VEC2,Vector2.ZERO)
	registered=true
static func bind(owner: Node) -> void:
	ensure(); active_id=owner.get_instance_id(); active_owner=weakref(owner); current=[]; area_source=false; failure=""
	RenderingServer.global_shader_parameter_set("nwn_native_fog_color",Vector3.ZERO)
	RenderingServer.global_shader_parameter_set("nwn_native_fog_params",Vector3.ZERO)
	RenderingServer.global_shader_parameter_set("nwn_native_fog_range",Vector2.ZERO)
static func owns(owner: Node) -> bool:
	return is_instance_valid(owner) and active_id==owner.get_instance_id() and active_owner!=null and active_owner.get_ref()==owner
static func authoritative(owner: Node) -> bool: return owns(owner) and area_source
static func packet(owner: Node) -> Array: return current.duplicate() if owns(owner) else []
static func publish(owner: Node,color: Vector3,enabled: bool,begin: float,end: float,from_area: bool=true) -> bool:
	if not owns(owner): return false
	begin=F.f(begin); end=F.f(end)
	if not color.is_finite() or not is_finite(begin) or not is_finite(end) or (enabled and end<=begin):
		failure="Invalid native surface fog publication"; return false
	var inverse:=F.f(1.0/F.f(F.f(end)-F.f(begin))) if enabled else 0.0
	if not is_finite(inverse): failure="Invalid native surface fog reciprocal"; return false
	var next: Array=[F.f(color.x),F.f(color.y),F.f(color.z),0.0,F.f(begin),F.f(end),inverse,3.0 if enabled else 0.0]
	area_source=from_area; failure=""
	if next==current: return true
	current=next; publications+=1
	RenderingServer.global_shader_parameter_set("nwn_native_fog_color",Vector3(next[0],next[1],next[2]))
	RenderingServer.global_shader_parameter_set("nwn_native_fog_params",Vector3(1.0 if enabled else 0.0,next[4],inverse))
	RenderingServer.global_shader_parameter_set("nwn_native_fog_range",Vector2(next[4],next[5]))
	return true
static func publish_camera(owner: Node,packet_value: Array) -> void:
	if authoritative(owner) or not owns(owner) or packet_value.size()!=8: return
	publish(owner,Vector3(packet_value[0],packet_value[1],packet_value[2]),packet_value[7]!=0,packet_value[4],packet_value[5],false)
static func retire(owner: Node) -> void:
	if not owns(owner): return
	active_id=0; active_owner=null; current=[]; area_source=false
	RenderingServer.global_shader_parameter_set("nwn_native_fog_color",Vector3.ZERO)
	RenderingServer.global_shader_parameter_set("nwn_native_fog_params",Vector3.ZERO)
	RenderingServer.global_shader_parameter_set("nwn_native_fog_range",Vector2.ZERO)
static func snapshot() -> Dictionary:
	return {"owner":active_id,"area_source":area_source,"packet":current.duplicate(),"publications":publications,"failure":failure}
