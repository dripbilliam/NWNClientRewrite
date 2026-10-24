extends "res://systems/draggable_panel.gd"

const Text = preload("res://systems/server_text.gd")
var state: Dictionary = {}
var body: VBoxContainer
var portrait: TextureRect
var title_text: RichTextLabel

func setup(storage: String = "user://native-menu-layout.cfg") -> void:
	configure("Examine", "local-examine", Vector2(90, 90), storage)
	title_text = Text.label({}, 500)
	content.add_child(title_text)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(560, 400)
	content.add_child(scroll)
	var row := HBoxContainer.new()
	scroll.add_child(row)
	portrait = TextureRect.new()
	portrait.custom_minimum_size = Vector2(80, 125)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(portrait)
	body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(body)
	var close := Button.new()
	close.text = "Close"
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(hide)
	content.add_child(close)
	reset()

func reset() -> void:
	state.clear()
	portrait.texture = null
	portrait.hide()
	for child in body.get_children():
		body.remove_child(child)
		child.queue_free()
	hide()

func present(message: Dictionary) -> void:
	reset()
	if message.get("close", false):
		return
	state = message.duplicate(true)
	Text.set_text(title_text, message.get("name", {"text": "Examine"}))
	for key in ["condition", "reaction", "description"]:
		if message.has(key):
			body.add_child(Text.label(message[key], 440))
	for row in message.get("facts", []):
		body.add_child(Text.label({"text": str(row.name) + ":"}, 440))
		body.add_child(Text.label(row.rich, 440))
	for key in ["properties", "effects"]:
		var values: Array = message.get(key, [])
		if not values.is_empty():
			body.add_child(Text.label({"text": "Item properties" if key == "properties" else "Effects"}, 440))
			for value in values:
				body.add_child(Text.label(value.rich if key == "properties" else value, 440))
	for warning in message.get("warnings", []):
		body.add_child(Text.label({"text": str(warning)}, 440))
	show()
	move_to_front()

func set_portrait(message: Dictionary) -> bool:
	if not visible or state.is_empty() or int(message.get("revision", -1)) != int(state.get("revision", -2)) or int(message.get("targetId", -1)) != int(state.get("targetId", -2)):
		return false
	var url := str(message.get("image", ""))
	if not url.begins_with("data:image/png;base64,") or url.length() > 350000:
		return false
	var image := Image.new()
	if image.load_png_from_buffer(Marshalls.base64_to_raw(url.substr(22))) != OK or image.get_width() > 1024 or image.get_height() > 1024:
		return false
	portrait.texture = ImageTexture.create_from_image(image)
	portrait.show()
	return true
