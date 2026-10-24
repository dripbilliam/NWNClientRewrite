extends Control
var element
var order := 1
var commands: Array = []
var chart: Array = []
var image_id := -1
var image_aspect := 0
var image_halign := 0
var image_valign := 0

func _ready() -> void: mouse_filter = Control.MOUSE_FILTER_IGNORE
# The JS NUI renderer uses truthiness for draw-list fill, including bound JSON
# values. GDScript's bool constructor rejects null, strings and containers.
static func draw_fill(value: Variant) -> bool:
	match typeof(value):
		TYPE_NIL: return false
		TYPE_BOOL: return value
		TYPE_INT, TYPE_FLOAT: return value != 0 and not is_nan(float(value))
		TYPE_STRING: return not value.is_empty()
		TYPE_ARRAY, TYPE_DICTIONARY: return true
	return false
static func draw_number(value: Variant, fallback: float = 0.0) -> float:
	var result := fallback
	if value is int or value is float: result = float(value)
	elif value is bool: result = 1.0 if value else 0.0
	elif value is String:
		var text: String = value.strip_edges()
		if text.is_empty(): result = 0.0
		elif text.is_valid_float(): result = text.to_float()
	return result if is_finite(result) else fallback
static func draw_integer(value: Variant, fallback: int = 0) -> int:
	# Draw enums/handles are 32-bit fields. Avoid overflowing an int constructor.
	return int(clampf(draw_number(value, fallback), -2147483648.0, 2147483647.0))
func rgba(value: Variant) -> Color:
	if not value is Dictionary: return Color.WHITE
	return Color(draw_number(value.get("r"), 255) / 255, draw_number(value.get("g"), 255) / 255, draw_number(value.get("b"), 255) / 255, draw_number(value.get("a"), 255) / 255)
func vector(value: Variant) -> Vector2:
	return Vector2(draw_number(value.get("x")), draw_number(value.get("y"))) if value is Dictionary else Vector2.ZERO
func rectangle(value: Variant) -> Rect2:
	return Rect2(vector(value), Vector2(maxf(0, draw_number(value.get("w"))), maxf(0, draw_number(value.get("h"))))) if value is Dictionary else Rect2()
func picture(id: int, box: Rect2, aspect: int = 0, halign: int = 0, valign: int = 0) -> void:
	var texture = element.manager.resources.get(id)
	if not texture is Texture2D or box.size.x <= 0 or box.size.y <= 0: return
	var source: Vector2 = texture.get_size()
	if aspect == 5: draw_texture_rect(texture, box, false); return
	var scale := maxf(box.size.x / source.x, box.size.y / source.y) if aspect == 1 else minf(box.size.x / source.x, box.size.y / source.y)
	if aspect in [3, 4]: scale = 1
	elif aspect == 2: scale = minf(1, scale)
	var extent := source * scale
	var offset := Vector2((box.size.x - extent.x) * (0.5 if halign == 0 else (0 if halign == 1 else 1)), (box.size.y - extent.y) * (0.5 if valign == 0 else (0 if valign == 1 else 1)))
	if aspect == 1: draw_texture_rect_region(texture, box, Rect2(-offset / scale, box.size / scale))
	else: draw_texture_rect(texture, Rect2(box.position + offset, extent), false)
func _draw() -> void:
	if element == null: return
	if image_id >= 0: picture(image_id, Rect2(Vector2.ZERO, size), image_aspect, image_halign, image_valign)
	if not chart.is_empty(): draw_chart()
	for item in commands:
		if not item is Dictionary: continue
		if (-1 if draw_integer(item.get("order"), 1) == -1 else 1) != order: continue
		var render := draw_integer(item.get("render"))
		if render == 1 and element.hovered or render == 2 and not element.hovered: continue
		if render >= 3 and element.pointer_button != {3: 0, 4: 2, 5: 1}.get(render, -2): continue
		var tint := rgba(item.get("color")); var fill := draw_fill(item.get("fill")); var thickness := draw_number(item.get("line_thickness"), 1)
		var box := rectangle(item.get("rect")); var a := vector(item.get("a")); var b := vector(item.get("b")); var points := PackedVector2Array()
		match draw_integer(item.get("type"), -1):
			0:
				var raw: Array = item.points if item.get("points") is Array else []
				if not raw.is_empty() and (raw[0] is float or raw[0] is int):
					for index in raw.size() / 2: points.append(Vector2(draw_number(raw[index * 2]), draw_number(raw[index * 2 + 1])))
				else:
					for value in raw: points.append(vector(value))
			1:
				var c := vector(item.get("ctrl0")); var d := vector(item.get("ctrl1"))
				for index in 65:
					var t := index / 64.0; var u := 1 - t
					points.append(a * u * u * u + c * 3 * u * u * t + d * 3 * u * t * t + b * t * t * t)
			2:
				for index in 65:
					var angle := index * TAU / 64.0; points.append(box.get_center() + Vector2(cos(angle), sin(angle)) * box.size / 2)
			3:
				var center := vector(item.get("c")); var radius := draw_number(item.get("radius")); var start := draw_number(item.get("amin")); var end := draw_number(item.get("amax"))
				if fill: points.append(center)
				for index in 65:
					var angle := lerpf(start, end, index / 64.0); points.append(center + Vector2(cos(angle), sin(angle)) * radius)
			4:
				var font: Font = element.manager.font_for(str(item.get("font", element.values.get("font", "(default)"))))
				var font_size: int = element.manager.font_size(str(item.get("font", element.values.get("font", "(default)"))))
				draw_string(font, box.position + Vector2(0, font.get_ascent(font_size)), str(item.get("text", "")), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, tint)
			5: picture(draw_integer(item.get("image"), -1), box, draw_integer(item.get("image_aspect")))
			6: draw_line(a, b, tint, thickness, true)
			7: draw_rect(box, tint, fill, thickness, true)
		if points.size() >= 3 and fill: draw_colored_polygon(points, tint)
		elif points.size() >= 2: draw_polyline(points, tint, thickness, true)
func draw_chart() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), element.manager.skin_color("chart", "background_color", Color.BLACK))
	var border := draw_number(element.manager.skin.get("chart", {}).get("border"), 1)
	if border > 0: draw_rect(Rect2(Vector2.ZERO, size), element.manager.skin_color("chart", "border_color", Color(0.68, 0.56, 0.38)), false, border)
	var minimum := 0.0; var maximum := 1.0
	for slot in chart:
		if not slot is Dictionary or not slot.get("data") is Array: continue
		for value in slot.data: minimum = minf(minimum, draw_number(value)); maximum = maxf(maximum, draw_number(value))
	for slot in chart:
		if not slot is Dictionary: continue
		var data: Array = slot.data if slot.get("data") is Array else []; var points := PackedVector2Array(); var tint: Color = rgba(slot.get("color")) if slot.get("color") is Dictionary else element.manager.skin_color("chart", "color", Color.WHITE)
		for index in data.size():
			var point := Vector2(10 + index * 280.0 / maxi(1, data.size() - 1), 110 - (draw_number(data[index]) - minimum) / (maximum - minimum) * 100) * size / Vector2(300, 120)
			if draw_integer(slot.get("type")) == 1:
				var width := 280.0 / maxi(1, data.size()) * size.x / 300
				draw_rect(Rect2(Vector2(10 * size.x / 300 + index * width, point.y), Vector2(maxf(0, width - 2), 110 * size.y / 120 - point.y)), tint)
			else: points.append(point); draw_circle(point, 4, tint)
		if points.size() > 1: draw_polyline(points, tint, 2, true)
