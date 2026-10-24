extends RefCounted

var client
var scope: Dictionary
var checks: Array[Dictionary] = []
var prompt_seen := false
var float_ack_seen := false
var stopped := false
var spell_observed := false
var ui_trace: Array = []
var traced_at := 0
var combat_samples: Array = []
var sampling := 0
var particle_before: Dictionary = {}
var particle_probe: Dictionary = {}

func stop() -> void:
	stopped = true
	if is_instance_valid(client) and client.combat.presentation_event.is_connected(combat_event):
		client.combat.presentation_event.disconnect(combat_event)

func combat_event(value: Dictionary) -> void:
	if not current() or int(value.id) != client.controlled_id or value.kind != "play" or int(value.get("animation", 0)) not in [17, 18, 19, 20, 61, 200, 201, 202, 203, 204, 205, 263, 264, 265] or combat_samples.size() + sampling >= 12:
		return
	var rigs = client.model_rigs
	var before: Dictionary = rigs.diagnostic_sample([client.controlled_id])
	sampling += 1
	await client.get_tree().create_timer(0.08).timeout
	sampling -= 1
	if not current() or not is_instance_valid(rigs) or client.model_rigs != rigs:
		return
	var comparison: Dictionary = rigs.compare_samples(before, rigs.diagnostic_sample([client.controlled_id]))
	combat_samples.append({"animation": value.animation, "clip": value.clip, "comparison": comparison})

func combat_test() -> bool:
	check(await wait_for(func(): return int(client.combat.stats.casts) >= 3), "Real cast records reach the native animation cue owner")
	check(await wait_for(func(): return combat_samples.any(func(row): return int(row.animation) in [17, 18, 19, 20, 61] and int(row.comparison.advanced_model_clocks) > 0 and float(row.comparison.maximum_local_skin_vertex_delta) > 0.0001)), "Actual native casting advances original model clocks and GPU skin vertices")
	if not check(await open_radial(int(scope.targetId)), "Native ray picking opens an attack menu on the local immortal target"):
		return false
	client.radial.buttons[2].pressed.emit()
	if not check(await wait_for(func(): return int(client.combat.stats.attacks) >= 2 and int(client.combat.stats.hits) >= 1, 25), "Real server attacks play native selected clips and their original hit events advance combat presentation"):
		return false
	check(await wait_for(func(): return combat_samples.any(func(row): return int(row.animation) in [200, 201, 202, 203, 204, 205, 263, 264, 265] and int(row.comparison.changed_local_parts) > 0 and float(row.comparison.maximum_local_skin_vertex_delta) > 0.0001)), "Native attack playback deforms the original controlled creature's GPU skin")
	check(await save_frame(str(scope.screenshot).replace("-gameplay.png", "-combat.png")), "Actual native combat frame saved for review")
	check(client.combat.failures.filter(func(reason): return str(reason).begins_with(str(client.controlled_id) + ":")).is_empty(), "Controlled casting and attack clips have no native selector/playback failures")
	return true

func note(message: Dictionary) -> void:
	if message.kind == "spell-observed":
		spell_observed = int(message.before) > int(message.after)
	if message.kind == "floating":
		var text := str(message.get("rich", {}).get("text", ""))
		prompt_seen = prompt_seen or text.contains("Select a slot")
		float_ack_seen = float_ack_seen or text.contains("GODOT_FLOAT_ACK")

func check(value: bool, name: String) -> bool:
	checks.append({"name": name, "passed": value})
	return value

func current() -> bool:
	return not stopped and is_instance_valid(client) and client.world_scope.admitted and client.world_scope.matches(scope)

func wait_for(predicate: Callable, seconds: float = 12.0) -> bool:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000)
	while current() and Time.get_ticks_msec() < deadline:
		if Time.get_ticks_msec() - traced_at >= 500:
			traced_at = Time.get_ticks_msec()
			ui_trace.append({"queue_peak_bytes": Performance.get_monitor(Performance.MEMORY_MESSAGE_BUFFER_MAX), "radial": [client.radial.stage.size.x, client.radial.stage.size.y], "buttons": client.radial.buttons.values().map(func(button): return [button.size.x, button.size.y]), "examine": [client.examine_panel.size.x, client.examine_panel.size.y], "examine_body": [client.examine_panel.body.size.x, client.examine_panel.body.size.y], "pending": client.radial.pending, "menu": client.radial.menu_id})
		if predicate.call():
			return true
		await client.get_tree().process_frame
	return false

func history_contains(text: String) -> bool:
	return client.chat_ui.system_messages.get_parsed_text().contains(text)

func finish(completed: bool) -> void:
	if not is_instance_valid(client) or not client.world_scope.admitted or not client.world_scope.matches(scope):
		return
	stop()
	client.command({"kind": "gameplay-tested", "result": {"completed": completed, "checks": checks, "radial": scope.get("radial", false), "book": scope.get("book", false), "combat": scope.get("combat", false), "combatSamples": combat_samples, "nativeCombat": client.combat.snapshot(), "nativeParticles": client.particles.stats.duplicate(true) if is_instance_valid(client.particles) else {}, "particleSamples": {"before": particle_before, "after": client.particles.diagnostic_sample() if is_instance_valid(client.particles) else {}}, "particleProbe": particle_probe, "uiTrace": ui_trace}})

func particle_test() -> bool:
	var world = client.particles
	if not check(await wait_for(func(): return world.stats.frames >= 20 and world.stats.visible > 0), "Real worker frames produce visible native particle owners"):
		return false
	var surfaces: Array = world.surfaces.values().filter(func(surface): return surface.visible and surface.source_texture != null)
	if not check(not surfaces.is_empty(), "Live emitter retains an original installed texture"):
		return false
	var surface = surfaces[0]
	var camera: Camera3D = client.owner_scene.camera
	var saved := camera.global_transform
	var following: bool = client.following
	var overlay_visible: bool = client.overlay.visible
	client.following = false
	client.overlay.hide()
	var center: Vector3 = surface.custom_aabb.get_center()
	camera.global_position = center + Vector3(0.8, 2, 4)
	camera.look_at(center, Vector3.UP)
	var mark: int = world.stats.frames
	check(await wait_for(func(): return world.stats.frames >= mark + 3), "Native camera change reaches live billboard vertex generation")
	await RenderingServer.frame_post_draw
	var active: Image = client.get_viewport().get_texture().get_image()
	var screen := camera.unproject_position(center)
	var rect := Rect2i(Vector2i(screen) - Vector2i(90, 90), Vector2i(180, 180)).intersection(Rect2i(Vector2i.ZERO, active.get_size()))
	check(await save_frame(str(scope.screenshot).replace("-gameplay.png", "-particles.png")), "Original live particle frame captured for visual review")
	world.diagnostic_hidden = true
	await client.get_tree().process_frame
	await RenderingServer.frame_post_draw
	var hidden: Image = client.get_viewport().get_texture().get_image()
	var changed := 0
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var a := active.get_pixel(x, y)
			var b := hidden.get_pixel(x, y)
			if Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length() > 0.025:
				changed += 1
	check(await save_frame(str(scope.screenshot).replace("-gameplay.png", "-particles-hidden.png")), "Matching world frame without particle surfaces captured")
	world.diagnostic_hidden = false
	camera.global_transform = saved
	client.following = following
	client.overlay.visible = overlay_visible
	particle_probe = {"changedPixels": changed, "rect": [rect.position.x, rect.position.y, rect.size.x, rect.size.y], "originalTexture": true, "surfaceCount": surfaces.size()}
	return check(changed >= 8, "Original particle surfaces contribute actual on-screen pixels")

func book_light() -> Dictionary:
	for row in client.spellbook.state.get("known", []):
		if int(row.spellId) == 100:
			return row
	return {}

func click_controlled() -> bool:
	var registry = client.owner_scene.registry
	var camera: Camera3D = client.owner_scene.camera
	var candidates: Array[Vector3] = [registry.bounds[client.controlled_id].get_center()]
	for mesh in registry.parts.get(client.controlled_id, []):
		candidates.append(mesh.global_transform * mesh.get_aabb().get_center())
	await client.get_tree().physics_frame
	for candidate in candidates:
		var point := camera.unproject_position(candidate)
		var hit: Dictionary = registry.pick(camera, point)
		if int(hit.get("id", -1)) != client.controlled_id or client.owner_scene.world_input.extra_pointer_block.call(point):
			continue
		var event := InputEventMouseButton.new()
		event.pressed = true
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = point
		client.owner_scene.world_input._unhandled_input(event)
		client.owner_scene.world_input._physics_process(0.1)
		return true
	return false

func book_test() -> bool:
	client.command({"kind": "radial-cancel", "requestId": client.radial.request_id})
	client.radial.reset()
	client.spellbook.open()
	if not check(await wait_for(func(): return client.spellbook.view_id >= 0 and not book_light().is_empty()), "Native spellbook receives the real wizard's known cantrips and prepared pool"):
		return false
	var light := book_light()
	check(int(light.uses) == 1, "Spellbook remaining uses agree with the preceding actual radial cast")
	check(await wait_for(func(): return client.spellbook.widgets[int(book_light().entryId)].image.texture != null), "Original Light icon is decoded into the native spellbook")
	client.spellbook.widgets[int(light.entryId)].pressed.emit()
	check(await wait_for(func(): return not client.spellbook.details.get_parsed_text().is_empty()), "Native spell description resolves from the installed TLK")
	client.quickbar.render(2)
	var payload: Dictionary = client.spellbook.widgets[int(light.entryId)].payload.duplicate(true)
	client.quickbar.buttons[35]._drop_data(Vector2.ZERO, payload)
	if not check(await wait_for(func(): return client.quickbar.rows.size() == 36 and client.quickbar.rows[35].enabled and str(client.quickbar.rows[35].label) == str(light.label)), "Native spell drag sends a real slot-35 shortcut assignment"):
		return false
	check(await wait_for(func(): return client.quickbar.buttons[35].image.texture != null), "Assigned shortcut displays the original spell icon and remaining count")
	check(await save_frame(str(scope.screenshot).replace("-gameplay.png", "-spellbook.png")), "Native spellbook, prepared rows and populated shortcut frame saved")
	client.quickbar.buttons[35].pressed.emit()
	if not check(await wait_for(func(): return client.targeting.active), "Clicking the native shortcut enters the original target-selection mode"):
		return false
	client.spellbook.wanted = false
	client.spellbook.hide()
	client.command({"kind": "spellbook-close"})
	if not check(await click_controlled(), "Actual native world ray click selects the controlled spell target"):
		return false
	if not check(await wait_for(func(): return client.quickbar.rows.size() == 36 and int(client.quickbar.rows[35].get("uses", -1)) == 0, 18), "Quickbar cast consumes the second actual server-prepared Light slot"):
		return false
	client.spellbook.open()
	if not check(await wait_for(func(): return not book_light().is_empty() and int(book_light().get("uses", -1)) == 0), "Reopened spellbook reflects the server's exhausted pool"):
		return false
	var memory: Array = client.spellbook.state.memory.filter(func(row): return int(row.spellId) == 100)
	if not check(not memory.is_empty(), "The physical used preparation slot remains visible"):
		return false
	var slot := int(memory[0].slot)
	client.spellbook.widgets[int(memory[0].entryId)].pressed.emit()
	client.spellbook.clear.pressed.emit()
	if not check(await wait_for(func(): return client.spellbook.state.memory.any(func(row): return int(row.slot) == slot and int(row.spellId) < 0)), "Clear prepared slot waits for an actual server-replicated empty record"):
		return false
	light = book_light()
	var destination: Dictionary = client.spellbook.state.memory.filter(func(row): return int(row.slot) == slot)[0]
	payload = client.spellbook.widgets[int(light.entryId)].payload.duplicate(true)
	client.spellbook.widgets[int(destination.entryId)]._drop_data(Vector2.ZERO, payload)
	if not check(await wait_for(func(): return client.spellbook.state.memory.any(func(row): return int(row.slot) == slot and int(row.spellId) == 100 and not row.pending)), "Native preparation drag reaches the server and returns the requested physical slot"):
		return false
	check(int(book_light().uses) == 0, "Preparing a used spell does not grant a ready cast before rest")
	var fixture: Dictionary = scope.familyFixture
	var before_view: int = client.spellbook.view_id
	client.spellbook.query({"level": fixture.level})
	if not check(await wait_for(func(): return client.spellbook.view_id != before_view and client.spellbook.state.known.any(func(row): return int(row.spellId) == int(fixture.spellId) and row.family)), "Real server admits the isolated fixture character's spell-family parent"):
		return false
	var parent: Dictionary = client.spellbook.state.known.filter(func(row): return int(row.spellId) == int(fixture.spellId))[0]
	client.spellbook.widgets[int(parent.entryId)].pressed.emit()
	if not check(await wait_for(func(): return client.spellbook.state.family.size() == fixture.children.size()), "Native family click exposes every child from the active original spell table"):
		return false
	var variant: Dictionary = client.spellbook.state.family[-1]
	check(not variant.family and variant.canDrag, "Actual family child has a draggable leaf binding while its parent cannot cast")
	client.quickbar.render(2)
	payload = client.spellbook.widgets[int(variant.entryId)].payload.duplicate(true)
	client.quickbar.buttons[34]._drop_data(Vector2.ZERO, payload)
	if not check(await wait_for(func(): return str(client.quickbar.rows[34].label) == str(variant.label) and client.quickbar.rows[34].enabled), "Real native variant drag assigns the child to a shortcut"):
		return false
	check(await wait_for(func(): return client.spellbook.state.family.all(func(row): return client.spellbook.widgets[int(row.entryId)].image.texture != null)), "Every original spell-family child icon reaches its native row")
	check(await save_frame(str(scope.screenshot).replace("-gameplay.png", "-family.png")), "Original spell-family variants and shortcut frame saved for review")
	client.quickbar.buttons[34].pressed.emit()
	if not check(await wait_for(func(): return client.targeting.active), "The assigned original family variant begins typed targeting"):
		return false
	client.spellbook.wanted = false
	client.spellbook.hide()
	client.command({"kind": "spellbook-close"})
	if not check(await click_controlled(), "Original family variant accepts an actual native controlled-creature ray hit"):
		return false
	if not check(await wait_for(func(): return int(client.quickbar.rows[34].get("uses", -1)) == 0, 18), "Casting the real child consumes the shared server-prepared family slot"):
		return false
	return true

func open_radial(id: int) -> bool:
	var registry = client.owner_scene.registry
	var camera: Camera3D = client.owner_scene.camera
	var candidates: Array[Vector3] = [registry.bounds[id].get_center()]
	for mesh in registry.parts.get(id, []):
		candidates.append(mesh.global_transform * mesh.get_aabb().get_center())
	await client.get_tree().physics_frame
	for candidate in candidates:
		if camera.is_position_behind(candidate):
			continue
		var point := camera.unproject_position(candidate)
		if not client.get_viewport().get_visible_rect().has_point(point):
			continue
		# Keep an existing examination beside the clicked object, not over it.
		if client.examine_panel.visible:
			client.examine_panel.position.x = 16 if point.x > client.get_viewport().get_visible_rect().size.x / 2 else client.get_viewport().get_visible_rect().size.x - client.examine_panel.size.x - 16
		if client.chat_box.get_global_rect().has_point(point) or client.examine_panel.visible and client.examine_panel.get_global_rect().has_point(point):
			continue
		var hit: Dictionary = registry.pick(camera, point)
		if int(hit.get("id", -1)) != id:
			continue
		var old_request: int = client.radial.request_id
		var event := InputEventMouseButton.new()
		event.pressed = true
		event.button_index = MOUSE_BUTTON_RIGHT
		event.position = point
		client.owner_scene.world_input._unhandled_input(event)
		client.owner_scene.world_input._physics_process(0.1)
		if client.radial.request_id <= old_request:
			continue
		return await wait_for(func(): return client.radial.active and not client.radial.pending and client.radial.menu_id > 0)
	return false

func radial_choose(slot: int) -> bool:
	var old_menu: int = client.radial.menu_id
	client.radial.buttons[slot].pressed.emit()
	return await wait_for(func(): return not client.radial.active or not client.radial.pending and client.radial.menu_id != old_menu)

func light_choice() -> Dictionary:
	if not await open_radial(client.controlled_id):
		return {}
	for slot in [1, 5, 0]:
		if not await radial_choose(slot):
			return {}
	for page in 8:
		for entry in client.radial.entries:
			if entry.get("spellId") == 100:
				return entry
		if not client.radial.entries.any(func(entry): return int(entry.slot) == 7 and entry.get("submenu", false)) or not await radial_choose(7):
			return {}
	return {}

func save_frame(name: String) -> bool:
	await RenderingServer.frame_post_draw
	var path := ProjectSettings.globalize_path("res://reports/" + name)
	return name.get_file() == name and name.ends_with(".png") and not FileAccess.file_exists(path) and client.get_viewport().get_texture().get_image().save_png(path) == OK

func run(value, message: Dictionary) -> void:
	particle_before = value.particles.diagnostic_sample() if is_instance_valid(value.particles) else {}
	client = value
	scope = message.duplicate()
	if scope.get("combat", false):
		client.combat.presentation_event.connect(combat_event)
	var target_id := int(message.targetId)
	var use_radial := bool(message.get("radial", false))
	if use_radial:
		if not check(await open_radial(target_id), "Actual native object ray pick opens the original context menu"):
			finish(false)
			return
		check(client.radial.layer > client.lobby.layer, "Wheel stays above the native lobby and gameplay windows")
		client.radial.buttons[0].pressed.emit()
	else:
		client.owner_scene.native_hud.inspect_entity(target_id)
	if not check(await wait_for(func(): return client.examine_panel.visible and int(client.examine_panel.state.get("targetId", -1)) == target_id), "Right-click/I examine path receives actual server examination"):
		finish(false)
		return
	var state: Dictionary = client.examine_panel.state
	check(str(state.get("name", {}).get("text", "")) == "Native Speaker", "Examine uses the server-disclosed creature identity")
	var description: Dictionary = state.get("description", {})
	check(str(description.get("text", "")).contains("Attuned to Fire") and not str(description.get("text", "")).contains("<FirstName>"), "Server-authored description and actual name token survive native examination")
	check(description.get("spans", []).any(func(span): return span.get("color") == "#87ceeb"), "Native examination receives the original byte RGB color")
	check(await wait_for(func(): return client.examine_panel.portrait.visible), "Installed portrait loads without blocking description delivery")
	if use_radial:
		if not check(await open_radial(target_id), "A new right-click wheel can coexist above the examination window"):
			finish(false)
			return
		check(await wait_for(func(): return client.radial.icons[0].texture != null), "Original action icon is displayed by a native radial button")
		check(await save_frame(str(message.screenshot).replace("-gameplay.png", "-radial.png")), "Native wheel and examination frame saved for visual review")
		client.radial.buttons[7].pressed.emit()
	else:
		client.command({"kind": "interact", "targetId": target_id})
	if not check(await wait_for(func(): return client.dialog_panel.visible and client.dialog_panel.entry_id >= 0 and client.dialog_panel.body.get_parsed_text().contains("FIRST_ENTRY")), "Native server starts conversation after ordinary interaction"):
		finish(false)
		return
	check(client.dialog_panel.body.get_parsed_text().contains("token-ready"), "Custom token sent by server script is resolved in native dialogue")
	check(client.examine_panel.visible and client.dialog_panel.replies.get_child_count() == 2, "Examine and server conversation coexist with both reply choices")
	await client.get_tree().process_frame
	await client.get_tree().process_frame
	await RenderingServer.frame_post_draw
	var screenshot := str(message.screenshot)
	var path := ProjectSettings.globalize_path("res://reports/" + screenshot)
	var saved := false
	if screenshot.get_file() == screenshot and screenshot.ends_with(".png") and not FileAccess.file_exists(path):
		saved = client.get_viewport().get_texture().get_image().save_png(path) == OK
	check(saved, "Actual native dialogue/examine frame saved for visual review")
	client.dialog_panel.replies.get_child(0).pressed.emit()
	if not check(await wait_for(func(): return client.dialog_panel.entry_id >= 0 and not client.dialog_panel.pending and client.dialog_panel.body.get_parsed_text().contains("SECOND_ENTRY")), "Advertised reply button advances the real native server DLG"):
		finish(false)
		return
	check(await wait_for(func(): return prompt_seen and history_contains("GODOT_PICK_ACK")), "Real server action script produces overhead feedback and chat history")
	client.dialog_panel.replies.get_child(0).pressed.emit()
	check(await wait_for(func(): return not client.dialog_panel.visible and history_contains("GODOT_END_ACK")), "Normal conversation end runs the real server end script and closes native choices")
	client.command({"kind": "interact", "targetId": target_id})
	if not check(await wait_for(func(): return client.dialog_panel.visible and client.dialog_panel.entry_id >= 0 and not client.dialog_panel.pending), "Same creature can begin another conversation without stale reply ownership"):
		finish(false)
		return
	client.dialog_panel.end_button.pressed.emit()
	check(await wait_for(func(): return not client.dialog_panel.visible and history_contains("GODOT_ABORT_ACK")), "Native abort sentinel runs the server abort script and closes the window")
	client.chat_ui.submit("-native-text")
	check(await wait_for(func(): return history_contains("GODOT_CHAT_ACK") and float_ack_seen), "Native chat entry invokes actual server chat/prompt scripts")
	check(client.chat_ui.rows.any(func(row): return row.get("system", false) and row.get("rich", {}).get("spans", []).any(func(span): return span.get("color") == "#01ff01")), "Server system-feedback history retains supplied colors")
	if use_radial:
		client.examine_panel.hide()
		var spell := await light_choice()
		if not check(not spell.is_empty() and not spell.get("disabled", true) and int(spell.get("uses", 0)) > 0, "Native class/level radial exposes the server-prepared Light spell"):
			finish(false)
			return
		var before := int(spell.uses)
		client.radial.buttons[int(spell.slot)].pressed.emit()
		if not check(await wait_for(func(): return spell_observed, 18), "Radial cast consumes an actual server-replicated prepared slot"):
			finish(false)
			return
		var after := await light_choice()
		check(not after.is_empty() and int(after.get("uses", before)) < before, "Reopening native spell menus reflects the server's changed remaining uses")
		client.radial.back()
		client.native_cursor.select(11)
		check(await wait_for(func(): return client.native_cursor.textures.has(11)), "Original talk cursor image reaches the native cursor owner")
	if scope.get("book", false) and not await book_test():
		finish(false)
		return
	if scope.get("combat", false) and not await combat_test():
		finish(false)
		return
	if scope.get("particles", false) and not await particle_test():
		finish(false)
		return
	finish(checks.all(func(row): return row.passed))
