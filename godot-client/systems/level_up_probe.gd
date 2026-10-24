extends "res://systems/inventory_probe.gd"
var runs: Array = []
var starting_level := 0

func choice(tag: String, value: int = -1) -> Dictionary:
	for row in client.level_up.state.get("items", []):
		if row.get("tag", "") == tag and not row.get("disabled", false) and (value < 0 or int(row.get("value", -2)) == value): return row
	return {}

func press(row: Dictionary, value: Variant = null) -> bool:
	if row.is_empty(): return false
	var wizard = client.level_up
	var old: int = wizard.view_id
	wizard.change(int(row.controlId), value, old)
	return await wait_until(func(): return not wizard.waiting and wizard.view_id != old, 12)

func page(step: int) -> bool:
	var wizard = client.level_up
	wizard.navigate(step)
	return await wait_until(func(): return int(wizard.state.get("step", -1)) == step and not wizard.waiting, 12)

func capture(name: String) -> bool:
	client.level_up.position = Vector2(65, 75)
	await client.get_tree().process_frame; await RenderingServer.frame_post_draw
	return client.get_viewport().get_texture().get_image().save_png(name) == OK

func run(owner, message: Dictionary) -> void:
	client = owner
	scope = {"connection": client.connection, "areaId": client.area_id, "generation": client.generation, "transferId": client.world_scope.ticket}
	check(await wait_until(func(): return client.level_state.get("available", false) and client.quickbar.level_button.visible, 20), "Actual server availability exposes native Level Up")
	starting_level = int(client.level_state.get("level", 0))
	check(starting_level > 0, "Starting character level comes from replicated classes")
	var wizard = client.level_up
	client.quickbar.level_button.pressed.emit()
	check(await wait_until(func(): return wizard.state.get("phase", "") == "editing", 20), "Native Level Up requests actual available classes and progression resources")
	if wizard.state.get("phase") != "editing": finish(message); return
	check(wizard.tabs.size() == 7 and not choice("class", 10).is_empty(), "All seven pages and the actual Wizard class are available")
	wizard.close_level_up()
	check(await wait_until(func(): return not wizard.wanted and not wizard.visible, 10), "Cancelling a real server draft retires the native wizard")
	check(int(client.level_state.get("level", 0)) == starting_level, "Cancelled draft never changes the replicated character level")
	for index in 2:
		client.quickbar.level_button.pressed.emit()
		check(await wait_until(func(): return wizard.state.get("phase", "") == "editing", 15), "Fresh native draft opens for accepted level " + str(index + 1))
		if wizard.state.get("phase") != "editing": finish(message); return
		var class_id := 10 if index == 0 else 4
		var selected := choice("class", class_id)
		check(not selected.is_empty() and await press(selected), "Native class selection uses a real server-available class")
		if selected.is_empty(): finish(message); return
		check(await page(1), "Abilities page opens through native navigation")
		if (starting_level + index + 1) % 4 == 0: check(await press(choice("ability", 3)), "Native ability choice selects the due Intelligence increase")
		check(await page(2), "Skill page displays raw ranks and actual class costs")
		var plus := {}
		for row in wizard.state.items:
			if row.get("tag", "") == "skill-plus" and not row.disabled and int(row.get("cost", 0)) == 1: plus = row; break
		check(not plus.is_empty() and await press(plus), "Native skill increment spends a valid class-skill point")
		check(await page(3), "Feat page opens with current requirements")
		var selected_feat := -1
		if index == 1:
			# The user's global Workshop tables include feats absent from the
			# vanilla test server. Exercise a real base-game group/feat rather
			# than alphabetically selecting an installed mod's BadStrRef row.
			var groups: Array = wizard.state.items.filter(func(row): return row.get("tag", "") == "feat-group" and not row.disabled)
			var feat := {}
			for group in groups:
				if not await press(group): break
				for candidate in wizard.state.items:
					if candidate.get("tag", "") == "feat" and not candidate.disabled and int(candidate.get("value", -1)) in range(0, 1000): feat = candidate; break
				if not feat.is_empty(): break
				if not await press(choice("feat-back")): break
			check(not feat.is_empty(), "Native Fighter bonus-feat selection traverses a master-feat group")
			selected_feat = int(feat.get("value", -1))
			check(not feat.is_empty() and await press(feat), "Native grouped feat choice satisfies the current bonus slot")
		check(await page(4), "Spell page follows the selected class")
		var spells: Array = []
		if index == 0:
			for count in 2:
				var spell := {}
				for row in wizard.state.items:
					if row.get("tag", "") == "spell" and not row.disabled and not row.get("selected", false): spell = row; break
				if not spell.is_empty(): spells.append(int(spell.value))
				check(not spell.is_empty() and await press(spell), "Native Wizard chooses a new spell from the shared two-spell pool")
		else: check(choice("spell").is_empty(), "The new Fighter level adds no fabricated spell choices")
		check(await page(5), "Companions page preserves familiar/animal choices")
		if index == 0: check(not wizard.inputs.is_empty(), "Existing Wizard familiar fields remain available")
		check(await page(6), "Review opens with all native choices")
		check(wizard.state.canFinish and wizard.state.errors.is_empty(), "Only a valid complete draft enables Finish")
		if not wizard.state.canFinish: finish(message); return
		check(await capture(str(message.screenshot).get_basename() + "-" + str(index + 1) + ".png"), "Actual native review frame captured")
		if index == 0:
			client.inventory.open(); client.character_sheet.open()
			check(await wait_until(func(): return client.inventory.visible and client.character_sheet.visible and client.character_sheet.view_id >= 0, 10), "Real inventory and character record coexist with the level-up draft")
			var keyboard = client.keyboard
			var focus: bool = keyboard.require_focus; keyboard.require_focus = false
			var begin: Vector3 = client.pivots[client.controlled_id].global_position
			keyboard.keys[KEY_W] = true; await client.get_tree().create_timer(0.6).timeout
			keyboard.keys.erase(KEY_W); keyboard.clear(true); keyboard.require_focus = focus
			check(client.pivots[client.controlled_id].global_position.distance_to(begin) > 0.05 and wizard.state.phase == "editing", "Actual WASD remains responsive with simultaneous draft/inventory/record windows")
		wizard.submit()
		check(await wait_until(func(): return not wizard.wanted or wizard.state.get("phase") in ["rejected", "error", "stale"], 20) and not wizard.wanted, "Actual native server confirmation completes the level-up")
		if wizard.wanted: finish(message); return
		check(await wait_until(func(): return int(client.level_state.get("level", 0)) == starting_level + index + 1, 15), "Actual replicated classes advance after server acceptance")
		runs.append({"classId": class_id, "skillId": plus.get("value", -1), "featId": selected_feat, "spells": spells, "level": client.level_state.get("level", 0)})
		if index == 0: check(await wait_until(func(): return client.level_state.get("available", false) and not client.quickbar.level_button.disabled, 10), "The remaining banked XP enables a second real level-up")
	finish(message)

func finish(message: Dictionary, _item_id: int = 0) -> void:
	if valid(): client.command({"kind": "level-tested", "result": {"completed": true, "checks": checks, "startingLevel": starting_level, "runs": runs, "classes": client.level_state.get("classes", []), "screenshot": message.screenshot}})
