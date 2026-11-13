extends Control
signal prepared
signal finished
const Assets=preload("res://systems/native_data/asset_service.gd")
const Plan=preload("res://systems/native_data/key_settings_layout.gd")
const Rules=preload("res://systems/native_data/keymap_rules.gd")
# Only rows with an installed native input/action path can accept edits.
# Remaining original actions stay visible with explicit unavailable tooltips.
const SUPPORTED=[37,38,39,40,41,42,62,63,65,66,67,68,69,70,87,88,89,90,91,92,93,97,107]
var frame
var text_owner
var bindings
var assets
var jobs: Dictionary={}
var requested: Dictionary={}
var sources: Dictionary={}
var models: Dictionary={}
var definition: Dictionary={}
var buttons: Dictionary={}
var row_buttons: Dictionary={}
var row_labels: Dictionary={}
var heading: Label
var notice: Label
var scroller: ScrollContainer
var body: Control
var scrollbar
var scope: Array=[]
var held: Dictionary={}
var selected: Dictionary={}
var ticket:=-1
var page:=0
var revision:=0
var layout_ready:=false
var closed:=false
var failure:=""
var storage:=""
var retained_position:=Vector2.INF
var dragging:=false
var drag_offset:=Vector2.ZERO
var modal_lease=preload("res://systems/native_data/modal_lease.gd").new()
var _entry_configuration: Dictionary={}
func set_modal_order(order,surfaces=null,canvas: CanvasLayer=null) -> void:
	modal_lease.configure(self,order,surfaces,canvas);modal_lease.bind_input(self)
	if not modal_lease.admission_changed.is_connected(modal_admission_changed):modal_lease.admission_changed.connect(modal_admission_changed)
	if visible and not scope.is_empty() and modal_lease.ticket.is_empty():modal_lease.activate(scope)
func modal_admission_changed(admitted: bool) -> void:
	if not admitted:
		dragging=false;held.clear()
		if is_instance_valid(bindings):bindings.stop_capture();refresh_bindings()
func configure(painter,text,catalog,cache_path: String,service,placement: String) -> void:
	frame=painter; text_owner=text; bindings=service; storage=placement; mouse_filter=Control.MOUSE_FILTER_STOP; hide()
	var saved:=ConfigFile.new()
	if not storage.is_empty() and saved.load(storage)==OK:
		var value: Variant=saved.get_value("positions","key-settings",Vector2.INF)
		if value is Vector2 and value.is_finite(): retained_position=value
	assets=Assets.new(); add_child(assets); assets.maximum_workers=2; assets.configure(catalog); assets.cache_directory=cache_path; assets.completed.connect(received)
	for name in ["options_key_pnl","options_key_page"]: jobs[assets.request(name,2047,"gff")]="@"+name
	for name in ["ctl_opt_btn_key","scrollbar_simple","pb_scrl_up","pb_scrl_down"]: request_model(name)
	bindings.edited.connect(refresh_bindings); bindings.cancel_requested.connect(discard); get_viewport().size_changed.connect(place)
func begin_entry_configuration(painter,text,catalog,cache_path: String,service,placement: String) -> Dictionary:
	if closed or not _entry_configuration.is_empty():return {}
	_entry_configuration={"phase":0,"painter":painter,"text":text,"catalog":catalog,"cache_path":cache_path,"service":service,"placement":placement}
	return _entry_configuration
func entry_configuration_phase(state: Dictionary) -> String:
	const PHASES=["initialize","asset_service","panel_request","page_request","button_request","scrollbar_request","scroll_up_request","scroll_down_request","signals","complete"]
	return PHASES[clampi(int(state.get("phase",0)),0,PHASES.size()-1)]
func entry_configuration_step(state: Dictionary) -> Dictionary:
	if state.is_empty() or not is_same(_entry_configuration,state) or closed or is_queued_for_deletion():return {"done":true,"accepted":false}
	match int(state.phase):
		0:
			frame=state.painter; text_owner=state.text; bindings=state.service; storage=str(state.placement); mouse_filter=Control.MOUSE_FILTER_STOP; hide()
			var saved:=ConfigFile.new()
			if not storage.is_empty() and saved.load(storage)==OK:
				var value: Variant=saved.get_value("positions","key-settings",Vector2.INF)
				if value is Vector2 and value.is_finite():retained_position=value
		1:
			assets=Assets.new(); add_child(assets); assets.maximum_workers=2; assets.configure(state.catalog); assets.cache_directory=str(state.cache_path); assets.completed.connect(received)
		2:jobs[assets.request("options_key_pnl",2047,"gff")]="@options_key_pnl"
		3:jobs[assets.request("options_key_page",2047,"gff")]="@options_key_page"
		4:request_model("ctl_opt_btn_key")
		5:request_model("scrollbar_simple")
		6:request_model("pb_scrl_up")
		7:request_model("pb_scrl_down")
		8:
			bindings.edited.connect(refresh_bindings); bindings.cancel_requested.connect(discard); get_viewport().size_changed.connect(place)
		9:
			_entry_configuration={}
			return {"done":true,"accepted":true}
	if not is_same(_entry_configuration,state) or closed or is_queued_for_deletion():return {"done":true,"accepted":false}
	state.phase=int(state.phase)+1
	return {"done":false,"accepted":false}
func finish_entry_configuration() -> void:
	# Keep the first publication behind the menu's modal and callback binds.
	if closed or not _entry_configuration.is_empty() or sources.size()!=2 or not jobs.is_empty() or not failure.is_empty() or layout_ready:return
	definition=Plan.parse(sources,models)
	if not str(definition.error).is_empty():failure=str(definition.error)
	else:build()
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
	if name.begins_with("@"):
		sources[name.substr(1)]=result.value.root; request_tree(result.value.root)
	else: models[name]=result.value
	if not _entry_configuration.is_empty() or sources.size()!=2 or not jobs.is_empty() or not failure.is_empty(): return
	definition=Plan.parse(sources,models)
	if not str(definition.error).is_empty(): failure=str(definition.error); return
	build()
func build() -> void:
	if closed or layout_ready: return
	size=definition.size; custom_minimum_size=size
	frame.image(definition.resource,definition.main.rect,self); frame.image(definition.page.resource,definition.page.rect,self)
	for tag in Plan.PANEL_ACTIONS.keys()+["closebutton","cancelbutton","defaultbutton"]:
		var entry: Dictionary=definition.entries[tag] if definition.entries.has(tag) else definition.page.entries[tag]
		var tab: bool=str(tag).begins_with("tab")
		var button: Button=frame.create_button(entry,self,models,tab); buttons[tag]=button
		frame.button_caption(button,text_owner.raw({"strRef":int(entry.get("caption",{}).get("Obj_StrRef",-1))}))
		button.button_down.connect(capture.bind(tag))
		button.pressed.connect(invoke.bind(tag))
	buttons.tab1.tooltip_text="Game actions and editable hotbar keys"
	heading=frame.create_label(definition.entries.tguilabel,self,text_owner.raw({"strRef":10413})); heading.clip_text=false; heading.size=heading.get_combined_minimum_size(); heading.mouse_filter=Control.MOUSE_FILTER_STOP; heading.gui_input.connect(title_input)
	scroller=ScrollContainer.new(); add_child(scroller); scroller.position=definition.clip.position; scroller.size=definition.clip.size; scroller.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; scroller.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_SHOW_NEVER
	body=Control.new(); scroller.add_child(body); body.mouse_filter=Control.MOUSE_FILTER_IGNORE
	scrollbar=preload("res://systems/native_scrollbar.gd").new(); add_child(scrollbar); scrollbar.configure(frame,models,definition.page.entries.buttonlist,scroller,float(definition.row.step.y))
	if not scrollbar.failure.is_empty(): failure=scrollbar.failure; return
	notice=Label.new(); add_child(notice); notice.mouse_filter=Control.MOUSE_FILTER_IGNORE; notice.position=Vector2(4,size.y+4); frame.font_style(notice,{"AurString_Font":"fnt_galahad14"}); notice.add_theme_color_override("font_shadow_color",Color.BLACK)
	layout_ready=true; place(); prepared.emit()
func place() -> void:
	if closed or not layout_ready: return
	var maximum: Vector2=(get_viewport_rect().size-size).max(Vector2.ZERO)
	position=retained_position.clamp(Vector2.ZERO,maximum) if retained_position.is_finite() else maximum*0.5
func show_page(value: Array) -> void:
	if closed or not layout_ready or bindings.blocked(): return
	revision+=1; scope=value.duplicate(); ticket=bindings.begin(); selected.clear(); held.clear(); page=0; render_rows(); show(); place(); move_to_front()
	modal_lease.activate(scope)
func capture(tag: String) -> void:
	if modal_lease.admits():held[tag]=revision
func key_id(kind: String,index: int) -> String: return kind+":"+str(index)
func render_rows() -> void:
	if not bindings.valid_transaction(ticket): return
	for child in body.get_children(): body.remove_child(child); child.queue_free()
	row_buttons.clear(); row_labels.clear()
	for index in 4: buttons["tab"+str(index)].set_pressed_no_signal(index==page)
	var rows: Array=[]
	for row in bindings.pending.normal.rows:
		if int(row.page)==page: rows.append({"kind":"normal","index":int(row.action),"text":text_owner.raw({"strRef":int(row.strRef)})})
	if page==1:
		rows.append({"kind":"heading","text":"Hotbar key bindings"})
		for index in 36: rows.append({"kind":"hotbar","index":index,"text":"Hotbar %d · Slot %d"%[index/12+1,index%12+1]})
	var offset: Vector2=definition.row.first-definition.clip.position
	var step: Vector2=definition.row.step
	for index in rows.size():
		var source: Dictionary=rows[index]; var origin: Vector2=offset+step*index; var rect: Rect2=definition.row.rect; rect.position+=origin
		if source.kind=="heading":
			var label: Label=frame.create_label({"rect":rect,"caption":{"AurString_Font":"fnt_galahad14","AurString_AlignV":0.5}},body); label.text=source.text; continue
		var id:=key_id(source.kind,int(source.index)); var button:=Button.new(); body.add_child(button)
		frame.button(button,{"resource":definition.row.resource,"rect":rect,"offset":origin,"caption":{"AurString_Font":"fnt_galahad14"}},body,models,false,true); button.toggle_mode=true
		button.disabled=source.kind=="normal" and int(source.index) not in SUPPORTED
		button.tooltip_text="This action is not available in the native client yet." if button.disabled else "Click to bind. Right-click to clear." if source.kind=="hotbar" else "Click to bind."
		button.button_down.connect(capture.bind(id))
		button.pressed.connect(select_row.bind(source.kind,int(source.index),id))
		if source.kind=="hotbar": button.gui_input.connect(clear_row.bind(int(source.index)))
		var captions: Dictionary={}
		for name in ["text","binding"]:
			var label:=Label.new(); button.add_child(label); label.mouse_filter=Control.MOUSE_FILTER_IGNORE; label.clip_text=name=="text"; frame.font_style(label,{"AurString_Font":"fnt_galahad14"}); label.add_theme_color_override("font_shadow_color",Color.BLACK); label.add_theme_constant_override("shadow_offset_x",1); label.add_theme_constant_override("shadow_offset_y",1); captions[name]=label
		captions.text.text=str(source.text); row_buttons[id]=button; row_labels[id]=captions
		for label in captions.values(): label.minimum_size_changed.connect(align_row.bind(id))
		button.set_meta("key_kind",source.kind); button.set_meta("key_index",int(source.index))
	body.custom_minimum_size=Vector2(definition.clip.size.x,maxf(definition.clip.size.y,offset.y+step.y*rows.size()))
	scroller.scroll_vertical=0; refresh_bindings()
func align_row(id: String) -> void:
	if closed or not row_buttons.has(id): return
	var button: Button=row_buttons[id]; var labels: Dictionary=row_labels[id]; var origin: Vector2=-definition.row.rect.position
	var extent: Vector2=labels.binding.get_combined_minimum_size(); labels.binding.size=extent; labels.binding.position=origin+definition.row.binding.anchor-extent*definition.row.binding.align
	var height: float=maxf(17,labels.text.get_combined_minimum_size().y)
	labels.text.position=origin+definition.row.text.anchor-Vector2(0,height*0.5); labels.text.size=Vector2(maxf(0,definition.row.binding.anchor.x-extent.x-definition.row.text.anchor.x-8),height)
func refresh_bindings() -> void:
	if closed or not layout_ready or not bindings.valid_transaction(ticket): return
	for id in row_buttons:
		var button: Button=row_buttons[id]; var kind: String=button.get_meta("key_kind"); var index: int=button.get_meta("key_index"); var capture: bool=bindings.capturing and bindings.capture_kind==kind and bindings.capture_index==index
		var caption: String=Rules.key_label(int(bindings.pending.normal.values.get(index,0)),func(ref):return text_owner.raw({"strRef":ref})) if kind=="normal" else bindings.caption(bindings.pending.hotbar[index],func(ref):return text_owner.raw({"strRef":ref}))
		# A key name is a single caption. The original Right Arrow TLK entry
		# ends with a line terminator; a Godot Label would otherwise reserve an
		# empty second line and lift its right/bottom anchored text into row1.
		row_labels[id].binding.text="" if capture else caption.trim_suffix("\n").trim_suffix("\r")
		row_labels[id].text.add_theme_color_override("font_color",Color(0.8,0.1,0.1) if capture else Color(0.6,0.6,0.6) if button.disabled else Color.WHITE)
		row_labels[id].binding.add_theme_color_override("font_color",Color(0.6,0.6,0.6) if button.disabled else Color.WHITE)
		button.set_pressed_no_signal(str(selected.get(page,""))==id); align_row(id)
	if is_instance_valid(notice): notice.text=bindings.failure
func select_row(kind: String,index: int,id: String) -> void:
	if closed or not visible or not modal_lease.admits() or int(held.get(id,-1))!=revision or not bindings.valid_transaction(ticket): return
	selected[page]=id; bindings.start_capture(kind,index,ticket); refresh_bindings()
func clear_row(event: InputEvent,index: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_RIGHT and visible and modal_lease.admits():
		bindings.unbind("hotbar",index,ticket); row_buttons[key_id("hotbar",index)].accept_event()
func invoke(tag: String) -> void:
	if closed or not visible or not modal_lease.admits() or int(held.get(tag,-1))!=revision: return
	held.erase(tag)
	if tag.begins_with("tab"):
		bindings.stop_capture(); page=int(tag.substr(3)); render_rows()
	elif tag=="defaultbutton": selected.clear(); bindings.defaults(ticket); render_rows()
	elif tag=="cancelbutton": finish_page(false)
	elif tag in ["closebutton","xbutton"]: finish_page(true)
func discard() -> void: finish_page(false)
func finish_page(commit: bool=false) -> void:
	if closed or not visible: return
	if commit and is_instance_valid(bindings) and not bindings.commit(ticket): refresh_bindings(); return
	if not commit and is_instance_valid(bindings): bindings.retire()
	if dragging: dragging=false; save_position()
	revision+=1; held.clear();modal_lease.retire(); hide(); finished.emit()
func retire_scope() -> void:
	if visible: finish_page(false)
	elif is_instance_valid(bindings): bindings.retire()
	modal_lease.retire()
	revision+=1; held.clear()
func title_input(event: InputEvent) -> void:
	if not modal_lease.admits():return
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		dragging=event.pressed
		if dragging: drag_offset=event.global_position-global_position; move_to_front()
func save_position() -> void:
	retained_position=position
	if storage.is_empty(): return
	var saved:=ConfigFile.new(); saved.load(storage); saved.set_value("positions","key-settings",position); saved.save(storage)
func _input(event: InputEvent) -> void:
	if closed or not visible or not modal_lease.admits(): return
	if dragging and event is InputEventMouseMotion: position=(event.position-drag_offset).clamp(Vector2.ZERO,(get_viewport_rect().size-size).max(Vector2.ZERO))
	if dragging and event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed: dragging=false; save_position()
func art_ready() -> bool:
	return layout_ready and failure.is_empty() and frame.art.waiting.is_empty() and frame.art.models.pending.is_empty() and not frame.art.models.active and frame.fonts.pending.is_empty() and scrollbar.art_ready
func snapshot() -> Dictionary:
	return {"ready":layout_ready,"failure":failure,"page":page,"visible":visible,"rows":row_buttons.size(),"capturing":bindings.capturing,"hotbar_slots":36,"unsupported_actions":bindings.active.get("normal",{}).get("rows",[]).filter(func(row):return int(row.action) not in SUPPORTED).size(),"native_only":true,"full_key_settings_parity":false}
func _notification(what: int) -> void:
	if what==NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		if is_instance_valid(bindings): bindings.stop_capture(); refresh_bindings()
		if dragging: dragging=false; save_position()
func close() -> void:
	if closed: return
	_entry_configuration={}
	retire_scope(); closed=true
	modal_lease.close()
	if is_instance_valid(bindings):
		if bindings.edited.is_connected(refresh_bindings): bindings.edited.disconnect(refresh_bindings)
		if bindings.cancel_requested.is_connected(discard): bindings.cancel_requested.disconnect(discard)
	if is_instance_valid(scrollbar): scrollbar.close()
	if is_instance_valid(assets): assets.close()
	jobs.clear(); models.clear(); sources.clear()
func _exit_tree() -> void: close()
