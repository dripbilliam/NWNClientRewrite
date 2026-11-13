extends RefCounted
# Native Camera.MapToScreen(false) is GUI-up. Round in that coordinate system
# before converting to the Godot UI viewport's downwards Y. Translation by H
# must precede CVTT: -y alone differs offscreen and at half-pixel boundaries.
# This adapts the current Godot UI viewport; original GUI-scale remapping is a
# separate camera/viewport policy, not inferred from a text message.
const F=preload("res://systems/native_render/particle_math.gd")
static func screen_down(point: Vector2,height: float) -> Dictionary:
	if not point.is_finite() or not is_finite(height) or height<=0:return {"ready":false}
	var native_y:=F.f(F.f(height)-F.f(point.y))
	var x:=F.cvtt(F.f(F.f(point.x)+F.f(0.5)))
	var y:=F.cvtt(F.f(native_y+F.f(0.5)))
	return {"ready":true,"screen":Vector2(x,F.f(F.f(height)-F.f(float(y))))}
