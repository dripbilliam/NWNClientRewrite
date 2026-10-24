extends SceneTree

const Radial = preload("res://systems/server_radial.gd")
const Targeting = preload("res://systems/server_targeting.gd")
const Cursor = preload("res://systems/server_cursor.gd")
const WorldInput = preload("res://systems/world_input.gd")
const Camera = preload("res://systems/camera_controller.gd")
const Connection = preload("res://systems/local_connection.gd")
const Main = preload("res://main.gd")
var checks := 0
var failures: Array[String] = []
var sent: Array = []
var output := ""

class Probe extends Connection:
	var commands: Array = []
	func send(message: Dictionary) -> void:
		commands.append(message.duplicate(true))

class Registry extends Node3D:
	var entities := {7: {"eligible": true}}
	var points: Array = []
	func pick(_camera: Camera3D, point: Vector2) -> Dictionary:
		points.append(point)
		return {"id": 7, "position": Vector3(1, 2, 3), "entity": entities[7]}
	func eligible_ids() -> Array:
		return [7]
	func mark(_ids: Array) -> void:
		pass

class Interface extends RefCounted:
	var current_id := -1
	func blocks_pointer(_point: Vector2) -> bool:
		return false
	func labels(_ids: Array) -> void:
		pass

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, name: String) -> void:
	checks += 1
	if not value and failures.size() < 30:
		failures.append(name)

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):
			output = arg.substr(9)
	if output.is_empty() or FileAccess.file_exists(output):
		quit(2)
		return
	var oracle: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://reports/authored-radial-hit-v1.json"))
	for row in oracle.cases:
		var result := Radial.hit(Vector2(row.point[0], row.point[1]))
		check(result.zone == row.expected.zone, "Original-derived pixel selection band %s" % [row.point])
		check(result.slot == int(row.expected.octant), "Original-derived physical octant %s" % [row.point])
	var radial := Radial.new()
	root.add_child(radial)
	radial.request.connect(func(message): sent.append(message))
	radial.open_at(Vector2(700, 400), 7, Vector3(1, 2, 3))
	check(radial.layer > 20 and radial.active, "Native wheel lives above HUD, conversation, examine and lobby layers")
	check(radial.stage.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Radial background has no invisible rectangular click shield")
	check(sent.back().targetId == 7 and sent.back().position == [1.0, 2.0, 3.0], "Context open keeps the actual picked target and world point")
	var request_id := radial.request_id
	var entries := [{"slot": 0, "label": "Examine", "disabled": false}, {"slot": 1, "label": "Cast spell", "submenu": true}, {"slot": 2, "label": "Unavailable", "disabled": true, "uses": 0}]
	radial.receive({"kind": "action-menu", "requestId": request_id, "menuId": 1, "title": "NPC", "depth": 0, "entries": entries})
	check(radial.buttons[0].visible and not radial.buttons[7].visible and radial.buttons[2].disabled, "Physical holes, disabled entries and all source slots remain intact")
	check(radial.counts[2].text == "0", "Zero available uses remain visible independently of caption wrapping")
	var count := sent.size()
	radial.choose(2)
	check(sent.size() == count, "A disabled action cannot dispatch")
	radial.choose(1)
	check(sent.back().kind == "radial-select" and sent.back().menuId == 1 and sent.back().slot == 1, "Selection sends menu identity and physical slot instead of a fabricated action binding")
	radial.choose(0)
	check(sent.size() == count + 1, "Pending selection suppresses duplicate button events")
	radial.receive({"kind": "action-menu", "requestId": request_id, "menuId": 2, "title": "Family", "depth": 4, "entries": [{"slot": 0, "label": "Good"}, {"slot": 1, "label": "Evil"}, {"slot": 2, "label": "Law"}, {"slot": 3, "label": "Chaos"}]})
	check(radial.depth == 4 and radial.captions[3].text == "Chaos" and not radial.pending, "A deep spell-family page preserves every child and returns control after its response")
	var image := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	image.fill(Color.GREEN)
	var png := "data:image/png;base64," + Marshalls.raw_to_base64(image.save_png_to_buffer())
	radial.receive({"kind": "action-icon", "requestId": request_id, "menuId": 1, "slot": 0, "image": png})
	check(radial.icons[0].texture == null, "Old submenu icon completion cannot decorate a new child")
	radial.receive({"kind": "action-icon", "requestId": request_id, "menuId": 2, "slot": 0, "image": png})
	check(radial.icons[0].texture != null, "Transient original-icon PNGs can be used by native action buttons")
	radial.back()
	check(sent.back().kind == "radial-back" and sent.back().menuId == 2, "Center navigation asks the owning backend to restore the prior menu")
	var w := InputEventKey.new()
	w.keycode = KEY_W
	w.pressed = true
	count = sent.size()
	radial._input(w)
	check(radial.active and sent.size() == count, "The radial leaves WASD movement keys available")
	var position := radial.origin
	check(radial.blocks_pointer(position) and not radial.blocks_pointer(position + Vector2(185, 185)), "Visible circular wheel blocks its own surface but transparent rectangle corners remain world input")
	var outside := InputEventMouseButton.new()
	outside.button_index = MOUSE_BUTTON_LEFT
	outside.pressed = true
	outside.position = Vector2(10, 10)
	radial._input(outside)
	check(not radial.active and sent.back().kind == "radial-cancel", "A world click cancels the wheel without becoming a radial choice")
	radial.open_at(Vector2(700, 400), null, Vector3(1, 2, 3))
	radial.receive({"kind": "action-close", "requestId": request_id})
	check(radial.active, "An old root's completion cannot close a newer wheel")
	var targeter := Targeting.new()
	targeter.request.connect(func(message): sent.append(message))
	targeter.receive({"kind": "target-mode", "token": 3, "active": true})
	targeter.hover({"id": 7})
	targeter.receive({"kind": "target-hover", "token": 3, "targetId": 8, "presentation": {"cursor": 31}})
	check(targeter.presentation.is_empty(), "Target validity for a previous hover cannot replace the current hover")
	targeter.receive({"kind": "target-hover", "token": 3, "targetId": 7, "presentation": {"cursor": 31}})
	check(targeter.presentation.cursor == 31, "Current invalid-target cursor comes from the original policy")
	targeter.choose({"id": 7, "position": Vector3(4, 2, -5)})
	check(sent.back().kind == "target-select" and sent.back().position == [4.0, 2.0, -5.0], "Native target click sends the picked point, independently of world navigation")
	count = sent.size()
	targeter.choose({"id": 7, "position": Vector3.ZERO})
	check(sent.size() == count, "Pending target click cannot dispatch twice")
	targeter.receive({"kind": "target-error", "token": 3})
	check(targeter.active and not targeter.pending, "Invalid target feedback permits another selection")
	targeter.cancel()
	check(not targeter.active and sent.back().kind == "target-cancel", "Cancel leaves targeting without walking or acting on an object")
	targeter.reset(true)
	targeter.receive({"kind": "target-mode", "token": 1, "active": true})
	check(targeter.active, "A new connection can reuse low token values after reset")
	var cursor := Cursor.new()
	cursor.request.connect(func(message): sent.append(message))
	cursor.select(11)
	check(sent.back() == {"kind": "cursor-request", "cursorId": 11}, "NWN cursor resources are loaded by their original numeric ID")
	cursor.receive({"cursorId": 11, "image": png})
	cursor.select(11, true)
	check(cursor.desired == 12 and sent.back().cursorId == 12, "Original up/down cursor pairs follow mouse button state")
	cursor.select(59, true)
	check(cursor.desired == 59, "Directional cursors do not use the up/down-pair transformation")
	cursor.reset(true)
	check(cursor.desired == -1 and cursor.textures.is_empty() and cursor.pending.is_empty(), "New resource context releases cursor textures and pending requests")
	var host := Main.new()
	root.add_child(host)
	var client := Probe.new()
	host.add_child(client)
	client.set_process(false)
	client.owner_scene = host
	client._make_ui()
	client.generation = 1
	client.area_id = 9
	client.targeting.receive({"kind": "target-mode", "token": 3, "active": true})
	client._world_action({"id": 7, "entity": {"eligible": true}, "position": Vector3.ZERO})
	check(client.commands.size() == 1 and client.commands[0].kind == "target-select", "An actual native world action routes into targeting and cannot silently become click-move/interact")
	var registry := Registry.new()
	host.add_child(registry)
	var view := Camera3D.new()
	host.add_child(view)
	view.position = Vector3(0, 10, 10)
	var world_input := WorldInput.new()
	host.add_child(world_input)
	world_input.set_physics_process(false)
	world_input.configure(registry, view, Interface.new())
	world_input.context_action = func(hit, point): sent.append({"kind": "context-pick", "id": hit.id, "point": point})
	var right := InputEventMouseButton.new()
	right.pressed = true
	right.button_index = MOUSE_BUTTON_RIGHT
	right.position = Vector2(650, 400)
	world_input._unhandled_input(right)
	world_input._physics_process(0.02)
	check(registry.points.back() == right.position and sent.back().point == right.position, "Right-click picks the original press point, even when physics runs after the pointer moved")
	var camera := Camera.new()
	host.add_child(camera)
	camera.configure(view, Vector3.ZERO)
	var middle := InputEventMouseButton.new()
	middle.button_index = MOUSE_BUTTON_MIDDLE
	middle.pressed = true
	camera._input(middle)
	check(camera.dragging and radial.active, "Middle-mouse orbit remains independent of the always-on-top native wheel")
	middle.pressed = false
	camera._input(middle)
	radial.queue_free()
	host.queue_free()
	await process_frame
	var file := FileAccess.open(output, FileAccess.WRITE)
	file.store_string(JSON.stringify({"scope": "Native radial/input/target/cursor authored checks and retained-source pixel-band oracle; not full gameplay, visual or FPS acceptance", "checks": checks, "failures": failures, "pixel_cases": oracle.cases.size()}, "  "))
	file.close()
	print(JSON.stringify({"checks": checks, "failures": failures, "report": output}))
	quit(0 if failures.is_empty() else 1)
