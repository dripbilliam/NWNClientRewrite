extends RefCounted
# Original CGuiSlider range/visible thumb arithmetic. Caller coordinate mapping
# is separate; these inputs are original range, visible range and hook length.
const Math=preload("res://systems/native_render/particle_math.gd")
static func thumb(range_units: int,visible: int,length: float) -> Dictionary:
	var clamped:=maxi(1,range_units); var total:=visible+clamped-1
	var ratio:=1.0 if total<1 else Math.f(Math.f(visible)/Math.f(total))
	var pixels:=maxf(Math.f(3.01),float(int(Math.f(Math.f(ratio*Math.f(length))+Math.f(0.5)))))
	return {"range":clamped,"pixels":pixels,"model_units":Math.f(pixels*Math.f(0.01)),"time":Math.f(Math.f(pixels-Math.f(3.0))/Math.f(30.0))}
