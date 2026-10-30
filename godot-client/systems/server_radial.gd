extends CanvasLayer

signal request(message: Dictionary)
const Images = preload("res://systems/runtime_image.gd")
const DragButton = preload("res://systems/radial_button.gd")
const Layout=preload("res://systems/native_data/radial_layout.gd")
const Numbers=preload("res://systems/native_data/game_numbers.gd")
var stage: Control
var art
var key_bindings
var layout_job:=-1
var layout_ready:=false
var hooks: Dictionary={}
var frames: Dictionary={}
var skin_errors: Array=[]
var center_image: TextureRect
var center_frame: TextureRect
var selection: TextureRect
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
var shortcut_kind:="radial-entry"

func _ready() -> void:
	layer = 100
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	stage=Control.new(); stage.size=Vector2(310,310); stage.mouse_filter=Control.MOUSE_FILTER_IGNORE; root.add_child(stage)
	title=Label.new(); title.hide(); stage.add_child(title)
	hint=Label.new(); hint.size=Vector2(240,48); hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; hint.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color",Color(1,0.95,0.8)); hint.add_theme_color_override("font_outline_color",Color.BLACK); hint.add_theme_constant_override("outline_size",4)
	hint.add_theme_font_size_override("font_size",16); hint.mouse_filter=Control.MOUSE_FILTER_IGNORE; hint.hide(); stage.add_child(hint)
	center=Button.new(); center.position=Vector2(127,127); center.size=Vector2(56,56); center.focus_mode=Control.FOCUS_NONE
	style_button(center); center.tooltip_text="Close menu"; center.pressed.connect(back); stage.add_child(center)
	center_image=image_rect(center,Vector2(12,12),Vector2(32,32))
	center_frame=image_rect(center,Vector2.ZERO,Vector2(56,56)); center.move_child(center_frame,0)
	selection=image_rect(stage,Vector2.ZERO,Vector2(56,56)); selection.hide()
	for slot in 8:
		var button:=DragButton.new(); button.radial=self; button.size=Vector2(56,56); button.focus_mode=Control.FOCUS_NONE; style_button(button)
		var frame:=image_rect(button,Vector2.ZERO,Vector2(56,56)); button.frame=frame; frames[slot]=frame
		var icon:=image_rect(button,Vector2(12,12),Vector2(32,32))
		var caption:=Label.new(); caption.hide(); button.add_child(caption)
		var count:=Label.new(); count.position=Vector2(28,0); count.size=Vector2(28,22)
		count.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT; count.add_theme_font_size_override("font_size",14)
		count.add_theme_color_override("font_color",Color.YELLOW); count.add_theme_color_override("font_outline_color",Color.BLACK); count.add_theme_constant_override("outline_size",4); count.mouse_filter=Control.MOUSE_FILTER_IGNORE; button.add_child(count)
		button.pressed.connect(func():choose(slot)); button.mouse_entered.connect(func():highlight(slot))
		stage.add_child(button); buttons[slot]=button; icons[slot]=icon; captions[slot]=caption; counts[slot]=count
		var angle:=slot*PI/4.0
		hooks[str(slot)+"hook"]=Vector2(sin(angle),-cos(angle))*100
		hooks[str(slot)+"submenu"]=Vector2(sin(angle),-cos(angle))*155
	hooks.center=Vector2.ZERO; hooks.text=Vector2(0,40)
	layout_controls()
	stage.move_child(selection,stage.get_child_count()-1); stage.move_child(hint,stage.get_child_count()-1)
	stage.hide()
	get_viewport().size_changed.connect(reset)

static func style_button(button: Button) -> void:
	for state in ["normal","hover","pressed","disabled","focus"]:
		button.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	button.add_theme_color_override("font_outline_color",Color.BLACK); button.add_theme_constant_override("outline_size",4)

static func image_rect(parent: Node,point: Vector2,dimensions: Vector2) -> TextureRect:
	var image:=TextureRect.new(); image.position=point; image.size=dimensions
	image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED; image.mouse_filter=Control.MOUSE_FILTER_IGNORE
	parent.add_child(image); return image

func configure_art(source) -> void:
	art=source
	art.assets.completed.connect(layout_prepared)
	art.loaded.connect(art_ready)
	for frame in frames.values(): art.bind(frame,"gui_ra_circle56","texture",true,"")
	art.bind(center_frame,"gui_ra_circle56","texture",true,"")
	art.bind(selection,"gui_ra_clearring","texture",true,"")
	layout_job=art.assets.request("gui_ra_menu",2002,"mdl-original")
	if layout_job<0: skin_errors.append("Original radial layout could not be requested")

func layout_prepared(id: int,result: Dictionary) -> void:
	if id!=layout_job: return
	layout_job=-1
	if not str(result.error).is_empty(): skin_errors.append(str(result.error)); return
	var parsed:=Layout.parse(result.value)
	if not str(parsed.error).is_empty(): skin_errors.append(str(parsed.error)); return
	hooks=parsed.hooks; layout_ready=true; layout_controls()

func art_ready(_key: String,_texture: Texture2D,_bounds: Dictionary) -> void:
	for button in buttons.values(): button.queue_redraw()

func layout_controls() -> void:
	center.position=Vector2(155,155)+hooks.center-center.size*0.5
	for slot in buttons: buttons[slot].position=Vector2(155,155)+hooks[str(slot)+"hook"]-Vector2(28,28)
	if selected>=0: highlight(selected)

func set_center(resource: String,portrait: bool=false) -> void:
	center_image.texture=null; center_image.flip_v=false
	center.size=Vector2(64,100) if portrait else Vector2(56,56)
	center_image.position=Vector2.ZERO if portrait else Vector2(12,12); center_image.size=Vector2(64,100) if portrait else Vector2(32,32)
	center_frame.visible=not portrait; center.text="" if portrait else ("↩" if depth else "×"); layout_controls()
	if not is_instance_valid(art): return
	art.bind(center_image,"")
	if portrait and not resource.is_empty(): art.bind_portrait(center_image,resource)
	else: art.bind(center_image,resource)

func skin_snapshot() -> Dictionary:
	return {"native_only":true,"layout_ready":layout_ready,"frame_ready":center_frame.texture!=null,"selection_ready":selection.texture!=null,"errors":skin_errors.duplicate(),"scope":"Original GUI_RA_MENU attachment positions and native circular model art; complete native radial preference/submenu-preview parity pending"}

func reset() -> void:
	request_id += 1
	active = false
	pending = false
	menu_id = -1
	entries.clear()
	selected=-1
	if is_instance_valid(selection): selection.hide()
	if is_instance_valid(art):
		art.bind(center_image,"")
		for icon in icons.values(): art.bind(icon,"")
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
	origin = point.clamp(Vector2(155,155), (size-Vector2(156,156)).max(Vector2(155,155)))
	stage.position = origin-Vector2(155,155)
	title.text = "Loading actions…"
	hint.text = "Esc: close · movement keys remain available"
	center.text = "×"
	center_image.texture=null
	if is_instance_valid(art): art.bind(center_image,"")
	selection.hide(); hint.hide()
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
			hint.position=Vector2(35,200); hint.show()
		"action-menu":
			menu_id = int(message.menuId)
			depth = int(message.depth)
			pending = false
			entries = message.entries
			selected=-1; selection.hide(); hint.hide()
			title.text = str(message.title)
			center.text = ("↩" if depth else "×") if center_frame.visible else ""
			center.tooltip_text=("Back — " if depth else "Close — ")+str(message.title)
			hint.text = "Click to use · Drag a power to a shortcut · Esc" if entries.any(func(entry): return entry.get("canDrag", false)) else "Click an action · 1–8 · center: back · Esc"
			for slot in buttons:
				var button: DragButton = buttons[slot]
				button.hide()
				button.payload = {}
				icons[slot].texture = null
				for entry in entries:
					if int(entry.slot) == slot:
						captions[slot].text = str(entry.label) + (" ›" if entry.get("submenu", false) else "")
						counts[slot].text = Numbers.text(entry.get("uses"), "")
						button.tooltip_text = captions[slot].text + (" · uses: " + counts[slot].text if entry.get("uses") != null else "") + (" · drag to a shortcut" if entry.get("canDrag",false) and not entry.get("submenu",false) else "")
						button.disabled = bool(entry.get("disabled", false))
						if entry.get("canDrag", false) and not entry.get("submenu", false) and not button.disabled:
							button.payload = {"kind":shortcut_kind,"requestId":request_id,"menuId":menu_id,"slot":slot}
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
	selection.hide(); hint.hide()
	for entry in entries:
		if int(entry.slot) == slot:
			hint.text = str(entry.label) + (" · unavailable in current state" if entry.get("disabled", false) else "")
			selection.position=buttons[slot].position; selection.show()
			var anchor: Vector2=Vector2(155,155)+hooks[str(slot)+"submenu"]
			hint.position=anchor-Vector2(hint.size.x*(0.0 if slot in [1,2,3] else 1.0 if slot in [5,6,7] else 0.5),hint.size.y*0.5)
			hint.position=(stage.position+hint.position).clamp(Vector2.ZERO,(get_viewport().get_visible_rect().size-hint.size).max(Vector2.ZERO))-stage.position
			hint.show()

static func hit(point: Vector2) -> Dictionary:
	var squared := floori(point.length_squared() + 0.5)
	var slot := posmod(int(floor((PI / 2 - atan2(-point.y, point.x)) / TAU * 8 + 0.5)), 8)
	return {"slot": slot, "zone": "center" if squared <= 400 else ("cancel" if squared <= 3136 else ("select" if squared <= 22500 else ("submenu" if squared <= 90000 else "exit")))}

func _input(event: InputEvent) -> void:
	if not active:
		return
	if event is InputEventKey and is_instance_valid(key_bindings) and key_bindings.blocked(): return
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
		else:
			selected=-1; selection.hide(); hint.hide()
	if event is InputEventMouseButton and not event.pressed and event.button_index==MOUSE_BUTTON_LEFT and blocks_pointer(event.position):
		# The original wheel accepts its angular sector between icon discs too.
		# Let real Button clicks/drag-and-drop retain their normal Godot path.
		var on_button:=center.get_global_rect().has_point(event.position)
		for button in buttons.values():
			if button.visible and button._has_point(event.position-button.global_position): on_button=true
		if not on_button:
			var hovered:=hit(event.position-origin)
			if hovered.zone in ["select","submenu"]: choose(int(hovered.slot))
			elif hovered.zone=="cancel": back()
			get_viewport().set_input_as_handled()
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
	return active and point.distance_squared_to(origin) <= 155 * 155

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT and active:
		request.emit({"kind": "radial-cancel", "requestId": request_id})
		reset()
