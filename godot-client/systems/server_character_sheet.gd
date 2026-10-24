extends "res://systems/draggable_panel.gd"

signal request(message: Dictionary)
signal level_requested
const Text = preload("res://systems/server_text.gd")
const Images = preload("res://systems/runtime_image.gd")
const Entry = preload("res://systems/record_entry.gd")
var wanted := false
var view_id := -1
var page := 0
var state: Dictionary = {}
var tabs: Array = []
var body: VBoxContainer
var image_nodes: Dictionary = {}
var entry_nodes: Dictionary = {}
var selected: Dictionary = {}
var scrolls: Dictionary = {}
var active_scrolls: Dictionary = {}
var description: RichTextLabel
var notice: Label
var level_button: Button

func setup(storage: String = "user://native-menu-layout.cfg") -> void:
	configure("Character Record", "character-sheet", Vector2(110, 80), storage)
	custom_minimum_size = Vector2(740, 650)
	var navigation := HBoxContainer.new(); content.add_child(navigation)
	for index in 3:
		var button := Button.new(); button.text = ["Character", "Skills", "Feats"][index]; button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(func():
			if view_id >= 0: request.emit({"kind": "sheet-page", "viewId": view_id, "page": index}))
		navigation.add_child(button); tabs.append(button)
	level_button = Button.new(); level_button.text = "Level Up"; level_button.focus_mode = Control.FOCUS_NONE; level_button.pressed.connect(func(): level_requested.emit()); navigation.add_child(level_button); level_button.hide()
	body = VBoxContainer.new(); content.add_child(body)
	notice = Label.new(); notice.add_theme_font_size_override("font_size", 12); content.add_child(notice)
	close_requested.connect(close_sheet)
	reset()

func reset() -> void:
	wanted = false; view_id = -1; page = 0
	if is_instance_valid(level_button): level_button.hide()
	state.clear(); selected.clear(); scrolls.clear(); clear_body(); hide()

func clear_body() -> void:
	for child in body.get_children(): body.remove_child(child); child.queue_free()
	image_nodes.clear(); entry_nodes.clear(); active_scrolls.clear(); description = null

func open() -> void:
	wanted = true; show(); move_to_front(); notice.text = "Waiting for server character details…"
	request.emit({"kind": "sheet-open", "page": page})

func close_sheet() -> void:
	save_scrolls(); wanted = false; hide(); request.emit({"kind": "sheet-close"})

func save_scrolls() -> void:
	for key in active_scrolls: scrolls[str(page) + ":" + key] = active_scrolls[key].scroll_vertical

func receive(message: Dictionary) -> void:
	match message.kind:
		"sheet-closed":
			view_id = -1; state.clear(); clear_body(); hide()
		"sheet-notice": notice.text = str(message.text)
		"sheet-view":
			if not wanted: return
			save_scrolls()
			if not state.is_empty() and state.model.identity != message.model.identity: selected.clear(); scrolls.clear()
			state = message.duplicate(true); view_id = int(message.viewId); page = int(message.page)
			render()
		"sheet-image":
			if not wanted or int(message.viewId) != view_id or not image_nodes.has(str(message.key)): return
			var texture: Texture2D = Images.png(str(message.image), 1024)
			if texture != null: image_nodes[str(message.key)].texture = texture

func value(raw: Variant) -> String:
	if raw == null: return "—"
	if raw is float and is_equal_approx(raw, roundf(raw)): return str(int(raw))
	return str(raw)

func scroll_box(key: String, size_hint: Vector2) -> ScrollContainer:
	var scroll := ScrollContainer.new(); scroll.custom_minimum_size = size_hint; scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	active_scrolls[key] = scroll
	return scroll

func picture(key: String, size_hint: Vector2) -> TextureRect:
	var image := TextureRect.new(); image.custom_minimum_size = size_hint; image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED; image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	image_nodes[key] = image
	return image

func render() -> void:
	clear_body()
	var model: Dictionary = state.model
	set_caption("Character Record, " + str(model.get("name", "—")))
	for index in tabs.size(): tabs[index].disabled = index == page
	if page == 0: statistics(model)
	else: entries()
	for key in active_scrolls: active_scrolls[key].set_deferred("scroll_vertical", int(scrolls.get(str(page) + ":" + key, 0)))
	notice.text = "Select a skill or feat to read its description. Drag available entries to the quickbar." if page > 0 else ("Level-up available on the server." if state.get("canLevelUp", false) else "")
	_clamp()

func statistics(model: Dictionary) -> void:
	var overview := HBoxContainer.new(); body.add_child(overview)
	overview.add_child(picture("portrait", Vector2(128, 200)))
	var right := VBoxContainer.new(); right.size_flags_horizontal = Control.SIZE_EXPAND_FILL; overview.add_child(right)
	right.add_child(Text.label({"text": str(model.get("race", "")) + ", " + str(model.get("alignment", ""))}, 520))
	for line in model.get("classes", []): right.add_child(Text.label({"text": str(line)}, 520))
	var grid := GridContainer.new(); grid.columns = 4; right.add_child(grid)
	for ability in model.abilities:
		var label := Label.new(); label.text = str(ability.label); grid.add_child(label)
		grid.add_child(picture("ability:" + str(ability.key), Vector2(24, 24)))
		for key in ["score", "modifier"]:
			var number := Label.new(); number.text = value(ability.get(key))
			number.name = str(ability.key) + "_" + key
			if key == "modifier" and ability.get(key) != null and int(ability[key]) > 0: number.text = "+" + number.text
			var adjustment: int = int(ability.get("adjustment" if key == "score" else "modifierAdjustment", 0))
			if adjustment != 0: number.add_theme_color_override("font_color", Color.LIME_GREEN if adjustment > 0 else Color.ORANGE_RED)
			grid.add_child(number)
	var vitals := HBoxContainer.new(); body.add_child(vitals)
	vitals.add_child(Text.label({"text": "AC: %s    HP: %s / %s" % [value(model.get("armorClass")), value(model.get("currentHP")), value(model.get("maximumHP"))]}, 330))
	vitals.add_child(Text.label({"text": "%s: %s\n%s: %s" % [str(model.labels.get("experience", "Experience")), value(model.get("experience")), str(model.labels.get("nextLevel", "Next level")), value(model.get("nextExperience"))]}, 330))
	var scroll := scroll_box("details", Vector2(700, 240)); body.add_child(scroll)
	var details := VBoxContainer.new(); details.size_flags_horizontal = Control.SIZE_EXPAND_FILL; scroll.add_child(details)
	for row in model.details:
		var spans: Array = [{"text": str(row.label).strip_edges().trim_suffix(":") + ": "}] if row.get("label", "") != "" else []
		spans.append_array(row.get("parts", [{"text": value(row.get("value"))}]))
		details.add_child(Text.label({"spans": spans}, 680))

func entries() -> void:
	var split := HBoxContainer.new(); body.add_child(split)
	var text_scroll := scroll_box("description", Vector2(340, 480)); split.add_child(text_scroll)
	description = Text.label({}, 320); text_scroll.add_child(description)
	var list_scroll := scroll_box("entries", Vector2(350, 480)); split.add_child(list_scroll)
	var list := VBoxContainer.new(); list.size_flags_horizontal = Control.SIZE_EXPAND_FILL; list_scroll.add_child(list)
	for row in state.entries:
		var button := Entry.new(); button.setup(self, row); list.add_child(button)
		entry_nodes[int(row.entryId)] = button; image_nodes["entry:" + str(int(row.entryId))] = button.image
		if int(row.id) == int(selected.get(str(page), -1)): select_entry(int(row.entryId))
	if state.entries.is_empty(): list.add_child(Text.label({"text": str(state.model.get("waiting", {}).get("Skills" if page == 1 else "Feats", "Waiting for server details…"))}, 320))

func select_entry(id: int) -> void:
	if not wanted: return
	for row in state.get("entries", []):
		if int(row.entryId) == id:
			selected[str(page)] = int(row.id)
			Text.set_text(description, row.description)
			for entry_id in entry_nodes: entry_nodes[entry_id].modulate = Color(1.0, 0.86, 0.5) if entry_id == id else Color.WHITE
			if active_scrolls.has("description"): active_scrolls.description.scroll_vertical = 0
			return

func can_drag(data: Dictionary) -> bool:
	return wanted and int(data.get("viewId", -1)) == view_id and state.get("entries", []).any(func(row): return int(row.entryId) == int(data.get("entryId", -1)) and row.get("canDrag", false))
