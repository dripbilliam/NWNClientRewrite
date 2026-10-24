extends CanvasLayer

signal request(message: Dictionary)
const Images = preload("res://systems/runtime_image.gd")
const DragButton = preload("res://systems/radial_button.gd")
var stage: PanelContainer
var title: Label
var hint: Label
var center: Button
var buttons: Dictionary = {}
var icons: Dictionary = {}
var captions: Dictionary = {}
var counts: Dictionary = {}
var entries: Array = []
var request_id := 0
var menu_id := -1
var active := false
var pending := false
var depth := 0
var origin := Vector2.ZERO
var gesture_start := Vector2.ZERO
var dragged := false
var initial_gesture := false
var click_mode := true
var selected := -1

func _ready() -> void:
	layer = 100
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	stage = PanelContainer.new()
	stage.custom_minimum_size = Vector2(380, 380)
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.02, 0.025, 0.025, 0.94)
	box.border_color = Color(0.65, 0.55, 0.3)
	box.set_border_width_all(1)
	box.set_corner_radius_all(170)
	stage.add_theme_stylebox_override("panel", box)
	root.add_child(stage)
	var surface := Control.new()
	surface.custom_minimum_size = Vector2(380, 380)
	surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(surface)
	title = Label.new()
	title.position = Vector2(70, 8)
	title.size = Vector2(240, 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.clip_text = true
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	surface.add_child(title)
	hint = Label.new()
	hint.position = Vector2(20, 340)
	hint.size = Vector2(340, 35)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 12)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	surface.add_child(hint)
	center = Button.new()
	center.position = Vector2(165, 165)
	center.size = Vector2(50, 50)
	center.focus_mode = Control.FOCUS_NONE
	center.pressed.connect(back)
	surface.add_child(center)
	for slot in 8:
		var button := DragButton.new()
		button.radial = self
		var angle := slot * PI / 4.0
		button.position = (Vector2(190, 190) + Vector2(sin(angle), -cos(angle)) * 112 - Vector2(44, 36)).round()
		button.size = Vector2(88, 72)
		button.focus_mode = Control.FOCUS_NONE
		# Async textures must not participate in Button minimum-size calculation.
		# Keep image and caption in fixed, non-container rectangles instead.
		var icon := TextureRect.new()
		icon.position = Vector2(29, 4)
		icon.size = Vector2(30, 30)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(icon)
		var caption := Label.new()
		caption.position = Vector2(4, 35)
		caption.size = Vector2(80, 34)
		caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		caption.max_lines_visible = 2
		caption.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.add_theme_font_size_override("font_size", 12)
		caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(caption)
		var count := Label.new()
		count.position = Vector2(61, 3)
		count.size = Vector2(23, 22)
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		count.add_theme_font_size_override("font_size", 12)
		count.add_theme_color_override("font_color", Color.YELLOW)
		count.add_theme_color_override("font_outline_color", Color.BLACK)
		count.add_theme_constant_override("outline_size", 4)
		count.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(count)
		button.pressed.connect(func(): choose(slot))
		button.mouse_entered.connect(func(): highlight(slot))
		surface.add_child(button)
		buttons[slot] = button
		icons[slot] = icon
		captions[slot] = caption
		counts[slot] = count
	stage.hide()
	get_viewport().size_changed.connect(reset)

func reset() -> void:
	request_id += 1
	active = false
	pending = false
	menu_id = -1
	entries.clear()
	if is_instance_valid(stage):
		stage.hide()

func open_at(point: Vector2, target_id: Variant, position: Vector3, emit_request: bool = true) -> void:
	request_id += 1
	active = true
	pending = true
	menu_id = -1
	selected = -1
	entries.clear()
	gesture_start = point
	dragged = false
	initial_gesture = true
	click_mode = not Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	var size := get_viewport().get_visible_rect().size
	origin = point.clamp(Vector2(192, 192), (size - Vector2(192, 192)).max(Vector2(192, 192)))
	stage.position = origin - Vector2(190, 190)
	title.text = "Loading actions…"
	hint.text = "Esc: close · movement keys remain available"
	center.text = "×"
	for button in buttons.values():
		button.hide()
	stage.show()
	if emit_request: request.emit({"kind": "radial-open", "requestId": request_id, "targetId": target_id, "position": [position.x, position.y, position.z]})

func receive(message: Dictionary) -> void:
	if not active or int(message.get("requestId", -1)) != request_id:
		return
	match message.kind:
		"action-close": reset()
		"action-error":
			pending = false
			hint.text = str(message.text)
		"action-menu":
			menu_id = int(message.menuId)
			depth = int(message.depth)
			pending = false
			entries = message.entries
			title.text = str(message.title)
			center.text = "↩" if depth else "×"
			hint.text = "Click to use · Drag a power to a shortcut · Esc" if entries.any(func(entry): return entry.get("canDrag", false)) else "Click an action · 1–8 · center: back · Esc"
			for slot in buttons:
				var button: DragButton = buttons[slot]
				button.hide()
				button.payload = {}
				icons[slot].texture = null
				for entry in entries:
					if int(entry.slot) == slot:
						captions[slot].text = str(entry.label) + (" ›" if entry.get("submenu", false) else "")
						counts[slot].text = str(entry.uses) if entry.get("uses") != null else ""
						button.tooltip_text = captions[slot].text + (" · uses: " + str(entry.uses) if entry.get("uses") != null else "")
						button.disabled = bool(entry.get("disabled", false))
						if entry.get("canDrag", false) and not entry.get("submenu", false) and not button.disabled:
							button.payload = {"kind":"radial-entry","requestId":request_id,"menuId":menu_id,"slot":slot}
						icons[slot].modulate = Color(1, 1, 1, 0.4 if button.disabled else 1.0)
						button.show()
		"action-icon":
			if int(message.get("menuId", -1)) == menu_id and buttons.has(int(message.slot)):
				icons[int(message.slot)].texture = Images.png(str(message.image), 512)

func choose(slot: int) -> void:
	if not active or pending:
		return
	for entry in entries:
		if int(entry.slot) == slot and not entry.get("disabled", false):
			pending = true
			request.emit({"kind": "radial-select", "requestId": request_id, "menuId": menu_id, "slot": slot})
			return

func can_shortcut(data: Dictionary) -> bool:
	if not active or pending or int(data.get("requestId", -1)) != request_id or int(data.get("menuId", -1)) != menu_id: return false
	for entry in entries:
		if int(entry.slot) == int(data.get("slot", -1)):
			return entry.get("canDrag", false) and not entry.get("submenu", false) and not entry.get("disabled", false)
	return false

func back() -> void:
	if not active:
		return
	if depth == 0 or menu_id < 0:
		request.emit({"kind": "radial-cancel", "requestId": request_id})
		reset()
	elif not pending:
		pending = true
		request.emit({"kind": "radial-back", "requestId": request_id, "menuId": menu_id})

func highlight(slot: int) -> void:
	selected = slot
	for entry in entries:
		if int(entry.slot) == slot:
			hint.text = str(entry.label) + (" · unavailable in current state" if entry.get("disabled", false) else (" · submenu" if entry.get("submenu", false) else (" · drag to a shortcut" if entry.get("canDrag", false) else "")))

static func hit(point: Vector2) -> Dictionary:
	var squared := floori(point.length_squared() + 0.5)
	var slot := posmod(int(floor((PI / 2 - atan2(-point.y, point.x)) / TAU * 8 + 0.5)), 8)
	return {"slot": slot, "zone": "center" if squared <= 400 else ("cancel" if squared <= 3136 else ("select" if squared <= 22500 else ("submenu" if squared <= 90000 else "exit")))}

func _input(event: InputEvent) -> void:
	if not active:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and not blocks_pointer(event.position):
		# Leave this press unhandled so it can still click-move in the world.
		request.emit({"kind": "radial-cancel", "requestId": request_id})
		reset()
		return
	if event is InputEventMouseMotion:
		dragged = dragged or event.position.distance_to(gesture_start) > 5
		var hovered := hit(event.position - origin)
		if hovered.zone in ["select", "submenu"]:
			highlight(int(hovered.slot))
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed:
			click_mode = false
		else:
			var hovered := hit(event.position - origin)
			if initial_gesture and not dragged:
				click_mode = true
			elif hovered.zone in ["select", "submenu"]:
				choose(int(hovered.slot))
			else:
				back()
			initial_gesture = false
		get_viewport().set_input_as_handled()
	if event is InputEventKey and event.pressed and not event.echo:
		var focus := get_viewport().gui_get_focus_owner()
		if focus is LineEdit or focus is TextEdit:
			return
		if event.keycode == KEY_ESCAPE:
			request.emit({"kind": "radial-cancel", "requestId": request_id})
			reset()
		elif event.keycode in [KEY_BACKSPACE, KEY_0]:
			back()
		elif event.keycode >= KEY_1 and event.keycode <= KEY_8:
			choose(int(event.keycode) - KEY_1)
		else:
			return
		get_viewport().set_input_as_handled()

func blocks_pointer(point: Vector2) -> bool:
	return active and point.distance_squared_to(origin) <= 190 * 190

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT and active:
		request.emit({"kind": "radial-cancel", "requestId": request_id})
		reset()
