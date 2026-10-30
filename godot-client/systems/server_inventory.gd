extends "res://systems/draggable_panel.gd"

signal request(message: Dictionary)
signal menu_requested(entry_id: int, point: Vector2)
const Slot = preload("res://systems/inventory_slot.gd")
const Repository = preload("res://systems/inventory_repository.gd")
const Images = preload("res://systems/runtime_image.gd")
var state: Dictionary = {}
var items: Dictionary = {}
var buttons: Dictionary = {}
var textures: Dictionary = {}
var view_id := -1
var wanted := false
var selected := -1
var creature_slots := false
var equipment: Control
var repository
var container_box: VBoxContainer
var container_repository
var container_title: Label
var container_page: Label
var container_controls: Dictionary = {}
var notice: Label
var footer: Label
var ac: Label
var pages: Array = []
var examine_mode := false
var item_controls: Dictionary = {}
var blocked_container_serial := -1
var blocked_store_generation := -1
var store_panel
var native_store
var layout_storage := ""
var native_equipment
var native_frame
var gold_owner
var barter_owner

func setup(storage: String = "user://native-menu-layout.cfg") -> void:
	layout_storage = storage
	configure("Inventory", "inventory", Vector2(80, 95), storage)
	custom_minimum_size = Vector2(450, 660)
	equipment = Control.new()
	equipment.custom_minimum_size = Vector2(420, 240)
	content.add_child(equipment)
	ac = Label.new()
	ac.position = Vector2(85, 132)
	ac.mouse_filter = Control.MOUSE_FILTER_IGNORE
	equipment.add_child(ac)
	container_box = VBoxContainer.new()
	content.add_child(container_box)
	container_title = Label.new()
	container_box.add_child(container_title)
	var controls := HBoxContainer.new()
	container_box.add_child(controls)
	for definition in [["Previous", "previous"], ["Next", "next"], ["Close container", "close"]]:
		var button := Button.new()
		button.text = definition[0]
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(func(): request.emit({"kind": "inventory-container", "viewId": view_id, "operation": definition[1]}))
		controls.add_child(button)
		container_controls[definition[1]] = button
	container_page = Label.new()
	controls.add_child(container_page)
	container_repository = Repository.new()
	container_repository.inventory = self
	container_repository.channel = "C"
	container_repository.columns = 7
	container_repository.rows = 5
	container_repository.custom_minimum_size = Vector2(280, 200)
	container_repository.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	container_box.add_child(container_repository)
	container_box.hide()
	var row := HBoxContainer.new()
	content.add_child(row)
	repository = Repository.new()
	repository.inventory = self
	repository.custom_minimum_size = Vector2(400, 240)
	row.add_child(repository)
	var pager := VBoxContainer.new()
	row.add_child(pager)
	for page in 6:
		var button := Button.new()
		button.text = str(page + 1)
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(func(): request.emit({"kind": "inventory-page", "viewId": view_id, "page": page}))
		pager.add_child(button)
		pages.append(button)
	footer = Label.new()
	content.add_child(footer)
	var actions := HBoxContainer.new()
	content.add_child(actions)
	for entry in [["Examine", "examine"], ["Use / equip", "activate"], ["Drop", "drop"]]:
		var button := Button.new()
		button.text = entry[0]
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(func():
			if entry[1]=="examine" and native_frame!=null and native_frame.layout_ready:
				examine_mode=not examine_mode; button.set_pressed_no_signal(examine_mode); return
			if selected >= 0: operation(selected, entry[1]))
		actions.add_child(button)
		item_controls[entry[1]] = button
	notice = Label.new()
	notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notice.custom_minimum_size = Vector2(420, 30)
	notice.add_theme_font_size_override("font_size", 12)
	content.add_child(notice)
	close_requested.connect(close_inventory)
	reset()

func reset() -> void:
	view_id = -1; selected = -1; wanted = false
	examine_mode=false
	blocked_container_serial = -1
	blocked_store_generation = -1
	if is_instance_valid(store_panel): store_panel.reset()
	state.clear(); items.clear(); textures.clear(); buttons.clear()
	if equipment != null:
		wipe(equipment); wipe(repository)
		wipe(container_repository)
		container_box.hide()
		equipment.show()
	hide()

func wipe(node: Node) -> void:
	for child in node.get_children():
		if child == ac or child.has_meta("native_inventory_art"): continue
		node.remove_child(child)
		child.queue_free()

func open() -> void:
	wanted = true
	show(); move_to_front()
	notice.text = "Waiting for server inventory…"
	request.emit({"kind": "inventory-open"})

func close_inventory() -> void:
	examine_mode=false
	blocked_container_serial = int(state.get("container", {}).get("serial", -1))
	blocked_store_generation = int(state.get("store", {}).get("generation", -1))
	if is_instance_valid(store_panel): store_panel.hide()
	wanted = false
	hide()
	request.emit({"kind": "inventory-close"})

func receive(message: Dictionary) -> void:
	match message.kind:
		"inventory-closed":
			var serial := blocked_container_serial
			var store_generation := blocked_store_generation
			reset()
			blocked_container_serial = serial
			blocked_store_generation = store_generation
		"inventory-notice": notice.text = str(message.text)
		"inventory-view":
			if not wanted:
				var store: Dictionary = message.get("store", {})
				var new_store: bool = store.get("open", false) and int(store.get("generation", -1)) > blocked_store_generation
				var container: Dictionary = message.get("container", {})
				var new_container := int(container.get("ownerId", 2130706432)) != 2130706432 and int(container.get("serial", -1)) > blocked_container_serial
				if not message.get("automatic", false) or not (new_store or new_container): return
				wanted = true
				show(); move_to_front()
			var selected_item: int = int(items[selected].itemId) if items.has(selected) else -1
			view_id = int(message.viewId)
			state = message.duplicate(true)
			items.clear(); textures.clear()
			for item in message.items: items[int(item.entryId)] = item
			selected = -1
			for id in items:
				if int(items[id].itemId) == selected_item: selected = id; break
			render()
		"inventory-icon":
			if int(message.viewId) != view_id: return
			var texture: Texture2D = Images.png(str(message.image), 512)
			if texture == null: return
			textures[int(message.entryId)] = texture
			if buttons.has(int(message.entryId)):
				buttons[int(message.entryId)].set_icon(texture)

func render() -> void:
	if state.is_empty(): return
	wipe(equipment); wipe(repository); wipe(container_repository); buttons.clear()
	set_caption("Inventory" + (": " + str(state.title) if not str(state.title).is_empty() else ""))
	equipment.custom_minimum_size.y = 320 if creature_slots else 240
	if native_equipment!=null and native_equipment.layout_ready:
		equipment.custom_minimum_size.y=native_equipment.definition.bounds.size.y+(80 if creature_slots else 0)
		native_equipment.apply_label()
	var container: Dictionary = state.get("container", {})
	var opened := int(container.get("ownerId", 2130706432)) != 2130706432
	container_box.visible = opened
	var store: Dictionary = state.get("store", {})
	equipment.visible = not opened and not store.get("open", false)
	for key in ["activate", "drop"]: item_controls[key].visible = not store.get("open", false)
	container_title.text = str(container.get("title", "Container"))
	container_page.text = "%s / %s" % [int(container.get("page", 0)) + 1, int(container.get("pageCount", 1))]
	for key in ["previous", "next"]: container_controls[key].disabled = int(container.get("pageCount", 1)) <= 1
	for layout in native_equipment.rows(creature_slots) if native_equipment!=null and native_equipment.layout_ready else state.layout:
		if int(layout.slot) >= 16384 and not creature_slots: continue
		var item := {}
		for value in items.values():
			if value.channel == "I" and int(value.slot) == int(layout.slot): item = value; break
		var button := Slot.new()
		button.setup(self, item, int(layout.slot))
		button.position = Vector2(layout.x, layout.y)
		button.size = Vector2(layout.w, layout.h)
		if item.is_empty(): button.tooltip_text = layout.label
		equipment.add_child(button)
		if native_equipment!=null: native_equipment.bind_slot(button,layout)
		if item.has("entryId"): register_button(item, button)
	if ac.get_parent() == null: equipment.add_child(ac)
	ac.move_to_front()
	ac.text = "AC: " + (str(int(state.armorClass)) if state.armorClass != null else "—")
	for item in items.values():
		var target = container_repository if item.channel == "C" else repository
		var page: int = int(container.get("page", 0)) if item.channel == "C" else int(state.page)
		var page_rows := 5 if item.channel == "C" else 6
		if item.channel not in ["R", "C"] or floori(float(item.y) / page_rows) != page: continue
		if item.channel == "C" and not opened: continue
		var button := Slot.new()
		button.setup(self, item)
		button.position=target.item_position(item)
		button.size=target.item_size(item)
		target.add_child(button)
		if native_frame!=null: native_frame.decorate_item(button,target,item)
		register_button(item, button)
	for index in pages.size(): pages[index].disabled = index == int(state.page)
	if store.get("open", false) and not is_instance_valid(store_panel):
		store_panel = preload("res://systems/server_store.gd").new()
		store_panel.setup(self, layout_storage)
		get_parent().add_child(store_panel)
		if native_store!=null: native_store.attach(store_panel)
	if is_instance_valid(store_panel): store_panel.render(store)
	var summary: Dictionary = state.summary
	footer.text = "%s / %s lbs.                  GP: %s" % [str(int(summary.weight)) if summary.weight != null else "—", str(int(summary.capacity)) if summary.capacity != null else "—", str(int(summary.gold)) if summary.gold != null else "—"]
	notice.text = "Click or drag an item to select Buy / Sell." if store.get("open", false) else "Double-click: use / equip · Drag: move / equip · Right-click: actions"
	if native_frame!=null: native_frame.refresh()
	_clamp()

func register_button(item: Dictionary, button) -> void:
	var id := int(item.entryId)
	buttons[id] = button
	if textures.has(id): button.set_icon(textures[id])

func install_native_icon(view: int,entry: int,texture: Texture2D) -> bool:
	if view!=view_id or texture==null or not items.has(entry): return false
	textures[entry]=texture
	if buttons.has(entry): buttons[entry].set_icon(texture)
	return true

func select_item(id: int) -> void:
	if examine_mode and items.has(id):
		examine_mode=false; item_controls.examine.set_pressed_no_signal(false); operation(id,"examine"); return
	selected = id
	if items.has(id): notice.text = str(items[id].name)
	if is_instance_valid(store_panel) and state.get("store", {}).get("open", false): store_panel.select_item(id)

func operation(id: int, action: String, fields: Dictionary = {}) -> void:
	if not wanted or view_id < 0 or not items.has(id): return
	if state.get("store", {}).get("open", false) and action != "examine": select_item(id); return
	var message := {"kind": "inventory-activate" if action == "activate" else "inventory-action", "viewId": view_id, "entryId": id, "operation": action}
	message.merge(fields)
	request.emit(message)

func item_menu(id: int, point: Vector2) -> void:
	select_item(id)
	menu_requested.emit(id, point)

func can_drop(data: Variant, slot: int) -> bool:
	if not data is Dictionary or data.get("kind") != "native-inventory-item" or int(data.get("viewId", -1)) != view_id or not items.has(int(data.get("entryId", -1))): return false
	var item: Dictionary = items[int(data.entryId)]
	if state.get("store", {}).get("open", false) and slot != 0: return false
	return not item.pending and (slot == 0 or (int(item.slotMask) & slot) != 0)

func can_shortcut(data: Dictionary) -> bool:
	if not wanted or int(data.get("viewId", -1)) != view_id or not items.has(int(data.get("entryId", -1))): return false
	var item: Dictionary = items[int(data.entryId)]
	return not item.get("pending", false) and item.get("channel", "") in ["R", "I"]

func drop_slot(data: Dictionary, slot: int) -> void:
	operation(int(data.entryId), "equip", {"slot": slot})

func _exit_tree() -> void:
	if is_instance_valid(store_panel): store_panel.queue_free()

func blocks_pointer(point: Vector2) -> bool:
	return (visible and get_global_rect().has_point(point)) or (is_instance_valid(store_panel) and store_panel.blocks_pointer(point))
