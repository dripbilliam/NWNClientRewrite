extends SceneTree
const Inventory = preload("res://systems/server_inventory.gd")
const Quickbar = preload("res://systems/server_quickbar.gd")
var checks := 0
var failures: Array = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, name: String) -> void:
	checks += 1
	if not ok: failures.append(name)
func motion(point: Vector2, relative: Vector2, held: bool) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point; event.global_position = point; event.relative = relative
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if held else 0
	root.push_input(event, true)
	await process_frame
func mouse(point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = point; event.global_position = point; event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed; event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	root.push_input(event, true)
	await process_frame
func run() -> void:
	var output := ""; var fixture := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output = arg.trim_prefix("--report=")
		elif arg.begins_with("--fixture="): fixture = arg.trim_prefix("--fixture=")
	if output.is_empty() or fixture.is_empty() or FileAccess.file_exists(output): quit(2); return
	root.size = Vector2i(1440, 1000)
	var panel := Inventory.new(); panel.setup(""); root.add_child(panel)
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(fixture)); panel.open(); panel.receive(data)
	var bar := Quickbar.new(); root.add_child(bar); bar.setup(); bar.inventory_valid = panel.can_shortcut
	var sent: Array = []; bar.request.connect(func(value): sent.append(value))
	var rows: Array = []
	for index in 36: rows.append({"index":index,"label":"Empty shortcut","empty":true,"enabled":false,"uses":null})
	bar.receive({"kind":"quickbar-view","quickbarId":7,"rows":rows}); bar.render(2)
	await process_frame; await process_frame
	var payload := {"kind":"native-inventory-item","viewId":panel.view_id,"entryId":0}
	var slot: Button = bar.buttons[35]
	check(panel.can_shortcut(payload) and slot._can_drop_data(Vector2.ZERO, payload), "Owned backpack items can be dropped on the third native shortcut page")
	slot._drop_data(Vector2.ZERO, payload)
	check(sent.size() == 1 and sent[0] == {"kind":"inventory-shortcut","quickbarId":7,"viewId":1,"entryId":0,"index":35}, "Drop sends only both private owners and the destination, without item IDs or forged bindings")
	var origin: Vector2 = panel.buttons[0].get_global_rect().get_center()
	var destination: Vector2 = slot.get_global_rect().get_center()
	check(root.get_visible_rect().has_point(origin) and root.get_visible_rect().has_point(destination), "Source item and destination shortcut are inside the native viewport")
	await motion(origin, Vector2.ZERO, false)
	await mouse(origin, true)
	await motion(origin + Vector2(20,0), Vector2(20,0), true)
	await motion(destination, destination - origin - Vector2(20,0), true)
	check(root.gui_is_dragging(), "Synthetic native pointer press and motion start Godot's actual inventory drag")
	await mouse(destination, false)
	check(sent.size() == 2 and sent.back() == sent[0] and not root.gui_is_dragging(), "Godot's GUI drop dispatch assigns the same owned item and ends its drag")
	payload.entryId = 1; check(panel.can_shortcut(payload), "Equipped owned items are also valid shortcut sources")
	var row: Dictionary = panel.items[1]
	for channel in ["C", "M"]:
		row.channel = channel; check(not panel.can_shortcut(payload) and not slot._can_drop_data(Vector2.ZERO,payload), "Foreign %s contents cannot become owned item shortcuts" % channel)
	row.channel = "I"; row.pending = true
	check(not panel.can_shortcut(payload), "An item awaiting a transfer cannot start another shortcut assignment")
	row.pending = false; payload.entryId = 0; payload.viewId = 0
	check(not slot._can_drop_data(Vector2.ZERO,payload), "A drag from a retired inventory view is rejected")
	payload.viewId = panel.view_id
	bar.receive({"kind":"quickbar-view","quickbarId":8,"rows":rows})
	var before: int = sent.size(); slot._drop_data(Vector2.ZERO,payload)
	check(sent.size() == before, "A retained old shortcut button cannot submit into its replacement owner")
	panel.reset(); bar.render(2)
	check(not bar.buttons[35]._can_drop_data(Vector2.ZERO,payload), "Closing inventory retires its outstanding native drag")
	bar.reset(); panel.free(); bar.free(); await process_frame; await process_frame
	var file := FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"checks":checks,"passed":failures.is_empty(),"failures":failures,"scope":"Authored native inventory/shortcut ownership and synthetic viewport mouse drag/drop; actual server activation checked separately; no physical-device acceptance"},"\t"));file.close();quit(0 if failures.is_empty() else 1)
