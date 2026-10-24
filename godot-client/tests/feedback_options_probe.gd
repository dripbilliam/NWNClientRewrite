extends "res://systems/inventory_probe.gd"
var phases: Array = []

func run(owner, message: Dictionary) -> void:
	client = owner
	scope = {"connection":client.connection,"areaId":client.area_id,"generation":client.generation,"transferId":client.world_scope.ticket}
	var options = client.options
	var original: Dictionary = options.feedback_values()
	var storage: String = options.preference_path
	var original_hash := FileAccess.get_sha256(storage) if FileAccess.file_exists(storage) else ""
	options.preference_path = str(message.screenshot).get_basename() + ".cfg"
	options.show(); options.move_to_front()
	check(await wait_until(func(): return client.feedback_ack == options.feedback_values(),10),"Actual current connection receives its initial native feedback preference")
	client.inventory.open()
	check(await wait_until(func(): return client.inventory.visible and client.inventory.view_id >= 0,12),"Options and actual inventory coexist during the feedback test")
	for mode in [[true,false],[true,true],[false,true]]:
		if not valid(): break
		options.floating_toggle.button_pressed = mode[0]
		options.totals_toggle.button_pressed = mode[1]
		client._send_feedback_preferences()
		check(await wait_until(func(): return client.feedback_ack == options.feedback_values(),10),"Live local acknowledgement applies floating=%s total=%s" % mode)
		client.floating.reset()
		var previous_rows: int = client.chat_ui.rows.size()
		client.command({"kind":"chat","channel":1,"text":"-native-feedback"})
		check(await wait_until(func(): return client.floating.entries.any(func(row): return row.label.get_parsed_text() == "GODOT_FEEDBACK_PROMPT"),15),"Real server-script overhead prompt remains visible with floating=%s" % mode[0])
		var texts: Array = client.floating.entries.map(func(row): return row.label.get_parsed_text())
		var numeric: Array = texts.filter(func(text): return str(text).is_valid_int())
		check(numeric == ["3"] if mode[0] else numeric.is_empty(),"Actual server damage numbers honor floating=%s total=%s" % mode)
		var rows: Array = client.chat_ui.rows.slice(previous_rows)
		check(rows.any(func(row): return row.get("category","") == "damage-feedback"),"Actual damage history remains present while floating=%s" % mode[0])
		phases.append({"values":options.feedback_values(),"floating":texts,"damageChat":rows.filter(func(row): return row.get("category","") == "damage-feedback").size()})
	var saved := ConfigFile.new(); var loaded := saved.load(options.preference_path)
	check(loaded == OK and saved.get_value("feedback","floating",true) == false and saved.get_value("feedback","total_damage",false) == true,"Both live native controls persist to the isolated preference file")
	if valid():
		var keyboard = client.keyboard; var focused: bool = keyboard.require_focus; keyboard.require_focus = false
		var before: Vector3 = client.pivots[client.controlled_id].global_position
		keyboard.keys[KEY_W] = true; await client.get_tree().create_timer(0.6).timeout
		keyboard.keys.erase(KEY_W); keyboard.clear(true); keyboard.require_focus = focused
		check(client.pivots[client.controlled_id].global_position.distance_to(before) > 0.05,"Real WASD remains active through simultaneous feedback Options and inventory")
		var camera = client.owner_scene.camera_controller; var yaw: float = camera.yaw
		var middle := InputEventMouseButton.new(); middle.button_index = MOUSE_BUTTON_MIDDLE; middle.pressed = true; camera._input(middle)
		var motion := InputEventMouseMotion.new(); motion.relative = Vector2(15,5); camera._input(motion); middle.pressed = false; camera._input(middle)
		check(camera.yaw != yaw and not camera.dragging,"Middle-mouse camera orbit remains available with the Options controls open")
		await client.get_tree().process_frame; await RenderingServer.frame_post_draw
		check(client.get_viewport().get_texture().get_image().save_png(str(message.screenshot)) == OK,"Actual native feedback Options frame is captured")
	options.preference_path = storage
	options.floating_feedback = original.floatingFeedback; options.damage_totals_only = original.damageTotalsOnly
	options.floating_toggle.set_pressed_no_signal(original.floatingFeedback); options.totals_toggle.set_pressed_no_signal(original.damageTotalsOnly)
	client._send_feedback_preferences()
	check(await wait_until(func(): return client.feedback_ack == original,10),"The original user feedback preference is restored after the local check")
	check((FileAccess.get_sha256(storage) if FileAccess.file_exists(storage) else "") == original_hash,"User preference file remains unchanged by the isolated live test")
	if valid(): client.command({"kind":"feedback-tested","result":{"completed":true,"checks":checks,"phases":phases,"userConfigUnchanged":checks.back().passed,"screenshot":message.screenshot}})
