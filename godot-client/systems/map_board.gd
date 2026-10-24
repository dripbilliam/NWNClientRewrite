extends Control
signal pin_selected(rich: Dictionary)
const Images = preload("res://systems/runtime_image.gd")
var columns := 0
var rows := 0
var cells: Array = []
var explored: Array = []
var pins: Array = []
var controls: Dictionary = {}
var art: Dictionary = {}
var zoom := 16
var point: Array = []
var heading := 0.0
var hovered := -1
var pressed_pin := -1

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(queue_redraw)
	mouse_exited.connect(func(): hovered = -1; pressed_pin = -1; queue_redraw())

func reset() -> void:
	columns = 0; rows = 0; cells.clear(); explored.clear(); pins.clear(); controls.clear(); art.clear(); point.clear(); hovered = -1; pressed_pin = -1; tooltip_text = ""; queue_redraw()

func configure(message: Dictionary) -> void:
	reset(); columns = int(message.width); rows = int(message.height); cells = message.cells.duplicate(); controls = message.controls.duplicate(); zoom = 16; resize_map()

func resize_map() -> void:
	custom_minimum_size = Vector2(columns * zoom, rows * zoom)
	queue_redraw()

func origin() -> Vector2:
	return ((size - Vector2(columns * zoom, rows * zoom)) / 2).max(Vector2.ZERO)

func center(value: Array) -> Vector2:
	return origin() + Vector2(columns * zoom / 2.0 + float(value[0]) * 100 * zoom / 16.0, rows * zoom / 2.0 - float(value[1]) * 100 * zoom / 16.0)

func receive(message: Dictionary) -> void:
	match message.kind:
		"map-art":
			var skin: Dictionary = message.skin
			var texture := Images.png(str(skin.url), 4096, 900000)
			if texture != null: art[int(message.index)] = {"texture": texture, "min": skin.min, "max": skin.max}
		"map-state": explored = message.explored.duplicate(); pins = message.pins.duplicate(true); hovered = -1; pressed_pin = -1
		"map-pose": point = message.point.duplicate(); heading = float(message.heading)
	queue_redraw()

func rect_for(skin: Dictionary, at: Vector2, scale: float) -> Rect2:
	return Rect2(at + Vector2(float(skin.min[0]), -float(skin.max[1])) * 100 * scale, Vector2(float(skin.max[0]) - float(skin.min[0]), float(skin.max[1]) - float(skin.min[1])) * 100 * scale)

func picture(index: int, at: Vector2) -> void:
	if art.has(index): draw_texture_rect(art[index].texture, rect_for(art[index], at, zoom / 16.0), false)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.015, 0.018, 0.02))
	if columns < 1: return
	var offset := origin()
	var clip := Rect2(-position, get_parent().size) if get_parent() is ScrollContainer else Rect2(Vector2.ZERO, size)
	for index in cells.size():
		if index >= explored.size() or not explored[index]: continue
		var tile_center := offset + Vector2((index % columns + 0.5) * zoom, (rows - index / columns - 0.5) * zoom)
		if clip.grow(zoom).has_point(tile_center): picture(int(cells[index]), tile_center)
	for index in pins.size():
		if not pins[index].visible or pins[index].point == null: continue
		var key := "down" if pressed_pin == index else ("hilite" if hovered == index else "pin")
		picture(int(controls.get(key, -1)), center(pins[index].point))
	if not point.is_empty() and art.has(int(controls.get("player", -1))):
		var skin: Dictionary = art[int(controls.player)]
		draw_set_transform(center(point), deg_to_rad(-heading), Vector2.ONE * zoom / 16.0)
		draw_texture_rect(skin.texture, rect_for(skin, Vector2.ZERO, 1), false)
		draw_set_transform(Vector2.ZERO)

func pin_at(at: Vector2) -> int:
	for index in range(pins.size() - 1, -1, -1):
		var pin: Dictionary = pins[index]
		if pin.visible and pin.point != null and Rect2(center(pin.point) - Vector2.ONE * 8, Vector2.ONE * 16).has_point(at): return index
	return -1

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		hovered = pin_at(event.position); tooltip_text = str(pins[hovered].rich.text) if hovered >= 0 else ""; queue_redraw()
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var hit := pin_at(event.position)
		if event.pressed: pressed_pin = hit
		else:
			if hit >= 0 and hit == pressed_pin: pin_selected.emit(pins[hit].rich)
			pressed_pin = -1
		queue_redraw(); accept_event()
