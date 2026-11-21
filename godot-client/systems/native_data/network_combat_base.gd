extends RefCounted
const RELEASE={17:250,18:251,19:252,20:253,61:261}
const LOCOMOTION=[2,3,4,5,6,7,8,24,25]
static func creature(animation: int,has_pending: bool,has_current: bool,queued: bool) -> Dictionary:
	if RELEASE.has(animation):return {"mode":"cast","base":int(RELEASE[animation])}
	if animation==9:return {"mode":"hold"}
	if animation in LOCOMOTION:return {"mode":"locomotion","base":animation}
	if has_pending and animation in [0,1]:return {"mode":"pending","base":animation}
	if has_current or queued:return {"mode":"defer","base":animation}
	return {"mode":"play","base":animation}
static func object_base(category: int,previous: int,animation: int) -> bool:
	return category==1 and previous!=animation
