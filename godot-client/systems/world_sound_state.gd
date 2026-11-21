extends RefCounted
static func f(v: float) -> float:return PackedFloat32Array([v])[0]
static func listener(player: Array,camera: Array,q: Array) -> Dictionary:
	var p := player.map(func(v):return f(v));var c := camera.map(func(v):return f(v));p[2] = f(p[2]+f(1.8))
	var position: Array = [0,1,2].map(func(i):return f(p[i]+f(f(c[i]-p[i])*f(1.0/6.0))))
	var w := f(q[0]);var x := f(q[1]);var y := f(q[2]);var z := f(q[3])
	return {"position":position,"forward":[-f(2*f(f(z*x)+f(y*w))),-f(2*f(f(z*y)-f(x*w))),-f(1-f(2*f(f(y*y)+f(x*x))))],"up":[f(2*f(f(y*x)-f(z*w))),f(1-f(2*f(f(z*z)+f(x*x)))),f(2*f(f(x*w)+f(z*y)))]}
static func profile() -> Dictionary:return {"positional":false,"loop":false,"priority":21,"referenceDistance":1.0,"maxDistance":20.0,"volume":127}
static func resource_ref(text: String) -> String:
	var result := ""
	for character in text:
		if character.unicode_at(0) == 0 or result.length() == 16:break
		result += character
	return result
static func position(point: Array,height: float) -> Array:return [f(point[0]),f(point[1]),f(f(point[2])+f(height))]
static func distance(a: Array,b: Array) -> float:
	var d: Array = [0,1,2].map(func(i):return f(a[i]-b[i]))
	return f(sqrt(f(f(f(d[0]*d[0])+f(d[1]*d[1]))+f(d[2]*d[2]))))
static func gain(profile_value: Dictionary,d: float) -> float:
	var volume := f(float(int(profile_value.volume)&255)/(255.0 if profile_value.positional else 127.0))
	if not profile_value.positional:return volume
	var lo := float(profile_value.referenceDistance);var hi := float(profile_value.maxDistance)
	var attenuation := 1.0 if hi == lo else 1.0-(clampf(d,lo,hi)-lo)/(hi-lo)
	return f(volume*attenuation)
static func delay_due(now: int,start: int,delay: int) -> bool:
	var elapsed := ((now&0xffffffff)-(start&0xffffffff)-(1 if (now&0xffffffff) < (start&0xffffffff) else 0))&0xffffffff
	return elapsed != 0 and elapsed >= (delay&0xffffffff)
