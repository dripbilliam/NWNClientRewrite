extends Button
const Numbers=preload("res://systems/native_data/game_numbers.gd")

signal selected
signal activated
signal context_requested(point: Vector2)
signal dropped(data: Dictionary)
var payload: Dictionary = {}
var accepts: Callable
var right_click_activates:=true
var image: TextureRect
var secondary_image: TextureRect
var caption: Label
var counter: Label

func setup(label: String, uses: Variant = null, compact: bool = false) -> void:
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = Vector2(50, 58) if compact else Vector2(258, 58)
	tooltip_text = label
	image = TextureRect.new()
	image.position = Vector2(5, 10)
	image.size = Vector2(38, 38)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(image)
	secondary_image = TextureRect.new()
	secondary_image.position = Vector2(29, 29)
	secondary_image.size = Vector2(18, 18)
	secondary_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	secondary_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	secondary_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(secondary_image)
	caption = Label.new()
	caption.position = Vector2(46, 7)
	caption.size = Vector2(204, 46)
	caption.text = label
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.max_lines_visible = 2
	caption.add_theme_font_size_override("font_size", 13)
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption.visible = not compact
	add_child(caption)
	counter = Label.new()
	counter.position = Vector2(3, 1)
	counter.text = Numbers.text(uses, "")
	counter.add_theme_font_size_override("font_size", 12)
	counter.add_theme_color_override("font_color", Color.YELLOW)
	counter.add_theme_color_override("font_outline_color", Color.BLACK)
	counter.add_theme_constant_override("outline_size", 4)
	counter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(counter)
	pressed.connect(func(): selected.emit())
	gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_RIGHT or event.button_index == MOUSE_BUTTON_LEFT and event.double_click:
				if event.button_index!=MOUSE_BUTTON_RIGHT or right_click_activates: activated.emit()
				if event.button_index == MOUSE_BUTTON_RIGHT: context_requested.emit(get_global_transform_with_canvas() * event.position)
				accept_event())

func _get_drag_data(_point: Vector2) -> Variant:
	if payload.is_empty():
		return null
	var preview := Label.new()
	preview.text = tooltip_text
	preview.add_theme_color_override("font_outline_color", Color.BLACK)
	preview.add_theme_constant_override("outline_size", 4)
	set_drag_preview(preview)
	return payload.duplicate(true)

func _can_drop_data(_point: Vector2, data: Variant) -> bool:
	return data is Dictionary and accepts.is_valid() and accepts.call(data)

func _drop_data(point: Vector2, data: Variant) -> void:
	if _can_drop_data(point, data):
		dropped.emit(data)
