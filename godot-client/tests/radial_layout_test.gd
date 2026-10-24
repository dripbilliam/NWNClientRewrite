extends SceneTree

var output := ""

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):
			output = arg.substr(9)
	if output.is_empty() or FileAccess.file_exists(output):
		quit(2)
		return
	var radial := preload("res://systems/server_radial.gd").new()
	root.add_child(radial)
	radial.open_at(Vector2(700, 400), 7, Vector3.ZERO)
	var entries: Array = []
	for slot in 8:
		entries.append({"slot": slot, "label": "A very long original action caption %s" % slot, "uses": 123})
	radial.receive({"kind": "action-menu", "requestId": radial.request_id, "menuId": 1, "title": "Authored icon sizing", "depth": 0, "entries": entries})
	for frame in 8:
		await process_frame
	var image := Image.create(32, 128, false, Image.FORMAT_RGBA8)
	image.fill(Color.GREEN)
	var png := "data:image/png;base64," + Marshalls.raw_to_base64(image.save_png_to_buffer())
	for slot in 8:
		radial.receive({"kind": "action-icon", "requestId": radial.request_id, "menuId": 1, "slot": slot, "image": png})
	var frames := 0
	var maximum_button := 0.0
	while frames < 90:
		await process_frame
		frames += 1
		for button in radial.buttons.values():
			maximum_button = maxf(maximum_button, button.size.y)
		if maximum_button > 1000:
			break
	var queue_peak := Performance.get_monitor(Performance.MEMORY_MESSAGE_BUFFER_MAX)
	var passed := maximum_button == 72 and queue_peak < 1048576
	for slot in 8:
		passed = passed and radial.icons[slot].texture != null and radial.counts[slot].text == "123" and radial.buttons[slot].size == Vector2(88, 72)
	var report := {"scope": "Authored native radial delayed-icon and long-caption layout stability over actual GUI frames; separate visible use counters", "passed": passed, "frames": frames, "queue_peak_bytes": queue_peak, "maximum_button_height": maximum_button, "stage_size": [radial.stage.size.x, radial.stage.size.y]}
	var file := FileAccess.open(output, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	radial.queue_free()
	await process_frame
	print(JSON.stringify(report))
	quit(0 if passed else 1)
