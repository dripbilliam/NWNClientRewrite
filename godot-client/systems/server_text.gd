extends RefCounted

# The host resolves NWN byte controls into literal spans. No HTML/BBCode from
# a server is interpreted. RichTextLabel's explicit push/add/pop API is used.
static func style(label: RichTextLabel) -> void:
	label.bbcode_enabled = false
	label.add_theme_color_override("default_color", Color(0.9, 0.88, 0.78))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 3)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE

static func append(label: RichTextLabel, rich: Dictionary, fallback: Color = Color(0.9, 0.88, 0.78)) -> void:
	if label.has_meta("native_text_color"): fallback=label.get_meta("native_text_color")
	var spans: Array = rich.get("spans", [{"text": rich.get("text", "")}])
	for part in spans:
		if not part is Dictionary:
			continue
		var color := str(part.get("color", ""))
		var valid := color.length() == 7 and color.begins_with("#") and color.substr(1).is_valid_hex_number(false)
		label.push_color(Color.html(color) if valid else fallback)
		label.add_text(str(part.get("text", "")))
		label.pop()

static func set_text(label: RichTextLabel, rich: Dictionary) -> void:
	label.clear()
	append(label, rich)

static func label(rich: Dictionary, width: float = 500.0) -> RichTextLabel:
	var result := RichTextLabel.new()
	style(result)
	result.fit_content = true
	result.scroll_active = false
	result.custom_minimum_size.x = width
	result.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	set_text(result, rich)
	return result

static func reply_button(rich: Dictionary, index: int) -> Button:
	var button := Button.new()
	button.focus_mode = Control.FOCUS_NONE
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var text := label({"spans": [{"text": "%s. " % index}] + rich.get("spans", [{"text": rich.get("text", "")}])})
	text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	text.offset_left = 12
	text.offset_top = 8
	text.offset_right = -12
	text.offset_bottom = -8
	button.add_child(text)
	text.resized.connect(func(): button.custom_minimum_size.y = maxf(40, text.get_content_height() + 16))
	button.custom_minimum_size = Vector2(530, 40)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var box := StyleBoxFlat.new()
		box.bg_color = Color(0.13, 0.14, 0.12, 0.98) if state == "hover" else Color(0.025, 0.03, 0.025, 0.98)
		box.border_color = Color(0.55, 0.48, 0.28)
		box.set_border_width_all(1)
		button.add_theme_stylebox_override(state, box)
	return button
