extends Node

const Motion = preload("res://systems/network_motion.gd")
var client
var keys: Dictionary = {}
var input_owner := ""
var moving := false
var walk := false
var input_pending := false
var last_flags := 0
var last_at := -INF
var preview_at := -INF
var request_id := 0
var preview_request := -1
var preview_context: Dictionary = {}
var preview_retry := false
var preview_attempt := 0
var statistics := {"requested": 0, "retried": 0, "stale": 0, "applied": 0}
var require_focus := true

func context() -> Dictionary:
	if client == null or not client.world_scope.admitted or not client.motion.objects.has(client.controlled_id):
		return {}
	var state: Dictionary = client.motion.objects[client.controlled_id]
	return {"identity": "%s/%s/%s/%s" % [client.connection, client.world_scope.ticket, client.controlled_id, state.lifetime], "id": client.controlled_id, "state": state}

func enabled() -> bool:
	var focus := get_viewport().gui_get_focus_owner()
	return (not require_focus or get_window().has_focus()) and not (focus is LineEdit or focus is TextEdit)

func clear(send_stop: bool = true) -> void:
	var current := context()
	if not current.is_empty():
		current.state.driveHeld = false
		if moving and send_stop and str(current.identity) == input_owner:
			request_id += 1
			client.command({"kind": "drive", "actorId": current.id, "lifetime": int(current.state.lifetime), "requestId": request_id, "operation": "stop"})
	keys.clear()
	walk = false
	moving = false
	last_flags = 0
	input_pending = false
	last_at = -INF
	preview_at = -INF
	preview_request = -1
	preview_context.clear()
	preview_retry = false

static func flags(held: Dictionary, walking: bool) -> int:
	var forward := int(held.has(KEY_W) or held.has(KEY_UP)) - int(held.has(KEY_S) or held.has(KEY_DOWN))
	var strafe := int(held.has(KEY_Q)) - int(held.has(KEY_E))
	var turn := int(held.has(KEY_A) or held.has(KEY_LEFT)) - int(held.has(KEY_D) or held.has(KEY_RIGHT))
	return (1 if walking else 3) * int(forward > 0) | 2 * int(forward < 0) | 4 * int(strafe > 0) | 8 * int(strafe < 0) | 16 * int(turn > 0) | 32 * int(turn < 0)

func handle_key(code: int, pressed: bool, modifiers: bool = false) -> bool:
	if code == KEY_SHIFT:
		walk = pressed
		return false
	if code not in [KEY_W, KEY_S, KEY_A, KEY_D, KEY_Q, KEY_E, KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT]:
		return false
	if not pressed:
		if keys.has(code):
			keys.erase(code)
			update_input()
			return true
		return false
	var current := context()
	if current.is_empty() or not enabled() or modifiers:
		return false
	var focus := get_viewport().gui_get_focus_owner()
	if code in [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT] and (focus is BaseButton or focus is Range or focus is ItemList or focus is Tree or focus is TabBar):
		return false
	if input_owner != str(current.identity):
		clear(false)
		input_owner = str(current.identity)
	keys[code] = true
	input_pending = true # SDL repeated key-downs also refresh native input.
	update_input()
	return true

func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		var code := int(event.physical_keycode) if event.physical_keycode != 0 else int(event.keycode)
		if event.pressed and code != KEY_SHIFT:
			walk = event.shift_pressed
		if handle_key(code, event.pressed, event.alt_pressed or event.ctrl_pressed or event.meta_pressed):
			get_viewport().set_input_as_handled()

func update_input(now_ms: float = -1) -> void:
	var current := context()
	if current.is_empty():
		clear(false)
		input_owner = ""
		return
	if str(current.identity) != input_owner:
		clear(false)
		input_owner = str(current.identity)
	if not enabled():
		clear()
		return
	var value := flags(keys, walk)
	if value == 0:
		var held := keys.duplicate()
		var walking := walk
		clear()
		keys = held
		walk = walking
		return
	var now := Time.get_ticks_usec() / 1000.0 if now_ms < 0 else now_ms
	var turn_only := (value & 15) == 0
	var changed := input_pending or value != last_flags
	var send_due := changed or now - last_at >= (250 if turn_only else 500)
	var preview_due := changed or send_due or now - preview_at >= 250
	if not preview_due:
		if preview_retry:
			preview_retry = false
			preview_attempt += 1
			statistics.retried += 1
			request_id += 1
			var direction: Vector3 = current.state.orientation
			var retry_heading := int(round(fposmod(atan2(direction.y, direction.x) * 180.0 / PI, 360) * 10)) % 3600
			_submit_preview(current, value, retry_heading, false, true)
		return
	var state: Dictionary = current.state
	request_id += 1
	var forward: Vector3 = state.orientation
	if turn_only:
		if send_due:
			if moving:
				client.command({"kind": "drive", "actorId": current.id, "lifetime": int(state.lifetime), "requestId": request_id, "operation": "stop"})
			moving = false
			var angle := Motion.f(Motion.f(30.0 if value & 16 else -30.0) * Motion.f(0.017453292))
			var cosine := Motion.f(cos(angle))
			var sine := Motion.f(sin(angle))
			var turned := Motion.normalized32(Vector3(Motion.f(Motion.f(forward.x * cosine) - Motion.f(forward.y * sine)), Motion.f(Motion.f(forward.x * sine) + Motion.f(forward.y * cosine)), 0))
			client.command({"kind": "drive", "actorId": current.id, "lifetime": int(state.lifetime), "requestId": request_id, "operation": "turn", "position": [turned.x, turned.y]})
			client.motion.preview(int(current.id), {"animation": 2, "facing": [turned.x, turned.y, 0]}, state.position)
	else:
		preview_attempt = 0
		preview_retry = false
		var heading := int(round(fposmod(atan2(forward.y, forward.x) * 180.0 / PI, 360) * 10)) % 3600
		if send_due:
			var radians := (heading / 10.0) * 0.01745329238474369
			state.orientation = Motion.normalized32(Vector3(cos(radians), sin(radians), 0))
			state.targetOrientation = state.orientation
			state.previewFacing = state.orientation
		_submit_preview(current, value, heading, send_due, false)
		state.driveHeld = true
		moving = true
	last_flags = value
	input_pending = false
	if send_due:
		last_at = now
	preview_at = now

func _submit_preview(current: Dictionary, value: int, heading: int, transmit: bool, retry: bool) -> void:
	var state: Dictionary = current.state
	var forward: Vector3 = state.orientation
	var positions: Array = []
	for id in client.motion.objects:
		var other: Dictionary = client.motion.objects[id]
		if Motion.length32(other.render - state.render) < 12 and positions.size() < 128:
			positions.append({"id": id, "position": [other.render.x, other.render.y, other.render.z]})
	var request := {"kind": "drive-preview-request" if retry else "drive", "actorId": current.id, "lifetime": int(state.lifetime), "requestId": request_id, "operation": "drive", "position": [state.position.x, state.position.y, state.position.z], "render": [state.render.x, state.render.y, state.render.z], "orientation": [forward.x, forward.y, forward.z], "heading": heading, "flags": value, "transmit": transmit, "poses": positions}
	preview_request = request_id
	preview_context = {"identity": input_owner, "position": state.position, "render": state.render, "orientation": forward}
	statistics.requested += 1
	client.command(request)

func result(message: Dictionary) -> void:
	var current := context()
	if current.is_empty() or int(message.actorId) != int(current.id) or int(message.lifetime) != int(current.state.lifetime):
		return
	if message.kind == "drive-ack":
		if message.has("sequence"):
			current.state.driveSequence = int(message.sequence)
		return
	if int(message.requestId) != preview_request or input_owner != str(current.identity) or not enabled() or last_flags == 0:
		return
	preview_request = -1
	var state: Dictionary = current.state
	if state.position != preview_context.position or state.render != preview_context.render or state.orientation != preview_context.orientation:
		statistics.stale += 1
		preview_retry = preview_attempt < 2 # Original scene bounds one input tick to three attempts.
		return
	if message.get("result") == null:
		return
	var result: Dictionary = message.result
	statistics.applied += 1
	var plan: Dictionary = result.plan
	if result.path != null:
		plan.factor = result.path.factor
		client.motion.preview(int(current.id), plan, result.path.target)
		if result.path.has("resendFraction"):
			last_at = Time.get_ticks_usec() / 1000.0 - (500000 - int(Motion.f(float(result.path.resendFraction)) * 500000)) / 1000.0
	else:
		client.motion.preview(int(current.id), plan)

