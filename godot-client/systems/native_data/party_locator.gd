extends RefCounted
const F=preload("res://systems/native_render/particle_math.gd")
# Original854320: distinguish live object coordinates from the cached bearing
# used when that object is absent. Different-area arrows use angleunknown.
static func bearing(position: Vector2,actor: Vector2,yaw: float) -> float:
	var x:=F.f(F.f(position.x)-F.f(actor.x)); var y:=F.f(F.f(position.y)-F.f(actor.y)); yaw=F.f(yaw)
	if x==0: return F.f((-180.0 if y<=0 else 0.0)-yaw)
	var angle:=F.f(F.f(F.f(atan(F.f(y/x)))/F.f(3.1415927))*180.0)
	if x<0: angle=F.f(angle+180.0)
	return F.f(F.f(angle-90.0)-yaw)
static func decide(same_area: bool,position: Variant,actor: Variant,yaw: float,cached: float,was_unknown: bool) -> Dictionary:
	var calls: Array=[]; var angle: Variant=null
	if not same_area:
		if not was_unknown: calls.append(["animation","angleunknown",1.0,1])
		return {"unknown":true,"angle":null,"calls":calls}
	if position==null: angle=F.f(F.f(cached)-F.f(yaw))
	elif actor!=null: angle=bearing(position,actor,yaw)
	if angle!=null: calls.append(["angle",angle])
	if was_unknown: calls.append(["advance",10.0])
	return {"unknown":false,"angle":angle,"calls":calls}
static func state_time(angle: float,length: float) -> float:
	# Original1eb510 ->1fb350 resets the run, changes its speed for one .001
	# clock step and stops it. Preserve its +/-1e-5 start and one-wrap rule.
	var delta:=F.f(0.001); var speed:=F.f(F.f(F.f(angle)/30.0)/delta); length=F.f(length)
	var start:=F.f(length+F.f(0.00001)) if speed<0 else F.f(-0.00001) if speed>0 else 0.0
	var time:=F.f(start+F.f(speed*delta))
	if time<0 and speed<=0: time=maxf(0,F.f(time+length))
	if time>length and speed>=0: time=minf(length,F.f(time-length))
	return time
