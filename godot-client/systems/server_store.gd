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
var prompt: Label
var confirm: Button
var identify: Button
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
	prompt = Label.new(); prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; selection.add_child(prompt)
	var actions := HBoxContainer.new(); selection.add_child(actions)
	confirm = Button.new(); confirm.focus_mode = Control.FOCUS_NONE
	confirm.pressed.connect(func(): transact()); actions.add_child(confirm)
	identify = Button.new(); identify.focus_mode = Control.FOCUS_NONE
	identify.pressed.connect(func(): transact("identify")); actions.add_child(identify)
	var examine := Button.new(); examine.text = "Examine"; examine.focus_mode = Control.FOCUS_NONE
	examine.pressed.connect(func():
		var id := entry()
		if id >= 0: inventory.operation(id, "examine"))
	actions.add_child(examine)
	var cancel := Button.new(); cancel.text = "Cancel"; cancel.focus_mode = Control.FOCUS_NONE
	cancel.pressed.connect(clear_selection); actions.add_child(cancel)
	close_requested.connect(func(): command("close"))
	reset()

func reset() -> void:
	clear_selection()
	if repository != null: inventory.wipe(repository)
	hide()

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
	inventory.wipe(repository)
	for index in tabs.size():
		tabs[index].text = str(store.labels[index]) if index < store.get("labels", []).size() else str(index + 1)
		tabs[index].disabled = int(store.panel) == index or store.get("navigationPending", false)
	pager.text = "%s / %s" % [int(store.page) + 1, int(store.pageCount)]
	previous.disabled = int(store.pageCount) <= 1 or store.get("navigationPending", false); next.disabled = previous.disabled
	gold.text = "Store gold: %s" % int(store.gold) if int(store.gold) != -1 else ""
	if store.get("navigationPending", false): gold.text += " · Loading…"
	for row in inventory.items.values():
		if row.channel != "M": continue
		var button := Slot.new()
		button.setup(inventory, row)
		button.position = Vector2(int(row.x) * 40, (int(row.y) % 10) * 40)
		button.size = Vector2(maxi(1, int(row.width)) * 40 - 1, maxi(1, int(row.height)) * 40 - 1)
		repository.add_child(button)
		inventory.register_button(row, button)
	var id := entry()
	if id < 0 or selected_generation != int(store.generation) or selected_price != int(inventory.items[id].get("price", -1)) or selected_channel != str(inventory.items[id].channel):
		clear_selection()
	elif id >= 0: select_item(id, false)
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

func command(operation: String, fields: Dictionary = {}) -> void:
	if not inventory.wanted or not inventory.state.get("store", {}).get("open", false): return
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
