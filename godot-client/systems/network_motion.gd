extends RefCounted

# Native frame owner for the established client movement rules. All simulation
# vectors below use NWN coordinates; only pose() changes to Godot's axes.
var objects: Dictionary = {}
var next_lifetime := 1
var remainder_ms := 0.0
var height_query: Callable

static func f(value: float) -> float:
	return Vector3(value, 0, 0).x

static func vector(value) -> Vector3:
	if value is Vector3:
		return value
	return Vector3(float(value[0]), float(value[1]), float(value[2]) if value.size() > 2 else 0.0)

static func length32(value: Vector3) -> float:
	return f(sqrt(f(f(f(value.x * value.x) + f(value.y * value.y)) + f(value.z * value.z))))

static func normalized32(value: Vector3) -> Vector3:
	var size := length32(value)
	return value / size if size > 0 else Vector3.ZERO

static func path_animation(animation: int) -> bool:
	return (animation & 65535) in [2, 3, 4, 78, 79, 84, 85, 86, 87]

static func facing(value) -> Vector3:
	if value is Dictionary:
		if value.has("vector"):
			return vector(value.vector)
		var angle := float(value.get("yaw", 0)) * PI / 180.0
		return Vector3(-sin(angle), cos(angle), 0)
	return vector(value)

func ensure(id: int, state: Dictionary) -> Dictionary:
	if objects.has(id):
		return objects[id]
	if not state.has("position"):
		return {}
	var direction := facing(state.get("orientation", [1, 0, 0]))
	var animation := int(state.get("animation", 0))
	var entry := {"lifetime": next_lifetime, "position": vector(state.position), "render": vector(state.position), "orientation": direction, "targetOrientation": direction, "animation": animation, "restingBase": 1 if animation == 1 else 0, "walkRate": state.get("walkRate", 0), "runRate": state.get("runRate", 0), "path": [], "cursor": 0, "acceleration": 0.0, "correction": 0, "script": 0, "factor": 1.0, "newPath": 1, "active": false, "modelType": state.get("modelType", 1), "walkDistance": state.get("walkDistance", 0), "runDistance": state.get("runDistance", 0)}
	next_lifetime += 1
	objects[id] = entry
	return entry

func configure(rows: Array) -> void:
	objects.clear()
	remainder_ms = 0.0
	for row in rows:
		var state: Dictionary = row.state
		var entry := ensure(int(row.id), state)
		for key in state:
			entry[key] = state[key]
		for key in ["position", "render", "orientation", "targetOrientation", "previewFacing", "movementDirection"]:
			if entry.has(key):
				entry[key] = vector(entry[key])
		entry.path = entry.get("path", []).map(vector)
		next_lifetime = maxi(next_lifetime, int(entry.lifetime) + 1)

func adopt(rows: Array) -> void:
	for row in rows:
		var id := int(row.id)
		var source: Dictionary = row.state
		var entry := ensure(id, source)
		for key in ["modelType", "walkDistance", "runDistance"]:
			if source.has(key):
				entry[key] = source[key]

func observe(id: int, changes: Dictionary, created: bool = false, initial: Dictionary = {}, defer_path: bool = false) -> void:
	if created:
		objects.erase(id)
	var state := ensure(id, initial if not initial.is_empty() else changes)
	if state.is_empty():
		return
	var stale: bool = state.script != 0 and state.has("driveSequence") and int(changes.get("actionFlag", 0)) != 0 and int(changes.actionFlag) != int(state.driveSequence)
	if stale:
		for key in ["walkRate", "runRate"]:
			if changes.has(key):
				state[key] = changes[key]
		if not changes.has("animation") or int(changes.animation) in [0, 1, 2, 3, 4, 78, 79, 84, 85, 86, 87]:
			return
	if changes.has("animation") and not path_animation(int(changes.animation)):
		state.previewBase = false
		state.previewAnimationPending = false
	if changes.has("orientation"):
		state.targetOrientation = facing(changes.orientation)
		if created:
			state.orientation = state.targetOrientation
	for key in ["walkRate", "runRate", "animation", "modelType", "walkDistance", "runDistance"]:
		if changes.has(key):
			state[key] = changes[key]
	if int(changes.get("animation", -1)) in [0, 1]:
		state.restingBase = int(changes.animation)
	if changes.has("path") and not defer_path:
		if not changes.path.is_empty():
			state.script = int(bool(changes.get("field8F4", 0)) or state.script != 0)
			state.factor = f(float(changes.get("field8EC", 1)))
		if not changes.path.is_empty() and path_animation(int(state.animation)):
			var end := vector(changes.path[-1])
			if state.path.is_empty() or length32(state.path[-1] - end) > 0.001 or not state.active:
				state.path = changes.path.map(func(point): return Vector3(float(point[0]), float(point[1]), 0))
				state.cursor = 0
				state.newPath = 1
				state.active = true
		else:
			state.path = []
			state.cursor = 0
			state.active = false
	if changes.has("position") and not defer_path and (not state.active or not path_animation(int(state.animation))):
		var position := vector(changes.position)
		if length32(position - state.position) > f(0.0001):
			state.position = position
			state.correction = 512

func accept_path(id: int, result: Dictionary, changes: Dictionary) -> void:
	if not objects.has(id):
		return
	var state: Dictionary = objects[id]
	if result.has("reset"):
		state.position = vector(result.reset)
		state.render = state.position
	state.script = int(bool(changes.get("field8F4", 0)) or state.script != 0)
	state.factor = f(float(changes.get("field8EC", 1)))
	state.path = result.path.map(vector)
	state.cursor = 0
	state.newPath = 1
	state.active = true

func preview(id: int, plan: Dictionary, target = null) -> void:
	if not objects.has(id):
		return
	var state: Dictionary = objects[id]
	state.driveHeld = true
	state.previewBase = true
	state.finished = false
	state.animation = int(plan.animation)
	state.previewAnimationPending = true
	if target == null:
		return # Blocked input still selects its original movement animation.
	state.script = 1
	state.factor = f(float(plan.get("factor", 1)))
	state.newPath = 0
	state.previewFacing = vector(plan.facing)
	state.targetOrientation = state.previewFacing
	state.path = [state.position, vector(target)]
	state.cursor = 0
	state.active = true

static func distance(state: Dictionary, dt: int) -> Dictionary:
	var animation := int(state.animation) & 65535
	var rate := f(1600.0001220703125) if animation in [78, 79] else f(float(state.walkRate if animation in [2, 3, 84, 85] else state.runRate))
	if state.script != 0:
		return {"distance": f(f(f(float(dt)) * f(rate * f(float(state.factor)))) / f(1e6)), "acceleration": 1.0, "rate": rate}
	var remaining := 0.0
	var last: Vector3 = state.position
	for point in state.path.slice(int(state.cursor)):
		remaining = f(remaining + length32(Vector3(f(point.x - last.x), f(point.y - last.y), 0)))
		last = point
	var half_second := f(f(rate * f(1000)) / f(2e6))
	var limit := 1.0
	if not half_second < remaining:
		var ratio := f(remaining / half_second) if half_second != 0 else 0.0
		limit = f((f(0.1) if ratio < f(0.01) else f(sqrt(ratio))) - f(f(float(dt)) / f(1000)))
	var old := f(float(state.acceleration))
	var next := limit
	if old <= 1:
		next = f(f(f(float(dt)) / (f(500) if state.newPath != 0 else f(1000))) + old)
		if limit <= next:
			next = limit
	var acceleration := f(0.1) if next < f(0.1) else next
	state.acceleration = acceleration
	return {"distance": f(f(f(f(f(float(dt)) * rate) * f(old + acceleration)) * f(0.5)) / f(1e6)), "acceleration": acceleration, "rate": rate}

func step_path(state: Dictionary, amount: float) -> Dictionary:
	var position: Vector3 = state.position
	var direction: Vector3 = state.orientation
	var done := false
	while int(state.cursor) < state.path.size():
		var point: Vector3 = state.path[int(state.cursor)]
		var delta := Vector3(f(point.x - position.x), f(point.y - position.y), 0)
		var size := length32(delta)
		if amount <= size:
			if size <= f(0.01):
				position = point
			else:
				direction = normalized32(delta)
				position += direction * amount
			if int(state.cursor) == state.path.size() - 1:
				done = length32(position - point) <= f(0.01)
			break
		amount = f(amount - size)
		position = point
		if size > f(0.01):
			direction = normalized32(delta)
		if int(state.cursor) == state.path.size() - 1:
			done = true
			break
		state.cursor += 1
	if int(state.cursor) == state.path.size() - 1 and state.script == 0:
		var end: Vector3 = state.path[-1]
		var remaining := length32(Vector3(f(end.x - state.position.x), f(end.y - state.position.y), 0))
		if remaining <= 1 and f(f(direction.x * state.orientation.x) + f(direction.y * state.orientation.y)) < f(-0.707):
			direction = -direction
			state.animation = 3
	position.z = f(float(height_query.call(position, state.position.z))) if height_query.is_valid() else state.position.z
	return {"position": position, "direction": direction, "done": done}

static func correct(state: Dictionary, position: Vector3, dt: int) -> Vector3:
	state.correctionCue = null
	var timer := int(state.correction)
	if dt >= timer:
		state.correction = 0
		return position
	state.correction = timer - dt
	var delta: Vector3 = state.position - state.render
	var xy := f(f(delta.x * delta.x) + f(delta.y * delta.y))
	var square := f(xy + f(delta.z * delta.z))
	if square < f(1e-5) or xy >= 16:
		state.correction = 0
		return position
	if int(state.get("visualAnimation", state.animation)) in [0, 1] and square >= f(0.04):
		var direction := normalized32(delta)
		var forward := normalized32(state.orientation)
		var dot := f(f(f(direction.y * forward.y) + f(direction.x * forward.x)) + f(direction.z * forward.z))
		var cross := f(f(direction.x * forward.y) - f(direction.y * forward.x))
		state.correctionCue = {"animation": (24 if dot >= f(0.707) else (25 if dot <= f(-0.707) else (27 if cross <= 0 else 26))), "type": 6, "duration": int(state.correction) & 65535}
	var ratio := f(f(float(state.correction)) / f(float(dt + int(state.correction))))
	return (state.render - position) * ratio + position

static func facing_step(old: Vector3, target: Vector3, animation: int, dt: int, options: Dictionary = {}) -> Dictionary:
	var desired := normalized32(Vector3(target.x, target.y, 0))
	var dot := f(f(f(old.y * desired.y) + f(old.x * desired.x)) + f(old.z * desired.z))
	var sign := -1.0 if f(f(old.x * desired.y) - f(old.y * desired.x)) < 0 else 1.0
	var requests: Array = []
	if dot < 1 and animation in [0, 1, 53, 54]:
		if dot >= f(0.99):
			return {"orientation": old, "target": desired, "requests": requests}
		var base := int(options.get("restored", 0)) if animation in [53, 54] else animation
		if base == 0 and options.get("model", true) and int(options.get("modelType", 1)) == 1:
			requests.append(80 if sign < 0 else 81)
		elif base == 1:
			requests.append(82 if sign < 0 else 83)
	var speed := f(f(1 - dot) * 3)
	if animation == 4:
		speed = f(speed + speed)
	speed = f(0.55) if speed <= f(0.55) else minf(f(1.55), speed)
	var angle := f(f(f(f(float(dt)) * speed) * 4000) / f(1e6))
	var next := desired
	if dot < f(cos(angle)):
		var signed := f(angle * sign)
		var cosine := f(cos(signed))
		var sine := f(sin(signed))
		next = Vector3(f(f(old.x * cosine) - f(old.y * sine)), f(f(old.x * sine) + f(old.y * cosine)), 0)
	return {"orientation": normalized32(next), "target": desired, "requests": requests}

func update(seconds: float) -> void:
	if not is_finite(seconds) or seconds < 0:
		return
	var elapsed := seconds * 1000 + remainder_ms
	var dt := int(elapsed)
	remainder_ms = elapsed - dt
	for id in objects:
		var state: Dictionary = objects[id]
		state.correctionCue = null
		if state.active and not state.path.is_empty() and path_animation(int(state.animation)):
			var gait := distance(state, dt)
			var step := step_path(state, float(gait.distance))
			state.position = step.position
			state.render = correct(state, step.position, dt)
			state.movementDirection = step.direction
			state.gait = {"animation": state.animation, "rate": gait.rate, "script": state.script, "factor": state.factor, "acceleration": gait.acceleration}
			if step.done:
				state.active = false
				state.acceleration = 0.0
				state.script = 0
				state.finished = true
		elif int(state.correction) != 0:
			state.render = correct(state, state.position, dt)
		var target: Vector3 = state.targetOrientation
		if state.active and path_animation(int(state.animation)):
			target = state.get("previewFacing", state.orientation) if state.script != 0 and state.get("previewBase", false) else state.get("movementDirection", state.targetOrientation)
		var facing_result := facing_step(state.orientation, target, int(state.get("visualAnimation", state.animation)), dt, {"modelType": state.modelType, "restored": state.restingBase})
		state.orientation = facing_result.orientation
		state.facingTurn = null if facing_result.requests.is_empty() else facing_result.requests[0]

func pose(id: int) -> Dictionary:
	if not objects.has(id):
		return {}
	var state: Dictionary = objects[id]
	return {"position": Vector3(state.render.x, state.render.z, -state.render.y), "rotation": -atan2(state.orientation.x, state.orientation.y)}

func finish_frame(id: int) -> void:
	var state: Dictionary = objects[id]
	if state.get("finished", false):
		state.finished = false
		state.animation = state.restingBase

func gait_speed(id: int, clip_seconds: float) -> float:
	var state: Dictionary = objects[id]
	if not state.active or not state.has("gait") or clip_seconds <= 0:
		return 1.0
	var gait: Dictionary = state.gait
	var creep: bool = (int(state.animation) & 65535) in [78, 79]
	var rate := f(1600.0001220703125) if creep else f(float(gait.rate))
	var scales := f(f(float(state.get("scale", 1))) * f(float(state.get("scale2", 1))))
	var stride := f(0.8) if creep else f(scales * f(float(state.walkDistance if int(state.animation) in [2, 3, 84, 85] else state.runDistance)))
	if stride <= 0:
		return 1.0
	var length_ms := f(f(clip_seconds) * 1000)
	var effective := f(rate * f(float(gait.factor))) if gait.script != 0 else rate
	var speed := f(f(effective / 1000) / f(f(stride * 1000) / length_ms))
	return speed if gait.script != 0 else f(speed * f(float(gait.acceleration)))
