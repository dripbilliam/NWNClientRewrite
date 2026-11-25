extends "res://systems/draggable_panel.gd"

signal request(message: Dictionary)
signal menu_requested(entry_id: int, point: Vector2)
const Slot = preload("res://systems/inventory_slot.gd")
const Repository = preload("res://systems/inventory_repository.gd")
const Images = preload("res://systems/runtime_image.gd")
const SceneHost = preload("res://systems/native_item_icon_panel_host.gd")
var state: Dictionary = {}
var items: Dictionary = {}
var buttons: Dictionary = {}
var textures: Dictionary = {}
var scene_host
var scene_icon_source
var scene_icon_backend_selected:=false
var scene_icon_bindings: Dictionary={}
var scene_icon_sealed:=false
var scene_icon_failure:=""
var view_id := -1
var wanted := false
var native_icon_gate := false
var item_commands_enabled:=true
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
var drag_tab_timer: Timer
var drag_tab := -1
var click_pickup:=false:
	set(enabled):
		if not enabled and click_pickup and active_item_drag().get("clickPickup",false): cancel_item_drag()
		click_pickup=enabled
var click_tab_pressed:=false
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
var item_tooltips
var structural_key: Variant=null
var equipment_controls: Dictionary={}
var repository_controls: Dictionary={}

func setup(storage: String = "user://native-menu-layout.cfg",window_key: String="inventory") -> void:
	layout_storage = storage
	configure("Inventory", window_key, Vector2(80,95) if window_key=="inventory" else Vector2(560,95), storage)
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
	drag_tab_timer=Timer.new()
	drag_tab_timer.one_shot=true
	drag_tab_timer.wait_time=0.35
	drag_tab_timer.timeout.connect(_switch_drag_tab)
	add_child(drag_tab_timer)
	for page in 6:
		var button := Button.new()
		button.text = str(page + 1)
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(_request_page.bind(page))
		button.mouse_entered.connect(func(): _hover_drag_tab(page))
		button.mouse_exited.connect(func():
			if drag_tab==page: drag_tab_timer.stop())
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
	cancel_item_drag()
	view_id = -1; selected = -1; wanted = false
	examine_mode=false
	blocked_container_serial = -1
	blocked_store_generation = -1
	if is_instance_valid(store_panel): store_panel.reset()
	state.clear(); items.clear(); textures.clear(); buttons.clear()
	if is_instance_valid(scene_host): scene_host.clear()
	scene_icon_bindings.clear(); scene_icon_sealed=false; scene_icon_failure=""
	structural_key=null
	equipment_controls.clear(); repository_controls.clear()
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
	if not native_icon_gate: show(); move_to_front()
	notice.text = "Waiting for server inventory…"
	request.emit({"kind": "inventory-open"})

func present_received(opened: bool) -> void:
	# Server13/1 is a visibility instruction, not a user input to echo back.
	wanted=opened
	if opened and not native_icon_gate:show();move_to_front()
	else:
		if not opened:
			cancel_item_drag()
			retire_scene_icons()
		examine_mode=false;hide()

func close_inventory() -> void:
	cancel_item_drag()
	examine_mode=false
	blocked_container_serial = int(state.get("container", {}).get("serial", -1))
	blocked_store_generation = int(state.get("store", {}).get("generation", -1))
	if is_instance_valid(store_panel): store_panel.hide()
	wanted = false
	retire_scene_icons()
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
				if not native_icon_gate: show(); move_to_front()
			var drag:=active_item_drag()
			var retain_drag: bool=not drag.is_empty() and int(drag.viewId)==view_id and int(drag.entryId)==int(message.get("dragEntry",-1))
			if not drag.is_empty() and not retain_drag: cancel_item_drag()
			var selected_item: int = int(items[selected].itemId) if items.has(selected) else -1
			view_id = int(message.viewId)
			state = message.duplicate(true)
			items.clear(); textures.clear()
			# Keep the last complete icon image and its model instances while the
			# new view is installed. seal_scene_icon_view removes only departed items.
			scene_icon_bindings.clear(); scene_icon_sealed=false; scene_icon_failure=""
			for item in message.items: items[int(item.entryId)] = item
			if retain_drag:
				var carried: Dictionary=message.get("carriedDragRow",{})
				if not carried.is_empty(): items[int(carried.entryId)]=carried
				drag.viewId=view_id
			selected = -1
			for id in items:
				if int(items[id].itemId) == selected_item: selected = id; break
			render()
			if native_icon_gate and wanted and not scene_icon_backend_selected: show(); move_to_front()
		"inventory-icon":
			if scene_icon_backend_selected: return
			if int(message.viewId) != view_id: return
			var texture: Texture2D = Images.png(str(message.image), 512)
			if texture == null: return
			textures[int(message.entryId)] = texture
			if buttons.has(int(message.entryId)):
				buttons[int(message.entryId)].set_icon(texture)

func render() -> void:
	if state.is_empty(): return
	var layouts: Array=native_equipment.rows(creature_slots) if native_equipment!=null and native_equipment.layout_ready else state.layout
	# Backpack page changes replace repository slots below; equipment and frame
	# controls retain the same structure and need no full-panel rebuild.
	var next_key:=hash([layouts,creature_slots,state.get("container",{}).get("ownerId"),state.get("container",{}).get("page"),state.get("store",{}).get("open",false),native_frame.layout_ready if native_frame!=null else false])
	var rebuild: bool=structural_key!=next_key
	structural_key=next_key
	if rebuild:
		wipe(equipment); wipe(repository); wipe(container_repository); buttons.clear(); equipment_controls.clear(); repository_controls.clear()
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
	for layout in layouts:
		if int(layout.slot) >= 16384 and not creature_slots: continue
		var item := {}
		for value in items.values():
			if value.channel == "I" and int(value.slot) == int(layout.slot): item = value; break
		var button=equipment_controls.get(int(layout.slot))
		var changed: bool=button==null or int(button.row.get("entryId",-1))!=int(item.get("entryId",-1))
		if button==null:
			button=Slot.new(); button.setup(self,item,int(layout.slot)); equipment_controls[int(layout.slot)]=button
			button.position=Vector2(layout.x,layout.y); button.size=Vector2(layout.w,layout.h); equipment.add_child(button)
		else:
			var old_id:=int(button.row.get("entryId",-1))
			if buttons.get(old_id)==button: buttons.erase(old_id)
			if changed:
				if native_equipment!=null: native_equipment.art.unbind(button.image)
				button.image.texture=null
			button.refresh_row(item,view_id)
		if item.is_empty(): button.tooltip_text = layout.label
		if native_equipment!=null and (rebuild or changed): native_equipment.bind_slot(button,layout)
		if item.has("entryId"): register_button(item, button)
	if ac.get_parent() == null: equipment.add_child(ac)
	ac.move_to_front()
	ac.text = "AC: " + (str(int(state.armorClass)) if state.armorClass != null else "—")
	var visible_rows: Dictionary={}
	for item in state.items:
		if item.channel not in ["R","C"]: continue
		var page: int=int(container.get("page",0)) if item.channel=="C" else int(state.page)
		var page_rows:=5 if item.channel=="C" else 6
		if floori(float(item.y)/page_rows)!=page or item.channel=="C" and not opened: continue
		visible_rows[int(item.entryId)]=item
	for id in repository_controls.keys():
		var item: Dictionary=visible_rows.get(id,{})
		var target=container_repository if item.get("channel","")=="C" else repository
		var button: Control=repository_controls[id]
		if not item.is_empty() and button.get_parent()==target and button.position.is_equal_approx(target.item_position(item)) and button.size.is_equal_approx(target.item_size(item)): continue
		if buttons.get(id)==button: buttons.erase(id)
		repository_controls.erase(id); button.get_parent().remove_child(button); button.queue_free()
	for item in visible_rows.values():
		var target = container_repository if item.channel == "C" else repository
		var button=repository_controls.get(int(item.entryId))
		if button==null:
			button=Slot.new(); button.setup(self,item); repository_controls[int(item.entryId)]=button
			button.position=target.item_position(item); button.size=target.item_size(item); target.add_child(button)
			if native_frame!=null: native_frame.decorate_item(button,target,item)
		else: button.refresh_row(item,view_id)
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
	if not item_commands_enabled:
		for control in item_controls.values():control.disabled=true
		notice.text=""
	_clamp()
	if scene_icon_backend_selected: sync_scene_icon_host()

func register_button(item: Dictionary, button) -> void:
	var id := int(item.entryId)
	buttons[id] = button
	if not item_commands_enabled:button.disabled=true
	if not scene_icon_backend_selected and textures.has(id): button.set_icon(textures[id])
	if scene_icon_bindings.has(id):
		button.image.texture=null; button.caption.hide(); button.count.z_index=1
		position_scene_icon(id)

func install_native_icon(view: int,entry: int,texture: Texture2D) -> bool:
	if scene_icon_backend_selected or view!=view_id or texture==null or not items.has(entry): return false
	textures[entry]=texture
	if buttons.has(entry): buttons[entry].set_icon(texture)
	return true

func configure_scene_icons(source) -> bool:
	scene_icon_backend_selected=true
	if is_instance_valid(scene_host) or not is_instance_valid(source): return false
	scene_icon_source=source
	scene_host=SceneHost.new(); scene_host.name="InventoryItemIconScene"
	add_child(scene_host); scene_host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if not scene_host.configure(source.pool):
		scene_icon_failure=str(scene_host.failure); return false
	resized.connect(sync_scene_icon_host)
	scene_host.presented.connect(func(_revision): try_admit_scene_icons())
	sync_scene_icon_host(); return true

func retire_scene_icons() -> void:
	if is_instance_valid(scene_host): scene_host.clear()
	scene_icon_bindings.clear(); scene_icon_sealed=false; scene_icon_failure=""

func sync_scene_icon_host() -> void:
	if not is_instance_valid(scene_host): return
	var pixels:=Vector2i(maxi(2,roundi(size.x)),maxi(2,roundi(size.y)))
	if scene_host.viewport.size!=pixels:
		scene_host.resize_panel(size)
	for id in scene_icon_bindings: position_scene_icon(int(id))
	try_admit_scene_icons()

func scene_icon_anchor(button) -> Vector2:
	var local: Vector2=button.native_icon_center if button.native_icon_center!=null else button.size*0.5
	return scene_host.get_global_transform().affine_inverse()*(button.get_global_transform()*local)

func position_scene_icon(entry: int) -> bool:
	if not is_instance_valid(scene_host) or not buttons.has(entry) or not scene_icon_bindings.has(entry): return false
	var row: Dictionary=scene_icon_bindings[entry]
	var button=buttons[entry]
	var anchor:=scene_icon_anchor(button)
	row.anchor=anchor; scene_icon_bindings[entry]=row
	# bind_slot reuses an unchanged model, repositions a moved one, or replaces
	# an item whose visual resource changed without clearing the whole panel.
	return scene_host.bind_slot(str(entry),str(row.key),row.bundle,anchor)

func install_scene_icon(view: int,entry: int,key: String,bundle: Dictionary) -> bool:
	if view!=view_id or not is_instance_valid(scene_host) or not items.has(entry) or key.is_empty() or bundle.is_empty(): return false
	scene_icon_bindings[entry]={"key":key,"bundle":bundle}
	if buttons.has(entry):
		buttons[entry].image.texture=null; buttons[entry].caption.hide()
		buttons[entry].count.z_index=1
		if not position_scene_icon(entry):
			scene_icon_failure=str(scene_host.failure); return false
	return true

func seal_scene_icon_view(expected: int) -> void:
	if scene_icon_bindings.size()!=expected:
		scene_icon_failure="Original item icon scene is incomplete (%d/%d)"%[scene_icon_bindings.size(),expected]
	if is_instance_valid(scene_host):
		for binding_id in scene_host.slots.keys():
			if not scene_icon_bindings.has(int(binding_id)): scene_host.unbind_slot(str(binding_id))
		if not scene_icon_failure.is_empty(): scene_host.presentation.visible=false
	scene_icon_sealed=true; try_admit_scene_icons()

func try_admit_scene_icons() -> void:
	if not scene_icon_sealed or not is_instance_valid(scene_host) or not wanted or view_id<0 or not scene_icon_failure.is_empty(): return
	for id in scene_icon_bindings:
		if not scene_host.binding_ready(str(id)): return
	if not scene_host.presentation_ready(): return
	# The frame art is a later sibling of the host. Put the transparent icon
	# image above it so its dark overlay cannot tint the models or cover hover.
	scene_host.move_to_front()
	show(); move_to_front()

func select_item(id: int) -> void:
	if examine_mode and items.has(id):
		examine_mode=false; item_controls.examine.set_pressed_no_signal(false); operation(id,"examine"); return
	selected = id
	if items.has(id): notice.text = str(items[id].name)
	if is_instance_valid(store_panel) and state.get("store", {}).get("open", false): store_panel.select_item(id)

func operation(id: int, action: String, fields: Dictionary = {}) -> void:
	if not item_commands_enabled:return
	if not wanted or view_id < 0 or not items.has(id): return
	if state.get("store", {}).get("open", false) and action != "examine": select_item(id); return
	var message := {"kind": "inventory-activate" if action == "activate" else "inventory-action", "viewId": view_id, "entryId": id, "operation": action}
	message.merge(fields)
	request.emit(message)

func item_menu(id: int, point: Vector2) -> void:
	if not item_commands_enabled:return
	select_item(id)
	menu_requested.emit(id, point)

func can_drop(data: Variant, slot: int) -> bool:
	if not wanted or not item_commands_enabled:return false
	if not data is Dictionary or data.get("kind") != "native-inventory-item" or int(data.get("viewId", -1)) != view_id or not items.has(int(data.get("entryId", -1))): return false
	if int(data.get("dragOwner",get_instance_id()))!=get_instance_id(): return false
	var item: Dictionary = items[int(data.entryId)]
	if state.get("store", {}).get("open", false) and slot != 0: return false
	return not item.pending and (slot == 0 or (int(item.slotMask) & slot) != 0)

func can_shortcut(data: Dictionary) -> bool:
	if not can_drop(data,0): return false
	var item: Dictionary = items[int(data.entryId)]
	return item.get("channel", "") in ["R", "I"]

func drop_slot(data: Dictionary, slot: int) -> void:
	if can_drop(data,slot): operation(int(data.entryId), "equip", {"slot": slot})

func active_item_drag() -> Dictionary:
	if not is_inside_tree() or not get_viewport().gui_is_dragging(): return {}
	var data: Variant=get_viewport().gui_get_drag_data()
	if data is Dictionary and data.get("kind")=="native-inventory-item" and int(data.get("dragOwner",-1))==get_instance_id(): return data
	return {}

func can_click_pickup() -> bool:
	return click_pickup and item_commands_enabled and not examine_mode and not state.get("store",{}).get("open",false)

func _input(event: InputEvent) -> void:
	super._input(event)
	if not click_pickup and not click_tab_pressed: return
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		if not event.pressed:
			if click_tab_pressed:
				click_tab_pressed=false
				get_viewport().set_input_as_handled()
			return
		click_tab_pressed=false
		var drag:=active_item_drag()
		if not drag.get("clickPickup",false): return
		var viewport:=get_viewport()
		# Consume the press so a destination button cannot also activate.
		# Godot still routes mouse-up through its normal drop handling.
		viewport.set_input_as_handled()
		var hovered:=viewport.gui_get_hovered_control()
		var tab:=pages.find(hovered)
		if tab>=0:
			click_tab_pressed=true
			if tab!=int(state.get("page",-1)) and can_drop(drag,0): _request_page(tab)
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_ESCAPE and active_item_drag().get("clickPickup",false):
		cancel_item_drag()
		get_viewport().set_input_as_handled()

func _request_page(page: int) -> void:
	request.emit({"kind":"inventory-page","viewId":view_id,"page":page})

func cancel_item_drag() -> void:
	if is_instance_valid(drag_tab_timer): drag_tab_timer.stop()
	if not active_item_drag().is_empty(): get_viewport().gui_cancel_drag()

func _hover_drag_tab(page: int) -> void:
	var drag:=active_item_drag()
	if drag.get("clickPickup",false) or not can_drop(drag,0) or int(state.get("page",-1))==page or state.get("store",{}).get("open",false): return
	drag_tab=page
	drag_tab_timer.start()

func _switch_drag_tab() -> void:
	var drag:=active_item_drag()
	if drag_tab>=0 and not drag.get("clickPickup",false) and pages[drag_tab].is_hovered() and can_drop(drag,0) and int(state.get("page",-1))!=drag_tab:
		_request_page(drag_tab)

func _exit_tree() -> void:
	if is_instance_valid(store_panel): store_panel.queue_free()

func blocks_pointer(point: Vector2) -> bool:
	return (visible and get_global_rect().has_point(point)) or (is_instance_valid(store_panel) and store_panel.blocks_pointer(point))
