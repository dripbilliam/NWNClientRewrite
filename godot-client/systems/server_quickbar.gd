extends PanelContainer

signal request(message: Dictionary)
signal spellbook_requested
signal inventory_requested
signal character_requested
signal map_requested
signal journal_requested
signal level_requested
signal options_requested
signal assignment_requested(index: int, point: Vector2)
const Slot = preload("res://systems/spell_slot.gd")
const Images = preload("res://systems/runtime_image.gd")
var quickbar_id := -1
var page := 0
var shown_page := 0
var selected_index := -1
var rows: Array = []
var buttons: Dictionary = {}
var pages: Array[Button] = []
var cells: HBoxContainer
var caption: Label
var clear: Button
var textures: Dictionary = {}
var secondary_textures: Dictionary = {}
var record_valid: Callable
var inventory_valid: Callable
var radial_valid: Callable
var level_button: Button

func setup() -> void:
	var outer := VBoxContainer.new()
	add_child(outer)
	var navigation := HBoxContainer.new()
	outer.add_child(navigation)
	for index in 3:
		var button := Button.new()
		button.text = str(index + 1)
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(func():
			page = index
			render(index))
		navigation.add_child(button)
		pages.append(button)
	var book := Button.new()
	book.text = "Spellbook · B"
	book.focus_mode = Control.FOCUS_NONE
	book.pressed.connect(func(): spellbook_requested.emit())
	navigation.add_child(book)
	for definition in [["Inventory · I", "inventory"], ["Character · C", "character"], ["Map · M", "map"], ["Journal · J", "journal"], ["Options", "options"]]:
		var button := Button.new()
		button.text = definition[0]
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(func():
			if definition[1] == "inventory": inventory_requested.emit()
			elif definition[1] == "character": character_requested.emit()
			elif definition[1] == "map": map_requested.emit()
			elif definition[1] == "journal": journal_requested.emit()
			else: options_requested.emit())
		navigation.add_child(button)
	clear = Button.new()
	clear.text = "Clear selected slot"
	clear.focus_mode = Control.FOCUS_NONE
	clear.pressed.connect(func():
		if selected_index >= 0:
			request.emit({"kind": "quickbar-clear", "quickbarId": quickbar_id, "index": selected_index}))
	navigation.add_child(clear)
	level_button = Button.new(); level_button.text = "Level Up"; level_button.focus_mode = Control.FOCUS_NONE; level_button.pressed.connect(func(): level_requested.emit()); navigation.add_child(level_button); level_button.hide()
	caption = Label.new()
	caption.add_theme_font_size_override("font_size", 12)
	navigation.add_child(caption)
	cells = HBoxContainer.new()
	outer.add_child(cells)
	get_viewport().size_changed.connect(place)
	reset()

func reset() -> void:
	quickbar_id = -1
	selected_index = -1
	page = 0
	rows.clear()
	buttons.clear()
	textures.clear()
	secondary_textures.clear()
	if is_instance_valid(level_button): level_button.hide()

	if is_instance_valid(cells):
		for child in cells.get_children():
			cells.remove_child(child)
			child.queue_free()
	hide()

func place() -> void:
	position = Vector2(maxf(0, (get_viewport_rect().size.x - size.x) / 2), maxf(0, get_viewport_rect().size.y - size.y - 8))

func receive(message: Dictionary) -> void:
	if message.kind == "quickbar-icon":
		if int(message.quickbarId) == quickbar_id:
			var images: Dictionary = secondary_textures if message.get("secondary", false) else textures
			images[int(message.index)] = Images.png(str(message.image), 512)
			if buttons.has(int(message.index)):
				if message.get("secondary", false): buttons[int(message.index)].secondary_image.texture = images[int(message.index)]
				else: buttons[int(message.index)].image.texture = images[int(message.index)]
	elif message.kind == "quickbar-view":
		textures.clear()
		secondary_textures.clear()
		quickbar_id = int(message.quickbarId)
		rows = message.rows
		render(shown_page)
		show()
		call_deferred("place")

func render(index: int) -> void:
	shown_page = index
	buttons.clear()
	for child in cells.get_children():
		cells.remove_child(child)
		child.queue_free()
	for i in 12:
		var slot := index * 12 + i
		var owner_view := quickbar_id
		if slot >= rows.size():
			continue
		var row: Dictionary = rows[slot]
		var button := Slot.new()
		button.setup(str(row.label), row.uses, true)
		button.image.texture = textures.get(slot)
		button.secondary_image.texture = secondary_textures.get(slot)
		if not row.empty:
			button.payload = {"kind": "shortcut", "quickbarId": quickbar_id, "sourceIndex": slot}
		button.selected.connect(func():
			if quickbar_id == owner_view:
				activate(slot))
		button.activated.connect(func():
			if quickbar_id != owner_view:
				return
			selected_index = slot
			caption.text = "Selected F%s · %s" % [slot % 12 + 1, str(row.label).left(30)]
			clear.disabled = false)
		button.context_requested.connect(func(point):
			if quickbar_id == owner_view: assignment_requested.emit(slot,point))
		button.accepts = func(data): return quickbar_id == owner_view and (data.get("kind") == "spell" and data.has("viewId") and data.has("entryId") or data.get("kind") == "record-entry" and record_valid.is_valid() and record_valid.call(data) or data.get("kind") == "native-inventory-item" and inventory_valid.is_valid() and inventory_valid.call(data) or data.get("kind") == "radial-entry" and radial_valid.is_valid() and radial_valid.call(data) or data.get("kind") == "shortcut" and int(data.get("quickbarId", -2)) == owner_view and data.has("sourceIndex"))
		button.dropped.connect(func(data):
			if quickbar_id != owner_view:
				return
			if data.kind == "spell":
				request.emit({"kind": "quickbar-assign", "viewId": data.viewId, "entryId": data.entryId, "index": slot})
			elif data.kind == "record-entry":
				request.emit({"kind": "sheet-assign", "viewId": data.viewId, "entryId": data.entryId, "index": slot})
			elif data.kind == "native-inventory-item":
				request.emit({"kind": "inventory-shortcut", "quickbarId": owner_view, "viewId": data.viewId, "entryId": data.entryId, "index": slot})
			elif data.kind == "radial-entry":
				request.emit({"kind":"radial-shortcut","quickbarId":owner_view,"requestId":data.requestId,"menuId":data.menuId,"slot":data.slot,"index":slot})
			else:
				request.emit({"kind": "quickbar-move", "quickbarId": quickbar_id, "sourceIndex": data.sourceIndex, "index": slot}))
		button.modulate = Color(1, 1, 1, 1.0 if row.enabled or row.empty else 0.5)
		var key := Label.new()
		key.text = "F%s" % (i + 1)
		key.position = Vector2(23, 41)
		key.add_theme_font_size_override("font_size", 10)
		key.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(key)
		cells.add_child(button)
		buttons[slot] = button
	for i in 3:
		pages[i].disabled = i == index
	clear.disabled = selected_index < 0

func activate(index: int) -> void:
	if quickbar_id >= 0 and index < rows.size() and rows[index].enabled:
		request.emit({"kind": "quickbar-activate", "quickbarId": quickbar_id, "index": index})

func _input(event: InputEvent) -> void:
	if not visible or not event is InputEventKey:
		return
	var focus := get_viewport().gui_get_focus_owner()
	if focus is LineEdit or focus is TextEdit or event.ctrl_pressed and event.alt_pressed:
		return
	if event.keycode in [KEY_SHIFT, KEY_CTRL]:
		render(2 if event.ctrl_pressed else (1 if event.shift_pressed else page))
	if not event.pressed or event.echo:
		return
	if event.keycode == KEY_B:
		spellbook_requested.emit()
		get_viewport().set_input_as_handled()
	elif event.keycode >= KEY_F1 and event.keycode <= KEY_F12:
		var index := (2 if event.ctrl_pressed else (1 if event.shift_pressed else page)) * 12 + int(event.keycode - KEY_F1)
		activate(index)
		get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT and is_instance_valid(cells) and visible:
		render(page)
