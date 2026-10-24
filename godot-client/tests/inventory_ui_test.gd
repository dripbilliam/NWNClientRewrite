extends SceneTree

const Inventory = preload("res://systems/server_inventory.gd")
const Options = preload("res://systems/native_options.gd")
const Connection = preload("res://systems/local_connection.gd")
var checks := 0
var failures: Array = []
var output := ""

func _initialize() -> void: call_deferred("run")
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)

func run() -> void:
	var fixture := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output = arg.substr(9)
		elif arg.begins_with("--fixture="): fixture = arg.substr(10)
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(fixture))
	var panel := Inventory.new()
	panel.setup("")
	root.add_child(panel)
	check(panel.ac.get_parent() == panel.equipment, "An inventory that was never opened still owns and frees its AC label")
	var sent: Array = []
	panel.request.connect(func(value): sent.append(value))
	panel.open(); panel.receive(data)
	await process_frame
	check(panel.equipment.get_children().size() == 15, "Default equipment has fourteen base-game slots plus AC, with creature slots hidden")
	check(panel.find_children("*", "CheckBox", true, false).is_empty(), "Creature-slot preference is absent from inventory controls")
	check(panel.buttons[0].size == Vector2(39, 119), "Original one-by-three item dimensions remain full height")
	check(panel.buttons[1].size == Vector2(100, 160), "Equipped robe occupies the original armor box")
	var drag := {"kind": "native-inventory-item", "viewId": 1, "entryId": 0}
	check(panel.can_drop(drag, 16) and not panel.can_drop(drag, 2), "Native equip targets respect active base-item slot masks")
	panel.drop_slot(drag, 16)
	check(sent.back().operation == "equip" and sent.back().slot == 16, "Equip drop requests the actual slot rather than predicting ownership")
	panel.repository.drop_global(drag, panel.repository.global_position + Vector2(125, 85))
	check(sent.back().operation == "move" and sent.back().x == 3 and sent.back().y == 2, "Backpack drop transmits original grid coordinates")
	var old_button: Button = panel.buttons[0]
	data.viewId = 2
	panel.receive(data)
	var count := sent.size()
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT; click.pressed = true; click.double_click = true
	old_button._gui_input(click)
	check(sent.size() == count, "Retired item controls cannot activate replacement entries")
	check(not panel.can_drop(drag, 16), "Old native drag cannot cross a view revision")
	var image := Image.create(32, 96, false, Image.FORMAT_RGBA8)
	image.fill(Color.GOLD)
	var png := "data:image/png;base64," + Marshalls.raw_to_base64(image.save_png_to_buffer())
	panel.receive({"kind": "inventory-icon", "viewId": 1, "entryId": 0, "image": png})
	check(panel.buttons[0].image.texture == null, "Late icon cannot decorate a replacement item view")
	panel.receive({"kind": "inventory-icon", "viewId": 2, "entryId": 0, "image": png})
	check(panel.buttons[0].image.texture != null and panel.buttons[0].image.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED, "Native original-icon transport preserves item aspect ratio")
	var preference := output.get_basename() + "-options.cfg"
	var options := Options.new()
	options.setup("", preference)
	root.add_child(options)
	options.inventory_preference.connect(func(value): panel.creature_slots = value; panel.render())
	check(not options.show_creature_slots, "Options default to hidden creature slots")
	options.creature.button_pressed = true
	check(panel.equipment.get_children().size() == 19 and panel.equipment.custom_minimum_size.y == 320, "Options reveals all four creature equipment slots")
	var restored := Options.new()
	restored.setup("", preference)
	root.add_child(restored)
	check(restored.show_creature_slots, "Creature-slot preference persists outside the inventory")
	panel.position = Vector2(30, 40)
	panel.close_inventory(); panel.open()
	check(panel.position == Vector2(30, 40), "Closing/reopening inventory retains its native window position")
	data.viewId = 3
	data.container = {"ownerId": 100, "page": 0, "pageCount": 2, "title": "Authored chest", "serial": 1}
	data.automatic = true
	data.items.append({"entryId": 3, "itemId": 10, "channel": "C", "x": 2, "y": 2, "width": 2, "height": 3, "slotMask": 2, "stack": 1, "name": "Stored robe", "pending": false})
	panel.receive(data)
	check(panel.container_box.visible and not panel.equipment.visible and panel.container_repository.rows == 5, "Container replaces equipment with the original seven-by-five repository")
	check(panel.buttons[3].position == Vector2(80, 80) and panel.buttons[3].size == Vector2(79, 119), "Container item retains its original cell extent")
	var from_chest := {"kind": "native-inventory-item", "viewId": 3, "entryId": 3}
	panel.repository.drop_global(from_chest, panel.repository.global_position + Vector2(45, 45))
	check(sent.back().destination == "backpack" and sent.back().operation == "move", "Chest-to-backpack drop retains transfer direction")
	panel.container_repository.drop_global({"kind": "native-inventory-item", "viewId": 3, "entryId": 0}, panel.container_repository.global_position + Vector2(45, 45))
	check(sent.back().destination == "container" and sent.back().x == 1 and sent.back().y == 1, "Backpack-to-chest drop targets container grid coordinates")
	panel.container_controls.next.pressed.emit()
	check(sent.back().kind == "inventory-container" and sent.back().operation == "next", "Container paging uses its dedicated original request")
	panel.close_inventory()
	panel.receive({"kind": "inventory-closed"})
	panel.receive(data)
	check(not panel.visible, "Late metadata from a closed container cannot reopen it")
	data.container.serial = 2
	panel.receive(data)
	check(panel.visible and panel.wanted, "A new server container context auto-opens native inventory")
	panel.reset()
	check(panel.items.is_empty() and panel.textures.is_empty() and not panel.visible, "World reset clears inventory identities and owned textures")
	await process_frame
	var file := FileAccess.open(output, FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed": failures.is_empty(), "checks": checks, "failures": failures, "scope": "Authored native inventory layout/input/options ownership; actual server transfer checked separately"}, "\t")); file.close()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(preference))
	panel.free(); options.free(); restored.free()
	quit(0 if failures.is_empty() else 1)
