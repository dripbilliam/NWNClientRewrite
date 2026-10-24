extends RefCounted
var client
var observations: Array = []
var checks: Array = []
var screenshot := ""
var captured := false
var capturing := false
var original_hash := ""
var cancel_test := false
var cancelling := false
func check(v: bool,label: String) -> void: checks.append({"passed":v,"name":label})
func start(owner,message: Dictionary) -> void:
	client = owner; screenshot = str(message.screenshot)
	cancel_test = bool(message.get("cancel",false))
	var path: String = client.options.preference_path
	original_hash = FileAccess.get_sha256(path) if FileAccess.file_exists(path) else ""
	client.lobby.resource_progress.connect(progress)
func progress(value: Dictionary) -> void:
	if observations.size() < 128: observations.append(value.duplicate(true))
	if cancel_test:
		if not cancelling and value.phase == "server-content" and value.completed > 0 and value.completed < value.total:
			cancelling = true; cancel_download()
		return
	if not captured and not capturing and value.phase == "server-content" and value.completed > 0 and value.completed < value.total:
		capturing = true; capture()
func capture() -> void:
	await client.get_tree().process_frame; await RenderingServer.frame_post_draw
	if client.lobby.download_bar.visible: captured = client.get_viewport().get_texture().get_image().save_png(screenshot) == OK
	capturing = false
func cancel_download() -> void:
	check(client.lobby.cancel_button.visible and not client.lobby.cancel_button.disabled,"Actual download exposes an enabled native Cancel button")
	check(observations.all(func(v): return not v.canPlay),"The cancelled download never admits character selection")
	await capture(); check(captured,"The actual in-progress download is captured before cancellation")
	var connection: int = client.connection; var point: Vector2 = client.lobby.cancel_button.get_global_rect().get_center()
	for pressed in [true,false]:
		var move := InputEventMouseMotion.new(); move.position = point; client.get_viewport().push_input(move,true)
		var event := InputEventMouseButton.new(); event.button_index = MOUSE_BUTTON_LEFT; event.position = point; event.global_position = point; event.pressed = pressed
		client.get_viewport().push_input(event,true); await client.get_tree().process_frame
	var deadline := Time.get_ticks_msec()+10000
	while Time.get_ticks_msec() < deadline and not (client.connection > connection and client.lobby.state.get("canJoin",false)):
		await client.get_tree().process_frame
	check(client.connection > connection and client.lobby.state.get("canJoin",false),"Native pointer cancellation ends the real download session and permits retry")
	check(not client.lobby.download_bar.visible,"Cancelled progress controls retire")
	check(client.generation < 0 and client.controlled_id < 0,"Cancellation never opens a game world or controlled character")
	var count := observations.size(); await client.get_tree().create_timer(0.3).timeout
	check(observations.size() == count,"Retired download cannot publish late native progress")
	if client.lobby.resource_progress.is_connected(progress): client.lobby.resource_progress.disconnect(progress)
	var path: String = client.options.preference_path
	check((FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "") == original_hash,"Cancellation leaves user preferences unchanged")
	client.send({"kind":"nwsync-cancel-tested","result":{"completed":true,"checks":checks,"progress":observations,"downloadScreenshot":screenshot,"userConfigUnchanged":checks.back().passed}})
func finish(message: Dictionary) -> void:
	check(not observations.is_empty(),"Native lobby receives actual NWSync progress before admission")
	check(observations.all(func(v): return not v.canPlay and v.canCancel),"Character admission stays gated and cancellation remains available while checking/downloading")
	check(observations.any(func(v): return v.phase == "server-content" and v.completed == v.total and v.total == 13),"Native resource counter reaches all thirteen authored resources")
	var cold: bool = observations.any(func(v): return v.downloadedBytes > 0)
	check(captured if cold else true,"Actual cold-download progress is rendered and captured")
	check(not client.lobby.download_bar.visible,"Download controls retire after actual world admission")
	var before := observations.size(); var label: String = client.lobby.message.text
	client.receive({"kind":"lobby","connection":client.connection-1,"state":{"phase":"resources","resourceProgress":{"phase":"server-content","completed":1,"total":99,"downloadedBytes":999}}})
	check(observations.size() == before and client.lobby.message.text == label,"Retired connection progress cannot reopen or overwrite the native lobby")
	var bytes := Marshalls.base64_to_raw(str(message.icon)); var image := Image.new(); var error := image.load_tga_from_buffer(bytes)
	check(error == OK and image.get_size() == Vector2i(16,16),"Downloaded NWSync texture decodes in native Godot")
	if error == OK:
		var pixel := image.get_pixel(0,0)
		check(absf(pixel.r-240.0/255) < 0.001 and absf(pixel.g-170.0/255) < 0.001 and absf(pixel.b-20.0/255) < 0.001,"The mounted downloaded texture retains its authored pixel values")
	var panel := PanelContainer.new(); panel.position = Vector2(640,140)
	var column := VBoxContainer.new(); panel.add_child(column)
	var text := Label.new(); text.text = "NWSync downloaded resource"; column.add_child(text)
	var icon := TextureRect.new(); icon.custom_minimum_size = Vector2(96,96); icon.texture = ImageTexture.create_from_image(image) if error == OK else null; column.add_child(icon)
	client.overlay.add_child(panel)
	await client.get_tree().process_frame; await RenderingServer.frame_post_draw
	check(client.get_viewport().get_texture().get_image().save_png(str(message.screenshot)) == OK,"Actual downloaded native texture and moving world are captured")
	panel.free(); await client.get_tree().process_frame
	var path: String = client.options.preference_path
	check((FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "") == original_hash,"NWSync admission leaves native user preferences unchanged")
	if client.lobby.resource_progress.is_connected(progress): client.lobby.resource_progress.disconnect(progress)
	client.command({"kind":"nwsync-tested","result":{"completed":true,"checks":checks,"progress":observations,"cold":cold,"downloadScreenshot":screenshot if captured else null,"screenshot":message.screenshot,"userConfigUnchanged":checks.back().passed}})
