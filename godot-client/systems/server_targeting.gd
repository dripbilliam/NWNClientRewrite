extends RefCounted

signal request(message: Dictionary)
var active := false
var token := -1
var pending := false
var mode: Dictionary = {}
var presentation: Dictionary = {}
var hover_id: Variant = null
var hover_at := 0

func reset(new_world: bool = false) -> void:
	if new_world:
		token = -1
	active = false
	pending = false
	mode.clear()
	presentation.clear()
	hover_id = null
	hover_at = 0

func receive(message: Dictionary) -> void:
	if message.kind == "target-mode":
		if int(message.token) < token:
			return
		token = int(message.token)
		reset()
		active = bool(message.active)
		mode = message.duplicate()
	elif int(message.get("token", -1)) == token:
		if message.kind == "target-hover" and message.get("targetId") == hover_id:
			if message.get("presentation") == null:
				reset()
			else:
				presentation = message.presentation
		elif message.kind == "target-error":
			pending = false

func hover(hit: Dictionary) -> int:
	if not active:
		return -1
	var id: Variant = hit.get("id") if int(hit.get("id", -1)) >= 0 else null
	var now := Time.get_ticks_msec()
	if id != hover_id or hover_at == 0 or now - hover_at >= 100:
		hover_id = id
		hover_at = now
		request.emit({"kind": "target-hover", "token": token, "targetId": id})
	return int(presentation.get("cursor", mode.get("cursor", 29)))

func choose(hit: Dictionary) -> void:
	if not active or pending or not hit.has("position"):
		return
	var point: Vector3 = hit.position
	pending = true
	request.emit({"kind": "target-select", "token": token, "targetId": hit.id if int(hit.get("id", -1)) >= 0 else null, "position": [point.x, point.y, point.z]})

func cancel() -> void:
	if active:
		request.emit({"kind": "target-cancel", "token": token})
	reset()
