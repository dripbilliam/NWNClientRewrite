extends "res://systems/inventory_probe.gd"
var record: Dictionary = {}
var skill: Dictionary = {}
var feat: Dictionary = {}
var strength: Array = []

func settle(sheet) -> bool:
	var tracker := {"view": sheet.view_id, "since": Time.get_ticks_msec()}
	return await wait_until(func():
		if tracker.view != sheet.view_id: tracker.view = sheet.view_id; tracker.since = Time.get_ticks_msec()
		return Time.get_ticks_msec() - int(tracker.since) >= 300, 5)

func capture_record(sheet) -> Dictionary:
	var model: Dictionary = sheet.state.model
	var saves: Array = []
	for key in ["fortitude", "reflex", "will"]:
		var values: Array = model.details.filter(func(row): return row.get("label", "") == model.labels.get(key))
		saves.append(values[0].get("value") if not values.is_empty() else null)
	return {"viewId": sheet.view_id, "abilities": model.abilities.map(func(a): return a.get("score")), "hp": model.get("currentHP"), "maximumHP": model.get("maximumHP"), "ac": model.get("armorClass"), "xp": model.get("experience"), "saves": saves}

func screenshot(name: String) -> bool:
	await client.get_tree().process_frame; await RenderingServer.frame_post_draw
	return client.get_viewport().get_texture().get_image().save_png(name) == OK

func run(owner, message: Dictionary) -> void:
	client = owner
	scope = {"connection": client.connection, "areaId": client.area_id, "generation": client.generation, "transferId": client.world_scope.ticket}
	var sheet = client.character_sheet
	sheet.open()
	check(await wait_until(func(): return sheet.visible and sheet.view_id >= 0 and sheet.page == 0 and sheet.state.model.get("experience") != null and sheet.state.model.abilities[0].get("score") != null, 15), "Native record receives actual subscribed server abilities, combat values and XP")
	if sheet.view_id < 0 or sheet.state.is_empty(): finish(message); return
	check(await settle(sheet), "Initial character-stat replication settles before inspection")
	check(sheet.state.model.abilities.size() == 6 and not sheet.state.model.details.is_empty(), "Native Character tab displays all six ability cells and detailed server statistics")
	check(await wait_until(func(): return sheet.image_nodes.has("portrait") and sheet.image_nodes.portrait.texture != null, 10), "Original large character portrait reaches the native sheet")
	check(await wait_until(func(): return sheet.image_nodes.keys().filter(func(key): return str(key).begins_with("ability:")).all(func(key): return sheet.image_nodes[key].texture != null), 10), "All original ability glyphs render in the native record")
	var before := int(sheet.state.model.abilities[0].score)
	var adjustment := int(sheet.state.model.abilities[0].adjustment)
	strength.append(before)
	client.command({"kind": "chat", "channel": 1, "text": "-native-sheet-buff"})
	check(await wait_until(func(): return int(sheet.state.model.abilities[0].score) == before + 4 and int(sheet.state.model.abilities[0].adjustment) == adjustment + 4, 10), "Actual server temporary Strength effect updates received score and adjustment live")
	strength.append(sheet.state.model.abilities[0].get("score"))
	check(sheet.find_child("Str_score", true, false).get_theme_color("font_color") == Color.LIME_GREEN, "Native score coloring follows the actual received positive adjustment")
	check(await wait_until(func(): return int(sheet.state.model.abilities[0].score) == before and int(sheet.state.model.abilities[0].adjustment) == adjustment, 12), "Server-owned effect expiry restores the original displayed Strength")
	strength.append(sheet.state.model.abilities[0].get("score"))
	record = capture_record(sheet)
	sheet.position = Vector2(65, 80)
	check(await screenshot(str(message.screenshot)), "Actual native statistics/portrait/original ability-icon frame captured")
	sheet.tabs[1].pressed.emit()
	check(await wait_until(func(): return sheet.page == 1 and not sheet.state.entries.is_empty() and sheet.state.entries.any(func(row): return row.canDrag), 12), "Skills subscription displays real server-visible ranks and usable skill entries")
	if sheet.page != 1 or sheet.state.entries.is_empty(): finish(message); return
	await settle(sheet)
	var row: Dictionary = sheet.state.entries.filter(func(value): return value.canDrag)[0]
	sheet.select_entry(int(row.entryId))
	check(not sheet.description.get_parsed_text().is_empty(), "Native skill selection displays its installed description")
	check(await wait_until(func(): return sheet.entry_nodes.values().all(func(button): return button.image.texture != null), 12), "Actual skill rows render their original icons")
	skill = {"id": int(row.id), "value": row.get("value"), "viewId": sheet.view_id}
	var skill_drag: Dictionary = sheet.entry_nodes[int(row.entryId)].drag_data()
	client.quickbar.render(2)
	check(client.quickbar.buttons[34].accepts.call(skill_drag), "A real native skill entry is accepted by the quickbar drag target")
	client.quickbar.buttons[34].dropped.emit(skill_drag)
	check(await wait_until(func(): return client.quickbar.rows.size() == 36 and str(client.quickbar.rows[34].label) == str(row.name), 10), "Native skill drop uses the actual session shortcut assignment and refreshes its label")
	check(await screenshot(str(message.screenshot).get_basename() + "-skills.png"), "Actual native skills/description/shortcut frame captured")
	sheet.tabs[2].pressed.emit()
	check(await wait_until(func(): return sheet.page == 2 and not sheet.state.entries.is_empty(), 12), "Feats subscription displays actual owned character feats")
	if sheet.page != 2 or sheet.state.entries.is_empty(): finish(message); return
	await settle(sheet)
	row = sheet.state.entries[0]
	feat = {"id": int(row.id), "viewId": sheet.view_id}
	sheet.select_entry(int(row.entryId))
	check(not sheet.description.get_parsed_text().is_empty(), "Native feat selection displays its installed description")
	check(await wait_until(func(): return sheet.entry_nodes.values().all(func(button): return button.image.texture != null), 12), "Actual feat rows render their original icons")
	check(not client.quickbar.buttons[35].accepts.call(skill_drag), "Skill drags from a previous record tab cannot be reused")
	var feat_drag: Dictionary = sheet.entry_nodes[int(row.entryId)].drag_data()
	client.quickbar.buttons[35].dropped.emit(feat_drag)
	check(await wait_until(func(): return str(client.quickbar.rows[35].label) == str(row.name), 10), "Native feat drop assigns the actual owned feat to the quickbar")
	check(await screenshot(str(message.screenshot).get_basename() + "-feats.png"), "Actual native feats/description/shortcut frame captured")
	var position: Vector2 = sheet.position
	sheet.close_sheet()
	check(await wait_until(func(): return sheet.view_id < 0 and not sheet.visible, 10), "Closing sends the signed-page close request and retires native record controls")
	check(not sheet.can_drag(feat_drag), "Closed record cannot authorize a stale shortcut drag")
	sheet.open()
	check(await wait_until(func(): return sheet.visible and sheet.page == 2 and sheet.view_id >= 0, 10) and sheet.position == position, "Reopening preserves the native record position and selected Feats page")
	client.inventory.open(); client.spellbook.open()
	check(await wait_until(func(): return client.inventory.visible and client.inventory.view_id >= 0 and client.spellbook.visible and not client.spellbook.state.is_empty(), 10), "Character record coexists with real inventory and spellbook windows")
	var keyboard = client.keyboard
	var focused: bool = keyboard.require_focus; keyboard.require_focus = false
	var start: Vector3 = client.pivots[client.controlled_id].global_position
	keyboard.keys[KEY_W] = true; await client.get_tree().create_timer(0.6).timeout
	keyboard.keys.erase(KEY_W); keyboard.clear(true); keyboard.require_focus = focused
	check(client.pivots[client.controlled_id].global_position.distance_to(start) > 0.05, "Actual WASD remains available through simultaneous character/inventory/spellbook windows")
	finish(message)

func finish(message: Dictionary, _item_id: int = 0) -> void:
	if valid(): client.command({"kind": "sheet-tested", "result": {"completed": true, "checks": checks, "record": record, "skill": skill, "feat": feat, "strength": strength, "screenshot": message.screenshot}})
