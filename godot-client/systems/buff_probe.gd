extends RefCounted
var client
var connection := -1
var running := true
var checks: Array = []
var observations: Dictionary = {}
func stop() -> void: running = false
func valid() -> bool: return running and is_instance_valid(client) and client.connection == connection
func check(value: bool, name: String) -> void:
	checks.append({"name":name,"passed":value}); print("NATIVE_BUFF_CHECK ", value, " ", name)
func wait_until(predicate: Callable, seconds: float = 12) -> bool:
	var until := Time.get_ticks_msec() + int(seconds * 1000)
	while valid() and Time.get_ticks_msec() < until:
		if predicate.call(): return true
		await client.get_tree().process_frame
	return false
func click(point: Vector2) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new(); event.button_index = MOUSE_BUTTON_LEFT; event.pressed = pressed; event.position = point; event.global_position = point
		client.get_viewport().push_input(event, true); await client.get_tree().process_frame
func run(owner, message: Dictionary) -> void:
	client = owner; connection = client.connection
	var bar = client.buffs
	if message.get("retired", false): check(bar.retired_alive() == 0, "Previous connection status widgets and original icon textures are released")
	client.command({"kind":"chat","channel":1,"text":"-native-buffs-start"})
	check(await wait_until(func(): return bar.rows.has(1) and bar.rows.has(2)), "Actual native server effect icons create both status slots")
	if not bar.rows.has(1) or not bar.rows.has(2): finish(message); return
	check(await wait_until(func(): return bar.images.has(1) and bar.images.has(2) and not str(bar.rows[1].label).begins_with("Effect ") and not str(bar.rows[2].label).begins_with("Effect ")), "Original installed status textures and localized labels reach the native HUD")
	observations.original = {"first":bar.rows[1].duplicate(),"second":bar.rows[2].duplicate(),"sizes":[str(bar.images[1].get_size()) if bar.images.has(1) else "missing",str(bar.images[2].get_size()) if bar.images.has(2) else "missing"]}
	check(bar.buttons.size() == bar.rows.size() and not bar.rows[1].has("duration"), "Native status slots remain aggregate icons without invented durations or stacks")
	var at: Vector2 = bar.buttons[1].get_global_rect().get_center(); await click(at)
	check(bar.pinned and bar.tip.visible and bar.tip_text.text == bar.rows[1].label, "Actual GUI status click pins the server icon's localized tooltip")
	check(bar.blocks_pointer(at) and not bar.blocks_pointer(Vector2(4, 4)), "Native status input blocking follows only its visible icon area")
	await client.get_tree().process_frame; await RenderingServer.frame_post_draw
	check(client.get_viewport().get_texture().get_image().save_png(str(message.screenshot)) == OK, "Actual native status artwork and pinned tooltip captured for visual review")
	var controller = client.owner_scene.camera_controller; var yaw: float = controller.yaw
	var middle := InputEventMouseButton.new(); middle.button_index = MOUSE_BUTTON_MIDDLE; middle.pressed = true; middle.position = at; client.get_viewport().push_input(middle, true)
	var motion := InputEventMouseMotion.new(); motion.position = at; motion.relative = Vector2(3, 0); client.get_viewport().push_input(motion, true); middle.pressed = false; client.get_viewport().push_input(middle, true)
	check(controller.yaw != yaw and not controller.dragging, "Middle mouse camera rotation remains active over status icons")
	controller.orbit(Vector2(-3, 0))
	var start: Vector3 = client.pivots[client.controlled_id].global_position; var driver = client.keyboard; var required: bool = driver.require_focus; driver.require_focus = false
	for pressed in [true, false]:
		var key := InputEventKey.new(); key.keycode = KEY_W; key.physical_keycode = KEY_W; key.pressed = pressed; client.get_viewport().push_input(key, true)
		if pressed: await client.get_tree().create_timer(0.7).timeout
	driver.require_focus = required
	check(await wait_until(func(): return client.pivots[client.controlled_id].global_position.distance_to(start) > 0.1, 8), "Actual WASD remains live while a native status tooltip is pinned")
	check(await wait_until(func(): return not bar.rows.has(1) and bar.rows.has(2), 15), "Actual server expiry removes only the short status while the long one remains")
	check(not bar.tip.visible and not bar.images.has(1), "Server icon removal retires its native texture and pinned tooltip")
	await client.get_tree().process_frame; await RenderingServer.frame_post_draw
	observations.survivor = {"button":str(bar.buttons[2].get_global_rect()),"bar":str(bar.get_global_rect())}
	await click(bar.buttons[2].get_global_rect().get_center())
	check(bar.tip.visible and bar.pinned, "A surviving status tooltip can be pinned after another icon expires")
	check(not client.lobby.panel.visible, "The connection menu does not cover or intercept status icons")
	start = client.pivots[client.controlled_id].global_position
	var camera: Camera3D = client.owner_scene.camera; var world_input = client.owner_scene.world_input; var clicked := false
	for offset in [Vector3(1.5, 0, 0), Vector3(-1.5, 0, 0), Vector3(0, 0, 1.5), Vector3(0, 0, -1.5)]:
		var screen := camera.unproject_position(start + offset)
		if world_input.extra_pointer_block.call(screen) or client.owner_scene.native_hud.blocks_pointer(screen): continue
		var hit: Dictionary = client.owner_scene.registry.pick(camera, screen)
		if hit.is_empty() or hit.get("entity", {}).get("eligible", false): continue
		await click(screen); clicked = true; break
	check(clicked and await wait_until(func(): return client.pivots[client.controlled_id].global_position.distance_to(start) > 0.1, 8) and not bar.tip.visible, "Actual outside GUI click dismisses the status tooltip and moves on the server")
	var long_button: int = bar.buttons[2].get_instance_id(); var area: int = client.area_id; var generation: int = client.generation
	client.command({"kind":"chat","channel":1,"text":"-native-b"})
	check(await wait_until(func(): return client.area_id != area and client.generation > generation and client.smoke_frame_complete, 45), "A second actual area admits and animates with the status HUD live")
	check(bar.buttons.has(2) and bar.buttons[2].get_instance_id() == long_button and bar.images.has(2), "Status widget and original texture ownership survive the area replacement")
	if not valid(): return
	generation = client.generation; client.command({"kind":"chat","channel":1,"text":"-native-a"})
	check(await wait_until(func(): return client.area_id == area and client.generation > generation and client.smoke_frame_complete, 45), "The status HUD completes the actual A–B–A lifecycle")
	check(bar.buttons.has(2) and bar.buttons[2].get_instance_id() == long_button, "Repeated world replacement preserves the same connection-owned status button")
	finish(message)
func finish(message: Dictionary) -> void:
	if not valid(): return
	client.command({"kind":"status-tested","result":{"completed":true,"checks":checks,"observations":observations,"actorId":client.buffs.actor_id,"rows":client.buffs.rows,"screenshot":message.screenshot}})
