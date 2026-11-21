extends RefCounted

# NWN coordinates and w,x,y,z quaternion order until presentation conversion.
# Keep original single-precision operation boundaries without per-frame JS IO.
const WALKING = [2,3,4,78,79,84,85,86,87]
const RAD := 0.017453292
const DEG := 57.295776
const DEFAULT_LIMITS := {"minPitch":1.0,"maxPitch":89.0,"minDist":1.0,"maxDist":25.0}
var state: Dictionary = {}

static func f(value: float) -> float: return Vector3(value,0,0).x
static func add(a: float,b: float) -> float: return f(a+b)
static func mul(a: float,b: float) -> float: return f(a*b)
static func sine(v: float) -> float: return f(sin(f(v)))
static func cosine(v: float) -> float: return f(cos(f(v)))
static func angle(value: float) -> float:
	while value < -180: value = add(value,360)
	while value > 180: value = add(value,-360)
	return value

static func product(a: Array,b: Array) -> Array:
	var w: float = a[0]; var x: float = a[1]; var y: float = a[2]; var z: float = a[3]
	var v: float = b[0]; var i: float = b[1]; var j: float = b[2]; var k: float = b[3]
	return [f(mul(w,v)-mul(x,i)-mul(y,j)-mul(z,k)),f(mul(w,i)+mul(x,v)+mul(y,k)-mul(z,j)),f(mul(w,j)-mul(x,k)+mul(y,v)+mul(z,i)),f(mul(w,k)+mul(x,j)-mul(y,i)+mul(z,v))]

static func quaternion(yaw: float,pitch: float) -> Array:
	var a := mul(mul(yaw,f(RAD)),0.5); var b := mul(mul(pitch,f(RAD)),0.5)
	return product([cosine(a),0,0,sine(a)],[cosine(b),sine(b),0,0])

static func interpolate(a: Array,b: Array,t: float) -> Array:
	var dot := add(add(add(mul(a[0],b[0]),mul(a[1],b[1])),mul(a[2],b[2])),mul(a[3],b[3]))
	if dot < 0:
		a = a.map(func(v): return -float(v)); dot = -dot
	var q: Array
	if absf(dot) >= 1: q = a.duplicate()
	else:
		var theta := f(acos(dot))
		if theta == 0: q = a.duplicate()
		else:
			var sin_theta := sine(theta)
			var bt := f(sine(mul(theta,t))/sin_theta)
			var at := f(sine(f(theta-mul(theta,t)))/sin_theta)
			q = []
			for index in 4: q.append(add(mul(a[index],at),mul(b[index],bt)))
	var square := add(add(add(mul(q[1],q[1]),mul(q[0],q[0])),mul(q[2],q[2])),mul(q[3],q[3]))
	if square == 1: return q
	if not square > 0: return [1.0,0.0,0.0,0.0]
	var scale := f(sqrt(f(1.0/square)))
	return q.map(func(v): return mul(v,scale))

static func quaternion_yaw(q: Array) -> float:
	var w: float = q[0]; var x: float = q[1]; var y: float = q[2]; var z: float = q[3]
	var a := mul(2,f(mul(x,y)-mul(w,z))); var b := f(1-mul(2,add(mul(z,z),mul(x,x))))
	return 0.0 if a == 0 and b == 0 else mul(f(atan2(-a,b)),f(DEG))

static func rate(s: Dictionary,axis: String,value: float,impulse: bool = false) -> bool:
	var block: int = {"yaw":16,"pitch":32,"zoom":64}.get(axis,0)
	if block == 0 or int(s.get("flags",0)) & block: return false
	var key := "speed" if axis == "zoom" else (("turnDelta" if impulse else "turn") if axis == "yaw" else ("tiltDelta" if impulse else "tilt"))
	s[key] = f(float(s.get(key,0))+f(value))
	if s.get("predictionInputs") == null: s.predictionInputs = {"tilt":0.0,"turn":0.0,"tiltDelta":0.0,"turnDelta":0.0,"speed":0.0}
	# Both native impulse setters write module150; yaw's prediction field is
	# intentionally tiltDelta, unlike the live Follow field turnDelta.
	var predicted := "speed" if axis == "zoom" else ("tiltDelta" if impulse else ("turn" if axis == "yaw" else "tilt"))
	s.predictionInputs[predicted] = s[key]
	if value != 0:
		s.manual = 1
		if axis == "yaw": s.yawEvent = 1
		if axis == "zoom": s.zoomEvent = 1
	return true

static func pointer(dx: float,dy: float,width: float) -> Dictionary:
	return {"yaw":f(f(f(dx*-75)*0.2)/f(f(width/1920)/0.01)),"pitch":f(f(f(-dy*75)*0.15)/f(f(width/1080)/0.01))}

static func steering(s: Dictionary,actor: Dictionary,seconds: float) -> void:
	if int(s.mode) == 1: return
	if int(actor.get("animation",0)) in WALKING:
		if s.get("wasIdle",0): s.manualLatch = 0; s.wasIdle = 0
	else: s.wasIdle = 1
	if s.get("manual",0): s.manualLatch = 1; s.turning = 0; return
	if s.get("manualLatch",0): return
	var yaw := quaternion_yaw(s.quaternion) if int(s.mode) == 0 else float(s.yaw)
	var facing: float = actor.facing
	var difference := angle(f(facing-yaw))
	if not actor.get("strafing",0):
		if difference > 90 and int(actor.get("strafe",0)) == 2: difference = -90
		elif difference < -90 and int(actor.get("strafe",0)) == 1: difference = 90
	if absf(difference) <= 1: s.turning = 0; return
	if int(s.mode) == 0:
		if absf(difference) > 30 or s.get("turning",0): rate(s,"yaw",clampf(difference,-90,90)); s.turning = 1
	else:
		var turn := clampf(mul(difference,5),-180,180)
		var remaining := angle(f(facing-add(mul(turn,f(seconds)),yaw)))
		if (turn > 0.0001 and remaining < 0.0001) or (turn < 0.0001 and remaining > 0.0001): turn = f(f(facing-yaw)/f(seconds))
		rate(s,"yaw",turn); s.turning = 1

static func follow(s: Dictionary,seconds: float,target: Array) -> void:
	var dt := f(seconds)
	s.yaw = add(add(mul(dt,s.get("turn",0)),s.yaw),s.get("turnDelta",0)); s.turn = 0.0; s.turnDelta = 0.0
	if s.get("clampYaw",0): s.yaw = clampf(s.yaw,s.minYaw,s.maxYaw)
	s.pitch = add(add(mul(dt,s.get("tilt",0)),s.pitch),s.get("tiltDelta",0)); s.tilt = 0.0; s.tiltDelta = 0.0
	if s.get("clampPitch",0): s.pitch = clampf(s.pitch,s.minPitch,s.maxPitch)
	s.distance = mul(f(pow(2,mul(mul(dt,s.get("speed",0)),-0.5))),s.distance); s.speed = 0.0
	if s.get("clampDist",0): s.distance = clampf(s.distance,s.minDist,s.maxDist)
	var alpha := f(1-f(pow(0.5,mul(dt,s.spring)))); var old := f(1-alpha)
	var offset: Array = s.get("offset",[0,0,s.get("height",1)])
	for index in 3: s.focus[index] = add(mul(add(target[index],offset[index]),alpha),mul(old,s.focus[index]))
	s.quaternion = interpolate(s.quaternion,quaternion(s.yaw,s.pitch),alpha)
	var q: Array = s.quaternion
	var axis := [mul(2,add(mul(q[0],q[2]),mul(q[1],q[3]))),mul(2,f(mul(q[2],q[3])-mul(q[0],q[1]))),f(1-mul(2,add(mul(q[2],q[2]),mul(q[1],q[1]))))]
	s.position = []
	for index in 3: s.position.append(add(mul(axis[index],s.distance),s.focus[index]))

func reset(mode: int = 1,height: float = 1,position: Variant = null,yaw: float = 0) -> void:
	state = {"mode":mode,"appearanceHeight":height,"yaw":f(yaw),"pitch":50.0,"distance":20.0,"spring":750.0,"clampPitch":1,"minPitch":1.0,"maxPitch":89.0,"clampDist":1,"minDist":1.0,"maxDist":25.0,"clampYaw":0,"minYaw":0.0,"maxYaw":360.0,"turn":0.0,"tilt":0.0,"speed":0.0,"turnDelta":0.0,"tiltDelta":0.0,"zoomImpulse":0.0,"manual":0,"manualLatch":0,"turning":0,"wasIdle":1,"flags":0,"predictionInputs":null,"yawEvent":0,"zoomEvent":0}
	state.merge({"heightOverride":null,"modeAppearanceHeight":null,"rawLimits":{"minPitch":-1.0,"maxPitch":-1.0,"minDist":-1.0,"maxDist":-1.0},"effectiveLimits":DEFAULT_LIMITS.duplicate(),"locks":{"pitch":false,"distance":false,"yaw":false},"savedCamera":null,"scriptLocation":null,"rememberedPose":null,"findClearView":false})
	set_height(height)
	state.quaternion = quaternion(state.yaw,state.pitch)
	state.focus = null if position == null else [add(position[0],state.offset[0]),add(position[1],state.offset[1]),add(position[2],state.offset[2])]
	state.position = null

func set_height(height: float,preserve_override: bool = false) -> void:
	state.appearanceHeight = height
	state.defaultHeight = maxf(1,f(height-(0.5 if int(state.mode) == 1 else 0.0)))
	if not preserve_override: state.heightOverride = null
	state.height = state.defaultHeight if state.heightOverride == null else state.heightOverride
	state.offset = [0.0,0.0,state.height]

func set_mode(mode: int) -> bool:
	if mode not in [0,1,2]: return false
	if mode != int(state.mode):
		state.mode = mode; state.pitch = 50.0; state.distance = 20.0; set_height(state.appearanceHeight if state.modeAppearanceHeight == null else state.modeAppearanceHeight); state.manualLatch = 0; state.turning = 0
		for key in DEFAULT_LIMITS: state.effectiveLimits[key] = bound(key)
		for pair in [["pitch","minPitch","maxPitch"],["distance","minDist","maxDist"]]:
			if not state.locks[pair[0]]:
				state[pair[1]] = bound(pair[1]); state[pair[2]] = bound(pair[2])
	return true

func bound(key: String) -> float: return state.rawLimits[key] if state.rawLimits[key] >= 0 else DEFAULT_LIMITS[key]
static func finite_number(v: Variant) -> bool: return (v is int or v is float) and is_finite(float(v))
static func snap_command(v: float) -> float: return f(float("%.6f" % v))
func apply_command(command: Dictionary) -> bool:
	match command.get("kind",""):
		"camera-mode": return set_mode(int(command.get("mode",-1)))
		"camera-flags":
			var v: Variant = command.get("flags")
			if not finite_number(v) or float(v) != float(int(v)) or v < -2147483648 or v > 2147483647: return false
			state.flags = int(v); return true
		"camera-store":
			state.savedCamera = {"mode":state.mode,"distance":state.distance,"yaw":state.yaw,"pitch":state.pitch}; return true
		"camera-restore":
			if state.scriptLocation != null: state.scriptLocation.rate = 0
			var saved: Variant = state.savedCamera; state.savedCamera = null
			if saved != null:
				set_mode(int(saved.mode)); state.yaw = snap_command(saved.yaw); state.distance = snap_command(20 if saved.distance == 0 else saved.distance); state.pitch = snap_command(50 if saved.pitch == 0 else saved.pitch)
			return true
		"camera-height":
			if not finite_number(command.get("height")): return false
			state.heightOverride = null if command.height == 0 else f(command.height)
			state.height = state.defaultHeight if state.heightOverride == null else state.heightOverride; state.offset = [0.0,0.0,state.height]; return true
		"camera-limits":
			if not command.get("limits") is Dictionary: return false
			for key in DEFAULT_LIMITS:
				if not finite_number(command.limits.get(key)): return false
			for key in DEFAULT_LIMITS: state.rawLimits[key] = f(command.limits[key])
			return true
		"camera-lock":
			var axis: String = command.get("axis",""); var locked: Variant = command.get("locked")
			if not state.locks.has(axis) or not locked is bool: return false
			state.locks[axis] = locked
			if axis == "yaw": state.minYaw = state.yaw if locked else 0.0; state.maxYaw = state.yaw if locked else 360.0; state.clampYaw = int(locked)
			else:
				var lo := "minPitch" if axis == "pitch" else "minDist"; var hi := "maxPitch" if axis == "pitch" else "maxDist"
				state[lo] = state[axis] if locked else bound(lo); state[hi] = state[axis] if locked else bound(hi)
				if not locked: state.effectiveLimits[lo] = state[lo]; state.effectiveLimits[hi] = state[hi]
			return true
		"camera-location":
			var mask: Variant = command.get("mask")
			if not finite_number(mask) or float(mask) != float(int(mask)) or mask < 0 or mask > 255: return false
			var fields := ["yawRadians","distance","pitch","transition"]
			for i in 4:
				if ((int(mask) & (1 << i)) != 0 or command.has(fields[i])) and not finite_number(command.get(fields[i])): return false
			var limits: Dictionary = state.effectiveLimits
			var distance := clampf(f(command.distance) if int(mask) & 2 else float(state.distance),limits.minDist,limits.maxDist)
			var pitch := clampf(f(command.pitch) if int(mask) & 4 else float(state.pitch),limits.minPitch,limits.maxPitch)
			var yaw := mul(f(f(command.yawRadians if int(mask) & 1 else state.yaw)-f(1.5707964)),f(DEG))
			var speed: int = int(command.transition) if int(mask) & 8 else 0
			state.scriptLocation = {"distance":distance,"yaw":yaw,"pitch":pitch,"rate":speed if speed >= 0 and speed <= 180 else 0}
			if state.scriptLocation.rate == 0:
				if int(mask) & 1: state.yaw = snap_command(yaw)
				if int(mask) & 2: state.distance = snap_command(distance)
				if int(mask) & 4: state.pitch = snap_command(pitch)
			return true
	return false

static func divide(a: float,b: float) -> float:
	if b == 0: return NAN if a == 0 else (INF if a > 0 else -INF)
	return f(a/b)

static func location(s: Dictionary,seconds: float,paused: bool = false) -> bool:
	var t: Variant = s.get("scriptLocation"); var epsilon := f(0.0001); var dt := f(seconds)
	if t == null or t.rate < epsilon: return true
	if paused: return false
	var delta := angle(f(t.yaw-s.yaw)); var pitch_delta := f(t.pitch-s.pitch)
	var ratio := preload("res://systems/camera_log.gd").evaluate(divide(t.distance,s.distance))
	var yaw_rate: float = t.rate; var pitch_rate: float
	var zoom_rate := divide(t.rate,absf(divide(90,preload("res://systems/camera_log.gd").evaluate(4))))
	var yaw_metric := absf(divide(delta,t.rate)); var zoom_metric := absf(mul(divide(-2,zoom_rate),ratio)); var pitch_metric := absf(divide(pitch_delta,divide(t.rate,f(3.6734693))))
	if not (yaw_metric > epsilon or zoom_metric > epsilon or pitch_metric > epsilon): return true
	if yaw_metric < zoom_metric or yaw_metric < pitch_metric:
		if zoom_metric < yaw_metric or zoom_metric < pitch_metric:
			yaw_rate = absf(divide(delta,pitch_metric)); pitch_rate = divide(t.rate,f(3.6734693)); zoom_rate = absf(divide(add(ratio,ratio),pitch_metric))
		else: yaw_rate = absf(divide(delta,zoom_metric)); pitch_rate = absf(divide(pitch_delta,zoom_metric))
	else: zoom_rate = absf(divide(add(ratio,ratio),yaw_metric)); pitch_rate = absf(divide(pitch_delta,yaw_metric))
	var current := angle(s.yaw); var target := angle(t.yaw); var difference := angle(f(target-current))
	var turn := -yaw_rate if difference < 0 else (yaw_rate if difference > 0 else 0.0); var next := add(mul(turn,dt),current)
	var yaw_done := true; var zoom_done := true; var pitch_done := true
	if (target < current and next < target) or (current < target and target < next): s.yaw = target
	elif current != target: rate(s,"yaw",turn); yaw_done = false
	if int(s.mode) != 2:
		var speed := zoom_rate if t.distance < s.distance else (-zoom_rate if t.distance > s.distance else 0.0)
		var predicted := mul(s.distance,f(pow(2,mul(mul(speed,dt),-0.5))))
		if (s.distance > t.distance and predicted < t.distance) or (s.distance < t.distance and predicted > t.distance): s.distance = t.distance
		elif s.distance != t.distance: rate(s,"zoom",speed); zoom_done = false
		var tilt := -pitch_rate if s.pitch > t.pitch else (pitch_rate if s.pitch < t.pitch else 0.0); var predicted_pitch := add(mul(tilt,dt),s.pitch)
		if (t.pitch < s.pitch and predicted_pitch < t.pitch) or (s.pitch < t.pitch and t.pitch < predicted_pitch): s.pitch = t.pitch
		elif s.pitch != t.pitch: rate(s,"pitch",tilt); pitch_done = false
	return yaw_done and zoom_done and pitch_done

func attach(position: Array,height: float = 1,creature: bool = true,find_clear: bool = false,clamps_enabled: bool = true) -> void:
	var pose: Variant = state.rememberedPose
	set_height(height if creature else 1.0)
	if not creature: state.defaultHeight = 1.0; state.height = 1.0; state.offset = [0.0,0.0,1.0]
	state.merge({"focus":position.map(func(v): return f(v)),"distance":8.0,"yaw":0.0,"pitch":state.effectiveLimits.maxPitch,"spring":750.0,"turn":0.0,"tilt":0.0,"speed":0.0,"turnDelta":0.0,"tiltDelta":0.0,"zoomImpulse":0.0,"clampYaw":0,"minYaw":0.0,"maxYaw":360.0,"clampPitch":int(clamps_enabled),"minPitch":0.0 if state.locks.pitch else state.effectiveLimits.minPitch,"maxPitch":360.0 if state.locks.pitch else state.effectiveLimits.maxPitch,"clampDist":int(clamps_enabled),"minDist":0.0 if state.locks.distance else state.effectiveLimits.minDist,"maxDist":10.0 if state.locks.distance else state.effectiveLimits.maxDist,"findClearView":find_clear},true)
	if pose != null and pose.distance != 0: state.merge(pose,true)

func input(values: Dictionary) -> void:
	if values.has("yaw"): rate(state,"yaw",values.yaw,true)
	if values.has("pitch"): rate(state,"pitch",values.pitch,true)
	if values.has("zoom"): state.zoomImpulse = add(state.get("zoomImpulse",0),values.zoom)

func update(actor: Dictionary,seconds: float) -> bool:
	if not actor.get("position") is Array or not is_finite(seconds) or seconds < 0: return false
	if state.get("focus") == null: state.focus = [add(actor.position[0],state.offset[0]),add(actor.position[1],state.offset[1]),add(actor.position[2],state.offset[2])]
	rate(state,"yaw",0); rate(state,"pitch",0)
	steering(state,actor,seconds)
	if location(state,seconds,bool(actor.get("paused",false))) and state.scriptLocation != null: state.scriptLocation.rate = 0
	state.rememberedPose = {"distance":state.distance,"yaw":state.yaw,"pitch":state.pitch}
	var zoom: float = state.get("zoomImpulse",0); state.zoomImpulse = 0.0
	if absf(zoom) > f(0.0001): rate(state,"zoom",zoom)
	follow(state,seconds,actor.position); state.manual = 0
	return true
