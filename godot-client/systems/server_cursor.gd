extends RefCounted

signal request(message: Dictionary)
const Images = preload("res://systems/runtime_image.gd")
var textures: Dictionary = {}
var pending: Dictionary = {}
var desired := -1

func reset(clear_cache: bool = false) -> void:
	desired = -1
	pending.clear()
	if clear_cache:
		textures.clear()
	if DisplayServer.get_name() != "headless":
		Input.set_custom_mouse_cursor(null)
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)

func select(id: int, pressed: bool = false) -> void:
	if id < 1 or id > 292:
		reset()
		return
	if pressed and id % 2 == 1 and (id <= 58 or id >= 91):
		id += 1
	if id == desired:
		return
	desired = id
	if textures.has(id):
		apply(id)
	elif not pending.has(id):
		pending[id] = true
		request.emit({"kind": "cursor-request", "cursorId": id})

func receive(message: Dictionary) -> void:
	var id := int(message.cursorId)
	pending.erase(id)
	var texture := Images.png(str(message.get("image", "")), 128, 150000)
	if texture == null:
		return
	textures[id] = texture
	if desired == id:
		apply(id)

func apply(id: int) -> void:
	if DisplayServer.get_name() != "headless":
		Input.set_custom_mouse_cursor(textures[id], Input.CURSOR_ARROW, Vector2.ZERO)
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)
