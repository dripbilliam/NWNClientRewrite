extends RefCounted
# Direct source conversion of src/native_projectile_math.js finite acosf and
# the two original CRT logf CPU dispatches used for the speed bucket.
const NativeLog=preload("res://systems/native_data/native_log.gd")

static func f32(number: float) -> float:
	return NativeLog.f32(number)

static func native_acosf(input: float) -> float:
	var x:=f32(input)
	var magnitude:=absf(x)
	var exponent:=(NativeLog.raw(magnitude) >> 23) & 255
	if not is_finite(x) or magnitude>1.0:
		push_error("Native acosf exceptional branch is unavailable")
		return NAN
	if exponent<0x65:return f32(PI/2.0)
	if x==1.0:return 0.0
	if x==-1.0:return f32(PI)
	var z:=f32(magnitude*magnitude) if exponent<0x7e else f32(f32(1.0-magnitude)*0.5)
	var root:=magnitude if exponent<0x7e else f32(sqrt(z))
	var r:=f32(f32(-0.013381929136812687)-f32(z*f32(0.003961374517530203)))
	r=f32(f32(r*z)-f32(0.05652986839413643))
	r=f32(f32(r*z)+f32(0.18416160345077515))
	r=f32(f32(r*z)/f32(f32(1.1049696207046509)-f32(z*f32(0.8364112973213196))))
	if exponent<0x7e:return f32(PI/2.0-(x-(6.123233995736766e-17-f32(r*x))))
	if x<0.0:return f32(PI-2.0*((f32(r*root)-6.123233995736766e-17)+root))
	var split:=NativeLog.value(NativeLog.raw(root)&0xffff0000)
	var correction:=f32(f32(z-f32(split*split))/f32(split+root))
	return f32(f32(f32(f32(root+root)*r)+f32(correction+correction))+f32(split*2.0))

static func native_positive_logf(input: float,dispatch: int) -> Dictionary:
	var x:=f32(input)
	if not (x>0.0) or not is_finite(x) or dispatch not in [0,1]:return {"error":"Native positive logf input/profile is unavailable"}
	var values: Dictionary=NativeLog.branches(x)
	return values if values.has("error") else {"value":values.get("values")[dispatch]}

static func speed_bucket(log_value: float) -> int:
	var scaled:=f32(log_value*5.0)
	var integer:=int(scaled) if is_finite(scaled) and scaled>=-2147483648.0 and scaled<2147483648.0 else -2147483648
	var word:=(absi(integer)+1)&0xffffffff
	return word-0x100000000 if word>=0x80000000 else word

static func speed_range(distance: float) -> int:
	var sse: Dictionary=native_positive_logf(distance,0)
	var fma: Dictionary=native_positive_logf(distance,1)
	if sse.has("error") or fma.has("error"):
		push_error(str(sse.get("error",fma.get("error","Native projectile logf is unavailable"))))
		return -1
	var sse_bucket:=speed_bucket(float(sse.value))
	var fma_bucket:=speed_bucket(float(fma.value))
	if sse_bucket!=fma_bucket:
		push_error("Native projectile logf CPU dispatch changes the speed bound")
		return -1
	return sse_bucket
