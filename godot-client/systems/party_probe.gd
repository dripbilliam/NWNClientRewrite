extends RefCounted
var client
var connection := -1
var running := true
var checks: Array = []
var companion_id := -1
var observations: Dictionary = {}
func stop() -> void: running = false
func valid() -> bool: return running and is_instance_valid(client) and client.connection == connection
func check(value: bool, name: String) -> bool:
	checks.append({"name":name,"passed":value}); print("NATIVE_PARTY_CHECK ", value, " ", name); return value
func wait_until(predicate: Callable, seconds: float = 12) -> bool:
	var until := Time.get_ticks_msec() + int(seconds * 1000)
	while valid() and Time.get_ticks_msec() < until:
		if predicate.call(): return true
		await client.get_tree().process_frame
	return false
func click(point: Vector2, key: int = MOUSE_BUTTON_LEFT) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new(); event.button_index = key; event.pressed = pressed; event.position = point; event.global_position = point; client.get_viewport().push_input(event, true); await client.get_tree().process_frame
func panel(index: int) -> void: await click(client.party.action_buttons[index].get_global_rect().get_center())
func light() -> Dictionary:
	for row in client.spellbook.state.get("known", []):
		if int(row.spellId) == 100: return row
	return {}
func run(owner, message: Dictionary) -> void:
	client = owner; connection = client.connection
	var bar = client.party
	client.examine_panel.hide()
	if message.get("retired", false): check(bar.retired_alive() == 0, "Previous connection party cards and original textures are released")
	if not check(await wait_until(func(): return bar.rows.size() >= 1 and bar.actor_id == client.controlled_id and bar.rows[0].available), "Actual server controlled creature creates the native party HUD"): finish(message); return
	var portrait: Button = bar.cards[0].get_node("Box/Portrait"); var portrait_identity := portrait.get_instance_id()
	check(await wait_until(func(): return portrait.get_node("Image").texture != null and not str(bar.rows[0].label).begins_with("Object ")), "Original installed player portrait and localized name reach the native HUD")
	check(await wait_until(func(): return bar.art.size() == 24), "All eight original button skins load in up, hover and pressed states")
	check(bar.rows[0].health != null and not bar.cards[0].get_node("Box/Health/Text").text.is_empty(), "Server-disclosed player health is shown without substituting private inventory fields")
	var controlled: int = client.controlled_id; var at: Vector2 = portrait.get_global_rect().get_center(); await click(at)
	check(client.controlled_id == controlled and not client.targeting.active and not client.radial.active, "Idle portrait selection preserves server ownership without starting movement or an action")
	client.command({"kind":"chat","channel":1,"text":"-native-party-add"})
	if not check(await wait_until(func(): return bar.rows.size() == 2 and bar.rows[1].available), "Actual AddHenchman server membership creates a second native party card"): finish(message); return
	companion_id = int(bar.rows[1].id)
	check(await wait_until(func(): return bar.cards[1].get_node("Box/Portrait/Image").texture != null), "The actual companion's original portrait is available")
	await client.get_tree().process_frame; await RenderingServer.frame_post_draw
	await click(bar.cards[1].get_node("Box/Portrait").get_global_rect().get_center(), MOUSE_BUTTON_RIGHT)
	var opened := await wait_until(func(): return client.radial.active and not client.radial.pending and not client.radial.entries.is_empty())
	observations.radial = {"opened":opened,"active":client.radial.active,"pending":client.radial.pending,"entries":client.radial.entries.duplicate(true),"hint":client.radial.hint.text,"portrait":str(bar.cards[1].get_node("Box/Portrait").get_global_rect())}
	if not check(opened, "Actual right-click party portrait opens the existing native radial provider"): finish(message); return
	observations.associateLayer = false
	if not client.radial.entries.any(func(r): return r.get("action") == "object.examine"):
		var branch: Array = client.radial.entries.filter(func(r): return str(r.get("icon", "")).to_upper() == "IR_ASSOC_ACTION" and r.get("submenu", false))
		if not branch.is_empty():
			observations.associateLayer = true
			var menu: int = client.radial.menu_id; client.radial.buttons[int(branch[0].slot)].pressed.emit()
			if not await wait_until(func(): return client.radial.menu_id != menu and not client.radial.pending and client.radial.entries.any(func(r): return r.get("action") == "object.examine")): finish(message); return
	var examine: Array = client.radial.entries.filter(func(r): return r.get("action") == "object.examine")
	if not examine.is_empty(): client.radial.buttons[int(examine[0].slot)].pressed.emit()
	check(await wait_until(func(): return client.examine_panel.visible and int(client.examine_panel.state.get("targetId", -1)) == companion_id), "Party radial examination receives the actual server companion description")
	client.examine_panel.hide()
	await panel(0); check(await wait_until(func(): return client.area_map.wanted and client.area_map.view_id >= 0), "Native party Map control opens the installed area map")
	await panel(1); check(await wait_until(func(): return client.inventory.wanted and client.inventory.view_id >= 0), "Party Inventory opens while the map remains open")
	await panel(3); check(await wait_until(func(): return client.character_sheet.wanted and client.character_sheet.view_id >= 0), "Party Character Sheet opens alongside other windows")
	await panel(2); check(await wait_until(func(): return client.journal.wanted and client.journal.view_id >= 0), "Party Journal connects to the existing native categories")
	client.area_map.close_map(); client.inventory.close_inventory(); client.character_sheet.close_sheet(); client.journal.close_journal()
	await panel(6); check(client.options.visible, "Party Options opens native persistent preferences")
	check(await wait_until(func(): return client.options.installation.view_id >= 0 and client.options.installation.status.get("resourcesLocked", false)), "Actual connected settings lock mod changes and receive protected-key metadata")
	check(not client.status.visible and not client.owner_scene.native_hud.metrics.text.contains("NATIVE GODOT"), "Admitted game frame has no outer debug overlay")
	var debug_before: bool = client.options.debug_enabled
	client.options.debug_toggle.button_pressed = true
	check(await wait_until(func(): return client.debug_window.visible and client.debug_window.backend.get("gameplay", {}).get("phase", "") == "playing"), "Separate native debug window receives the live local gameplay state")
	check(client.debug_window.get_window_id() != client.get_viewport().get_window_id(), "Live debug diagnostics use a separate operating-system window")
	client.debug_window.close_requested.emit(); client.options.debug_toggle.button_pressed = debug_before
	var fps_before: bool = client.options.show_fps; client.options.fps_toggle.button_pressed = not fps_before
	check(client.owner_scene.native_hud.metrics.visible == not fps_before, "Native FPS preference controls only the compact game counter")
	client.options.fps_toggle.button_pressed = fps_before
	await panel(6)
	check(not client.options.visible, "Actual party Options button closes preferences after returning from the separate debug window")
	await panel(7); check(await wait_until(func(): return client.players.wanted and client.players.view_id >= 0 and not client.players.rows.is_empty()), "Native PvP button receives the actual server player roster")
	check(client.players.rows.any(func(r): return r.self) and client.players.list.get_child_count() == client.players.rows.size(), "Player attitude list marks the controlled player and creates only received rows")
	client.players.close_players()
	await panel(5)
	if not check(await wait_until(func(): return client.spellbook.wanted and not light().is_empty() and int(light().get("uses", 0)) > 0), "Party Spellbook opens with actual prepared Light uses"): finish(message); return
	var before: int = int(light().uses); client.spellbook.widgets[int(light().entryId)].pressed.emit(); await client.get_tree().process_frame
	await click(client.spellbook.cast.get_global_rect().get_center())
	check(await wait_until(func(): return client.targeting.active), "The native book's cast control enables the original spell targeter")
	await click(bar.cards[1].get_node("Box/Portrait").get_global_rect().get_center())
	check(await wait_until(func(): return not client.targeting.active and not light().is_empty() and int(light().uses) < before, 20), "Actual companion portrait click casts Light and consumes a server-prepared use")
	client.spellbook.wanted = false; client.spellbook.hide(); client.command({"kind":"spellbook-close"})
	check(client.controlled_id == controlled, "Targeting a companion never changes the server-controlled actor")
	await panel(7)
	var controller = client.owner_scene.camera_controller; var yaw: float = controller.yaw
	var middle := InputEventMouseButton.new(); middle.button_index = MOUSE_BUTTON_MIDDLE; middle.pressed = true; middle.position = at; client.get_viewport().push_input(middle, true)
	var motion := InputEventMouseMotion.new(); motion.position = at; motion.relative = Vector2(3, 0); client.get_viewport().push_input(motion, true); middle.pressed = false; client.get_viewport().push_input(middle, true)
	check(controller.yaw != yaw and not controller.dragging, "Middle mouse camera rotation works over the party HUD with a player window open"); controller.orbit(Vector2(-3, 0))
	var start: Vector3 = client.pivots[controlled].global_position; var required: bool = client.keyboard.require_focus; client.keyboard.require_focus = false
	for pressed in [true, false]:
		var key := InputEventKey.new(); key.keycode = KEY_W; key.physical_keycode = KEY_W; key.pressed = pressed; client.get_viewport().push_input(key, true)
		if pressed: await client.get_tree().create_timer(0.7).timeout
	client.keyboard.require_focus = required
	check(await wait_until(func(): return client.pivots[controlled].global_position.distance_to(start) > 0.1, 8), "WASD remains live with native party and player-list menus")
	client.players.close_players(); await client.get_tree().process_frame; await RenderingServer.frame_post_draw
	check(client.get_viewport().get_texture().get_image().save_png(str(message.screenshot)) == OK, "Actual original party portraits and eight installed HUD skins captured for visual review")
	observations.before = {"rows":bar.rows.duplicate(true),"art":bar.art.size(),"portrait":str(portrait.get_node("Image").texture.get_size())}
	var area: int = client.area_id; var generation: int = client.generation; client.command({"kind":"chat","channel":1,"text":"-native-b"})
	check(await wait_until(func(): return client.area_id != area and client.generation > generation and client.smoke_frame_complete, 45), "Actual second area admits and animates with party controls live")
	check(bar.cards[0].get_node("Box/Portrait").get_instance_id() == portrait_identity and bar.art.size() == 24, "Area replacement preserves the connection-owned portrait widget and original HUD art")
	if not valid(): return
	generation = client.generation; client.command({"kind":"chat","channel":1,"text":"-native-a"})
	check(await wait_until(func(): return client.area_id == area and client.generation > generation and client.smoke_frame_complete, 45), "Native party HUD completes actual A–B–A world replacement")
	client.command({"kind":"chat","channel":1,"text":"-native-party-remove"})
	check(await wait_until(func(): return bar.rows.size() == 1 and bar.cards.size() == 1), "Actual RemoveHenchman membership retires the companion card without transferring control")
	await panel(4); check(client.controlled_id == controlled, "Native Rest control keeps the current controlled actor")
	await client.get_tree().create_timer(0.4).timeout
	finish(message)
func finish(message: Dictionary) -> void:
	if valid(): client.command({"kind":"roster-tested","result":{"completed":true,"checks":checks,"rows":client.party.rows,"actorId":client.party.actor_id,"companionId":companion_id,"observations":observations,"screenshot":message.screenshot}})
