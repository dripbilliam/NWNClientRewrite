extends Button

var inventory
var row: Dictionary = {}
var slot := 0
var channel := ""
var bound_view := -1
var image: TextureRect
var count: Label
var caption: Label

func setup(owner, value: Dictionary, target_slot: int = 0) -> void:
	inventory = owner
	row = value
	channel = str(row.get("channel", ""))
	bound_view = inventory.view_id
	slot = target_slot
	focus_mode = Control.FOCUS_NONE
	clip_contents = true
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.015, 0.02, 0.018, 0.92)
	style.border_color = Color(0.38, 0.34, 0.22)
	style.set_border_width_all(1)
	add_theme_stylebox_override("normal", style)
	var hover := style.duplicate()
	hover.border_color = Color(0.85, 0.74, 0.4)
	add_theme_stylebox_override("hover", hover)
	image = TextureRect.new()
	image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(image)
	caption = Label.new()
	caption.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.clip_text = true
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption.add_theme_font_size_override("font_size", 11)
	add_child(caption)
	count = Label.new()
	count.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	count.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	count.add_theme_color_override("font_shadow_color", Color.BLACK)
	count.add_theme_constant_override("shadow_offset_x", 1)
	count.add_theme_constant_override("shadow_offset_y", 1)
	add_child(count)
	tooltip_text = str(row.get("name", ""))
	if not row.is_empty():
		disabled = row.get("pending", false)
		count.text = str(int(row.stack)) if int(row.get("stack", 1)) > 1 else ""
		caption.text = str(row.get("name", "")).left(8)
		add_theme_font_size_override("font_size", 11)
	pressed.connect(func():
		if current() and row.has("entryId"): inventory.select_item(int(row.entryId)))

func current() -> bool:
	return is_instance_valid(inventory) and inventory.wanted and inventory.view_id == bound_view

func _gui_input(event: InputEvent) -> void:
	if not current() or not row.has("entryId"): return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT and event.double_click:
			inventory.operation(int(row.entryId), "activate")
			accept_event()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			inventory.item_menu(int(row.entryId), get_global_mouse_position())
			accept_event()

func _get_drag_data(_position: Vector2) -> Variant:
	if not current() or not row.has("entryId") or disabled: return null
	var preview := TextureRect.new()
	preview.texture = image.texture
	preview.custom_minimum_size = Vector2(50, 50)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	set_drag_preview(preview)
	return {"kind": "native-inventory-item", "viewId": inventory.view_id, "entryId": int(row.entryId)}

func _can_drop_data(_position: Vector2, data: Variant) -> bool:
	return current() and inventory.can_drop(data, slot)

func _drop_data(_position: Vector2, data: Variant) -> void:
	if not current() or not inventory.can_drop(data, slot): return
	if slot > 0: inventory.drop_slot(data, slot)
	else:
		var repository = inventory.store_panel.repository if channel == "M" and is_instance_valid(inventory.store_panel) else (inventory.container_repository if channel == "C" else inventory.repository)
		repository.drop_global(data, get_global_mouse_position())
