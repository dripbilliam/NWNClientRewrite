extends Control
signal pin_selected(rich: Dictionary)
signal pin_action(pin: Dictionary)
signal panned(relative: Vector2)
signal note_dropped(point: Vector2,data: Dictionary)
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
var native_view:=false
var tile_banks: Dictionary={}
var drag_source: Callable
var moved:=false
var panning:=false
var last_drag: Dictionary={}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(queue_redraw)
	mouse_exited.connect(func(): hovered = -1; pressed_pin = -1; queue_redraw())

func reset() -> void:
	columns = 0; rows = 0; cells.clear(); explored.clear(); pins.clear(); controls.clear(); art.clear(); tile_banks.clear(); point.clear(); hovered = -1; pressed_pin = -1; tooltip_text = ""; moved=false; panning=false; queue_redraw()

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

func picture(index: int, at: Vector2, tile: bool=false) -> void:
	var bank: Dictionary=tile_banks.get(zoom,{}) if native_view and tile else art
	if not bank.has(index): return
	var scale_value:=1.0 if native_view else zoom/16.0
	draw_texture_rect(bank[index].texture,rect_for(bank[index],at,scale_value),false,Color(1,1,1,0.8 if native_view and tile else 1.0))

func _draw() -> void:
	if not native_view: draw_rect(Rect2(Vector2.ZERO, size), Color(0.015, 0.018, 0.02))
	if columns < 1: return
	var offset := origin()
	var clip := Rect2(-position, get_parent().size) if get_parent() is ScrollContainer else Rect2(Vector2.ZERO, size)
	for index in cells.size():
		if index >= explored.size() or int(explored[index])!=1: continue
		var tile_center := offset + Vector2((index % columns + 0.5) * zoom, (rows - index / columns - 0.5) * zoom)
		if clip.grow(zoom).has_point(tile_center): picture(int(cells[index]),tile_center,true)
	for index in pins.size():
		if not pins[index].visible or pins[index].point == null: continue
		var key := "down" if pressed_pin == index else ("hilite" if hovered == index else "pin")
		picture(int(controls.get(key, -1)), center(pins[index].point))
	if not point.is_empty() and art.has(int(controls.get("player", -1))):
		var skin: Dictionary = art[int(controls.player)]
		draw_set_transform(center(point), deg_to_rad(-heading), Vector2.ONE if native_view else Vector2.ONE * zoom / 16.0)
		draw_texture_rect(skin.texture, rect_for(skin, Vector2.ZERO, 1), false)
		draw_set_transform(Vector2.ZERO)

func pin_at(at: Vector2) -> int:
	for index in range(pins.size() - 1, -1, -1):
		var pin: Dictionary = pins[index]
		var rect:=Rect2(center(pin.point)-Vector2.ONE*8,Vector2.ONE*16) if pin.point!=null else Rect2()
		if native_view and art.has(int(controls.get("pin",-1))) and pin.point!=null: rect=rect_for(art[int(controls.pin)],center(pin.point),1.0)
		if pin.visible and pin.point != null and rect.has_point(at): return index
	return -1

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		hovered = pin_at(event.position); tooltip_text = str(pins[hovered].rich.text) if hovered >= 0 else ""; queue_redraw()
		if native_view and panning and event.button_mask&MOUSE_BUTTON_MASK_LEFT: moved=true; panned.emit(event.relative); accept_event()
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var hit := pin_at(event.position)
		if event.pressed: pressed_pin = hit; moved=false; panning=hit<0
		else:
			if hit >= 0 and hit == pressed_pin and not moved: pin_selected.emit(pins[hit].rich); pin_action.emit(pins[hit])
			pressed_pin = -1
			panning=false
		queue_redraw(); accept_event()
func tile_at_point(at: Vector2) -> int:
	var local:=at-origin(); var x:=floori(local.x/zoom); var y:=rows-1-floori(local.y/zoom)
	return y*columns+x if x>=0 and x<columns and y>=0 and y<rows else -1
func _can_drop_data(at: Vector2,data: Variant) -> bool:
	if not native_view or not data is Dictionary or not drag_source.is_valid() or not drag_source.call(data): return false
	var index:=tile_at_point(at)
	last_drag={"point":[at.x,at.y],"tile":index,"explored":index>=0 and index<explored.size() and int(explored[index])==1}
	return index>=0 and index<explored.size() and int(explored[index])==1
func _drop_data(at: Vector2,data: Variant) -> void:
	if _can_drop_data(at,data): note_dropped.emit(at,data)
