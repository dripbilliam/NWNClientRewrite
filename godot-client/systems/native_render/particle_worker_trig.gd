extends RefCounted
# The same finite CRT branches used by NativeMath, without its shared
# last_error slot. Several immutable particle snapshots can evaluate at once.
const M=preload("res://systems/native_render/particle_math.gd")
const NativeMath=preload("res://systems/native_data/native_math.gd")
static func trig(value: float,cosine: bool) -> float:
	value=M.f(value)
	if not is_finite(value) or absf(value)>=500000.0: return NAN
	var sse: float=NativeMath._trig_branch(value,cosine,false)
	var fused: float=NativeMath._trig_branch(value,cosine,true)
	if not is_finite(sse) or not is_finite(fused) or NativeMath._bits32(sse)!=NativeMath._bits32(fused): return NAN
	return sse
static func sine(value: float) -> float: return trig(value,false)
static func cosine(value: float) -> float: return trig(value,true)
