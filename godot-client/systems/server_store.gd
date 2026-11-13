extends "res://systems/draggable_panel.gd"

const Slot = preload("res://systems/inventory_slot.gd")
const Repository = preload("res://systems/inventory_repository.gd")
var inventory
var repository
var tabs: Array = []
var pager: Label
var previous: Button
var next: Button
var gold: Label
var selection: VBoxContainer
var prompt: RichTextLabel
var confirm: Button
var identify: Button
var examine: Button
var cancel_button: Button
var native_skin
var stock_buttons: Dictionary={}
var structural_key: Variant=null
var selected_item := -1
var selected_price := -1
var selected_generation := -1
var selected_channel := ""

func setup(owner, storage: String) -> void:
	inventory = owner
	configure("Store", "store", Vector2(560, 85), storage)
	custom_minimum_size = Vector2(430, 620)
	close_hides = false
	var categories := HFlowContainer.new()
	content.add_child(categories)
	for index in 5:
		var button := Button.new()
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(func(): command("panel", {"panel": index}))
		categories.add_child(button)
		tabs.append(button)
	var navigation := HBoxContainer.new()
	content.add_child(navigation)
	previous = Button.new(); previous.text = "Previous"; previous.focus_mode = Control.FOCUS_NONE
	previous.pressed.connect(func(): navigate(-1)); navigation.add_child(previous)
	pager = Label.new(); navigation.add_child(pager)
	next = Button.new(); next.text = "Next"; next.focus_mode = Control.FOCUS_NONE
	next.pressed.connect(func(): navigate(1)); navigation.add_child(next)
	gold = Label.new(); content.add_child(gold)
	repository = Repository.new()
	repository.inventory = inventory; repository.channel = "M"; repository.rows = 10
	repository.custom_minimum_size = Vector2(400, 400)
	content.add_child(repository)
	selection = VBoxContainer.new(); content.add_child(selection)
	prompt = preload("res://systems/server_text.gd").label({},400); prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; selection.add_child(prompt)
	var actions := HBoxContainer.new(); selection.add_child(actions)
	confirm = Button.new(); confirm.focus_mode = Control.FOCUS_NONE
	confirm.pressed.connect(func(): transact()); actions.add_child(confirm)
	identify = Button.new(); identify.focus_mode = Control.FOCUS_NONE
	identify.pressed.connect(func(): transact("identify")); actions.add_child(identify)
	examine = Button.new(); examine.text = "Examine"; examine.focus_mode = Control.FOCUS_NONE
	examine.pressed.connect(func():
		if native_skin!=null and native_skin.built():
			inventory.examine_mode=not inventory.examine_mode; examine.set_pressed_no_signal(inventory.examine_mode); return
		var id := entry()
		if id >= 0: inventory.operation(id, "examine"))
	actions.add_child(examine)
	cancel_button = Button.new(); cancel_button.text = "Cancel"; cancel_button.focus_mode = Control.FOCUS_NONE
	cancel_button.pressed.connect(clear_selection); actions.add_child(cancel_button)
	close_requested.connect(func(): command("close"))
	reset()

func reset() -> void:
	clear_selection()
	for id in stock_buttons.keys(): retire_stock(int(id))
	stock_buttons.clear(); structural_key=null
	hide()

func retire_stock(id: int) -> void:
	var button=stock_buttons.get(id)
	if inventory.buttons.get(id)==button: inventory.buttons.erase(id)
	stock_buttons.erase(id)
	if not is_instance_valid(button): return
	if native_skin!=null: native_skin.clear_hover(id)
	if button.get_parent()!=null: button.get_parent().remove_child(button)
	button.queue_free()

func clear_selection() -> void:
	selected_item = -1; selected_price = -1; selected_generation = -1; selected_channel = ""
	if selection != null: selection.hide()

func entry() -> int:
	for id in inventory.items:
		if int(inventory.items[id].itemId) == selected_item: return id
	return -1

func render(store: Dictionary) -> void:
	if not store.get("open", false) or not inventory.wanted: reset(); return
	var first := not visible
	show()
	if first: move_to_front()
	var next_key:=hash([store.generation,store.panel,store.page,native_skin.built() if native_skin!=null else false])
	var rebuild: bool=structural_key!=next_key; structural_key=next_key
	for id in stock_buttons.keys():
		var row: Dictionary=inventory.items.get(id,{})
		if rebuild or row.get("channel","")!="M": retire_stock(int(id)); continue
		var button: Control=stock_buttons[id]
		if not button.position.is_equal_approx(repository.item_position(row)) or not button.size.is_equal_approx(repository.item_size(row)): retire_stock(int(id))
	for index in tabs.size():
		tabs[index].text = str(store.labels[index]) if index < store.get("labels", []).size() else str(index + 1)
		tabs[index].disabled = int(store.panel) == index or store.get("navigationPending", false)
	pager.text = "%s / %s" % [int(store.page) + 1, int(store.pageCount)]
	previous.disabled = int(store.pageCount) <= 1 or store.get("navigationPending", false); next.disabled = previous.disabled
	gold.text = "Store gold: %s" % int(store.gold) if int(store.gold) != -1 else ""
	if store.get("navigationPending", false): gold.text += " · Loading…"
	for row in inventory.items.values():
		if row.channel != "M": continue
		var button
		if stock_buttons.has(int(row.entryId)):
			button=stock_buttons[int(row.entryId)]; button.refresh_row(row,inventory.view_id)
			inventory.register_button(row,button); continue
		button=Slot.new(); button.setup(inventory,row); stock_buttons[int(row.entryId)]=button
		button.position = repository.item_position(row)
		button.size = repository.item_size(row)
		repository.add_child(button)
		if native_skin!=null and native_skin.built():
			native_skin.frame.decorate_item(button,repository,row)
			var id:=int(row.entryId)
			button.mouse_entered.connect(func():
				if native_skin!=null: native_skin.hover_item(id))
			button.mouse_exited.connect(func():
				if native_skin!=null: native_skin.clear_hover(id))
		inventory.register_button(row, button)
	var id := entry()
	if id < 0 or selected_generation != int(store.generation) or selected_price != int(inventory.items[id].get("price", -1)) or selected_channel != str(inventory.items[id].channel):
		clear_selection()
	elif id >= 0: select_item(id, false)
	if native_skin!=null: native_skin.render(store)
	_clamp()

func select_item(id: int, raise_window: bool = true) -> void:
	if not inventory.items.has(id): return
	var row: Dictionary = inventory.items[id]
	if row.channel not in ["M", "R", "I"]: return
	var store: Dictionary = inventory.state.get("store", {})
	if not store.get("open", false): return
	selected_item = int(row.itemId); selected_price = int(row.price); selected_generation = int(store.generation)
	selected_channel = str(row.channel)
	var buy: bool = row.channel == "M"
	prompt.text = "%s — %s for %s gold?" % [str(row.name), "Buy" if buy else "Sell", selected_price]
	confirm.text = "Buy" if buy else "Sell"; confirm.disabled = row.pending
	identify.visible = row.get("canIdentify", false)
	identify.text = "Identify (%s gold)" % int(store.identifyPrice); identify.disabled = row.pending
	selection.show()
	if raise_window: show(); move_to_front()
	if native_skin!=null: native_skin.selection_changed(raise_window)

func command(operation: String, fields: Dictionary = {}) -> void:
	if not inventory.wanted or not inventory.state.get("store", {}).get("open", false): return
	if operation=="panel" and int(fields.get("panel",-1))==int(inventory.state.store.get("panel",-2)): return
	clear_selection()
	var message := {"kind": "inventory-store", "viewId": inventory.view_id, "operation": operation}
	message.merge(fields)
	inventory.request.emit(message)

func navigate(delta: int) -> void:
	var store: Dictionary = inventory.state.get("store", {})
	var count := maxi(1, int(store.get("pageCount", 1)))
	command("page", {"page": posmod(int(store.get("page", 0)) + delta, count)})

func transact(operation: String = "") -> void:
	var id := entry()
	if id < 0: return
	var row: Dictionary = inventory.items[id]
	var store: Dictionary = inventory.state.get("store", {})
	if row.pending or selected_generation != int(store.get("generation", -1)) or selected_price != int(row.get("price", -1)): return
	command(operation if not operation.is_empty() else ("buy" if row.channel == "M" else "sell"), {"entryId": id})
func blocks_pointer(point: Vector2) -> bool:
	return visible and get_global_rect().has_point(point) or native_skin!=null and native_skin.selection_blocks(point)
func _unhandled_key_input(event: InputEvent) -> void:
	if selection.visible and event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_ESCAPE:
		clear_selection(); get_viewport().set_input_as_handled()
func _exit_tree() -> void:
	if is_instance_valid(selection) and not is_ancestor_of(selection): selection.queue_free()
