extends Node

var camera: Camera3D
var target := Vector3.ZERO
var distance := 20.0
var yaw := 0.0
var pitch := 0.7
var dragging := false
var home: Transform3D
var home_target: Vector3
var old_mouse_mode := Input.MOUSE_MODE_VISIBLE
var keyboard_pan := true
var follow_state
var camera_keys: Dictionary = {}
var view_updates := 0
var follow_height := NAN

func enable_follow(mode: int, position: Vector3, height: float = 1.0, remembered: Dictionary = {}, persistent: Variant = null) -> void:
	if persistent != null:
		follow_state = persistent
		follow_state.set_height(height,true)
		if follow_state.state.get("position") == null:
			follow_state.state.focus = [follow_state.add(position.x,follow_state.state.offset[0]),follow_state.add(-position.z,follow_state.state.offset[1]),follow_state.add(position.y,follow_state.state.offset[2])]
	else:
		follow_state = preload("res://systems/game_camera_state.gd").new()
		follow_state.reset(mode,height,[position.x,-position.z,position.y],rad_to_deg(yaw))
		follow_state.state.pitch = follow_state.f(90-rad_to_deg(pitch))
		follow_state.state.distance = follow_state.f(distance)
		if remembered.get("mode",-1) == mode:
			for key in ["yaw","pitch","distance"]: follow_state.state[key] = remembered[key]
		follow_state.state.quaternion = follow_state.quaternion(follow_state.state.yaw,follow_state.state.pitch)
	keyboard_pan = false
	follow_height = height
	camera_keys.clear()

func set_follow_mode(mode: int) -> bool:
	return follow_state.set_mode(mode) if follow_state != null else false

func remembered_pose() -> Dictionary:
	if follow_state == null: return {}
	var s: Dictionary = follow_state.state
	return {"mode":s.mode,"yaw":s.yaw,"pitch":s.pitch,"distance":s.distance}

func follow_frame(position: Vector3, facing: float, animation: int, delta: float, height: float = 1.0) -> void:
	if follow_state == null: return
	if follow_height != height: follow_state.set_height(height,true); follow_height = height
	var focus := get_viewport().gui_get_focus_owner()
	if focus is LineEdit or focus is TextEdit: camera_keys.clear()
	var turn := (float(camera_keys.has(KEY_HOME))-float(camera_keys.has(KEY_END)))*75
	var tilt := (float(camera_keys.has(KEY_INSERT))-float(camera_keys.has(KEY_DELETE)))*75
	var wheel := (float(camera_keys.has(KEY_PAGEUP))-float(camera_keys.has(KEY_PAGEDOWN)))*7.5
	follow_state.rate(follow_state.state,"yaw",turn); follow_state.rate(follow_state.state,"pitch",tilt)
	if wheel != 0: follow_state.input({"zoom":wheel})
	if not follow_state.update({"position":[position.x,-position.z,position.y],"facing":facing,"animation":animation},delta): return
	var s: Dictionary = follow_state.state; var p: Array = s.position; var q: Array = s.quaternion; var center: Array = s.focus
	var view := Transform3D(Basis(Quaternion(Vector3.RIGHT,-PI/2)*Quaternion(q[1],q[2],q[3],q[0])),Vector3(p[0],p[2],-p[1]))
	if camera.global_transform != view:
		camera.global_transform = view
		view_updates += 1
	target = Vector3(center[0],center[2],-center[1]); distance = s.distance; yaw = deg_to_rad(s.yaw); pitch = deg_to_rad(90-s.pitch)

func follow_valid(position: Vector3) -> bool:
	if follow_state == null or follow_state.state.get("position") == null: return false
	var desired := position + Vector3.UP*float(follow_state.state.height)
	var direction := (target-camera.global_position).normalized()
	return target.distance_to(desired) < 0.05 and -camera.global_basis.z.dot(direction) > 0.999

func configure(value: Camera3D, focus: Vector3) -> void:
	camera = value
	target = focus
	home = camera.global_transform
	home_target = focus
	_read_pose()

func _read_pose() -> void:
	var offset := camera.global_position - target
	distance = maxf(0.01, offset.length())
	yaw = atan2(offset.x, offset.z)
	pitch = asin(clampf(offset.y / distance, -1.0, 1.0))

func _input(event: InputEvent) -> void:
	if camera == null:
		return
	if follow_state != null and event is InputEventKey and event.keycode in [KEY_HOME,KEY_END,KEY_INSERT,KEY_DELETE,KEY_PAGEUP,KEY_PAGEDOWN]:
		if not event.pressed: camera_keys.erase(event.keycode)
		else:
			var focus := get_viewport().gui_get_focus_owner()
			if not event.echo and not event.ctrl_pressed and not event.alt_pressed and not event.meta_pressed and not focus is LineEdit and not focus is TextEdit:
				camera_keys[event.keycode] = true
				get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_MIDDLE:
		dragging = event.pressed
		if dragging:
			old_mouse_mode = Input.mouse_mode
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		else:
			Input.mouse_mode = old_mouse_mode
	elif event is InputEventMouseMotion and dragging:
		orbit(event.relative)

func _unhandled_input(event: InputEvent) -> void:
	if camera == null:
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom(1.0 / 1.12)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom(1.12)
	if follow_state == null and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_HOME:
		reset()

func _process(delta: float) -> void:
	if camera == null or not keyboard_pan or not get_window().has_focus():
		return
	var focus := get_viewport().gui_get_focus_owner()
	if focus is LineEdit or focus is TextEdit:
		return
	var axis := Vector2(float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)), float(Input.is_physical_key_pressed(KEY_W)) - float(Input.is_physical_key_pressed(KEY_S)))
	if axis != Vector2.ZERO:
		pan(axis, minf(delta, 0.1), Input.is_physical_key_pressed(KEY_SHIFT))

func pan(axis: Vector2, delta: float, fast: bool = false) -> void:
	var forward := target - camera.global_position
	forward.y = 0
	forward = forward.normalized()
	var right := forward.cross(Vector3.UP)
	var offset := (right * axis.normalized().x + forward * axis.normalized().y) * delta * (20.0 if fast else 7.0)
	target += offset
	camera.global_position += offset

func orbit(relative: Vector2) -> void:
	if follow_state != null:
		follow_state.input(follow_state.pointer(relative.x,relative.y,maxf(1,get_viewport().get_visible_rect().size.x)))
		# Public input diagnostics expose the queued yaw; the quaternion changes
		# only when the original Follow step consumes that impulse next frame.
		yaw = deg_to_rad(float(follow_state.state.yaw)+float(follow_state.state.turnDelta))
		return
	yaw -= relative.x * 0.006
	pitch = clampf(pitch + relative.y * 0.006, deg_to_rad(10), deg_to_rad(85))
	_apply()

func zoom(factor: float) -> void:
	if follow_state != null:
		follow_state.input({"zoom":7.5 if factor < 1 else -7.5})
		return
	distance = clampf(distance * factor, 2.0, 140.0)
	_apply()

func _apply() -> void:
	camera.global_position = target + Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * distance
	camera.look_at(target, Vector3.UP)

func reset() -> void:
	target = home_target
	camera.global_transform = home
	_read_pose()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		camera_keys.clear()
		if dragging:
			dragging = false
			Input.mouse_mode = old_mouse_mode
