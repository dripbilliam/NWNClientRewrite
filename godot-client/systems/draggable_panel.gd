extends PanelContainer

signal close_requested

var title := ""
var content: VBoxContainer
var dragging := false
var drag_offset := Vector2.ZERO
var settings_path := "user://native-menu-layout.cfg"
var layout_key := ""
var heading: Label
var close_hides := true

func set_caption(caption: String) -> void:
	title = caption
	if heading != null:
		heading.text = caption

func configure(caption: String, key: String, initial: Vector2, storage: String = "user://native-menu-layout.cfg") -> void:
	title = caption
	layout_key = key
	settings_path = storage
	position = initial
	custom_minimum_size = Vector2(300, 140)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.045, 0.05, 0.97)
	style.border_color = Color(0.5, 0.44, 0.26)
	style.set_border_width_all(1)
	style.set_content_margin_all(12)
	style.shadow_color = Color(0, 0, 0, 0.45)
	style.shadow_size = 8
	add_theme_stylebox_override("panel", style)
	var column := VBoxContainer.new()
	add_child(column)
	var bar := HBoxContainer.new()
	column.add_child(bar)
	heading = Label.new()
	heading.text = caption
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.custom_minimum_size.y = 30
	heading.mouse_filter = Control.MOUSE_FILTER_STOP
	heading.gui_input.connect(_title_input)
	bar.add_child(heading)
	var close := Button.new()
	close.text = "×"
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(func():
		close_requested.emit()
		if close_hides:
			hide())
	bar.add_child(close)
	content = VBoxContainer.new()
	column.add_child(content)
	if not settings_path.is_empty():
		var config := ConfigFile.new()
		if config.load(settings_path) == OK:
			position = config.get_value("positions", layout_key, initial)

func _ready() -> void:
	get_viewport().size_changed.connect(_clamp)
	call_deferred("_clamp")

func _title_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		dragging = event.pressed
		if dragging:
			drag_offset = get_global_mouse_position() - global_position
			move_to_front()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and dragging:
		position = get_global_mouse_position() - drag_offset
		_clamp()
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed and dragging:
		dragging = false
		_save()

func _clamp() -> void:
	position = position.clamp(Vector2.ZERO, (get_viewport_rect().size - size).max(Vector2.ZERO))

func _save() -> void:
	if settings_path.is_empty():
		return
	var config := ConfigFile.new()
	config.load(settings_path)
	config.set_value("positions", layout_key, position)
	config.save(settings_path)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT and dragging:
		dragging = false
		_save()
