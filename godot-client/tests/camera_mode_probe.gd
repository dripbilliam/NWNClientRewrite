extends RefCounted
var client
var connection := -1
var running := true
var checks: Array = []
var modes: Array = []
var transitions: Array = []
func stop() -> void: running = false
func valid() -> bool: return running and is_instance_valid(client) and client.connection == connection
func check(value: bool,label: String) -> void: checks.append({"passed":value,"name":label})
func wait_until(predicate: Callable,seconds: float = 15) -> bool:
	var until := Time.get_ticks_msec()+int(seconds*1000)
	while valid() and Time.get_ticks_msec() < until:
		if predicate.call(): return true
		await client.get_tree().process_frame
	return false
func camera_key(code: int) -> void:
	for pressed in [true,false]:
		var event := InputEventKey.new(); event.keycode = code; event.physical_keycode = code; event.pressed = pressed
		client.get_viewport().push_input(event,true); await client.get_tree().process_frame
func select_mode(mode: int) -> bool:
	var choice: OptionButton = client.options.camera_choice
	await client.get_tree().process_frame; await client.get_tree().process_frame
	for pressed in [true,false]:
		var event := InputEventMouseButton.new(); event.button_index = MOUSE_BUTTON_LEFT; event.pressed = pressed; event.position = choice.get_global_rect().get_center(); event.global_position = event.position
		client.get_viewport().push_input(event,true); await client.get_tree().process_frame
	var popup: PopupMenu = choice.get_popup()
	if not popup.visible: return false
	for i in 5:
		if popup.get_focused_item() == choice.get_item_index(mode): break
		await camera_key(KEY_DOWN)
	await camera_key(KEY_ENTER)
	return not popup.visible and choice.get_selected_id() == mode
func pose() -> Dictionary: return client.owner_scene.camera_controller.remembered_pose()
func run(owner,message: Dictionary) -> void:
	client = owner; connection = client.connection
	var options = client.options
	var original_mode: int = options.camera_mode
	var original_pose: Dictionary = pose()
	var original_path: String = options.preference_path
	var original_hash := FileAccess.get_sha256(original_path) if FileAccess.file_exists(original_path) else ""
	options.preference_path = str(message.screenshot).get_basename()+".cfg"
	options.show(); options.move_to_front(); client.inventory.open()
	check(await wait_until(func(): return client.inventory.visible and client.inventory.view_id >= 0),"Actual inventory and camera Options coexist")
	for mode in [1,0,2]:
		if not valid(): break
		var chosen := await select_mode(mode)
		var controller = client.owner_scene.camera_controller
		var actor: Dictionary = client.motion.objects[client.controlled_id]
		var facing := rad_to_deg(atan2(-actor.orientation.x,actor.orientation.y))
		var before: Dictionary = pose()
		check(chosen and int(controller.follow_state.state.mode) == mode,"Actual popup selection applies and displays camera mode %s" % mode)
		await client.get_tree().create_timer(0.65).timeout
		var after: Dictionary = pose()
		var prior_error := absf(controller.follow_state.angle(facing-float(before.yaw)))
		var next_error := absf(controller.follow_state.angle(facing-float(after.yaw)))
		check(after.yaw == before.yaw if mode == 1 else next_error <= prior_error+0.0001,"Live mode %s retains its original top-down/chase steering policy" % mode)
		check(controller.follow_valid(client.pivots[client.controlled_id].global_position),"Mode %s points at the actual controlled follow focus" % mode)
		await RenderingServer.frame_post_draw
		var path := str(message.screenshot).get_basename()+"-mode-%s.png" % mode
		check(client.get_viewport().get_texture().get_image().save_png(path) == OK,"Actual mode %s frame is captured" % mode)
		modes.append({"requested":mode,"selected":options.camera_choice.get_selected_id(),"before":before,"after":after,"facing":facing,"screenshot":path})
	if valid():
		var controller = client.owner_scene.camera_controller
		var yaw: float = controller.follow_state.state.yaw
		var middle := InputEventMouseButton.new(); middle.button_index = MOUSE_BUTTON_MIDDLE; middle.pressed = true; controller._input(middle)
		var motion := InputEventMouseMotion.new(); motion.relative = Vector2(20,5); controller._input(motion); middle.pressed = false; controller._input(middle)
		await client.get_tree().create_timer(0.08).timeout
		check(controller.follow_state.state.yaw != yaw and controller.follow_state.state.manualLatch == 1,"Middle drag uses native mouse impulses and latches chase steering with menus open")
		var keyboard = client.keyboard; var required: bool = keyboard.require_focus; keyboard.require_focus = false
		var before: Vector3 = client.pivots[client.controlled_id].global_position
		keyboard.keys[KEY_W] = true; await client.get_tree().create_timer(0.6).timeout
		keyboard.keys.erase(KEY_W); keyboard.clear(true); keyboard.require_focus = required
		check(client.pivots[client.controlled_id].global_position.distance_to(before) > 0.05,"Actual WASD remains active through camera Options and inventory")
		await select_mode(1); controller.orbit(Vector2(-13,4)); controller.zoom(1.0/1.12)
		await client.get_tree().create_timer(0.1).timeout
		var remembered: Dictionary = pose()
		for destination in ["-native-b","-native-a"]:
			var old_area: int = client.area_id; var old_generation: int = client.generation
			var old_controller: WeakRef = weakref(client.owner_scene.camera_controller)
			var old_render: Dictionary = {"kind":"particle-frame","connection":connection,"areaId":old_area,"generation":old_generation,"transferId":client.world_scope.ticket,"epoch":client.particles.epoch,"sequence":987654,"delta":0.0,"camera":[1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1],"poses":[]}
			client.command({"kind":"chat","channel":1,"text":destination})
			var arrived := await wait_until(func(): return client.world_scope.admitted and client.area_id != old_area and client.generation > old_generation and client.following and client.smoke_frame_complete,30)
			check(arrived,"Native camera remains playable after actual server transition "+destination)
			if not arrived: break
			# Retain this real epoch through an actual transition, then deliver
			# its renderer work late to exercise retirement deterministically.
			client.send(old_render)
			check(old_controller.get_ref() == null,"Retired area's camera frame owner is released")
			var current: Dictionary = pose()
			check(current == remembered and options.camera_choice.get_selected_id() == 1,"Top-down mode and manual yaw/pitch/distance survive area replacement")
			transitions.append({"areaId":client.area_id,"generation":client.generation,"pose":current,"expected":remembered})
	var saved := ConfigFile.new(); var loaded := saved.load(options.preference_path)
	check(loaded == OK and saved.get_value("camera","mode",-1) == 1,"The selected camera mode persists to the isolated native preference file")
	options.preference_path = original_path; options.camera_mode = original_mode; options.show_camera_mode(original_mode)
	if valid() and client.following:
		client.owner_scene.camera_controller.enable_follow(original_mode,client.pivots[client.controlled_id].global_position,float(client.camera_heights.get(client.controlled_id,1)),original_pose)
	check((FileAccess.get_sha256(original_path) if FileAccess.file_exists(original_path) else "") == original_hash,"The live camera test leaves the user's preference file unchanged")
	if valid(): client.command({"kind":"camera-tested","result":{"completed":true,"checks":checks,"modes":modes,"transitions":transitions,"userConfigUnchanged":checks.back().passed}})
