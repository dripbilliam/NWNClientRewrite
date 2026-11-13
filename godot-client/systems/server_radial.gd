extends CanvasLayer

signal request(message: Dictionary)
const Images = preload("res://systems/runtime_image.gd")
const DragButton = preload("res://systems/radial_button.gd")
const Layout=preload("res://systems/native_data/radial_layout.gd")
const Numbers=preload("res://systems/native_data/game_numbers.gd")
const GuiIcons=preload("res://systems/native_item_icons.gd")
const Bubble=preload("res://systems/native_data/radial_text.gd")
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
var text_fonts
var text_backgrounds: Dictionary={}
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
var modal_owner_order
var modal_owner_ticket: Dictionary={}
var modal_owner_retire: Callable
var modal_input=preload("res://systems/native_data/modal_lease.gd").new()
var depth := 0
var origin := Vector2.ZERO
var gesture_start := Vector2.ZERO
var dragged := false
var initial_gesture := false
var click_mode := true
var selected := -1
var shortcut_kind:="radial-entry"
var preview_provider: Callable
var arrows: Dictionary={}
var arrow_offset:=Vector2(-16,-16)
var arrow_size:=Vector2(32,32)
var arrow_bounds: Dictionary={}
var preview_layer: Control
var preview_icons: Dictionary={}
var preview_frames: Dictionary={}
var preview_counts: Dictionary={}
var preview_groups: Dictionary={}
var hover_menu:=-1
var hover_slot:=-1
var hover_at:=0
var last_motion: Dictionary={}
var submenu_previews:=true
var submenu_preview_mode:=1 # Original g_rmSubmenuPreviewMode012: off/hover/all.
var text_preview_mode:=1
var hide_icons:=false
var text_in_center:=false
var center_align_text:=false
var use_screen_center:=false
var left_mirrors_right:=true # Original g_rmLeftMouseMirrorsRight initializer1.
var left_gesture:=false
var suppress_gui_activation:=false
var submenu_delay_usec:=150000 # Original g_rmTimeoutToSubMenu initializer.

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
	prepare_text(hint)
	center=Button.new(); center.position=Vector2(127,127); center.size=Vector2(56,56); center.focus_mode=Control.FOCUS_NONE
	style_button(center); center.tooltip_text="Close menu"; center.pressed.connect(func():
		if not suppress_gui_activation: back())
	stage.add_child(center)
	center_image=image_rect(center,Vector2(12,12),Vector2(32,32))
	center_frame=image_rect(center,Vector2.ZERO,Vector2(56,56)); center.move_child(center_frame,0)
	selection=image_rect(stage,Vector2.ZERO,Vector2(56,56)); selection.hide()
	for slot in 8:
		var button:=DragButton.new(); button.radial=self; button.size=Vector2(56,56); button.focus_mode=Control.FOCUS_NONE; style_button(button)
		var frame:=image_rect(button,Vector2.ZERO,Vector2(56,56)); button.frame=frame; frames[slot]=frame
		var icon:=image_rect(button,Vector2(12,12),Vector2(32,32))
		var caption:=Label.new(); style_text(caption); caption.hide(); button.add_child(caption)
		var count:=Label.new(); count.position=Vector2(28,0); count.size=Vector2(28,22)
		count.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT; count.add_theme_font_size_override("font_size",14)
		count.add_theme_color_override("font_color",Color.YELLOW); count.add_theme_color_override("font_outline_color",Color.BLACK); count.add_theme_constant_override("outline_size",4); count.mouse_filter=Control.MOUSE_FILTER_IGNORE; button.add_child(count)
		button.pressed.connect(func():
			if not suppress_gui_activation: choose(slot))
		button.mouse_entered.connect(func():highlight(slot))
		stage.add_child(button); buttons[slot]=button; icons[slot]=icon; captions[slot]=caption; counts[slot]=count
		prepare_text(caption)
		var angle:=slot*PI/4.0
		hooks[str(slot)+"hook"]=Vector2(sin(angle),-cos(angle))*100
		hooks[str(slot)+"submenu"]=Vector2(sin(angle),-cos(angle))*155
	hooks.center=Vector2.ZERO; hooks.text=Vector2(0,40)
	for slot in 8:
		var arrow:=image_rect(stage,Vector2.ZERO,Vector2(32,32)); arrow.pivot_offset=Vector2(16,16); arrow.rotation=slot*PI/4.0; arrow.hide(); arrows[slot]=arrow
	preview_layer=Control.new(); preview_layer.mouse_filter=Control.MOUSE_FILTER_IGNORE; preview_layer.hide(); stage.add_child(preview_layer)
	use_preview_group(0)
	layout_controls()
	stage.move_child(selection,stage.get_child_count()-1); stage.move_child(hint,stage.get_child_count()-1)
	stage.hide()
	get_viewport().size_changed.connect(reset)

func use_preview_group(parent_slot: int) -> Control:
	if preview_groups.has(parent_slot):
		var saved: Dictionary=preview_groups[parent_slot]; preview_icons=saved.icons; preview_frames=saved.frames; preview_counts=saved.counts; return saved.layer
	var group:=Control.new(); group.mouse_filter=Control.MOUSE_FILTER_IGNORE; group.hide(); preview_layer.add_child(group)
	preview_icons={}; preview_frames={}; preview_counts={}
	for slot in 8:
		var frame:=image_rect(group,Vector2.ZERO,Vector2(22,22)); frame.hide(); preview_frames[slot]=frame
		var icon:=image_rect(group,Vector2.ZERO,Vector2(16,16)); icon.hide(); preview_icons[slot]=icon
		var count:=Label.new(); count.hide(); count.add_theme_font_size_override("font_size",11); count.add_theme_color_override("font_outline_color",Color.BLACK); count.add_theme_constant_override("outline_size",3); count.mouse_filter=Control.MOUSE_FILTER_IGNORE; group.add_child(count); preview_counts[slot]=count
	preview_groups[parent_slot]={"layer":group,"icons":preview_icons,"frames":preview_frames,"counts":preview_counts}
	return group

static func style_text(label: Label) -> void:
	label.add_theme_font_size_override("font_size",16); label.add_theme_color_override("font_color",Color(1,0.95,0.8)); label.add_theme_color_override("font_outline_color",Color.BLACK); label.add_theme_constant_override("outline_size",4); label.mouse_filter=Control.MOUSE_FILTER_IGNORE
func prepare_text(label: Label) -> void:
	label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER; label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	var background:=image_rect(label,Vector2.ZERO,Vector2.ZERO); background.show_behind_parent=true; text_backgrounds[label.get_instance_id()]=background
func configure_text(source) -> void:
	text_fonts=source; text_fonts.loaded.connect(text_font_ready)
	for label in [hint]+captions.values(): text_fonts.bind(label,Bubble.DIALOG_FONT)
func text_font_ready(name: String) -> void:
	if name!=Bubble.DIALOG_FONT: return
	refresh_text()
	if selected>=0: highlight(selected)
func fit_text(label: Label) -> void:
	var font: Font=label.get_theme_font("font"); var size:=label.get_theme_font_size("font_size")
	var signature: Array=[label.text,font.get_rid(),size]
	if label.get_meta("radial_bubble_signature",[])!=signature:
		var selected_bubble:=Bubble.choose(font,size,label.text)
		label.set_meta("native_bubble_dimensions",Vector2(float(selected_bubble[0]),float(selected_bubble[1])))
		label.set_meta("radial_bubble_signature",signature)
		var background: TextureRect=text_backgrounds[label.get_instance_id()]; background.size=label.get_meta("native_bubble_dimensions")
		background.set_meta("native_bubble_model",str(selected_bubble[2]))
		bind_text_background(background)
	var dimensions: Vector2=label.get_meta("native_bubble_dimensions")
	if label.size!=dimensions:
		# Shape at the chosen width before shrinking height: Control otherwise
		# clamps against the previous wrap's minimum and retains that old height.
		label.size=Vector2(dimensions.x,label.size.y); label.size=dimensions
		if label.size!=dimensions: label.set_deferred("size",dimensions)
func bind_text_background(background: TextureRect) -> void:
	var resource:=str(background.get_meta("native_bubble_model",""))
	if resource.is_empty() or not is_instance_valid(art): return
	art.bind(background,resource,"texture",true,"")
	var key:=GuiIcons.model_key(resource,"")
	if art.bounds.has(key): apply_text_bounds(background,art.bounds[key])
func apply_text_bounds(background: TextureRect,bounds: Dictionary) -> void:
	var low: Array=bounds.get("min",[]); var high: Array=bounds.get("max",[])
	if low.size()!=2 or high.size()!=2: return
	var offset:=Vector2(float(low[0]),-float(high[1]))*100.0
	var extent:=Vector2(float(high[0])-float(low[0]),float(high[1])-float(low[1]))*100.0
	if not offset.is_finite() or not extent.is_finite() or extent.x<=0 or extent.y<=0: return
	background.position=offset; background.size=extent

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
	for arrow in arrows.values(): art.bind(arrow,"gui_ra_more","texture",true,"")
	var arrow_key:=GuiIcons.model_key("gui_ra_more","")
	if art.bounds.has(arrow_key): apply_arrow_bounds(art.bounds[arrow_key])
	for frame in preview_frames.values(): art.bind(frame,"gui_ra_circle56","texture",true,"")
	for background in text_backgrounds.values(): bind_text_background(background)
	layout_job=art.assets.request("gui_ra_menu",2002,"mdl-original")
	if layout_job<0: skin_errors.append("Original radial layout could not be requested")

func layout_prepared(id: int,result: Dictionary) -> void:
	if id!=layout_job: return
	layout_job=-1
	if not str(result.error).is_empty(): skin_errors.append(str(result.error)); return
	var parsed:=Layout.parse(result.value)
	if not str(parsed.error).is_empty(): skin_errors.append(str(parsed.error)); return
	hooks=parsed.hooks; layout_ready=true; layout_controls()

func art_ready(key: String,_texture: Texture2D,bounds: Dictionary) -> void:
	if key==GuiIcons.model_key("gui_ra_more",""): apply_arrow_bounds(bounds)
	for background in text_backgrounds.values():
		if key==GuiIcons.model_key(str(background.get_meta("native_bubble_model","")),""): apply_text_bounds(background,bounds)
	for button in buttons.values(): button.queue_redraw()
func apply_arrow_bounds(bounds: Dictionary) -> void:
	var low: Array=bounds.get("min",[]); var high: Array=bounds.get("max",[])
	if low.size()!=2 or high.size()!=2: return
	var offset:=Vector2(float(low[0]),-float(high[1]))*100.0; var extent:=Vector2(float(high[0])-float(low[0]),float(high[1])-float(low[1]))*100.0
	if not offset.is_finite() or not extent.is_finite() or extent.x<=0 or extent.y<=0: return
	arrow_offset=offset; arrow_size=extent; arrow_bounds=bounds.duplicate(true); layout_controls()

func layout_controls() -> void:
	center.position=Vector2(155,155)+hooks.center-center.size*0.5
	for slot in buttons: buttons[slot].position=Vector2(155,155)+hooks[str(slot)+"hook"]-Vector2(28,28)
	for slot in arrows:
		arrows[slot].size=arrow_size; arrows[slot].pivot_offset=-arrow_offset; arrows[slot].position=Vector2(155,155)+hooks[str(slot)+"submenu"]+arrow_offset
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
	return {"native_only":true,"layout_ready":layout_ready,"frame_ready":center_frame.texture!=null,"selection_ready":selection.texture!=null,"arrow_bounds":arrow_bounds.duplicate(true),"errors":skin_errors.duplicate(),"left_mirrors_right":left_mirrors_right,"scope":"Original GUI hooks/art, native bubble-root edge alignment and mirrored left/right navigation; complete font wrapping, DPI and DM parity remain separate"}

func reset() -> void:
	retire_modal_owner()
	request_id += 1
	active = false
	pending = false
	menu_id = -1
	entries.clear()
	selected=-1
	left_gesture=false
	hover_slot=-1; hover_menu=-1
	if is_instance_valid(preview_layer): clear_preview()
	for arrow in arrows.values(): arrow.hide()
	if is_instance_valid(selection): selection.hide()
	if is_instance_valid(art):
		art.bind(center_image,"")
		for icon in icons.values(): art.bind(icon,"")
	if is_instance_valid(stage):
		stage.hide()

func open_at(point: Vector2, target_id: Variant, position: Vector3, emit_request: bool = true) -> void:
	retire_modal_owner()
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
	origin = size*0.5 if use_screen_center else point.clamp(Vector2(155,155), (size-Vector2(156,156)).max(Vector2(155,155)))
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
	register_modal_owner()
	if emit_request: emit_request({"kind": "radial-open", "requestId": request_id, "targetId": target_id, "position": [position.x, position.y, position.z]})

func set_modal_owner(order,retire: Callable) -> void:
	retire_modal_owner(); modal_owner_order=order; modal_owner_retire=retire
	modal_input.configure(self,order);modal_input.bind_input(stage)
	if active: register_modal_owner()
func register_modal_owner() -> void:
	if not active or not is_instance_valid(modal_owner_order) or not modal_owner_retire.is_valid(): return
	var ticket: Dictionary=modal_owner_order.activate(self,"Rmnu",request_id,[],deactivate_modal_owner,superseded_modal_owner)
	modal_owner_ticket=ticket if ticket.has("registry") else {}
	modal_input.active=true;modal_input.ticket=modal_owner_ticket;modal_input.update_input()
func retire_modal_owner() -> void:
	if is_instance_valid(modal_owner_order) and not modal_owner_ticket.is_empty(): modal_owner_order.retire(modal_owner_ticket)
	modal_owner_ticket.clear()
	modal_input.active=false;modal_input.ticket={};modal_input.update_input()
func deactivate_modal_owner(ticket: Dictionary) -> bool:
	if not active or ticket!=modal_owner_ticket or int(ticket.get("lifetime",-1))!=request_id or not modal_owner_retire.is_valid(): return false
	return bool(modal_owner_retire.call(request_id))
func superseded_modal_owner(ticket: Dictionary) -> void:
	if is_instance_valid(modal_owner_order) and not modal_owner_order.callback_owner(ticket):deactivate_modal_owner(ticket)
func modal_admitted() -> bool:
	return not is_instance_valid(modal_owner_order) or modal_owner_order.admits(modal_owner_ticket)
func emit_request(message: Dictionary) -> void:
	if is_instance_valid(modal_owner_order):modal_owner_order.with_callback(modal_owner_ticket,func():request.emit(message))
	else:request.emit(message)

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
			# Reset owns this Array header. Never clear the caller's retained
			# menu/page when backing out or reopening a wheel.
			entries = message.entries.duplicate()
			selected=-1; selection.hide(); hint.hide(); clear_preview(); hover_slot=-1; hover_menu=-1
			title.text = str(message.title)
			center.text = ("↩" if depth else "×") if center_frame.visible else ""
			center.tooltip_text=("Back — " if depth else "Close — ")+str(message.title)
			hint.text = "Click to use · Drag a power to a shortcut · Esc" if entries.any(func(entry): return entry.get("canDrag", false)) else "Click an action · 1–8 · center: back · Esc"
			for slot in buttons:
				var button: DragButton = buttons[slot]
				button.hide()
				arrows[slot].hide()
				button.payload = {}
				icons[slot].texture = null
				for entry in entries:
					if int(entry.slot) == slot:
						captions[slot].text = str(entry.label)
						counts[slot].text = Numbers.text(entry.get("uses"), "")
						button.tooltip_text = captions[slot].text + (" · uses: " + counts[slot].text if entry.get("uses") != null else "") + (" · drag to a shortcut" if entry.get("canDrag",false) and not entry.get("submenu",false) else "")
						button.disabled = bool(entry.get("disabled", false))
						arrows[slot].visible=not hide_icons and bool(entry.get("submenu",false)); arrows[slot].modulate.a=0.4 if button.disabled else 1.0
						if entry.get("canDrag", false) and not entry.get("submenu", false) and not button.disabled:
							button.payload = {"kind":shortcut_kind,"requestId":request_id,"menuId":menu_id,"slot":slot}
						icons[slot].modulate = Color(1, 1, 1, 0.4 if button.disabled else 1.0)
						icons[slot].visible=not hide_icons; frames[slot].visible=not hide_icons; counts[slot].visible=not hide_icons
						button.show()
			refresh_text(); refresh_previews()
		"action-icon":
			if int(message.get("menuId", -1)) == menu_id and buttons.has(int(message.slot)):
				icons[int(message.slot)].texture = Images.png(str(message.image), 512)

func choose(slot: int) -> void:
	if not active or pending or not modal_admitted():
		return
	for entry in entries:
		if int(entry.slot) == slot and not entry.get("disabled", false):
			pending = true
			emit_request({"kind": "radial-select", "requestId": request_id, "menuId": menu_id, "slot": slot})
			return

func can_shortcut(data: Dictionary) -> bool:
	if not active or pending or not modal_admitted() or int(data.get("requestId", -1)) != request_id or int(data.get("menuId", -1)) != menu_id: return false
	for entry in entries:
		if int(entry.slot) == int(data.get("slot", -1)):
			return entry.get("canDrag", false) and not entry.get("submenu", false) and not entry.get("disabled", false)
	return false

func back() -> void:
	if not active or not modal_admitted():
		return
	if depth == 0 or menu_id < 0:
		emit_request({"kind": "radial-cancel", "requestId": request_id})
		reset()
	elif not pending:
		pending = true
		emit_request({"kind": "radial-back", "requestId": request_id, "menuId": menu_id})

func highlight(slot: int) -> void:
	var changed:=selected!=slot
	selected = slot
	selection.hide(); hint.hide()
	for entry in entries:
		if int(entry.slot) == slot:
			hint.text = str(entry.label) + (" · unavailable in current state" if entry.get("disabled", false) else "")
			selection.position=buttons[slot].position; selection.visible=not hide_icons and (not entry.get("submenu",false) or preview_mode()==0)
			fit_text(hint); position_text(hint,slot)
			hint.visible=text_preview_mode==1
			refresh_text()
			if changed: show_preview(entry)
			return
	if preview_mode()!=2: clear_preview()
func position_text(label: Label,slot: int) -> void:
	var anchor: Vector2=Vector2(155,155)+hooks.text if text_in_center else Vector2(155,155)+hooks[str(slot)+("hook" if hide_icons else "submenu")]
	var screen:=get_viewport().get_visible_rect().size
	var local_origin: Vector2=buttons[slot].position if label==captions[slot] else Vector2.ZERO
	var dimensions: Vector2=label.get_meta("native_bubble_dimensions",label.size)
	var signature: Array=[anchor,dimensions,stage.position,screen,local_origin,slot,hide_icons,center_align_text,text_in_center,text_preview_mode]
	if label.get_meta("radial_alignment_signature",[])==signature: return
	var center_position:=stage.position+Vector2(155,155)
	var alignment:=Bubble.alignment(slot,Vector2(center_position.x,screen.y-center_position.y),screen,dimensions,hide_icons,center_align_text or text_in_center,text_preview_mode)
	var model_offset:=Bubble.root_offset(alignment,dimensions)
	label.position=anchor+Vector2(model_offset.x,-model_offset.y)*100.0-local_origin
	label.set_meta("radial_alignment_signature",signature)
func refresh_text() -> void:
	for slot in captions:
		var label: Label=captions[slot]; label.visible=buttons[slot].visible and text_preview_mode==2
		if label.visible:
			fit_text(label); label.add_theme_color_override("font_color",Color.YELLOW if selected==slot else Color(1,1,1,0.4 if buttons[slot].disabled else 1.0)); position_text(label,slot)
func preview_mode() -> int: return submenu_preview_mode if submenu_previews and not hide_icons else 0
func refresh_previews() -> void:
	clear_preview()
	if preview_mode()==2:
		for entry in entries: build_preview(entry)
func clear_preview() -> void:
	preview_layer.hide()
	for group in preview_groups.values():
		group.layer.hide()
		for slot in group.icons:
			group.icons[slot].hide(); group.frames[slot].hide(); group.counts[slot].hide(); group.icons[slot].texture=null
			if is_instance_valid(art): art.bind(group.icons[slot],"")
func show_preview(entry: Dictionary) -> void:
	if preview_mode()==2: return
	clear_preview()
	if preview_mode()==1: build_preview(entry)
func build_preview(entry: Dictionary) -> void:
	if preview_mode()==0 or not bool(entry.get("submenu",false)) or not preview_provider.is_valid() or not is_instance_valid(art): return
	var values: Variant=preview_provider.call(int(entry.slot),request_id,menu_id)
	if not values is Array: return
	var group:=use_preview_group(int(entry.slot)); group.show()
	var anchor: Vector2=buttons[int(entry.slot)].position+Vector2(28,28)
	for index in mini(8,values.size()):
		var child: Dictionary=values[index]; var slot:=int(child.get("slot",index))
		if slot<0 or slot>7: continue
		var angle:=slot*PI/4.0; var point:=anchor+Vector2(int(sin(angle)*30.0),-int(cos(angle)*30.0)) # BuildSubMenuIcons truncates each30px component.
		var frame: TextureRect=preview_frames[slot]; var icon: TextureRect=preview_icons[slot]; var count: Label=preview_counts[slot]
		frame.position=point-Vector2(11,11); icon.position=point-Vector2(8,8); count.position=point+Vector2(1,0)
		frame.modulate.a=0.4 if entry.get("disabled",false) or child.get("disabled",false) else 1.0; icon.modulate.a=frame.modulate.a
		frame.hide(); icon.size=Vector2(22,22); icon.position=point-Vector2(11,11); icon.show(); count.text=Numbers.text(child.get("uses"),""); count.visible=not count.text.is_empty()
		var resource:=str(child.get("icon",""))
		# Native micro previews use GUI_ICON_1X1MRNG with the child icon in
		# gui_replace01; they are not full-sized icons laid over another circle.
		art.bind(icon,"gui_icon_1x1mrng" if not resource.is_empty() else "gui_ra_multisub8","texture",true,"",false,{"gui_replace01":resource} if not resource.is_empty() else {})
	preview_layer.show()
func _process(_delta: float) -> void:
	if active and not pending and not click_mode and not get_viewport().gui_is_dragging() and hover_menu==menu_id and hover_slot>=0 and Time.get_ticks_usec()-hover_at>submenu_delay_usec:
		var slot:=hover_slot; hover_slot=-1; choose(slot)

static func hit(point: Vector2) -> Dictionary:
	var squared := floori(point.length_squared() + 0.5)
	var slot := posmod(int(floor((PI / 2 - atan2(-point.y, point.x)) / TAU * 8 + 0.5)), 8)
	return {"slot": slot, "zone": "center" if squared <= 400 else ("cancel" if squared <= 3136 else ("select" if squared <= 22500 else ("submenu" if squared <= 90000 else "exit")))}

func clear_gui_activation_suppression() -> void:
	suppress_gui_activation=false
func on_button(point: Vector2) -> bool:
	if center.get_global_rect().has_point(point): return true
	for button in buttons.values():
		if button.visible and button._has_point(point-button.global_position): return true
	return false
func _input(event: InputEvent) -> void:
	if not active or not modal_admitted():
		return
	if event is InputEventKey and is_instance_valid(key_bindings) and key_bindings.blocked(): return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and not blocks_pointer(event.position):
		# Leave this press unhandled so it can still click-move in the world.
		emit_request({"kind": "radial-cancel", "requestId": request_id})
		reset()
		return
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		if not left_mirrors_right:
			if event.pressed: back()
			else: click_mode=true
			get_viewport().set_input_as_handled(); return
		if event.pressed:
			left_gesture=true; suppress_gui_activation=false; click_mode=false; initial_gesture=false
			gesture_start=event.position; dragged=false
			# Real icon buttons retain their GUI press so power dragging works.
			# Angular gaps belong to the wheel, not the world underneath it.
			if not on_button(event.position): get_viewport().set_input_as_handled()
			return
		if left_gesture:
			left_gesture=false; click_mode=true
			if get_viewport().gui_is_dragging(): return
			# Let Godot release its pressed button, but suppress its second action
			# if the first selection synchronously replaced the submenu contents.
			suppress_gui_activation=true; call_deferred("clear_gui_activation_suppression")
			var hovered:=hit(event.position-origin)
			if hovered.zone in ["select","submenu"]: choose(int(hovered.slot))
			else: back()
			return
	if event is InputEventMouseMotion:
		if get_viewport().gui_is_dragging(): hover_slot=-1; return
		dragged = dragged or event.position.distance_to(gesture_start) > 5
		var hovered := hit(event.position - origin)
		last_motion={"position":event.position,"origin":origin,"sector":hovered,"click_mode":click_mode,"menu_id":menu_id}
		if hovered.zone in ["select", "submenu"]:
			highlight(int(hovered.slot))
			if not click_mode and hovered.zone=="submenu" and entries.any(func(entry):return int(entry.slot)==int(hovered.slot) and entry.get("submenu",false) and not entry.get("disabled",false)):
				if hover_slot!=int(hovered.slot) or hover_menu!=menu_id: hover_slot=int(hovered.slot); hover_menu=menu_id; hover_at=Time.get_ticks_usec()
			else: hover_slot=-1
		else:
			selected=-1; selection.hide(); hint.hide(); refresh_text(); hover_slot=-1
			if preview_mode()!=2: clear_preview()
	if event is InputEventMouseButton and not event.pressed and event.button_index==MOUSE_BUTTON_LEFT and blocks_pointer(event.position):
		# The original wheel accepts its angular sector between icon discs too.
		# Let real Button clicks/drag-and-drop retain their normal Godot path.
		if not on_button(event.position):
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
			emit_request({"kind": "radial-cancel", "requestId": request_id})
			reset()
		elif event.keycode in [KEY_BACKSPACE, KEY_0]:
			back()
		elif event.keycode >= KEY_1 and event.keycode <= KEY_8:
			choose(int(event.keycode) - KEY_1)
		else:
			return
		get_viewport().set_input_as_handled()

func blocks_pointer(point: Vector2) -> bool:
	return active and modal_admitted() and point.distance_squared_to(origin) <= 155 * 155

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT and active:
		emit_request({"kind": "radial-cancel", "requestId": request_id})
		reset()
func _exit_tree() -> void:
	retire_modal_owner();modal_input.close(); modal_owner_order=null; modal_owner_retire=Callable()
