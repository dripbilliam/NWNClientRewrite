extends "res://systems/inventory_probe.gd"

static var retired_handles: Array = []
var observations: Dictionary = {}
var restored_input := false
const SLOTS = [0,12,28,29,33,34,35]

func trigger_slot(index: int) -> void:
	if not restored_input:
		client.quickbar.activate(index)
		return
	observations.keyboardSlots.append(index)
	for pressed in [true,false]:
		var event := InputEventKey.new()
		event.keycode = KEY_F1 + index % 12
		event.pressed = pressed
		event.ctrl_pressed = index >= 24
		event.shift_pressed = index >= 12 and index < 24
		client.get_viewport().push_input(event,true)
		await client.get_tree().process_frame

func move_binding(source: int, destination: int) -> bool:
	var bar = client.quickbar
	bar.render(source / 12); await client.get_tree().process_frame
	var payload: Dictionary = bar.buttons[source].payload.duplicate(true)
	var label: String = bar.rows[source].label
	bar.render(destination / 12); await client.get_tree().process_frame
	if not bar.buttons[destination]._can_drop_data(Vector2.ZERO,payload): return false
	bar.buttons[destination]._drop_data(Vector2.ZERO,payload)
	return await wait_until(func(): return bar.rows[source].empty and bar.rows[destination].label == label,10)

func run(owner, message: Dictionary) -> void:
	client = owner
	scope = {"connection":client.connection,"areaId":client.area_id,"generation":client.generation,"transferId":client.world_scope.ticket}
	var restored: bool = message.get("restored",false)
	restored_input = restored
	observations.keyboardSlots = []
	var panel = client.inventory
	var bar = client.quickbar
	panel.open()
	if not await wait_until(func(): return panel.view_id >= 0 and not panel.items.is_empty() and bar.rows.size() == 36,15):
		check(false,"Actual inventory and shortcut records are available"); complete(message); return
	check(true,"Actual inventory and shortcut records are available")
	var gear: Array = panel.items.values().filter(func(row): return row.channel == "I" and int(row.slot) == 2)
	var potions: Array = panel.items.values().filter(func(row): return row.channel == "R" and int(row.stack) > 1 and int(row.slotMask) == 0)
	if gear.is_empty() or potions.is_empty(): check(false,"Isolated character owns its robe and potion stack"); complete(message); return
	var armor: Dictionary = gear[0]
	var potion: Dictionary = potions[0]
	var armor_id := int(armor.itemId)
	var potion_id := int(potion.itemId)
	observations.itemIds = [armor_id,potion_id]
	if not restored:
		bar.render(2); await client.get_tree().process_frame
		bar.buttons[35]._drop_data(Vector2.ZERO,{"kind":"native-inventory-item","viewId":panel.view_id,"entryId":armor.entryId})
		check(await wait_until(func(): return not bar.rows[35].empty and bar.rows[35].label == armor.name,10),"Owned robe is assigned through its native inventory drag")
		panel.item_menu(int(potion.entryId),Vector2(650,350))
		var wheel = client.radial
		var power_ready := await wait_until(func(): return wheel.active and not wheel.pending and wheel.entries.any(func(row): return row.get("canDrag",false)),10)
		check(power_ready,"Actual potion wheel exposes a draggable power")
		if not power_ready: complete(message); return
		var leaf: Dictionary = wheel.entries.filter(func(row): return row.get("canDrag",false) and not row.get("submenu",false))[0]
		bar.render(2); await client.get_tree().process_frame
		bar.buttons[34]._drop_data(Vector2.ZERO,wheel.buttons[int(leaf.slot)].payload.duplicate(true))
		check(await wait_until(func(): return not wheel.active and bar.rows[34].label == potion.name,10),"Potion property is assigned through the original native wheel")
		check(await assign_choice(33,1,"Light"),"Prepared Light is assigned from the native spell menu")
		check(await assign_choice(32,0,"Follow"),"Original Follow command is assigned")
		check(await move_binding(32,0),"Native drag moves a command from page three to page one and clears its source")
		check(await assign_choice(31,4,"Heal"),"Original Heal skill is assigned")
		check(await move_binding(31,12),"Native drag moves a skill from page three to page two and clears its source")
		check(await assign_choice(29,4,"Parry"),"Original Parry mode is assigned")
		check(await assign_choice(28,4,"Craft Trap"),"Original Craft Trap skill is assigned")
	else:
		check(not retired_handles.is_empty() and retired_handles.all(func(value): return value.get_ref() == null),"Old connection shortcut buttons and textures have been freed")
		var expected: Array = message.expected
		check(SLOTS.all(func(index): return not bar.rows[index].empty and bar.rows[index].label == expected[index].label),"All seven saved item/spell/skill/command bindings return on their original three pages")
		check(bar.rows[31].empty and bar.rows[32].empty,"Cross-page drag source slots remain cleared after saved-character reconnect")
		check(str(bar.rows[34].uses) == str(expected[34].uses) and int(str(bar.rows[33].uses)) == int(message.serverLightUses),"Saved potion count and current server-authoritative spell readiness reach restored shortcuts")
	check(await wait_until(func(): return SLOTS.all(func(index): return bar.textures.has(index)),15),"All seven original shortcut icons arrive")
	# Original ConfigureItemQuickbar deliberately uses only the item icon for
	# potion base49, unlike spell-powered items that receive two icons.
	check(bar.rows[34].secondaryIcon == null and not bar.secondary_textures.has(34),"Original potion icon exception is preserved without adding a second spell icon")
	observations.before = {"potion":int(potion.stack),"light":int(str(bar.rows[33].uses))}
	await trigger_slot(35)
	check(await wait_until(func(): var row := item(armor_id,"R"); return not row.is_empty() and not row.pending,15),"Persisted equipment binding unequips the actual current-session item")
	await trigger_slot(35)
	check(await wait_until(func(): var row := item(armor_id,"I"); return not row.is_empty() and int(row.slot) == 2 and not row.pending,15),"The same binding re-equips that actual item after server acknowledgement")
	await trigger_slot(34); await client.get_tree().create_timer(0.3).timeout
	if client.targeting.active: client.targeting.choose({"id":client.controlled_id,"position":client.pivots[client.controlled_id].global_position})
	check(await wait_until(func(): var row := item(potion_id,"R"); return not row.is_empty() and int(row.stack) == int(observations.before.potion)-1 and int(str(bar.rows[34].uses)) == int(row.stack),15),"Persisted item-power binding consumes exactly one real server potion")
	await trigger_slot(33); await client.get_tree().create_timer(0.3).timeout
	if client.targeting.active: client.targeting.choose({"id":client.controlled_id,"position":client.pivots[client.controlled_id].global_position})
	check(await wait_until(func(): return int(str(bar.rows[33].uses)) == int(observations.before.light)-1,15),"Persisted spell binding consumes exactly one actual prepared Light use")
	check(await wait_until(func(): return int(client.motion.objects[client.controlled_id].animation) in [0,1],15),"Server casting action finishes before the next shortcut action")
	await trigger_slot(28)
	check(await wait_until(func(): return client.dialog_panel.visible and client.dialog_panel.entry_id >= 0 and not client.dialog_panel.pending,12),"Persisted crafting binding opens the real server conversation")
	if client.dialog_panel.visible:
		client.dialog_panel.end_button.pressed.emit()
		check(await wait_until(func(): return not client.dialog_panel.visible,10),"Server conversation closes normally before save")
	observations.after = {"potion":int(str(bar.rows[34].uses)),"light":int(str(bar.rows[33].uses))}
	bar.render(2); await client.get_tree().process_frame; await RenderingServer.frame_post_draw
	check(client.get_viewport().get_texture().get_image().save_png(str(message.screenshot)) == OK,"Native retained shortcut frame is saved for review")
	if not restored:
		retired_handles.clear()
		for value in bar.buttons.values(): retired_handles.append(weakref(value))
		for value in bar.textures.values(): retired_handles.append(weakref(value))
		for value in bar.secondary_textures.values(): retired_handles.append(weakref(value))
	complete(message)

func complete(message: Dictionary) -> void:
	if not valid(): return
	client.command({"kind":"shortcut-reconnect-tested","result":{"completed":true,"restored":message.get("restored",false),"checks":checks,"observations":observations,"rows":client.quickbar.rows.duplicate(true),"screenshot":message.screenshot}})
