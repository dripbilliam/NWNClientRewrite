extends "res://systems/draggable_panel.gd"

signal request(message: Dictionary)
signal rendered
const Slot = preload("res://systems/spell_slot.gd")
const Images = preload("res://systems/runtime_image.gd")
const Text = preload("res://systems/server_text.gd")
var view_id := -1
var state: Dictionary = {}
var rows: Dictionary = {}
var widgets: Dictionary = {}
var selected_id := -1
var classes: HBoxContainer
var levels: HBoxContainer
var meta: OptionButton
var lists: HBoxContainer
var family_box: VBoxContainer
var details: RichTextLabel
var notice: Label
var cast: Button
var memorize: Button
var clear: Button
var changing := false
var wanted := false
var scrolls: Dictionary = {}
var scroll_positions: Dictionary = {}
var native_skin
var pending_view: Dictionary={}
func _process(_delta: float) -> void:
	if not wanted or pending_view.is_empty(): set_process(false); return
	if not is_instance_valid(native_skin):
		var ready_view:=pending_view; pending_view={}; present(ready_view); return
	if not str(native_skin.failure).is_empty():
		notice.text="Original spellbook frame could not be prepared: "+str(native_skin.failure)
		show(); set_process(false); return
	if native_skin.view_icons_ready(pending_view):
		var ready_view:=pending_view; pending_view={}; present(ready_view)

func setup(storage: String = "user://native-menu-layout.cfg") -> void:
	configure("Spellbook", "spellbook", Vector2(70, 170), storage)
	custom_minimum_size = Vector2(700, 580)
	classes = HBoxContainer.new()
	content.add_child(classes)
	levels = HBoxContainer.new()
	content.add_child(levels)
	for level in 10:
		var button := Button.new()
		button.text = str(level)
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(func(): query({"level": level}))
		levels.add_child(button)
	meta = OptionButton.new()
	meta.focus_mode = Control.FOCUS_NONE
	meta.item_selected.connect(func(index):
		if not changing:
			query({"metamagic": meta.get_item_id(index)}))
	content.add_child(meta)
	lists = HBoxContainer.new()
	content.add_child(lists)
	family_box = VBoxContainer.new()
	content.add_child(family_box)
	details = RichTextLabel.new()
	details.custom_minimum_size = Vector2(650, 76)
	details.scroll_active = true
	Text.style(details)
	content.add_child(details)
	var actions := HBoxContainer.new()
	content.add_child(actions)
	cast = action_button(actions, "Cast / target", func(): operation("book-activate"))
	memorize = action_button(actions, "Prepare in empty slot", func(): operation("book-prepare"))
	clear = action_button(actions, "Clear prepared slot", func(): operation("book-clear"))
	notice = Label.new()
	notice.text = "Select a spell · Double-click or Cast to target · Drag a variant to the quickbar"
	notice.add_theme_font_size_override("font_size", 12)
	content.add_child(notice)
	close_requested.connect(func():
		wanted = false
		request.emit({"kind": "spellbook-close"}))
	resized.connect(_fit_above_quickbar)
	reset()

func _fit_above_quickbar() -> void:
	if is_instance_valid(native_skin) and native_skin.layout_ready: return
	# Growing a family panel should leave the docked drag destination visible.
	# This changes position only, never minimum size during a layout callback.
	position.y = minf(position.y, maxf(0, get_viewport_rect().size.y - 110 - size.y))

func action_button(parent: Node, label: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = label
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func reset() -> void:
	wanted = false
	pending_view.clear()
	set_process(false)
	view_id = -1
	state.clear()
	rows.clear()
	widgets.clear()
	selected_id = -1
	scrolls.clear()
	scroll_positions.clear()
	if is_instance_valid(lists):
		wipe(lists)
		wipe(family_box)
		wipe(classes)
		details.clear()
	hide()

func open() -> void:
	wanted = true
	pending_view.clear()
	if not is_instance_valid(native_skin):
		show()
		move_to_front()
	else: hide()
	notice.text = "Loading spellbook…"
	request.emit({"kind": "spellbook-open"})

func query(change: Dictionary) -> void:
	var value := {"kind": "spellbook-query", "classIndex": state.get("classIndex", 0), "level": state.get("level", 0), "metamagic": state.get("metamagic", 0)}
	value.merge(change, true)
	request.emit(value)

func wipe(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()

func receive(message: Dictionary) -> void:
	match message.kind:
		"book-notice": notice.text = str(message.text)
		"book-description":
			if int(message.viewId) == view_id and int(message.entryId) == selected_id:
				Text.set_text(details, message.rich)
		"book-icon":
			if int(message.viewId) == view_id and widgets.has(int(message.entryId)):
				widgets[int(message.entryId)].image.texture = Images.png(str(message.image), 512)
		"spellbook-view":
			if wanted:
				present(message)

func present(message: Dictionary) -> void:
	if is_instance_valid(native_skin) and not native_skin.view_icons_ready(message):
		pending_view=message
		hide()
		set_process(true)
		return
	pending_view.clear()
	set_process(false)
	var old_key := str(rows.get(selected_id, {}).get("key", ""))
	if is_instance_valid(native_skin) and native_skin.layout_ready: native_skin.begin_render()
	for key in scrolls:
		scroll_positions[key] = scrolls[key].scroll_vertical
	scrolls.clear()
	view_id = int(message.viewId)
	state = message
	rows.clear()
	widgets.clear()
	selected_id = -1
	changing = true
	wipe(classes)
	for cls in message.classes:
		var button := action_button(classes, str(cls.label), func(): query({"classIndex": cls.index, "metamagic": 0}))
		button.disabled = int(cls.index) == int(message.classIndex)
	for level in 10:
		levels.get_child(level).disabled = level == int(message.level)
	meta.clear()
	for row in message.metas:
		meta.add_item(str(row.label), int(row.value))
		if int(row.value) == int(message.metamagic):
			meta.select(meta.item_count - 1)
	changing = false
	wipe(lists)
	make_list(lists, "Known spells", message.known)
	if message.prepared:
		make_list(lists, "Prepared · level %s" % int(message.level), message.memory)
	wipe(family_box)
	if not str(message.familyTitle).is_empty():
		action_button(family_box, "← " + str(message.familyTitle), func(): request.emit({"kind": "book-family-back", "viewId": view_id}))
		make_list(family_box, "Choose a variant; drag it to the quickbar", message.family, 110)
	cast.disabled = true
	memorize.disabled = true
	clear.disabled = true
	notice.text = "Select a spell · Double-click or Cast to target · Drag to the quickbar"
	var kept := false
	for id in rows:
		if not old_key.is_empty() and str(rows[id].get("key", "")) == old_key:
			select_entry(id, true)
			kept = true
			break
	if not kept:
		details.clear()
	show()
	if is_instance_valid(native_skin):
		var icon_error: String=native_skin.view_icon_error(message)
		if not icon_error.is_empty(): notice.text="Original spell icon unavailable: "+icon_error
	if is_instance_valid(native_skin) and native_skin.layout_ready: native_skin.render()
	rendered.emit()

func make_list(parent: Node, caption: String, entries: Array, height: float = 220) -> void:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(column)
	var heading := Label.new()
	heading.text = caption
	column.add_child(heading)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(280, height)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	var scroll_key := "%s:%s:%s:%s" % [state.classIndex, state.level, state.metamagic, caption]
	scrolls[scroll_key] = scroll
	scroll.set_deferred("scroll_vertical", scroll_positions.get(scroll_key, 0))
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	for row in entries:
		var id := int(row.entryId)
		var owner_view := view_id
		rows[id] = row
		var button := Slot.new()
		if is_instance_valid(native_skin) and native_skin.layout_ready: button.right_click_activates=false
		var ready_text := (" · Ready" if row.ready else " · Used / rest required") if entries == state.get("memory", []) and int(row.spellId) >= 0 else ""
		button.setup(str(row.label) + (" ›" if row.family else "") + ready_text + (" · waiting" if row.pending else ""), row.uses if int(row.spellId) >= 0 else null)
		if row.canDrag and not row.pending:
			button.payload = {"kind": "spell", "viewId": view_id, "entryId": id}
		button.selected.connect(func():
			if wanted and view_id == owner_view and widgets.get(id)==button:
				select_entry(id))
		button.activated.connect(func():
			if not wanted or view_id != owner_view or widgets.get(id)!=button:
				return
			select_entry(id)
			if not row.family:
				operation("book-activate"))
		button.accepts = func(data): return wanted and view_id == owner_view and widgets.get(id)==button and data.get("kind") == "spell" and int(data.get("viewId", -2)) == owner_view and rows.has(int(data.get("entryId", -1))) and not row.pending and not rows[int(data.entryId)].pending and int(rows[int(data.entryId)].classIndex)==int(row.classIndex) and int(rows[int(data.entryId)].level)==int(row.level) and row.get("slot", -1) >= 0 and entries == state.get("memory", [])
		button.dropped.connect(func(data):
			if wanted and view_id == owner_view and widgets.get(id)==button:
				request.emit({"kind": "book-prepare", "viewId": owner_view, "entryId": data.entryId, "destinationId": id}))
		list.add_child(button)
		widgets[id] = button
	if entries.is_empty():
		var empty := Label.new()
		empty.text = "No spells at this level."
		list.add_child(empty)

func select_entry(id: int, restoring: bool = false) -> void:
	if not rows.has(id):
		return
	if not restoring and id != selected_id:
		details.clear()
	selected_id = id
	var row: Dictionary = rows[id]
	cast.disabled = not row.canCast or row.family or row.pending
	memorize.disabled = not state.prepared or int(row.spellId) < 0 or int(row.get("slot",-1))>=0 or row.pending
	clear.disabled = int(row.spellId) < 0 or not state.memory.any(func(w): return int(w.entryId) == id) or row.pending
	if not row.family or not restoring:
		request.emit({"kind": "book-family" if row.family else "book-inspect", "viewId": view_id, "entryId": id})
	if is_instance_valid(native_skin) and native_skin.layout_ready: native_skin.select_entry()

func operation(kind: String) -> void:
	if view_id >= 0 and selected_id >= 0:
		request.emit({"kind": kind, "viewId": view_id, "entryId": selected_id})
