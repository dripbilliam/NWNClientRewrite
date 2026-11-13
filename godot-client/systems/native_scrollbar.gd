extends Control
# Original vertex-animated rail/thumb and arrow models over the native range.
# No screenshot stretching or per-scroll model preparation.
const Layout=preload("res://systems/native_data/scrollbar_layout.gd")
const Repeat=preload("res://systems/native_data/gui_repeat.gd")
const ThumbRange=preload("res://systems/native_data/gui_scroll_range.gd")
var frame
var art
var scroll: ScrollContainer
var range_control: VScrollBar
var plan: Dictionary={}
var rail: TextureRect
var thumb: TextureRect
var up: Button
var down: Button
var rail_key:=""
var thumb_key:=""
var thumb_image_key:=""
var pending_thumb_plan: Dictionary={}
var requested_thumb_pixels:=-1.0
var art_ready:=false
var failure:=""
var dragging:=false
var drag_offset:=0.0
var drag_start_value:=0.0
var line_step:=14.0
var visible_units_override:=-1 # Some original programmatic grids use logical page units.
var closed:=false
var previous_mode:=ScrollContainer.SCROLL_MODE_AUTO
var repeat_clock:=Repeat.new()
var arrow_direction:=0
var page_direction:=0
var page_held:=false
var font_name:=""
var source_models: Dictionary={}
var layout_target: Dictionary={}
var layout_inflight: Dictionary={}
var layout_requests:=0
func configure(painter,models: Dictionary,entry: Dictionary,owner: ScrollContainer,step_pixels: float=14) -> void:
	hide(); frame=painter; art=painter.art; scroll=owner; range_control=scroll.get_v_scroll_bar(); line_step=maxf(1,step_pixels); previous_mode=scroll.vertical_scroll_mode
	source_models=models
	font_name=str(entry.get("caption",{}).get("AurString_Font",""))
	if is_instance_valid(frame.fonts): frame.fonts.loaded.connect(font_loaded)
	scroll.gui_input.connect(content_input)
	font_loaded(font_name)
	for name in ["scrollbar_simple","pb_scrl_up","pb_scrl_down"]:
		if not models.has(name): failure="Original scrollbar model is missing: "+name; return
	plan=Layout.parse(models.scrollbar_simple,entry,models.pb_scrl_up,models.pb_scrl_down)
	if not str(plan.error).is_empty(): failure=str(plan.error); return
	position=plan.attachment+plan.bounds.position; size=plan.bounds.size; mouse_filter=Control.MOUSE_FILTER_STOP; focus_mode=Control.FOCUS_NONE
	visibility_changed.connect(func():
		if not is_visible_in_tree(): cancel_drag(); stop_repeat())
	var origin: Vector2=-plan.bounds.position
	for name in ["up","down"]:
		var button:=Button.new(); add_child(button)
		var resource: String="pb_scrl_"+name; var rect: Rect2=plan[name]; rect.position+=origin
		frame.button(button,{"resource":resource,"rect":rect,"offset":origin+plan.hooks[name]},self,models,false)
		button.button_down.connect(func():begin_arrow(-1 if name=="up" else 1))
		button.button_up.connect(stop_repeat)
		if name=="up": up=button
		else: down=button
	rail=picture(); thumb=picture(); move_child(rail,0); move_child(thumb,1)
	art.loaded.connect(loaded); range_control.value_changed.connect(changed); range_control.changed.connect(refresh)
	rail_key=art.request_model("scrollbar_simple","",{},0,"gui_boxes_ingame",plan.poses)
	request_thumb()
	if rail_key.is_empty() or thumb_key.is_empty(): failure="Original scrollbar artwork could not be requested"; return
	for key in [rail_key,thumb_key]:
		if art.textures.has(key): loaded(key,art.textures[key],art.bounds.get(key,{}))
	refresh()
func picture() -> TextureRect:
	var control:=TextureRect.new(); control.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; control.mouse_filter=Control.MOUSE_FILTER_IGNORE; control.stretch_mode=TextureRect.STRETCH_SCALE; add_child(control); return control
func loaded(key: String,texture: Texture2D,_bounds: Dictionary) -> void:
	if not closed and not layout_inflight.is_empty() and key in [layout_inflight.rail_key,layout_inflight.thumb_key]:
		publish_layout(); return
	if closed or key not in [rail_key,thumb_key] or texture==null: return
	var control: TextureRect=rail if key==rail_key else thumb
	control.texture=texture
	if key==thumb_key:
		thumb_image_key=key; plan=pending_thumb_plan
	if rail.texture!=null and thumb.texture!=null:
		art_ready=true; show(); scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_SHOW_NEVER
	refresh()
func image_rect(key: String) -> Rect2:
	var data: Dictionary=art.bounds.get(key,{})
	return Rect2(Vector2(float(data.min[0]),-float(data.max[1]))*100.0,Vector2(float(data.max[0])-float(data.min[0]),float(data.max[1])-float(data.min[1]))*100.0) if data.has("min") and data.has("max") else Rect2()
func maximum() -> float: return maxf(0,range_control.max_value-range_control.page)
func _process(delta: float) -> void:
	if closed or not failure.is_empty(): stop_repeat(); set_process(false); return
	if art.failed.has(rail_key) or art.failed.has(thumb_key): failure="Original scrollbar model rendering failed"; stop_repeat(); set_process(false); return
	service_layout()
	if not failure.is_empty(): stop_repeat(); set_process(false); return
	if not art_ready:
		if not rail_key.is_empty() and art.failed.has(rail_key) or not thumb_key.is_empty() and art.failed.has(thumb_key): failure="Original scrollbar model rendering failed"; set_process(false)
		return
	if not repeat_clock.active:
		if layout_target.is_empty() and layout_inflight.is_empty() and thumb_key==thumb_image_key: set_process(false)
		return
	advance_repeat(roundi(delta*1000000.0))
func font_loaded(name: String) -> void:
	if closed or name!=font_name: return
	if is_instance_valid(frame.fonts) and frame.fonts.metrics.has(name): line_step=maxf(1,roundf(float(frame.fonts.metrics[name].height)))
func wheel_input(event: InputEvent) -> bool:
	if not event is InputEventMouseButton or event.button_index not in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]: return false
	if event.pressed: change(line_step*3*event.factor*(-1 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 1))
	return true
func content_input(event: InputEvent) -> void:
	# Signal precedes Godot's viewport-height-relative native wheel default.
	# Only the visible original bar owns this scroll container in this mode.
	if not closed and art_ready and is_visible_in_tree() and wheel_input(event): scroll.accept_event()
func begin_arrow(direction: int) -> void:
	if closed or not art_ready or not is_visible_in_tree(): return
	stop_repeat(); arrow_direction=direction; repeat_clock.begin(); change(direction*line_step); set_process(true)
func begin_page() -> void:
	stop_repeat(); page_held=true; repeat_clock.begin_rail(); set_process(true)
func stop_repeat() -> void:
	repeat_clock.stop(); arrow_direction=0; page_direction=0; page_held=false
func cancel_drag() -> void:
	if dragging and is_instance_valid(range_control): range_control.value=drag_start_value
	dragging=false
func advance_repeat(microseconds: int) -> void:
	if not is_visible_in_tree(): stop_repeat(); return
	if arrow_direction!=0:
		var button: Button=up if arrow_direction<0 else down
		if button.disabled or not button.is_pressed(): stop_repeat(); return
		if repeat_clock.tick(microseconds,button.get_global_rect().has_point(button.get_global_mouse_position())): change(arrow_direction*line_step)
	elif page_held and repeat_clock.tick(microseconds):
		var point:=get_local_mouse_position(); var direction: int=-1 if point.y<thumb.position.y else 1
		var eligible:=Rect2(Vector2.ZERO,size).has_point(point) and not thumb.get_rect().has_point(point) and (page_direction==0 or page_direction==direction)
		if eligible: page_direction=direction; change(direction*visible_units())
func _notification(what: int) -> void:
	if what==NOTIFICATION_WM_WINDOW_FOCUS_OUT: cancel_drag(); stop_repeat()
func changed(_value: float) -> void: refresh()
func refresh() -> void:
	if closed or plan.is_empty() or not failure.is_empty(): return
	request_thumb()
	var origin: Vector2=-plan.bounds.position
	if rail.texture!=null:
		var rect:=image_rect(rail_key); rail.position=origin+rect.position; rail.size=rect.size
	if thumb.texture!=null:
		var rect:=image_rect(thumb_image_key); thumb.position=origin+rect.position+Layout.thumb_offset(plan,range_control.value,maximum()); thumb.size=rect.size
	up.disabled=not art_ready or range_control.value<=range_control.min_value; down.disabled=not art_ready or range_control.value>=maximum()
func request_thumb() -> void:
	if closed or plan.is_empty() or not failure.is_empty() or not layout_target.is_empty() or not layout_inflight.is_empty(): return
	# Godot exposes maximum position; original a4 stores one beyond it. The
	# caller's content/page coordinate mapping remains a separate parity audit.
	var desired:=ThumbRange.thumb(ceili(maximum())+1,visible_units(),float(plan.length))
	if float(desired.pixels)==requested_thumb_pixels: return
	requested_thumb_pixels=float(desired.pixels); pending_thumb_plan=plan.duplicate(true)
	pending_thumb_plan.thumb_pixels=requested_thumb_pixels; pending_thumb_plan.travel=maxf(0,float(plan.length)-requested_thumb_pixels)
	pending_thumb_plan.poses[1]={"clip":"thumbsize","time":float(desired.time)}
	thumb_key=art.request_model("scrollbar_simple","",{},0,"gui_scrollbar",pending_thumb_plan.poses)
	if thumb_key.is_empty(): failure="Original content-sized scrollbar thumb could not be requested"; return
	set_process(true)
	if art.textures.has(thumb_key): loaded(thumb_key,art.textures[thumb_key],art.bounds.get(thumb_key,{}))
func relayout(entry: Dictionary) -> void:
	if closed or plan.is_empty() or not failure.is_empty(): return
	cancel_drag(); stop_repeat(); layout_target=entry.duplicate(true); set_process(true)
func service_layout() -> void:
	if not layout_inflight.is_empty():
		if art.failed.has(layout_inflight.rail_key) or art.failed.has(layout_inflight.thumb_key): failure="Original resized scrollbar artwork failed"; return
		publish_layout(); return
	if layout_target.is_empty() or not art_ready or thumb_key!=thumb_image_key: return
	var next:=Layout.parse(source_models.scrollbar_simple,layout_target,source_models.pb_scrl_up,source_models.pb_scrl_down)
	layout_target={}
	if not str(next.error).is_empty(): failure=str(next.error); return
	var desired:=ThumbRange.thumb(ceili(maximum())+1,visible_units(),float(next.length))
	next.thumb_pixels=float(desired.pixels); next.travel=maxf(0,float(next.length)-float(desired.pixels)); next.poses[1]={"clip":"thumbsize","time":float(desired.time)}
	var rail_request: String=art.request_model("scrollbar_simple","",{},0,"gui_boxes_ingame",next.poses)
	var thumb_request: String=art.request_model("scrollbar_simple","",{},0,"gui_scrollbar",next.poses)
	if rail_request.is_empty() or thumb_request.is_empty(): failure="Original resized scrollbar could not be requested"; return
	layout_inflight={"plan":next,"rail_key":rail_request,"thumb_key":thumb_request}; layout_requests+=1
	publish_layout()
func publish_layout() -> void:
	if closed or layout_inflight.is_empty() or not art.textures.has(layout_inflight.rail_key) or not art.textures.has(layout_inflight.thumb_key): return
	plan=layout_inflight.plan; rail_key=layout_inflight.rail_key; thumb_key=layout_inflight.thumb_key; thumb_image_key=thumb_key
	rail.texture=art.textures[rail_key]; thumb.texture=art.textures[thumb_key]; pending_thumb_plan=plan; requested_thumb_pixels=float(plan.thumb_pixels); layout_inflight={}
	position=plan.attachment+plan.bounds.position; size=plan.bounds.size
	var origin: Vector2=-plan.bounds.position
	for name in ["up","down"]:
		var button: Button=up if name=="up" else down; var data: Dictionary=frame.button_geometry[button.get_instance_id()]
		data.offset=origin+plan.hooks[name]; data.rect=plan[name]; data.rect.position+=origin; frame.update_button(button.get_instance_id())
	refresh(); set_process(true)
func change(amount: float) -> void:
	if art_ready: range_control.value=clampf(range_control.value+amount,range_control.min_value,maximum())
func visible_units() -> int:
	return visible_units_override if visible_units_override>=0 else roundi(range_control.page)
func _gui_input(event: InputEvent) -> void:
	if not art_ready: return
	if event is InputEventMouseButton:
		if wheel_input(event): accept_event()
		elif event.button_index==MOUSE_BUTTON_LEFT:
			if event.pressed:
				stop_repeat()
				dragging=thumb.get_rect().has_point(event.position); drag_offset=event.position.y-thumb.position.y
				if dragging: drag_start_value=range_control.value
				if not dragging: begin_page()
			else: dragging=false; stop_repeat()
			accept_event()
	elif event is InputEventMouseMotion and dragging:
		if not event.button_mask&MOUSE_BUTTON_MASK_LEFT: cancel_drag(); stop_repeat(); return
		var start: float=(-plan.bounds.position+plan.hooks.min).y
		if float(plan.travel)>0: range_control.value=clampf((event.position.y-drag_offset-start)/float(plan.travel),0,1)*maximum()
		accept_event()
func snapshot() -> Dictionary:
	return {"art_ready":art_ready,"failure":failure,"dragging":dragging,"repeating":repeat_clock.active,"line_step":line_step,"value":range_control.value if is_instance_valid(range_control) else 0,"thumb_pixels":plan.get("thumb_pixels",0),"thumb_pending":thumb_key!=thumb_image_key,"layout_pending":not layout_target.is_empty() or not layout_inflight.is_empty(),"layout_requests":layout_requests,"native_only":true,"full_scrollbar_parity":false}
func close() -> void:
	if closed: return
	closed=true; cancel_drag(); stop_repeat()
	set_process(false)
	if is_instance_valid(art) and art.loaded.is_connected(loaded): art.loaded.disconnect(loaded)
	if is_instance_valid(frame) and is_instance_valid(frame.fonts) and frame.fonts.loaded.is_connected(font_loaded): frame.fonts.loaded.disconnect(font_loaded)
	if is_instance_valid(range_control):
		if range_control.value_changed.is_connected(changed): range_control.value_changed.disconnect(changed)
		if range_control.changed.is_connected(refresh): range_control.changed.disconnect(refresh)
	if is_instance_valid(scroll) and scroll.gui_input.is_connected(content_input): scroll.gui_input.disconnect(content_input)
	layout_target={}; layout_inflight={}; source_models={}
func _exit_tree() -> void: close()
