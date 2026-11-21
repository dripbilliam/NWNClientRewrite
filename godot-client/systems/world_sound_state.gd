extends RefCounted
const GffText=preload("res://systems/native_data/native_gff_text.gd")
static func f(v: float) -> float:return PackedFloat32Array([v])[0]
static func listener(player: Array,camera: Array,q: Array) -> Dictionary:
	var p := player.map(func(v):return f(v));var c := camera.map(func(v):return f(v));p[2] = f(p[2]+f(1.8))
	var position: Array = [0,1,2].map(func(i):return f(p[i]+f(f(c[i]-p[i])*f(1.0/6.0))))
	var w := f(q[0]);var x := f(q[1]);var y := f(q[2]);var z := f(q[3])
	return {"position":position,"forward":[-f(2*f(f(z*x)+f(y*w))),-f(2*f(f(z*y)-f(x*w))),-f(1-f(2*f(f(y*y)+f(x*x))))],"up":[f(2*f(f(y*x)-f(z*w))),f(1-f(2*f(f(z*z)+f(x*x)))),f(2*f(f(x*w)+f(z*y)))]}
static func profile() -> Dictionary:return {"positional":false,"loop":false,"priority":21,"referenceDistance":1.0,"maxDistance":20.0,"volume":127}
static func resource_ref_result(text: String) -> Dictionary:
	# CResRef(CExoString) copies no more than sixteen original Western bytes,
	# stopping at NUL. Lookup may lowercase later; the cue keeps authored case.
	var encoded: Dictionary=GffText.encode(text)
	if encoded.has("error"):return {"resRef":"","error":str(encoded.error)}
	var bytes: PackedByteArray=encoded.bytes
	var end: int=bytes.find(0)
	var count: int=mini(16,end if end>=0 else bytes.size())
	return {"resRef":GffText.decode(bytes.slice(0,count)),"error":""}
static func resource_ref(text: String) -> String:
	return str(resource_ref_result(text).resRef)
static func is_native_audio_resource_ref(value: String) -> bool:
	if value.is_empty() or "\\" in value or "/" in value or ":" in value or String.chr(0) in value:return false
	var result: Dictionary=resource_ref_result(value)
	return str(result.error).is_empty() and str(result.resRef)==value
static func one_shot_cue(options: Dictionary) -> Dictionary:
	var ref: Dictionary=resource_ref_result(str(options.get("resRef","")))
	if not str(ref.error).is_empty():return {"error":str(ref.error)}
	if str(ref.resRef).is_empty():return {}
	var point: Variant=options.get("position")
	if point!=null and (not point is Array or point.size()!=3 or not point.all(func(v):return (v is int or v is float) and is_finite(float(v)))):
		return {"error":"Native script sound source position is invalid"}
	var height: Variant=options.get("height",0.0)
	var priority: Variant=options.get("priority",8)
	var volume: Variant=options.get("volume",0)
	var delay: Variant=options.get("delay",0)
	if not (height is int or height is float) or not is_finite(float(height)) or not priority is int or not volume is int or not delay is int or int(delay)<0 or int(delay)>0xffffffff:
		return {"error":"Native one-shot sound arguments are unavailable"}
	var profile: Dictionary={"positional":point!=null,"priority":int(priority)&255,"volume":(int(volume)&255) if (int(volume)&255)!=0 else 127,"referenceDistance":1,"maxDistance":20,"rolloff":1,"monoOnly":point!=null,"fixedPosition":true}
	if int(delay)!=0: profile.delay=int(delay)
	return {"resRef":str(ref.resRef),"position":position(point,float(height)) if point!=null else null,"channel":str(options.get("channel","effect")),"nativeSource":profile,"error":""}
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
