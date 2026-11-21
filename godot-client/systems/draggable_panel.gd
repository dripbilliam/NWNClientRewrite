extends PanelContainer
const MenuBuilder=preload("res://systems/native_menu_builder.gd")
const MenuStyle=preload("res://systems/native_client_menu_style.gd")
const LEGACY_LAYOUT_KEYS={"local-dialog":"conversation","local-examine":"examine","spellbook":"spells-known"}

signal close_requested

var title := ""
var content: VBoxContainer
var dragging := false
var drag_offset := Vector2.ZERO
var drag_start := Vector2.ZERO
var drag_moved := false
var drag_device := -1
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
	layout_key = str(LEGACY_LAYOUT_KEYS.get(key,key))
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
			var saved: Variant=config.get_value("positions",layout_key,null) if config.has_section_key("positions",layout_key) else null
			if saved==null and layout_key!=key:
				saved=config.get_value("positions",key,null) if config.has_section_key("positions",key) else null
				if saved is Vector2:
					config.set_value("positions",layout_key,saved)
					config.erase_section_key("positions",key)
					config.save(settings_path)
			if saved is Vector2:position=saved

func _ready() -> void:
	add_to_group("native_client_windows")
	visibility_changed.connect(_window_visibility)
	if is_instance_valid(close_button): apply_native_theme(MenuStyle.for_tree(get_tree()))
	get_viewport().size_changed.connect(_clamp)
	call_deferred("_clamp")
	if is_visible_in_tree():raise_game_window()

static func front_game_window(root: Control) -> Control:
	if not is_instance_valid(root) or not root.is_inside_tree():return root
	var front: Control=null
	for candidate in root.get_tree().get_nodes_in_group("native_client_windows"):
		if not candidate is Control or candidate.get_viewport()!=root.get_viewport() or not candidate.is_visible_in_tree() or candidate.get_global_rect().size.x<=0:continue
		var layer:=window_layer(candidate)
		var top_layer:=window_layer(front) if front!=null else -2147483648
		if front==null or layer>top_layer or layer==top_layer and (candidate.z_index>front.z_index or candidate.z_index==front.z_index and candidate.get_index()>front.get_index()):front=candidate
	return front

static func window_layer(window: Control) -> int:
	var node: Node=window
	while node!=null:
		if node is CanvasLayer:return node.layer
		node=node.get_parent()
	return 0

func raise_game_window() -> void:
	if not is_inside_tree():return
	var tree:=get_tree()
	var serial:=int(tree.get_meta("nwn_movable_window_order",20))+1
	if serial>200:
		var windows: Array=[]
		for candidate in tree.get_nodes_in_group("native_client_windows"):
			if candidate is Control and candidate.get_viewport()==get_viewport():windows.append(candidate)
		windows.sort_custom(func(a,b):return a.z_index<b.z_index)
		for index in windows.size():windows[index].z_index=index+20
		serial=windows.size()+21
	move_to_front()
	z_index=serial
	tree.set_meta("nwn_movable_window_order",serial)

func _window_visibility() -> void:
	if is_visible_in_tree():raise_game_window()
	elif dragging:
		dragging=false
		drag_device=-1
		if drag_moved:_save()
		drag_moved=false

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
		if event.pressed and not dragging:
			dragging = true
			drag_start = event.global_position
			drag_offset = event.global_position - global_position
			drag_moved = false
			drag_device = event.device
			raise_game_window()
			accept_event()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and is_visible_in_tree():
		var hovered: Control=get_viewport().gui_get_hovered_control()
		if hovered!=null and (hovered==self or is_ancestor_of(hovered)):raise_game_window()
	if event is InputEventMouseMotion and dragging and event.device == drag_device:
		if not drag_moved and event.global_position.distance_to(drag_start)<3.0:return
		drag_moved = true
		global_position = event.global_position - drag_offset
		_clamp()
		get_viewport().set_input_as_handled()
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed and dragging and event.device == drag_device:
		dragging = false
		drag_device = -1
		if drag_moved:
			_save()
			get_viewport().set_input_as_handled()
		drag_moved = false

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
		drag_device = -1
		if drag_moved:_save()
		drag_moved = false
