extends SceneTree

const Inventory = preload("res://systems/server_inventory.gd")
var failures: Array = []
var checks := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)

func run() -> void:
	root.size = Vector2i(1440, 1080)
	var output := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output = arg.substr(9)
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://reports/inventory-ui-fixture-v1.json"))
	data.store = {"open": true, "generation": 1, "panel": 0, "page": 0, "pageCount": 3, "labels": ["Weapons", "Armor", "Other", "Potions", "Rings"], "gold": 200, "identifyPrice": 100}
	data.automatic = true
	data.items[0].price = 50; data.items[0].canIdentify = true
	data.items[1].price = 25; data.items[1].canIdentify = false
	data.items.append({"entryId": 3, "itemId": 10, "channel": "M", "x": 2, "y": 24, "width": 2, "height": 3, "slotMask": 2, "stack": 1, "name": "Stock robe", "price": 125, "pending": false, "canIdentify": false})
	var panel := Inventory.new(); panel.setup(""); root.add_child(panel)
	var sent: Array = []; panel.request.connect(func(m): sent.append(m))
	panel.receive(data)
	await process_frame
	var store = panel.store_panel
	check(panel.visible and store.visible and not panel.equipment.visible, "Real status metadata auto-opens two native windows and hides equipment during trade")
	check(not panel.item_controls.drop.visible and not panel.item_controls.activate.visible, "Trading exposes confirmation actions rather than misleading Use/Drop controls")
	check(store.repository.rows == 10 and store.repository.columns == 10 and store.repository.custom_minimum_size == Vector2(400, 400), "Merchant uses the full original ten-by-ten grid")
	check(panel.blocks_pointer(store.repository.global_position + Vector2(10, 10)) and not panel.blocks_pointer(Vector2(1400, 1050)), "Merchant blocks world hover/click only inside its bounds; outside world input remains available")
	check(panel.buttons[3].position == Vector2(80, 160) and panel.buttons[3].size == Vector2(79, 119), "Merchant page-global coordinates preserve original icon dimensions")
	panel.select_item(3)
	check(store.selection.visible and store.confirm.text == "Buy" and store.prompt.text.contains("125 gold") and not store.identify.visible, "Stock selection asks for an explicit priced Buy confirmation")
	var count := sent.size()
	panel.operation(3, "activate")
	check(sent.size() == count, "Double-clicking stock selects without accidental purchase or item activation")
	store.confirm.pressed.emit()
	check(sent.back().kind == "inventory-store" and sent.back().operation == "buy" and sent.back().entryId == 3 and not store.selection.visible, "Buy confirmation sends a scoped transaction and retires selection")
	panel.select_item(0)
	check(store.confirm.text == "Sell" and store.identify.visible and store.identify.text.contains("100 gold"), "Unidentified carried item offers Sell and the actual identification fee")
	store.identify.pressed.emit()
	check(sent.back().operation == "identify" and sent.back().entryId == 0, "Identify sends the carried item's scoped entry")
	var drag := {"kind": "native-inventory-item", "viewId": 1, "entryId": 3}
	count = sent.size()
	panel.repository.drop_global(drag, panel.repository.global_position + Vector2(10, 10))
	check(sent.size() == count and store.selected_item == 10 and not panel.can_drop(drag, 2), "Dropping stock opens confirmation and never equips or predicts ownership")
	store.next.pressed.emit()
	check(sent.back().operation == "page" and sent.back().page == 1, "Merchant paging is separate from player backpack paging")
	store.tabs[4].pressed.emit()
	check(sent.back().operation == "panel" and sent.back().panel == 4, "Every merchant category is selectable")
	panel.select_item(3)
	data.viewId = 2; data.items[3].price = 200
	panel.receive(data)
	check(not store.selection.visible and not panel.can_drop(drag, 0), "Price/view revisions invalidate confirmation and old drags")
	panel.select_item(3)
	data.viewId = 3; data.items[3].pending = true
	panel.receive(data)
	count = sent.size(); store.transact()
	check(store.confirm.disabled and sent.size() == count, "Outstanding transaction blocks duplicate confirmation")
	panel.close_inventory(); panel.receive({"kind": "inventory-closed"}); panel.receive(data)
	check(not panel.visible and not store.visible, "Closing both windows rejects late metadata from the same store generation")
	data.viewId = 4; data.store.generation = 2
	panel.receive(data)
	check(panel.visible and store.visible, "New server store generation can reopen native trading")
	store.position = Vector2(60, 80)
	data.viewId = 5; data.store.open = false
	panel.receive(data)
	check(not store.visible and panel.equipment.visible and store.selected_item == -1, "Server closure restores equipment and retires merchant selection")
	data.viewId = 6; data.store.open = true; data.store.generation = 3
	panel.receive(data)
	check(store.position == Vector2(60, 80), "Reopening preserves the merchant's independent native position")
	panel.reset()
	check(not store.visible and store.repository.get_child_count() == 0, "World reset releases stock controls and hides the merchant window")
	panel.free()
	await process_frame
	var file := FileAccess.open(output, FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed": failures.is_empty(), "checks": checks, "failures": failures, "scope": "Authored native merchant geometry/confirmation/price revisions, paging, position and lifetime; actual transactions checked separately"}, "\t")); file.close()
	quit(0 if failures.is_empty() else 1)
