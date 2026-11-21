extends RefCounted
# Shared native CRT float32 dispatch for original particle callers.
const NativeMath=preload("res://systems/native_data/native_math.gd")
static func trig(value: float,cosine: bool)->float:
	return NativeMath.native_cosf(value) if cosine else NativeMath.native_sinf(value)
static func cosine(value: float)->float:return trig(value,true)
static func sine(value: float)->float:return trig(value,false)
