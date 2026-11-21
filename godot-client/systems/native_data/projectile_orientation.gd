extends RefCounted
# Original projectile9ddda0/AI983860: Pitch/Yaw then YawPitchRoll. Finite
# CRT float32 branches from NativeMath; no engine look_at substitute.
const M=preload("res://systems/native_render/particle_math.gd")
const NativeMath=preload("res://systems/native_data/native_math.gd")
static func negative(value: float) -> bool:
	return NativeMath._negative(value)
static func atanf(value: float) -> float:
	return NativeMath.native_atanf(value)
static func atan2f(y: float,x: float) -> float:
	return NativeMath.native_atan2f(y,x)
static func trig(value: float,cosine: bool) -> float:
	return NativeMath.native_cosf(value) if cosine else NativeMath.native_sinf(value)
static func impact(vector: Array) -> Array:
	var v:=M.values(vector); var yaw:=M.f(atan2f(M.f(-v[0]),v[1])*M.f(57.295776)) if v[0]!=0 or v[1]!=0 else 0.0
	var pitch:=M.f(atan2f(v[2],M.f(sqrt(M.f(M.f(v[1]*v[1])+M.f(v[0]*v[0])))))*M.f(57.295776)); var q: Array=[1.0,0.0,0.0,0.0]
	if yaw!=0:
		var angle:=M.f(M.f(yaw*M.f(0.017453292))*0.5); var s:=trig(angle,false); q=[trig(angle,true),M.f(0*s),M.f(0*s),s]
	if pitch!=0:
		var angle:=M.f(M.f(pitch*M.f(0.017453292))*0.5); var s:=trig(angle,false); q=M.multiply(q,[trig(angle,true),s,M.f(0*s),M.f(0*s)])
	return q
static func model(vector: Array) -> Variant:
	var v:=M.values(vector); var length:=M.f(sqrt(M.f(M.f(M.f(v[0]*v[0])+M.f(v[1]*v[1]))+M.f(v[2]*v[2]))))
	return null if length<=M.f(0.0001) else impact(M.normalize(v))
