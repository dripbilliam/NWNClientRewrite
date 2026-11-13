extends Control
signal prepared
signal finished
const Assets=preload("res://systems/native_data/asset_service.gd")
const Plan=preload("res://systems/native_data/video_options_layout.gd")
const Repeat=preload("res://systems/native_data/gui_repeat.gd")
var frame
var text_owner
var settings
var assets
var models: Dictionary={}
var jobs: Dictionary={}
var requested: Dictionary={}
var source: Dictionary={}
var definition: Dictionary={}
var buttons: Dictionary={}
var labels: Dictionary={}
var scope: Array=[]
var held: Dictionary={}
var revision:=0
var layout_ready:=false
var closed:=false
var failure:=""
var pending_scale:=1.0
var applied:=false
var mode_list: VBoxContainer
var mode_scroll: ScrollContainer
var scrollbar
var repeat_clock:=Repeat.new()
var arrow:=0
var mode_signature: Array=[]
var layout_path:="user://native-menu-layout.cfg"
var retained_position:=Vector2.INF
var dragging:=false
var drag_offset:=Vector2.ZERO
var modal_lease=preload("res://systems/native_data/modal_lease.gd").new()
func set_modal_order(order,surfaces=null,canvas: CanvasLayer=null) -> void:
	modal_lease.configure(self,order,surfaces,canvas);modal_lease.bind_input(self)
	if not modal_lease.admission_changed.is_connected(modal_admission_changed):modal_lease.admission_changed.connect(modal_admission_changed)
	if visible and not scope.is_empty() and modal_lease.ticket.is_empty():modal_lease.activate(scope)
func modal_admission_changed(admitted: bool) -> void:
	if not admitted:dragging=false;held.clear();stop_arrow()
func configure(painter,text,catalog,cache_path: String,service,placement_path: String="user://native-menu-layout.cfg") -> void:
	frame=painter; text_owner=text; settings=service; mouse_filter=Control.MOUSE_FILTER_STOP; hide()
	layout_path=placement_path
	var saved:=ConfigFile.new()
	if not layout_path.is_empty() and saved.load(layout_path)==OK:
		var value: Variant=saved.get_value("positions","video-options",Vector2.INF)
		if value is Vector2 and value.is_finite(): retained_position=value
	assets=Assets.new(); add_child(assets); assets.configure(catalog); assets.cache_directory=cache_path; assets.maximum_workers=2; assets.completed.connect(received)
	jobs[assets.request("options_vidmodes",2047,"gff")]="@layout"
	for name in ["scrollbar_simple","pb_scrl_up","pb_scrl_down"]: request_model(name)
	settings.changed.connect(settings_changed)
	get_viewport().size_changed.connect(place)
func request_model(name: String) -> void:
	if name.is_empty() or requested.has(name): return
	requested[name]=true; jobs[assets.request(name,2002,"actor-model")]=name
func request_tree(node: Dictionary) -> void:
	request_model(str(node.get("Obj_ResRef","")).to_lower())
	for child in node.get("Obj_ChildList",[]): request_tree(child)
func received(id: int,result: Dictionary) -> void:
	if closed or not jobs.has(id): return
	var name: String=jobs[id]; jobs.erase(id)
	if not str(result.get("error","")).is_empty(): failure=name+": "+str(result.error); return
	if name=="@layout": source=result.value.root; request_tree(source)
	else: models[name]=result.value
	if not jobs.is_empty() or source.is_empty() or not failure.is_empty(): return
	definition=Plan.parse(source,models)
	if not str(definition.error).is_empty(): failure=str(definition.error); return
	build()
func build() -> void:
	if closed or layout_ready: return
	size=definition.size; custom_minimum_size=size; frame.image(definition.resource,definition.main.rect,self)
	var scale_entry: Dictionary=definition.entries.intlabel
	frame.image(str(scale_entry.resource),scale_entry.rect,self)
	for tag in ["applybutton","okbutton","cancelbutton","xbutton","intupbutton","intdownbutton"]:
		var button: Button=frame.create_button(definition.entries[tag],self,models); buttons[tag]=button
		frame.button_caption(button,text_owner.raw({"strRef":int(definition.entries[tag].caption.get("Obj_StrRef",-1))}))
		button.button_down.connect(capture.bind(tag))
		button.button_up.connect(stop_arrow)
		if tag not in ["intupbutton","intdownbutton"]: button.pressed.connect(invoke.bind(tag))
	for tag in Plan.LABELS:
		var entry: Dictionary=definition.entries[tag]; var label: Label=frame.create_label(entry,self); label.clip_text=false
		labels[tag]=label
		if tag=="tguilabel": label.mouse_filter=Control.MOUSE_FILTER_STOP; label.gui_input.connect(title_input)
		label.text=text_owner.raw({"strRef":int(entry.caption.get("Obj_StrRef",-1))})
		if entry.get("floating",false): label.minimum_size_changed.connect(place_label.bind(tag)); place_label(tag)
		elif tag=="intlabel":
			label.position=entry.offset+entry.model.hooks.text-Vector2(0,9); label.size=Vector2(260,18)
	var entry: Dictionary=definition.entries.videomodelist
	frame.image(entry.resource,entry.rect,self)
	var lo: Vector2=entry.offset+entry.model.hooks.text0; var hi: Vector2=entry.offset+entry.model.hooks.text1
	mode_scroll=ScrollContainer.new(); add_child(mode_scroll); mode_scroll.position=lo.min(hi); mode_scroll.size=(hi-lo).abs(); mode_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	mode_list=VBoxContainer.new(); mode_list.add_theme_constant_override("separation",0); mode_scroll.add_child(mode_list)
	scrollbar=preload("res://systems/native_scrollbar.gd").new(); add_child(scrollbar); scrollbar.configure(frame,models,entry,mode_scroll)
	if not scrollbar.failure.is_empty(): failure=scrollbar.failure; return
	layout_ready=true; settings_changed(); place(); prepared.emit()
func place_label(tag: String) -> void:
	if closed or not labels.has(tag): return
	var label: Label=labels[tag]; var entry: Dictionary=definition.entries[tag]; var extent:=label.get_combined_minimum_size()
	label.size=extent; label.position=entry.anchor-extent*Vector2(float(entry.caption.get("AurString_AlignH",0)),float(entry.caption.get("AurString_AlignV",0)))
func place() -> void:
	if not layout_ready or closed: return
	var maximum: Vector2=(get_viewport_rect().size-size).max(Vector2.ZERO)
	position=retained_position.clamp(Vector2.ZERO,maximum) if retained_position.is_finite() else maximum*0.5
func title_input(event: InputEvent) -> void:
	if not modal_lease.admits():return
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		dragging=event.pressed
		if dragging: drag_offset=event.global_position-global_position; move_to_front()
func save_position() -> void:
	retained_position=position
	if layout_path.is_empty(): return
	var saved:=ConfigFile.new(); saved.load(layout_path); saved.set_value("positions","video-options",position); saved.save(layout_path)
func _input(event: InputEvent) -> void:
	if closed or not visible or not modal_lease.admits(): return
	if dragging and event is InputEventMouseMotion: position=(event.position-drag_offset).clamp(Vector2.ZERO,(get_viewport_rect().size-size).max(Vector2.ZERO))
	if dragging and event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed: dragging=false; save_position()
func show_page(value: Array) -> void:
	if closed or not layout_ready: return
	revision+=1; scope=value.duplicate(); held.clear(); stop_arrow(); pending_scale=settings.applied_scale; applied=false; refresh(); show(); place()
	modal_lease.activate(scope)
func capture(tag: String) -> void:
	if not modal_lease.admits():return
	held[tag]=revision;if_arrow(tag)
func stop_arrow() -> void: repeat_clock.stop(); arrow=0
func if_arrow(tag: String) -> void:
	if tag not in ["intupbutton","intdownbutton"]: return
	arrow=1 if tag=="intupbutton" else -1; step_scale(); repeat_clock.begin()
func step_scale() -> void:
	if closed or not is_visible_in_tree() or arrow==0 or not modal_lease.admits(): return
	var current: Dictionary=settings.current(); pending_scale=Plan.scale_step(pending_scale,arrow>0,float(current.minimum),float(current.maximum)); refresh()
func _process(delta: float) -> void:
	if not closed and is_visible_in_tree() and arrow!=0 and repeat_clock.tick(int(round(delta*1000000)),buttons.intupbutton.is_hovered() if arrow>0 else buttons.intdownbutton.is_hovered()): step_scale()
func invoke(tag: String) -> void:
	if closed or not is_visible_in_tree() or not modal_lease.admits() or int(held.get(tag,-1))!=revision: return
	held.erase(tag)
	if tag in ["cancelbutton","xbutton"]: finish_page(); return
	if tag in ["applybutton","okbutton"]:
		if not settings.apply_choice(pending_scale): return
		applied=true; pending_scale=settings.applied_scale; refresh()
		if tag=="okbutton": finish_page()
func finish_page() -> void:
	if closed: return
	if dragging: dragging=false; save_position()
	if applied: settings.commit()
	applied=false; revision+=1; held.clear(); stop_arrow();modal_lease.retire(); hide(); finished.emit()
func retire_scope() -> void:
	if visible: finish_page()
	else:modal_lease.retire()
	revision+=1; held.clear(); stop_arrow()
func settings_changed() -> void:
	if closed or not layout_ready: return
	if visible: pending_scale=minf(pending_scale,settings.maximum_scale)
	refresh()
func refresh() -> void:
	if not layout_ready or closed: return
	var current: Dictionary=settings.current()
	labels.currres.text="%s : %dx%d"%[text_owner.raw({"strRef":0x1b5a1 if current.windowed else 0x1b59c}),current.width,current.height]
	labels.currscale.text="%s : %.1f"%[text_owner.raw({"strRef":0x1b59d}),current.scale]
	labels.newres.text=text_owner.raw({"strRef":0x1b5a3 if current.windowed else 0x1b5a2})
	labels.intlabel.text="%s (%s:%.1f,%s:%.1f)"%[text_owner.raw({"strRef":0x1b59e}),text_owner.raw({"strRef":0x1b59f}),current.minimum,text_owner.raw({"strRef":0x1b5a0}),current.maximum]
	labels.intedit.text="%.1f"%pending_scale
	var rows: Array=settings.modes(); var signature: Array=[rows,settings.error,settings.query_ready]
	if signature==mode_signature: return
	mode_signature=signature.duplicate(true)
	for child in mode_list.get_children(): mode_list.remove_child(child); child.queue_free()
	for row in rows:
		var label:=Label.new(); mode_list.add_child(label); frame.font_style(label,definition.entries.videomodelist.caption); label.text=str(row.label); label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	if rows.is_empty():
		var label:=Label.new(); mode_list.add_child(label); frame.font_style(label,definition.entries.videomodelist.caption); label.text=settings.error if not settings.error.is_empty() else "Reading display modes…"; label.mouse_filter=Control.MOUSE_FILTER_IGNORE
func art_ready() -> bool:
	return not closed and layout_ready and failure.is_empty() and frame.art.waiting.is_empty() and frame.art.models.pending.is_empty() and not frame.art.models.active and frame.fonts.pending.is_empty() and scrollbar.art_ready
func snapshot() -> Dictionary:
	return {"ready":layout_ready,"failure":failure,"visible":visible,"pending_scale":pending_scale,"applied":applied,"mode_rows":mode_list.get_child_count() if mode_list!=null else 0,"mode_selection_enabled":false,"scope":scope.duplicate(),"jobs":jobs.size(),"native_only":true,"full_video_parity":false}
func _notification(what: int) -> void:
	if what==NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		stop_arrow()
		if dragging: dragging=false; save_position()
func close() -> void:
	if closed: return
	retire_scope(); closed=true
	modal_lease.close()
	if is_instance_valid(settings) and settings.changed.is_connected(settings_changed): settings.changed.disconnect(settings_changed)
	if is_instance_valid(scrollbar): scrollbar.close()
	if is_instance_valid(assets): assets.close()
	jobs.clear(); frame=null; text_owner=null; settings=null
func _exit_tree() -> void: close()
