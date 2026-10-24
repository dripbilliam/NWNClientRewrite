extends "res://systems/inventory_probe.gd"

var purchased_id := -1
var armor_panel := -1
var transaction_gold: Array = []
var identified_id := -1
var observations: Array = []

func stock() -> Array: return client.inventory.items.values().filter(func(row): return row.channel == "M")
func state() -> Dictionary: return client.inventory.state.get("store", {})
func player_gold() -> int: return int(client.inventory.state.get("summary", {}).get("gold", -1))

func settle() -> bool:
	var tracker := {"revision": client.inventory.view_id, "since": Time.get_ticks_msec()}
	return await wait_until(func():
		if client.inventory.view_id != tracker.revision:
			tracker.revision = client.inventory.view_id; tracker.since = Time.get_ticks_msec()
		return Time.get_ticks_msec() - int(tracker.since) >= 350, 5)

func run(owner, message: Dictionary) -> void:
	client = owner
	scope = {"connection": client.connection, "areaId": client.area_id, "generation": client.generation, "transferId": client.world_scope.ticket}
	client.command({"kind": "chat", "channel": 1, "text": "-native-store-setup"})
	check(await wait_until(func(): return client.chat_ui.system_messages.get_parsed_text().contains("GODOT_STORE_READY"), 10), "Actual server creates merchant, stock and identification item from installed template references")
	client.command({"kind": "chat", "channel": 1, "text": "-native-store"})
	check(await wait_until(func(): return state().get("open", false) and client.inventory.visible and is_instance_valid(client.inventory.store_panel) and client.inventory.store_panel.visible, 15), "Actual OpenStore status automatically opens native merchant and player windows")
	if not state().get("open", false): finish(message); return
	var panel = client.inventory
	var store = panel.store_panel
	check(int(state().identifyPrice) == 100 and int(state().gold) == 100000, "Merchant fee and finite gold come from actual server status")
	for category in 5:
		if int(state().get("panel", -1)) != category: store.command("panel", {"panel": category})
		await wait_until(func(): return int(state().get("panel", -1)) == category and not state().get("navigationPending", false) and not stock().is_empty(), 2)
		if int(state().get("pageCount", 1)) > 1 and stock().size() >= 10: armor_panel = category; break
	check(armor_panel >= 0, "Actual server stocks multiple merchant pages of original clothing")
	if armor_panel < 0: finish(message); return
	store.next.pressed.emit()
	check(await wait_until(func(): return int(state().page) == 1 and not state().get("navigationPending", false) and not stock().is_empty(), 10), "Native Next requests and renders the real second merchant page")
	store.previous.pressed.emit()
	check(await wait_until(func(): return int(state().page) == 0 and not state().get("navigationPending", false) and not stock().is_empty(), 10), "Native Previous restores actual first-page stock")
	if not valid(): return
	var old_view: int = panel.view_id
	panel.pages[5].pressed.emit()
	check(await wait_until(func(): return panel.view_id != old_view and int(panel.state.page) == 5 and int(state().page) == 0, 10), "Player page six does not alter the merchant page")
	# Auto-placement buys into the first available player page, not the
	# currently inspected sixth page. Request that authoritative page first.
	old_view = panel.view_id
	panel.pages[0].pressed.emit()
	check(await wait_until(func(): return panel.view_id != old_view and int(panel.state.page) == 0, 10), "Player first page is replicated before observing automatic purchase placement")
	check(await settle(), "Initial inventory replication settles before merchant confirmation")
	var source: Dictionary = stock()[0]
	var stock_id := int(source.itemId)
	var carried_before: Array = panel.items.values().filter(func(row): return row.channel in ["I", "R"]).map(func(row): return int(row.itemId))
	var before := player_gold()
	transaction_gold.append(before)
	observations.append({"operation": "buy", "item": source.duplicate(true), "playerGold": before})
	panel.select_item(int(source.entryId))
	check(store.confirm.text == "Buy" and store.prompt.text.contains(str(int(source.price))), "Clicking real stock offers its native priced confirmation")
	store.confirm.pressed.emit()
	check(await wait_until(func(): var row := item(stock_id, "R"); return player_gold() < before and not row.is_empty() and not row.pending, 15), "Actual purchase changes player gold and canonical item ownership only after server updates")
	var acquired: Array = panel.items.values().filter(func(row): return row.channel == "R" and int(row.itemId) == stock_id and int(row.itemId) not in carried_before)
	if acquired.is_empty(): finish(message); return
	purchased_id = int(acquired[0].itemId)
	transaction_gold.append(player_gold())
	var bought := item(purchased_id, "R")
	panel.operation(int(bought.entryId), "examine")
	check(await wait_until(func(): return int(client.examine_panel.state.get("targetId", -1)) == purchased_id, 10), "Store selection Examine obtains the actual server item description")
	client.examine_panel.hide()
	bought = item(purchased_id, "R")
	panel.select_item(int(bought.entryId))
	before = player_gold()
	check(store.confirm.text == "Sell", "Purchased item exposes a separate Sell confirmation")
	store.confirm.pressed.emit()
	check(await wait_until(func(): return player_gold() > before and item(purchased_id, "R").is_empty(), 15), "Actual sale removes carried ownership and increases canonical player gold")
	transaction_gold.append(player_gold())
	# The authored server also gave an unidentified potion. Observe the real
	# identified property through canIdentify, not merely a transaction reply.
	var unidentified: Array = panel.items.values().filter(func(row): return row.channel == "R" and row.get("canIdentify", false))
	check(not unidentified.is_empty(), "A real carried unidentified item is available for server identification")
	if not unidentified.is_empty():
		var identify_id := int(unidentified[0].itemId)
		identified_id = identify_id
		before = player_gold()
		panel.select_item(int(unidentified[0].entryId))
		store.identify.pressed.emit()
		check(await wait_until(func(): var row := item(identify_id, "R"); return not row.is_empty() and not row.get("canIdentify", true) and player_gold() <= before - 100, 15), "Actual Identify reply, property update and gold charge agree")
		transaction_gold.append(player_gold())
		client.examine_panel.hide()
	var old_generation := int(state().generation)
	var stale_drag := {"kind": "native-inventory-item", "viewId": panel.view_id, "entryId": int(stock()[0].entryId) if not stock().is_empty() else -1}
	store.command("close")
	check(await wait_until(func(): return not state().get("open", false) and not store.visible and panel.equipment.visible, 10), "Closing the store restores native equipment and retires merchant controls")
	check(not panel.can_drop(stale_drag, 0), "Old merchant drag cannot act after close")
	client.command({"kind": "chat", "channel": 1, "text": "-native-store"})
	check(await wait_until(func(): return state().get("open", false) and int(state().generation) > old_generation and store.visible, 10), "Reopening the same actual merchant creates a new native trading context")
	check(not panel.can_drop(stale_drag, 0), "Reused store IDs never revive stale merchant selections")
	var other := (armor_panel + 1) % 5
	store.command("panel", {"panel": other})
	check(await wait_until(func(): return int(state().get("panel", -1)) == other and not state().get("navigationPending", false), 10), "A distinct merchant category receives its actual server page acknowledgement")
	store.command("panel", {"panel": armor_panel})
	check(await wait_until(func(): return not stock().is_empty() and stock().all(func(row): return panel.buttons.has(int(row.entryId)) and panel.buttons[int(row.entryId)].image.texture != null), 12), "All visible real clothing stock uses the original layered item icons")
	# Menus remain nonmodal while trading, including the native spellbook.
	client.spellbook.open()
	check(await wait_until(func(): return client.spellbook.visible and not client.spellbook.state.is_empty(), 10), "Merchant and inventory coexist with the native spellbook")
	var keyboard = client.keyboard
	var focus: bool = keyboard.require_focus; keyboard.require_focus = false
	var position: Vector3 = client.pivots[client.controlled_id].global_position
	keyboard.keys[KEY_W] = true
	await client.get_tree().create_timer(0.6).timeout
	keyboard.keys.erase(KEY_W); keyboard.clear(true); keyboard.require_focus = focus
	check(client.pivots[client.controlled_id].global_position.distance_to(position) > 0.05, "WASD remains active through simultaneous merchant, inventory and spellbook windows")
	client.spellbook.hide()
	panel.position = Vector2(25, 85); store.position = Vector2(520, 85)
	if not stock().is_empty(): panel.select_item(int(stock()[0].entryId))
	await client.get_tree().process_frame
	await RenderingServer.frame_post_draw
	check(client.get_viewport().get_texture().get_image().save_png(str(message.screenshot)) == OK, "Actual native merchant confirmation/backpack/original-icon frame captured")
	finish(message, stock_id)

func finish(message: Dictionary, source_id: int = -1) -> void:
	if valid(): client.command({"kind": "store-tested", "result": {"completed": true, "checks": checks, "sourceStockId": source_id, "purchasedId": purchased_id, "identifiedId": identified_id, "gold": transaction_gold, "observations": observations, "armorPanel": armor_panel, "screenshot": message.screenshot}})
