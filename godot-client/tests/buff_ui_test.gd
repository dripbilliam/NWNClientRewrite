extends SceneTree
const Bar = preload("res://systems/server_buffs.gd")
const Lobby = preload("res://systems/character_lobby.gd")
var checks := 0
var failures: Array = []
class WorldClicks extends Node:
	var clicks := 0
	func _unhandled_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed: clicks += 1
func _initialize() -> void: call_deferred("run")
func check(value: bool, name: String) -> void:
	checks += 1
	if not value: failures.append(name)
func click(point: Vector2) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new(); event.button_index = MOUSE_BUTTON_LEFT; event.pressed = pressed; event.position = point; event.global_position = point
		root.push_input(event, true); await process_frame
func view(bar, id: int, values: Array) -> void:
	bar.receive({"kind":"buff-begin","viewId":id,"actorId":9,"count":values.size()}); bar.receive({"kind":"buff-rows","viewId":id,"rows":values}); bar.receive({"kind":"buff-commit","viewId":id})
func run() -> void:
	var output := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output = arg.substr(9)
	if output.is_empty() or FileAccess.file_exists(output): quit(2); return
	root.size = Vector2i(1000, 800)
	var layer := CanvasLayer.new(); root.add_child(layer)
	var lobby := Lobby.new(); root.add_child(lobby); lobby.apply_state({"connection":1,"state":{"phase":"playing","connected":true}})
	var bar := Bar.new(); layer.add_child(bar); bar.setup()
	var world := WorldClicks.new(); root.add_child(world)
	view(bar, 1, [{"id":0,"state":0},{"id":1,"state":1}]); await process_frame; await process_frame
	check(bar.visible and bar.buttons.size() == 2 and bar.rows[0].state == 0, "Both server Boolean states produce visible native status slots")
	var first = bar.buttons[0]; var identity: int = first.get_instance_id()
	bar.receive({"kind":"buff-description","viewId":1,"effectId":0,"label":"Authored blessing"})
	var pixels := Image.create(32, 32, false, Image.FORMAT_RGBA8); pixels.fill(Color.GREEN)
	var image := "data:image/png;base64," + Marshalls.raw_to_base64(pixels.save_png_to_buffer())
	bar.receive({"kind":"buff-icon","viewId":1,"effectId":0,"resource":"authored_icon","image":image})
	check(first.get_node("Icon").texture.get_size() == Vector2(32, 32) and first.text.is_empty(), "Decoded status artwork fills the original 32-pixel icon area")
	var at: Vector2 = first.get_global_rect().get_center(); check(bar.blocks_pointer(at) and not bar.blocks_pointer(Vector2(10, 600)), "Only status slots block world input")
	await click(at); await process_frame
	check(bar.pinned and bar.tip.visible and bar.tip_text.text == "Authored blessing", "Actual native GUI click pins the resolved status tooltip")
	check(world.clicks == 0, "Clicking a status icon never becomes a world action")
	await click(bar.buttons[1].get_global_rect().get_center()); await process_frame
	check(bar.pinned and bar.pinned_id == 1 and not lobby.panel.visible, "A second status icon is clickable through the real connection-menu overlay and switches the pinned owner")
	await click(at); await process_frame
	check(Rect2(Vector2.ZERO, Vector2(root.size)).encloses(bar.tip.get_global_rect()) and bar.tip.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Status tooltip stays in the viewport and does not intercept input")
	view(bar, 2, [{"id":0,"state":1},{"id":1,"state":1}]); await process_frame
	check(bar.buttons[0].get_instance_id() == identity and bar.rows[0].state == 1 and bar.images.has(0), "A server state change retains the button, artwork and pinned tooltip owner")
	bar.receive({"kind":"buff-description","viewId":1,"effectId":0,"label":"Old reply"})
	check(bar.rows[0].label == "Authored blessing", "An old view cannot replace the current tooltip text")
	await click(Vector2(10, 600)); check(not bar.tip.visible and world.clicks > 0, "Outside click dismisses status text and still reaches world input")
	await click(at); var escape := InputEventKey.new(); escape.keycode = KEY_ESCAPE; escape.pressed = true; root.push_input(escape, true); await process_frame
	check(not bar.tip.visible, "Escape dismisses the status tooltip")
	view(bar, 3, [{"id":1,"state":1}]); await process_frame
	check(not bar.buttons.has(0) and not bar.images.has(0) and not bar.tip.visible, "Only explicit list removal retires a status slot and its original texture")
	bar.receive({"kind":"buff-icon","viewId":2,"effectId":0,"image":image})
	check(not bar.images.has(0), "A late icon cannot resurrect a removed status")
	var many: Array = []
	for id in 400: many.append({"id":id,"state":0})
	view(bar, 4, many); await process_frame; await process_frame
	bar.scroll.scroll_vertical = 100000; await process_frame; await process_frame
	var last: Vector2 = bar.buttons[399].get_global_rect().get_center()
	check(bar.buttons.size() == 400 and bar.scroll.get_global_rect().has_point(last) and not bar.blocks_pointer(bar.buttons[0].get_global_rect().get_center()), "A large status list scrolls to its last original index without offscreen input blocking")
	await click(last); await process_frame
	check(bar.pinned and bar.tip_text.text == "Effect 399", "Scrolled status buttons retain their correct original ID and tooltip")
	root.size = Vector2i(320, 240); await process_frame; await process_frame
	check(bar.get_global_rect().end.x <= 320 and bar.get_global_rect().end.y <= 240 and bar.size.y <= 72, "Status wrapping and scrolling adapt to a narrow resized viewport")
	first = null; bar.reset(); await process_frame; await process_frame
	check(bar.buttons.is_empty() and bar.images.is_empty() and bar.retired_alive() == 0, "Connection reset releases native status buttons and images")
	bar.free(); world.free(); layer.free(); lobby.free(); await process_frame
	var file := FileAccess.open(output, FileAccess.WRITE); file.store_string(JSON.stringify({"checks":checks,"passed":failures.is_empty(),"success":failures.is_empty(),"failures":failures},"\t")); file.close(); quit(0 if failures.is_empty() else 1)
