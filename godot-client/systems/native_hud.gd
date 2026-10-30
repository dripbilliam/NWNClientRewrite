extends CanvasLayer
const Timing=preload("res://systems/native_render/frame_profile.gd")

signal examine_requested(id: int)

const DraggablePanel = preload("res://systems/draggable_panel.gd")
var registry
var camera: Camera3D
var root: Control
var panels: Dictionary = {}
var nameplates: Dictionary = {}
var details: Label
var object_list: ItemList
var object_ids: Array = []
var current_id := -1
var metrics: Label
var nameplate_root: Control
var storage := "user://native-menu-layout.cfg"
var live_mode := false
var instructions: Label
var refresh_queued:=false

func enable_live_mode() -> void:
	live_mode = true
	panels.details.set_caption("Object details · local server")
	panels.objects.set_caption("World objects · local server")
	instructions.text = "Middle drag: orbit · Wheel: zoom\nW/S: forward/back · A/D: turn · Q/E: strafe\nShift: walk · Enter: chat · Hold Tab: highlights\nHome: initial view · Left click: move / interact\nRight click: actions · I: inventory · X: examine · B: spellbook\nF1–F12: shortcuts · Ctrl+Alt+F1/F2/F3: debug\n\nNative movement/animation. Effects / full menus pending."

func configure(value, view: Camera3D, settings: String = "user://native-menu-layout.cfg") -> void:
	registry = value
	camera = view
	storage = settings
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	metrics = Label.new()
	metrics.position = Vector2(16, 16)
	metrics.mouse_filter = Control.MOUSE_FILTER_IGNORE
	metrics.add_theme_color_override("font_shadow_color", Color.BLACK)
	metrics.add_theme_constant_override("shadow_offset_x", 2)
	metrics.add_theme_constant_override("shadow_offset_y", 2)
	root.add_child(metrics)
	nameplate_root = Control.new()
	nameplate_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	nameplate_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(nameplate_root)
	var inspect = _panel("Object details · captured state", "details", Vector2(36, 160))
	details = Label.new()
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.custom_minimum_size = Vector2(310, 180)
	inspect.content.add_child(details)
	var objects = _panel("World objects · captured state", "objects", Vector2(400, 160))
	object_list = ItemList.new()
	object_list.custom_minimum_size = Vector2(320, 330)
	object_list.focus_mode = Control.FOCUS_NONE
	objects.content.add_child(object_list)
	object_list.item_selected.connect(func(index): inspect_entity(int(object_ids[index])))
	for id in registry.eligible_ids():
		object_ids.append(id)
		object_list.add_item(_name(id))
	var help = _panel("Controls", "help", Vector2(36, 420))
	instructions = Label.new()
	instructions.text = "Middle drag: orbit · Wheel: zoom\nWASD: pan inspection camera · Shift: faster\nHome: captured view · Hold Tab: highlights\nLeft click: select · Right click / I: details\nF1: controls · F2: objects · F3: performance\n\nOffline captured state. No server actions."
	help.content.add_child(instructions)
	for panel in panels.values():
		panel.hide()

func _panel(caption: String, key: String, initial: Vector2):
	var panel = DraggablePanel.new()
	panel.configure(caption, key, initial, storage)
	root.add_child(panel)
	panels[key] = panel
	return panel

func _name(id: int) -> String:
	var row: Dictionary = registry.entities.get(id, {})
	var value := str(row.get("name", ""))
	return value if not value.is_empty() else "Object %s" % id

func refresh_entities() -> void:
	object_list.clear()
	object_ids.clear()
	for id in registry.eligible_ids():
		object_ids.append(id)
		object_list.add_item(_name(id))
	for id in nameplates.keys():
		if not registry.entities.has(id):
			nameplates[id].queue_free()
			nameplates.erase(id)
		else:
			nameplates[id].text = _name(id)
	if current_id >= 0 and not registry.entities.has(current_id):
		current_id = -1
		panels.details.hide()
func queue_refresh_entities() -> void:
	if refresh_queued: return
	refresh_queued=true; _flush_entities.call_deferred()
func _flush_entities() -> void:
	var began:=Timing.begin(); refresh_queued=false
	if is_inside_tree(): refresh_entities()
	Timing.finish("hud_deferred_refresh_ms",began)

func inspect_entity(id: int) -> void:
	if not registry.entities.has(id):
		return
	current_id = id
	if live_mode:
		examine_requested.emit(id)
		return
	var row: Dictionary = registry.entities[id]
	details.text = "%s\nID: %s · type: %s\n\nModels:\n%s\n\nRead-only captured state.\nInteraction and movement await the live bridge." % [_name(id), id, row.get("type", "?"), "\n".join(row.get("resources", []))]
	panels.details.show()
	panels.details.move_to_front()

func toggle_panel(key: String) -> void:
	var panel = panels[key]
	panel.visible = not panel.visible
	if panel.visible:
		panel.move_to_front()

func blocks_pointer(point: Vector2) -> bool:
	for panel in panels.values():
		if panel.visible and panel.get_global_rect().has_point(point):
			return true
	return false

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var children := root.get_children()
		children.reverse()
		for panel in children:
			if panel is PanelContainer and panel.visible and panel.get_global_rect().has_point(event.position):
				panel.move_to_front()
				break

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if live_mode and event.keycode != KEY_X: return
	match event.keycode:
		KEY_F1: toggle_panel("help")
		KEY_F2: toggle_panel("objects")
		KEY_F3: metrics.visible = not metrics.visible
		KEY_I:
			if not live_mode: inspect_entity(current_id)
		KEY_X:
			if live_mode: inspect_entity(current_id)

func labels(ids: Array) -> void:
	for id in nameplates:
		nameplates[id].hide()
	for id in ids:
		if not registry.entities.has(id):
			continue
		var point: Vector3 = registry.label_position(id)
		if camera.is_position_behind(point):
			continue
		if not nameplates.has(id):
			var text := Label.new()
			text.mouse_filter = Control.MOUSE_FILTER_IGNORE
			text.add_theme_color_override("font_shadow_color", Color.BLACK)
			text.add_theme_constant_override("shadow_outline_size", 4)
			text.add_theme_color_override("font_outline_color", Color.BLACK)
			text.add_theme_constant_override("outline_size", 4)
			text.text = _name(id)
			nameplate_root.add_child(text)
			nameplates[id] = text
		var text: Label = nameplates[id]
		text.position = camera.unproject_position(point) - Vector2(text.size.x * 0.5, text.size.y)
		text.visible = get_viewport().get_visible_rect().has_point(text.position)

func update_metrics() -> void:
	if live_mode:
		metrics.text = "%.1f FPS" % Engine.get_frames_per_second()
		return
	metrics.text = "NATIVE GODOT · captured-world prototype\n%.1f FPS · %s objects · %s picking surfaces\nMiddle drag / wheel / WASD camera · F1 controls\nFrozen animation; no server connection." % [Engine.get_frames_per_second(), registry.entities.size(), registry.stats.colliders]
