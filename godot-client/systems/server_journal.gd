extends "res://systems/draggable_panel.gd"
signal request(message: Dictionary)
const Text = preload("res://systems/server_text.gd")
var wanted := false
var view_id := -1
var page := 0
var tabs: Array = []
var scroll: ScrollContainer
var body: VBoxContainer
var state: Dictionary = {}
var positions: Dictionary = {}

func setup(storage: String = "user://native-menu-layout.cfg") -> void:
	configure("Journal", "journal", Vector2(250, 100), storage)
	var navigation := HBoxContainer.new(); content.add_child(navigation)
	for index in 4:
		var button := Button.new(); button.text = ["Quests", "Completed", "Notes", "Messages"][index]; button.focus_mode = Control.FOCUS_NONE; button.pressed.connect(func(): choose(index)); navigation.add_child(button); tabs.append(button)
	scroll = ScrollContainer.new(); scroll.custom_minimum_size = Vector2(580, 450); scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; content.add_child(scroll)
	body = VBoxContainer.new(); body.size_flags_horizontal = Control.SIZE_EXPAND_FILL; scroll.add_child(body)
	close_requested.connect(close_journal); reset()

func clear_body() -> void:
	for child in body.get_children(): body.remove_child(child); child.queue_free()

func reset() -> void:
	wanted = false; view_id = -1; page = 0; state.clear(); positions.clear(); clear_body(); hide()

func open() -> void:
	if wanted: show(); move_to_front(); return
	wanted = true; show(); move_to_front(); clear_body(); body.add_child(Text.label({"text": "Waiting for the server journal…"}, 550)); request.emit({"kind": "journal-open"})

func close_journal() -> void:
	if wanted: request.emit({"kind": "journal-close"})
	wanted = false; hide()

func choose(index: int) -> void:
	if wanted and view_id >= 0 and index != page:
		request.emit({"kind": "journal-page", "viewId": view_id, "page": index})

func receive(message: Dictionary) -> void:
	if message.kind == "journal-closed": reset(); return
	if not wanted or message.kind != "journal-view": return
	positions[page] = scroll.scroll_vertical; page = int(message.page); view_id = int(message.viewId); state = message.duplicate(true); clear_body()
	for index in tabs.size(): tabs[index].disabled = index == page
	for entry in state.entries:
		body.add_child(Text.label(entry.title, 550)); body.add_child(Text.label(entry.description, 550)); body.add_child(HSeparator.new())
	if state.entries.is_empty(): body.add_child(Text.label({"text": "No entries in this category." if state.loaded else "Waiting for the server journal…"}, 550))
	scroll.set_deferred("scroll_vertical", int(positions.get(page, 0))); _clamp()
