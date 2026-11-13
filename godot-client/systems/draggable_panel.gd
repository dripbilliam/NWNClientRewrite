extends PanelContainer
const MenuBuilder=preload("res://systems/native_menu_builder.gd")
const MenuStyle=preload("res://systems/native_client_menu_style.gd")

signal close_requested

var title := ""
var content: VBoxContainer
var dragging := false
var drag_offset := Vector2.ZERO
var settings_path := "user://native-menu-layout.cfg"
var layout_key := ""
var heading: Label
var close_hides := true
var window_column: VBoxContainer
var close_button: Button
var title_bar: HBoxContainer
var visual_extent := Vector2.ZERO
var pending_native_theme: Theme
var pending_native_theme_source:=0

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
	var column := VBoxContainer.new()
	window_column=column
	add_child(column)
	var bar := HBoxContainer.new()
	title_bar=bar
	column.add_child(bar)
	heading = Label.new()
	heading.text = caption
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.custom_minimum_size.y = 30
	heading.mouse_filter = Control.MOUSE_FILTER_STOP
	heading.gui_input.connect(_title_input)
	bar.add_child(heading)
	var close := Button.new()
	close_button=close
	close.text = "×"
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(func():
		close_requested.emit()
		if close_hides:
			hide())
	bar.add_child(close)
	content = VBoxContainer.new()
	column.add_child(content)
	apply_native_theme(MenuStyle.for_tree(get_tree() if is_inside_tree() else null))
	if not settings_path.is_empty():
		var config := ConfigFile.new()
		if config.load(settings_path) == OK:
			position = config.get_value("positions", layout_key, initial)

func _ready() -> void:
	add_to_group("native_client_windows")
	if is_instance_valid(close_button): apply_native_theme(MenuStyle.for_tree(get_tree()))
	get_viewport().size_changed.connect(_clamp)
	call_deferred("_clamp")

func apply_native_theme(value: Theme) -> void:
	pending_native_theme=null;pending_native_theme_source=0
	if visibility_changed.is_connected(_apply_pending_native_theme):visibility_changed.disconnect(_apply_pending_native_theme)
	# Authored source skins may replace the prototype panel/close controls.
	# Keep those exact overrides; flexible windows inherit the shared theme.
	var authored:=has_theme_stylebox_override("panel") and get_theme_stylebox("panel") is StyleBoxEmpty
	if authored:
		theme=value
	else:
		MenuBuilder.apply_window(self,value,close_button if is_instance_valid(close_button) and close_button.get_parent()==title_bar else null)

func stage_native_theme(value: Theme,source_id: int) -> bool:
	if is_visible_in_tree():apply_native_theme(value);return false
	pending_native_theme=value;pending_native_theme_source=source_id
	if not visibility_changed.is_connected(_apply_pending_native_theme):visibility_changed.connect(_apply_pending_native_theme)
	return true

func discard_pending_native_theme(source_id: int) -> void:
	if pending_native_theme_source!=source_id:return
	pending_native_theme=null;pending_native_theme_source=0
	if visibility_changed.is_connected(_apply_pending_native_theme):visibility_changed.disconnect(_apply_pending_native_theme)

func _apply_pending_native_theme() -> void:
	if pending_native_theme==null or not is_visible_in_tree():return
	apply_native_theme(pending_native_theme)

func _title_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		dragging = event.pressed
		if dragging:
			drag_offset = event.global_position - global_position
			move_to_front()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and dragging:
		global_position = event.position - drag_offset
		_clamp()
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed and dragging:
		dragging = false
		_save()

func _clamp() -> void:
	position = position.clamp(Vector2.ZERO, (get_viewport_rect().size - size.max(visual_extent)).max(Vector2.ZERO))

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
