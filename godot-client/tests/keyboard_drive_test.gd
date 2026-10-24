extends SceneTree

const Driver = preload("res://systems/keyboard_drive.gd")
class Client extends Node:
	var connection := 1
	var controlled_id := 1
	var world_scope = preload("res://systems/world_scope.gd").new()
	var motion = preload("res://systems/network_motion.gd").new()
	var requests: Array = []
	func command(value: Dictionary) -> void:
		requests.append(value)

var checks := 0
var failures: Array = []
var output := ""

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, name: String) -> void:
	checks += 1
	if not value and failures.size() < 20:
		failures.append(name)

func setup() -> Array:
	var client := Client.new()
	root.add_child(client)
	client.world_scope.reset(1)
	var scope := {"connection": 1, "transferId": 1, "areaId": 1, "generation": 1}
	client.world_scope.begin(scope)
	client.world_scope.admit(scope)
	client.motion.ensure(1, {"position": [10, 20, 0], "orientation": [1, 0, 0], "animation": 0, "walkRate": 2200, "runRate": 4400})
	var input := Driver.new()
	input.client = client
	input.require_focus = false
	client.add_child(input)
	input.input_owner = input.context().identity
	return [client, input]

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):
			output = arg.substr(9)
	if output.is_empty() or FileAccess.file_exists(output):
		quit(2)
		return
	var oracle: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://../backups/animations/native-drive-input-timing-v1.json")))
	var index := 0
	for row in oracle.cases:
		var pair := setup()
		var client: Client = pair[0]
		var input = pair[1]
		var c: Dictionary = row.case
		input.last_flags = 0 if c.dirty else int(c.flags)
		input.last_at = 10000 - float(c.wireAgo) / 1000.0
		input.preview_at = 10000 - float(c.previewAgo) / 1000.0
		for code in ([KEY_W] if c.flags == 3 else ([KEY_Q] if c.flags == 4 else ([KEY_E] if c.flags == 8 else [KEY_Q, KEY_A]))):
			input.keys[code] = true
		input.update_input(10000)
		var drives: Array = client.requests.filter(func(request): return request.operation == "drive")
		check(drives.filter(func(request): return request.transmit).size() == row.calls.filter(func(call): return call.kind == "drive").size(), "native wire schedule %s" % index)
		check((int(c.lastSequence) + drives.size()) & 255 == int(row.sequence), "native local sequence advance %s" % index)
		check(int(round(input.last_at * 1000)) == int(row.lastWire), "native wire timestamp %s" % index)
		check(int(round(input.preview_at * 1000)) == int(row.lastPreview), "native preview timestamp %s" % index)
		client.free()
		index += 1
	var pair := setup()
	var client: Client = pair[0]
	var input = pair[1]
	input.handle_key(KEY_W, true)
	var first := client.requests.size()
	input.handle_key(KEY_W, true)
	check(client.requests.size() == first + 1 and client.requests[-1].transmit, "repeated key-down refreshes held drive immediately")
	input.handle_key(KEY_W, false)
	check(client.requests[-1].operation == "stop" and input.keys.is_empty(), "release sends native abort and clears preview ownership")
	input.handle_key(KEY_W, true)
	input.handle_key(KEY_S, true)
	check(input.keys.has(KEY_W) and input.keys.has(KEY_S) and not input.moving, "opposing input stops without losing held keys")
	input.handle_key(KEY_S, false)
	check(input.moving and client.requests[-1].flags == 3, "releasing opposed key resumes the remaining held direction")
	input.clear()
	input.handle_key(KEY_A, true)
	check(client.requests[-1].operation == "turn" and not input.moving, "A uses original character-turn protocol")
	input.clear()
	input.handle_key(KEY_SHIFT, true)
	input.handle_key(KEY_Q, true)
	input.handle_key(KEY_W, true)
	check(client.requests[-1].flags == 5, "walk plus strafe retains original bit flags")
	input.clear()
	var canvas := CanvasLayer.new()
	client.add_child(canvas)
	var Panel = preload("res://systems/draggable_panel.gd")
	for i in 2:
		var panel := Panel.new()
		panel.configure("Authored menu", "drive-test-%s" % i, Vector2(i * 300, 100), "user://authored-drive-layout.cfg")
		canvas.add_child(panel)
		panel.show()
	input.handle_key(KEY_W, true)
	check(input.moving, "two open movable menus do not block movement keys")
	var entry := LineEdit.new()
	canvas.add_child(entry)
	entry.grab_focus()
	input.update_input()
	check(not input.moving and input.keys.is_empty() and client.requests[-1].operation == "stop", "text focus releases held movement through native abort")
	entry.release_focus()
	input.update_input()
	check(not input.moving, "leaving text focus does not resurrect a swallowed held key")
	input.handle_key(KEY_W, true)
	var stale_id := int(input.preview_request)
	input.handle_key(KEY_W, false)
	var previous_path: Array = client.motion.objects[1].path.duplicate()
	input.result({"kind": "drive-preview", "actorId": 1, "lifetime": 1, "requestId": stale_id, "result": {"plan": {"animation": 4, "facing": [1, 0, 0]}, "path": {"target": [20, 20, 0], "factor": 1}}})
	check(client.motion.objects[1].path == previous_path, "late geometry cannot rearm released input")
	client.free()
	var file := FileAccess.open(output, FileAccess.WRITE)
	file.store_string(JSON.stringify({"scope": "Native input scheduler against 192 retained original UI schedules plus authored menu/focus/release cases; no live server or FPS claim", "checks": checks, "failures": failures}, "  "))
	file.close()
	print(JSON.stringify({"checks": checks, "failures": failures, "report": output}))
	quit(0 if failures.is_empty() else 1)
