extends Button

var radial
var payload: Dictionary = {}

func _get_drag_data(_point: Vector2) -> Variant:
	if not is_instance_valid(radial) or not radial.can_shortcut(payload): return null
	var preview := Label.new()
	preview.text = tooltip_text
	preview.add_theme_color_override("font_outline_color", Color.BLACK)
	preview.add_theme_constant_override("outline_size", 4)
	set_drag_preview(preview)
	return payload.duplicate(true)
