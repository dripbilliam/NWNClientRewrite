extends RefCounted
# Original CGuiInGameFloatyText972750/972840. This is independent of ordinary
# popup replacement and of legacy combat-digit controls. The existing576-row
# unchanged-original frame corpus is the arithmetic/call-order authority.
const F=preload("res://systems/native_render/particle_math.gd")
const GuiProjection=preload("res://systems/native_data/gui_projection.gd")
const DURATION=1.5
const DEPTH=-5.1
static func frame(remaining: float,delta: float,duration: float=DURATION) -> Dictionary:
	if not is_finite(remaining) or not is_finite(delta) or delta<0 or not is_finite(duration):return {"ready":false,"reason":"Native floaty frame values are unavailable."}
	remaining=F.f(remaining);delta=F.f(delta);duration=F.f(duration)
	# Native destroys BEFORE any lookup, color or position work at >= boundary.
	if not delta<remaining:return {"ready":true,"active":false,"destroy":true,"remaining":remaining}
	var height:=F.f(F.f(F.f(duration-remaining)*F.f(0.5))+F.f(2.0))
	var alpha:=F.f(1.0) if remaining>=F.f(0.5) else F.f(remaining+remaining)
	return {"ready":true,"active":true,"destroy":false,"height":height,"alpha":alpha,"remaining":F.f(remaining-delta),"depth":F.f(DEPTH)}
static func native_screen(point: Vector2) -> Vector3:
	# Source camera/GUI point has +Y up. Integer conversion truncates toward0.
	return Vector3(F.cvtt(F.f(point.x+F.f(0.5))),F.cvtt(F.f(point.y+F.f(0.5))),F.f(DEPTH))
static func screen_down(point: Vector2,viewport_height: float) -> Dictionary:
	var projected:=GuiProjection.screen_down(point,viewport_height)
	return {"ready":true,"point":projected.screen,"depth":F.f(DEPTH)} if projected.get("ready",false) else projected
