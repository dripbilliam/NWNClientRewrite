extends RefCounted
var client
var running := true
var checks: Array = []
var saved_key := ""
var replay_key := ""
var last_name := ""
var first_name := ""
var join_geometry: Dictionary = {}
var voice_samples: Array = []
var preview_samples: Array = []
var preview_animation: Dictionary = {}
func stop() -> void: running = false
func check(value: bool, label: String) -> bool:
	checks.append({"name":label,"passed":value}); print("NATIVE_CREATION_CHECK ", value, " ", label); return value
func wait_until(predicate: Callable, seconds: float = 25) -> bool:
	var until := Time.get_ticks_msec() + int(seconds * 1000)
	while running and is_instance_valid(client) and Time.get_ticks_msec() < until:
		if predicate.call(): return true
		await client.get_tree().process_frame
	return false
func press(button: Button) -> void:
	# Live protocol/UI evidence uses the native button signal. Physical mouse
	# movement in another window can cancel a synthetic press between frames;
	# authored native GUI tests cover pointer dispatch separately.
	if button.is_visible_in_tree() and not button.disabled: button.pressed.emit()
	await client.get_tree().process_frame
func page(step: int) -> bool:
	var ui = client.creation; var before: int = ui.view_id
	await press(ui.tabs[step])
	return await wait_until(func(): return ui.view_id > before and not ui.waiting and int(ui.state.step) == step)
func run(owner, message: Dictionary) -> void:
	client = owner; var ui = client.creation; last_name = str(message.lastName); first_name = str(message.firstName)
	check(client.generation < 0 and client.main_menu.panel.visible, "Character creation starts at the native Main Menu without an uploaded preset")
	client.main_menu.choose("multiplayer"); await client.get_tree().process_frame
	if not await wait_until(func(): return client.server_browser.view_id >= 0): finish(); return
	var browser = client.server_browser
	check(browser.host_edit.text == "127.0.0.1" and browser.port_edit.value == 5121 and browser.state.localOnly, "Native browser defaults to the owned local endpoint with outside connections disabled")
	await press(browser.inspect_button)
	if not check(await wait_until(func(): return browser.status.text == "Server information received" and not browser.state.busy), "Native Server info receives the actual owned server's UDP query reply"): finish(); return
	await press(browser.favorite_button)
	if not await wait_until(func(): return not browser.state.busy): finish(); return
	browser._tab("Favorites")
	if not check(await wait_until(func(): return browser.state.tab == "Favorites" and browser.entries.size() == 1), "Direct endpoint can be saved and listed in native Favorites"): finish(); return
	browser._tab("Direct")
	if not await wait_until(func(): return browser.state.tab == "Direct"): finish(); return
	await client.get_tree().process_frame; await RenderingServer.frame_post_draw
	client.get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://reports/" + str(message.review).replace("-review.png", "-browser.png")))
	await client.get_tree().process_frame; await RenderingServer.frame_post_draw
	join_geometry = {"panel":str(client.server_browser.panel.get_global_rect()),"button":str(client.server_browser.connect_button.get_global_rect()),"visible":client.server_browser.connect_button.is_visible_in_tree(),"disabled":client.server_browser.connect_button.disabled,"menuVisible":client.main_menu.panel.visible,"windowFocused":client.get_window().has_focus()}
	await press(client.server_browser.connect_button)
	if not check(await wait_until(func(): return client.lobby.state.get("canCreate", false)), "Owned local server advertises ready active rules and unlocks Create character"): finish(); return
	check(client.lobby.state.localAllowed or client.lobby.state.choices.all(func(row): return row.source == "server"), "Server-vault-only policy never exposes installed or local-export characters")
	await press(client.lobby.create_button)
	if not check(await wait_until(func(): return ui.wanted and ui.state.get("canEdit", false), 45), "Native Create button opens the live server's creation rules"): finish(); return
	check(not client.lobby.panel.visible and not client.lobby.state.canSelect, "Creation owns the character draft while unrelated vault selection is locked")
	if not check(await page(3), "Native sidebar reaches Class using a fresh private view"): finish(); return
	var fighter: Dictionary = {}
	for item in ui.items:
		if item.get("tag", "") == "class" and item.get("value", -1) == 4: fighter = item
	if not check(not fighter.is_empty() and not fighter.disabled, "Original Fighter class is offered by the active server rules"): finish(); return
	var before: int = ui.view_id; ui.change(int(fighter.controlId), null, before)
	if not check(await wait_until(func(): return ui.view_id > before and not ui.waiting), "Class selection resets dependent choices through the shared creator"): finish(); return
	before = ui.view_id; await press(ui.recommend)
	if not check(await wait_until(func(): return ui.view_id > before and ui.state.get("canEdit", false) and not ui.waiting, 40), "Recommended resolves original package preferences and returns editable choices"): finish(); return
	check(str(ui.state.status).is_empty(), "The local package recommendation completes without missing-resource errors")
	for step in 15:
		if step != int(ui.state.step) and not check(await page(step), "Native creation page %d responds" % (step + 1)): finish(); return
		if step == 2:
			if not check(await wait_until(func():
				var count := 0
				for button in ui.controls.values():
					if button.has_meta("portrait") and button.get_meta("portrait").texture != null: count += 1
				return count == 48, 40), "Original portrait page resolves before any live world or quickbar exists"): finish(); return
			await client.get_tree().process_frame; await RenderingServer.frame_post_draw
			client.get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://reports/" + str(message.portraits)))
		if step == 11:
			var preview = ui.appearance_preview
			if not check(await wait_until(func(): return is_instance_valid(preview.model) and preview.model.installed, 45), "Original body, parts, palettes and idle clips arrive in the isolated native viewport"): finish(); return
			await client.get_tree().process_frame; await RenderingServer.frame_post_draw
			preview_samples.append(preview.snapshot())
			check(preview.model.metadata.entities.is_empty() and preview.model.find_children("*", "CollisionObject3D", true, false).is_empty(), "Original preview has no gameplay entity, collision or interaction owner")
			var sample_before: Dictionary = preview.animation_sample(); var angle_before: float = preview.pivot.rotation.y
			await client.get_tree().create_timer(0.3).timeout; await RenderingServer.frame_post_draw
			preview_animation = preview.model.rigs.compare_samples(sample_before, preview.animation_sample())
			check(int(preview_animation.changed_local_parts) > 0 and int(preview_animation.advanced_model_clocks) > 0 and absf(preview.pivot.rotation.y - angle_before) > 0.01, "Original idle animation and rotation advance in Godot without new model transfers")
			var head: Dictionary = {}; var clothing: Dictionary = {}; var palette: Dictionary = {}
			for item in ui.items:
				if item.get("tag", "") == "head": head = item
				elif item.get("tag", "") == "clothing": clothing = item
				elif item.get("tag", "") == "palette-open" and item.palette == "skin": palette = item
			if not check(head.get("options", []).size() > 1 and clothing.get("options", []).size() > 1, "Active rules offer distinct original head and clothing previews"): finish(); return
			var previous_id: int = preview.preview_id; var previous_view: int = ui.view_id
			ui.change(int(head.controlId), (int(head.value) + 1) % head.options.size(), ui.view_id)
			if not check(await wait_until(func(): return ui.view_id > previous_view and preview.preview_id > previous_id and is_instance_valid(preview.model), 45), "Changing Head replaces the native original-model preview"): finish(); return
			preview_samples.append(preview.snapshot())
			for item in ui.items:
				if item.get("tag", "") == "clothing": clothing = item
			previous_id = preview.preview_id; previous_view = ui.view_id
			ui.change(int(clothing.controlId), (int(clothing.value) + 1) % clothing.options.size(), ui.view_id)
			if not check(await wait_until(func(): return ui.view_id > previous_view and preview.preview_id > previous_id and is_instance_valid(preview.model), 45), "Changing Clothing rebuilds original body parts and material palettes"): finish(); return
			preview_samples.append(preview.snapshot())
			for item in ui.items:
				if item.get("tag", "") == "palette-open" and item.palette == "skin": palette = item
			previous_id = preview.preview_id; previous_view = ui.view_id
			ui.change(int(palette.controlId), null, ui.view_id)
			if not check(await wait_until(func(): return ui.view_id > previous_view and not ui.waiting), "Original skin palette opens without replacing an unchanged model"): finish(); return
			check(preview.preview_id == previous_id and is_instance_valid(preview.model), "Palette browsing reuses the current appearance instead of allocating another preview")
			var color: Dictionary = {}
			for item in ui.items:
				if item.type == "colour" and item.palette == "skin" and int(item.value) == 10: color = item
			if not check(not color.is_empty(), "Original skin swatches expose an active palette row"): finish(); return
			var previous_sha: String = preview.last.glbSha256; ui.change(int(color.controlId), null, ui.view_id)
			if not check(await wait_until(func(): return preview.preview_id > previous_id and is_instance_valid(preview.model), 45), "Skin color selection produces a fresh native model with original palette textures"): finish(); return
			check(str(preview.last.glbSha256) != previous_sha and int(preview.last.appearance.skin) == 10, "Palette selection changes actual transferred model/texture bytes")
			preview_samples.append(preview.snapshot())
			await client.get_tree().process_frame; await client.get_tree().process_frame; await RenderingServer.frame_post_draw
			check(preview.snapshot().retiredAlive == 0 and preview.snapshot().pendingParts == 0 and preview.snapshot().bufferParts == 0, "Replaced preview models retire and both transfer buffers are released")
			client.get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://reports/" + str(message.review).replace("-review.png", "-appearance.png")))
		if step == 12:
			check(not ui.appearance_preview.active and not is_instance_valid(ui.appearance_preview.model), "Leaving Appearance releases the native preview without affecting voice selection")
			var sample: Dictionary = {}
			var alternative: Dictionary = {}
			for item in ui.items:
				if item.type == "voice-sample": sample = item
				elif item.get("tag", "") == "voice" and not item.get("selected", false): alternative = item
			if not check(not sample.is_empty() and not alternative.is_empty(), "Native voice page offers original soundsets and a separate sample control"): finish(); return
			var played: int = ui.voice_audio.played
			await press(ui.controls[int(sample.controlId)])
			if not check(await wait_until(func(): return ui.voice_audio.played > played, 20), "Original selected SSF line is decoded and starts in the native audio player"): finish(); return
			if not check(await wait_until(func(): return ui.voice_audio.player.get_playback_position() > 0.04, 3), "Actual Windows audio clock advances during the original voice line"): finish(); return
			voice_samples.append(ui.voice_audio.snapshot())
			played = ui.voice_audio.played; await press(ui.controls[int(sample.controlId)])
			if not check(await wait_until(func(): return ui.voice_audio.played > played, 20), "Repeated sample advances to the next original soundset entry"): finish(); return
			voice_samples.append(ui.voice_audio.snapshot())
			var previous_owner: int = ui.voice_audio.voice_owner
			var old_view: int = ui.view_id; ui.change(int(alternative.controlId), null, old_view)
			if not check(await wait_until(func(): return ui.view_id > old_view and not ui.waiting and ui.voice_audio.voice_owner != previous_owner and ui.voice_audio.player.stream == null), "Selecting a different soundset stops and releases the previous native voice"): finish(); return
			for item in ui.items:
				if item.type == "voice-sample": sample = item
			played = ui.voice_audio.played; await press(ui.controls[int(sample.controlId)])
			if not check(await wait_until(func(): return ui.voice_audio.played > played, 20), "New soundset samples restart at their first original line"): finish(); return
			voice_samples.append(ui.voice_audio.snapshot())
			check(voice_samples.all(func(row): return row.last.driver != "Dummy" and row.last.duration > 0), "Live voice evidence uses the native Windows output driver with positive decoded durations")
			await client.get_tree().process_frame; await RenderingServer.frame_post_draw
			client.get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://reports/" + str(message.review).replace("-review.png", "-voice.png")))
		if step == 13: check(ui.voice_audio.player.stream == null and ui.voice_audio.pending.is_empty(), "Leaving Voice releases playback and pending transfer buffers")
	if not await page(13): finish(); return
	for item in ui.items:
		if item.get("tag", "") == "firstName": ui.inputs[int(item.controlId)].text = first_name
		elif item.get("tag", "") == "lastName": ui.inputs[int(item.controlId)].text = last_name
		elif item.get("tag", "") == "biography": ui.inputs[int(item.controlId)].text = "Authored native creation test.\nOriginal game rules and resources."
	if not check(await page(14), "Name and biography survive the native Review navigation"): finish(); return
	if not check(ui.state.errors.is_empty() and ui.state.canFinish, "Shared validation accepts all required first-level choices before Play"): finish(); return
	await client.get_tree().process_frame; await RenderingServer.frame_post_draw
	client.get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://reports/" + str(message.review)))
	await press(ui.finish)
	if not check(await wait_until(func(): return client.generation >= 0 and client.pivots.has(client.controlled_id) and client.smoke_frame_complete, 65), "Server admits the newly created character and native animation moves its original model"): finish(); return
	check(not ui.wanted and not ui.panel.visible and ui.controls.is_empty(), "Admission retires the native creator and releases portrait widgets")
	var first: int = client.connection; client.send({"kind":"lobby-export"})
	if not check(await wait_until(func(): return not saved_key.is_empty()), "The admitted new character exports into the persistent owned vault"): finish(); return
	client.send({"kind":"lobby-disconnect","saveCharacter":true})
	if not check(await wait_until(func(): return client.connection > first and client.lobby.state.get("canJoin", false)), "Clean disconnect releases the first character connection"): finish(); return
	client.main_menu.choose("multiplayer")
	if not await wait_until(func(): return client.server_browser.view_id >= 0): finish(); return
	check(client.server_browser.password_edit.text.is_empty() and client.server_browser.key_edit.text.is_empty(), "Reconnect starts with empty transient login credentials")
	client.server_browser._tab("History")
	if not check(await wait_until(func(): return client.server_browser.state.tab == "History" and client.server_browser.entries.size() == 1), "Successful native admission is retained in the isolated History store"): finish(); return
	client.server_browser._tab("Direct")
	if not await wait_until(func(): return client.server_browser.state.tab == "Direct"): finish(); return
	await press(client.server_browser.connect_button)
	if not check(await wait_until(func():
		if not client.lobby.state.get("canSelect", false): return false
		if client.lobby.state.localAllowed and client.lobby.keys.has(saved_key): replay_key = saved_key; return true
		for row in client.lobby.state.choices:
			if row.source == "server" and row.label == first_name + " " + last_name: replay_key = str(row.key); return true
		return false), "Reconnect lists the persistent character created through native controls under its allowed vault policy"): finish(); return
	client.lobby._choose(client.lobby.keys.find(replay_key))
	if not check(await wait_until(func(): return client.lobby.state.get("preview") != null), "Saved native-created character has a valid server/local preview"): finish(); return
	client.lobby._play()
	check(await wait_until(func(): return client.generation >= 0 and client.pivots.has(client.controlled_id) and client.smoke_frame_complete, 65), "Saved native-created character is re-admitted, rendered and animated after reconnect")
	finish()
func finish() -> void:
	var passed := not checks.is_empty() and checks.all(func(row): return row.passed)
	client.send({"kind":"creator-tested","result":{"completed":passed,"checks":checks,"previewSamples":preview_samples,"previewAnimation":preview_animation,"voiceSamples":voice_samples,"savedKey":saved_key,"replayKey":replay_key,"joinGeometry":join_geometry,"lobby":{"phase":client.lobby.state.get("phase"),"busy":client.lobby.state.get("busy"),"canJoin":client.lobby.state.get("canJoin"),"canCreate":client.lobby.state.get("canCreate"),"error":client.lobby.state.get("error")}}})
