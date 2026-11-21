extends Node
const Timing=preload("res://systems/native_render/frame_profile.gd")
const Kernel=preload("res://systems/native_render/particle_kernel.gd")
const M=preload("res://systems/native_render/particle_math.gd")
var native_owner: RefCounted
var token:=0
var rng
var maximum_records:=32768
var closed:=false
var failure:=""
var last_noise_draws:=0
var point_count:=0
var area_signature: Array=[]
var parameters: Dictionary={}
var stats:={"added":0,"expired":0,"frames":0,"samples":0,"peak_records":0}
# Explicit diagnostics only; runtime never exports noise tables or points.
var state: Dictionary:
	get:
		if native_owner==null: return {"records":[],"capacity":0}
		var raw: Dictionary=native_owner.call("dispatch",4,{})
		return {"capacity":int(raw.capacity),"records":raw.records.map(func(row):return {"position":row.slice(0,3),"radius":row[3],"duration":row[4],"remaining":row[5],"strength":row[6]})}
func _ready() -> void:
	process_priority=10
	if not Kernel.available() or not ClassDB.class_exists("NwnWindManager"): failure="Native scene wind kernel is unavailable"; return
	var ancestor:=get_parent()
	while ancestor!=null:
		if ancestor.has_meta("native_particle_random"): rng=ancestor.get_meta("native_particle_random"); break
		ancestor=ancestor.get_parent()
	if rng==null: rng=preload("res://systems/native_render/particle_random.gd").new()
	native_owner=ClassDB.instantiate("NwnWindManager")
	var result: Dictionary=native_owner.call("dispatch",0,{"seed":rng.state,"deviation":0.0,"pitch":0.0,"cache":not OS.get_cmdline_user_args().has("--wind-cache=off")})
	if not accept(result): return
	token=int(native_owner.call("dispatch",6,{}))
func accept(value: Dictionary,sync_rng: bool=true) -> bool:
	if value.has("error"): failure=str(value.error); return false
	if sync_rng and value.has("seed"):
		rng.state=int(value.seed); rng.draws+=int(value.draws)-last_noise_draws; last_noise_draws=int(value.draws)
	return true
func set_area(fields: Dictionary) -> bool:
	if closed or native_owner==null: return false
	var signature: Array=[]
	for name in ["e4","e8","ec","f0","f4","f8","fc"]: signature.append(fields.get(name))
	if signature==area_signature: return true
	var power:=int(fields.get("e4",0)); var direction:=[0.7071067690849304,0.7071067690849304,0.0]
	var magnitude:=0.0; var yaw:=0.0; var pitch:=0.0
	match power:
		0: pass
		1: magnitude=1.0; yaw=100.0; pitch=3.0
		2: magnitude=2.0; yaw=150.0; pitch=5.0
		3:
			for name in ["e8","ec","f0","f4","f8","fc"]:
				if not fields.get(name) is float and not fields.get(name) is int: failure="Native custom area wind fields are unavailable"; return false
			direction=[M.f(fields.e8),M.f(fields.ec),M.f(fields.f0)]; magnitude=M.f(fields.f4); yaw=M.f(fields.f8); pitch=M.f(fields.fc)
		_: failure="Native area wind power is invalid"; return false
	# Original helper7e6870 formats renderer commands with %f before the
	# scene converts degrees to radians. Retain its six decimal boundary.
	var wind: Array=direction.map(func(value):return M.f(float("%.6f"%M.f(M.f(value)*magnitude))))
	parameters={"wind":wind,"deviation":M.f(M.f(float("%.6f"%yaw))*M.f(0.017453292)),"pitch":M.f(M.f(float("%.6f"%pitch))*M.f(0.017453292))}
	var result: Variant=native_owner.call("dispatch",5,parameters)
	if result is Dictionary and result.has("error"): failure=str(result.error); return false
	area_signature=signature; return true
func add_source(position: Array,radius: float,duration: float,strength: float) -> bool:
	if closed or native_owner==null: failure="Native point-wind scene is retired"; return false
	if point_count>=maximum_records: failure="Native point-wind source allocation exceeds explicit limit"; return false
	if not accept(native_owner.call("dispatch",3,{"position":position,"radius":radius,"duration":duration,"strength":strength}),false): return false
	point_count+=1; stats.added+=1; stats.peak_records=maxi(stats.peak_records,point_count); return true
func tick(delta: float) -> void:
	if closed or native_owner==null or not failure.is_empty(): return
	var result: Dictionary=native_owner.call("dispatch",1,{"seed":rng.state,"delta":delta})
	if not accept(result): return
	stats.expired+=point_count-int(result.points); point_count=int(result.points); stats.frames+=1
func point_vector(position: Array) -> Array:
	if closed or native_owner==null: return []
	stats.samples+=1
	return native_owner.call("dispatch",8,{"position":position})
func wind_vector(position: Array,factor: float) -> Array:
	if closed or native_owner==null: return []
	stats.samples+=1
	var result: Variant=native_owner.call("dispatch",2,{"position":position,"factor":factor})
	if result is Dictionary: failure=str(result.get("error","Native wind sampling failed")); return []
	return result
func _process(delta: float) -> void:
	var began:=Timing.begin(); tick(delta); Timing.finish("callback_wind",began)
func snapshot() -> Dictionary:
	var out:=stats.duplicate(); var native: Dictionary=native_owner.call("dispatch",7,{}) if native_owner!=null else {}
	out.merge({"records":point_count,"failure":failure,"closed":closed,"native_only":true,"parameters":parameters.duplicate(true),"native":native,"complete_wind_manager":false,"scope":"Native ambient/noise and point-source sampling/lifetime with cached cell rotations. Original startup seed/global frame ordering, grass and complete mixed-client parity remain separate."})
	return out
func close() -> void:
	if closed: return
	closed=true; set_process(false)
	if native_owner!=null: native_owner.call("dispatch",9,{})
	native_owner=null; token=0; point_count=0
func _exit_tree() -> void: close()
