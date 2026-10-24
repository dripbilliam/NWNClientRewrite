extends RefCounted
# Real owned-server messages only; synthetic stale frames test epoch rejection.
var client
var connection := -1
var running := true
var checks: Array = []
var icon_sample: Array = []
func stop() -> void: running = false
func valid() -> bool: return running and is_instance_valid(client) and client.connection == connection
func check(value: bool, name: String) -> void:
	checks.append({"name":name,"passed":value}); print("NATIVE_NUI_HANDOFF ", value, " ", name)
func wait_until(predicate: Callable, seconds: float = 15) -> bool:
	var until := Time.get_ticks_msec() + int(seconds * 1000)
	while valid() and Time.get_ticks_msec() < until:
		if predicate.call(): return true
		await client.get_tree().process_frame
	return false
func window_named(title: String):
	for window in client.nui.windows.values():
		if window.state.get("title") == title: return window
	return null
func element(window, tag: String):
	if not is_instance_valid(window): return null
	for node in window.nodes.values():
		if node.spec.get("tag") == tag: return node
	return null
func label(window, tag: String) -> String:
	var node = element(window, tag)
	return str(node.widget.text) if node != null and node.widget != null else ""
func click(node) -> void:
	if node == null: return
	var at: Vector2 = node.widget.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new(); motion.position = at; motion.global_position = at
	client.get_viewport().push_input(motion, true)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new(); event.button_index = MOUSE_BUTTON_LEFT; event.pressed = pressed; event.position = at; event.global_position = at
		client.get_viewport().push_input(event, true); await client.get_tree().process_frame
func run(owner, message: Dictionary) -> void:
	client = owner; connection = client.connection
	await client.get_tree().process_frame
	var retired: Dictionary = client.nui.retired_state()
	check(client.nui.windows.is_empty(), "Prior server windows are absent before opening new menus")
	check(client.nui.resources.is_empty() and client.nui.transfers.is_empty(), "Prior resource and partial transfer maps are empty")
	check(int(retired.windows) == 0 and int(retired.resources) == 0, "Retired native menu and resource weak owners are freed")
	var server: String = message.label
	client.command({"kind":"chat","channel":1,"text":"-native-transfer-nui"})
	check(await wait_until(func(): return window_named("Transfer NUI " + server) != null), "Real server creates the new native root menu")
	var root = window_named("Transfer NUI " + server)
	if root == null: finish(message, retired); return
	check(await wait_until(func(): return label(root,"caption") == "Opened by server " + server), "Open callback reaches the destination server")
	check(await wait_until(func(): return element(root,"edit") != null and element(root,"edit").widget.text == "Draft " + server), "New server canonical bindings replace previous drafts")
	check(await wait_until(func(): return client.nui.skin_ready(), 25), "Original skin and fonts load for the new connection")
	var icon_ready := await wait_until(func(): return element(root,"icon") != null and client.nui.resources.get(element(root,"icon").image_canvas.image_id) is Texture2D)
	if icon_ready and message.has("pixel"):
		var texture: Texture2D = client.nui.resources.get(element(root,"icon").image_canvas.image_id)
		var pixel: Color = texture.get_image().get_pixel(0,0)
		icon_sample = [roundi(pixel.r*255),roundi(pixel.g*255),roundi(pixel.b*255),roundi(pixel.a*255)]
		icon_ready = message.pixel.size() == 4
		for i in range(4): icon_ready = icon_ready and int(icon_sample[i]) == int(message.pixel[i])
	check(icon_ready, "Fixture icon resolves through this connection's resource owner with correct pixels" if message.has("pixel") else "Original spell icon loads through the new resource owner")
	var edit = element(root,"edit")
	if edit != null:
		edit.widget.grab_focus(); edit.widget.text = "Edited on " + server; edit.widget.text_changed.emit(edit.widget.text); edit.widget.release_focus()
	check(await wait_until(func(): return label(root,"echo") == "Edited on " + server), "Watched input round trips through this server's event script")
	await click(element(root,"child"))
	check(await wait_until(func(): return window_named("Transfer child " + server) != null), "Native click creates the resource-backed destination child")
	var child = window_named("Transfer child " + server)
	check(label(child,"resource") == "Resource belongs to server " + server, "Same JUI resref resolves this server's distinct module content")
	await click(element(child,"ack"))
	check(await wait_until(func(): return label(child,"caption") == "Acknowledged by server " + server), "Child action reaches the current destination")
	if message.has("retiredConnection"):
		check(root.window_id == int(message.retiredWindowId), "Native window handle is deliberately reused across servers")
		client.receive({"kind":"nui-remove","connection":int(message.retiredConnection),"windowId":root.window_id})
		check(client.nui.windows.get(root.window_id) == root, "Retired server presentation cannot remove a reused menu")
		client.send({"kind":"nui-input","connection":int(message.retiredConnection),"windowId":root.window_id,"operation":"close"})
		await client.get_tree().create_timer(0.3).timeout
		check(client.nui.windows.get(root.window_id) == root, "Retired native close is rejected without touching the new menu")
	check(is_instance_valid(child) and root.visible and child.visible and client.nui.windows.size() == 2, "Root and child remain open for the actual server transfer")
	await RenderingServer.frame_post_draw
	var saved: bool = client.get_viewport().get_texture().get_image().save_png(message.screenshot) == OK
	check(saved, "Rendered transfer-menu screenshot is saved")
	finish(message, retired)
func finish(message: Dictionary, retired: Dictionary) -> void:
	if not valid(): return
	var root = window_named("Transfer NUI " + str(message.label))
	client.command({"kind":"nui-handoff-tested","result":{"completed":true,"label":message.label,"checks":checks,"rootWindowId":root.window_id if root != null else -1,"retired":retired,"statistics":client.nui.statistics.duplicate(),"windows":client.nui.windows.size(),"screenshot":message.screenshot,"iconPixel":icon_sample,"download":client.sync_handoff_watch.snapshot(connection) if client.sync_handoff_watch != null else null}})
