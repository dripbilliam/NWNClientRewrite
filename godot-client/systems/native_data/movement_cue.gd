extends RefCounted
# Original creature PlayAnimation 0x1407fc7d0: type6 branch
# 0x1407fcb2d..0x1407fcb71 fits one clip to the WORD correction timer.
static func f(value: float) -> float: return Vector3(value,0,0).x
static func build(request: Dictionary,clip_seconds: float,animation_speed: float=1.0) -> Dictionary:
	var length:=f(f(clip_seconds)*1000.0)
	if not is_finite(length) or length<0 or not is_finite(animation_speed): return {"error":"Original movement cue parameters are unavailable"}
	if int(request.get("type",0))==6:
		var duration:=int(request.get("duration",0))&65535
		if duration==0: return {"error":"Original correction duration is zero"}
		return {"animation":int(request.animation),"duration":duration,"speed":f(length/f(float(duration))) if length>0 else 1.0,"record":null,"delay":0}
	return {"animation":int(request.animation),"duration":int(length if animation_speed==0 else f(length/absf(f(animation_speed))))&0xffffffff,"speed":f(animation_speed),"record":null,"delay":0}
