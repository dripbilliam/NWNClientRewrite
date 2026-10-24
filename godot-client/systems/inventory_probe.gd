extends RefCounted

var running := true
var client
var scope: Dictionary
var checks: Array = []
var cast_recovery: Dictionary = {}
var shortcut_screenshot := ""
var shortcut_captured := false
var skill_result: Dictionary = {}

func stop() -> void: running = false
func valid() -> bool: return running and is_instance_valid(client) and client.world_scope.admitted and client.world_scope.matches(scope)
func check(value: bool, label: String) -> void: checks.append({"name": label, "passed": value})
func wait_until(predicate: Callable, seconds: float) -> bool:
	var until := Time.get_ticks_msec() + int(seconds * 1000)
	while valid() and Time.get_ticks_msec() < until:
		if predicate.call(): return true
		await client.get_tree().process_frame
	return false
func item(id: int, channel: String) -> Dictionary:
	for row in client.inventory.items.values():
		if int(row.itemId) == id and row.channel == channel: return row
	return {}

func assign_choice(index: int, category: int, label: String) -> bool:
	var bar = client.quickbar
	bar.render(2)
	await client.get_tree().process_frame
	bar.buttons[index].context_requested.emit(bar.buttons[index].get_global_rect().get_center())
	var wheel = client.radial
	if not await wait_until(func(): return wheel.active and not wheel.pending and wheel.menu_id >= 0,10): return false
	if not shortcut_captured and not shortcut_screenshot.is_empty():
		await client.get_tree().process_frame
		await RenderingServer.frame_post_draw
		shortcut_captured = client.get_viewport().get_texture().get_image().save_png(shortcut_screenshot) == OK
		check(shortcut_captured, "Actual native shortcut category wheel frame captured for review")
	if category < 0:
		wheel.choose(6)
		return await wait_until(func(): return not wheel.active and bar.rows[index].empty,10)
	var previous: int = wheel.menu_id
	wheel.choose(category)
	if not await wait_until(func(): return wheel.active and not wheel.pending and wheel.menu_id != previous,10): return false
	for page in 32:
		var matches: Array = wheel.entries.filter(func(row): return row.label == label and not row.get("submenu",false))
		if not matches.is_empty():
			wheel.choose(int(matches[0].slot))
			return await wait_until(func(): return not wheel.active and not bar.rows[index].empty and bar.rows[index].label == label,10)
		var more: Array = wheel.entries.filter(func(row): return row.label == "More…" and row.get("submenu",false))
		if more.is_empty(): return false
		previous = wheel.menu_id; wheel.choose(int(more[0].slot))
		if not await wait_until(func(): return wheel.active and not wheel.pending and wheel.menu_id != previous,10): return false
	return false

func run(owner, message: Dictionary) -> void:
	client = owner
	shortcut_screenshot = str(message.screenshot).get_basename() + "-shortcut-menu.png"
	scope = {"connection": client.connection, "areaId": client.area_id, "generation": client.generation, "transferId": client.world_scope.ticket}
	var panel = client.inventory
	panel.open()
	check(await wait_until(func(): return panel.view_id >= 0 and not panel.items.is_empty(), 15), "Native inventory receives actual replicated equipment/backpack rows")
	if not valid(): return
	var equipment: Array = panel.items.values().filter(func(row): return row.channel == "I" and int(row.slot) < 16384)
	check(not equipment.is_empty(), "Actual selected character has server-owned equipped items")
	if equipment.is_empty(): finish(message, 0); return
	var selected: Dictionary = equipment.filter(func(row): return int(row.slot) == 2)[0] if equipment.any(func(row): return int(row.slot) == 2) else equipment[0]
	var id := int(selected.itemId)
	var slot := int(selected.slot)
	panel.item_menu(int(selected.entryId), Vector2(300, 300))
	check(await wait_until(func(): return client.radial.active and client.radial.menu_id >= 0 and not client.radial.pending, 10), "Right-click inventory item uses the original native radial provider")
	if client.radial.active and not client.radial.pending:
		var entries: Array = client.radial.entries.filter(func(row): return row.get("action") == "object.examine")
		if not entries.is_empty():
			client.radial.choose(int(entries[0].slot))
			check(await wait_until(func(): return int(client.examine_panel.state.get("targetId", -1)) == id, 10), "Inventory radial Examine receives the actual server item description")
		else: check(false, "Item radial exposes an examination action"); client.radial.back()
	client.examine_panel.hide()
	var old_view: int = panel.view_id
	panel.pages[5].pressed.emit()
	check(await wait_until(func(): return panel.view_id != old_view and int(panel.state.get("page", -1)) == 5, 10), "Native page button requests the real sixth server repository page")
	if not valid(): return
	selected = item(id, "I")
	if selected.is_empty(): check(false, "Equipment remains replicated after page selection"); finish(message, 0); return
	panel.operation(int(selected.entryId), "unequip", {"destination": "backpack", "x": 0, "y": 30})
	check(await wait_until(func(): var row := item(id, "R"); return not row.is_empty() and int(row.x) == 0 and int(row.y) == 30 and not row.pending, 15), "Actual server acknowledgement and world state confirm unequip into the sixth page")
	if not valid(): return
	var unequipped := item(id, "R")
	if not unequipped.is_empty():
		var drag := {"kind": "native-inventory-item", "viewId": panel.view_id, "entryId": int(unequipped.entryId)}
		check(panel.can_drop(drag, slot), "Real item exposes a compatible native equipment drag target")
		panel.drop_slot(drag, slot)
		check(await wait_until(func(): var row := item(id, "I"); return not row.is_empty() and int(row.slot) == slot and not row.pending, 15), "Native drop callback re-equips the same real item after authoritative server acknowledgement")
	else: check(false, "Unequipped item is visible for drag-back")
	old_view = panel.view_id
	panel.pages[0].pressed.emit()
	check(await wait_until(func(): return panel.view_id != old_view and int(panel.state.get("page", -1)) == 0, 10), "Original repository page can be reopened after equipment changes")
	check(await wait_until(func(): return not panel.textures.is_empty(), 10), "Original item icon pipeline delivers actual native inventory textures")
	if not valid(): return
	var bar = client.quickbar
	check(await wait_until(func(): return bar.quickbar_id >= 0 and bar.rows.size() == 36, 10), "Native shortcut pages receive the current server character's bindings")
	selected = item(id, "I")
	if not selected.is_empty() and bar.quickbar_id >= 0:
		bar.render(2)
		var drag := {"kind": "native-inventory-item", "viewId": panel.view_id, "entryId": int(selected.entryId)}
		check(bar.buttons[35]._can_drop_data(Vector2.ZERO, drag), "Owned equipped armor can be dropped into the third shortcut page")
		bar.buttons[35]._drop_data(Vector2.ZERO, drag)
		check(await wait_until(func(): return not bar.rows[35].empty and bar.rows[35].label == selected.name and bar.textures.has(35), 10), "Assigned item shortcut receives its original item name and decoded icon")
		bar.activate(35)
		check(await wait_until(func(): var row := item(id, "R"); return not row.is_empty() and not row.pending, 15), "Activating the assigned shortcut unequips the item through the actual server")
		bar.activate(35)
		check(await wait_until(func(): var row := item(id, "I"); return not row.is_empty() and int(row.slot) == slot and not row.pending, 15), "Activating the same shortcut re-equips the item after authoritative acknowledgement")
		bar.selected_index = 35
		bar.clear.pressed.emit()
		check(await wait_until(func(): return bar.rows[35].empty, 10), "Native clear control removes the test item binding")
		bar.page = 0
		bar.render(0)
	else: check(false, "Owned equipment and shortcut owner are available for actual assignment")
	if not valid(): return
	var potions: Array = panel.items.values().filter(func(row): return row.channel == "R" and int(row.stack) > 1 and int(row.slotMask) == 0)
	var power_id := int(potions[0].itemId) if not potions.is_empty() else -1
	var power := item(power_id, "R")
	check(not power.is_empty(), "Actual admitted character owns a consumable item power for the wheel assignment test")
	if not power.is_empty():
		var before_stack := int(power.stack)
		panel.item_menu(int(power.entryId), Vector2(650,350))
		check(await wait_until(func(): return client.radial.active and not client.radial.pending and client.radial.entries.any(func(row): return row.get("canDrag",false)),10), "Original item wheel exposes the real potion's draggable power")
		var leaves: Array = client.radial.entries.filter(func(row): return row.get("canDrag",false) and not row.get("submenu",false))
		if not leaves.is_empty():
			bar.render(2)
			var payload: Dictionary = client.radial.buttons[int(leaves[0].slot)].payload.duplicate(true)
			check(bar.buttons[34]._can_drop_data(Vector2.ZERO,payload), "Native wheel power is a valid shortcut drag source")
			bar.buttons[34]._drop_data(Vector2.ZERO,payload)
			check(await wait_until(func(): return not client.radial.active and not bar.rows[34].empty and bar.rows[34].label == power.name and bar.textures.has(34),10), "Item power assignment closes its wheel and displays the original shortcut icon")
			bar.activate(34)
			await client.get_tree().create_timer(0.3).timeout
			if client.targeting.active: client.targeting.choose({"id":client.controlled_id,"position":client.pivots[client.controlled_id].global_position})
			check(await wait_until(func(): var row := item(power_id,"R"); return not row.is_empty() and int(row.stack) == before_stack-1 and str(bar.rows[34].uses) == str(before_stack-1),15), "Wheel-created shortcut consumes exactly one actual server potion and updates its count")
			bar.selected_index = 34; bar.clear.pressed.emit()
			check(await wait_until(func(): return bar.rows[34].empty,10), "Native clear retires the item-power binding after activation")
		else: check(false,"Actual item power has a usable leaf entry")
		bar.render(0)
	if not valid(): return
	check(await assign_choice(33,1,"Light"), "Native shortcut assignment wheel selects the actual character's Light spell")
	var uses := int(str(bar.rows[33].uses))
	check(uses > 0, "Menu-assigned spell displays its actual ready server uses")
	bar.activate(33)
	await client.get_tree().create_timer(0.3).timeout
	if client.targeting.active: client.targeting.choose({"id":client.controlled_id,"position":client.pivots[client.controlled_id].global_position})
	check(await wait_until(func(): return int(str(bar.rows[33].uses)) == uses-1,15), "Menu-assigned spell casts through the actual server and consumes one prepared use")
	check(await assign_choice(32,0,"Follow"), "Native assignment wheel exposes and assigns the original Follow command")
	bar.activate(32)
	check(await assign_choice(32,-1,""), "Assignment wheel Clear removes the command binding")
	check(await assign_choice(33,-1,""), "Assignment wheel Clear removes the spell binding")
	bar.page = 0; bar.render(0)
	if not valid(): return
	var position: Vector2 = panel.position
	panel.close_inventory()
	await client.get_tree().create_timer(0.3).timeout
	panel.open()
	check(await wait_until(func(): return panel.wanted and panel.visible and panel.view_id >= 0, 10) and panel.position == position, "Closing and reopening retains native inventory placement")
	client.spellbook.open()
	check(await wait_until(func(): return client.spellbook.visible and not client.spellbook.state.is_empty(), 10) and panel.visible, "Native inventory and real spellbook remain open together")
	cast_recovery.before = int(client.motion.objects[client.controlled_id].animation)
	cast_recovery.ready = await wait_until(func(): return int(client.motion.objects[client.controlled_id].animation) in [0,1],12)
	cast_recovery.after = int(client.motion.objects[client.controlled_id].animation)
	check(cast_recovery.ready, "The server finishes the preceding spell action before the menu movement check")
	check(await assign_choice(31,4,"Heal"), "Actual server-disclosed Heal skill can be assigned from the native menu")
	bar.activate(31)
	check(await wait_until(func(): return client.targeting.active and int(client.targeting.mode.get("skillId",-1)) == 4,10), "Skill shortcut activates the shared native target selection mode")
	# This authored target-hover check owns its synthetic hit while the reply is
	# in flight; physical mouse polling must not replace that hit asynchronously.
	var input = client.owner_scene.world_input
	var previous_smoke_lock: bool = input.smoke_locked
	input.smoke_locked = true
	client.targeting.hover({"id":client.controlled_id})
	check(await wait_until(func(): return client.targeting.presentation.get("valid",false) and int(client.targeting.presentation.get("cursor",0)) == 37,10), "A valid skill target receives the original action cursor")
	skill_result.cursor = client.targeting.presentation.duplicate(true)
	var previous_rows: int = client.chat_ui.rows.size()
	client.targeting.choose({"id":client.controlled_id,"position":client.pivots[client.controlled_id].global_position})
	check(await wait_until(func(): return not client.targeting.active,10), "Targeted Heal submits and retires selection without fabricating server feedback")
	input.smoke_locked = previous_smoke_lock
	await client.get_tree().create_timer(0.5).timeout
	skill_result.feedback = client.chat_ui.rows.slice(previous_rows)
	skill_result.heal_requires_item = true
	check(await assign_choice(31,-1,""), "Targeted skill binding can be cleared through its original assignment menu")
	check(await assign_choice(30,4,"Parry"), "Actual disclosed Parry skill can be assigned from the native menu")
	bar.activate(30)
	await client.get_tree().create_timer(0.3).timeout
	check(not client.targeting.active, "Parry uses its original immediate mode path instead of opening a skill targeter")
	bar.activate(30)
	await client.get_tree().create_timer(0.3).timeout
	check(await assign_choice(30,-1,""), "Mode skill binding can be cleared after the second mode submission")
	check(await assign_choice(29,4,"Craft Trap"), "Actual Craft Trap skill can be assigned from the native menu")
	bar.activate(29)
	check(await wait_until(func(): return client.dialog_panel.visible and client.dialog_panel.entry_id >= 0 and not client.dialog_panel.pending,12), "Craft Trap immediately targets self and the real server opens its crafting conversation")
	skill_result.craft_dialog = client.dialog_panel.visible
	if client.dialog_panel.visible:
		client.dialog_panel.end_button.pressed.emit()
		await wait_until(func(): return not client.dialog_panel.visible,10)
	check(await assign_choice(29,-1,""), "Crafting skill binding can be cleared after the server response")
	bar.page = 0; bar.render(0)
	if not valid(): return
	var keyboard = client.keyboard
	var previous_focus: bool = keyboard.require_focus
	keyboard.require_focus = false
	var before: Vector3 = client.pivots[client.controlled_id].global_position
	keyboard.keys[KEY_W] = true
	await client.get_tree().create_timer(0.7).timeout
	keyboard.keys.erase(KEY_W)
	keyboard.clear(true)
	keyboard.require_focus = previous_focus
	check(client.pivots[client.controlled_id].global_position.distance_to(before) > 0.05, "Real WASD movement remains active through simultaneous inventory and spellbook windows")
	if not valid(): return
	panel.position = Vector2(25, 100)
	client.spellbook.position = Vector2(500, 100)
	await client.get_tree().process_frame
	await RenderingServer.frame_post_draw
	var screenshot: Image = client.get_viewport().get_texture().get_image()
	check(screenshot.save_png(str(message.screenshot)) == OK, "Native inventory/equipment/icon/multiple-menu frame captured")
	finish(message, id)

func finish(message: Dictionary, id: int) -> void:
	if not valid(): return
	client.command({"kind": "inventory-tested", "result": {"completed": true, "checks": checks, "itemId": id, "entries": client.inventory.items.size(), "icons": client.inventory.textures.size(), "castRecovery":cast_recovery,"skill":skill_result,"shortcutScreenshot":shortcut_screenshot,"screenshot": message.screenshot}})
