extends Button

var radial
var payload: Dictionary = {}
var frame: TextureRect

func _has_point(point: Vector2) -> bool:
	return point.distance_squared_to(size*0.5)<=pow(minf(size.x,size.y)*0.5,2)

func _draw() -> void:
	# Only a temporary/missing-resource fallback. Original model art owns the
	# normal appearance; an inherited Button theme must never add rectangles.
	if is_instance_valid(radial) and radial.hide_icons: return
	if frame!=null and frame.texture!=null: return
	draw_circle(size*0.5,minf(size.x,size.y)*0.5-1,Color(0.02,0.02,0.02,0.85))
	draw_arc(size*0.5,minf(size.x,size.y)*0.5-1,0,TAU,64,Color(0.65,0.55,0.3),1,true)

func _get_drag_data(_point: Vector2) -> Variant:
	if not is_instance_valid(radial) or not radial.can_shortcut(payload): return null
	var preview := Label.new()
	preview.text = tooltip_text
	preview.add_theme_color_override("font_outline_color", Color.BLACK)
	preview.add_theme_constant_override("outline_size", 4)
	set_drag_preview(preview)
	return payload.duplicate(true)
