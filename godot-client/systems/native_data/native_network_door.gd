extends RefCounted
# network_door.js: replicated animation WORD to client door click BYTE.
static func state(animation: Variant) -> Variant:
	if animation is int or animation is float:
		if not is_finite(float(animation)) or floor(float(animation))!=float(animation):return null
		return {22:0,50:1,51:2,72:3}.get(int(animation),null)
	if animation is String:return {"22":0,"50":1,"51":2,"72":3}.get(animation,null)
	return null

static func apply_open_state(previous: Variant,animation: Variant,creation: bool) -> Variant:
	var next:Variant=state(animation)
	return next if next!=null and (creation or next!=3) else previous

static func click_state(object: Dictionary) -> Variant:
	var replicated:Variant=object.get("replicated")
	if not replicated is Dictionary:return null
	var current:Variant=replicated.get("doorOpenState")
	return current if current!=null else state(replicated.get("animation"))
