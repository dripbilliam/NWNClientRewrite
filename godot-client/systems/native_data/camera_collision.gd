extends RefCounted
# Direct translation of the original camera collision dispatcher and its two
# distance caches. The query returns the nearest native hit point or null.
const TileSurface=preload("res://systems/native_data/tile_surface.gd")
static func f(value: float)->float:return Vector3(value,0,0).x
static func add(a: float,b: float)->float:return f(a+b)
static func sub(a: float,b: float)->float:return f(a-b)
static func mul(a: float,b: float)->float:return f(a*b)
static func plus(a: Array,b: Array)->Array:return [add(a[0],b[0]),add(a[1],b[1]),add(a[2],b[2])]
static func minus(a: Array,b: Array)->Array:return [sub(a[0],b[0]),sub(a[1],b[1]),sub(a[2],b[2])]
static func scale(a: Array,k: float)->Array:return [mul(a[0],k),mul(a[1],k),mul(a[2],k)]
static func magnitude(a: Array)->float:return f(sqrt(add(add(mul(a[0],a[0]),mul(a[1],a[1])),mul(a[2],a[2]))))
static func state()->Dictionary:return {"primary":{"distance":0.0,"focus":[0.0,0.0,0.0]},"stiff":{"distance":0.0,"focus":[0.0,0.0,0.0]}}
static func clipped(point: Array,focus: Array)->float:return magnitude(minus(point,focus))

static func recover(s: Dictionary,cache: Dictionary,focus: Array,direction: Array,nudge: Array,view: Array,dt: float,query: Callable)->Dictionary:
	if not (float(cache.distance)>0):return {"distance":0.0,"recovering":false}
	var wanted:=minus(focus,scale(direction,float(cache.distance)))
	var hit: Variant=query.call(wanted,view) if float(cache.distance)<=float(s.distance) else query.call(view,wanted)
	var distance:=add(float(s.distance),mul(mul(sub(float(cache.distance),float(s.distance)),3.5),dt))
	if hit!=null:
		var limit:=clipped(plus(hit,nudge),focus)
		if limit<=distance:distance=limit
		return {"distance":distance,"recovering":false}
	if int(s.mode)==2 and float(cache.distance)<=distance or int(s.mode)!=2 and sub(distance,float(cache.distance))>=f(-0.0001):
		distance=float(cache.distance);cache.distance=0.0
	return {"distance":distance,"recovering":true}

static func step(s: Dictionary,caches: Dictionary,context: Dictionary,seconds: float,input_speed: float,query: Callable,predict: Callable)->float:
	var speed:=f(input_speed);var dt:=f(seconds)
	if s.findClearView or (int(context.get("flags",0))&2)!=0 or not bool(context.get("enabled",true)) or not bool(context.get("eligible",true)):return speed
	var position: Array=context.position;var camera_position: Array=context.cameraPosition
	var focus:=plus(position,s.offset);var delta:=minus(focus,camera_position)
	if not (magnitude(delta)>0):return speed
	var direction: Array=TileSurface.normalize(delta);var nudge:=scale(direction,f(0.001))
	var cache: Dictionary=caches.stiff if int(s.mode)==2 else caches.primary
	if cache.focus[0]==0 and cache.focus[1]==0 and cache.focus[2]==0:cache.focus=position.duplicate()
	var prediction: Dictionary=predict.call(cache.focus,speed)
	cache.focus=prediction.focus
	var view: Array=prediction.position
	var zoom:=speed;var distance:=0.0;var clamp_enabled:=true;var recovering:=false;var negative_only:=false
	if int(s.mode)==2:
		var hit: Variant=query.call(focus,view)
		if hit!=null:
			distance=clipped(plus(hit,nudge),focus)
			if float(cache.distance)==0:cache.distance=s.distance
		else:
			var stiff_recovery:=recover(s,cache,focus,direction,nudge,view,dt,query)
			distance=float(stiff_recovery.distance);recovering=bool(stiff_recovery.recovering)
	else:
		var retry:=false
		if speed<0:
			var far:=minus(focus,scale(direction,float(s.effectiveLimits.maxDist)))
			var far_first: Variant=query.call(view,far)
			var far_second: Variant=query.call(plus(far_first,nudge),view) if far_first!=null else query.call(far,view)
			if far_second!=null:
				distance=clipped(minus(far_second,nudge),focus);cache.distance=0.0;negative_only=true
			else:retry=true
		if not negative_only:
			var near_first: Variant=query.call(view,focus)
			var near_second: Variant=query.call(minus(near_first,nudge),view) if near_first!=null else query.call(focus,view)
			if near_second!=null:
				if float(cache.distance)==0:cache.distance=s.distance
				if retry:zoom=0.0
				distance=clipped(plus(near_second,nudge),focus)
			else:
				var near_recovery:=recover(s,cache,focus,direction,nudge,view,dt,query)
				distance=float(near_recovery.distance);recovering=bool(near_recovery.recovering)
	if not negative_only:
		if speed>0:cache.distance=0.0
		if distance==0 and float(s.distance)<float(s.effectiveLimits.minDist) or distance>0 and sub(float(s.effectiveLimits.minDist),distance)>=f(0.0001):
			clamp_enabled=false
			if float(cache.distance)<float(s.effectiveLimits.minDist):cache.distance=s.effectiveLimits.minDist
			zoom=0.0
	if bool(context.get("clampsEnabled",true)):
		s.clampDist=int(clamp_enabled)
		if distance>0:
			s.distance=distance
			if not recovering:zoom=0.0
			s.manual=1
		if float(s.distance)<=float(s.effectiveLimits.minDist):zoom=minf(zoom,0.0)
		if float(s.distance)>=float(s.effectiveLimits.maxDist):zoom=maxf(zoom,0.0)
	return zoom
