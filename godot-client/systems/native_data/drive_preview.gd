extends RefCounted
# Original finite-vector input plan6ea9e0 and mode2 path search7fdeb0.
# Callers supply native collision; this class never changes server state.
const Motion=preload("res://systems/network_motion.gd")
const NativeMath=preload("res://systems/native_data/native_math.gd")
static func native_normalized(v: Vector3) -> Vector3:
	var square:=Motion.f(Motion.f(Motion.f(v.x*v.x)+Motion.f(v.y*v.y))+Motion.f(v.z*v.z))
	if square>=Motion.f(0.99999) and square<=Motion.f(1.00001): return v
	if square==0: return Vector3.RIGHT
	return v*Motion.f(sqrt(Motion.f(1.0/square)))
static func dot(a: Vector3,b: Vector3) -> float:
	return Motion.f(Motion.f(Motion.f(a.y*b.y)+Motion.f(a.x*b.x))+Motion.f(a.z*b.z))
static func turn(vector: Vector3,flags: int) -> Vector3:
	if (flags&48)==0: return vector
	var angle:=Motion.f(Motion.f(30.0 if flags&16 else -30.0)*Motion.f(0.017453292))
	var c:=NativeMath.native_cosf(angle); var s:=NativeMath.native_sinf(angle)
	return Motion.normalized32(Vector3(Motion.f(Motion.f(vector.x*c)-Motion.f(vector.y*s)),Motion.f(Motion.f(vector.x*s)+Motion.f(vector.y*c)),0))
static func wire_facing(heading: int) -> Vector3:
	var angle:=(heading/10.0)*0.01745329238474369
	return Motion.normalized32(Vector3(cos(angle),sin(angle),0))
static func plan(position: Vector3,orientation: Vector3,walk_rate: float,run_rate: float,flags: int) -> Dictionary:
	if not position.is_finite() or not orientation.is_finite() or not is_finite(walk_rate) or not is_finite(run_rate):return {"error":"Native drive preview pose/rates unavailable"}
	var vector:=Vector3.ZERO; var distance:=0.0; var animation:=2; var run:=false
	if flags&4: vector+=Vector3(-orientation.y,orientation.x,0); distance=Motion.f(0.8); animation=78
	elif flags&8: vector+=Vector3(orientation.y,-orientation.x,0); distance=Motion.f(0.8); animation=79
	if (flags&3)==3:
		vector+=orientation; distance=Motion.f(Motion.f(run_rate*400)/Motion.f(1e6)); animation=86 if flags&4 else 87 if flags&8 else 4; run=true
	elif flags&1:
		vector+=orientation; distance=Motion.f(Motion.f(walk_rate*400)/Motion.f(1e6)); animation=84 if flags&4 else 85 if flags&8 else 2
	elif flags&2:
		vector-=orientation; distance=Motion.f(Motion.f(walk_rate*400)/Motion.f(1e6)); animation=3
	var facing:=turn(orientation,flags)
	if flags&48: vector=turn(vector,flags)
	return {"target":position+Motion.normalized32(vector)*distance,"facing":facing,"animation":animation,"run":run,"mode":2,"factor":1.0}
static func path(from: Vector3,target: Vector3,render: Vector3,clear: Callable,failure: Dictionary={}) -> Dictionary:
	var direct: Variant=clear.call(from,target)
	if not str(failure.get("error","")).is_empty(): return {"error":str(failure.error)}
	if direct: return {"target":target,"factor":1.0}
	var fraction:=Motion.f(0.5); var step:=Motion.f(0.25); var best: Variant=null
	while true:
		var point:=from+(target-from)*fraction
		var clear_point: Variant=clear.call(from,point)
		if not str(failure.get("error","")).is_empty(): return {"error":str(failure.error)}
		if clear_point: best=point; fraction=Motion.f(fraction+step)
		else: fraction=Motion.f(fraction-step)
		step=Motion.f(step*0.5)
		if not Motion.f(0.005)<step: break
	if best!=null: return {"target":best,"factor":1.0,"resendFraction":fraction}
	var delta:=target-from; var direction:=native_normalized(delta); var length:=Motion.length32(delta)
	var best_a:=native_normalized(Vector3(-direction.y,direction.x,0)); var best_b:=native_normalized(-best_a)
	var blocked_a:=direction; var blocked_b:=direction; var search_a:=true; var search_b:=true; var clear_a:=false; var clear_b:=false
	for attempt in 15:
		if not search_a and not search_b: break
		var a:=native_normalized(best_a+blocked_a); var b:=native_normalized(best_b+blocked_b)
		if search_a:
			clear_a=clear.call(from,render+a*length)
			if not str(failure.get("error","")).is_empty(): return {"error":str(failure.error)}
		if search_b:
			clear_b=clear.call(from,render+b*length)
			if not str(failure.get("error","")).is_empty(): return {"error":str(failure.error)}
		if search_a:
			if clear_a: best_a=a
			else: search_a=not clear_b; blocked_a=a
		if search_b:
			if clear_b: best_b=b
			else: search_b=not clear_a; blocked_b=b
	var selected: Vector3=(best_b if dot(best_a,direction)<=dot(best_b,direction) else best_a) if search_a==search_b else best_a if search_a else best_b
	var factor:=maxf(Motion.f(0.25),dot(selected,direction)); var end:=render+selected*Motion.f(factor*length)
	var clear_end: Variant=clear.call(from,end)
	if not str(failure.get("error","")).is_empty(): return {"error":str(failure.error)}
	return {"target":end,"factor":factor} if clear_end else {}
static func blocked(animation: int) -> bool:
	return animation in [6,8,17,18,19,20,61,70,71,221,222,250,251,252,253,261]
static func repair(state: Dictionary,path: Array,server_position: Vector3,clear: Callable,failure: Dictionary={}) -> Dictionary:
	# Original8001f0 connects received waypoints to the displayed pose. It does
	# not rewind a continuing local path to the start of an older server packet.
	if not state.get("area",true) or path.is_empty() or int(state.get("script",0))!=0 and int(state.get("sequence",0))!=0 and int(state.sequence)!=int(state.get("lastSequence",0)): return {}
	var points: Array=path.map(Motion.vector); var render: Vector3=Motion.vector(state.render)
	var first_clear: Variant=clear.call(render,points[0])
	if not str(failure.get("error","")).is_empty(): return {"error":str(failure.error)}
	if first_clear: return {"path":points}
	var position_clear: Variant=clear.call(render,server_position)
	if not str(failure.get("error","")).is_empty(): return {"error":str(failure.error)}
	if position_clear: return {"path":[server_position]+points}
	for i in range(1,points.size()):
		var waypoint_clear: Variant=clear.call(render,points[i])
		if not str(failure.get("error","")).is_empty(): return {"error":str(failure.error)}
		if waypoint_clear: return {"path":points.slice(i)}
	var prior: Array=state.get("path",[]).map(Motion.vector)
	if not prior.is_empty():
		var prior_clear: Variant=clear.call(prior[-1],points[-1])
		if not str(failure.get("error","")).is_empty(): return {"error":str(failure.error)}
		if prior_clear: return {"path":prior.slice(int(state.get("cursor",0)))+[points[-1]]}
	return {"path":points,"reset":server_position}
