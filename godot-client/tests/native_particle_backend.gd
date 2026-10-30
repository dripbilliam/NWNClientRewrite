extends RefCounted
# Test adapter only: run the same original-observation corpus against either
# native GD or compiled owners. Runtime scene nodes select their backend directly.
const GD=preload("res://systems/native_render/particle_schedule.gd")
const Init=preload("res://systems/native_render/particle_initialization.gd")
const Move=preload("res://systems/native_render/particle_movement.gd")
const Kernel=preload("res://systems/native_render/particle_kernel.gd")
static func compiled() -> bool: return Kernel.enabled()
static func apply(operation: String,e: Dictionary,delta: float,p: Dictionary,part: Dictionary={},factor: float=1.0) -> Dictionary:
	var out:=Kernel.simulate(operation,e,delta,p,part,factor)
	assert(not out.has("error"),str(out.get("error","")))
	return out
static func invoke(p: Dictionary,name: String,args: Array=[]) -> Variant: return GD.invoke(p,name,args)
static func check_life(e: Dictionary,delta: float,p: Dictionary) -> void:
	if compiled(): apply("check_life",e,delta,p)
	else: GD.check_life(e,delta,p)
static func animate(e: Dictionary,delta: float,p: Dictionary) -> void:
	if compiled(): apply("animate",e,delta,p)
	else: GD.animate(e,delta,p)
static func fountain(e: Dictionary,delta: float,p: Dictionary) -> void:
	if compiled(): apply("fountain",e,delta,p)
	else: GD.fountain(e,delta,p)
static func explosion(e: Dictionary,delta: float,p: Dictionary) -> void:
	if compiled(): apply("explosion",e,delta,p)
	else: GD.explosion(e,delta,p)
static func single(e: Dictionary,delta: float,p: Dictionary) -> void:
	if compiled(): apply("single",e,delta,p)
	else: GD.single(e,delta,p)
static func standard(e: Dictionary,delta: float,p: Dictionary) -> void:
	if compiled(): apply("standard",e,delta,p)
	else: Move.standard(e,delta,p)
static func create(e: Dictionary,delta: float,p: Dictionary) -> Dictionary:
	return apply("create",e,delta,p).get("value",{}) if compiled() else Init.create(e,delta,p)
static func initialize(part: Dictionary,e: Dictionary,delta: float,factor: float,p: Dictionary) -> void:
	if compiled(): apply("initialize",e,delta,p,part,factor)
	else: Init.initialize(part,e,delta,factor,p)
static func randomize_frame(e: Dictionary,part: Dictionary,p: Dictionary) -> void:
	if compiled(): apply("randomize_frame",e,0,p,part)
	else: Init.randomize_frame(e,part,p)
static func random_position(part: Dictionary,e: Dictionary,x_size: int,y_size: int,p: Dictionary) -> void:
	if compiled(): apply("random_position",e,x_size,p,part,y_size)
	else: Init.random_position(part,e,x_size,y_size,p)
