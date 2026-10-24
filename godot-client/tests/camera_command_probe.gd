extends "res://tests/camera_mode_probe.gd"
var phases: Array = []
func state() -> Dictionary: return client.camera_session.state
func sample() -> Dictionary:
	var s := state()
	return {"mode":s.mode,"yaw":s.yaw,"pitch":s.pitch,"distance":s.distance,"height":s.height,"locks":s.locks.duplicate(),"limits":s.rawLimits.duplicate(),"effectiveLimits":s.effectiveLimits.duplicate(),"savedCamera":s.savedCamera.duplicate() if s.savedCamera != null else null,"flags":s.flags,"target":client.camera_target_id,"scriptLocation":s.scriptLocation.duplicate() if s.scriptLocation != null else null}
func near(a: float,b: float) -> bool: return absf(a-b) < 0.001
func phase(name: String,kind: String) -> bool:
	var before: int = client.camera_events.size()
	var rows: int = client.chat_ui.rows.size()
	client.command({"kind":"chat","channel":1,"text":"-native-camera-"+name})
	var received := await wait_until(func(): return client.camera_events.slice(before).any(func(row): return row.kind == kind) and client.chat_ui.rows.slice(rows).any(func(row): return str(row.get("rich",{}).get("text",row.get("text",""))) == "GODOT_CAMERA_"+name.to_upper()),12)
	check(received,"Actual native server acknowledges camera "+name)
	if received: await client.get_tree().create_timer(0.08).timeout
	phases.append({"name":name,"received":received,"state":sample(),"events":client.camera_events.slice(before)})
	return received
func input_gesture() -> void:
	var camera = client.owner_scene.camera_controller
	camera.orbit(Vector2(90,-50)); camera.zoom(1.0/1.12)
	await client.get_tree().create_timer(0.1).timeout
func run(owner,message: Dictionary) -> void:
	client = owner; connection = client.connection
	var original_pose: Dictionary = pose(); var original_mode: int = client.options.camera_mode
	var original_path: String = client.options.preference_path
	var original_hash := FileAccess.get_sha256(original_path) if FileAccess.file_exists(original_path) else ""
	client.options.show(); client.inventory.open()
	check(await wait_until(func(): return client.inventory.visible and client.inventory.view_id >= 0),"Inventory and Options remain open for scripted camera checks")
	if await phase("setup","camera-location"):
		check(state().mode == 1 and client.options.camera_choice.get_selected_id() == 1,"Real SetCameraMode changes native mode and displayed selection")
		check(near(state().yaw,45) and near(state().distance,12) and near(state().pitch,55),"Real snap applies direction offset, distance and pitch")
		check(state().height == 3 and state().effectiveLimits == {"minPitch":10.0,"maxPitch":80.0,"minDist":2.0,"maxDist":30.0},"Actual height/limits/unlock messages initialize follow bounds")
	await phase("store","camera-store"); var stored: Variant = state().savedCamera.duplicate() if state().savedCamera != null else null
	await phase("snap","camera-location")
	check(near(state().yaw,160) and near(state().distance,8) and near(state().pitch,35),"A second actual snap replaces the displayed pose")
	await phase("restore","camera-restore")
	check(stored != null and state().savedCamera == null and near(state().yaw,stored.yaw) and near(state().distance,stored.distance) and near(state().pitch,stored.pitch),"Actual restore consumes the stored camera and restores all axes")
	await phase("lock","camera-lock"); var locked := sample(); await input_gesture()
	check(state().yaw == locked.yaw and state().pitch == locked.pitch and state().distance == locked.distance,"All actual server axis locks constrain native mouse/wheel input")
	await phase("unlock","camera-lock"); await phase("flags","camera-flags"); var blocked := sample(); await input_gesture()
	check(state().flags == 112 and state().yaw == blocked.yaw and state().pitch == blocked.pitch and state().distance == blocked.distance,"Real flag bits block new yaw/pitch/zoom input")
	await phase("clear","camera-flags"); await input_gesture()
	check(state().yaw != blocked.yaw and state().pitch != blocked.pitch and state().distance != blocked.distance,"Clearing actual input flags restores camera gestures through open menus")
	await phase("transition","camera-location")
	check(await wait_until(func(): return state().scriptLocation != null and state().scriptLocation.rate == 0,10),"Actual synchronized script transition reaches completion")
	check(near(state().yaw,120) and near(state().distance,6) and near(state().pitch,65),"Actual transition reaches all original endpoints")
	var controlled: int = client.controlled_id
	await phase("attach","camera-attach")
	var attached: int = client.camera_target_id
	check(attached >= 0 and attached != controlled and client.controlled_id == controlled,"Actual remote attachment changes camera target without changing player control")
	check(attached >= 0 and client.owner_scene.camera_controller.follow_valid(client.pivots[attached].global_position),"Native view follows the rendered server attachment")
	await phase("self","camera-attach")
	check(client.camera_target_id == -1 and client.controlled_id == controlled,"Actual self attachment restores controlled follow")
	await phase("height","camera-height")
	check(state().heightOverride == null and state().height == state().defaultHeight,"Actual zero-height message restores appearance-derived follow height")
	await phase("store","camera-store"); var stored_across: Dictionary = state().savedCamera.duplicate(); var limits: Dictionary = state().rawLimits.duplicate()
	for destination in ["-native-b","-native-a"]:
		var old_area: int = client.area_id; var old_generation: int = client.generation
		var old_camera: WeakRef = weakref(client.owner_scene.camera_controller)
		client.command({"kind":"chat","channel":1,"text":destination})
		var arrived := await wait_until(func(): return client.world_scope.admitted and client.area_id != old_area and client.generation > old_generation and client.following and client.smoke_frame_complete,30)
		check(arrived,"Actual scripted-camera session survives area transition "+destination)
		if not arrived: break
		check(state().savedCamera == stored_across and state().rawLimits == limits,"Stored view and server limit state survive native area replacement")
		check(old_camera.get_ref() == null,"Old area's camera owner releases while connection camera state persists")
		transitions.append({"generation":client.generation,"areaId":client.area_id,"saved":state().savedCamera.duplicate(),"limits":state().rawLimits.duplicate()})
	await phase("restore","camera-restore")
	check(state().savedCamera == null and near(state().yaw,stored_across.yaw),"Stored server view remains usable after both area replacements")
	await phase("reset","camera-mode")
	client.options.show(); client.inventory.open(); await client.get_tree().process_frame; await RenderingServer.frame_post_draw
	check(client.get_viewport().get_texture().get_image().save_png(str(message.screenshot)) == OK,"Actual native scripted camera frame is captured")
	client.owner_scene.camera_controller.enable_follow(original_mode,client.pivots[client.controlled_id].global_position,float(client.camera_heights.get(client.controlled_id,1)),original_pose)
	client.camera_session = client.owner_scene.camera_controller.follow_state; client.server_camera_mode = -1; client.options.show_camera_mode(original_mode)
	check((FileAccess.get_sha256(original_path) if FileAccess.file_exists(original_path) else "") == original_hash,"Server camera commands leave the user's preference file unchanged")
	if valid(): client.command({"kind":"camera-command-tested","result":{"completed":true,"checks":checks,"phases":phases,"transitions":transitions,"userConfigUnchanged":checks.back().passed,"screenshot":message.screenshot}})
