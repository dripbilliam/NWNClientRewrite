extends RefCounted
# Original CGuiMan1f55d0/1f5190/1f6b80/1f6fc0/1f6590. IDs are opaque GUI
# owners, not item IDs. The caller supplies the actual hit and modal decision.
const DEFAULT_USEC:=100000
var remaining:=DEFAULT_USEC
var delay:=DEFAULT_USEC
var saved:=DEFAULT_USEC
var active:=0
var point:=Vector2i(-1,-1)
var origin:=Vector2i(-1,-1)
static func signed32(value: int) -> int:
	var bits:=value&0xffffffff
	return bits-0x100000000 if bits>=0x80000000 else bits
func configure(usec: int) -> void:
	delay=signed32(usec); saved=delay
func events() -> Dictionary: return {"finish":0,"trigger":0,"reset":false}
func motion(hit: int,at: Vector2i) -> Dictionary:
	point=at; var result:=events(); var dx:=signed32(point.x-origin.x); var dy:=signed32(point.y-origin.y)
	if active==hit and signed32(signed32(dx*dx)+signed32(dy*dy))<=1024: return result
	origin=point
	if active!=0: result.finish=active; active=0
	remaining=delay; result.reset=true; return result
func dispatch(hit: int,allowed: bool,flags: int,result: Dictionary) -> Dictionary:
	active=hit
	if hit==0 or not allowed: return result
	result.trigger=hit; origin=point
	if flags&0x400: remaining=3000000
	return result
func advance(usec: int,hit: int,allowed: bool=true,flags: int=0) -> Dictionary:
	var result:=events()
	if remaining<=0: return result
	remaining=signed32(remaining-signed32(usec))
	if remaining<=0: return dispatch(hit,allowed,flags,result)
	return result
func instant(enabled: bool,visible: bool,hit: int,allowed: bool=true,flags: int=0) -> Dictionary:
	delay=1 if enabled else saved; var result:=events()
	if not enabled or visible: return result
	remaining=-1; return dispatch(hit,allowed,flags,result)
func trigger(visible: bool,hit: int,allowed: bool=true,flags: int=0) -> Dictionary:
	var result:=events()
	if visible: return result
	remaining=-1; return dispatch(hit,allowed,flags,result)
func remove(owner: int) -> Dictionary:
	var result:=events()
	if owner!=0 and active==owner:
		result.finish=active; remaining=delay; active=0; result.reset=true
	return result
