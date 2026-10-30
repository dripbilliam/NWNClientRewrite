extends RefCounted
# Original854740: poison flag+158, disease flag+15c. Creature781e80's
# party block sends disease first (field8B4), then poison (field8B0).
const F=preload("res://systems/native_render/particle_math.gd")
const CLIPS=["percentage","poison","disease","diseasepoison"]
static func flag(value: Variant) -> bool:
	return value if value is bool else value!=0 if value is int or value is float else false
static func mode(poison: Variant,disease: Variant) -> String:
	return "diseasepoison" if flag(poison) and flag(disease) else "poison" if flag(poison) else "disease" if flag(disease) else "percentage"
static func from_party(party: Dictionary) -> String: return mode(party.get("field8B0",0),party.get("field8B4",0))
static func sample(percent: float,clip: String="percentage") -> Dictionary:
	if not is_finite(percent) or not clip in CLIPS: return {"error":"Invalid original health animation state"}
	var value: float=clampf(F.f(percent),0,100)
	return {"error":"","clip":clip,"percent":value,"time":F.f(value/30.0)}
