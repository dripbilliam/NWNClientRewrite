extends "res://systems/draggable_panel.gd"
signal request(message: Dictionary)
const Text = preload("res://systems/server_text.gd")
var wanted := false
var view_id := -1
var board
var scroll: ScrollContainer
var note: RichTextLabel
var native_skin

func setup(storage: String = "user://native-menu-layout.cfg") -> void:
	configure("Area Map", "area-map", Vector2(150, 100), storage)
	scroll = ScrollContainer.new(); scroll.custom_minimum_size = Vector2(580, 430); content.add_child(scroll)
	board = preload("res://systems/map_board.gd").new(); board.size_flags_horizontal = Control.SIZE_EXPAND_FILL; board.size_flags_vertical = Control.SIZE_EXPAND_FILL; scroll.add_child(board)
	board.pin_selected.connect(func(rich): Text.set_text(note, rich))
	scroll.get_h_scroll_bar().value_changed.connect(func(_v): board.queue_redraw())
	scroll.get_v_scroll_bar().value_changed.connect(func(_v): board.queue_redraw())
	var bar := HBoxContainer.new(); content.add_child(bar)
	for amount in [-1, 1]:
		var button := Button.new(); button.text = "−" if amount < 0 else "+"; button.focus_mode = Control.FOCUS_NONE; button.pressed.connect(func(): set_zoom(board.zoom / 2 if amount < 0 else board.zoom * 2)); bar.add_child(button)
	note = Text.label({"text": ""}, 550); note.custom_minimum_size.y = 48; content.add_child(note)
	close_requested.connect(close_map); reset()

func reset() -> void:
	if is_instance_valid(native_skin): native_skin.reset_view()
	wanted = false; view_id = -1; board.reset(); Text.set_text(note, {}); hide()

func open() -> void:
	if wanted: show(); move_to_front(); return
	wanted = true; show(); move_to_front(); Text.set_text(note, {"text": "Loading installed map artwork…"}); request.emit({"kind": "map-open"})

func close_map() -> void:
	if wanted: request.emit({"kind": "map-close"})
	wanted = false; hide()
	if is_instance_valid(native_skin): native_skin.close_editor()

func set_zoom(value: int) -> void:
	if is_instance_valid(native_skin): native_skin.set_zoom(value); return
	board.zoom = clampi(value, 8, 64); board.resize_map()

func receive(message: Dictionary) -> void:
	if message.kind == "map-closed": reset(); return
	if not wanted: return
	if message.kind == "map-view":
		view_id = int(message.viewId); board.configure(message); Text.set_text(note, {"text": "Only explored tiles are shown. Select a map pin to read its note."}); _clamp()
		if is_instance_valid(native_skin): native_skin.map_changed()
	elif int(message.get("viewId", -2)) == view_id:
		if message.kind == "map-notice": Text.set_text(note, {"text": str(message.text)})
		else: board.receive(message)
