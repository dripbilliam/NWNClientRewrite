extends RefCounted
# Compiled arithmetic. The scene/provider owner remains native GD.
# No emitter state is retained across calls by the library.
const Vertices=preload("res://systems/native_render/particle_vertices.gd")
const Schedule=preload("res://systems/native_render/particle_schedule.gd")
const M=preload("res://systems/native_render/particle_math.gd")
static var extension: Resource
const OPERATIONS={"check_life":0,"animate":1,"fountain":2,"explosion":3,"single":4,"standard":5,"initialize":6,"create":7,"randomize_frame":8,"random_position":9,"animate_fountain":10,"animate_explosion":11,"animate_single":12,"parameters":13}
static func fused_enabled() -> bool: return not OS.get_cmdline_user_args().has("--particle-dispatch=composed")
static func streams_enabled() -> bool: return not OS.get_cmdline_user_args().has("--particle-streams=legacy")
static func enabled() -> bool:
	var args:=OS.get_cmdline_user_args()
	if args.has("--particle-kernel=gd"): return false
	if args.has("--particle-kernel=compiled"): return true
	var choice:=OS.get_environment("NWN_PARTICLE_KERNEL")
	return choice=="compiled" or choice!="gd" and OS.get_name()=="Windows"
static func available() -> bool:
	if ClassDB.class_exists("NwnParticleKernel"): return true
	extension=load("res://native/particle_kernel.gdextension")
	return extension!=null and ClassDB.class_exists("NwnParticleKernel")
static func build(e: Dictionary,p: Dictionary,atlas_prepared: bool=false) -> Dictionary:
	if not available(): return {"error":"Compiled native particle kernel is unavailable"}
	if p.has("sineFloat") or p.has("cosineFloat"): return {"error":"Compiled particle kernel requires the original native CRT arithmetic provider"}
	# Original providers are called only after original fade/lifetime rejection,
	# in the same source/camera/tint order as the data-level GD implementation.
	if Vertices.draw_count(e)==0: return {}
	var input:={"factor":M.f(Schedule.invoke(p,"sourceFactor",[e.source50])) if e.source50!=null else 1.0,"camera":M.values(Schedule.invoke(p,"cameraQuaternion")),"tint":M.values(Schedule.invoke(p,"lightColor",[e.position1e0.duplicate()])) if (int(e.flags)&8)!=0 else [1.0,1.0,1.0]}
	return ClassDB.class_call_static("NwnParticleKernel","vertices",e,input,atlas_prepared)
static func simulate(operation: String,e: Dictionary,delta: float,p: Dictionary,particle: Dictionary={},factor: float=1.0) -> Dictionary:
	if not available(): return {"error":"Compiled native particle kernel is unavailable"}
	if not OPERATIONS.has(operation): return {"error":"Unknown compiled native particle operation: "+operation}
	return ClassDB.class_call_static("NwnParticleKernel","simulate",OPERATIONS[operation],e,delta,p,particle,factor)
static func build_streams(e: Dictionary,p: Dictionary,capacity: int,atlas_prepared: bool=false) -> Dictionary:
	if not available(): return {"error":"Compiled native particle kernel is unavailable"}
	if p.has("sineFloat") or p.has("cosineFloat"): return {"error":"Compiled particle kernel requires the original native CRT arithmetic provider"}
	var input: Dictionary={}
	if Vertices.draw_count(e)>0:
		input={"factor":M.f(Schedule.invoke(p,"sourceFactor",[e.source50])) if e.source50!=null else 1.0,"camera":M.values(Schedule.invoke(p,"cameraQuaternion")),"tint":M.values(Schedule.invoke(p,"lightColor",[e.position1e0.duplicate()])) if (int(e.flags)&8)!=0 else [1.0,1.0,1.0]}
	return ClassDB.class_call_static("NwnParticleKernel","streams",e,input,atlas_prepared,capacity)
