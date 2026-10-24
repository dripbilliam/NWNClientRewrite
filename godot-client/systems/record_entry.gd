extends Button
var owner_sheet
var bound_view := -1
var entry_id := -1
var draggable := false
var image: TextureRect

func setup(sheet, row: Dictionary) -> void:
	owner_sheet = sheet; bound_view = sheet.view_id; entry_id = int(row.entryId); draggable = row.get("canDrag", false)
	focus_mode = Control.FOCUS_NONE
	clip_contents = true
	custom_minimum_size = Vector2(300, 44)
	tooltip_text = str(row.name)
	var line := HBoxContainer.new(); line.mouse_filter = Control.MOUSE_FILTER_IGNORE; line.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(line)
	image = TextureRect.new(); image.custom_minimum_size = Vector2(36, 36); image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED; image.mouse_filter = Control.MOUSE_FILTER_IGNORE; line.add_child(image)
	var label := Label.new(); label.text = str(row.name); label.size_flags_horizontal = Control.SIZE_EXPAND_FILL; label.mouse_filter = Control.MOUSE_FILTER_IGNORE; line.add_child(label)
	if row.has("value"):
		var value := Label.new(); value.text = str(int(row.value)); value.mouse_filter = Control.MOUSE_FILTER_IGNORE; line.add_child(value)
	pressed.connect(func():
		if current(): owner_sheet.select_entry(entry_id))

func current() -> bool: return is_instance_valid(owner_sheet) and owner_sheet.wanted and owner_sheet.view_id == bound_view

func _get_drag_data(_point: Vector2) -> Variant:
	var data: Variant = drag_data()
	if data == null: return null
	var preview := Label.new(); preview.text = tooltip_text; set_drag_preview(preview)
	return data

func drag_data() -> Variant:
	if not current() or not draggable: return null
	return {"kind": "record-entry", "viewId": bound_view, "entryId": entry_id}
