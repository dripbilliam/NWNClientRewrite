extends SceneTree

const Radial = preload("res://systems/server_radial.gd")
const Quickbar = preload("res://systems/server_quickbar.gd")
var checks := 0
var failures: Array = []

func _initialize() -> void: call_deferred("run")
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)
func motion(point: Vector2, relative: Vector2, held: bool) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point; event.global_position = point; event.relative = relative
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if held else 0
	root.push_input(event, true); await process_frame
func mouse(point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = point; event.global_position = point; event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed; event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	root.push_input(event, true); await process_frame
func run() -> void:
	var output := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output = arg.trim_prefix("--report=")
	if output.is_empty() or FileAccess.file_exists(output): quit(2); return
	root.size = Vector2i(1440,1000)
	var radial := Radial.new(); root.add_child(radial)
	var bar := Quickbar.new(); root.add_child(bar); bar.setup(); bar.radial_valid = radial.can_shortcut
	var sent: Array = []; var actions: Array = []
	bar.request.connect(func(value): sent.append(value)); radial.request.connect(func(value): actions.append(value))
	var rows: Array = []
	for index in 36: rows.append({"index":index,"label":"Empty shortcut","empty":true,"enabled":false,"uses":null})
	bar.receive({"kind":"quickbar-view","quickbarId":7,"rows":rows}); bar.pages[2].pressed.emit()
	radial.open_at(Vector2(500,350),null,Vector3.ZERO,false)
	var request_id: int = radial.request_id
	var entries: Array = JSON.parse_string(JSON.stringify([{"slot":0,"label":"Family parent","submenu":true,"canDrag":true},{"slot":1,"label":"Protection from Evil","canDrag":true,"uses":3},{"slot":2,"label":"No charges","canDrag":true,"disabled":true},{"slot":7,"label":"More powers","submenu":true}]))
	radial.receive({"kind":"action-menu","requestId":request_id,"menuId":5,"depth":2,"title":"Item powers","entries":entries})
	await process_frame; await process_frame
	check(radial.counts[1].text=="3" and radial.buttons[1].tooltip_text.contains("uses: 3 ·") and not radial.buttons[1].tooltip_text.contains("3.0"), "Wheel use count and tooltip format JSON numbers as integers")
	check(radial.hint.text.contains("Drag a power"), "Item power menus explain the native shortcut drag gesture")
	check(radial.buttons[0]._get_drag_data(Vector2.ZERO) == null and radial.buttons[7]._get_drag_data(Vector2.ZERO) == null, "Family parents and More pages navigate instead of creating invalid bindings")
	check(radial.buttons[2]._get_drag_data(Vector2.ZERO) == null, "A disabled power cannot start a drag")
	var payload: Dictionary = radial.buttons[1].payload.duplicate(true)
	check(payload == {"kind":"radial-entry","requestId":request_id,"menuId":5,"slot":1}, "Native power drag carries only the private menu/request and physical slot")
	check(bar.buttons[35]._can_drop_data(Vector2.ZERO,payload), "Current leaf power can be dropped into the third shortcut page")
	var origin: Vector2 = radial.buttons[1].get_global_rect().get_center()
	var destination: Vector2 = bar.buttons[35].get_global_rect().get_center()
	await motion(origin,Vector2.ZERO,false); await mouse(origin,true)
	await motion(origin+Vector2(20,0),Vector2(20,0),true)
	await motion(destination,destination-origin-Vector2(20,0),true)
	check(root.gui_is_dragging(), "Synthetic native pointer motion starts the wheel power drag")
	await mouse(destination,false)
	check(sent.size() == 1 and sent[0] == {"kind":"radial-shortcut","quickbarId":7,"requestId":request_id,"menuId":5,"slot":1,"index":35,"kindSource":"radial-entry"}, "Actual Godot GUI drop sends the private assignment and existing route marker without casting or forged property data")
	check(actions.is_empty() and not root.gui_is_dragging(), "Power dragging does not dispatch its click action or cancel the menu prematurely")
	radial.pending = true
	check(not bar.buttons[35]._can_drop_data(Vector2.ZERO,payload), "A menu awaiting an action cannot authorize a second assignment")
	radial.pending = false
	radial.receive({"kind":"action-menu","requestId":request_id,"menuId":6,"depth":3,"title":"Another page","entries":entries})
	check(not bar.buttons[35]._can_drop_data(Vector2.ZERO,payload), "Navigating the item wheel retires the prior leaf drag")
	var image := Image.create(16,16,false,Image.FORMAT_RGBA8); image.fill(Color.GOLD)
	var png := "data:image/png;base64," + Marshalls.raw_to_base64(image.save_png_to_buffer())
	bar.receive({"kind":"quickbar-icon","quickbarId":7,"index":35,"secondary":true,"image":png})
	check(bar.buttons[35].secondary_image.texture != null and bar.buttons[35].image.texture == null, "Original item overlay has a separate native texture from the power icon")
	bar.render(2)
	check(bar.buttons[35].secondary_image.texture != null, "Changing native shortcut pages preserves the decoded secondary item icon")
	bar.receive({"kind":"quickbar-view","quickbarId":8,"rows":rows})
	bar.receive({"kind":"quickbar-icon","quickbarId":7,"index":35,"secondary":true,"image":png})
	check(bar.secondary_textures.is_empty() and bar.buttons[35].secondary_image.texture == null, "Late secondary icon completion cannot decorate a replacement binding owner")
	var current: Dictionary = radial.buttons[1].payload.duplicate(true)
	radial.reset()
	check(not bar.buttons[35]._can_drop_data(Vector2.ZERO,current), "Closing the wheel retires all outstanding action drags")
	bar.reset(); bar.free(); radial.free(); await process_frame; await process_frame
	var file := FileAccess.open(output,FileAccess.WRITE)
	file.store_string(JSON.stringify({"success":failures.is_empty(),"passed":failures.is_empty(),"checks":checks,"failures":failures,"assignments":sent,"scope":"Authored native power drag/drop and icon ownership with synthetic viewport input; not physical-device or actual server activation acceptance"},"\t")); file.close()
	quit(0 if failures.is_empty() else 1)
