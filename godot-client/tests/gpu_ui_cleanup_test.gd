extends SceneTree
var mode := "none"
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--mode="): mode = arg.substr(7)
	call_deferred("run")
func run() -> void:
	root.size = Vector2i(320, 240); root.title = "Authored native UI cleanup diagnostic"
	var label := Label.new(); label.text = "Authored UI cleanup: " + mode; root.add_child(label)
	if mode == "cursor": await cursor_test()
	elif mode == "images": await image_test(label)
	await process_frame; await process_frame
	label.free(); await process_frame; quit()
func cursor_test() -> void:
	for index in 8:
		var image := Image.create(32, 32, false, Image.FORMAT_RGBA8); image.fill(Color(index / 8.0, 1, 0))
		var texture := ImageTexture.create_from_image(image)
		Input.set_custom_mouse_cursor(texture); await process_frame
		Input.set_custom_mouse_cursor(null)
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
func image_test(label: Label) -> void:
	for index in 8:
		var image := Image.create(32, 32, false, Image.FORMAT_RGBA8); image.fill(Color(index / 8.0, 1, 0))
		var texture := ImageTexture.create_from_image(image)
		var picture := TextureRect.new(); picture.texture = texture; label.add_child(picture)
		await process_frame; picture.free()
