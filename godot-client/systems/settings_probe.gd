extends RefCounted
var client
var running := true
var checks: Array = []
var native_window := false
func stop() -> void: running = false
func check(value: bool, name: String) -> bool:
	checks.append({"name":name,"passed":value}); print("NATIVE_SETTINGS_CHECK ", value, " ", name); return value
func wait_until(predicate: Callable, seconds: float = 12) -> bool:
	var until := Time.get_ticks_msec() + int(seconds * 1000)
	while running and is_instance_valid(client) and Time.get_ticks_msec() < until:
		if predicate.call(): return true
		await client.get_tree().process_frame
	return false
func click(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new(); motion.position = point; motion.global_position = point; client.get_viewport().push_input(motion, true)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new(); event.button_index = MOUSE_BUTTON_LEFT; event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0; event.pressed = pressed; event.position = point; event.global_position = point; client.get_viewport().push_input(event, true)
	await client.get_tree().process_frame
func press(button: BaseButton) -> void:
	# Native control dispatch for the live persistence/window check. Isolated
	# authored GUI tests cover pointer dispatch without concurrent OS input.
	if button.is_visible_in_tree() and not button.disabled:
		if button is CheckBox: button.button_pressed = not button.button_pressed
		else: button.pressed.emit()
	await client.get_tree().process_frame
func run(owner, message: Dictionary) -> void:
	client = owner
	check(client.generation < 0 and client.main_menu.panel.visible, "Native Main Menu is available before any server admission")
	client.main_menu.choose("options"); await client.get_tree().process_frame
	var setup = client.options.installation; client.options.tabs.current_tab = 1
	if not check(await wait_until(func(): return setup.view_id >= 0 and setup.rows.size() == 2), "Native Main Menu Options receives the actual authored Workshop catalog"): finish(message); return
	check(setup.status.protectedStorageAvailable and not setup.status.hasSavedCdKey and not setup.status.resourcesLocked, "Real Windows-protected storage metadata reaches the native client without a key")
	check(str(setup.status.defaultModsDirectory) == str(message.mods) and setup.folder.text == str(message.mods), "Detected default folder and selected mods root are displayed")
	await client.get_tree().process_frame; await RenderingServer.frame_post_draw
	var second: TreeItem = setup.mods.get_root().get_child(1); var rectangle: Rect2 = setup.mods.get_item_area_rect(second, 0)
	await click(setup.mods.global_position + rectangle.position + Vector2(10, rectangle.size.y / 2))
	check(not second.is_checked(0), "Actual native catalog checkbox disables the second mod")
	setup.key.text = "AAAAA-AAAAA-AAAAA-AAAAA-AAAAA-AAAAA-AAAAA"; var old: int = setup.view_id
	await press(setup.save_button)
	check(setup.key.text.is_empty(), "Native Save clears entered key text before the asynchronous protected write")
	if not check(await wait_until(func(): return setup.view_id > old and setup.status.hasSavedCdKey), "Actual native request saves a key with Windows protection and refreshes safe metadata"): finish(message); return
	check(setup.rows[0].enabled and not setup.rows[1].enabled and setup.key.text.is_empty(), "The persisted mod toggle returns without any key readback")
	client.options.hide(); client.options.show(); client.options.tabs.current_tab = 1
	check(await wait_until(func(): return setup.view_id >= 0 and setup.status.get("hasSavedCdKey", false)), "Reopening Main Menu settings reads the same protected key metadata and persisted mod state")
	old = setup.view_id; setup.picker.dir_selected.emit(str(message.other))
	check(await wait_until(func(): return setup.view_id > old and setup.folder.text == str(message.other) and setup.rows.size() == 1), "Folder selection scans the alternate local mod root as an unsaved draft")
	old = setup.view_id; await press(setup.save_button)
	check(await wait_until(func(): return setup.view_id > old and setup.rows[0].id == "33"), "Actual Save commits the alternate folder and its independent enabled mod catalog")
	old = setup.view_id; await press(setup.defaults)
	check(await wait_until(func(): return setup.view_id > old and setup.folder.text == str(message.mods)), "Use default returns to the detected Workshop root")
	old = setup.view_id; setup.remove_key.button_pressed = true; await press(setup.save_button)
	check(await wait_until(func(): return setup.view_id > old and not setup.status.hasSavedCdKey), "Explicit native key removal is persisted without returning its previous value")
	await client.get_tree().process_frame; await RenderingServer.frame_post_draw
	check(client.get_viewport().get_texture().get_image().save_png(str(message.screenshot)) == OK, "Actual native Main Menu settings frame captured for visual review")
	client.options.tabs.current_tab = 0; await client.get_tree().process_frame
	await press(client.options.debug_toggle)
	check(await wait_until(func(): return client.debug_window.visible), "Options opens the actual separate native debug window")
	check(client.debug_window.get_window_id() != client.get_viewport().get_window_id(), "Debug diagnostics have a distinct operating-system window rather than a game overlay")
	native_window = client.debug_window.get_window_id() != client.get_viewport().get_window_id()
	for index in 5:
		client.debug_window.tabs.current_tab = index; client.debug_window.refresh(); check(not client.debug_window.bodies[index].text.is_empty(), "Actual native debug tab %s updates" % index)
	check(await wait_until(func(): return not client.debug_window.backend.is_empty()), "Debug window receives bounded live backend metadata without an admitted world")
	client.debug_window.tabs.current_tab = 0; await client.get_tree().create_timer(1.1).timeout; await RenderingServer.frame_post_draw
	check(client.debug_window.get_texture().get_image().save_png(str(message.debugScreenshot)) == OK, "Separate native debug-window rendering captured for review")
	client.debug_window.close_requested.emit(); await client.get_tree().process_frame
	check(not client.debug_window.visible and not client.options.debug_toggle.button_pressed, "Closing the separate debug window synchronizes Options")
	var updates: int = client.debug_window.updates; await client.get_tree().create_timer(0.7).timeout
	check(client.debug_window.updates == updates, "Closed debug diagnostics stop native sampling and formatting")
	client.options.hide(); finish(message)
func finish(message: Dictionary) -> void:
	if running and is_instance_valid(client): client.send({"kind":"setup-tested","result":{"completed":true,"nativeWindow":native_window,"checks":checks,"screenshot":message.screenshot,"debugScreenshot":message.debugScreenshot}})
