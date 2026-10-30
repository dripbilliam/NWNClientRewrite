extends Node
const Assets=preload("res://systems/native_data/asset_service.gd")
const Plan=preload("res://systems/native_data/area_map_layout.gd")
const Panbar=preload("res://systems/native_map_panbar.gd")
const NoteEditor=preload("res://systems/native_map_note_editor.gd")
const STATIC=["ctl_map_pinsrc","ctl_map_zoomin","ctl_map_zoomout","ctl_btn_x","ctl_map_panbar","pnl_lvlup_sum","ctl_lvlup_sum","ctl_btn_pre_116","scrollbar_simple","pb_scrl_up","pb_scrl_down"]
class PinSource extends Button:
	var owner_ref: WeakRef
	func _get_drag_data(_position: Vector2) -> Variant:
		var skin: Object=owner_ref.get_ref()
		if not is_instance_valid(skin) or not skin.layout_ready or not skin.panel.wanted: return null
		var preview:=TextureRect.new(); preview.texture=skin.desktop.art.textures.get("ir_buy"); preview.custom_minimum_size=Vector2(32,32); preview.size=Vector2(32,32); preview.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; preview.mouse_filter=Control.MOUSE_FILTER_IGNORE; set_drag_preview(preview)
		return {"kind":"native-map-note","viewId":skin.panel.view_id,"scope":skin.scope()}
var desktop
var panel
var frame
var assets
var editor
var models: Dictionary={}
var layouts: Dictionary={}
var jobs: Dictionary={}
var requested_names: Dictionary={}
var image_requests: Dictionary={}
var requested:=false
var layout_ready:=false
var closed:=false
var failure:=""
var level:=1
var displayed_level:=-1
var definition: Dictionary={}
var stage: Control
var main_image: TextureRect
var drag_header: Control
var buttons: Dictionary={}
var bars: Array=[]
var auto_center:=true
var context: Array=[]
var serial:=0
var pending: Dictionary={}
var overlays: Dictionary={}
var shape_signature: Array=[]
var claimed_adds: Dictionary={}
func configure(owner,catalog,cache_path: String) -> void:
	desktop=owner; panel=owner.area_map; panel.native_skin=self; frame=owner.owner_ui.inventory.frame_skin
	assets=Assets.new(); add_child(assets); assets.configure(catalog); assets.cache_directory=cache_path; assets.maximum_workers=2; assets.completed.connect(prepared)
	frame.art.loaded.connect(loaded); panel.board.pin_action.connect(pin_selected); panel.board.panned.connect(pan); panel.board.note_dropped.connect(drop_note); panel.board.drag_source=valid_drag
func scope() -> Array: return [desktop.generation,desktop.area_id,desktop.actor_id]
func request_model(name: String) -> void:
	if requested_names.has(name): return
	requested_names[name]=true; jobs[assets.request(name,2002,"actor-model")]=name
func _process(_delta: float) -> void:
	if closed: return
	observe_pending()
	if not panel.wanted or panel.board.columns<1: return
	for request in image_requests.values():
		if frame.art.failed.has(request.key): report_failure("Original map artwork could not be prepared: "+str(request.key)); return
	if layout_ready and shape_signature==[panel.board.columns,panel.board.rows,level]:
		if auto_center: follow_player()
		return
	if not requested:
		requested=true
		for name in STATIC: request_model(name)
		jobs[assets.request("map_pin_text",2047,"gff")]="@map_pin_text"
		var preview:=TextureRect.new(); add_child(preview); preview.hide(); desktop.art.bind(preview,"ir_buy")
	var target:=Plan.frame(panel.board.columns,panel.board.rows,level,Vector2i(21,24))
	if not str(target.error).is_empty(): report_failure(str(target.error)); return
	request_model(target.resource)
	if not failure.is_empty() or not STATIC.all(func(name):return models.has(name)) or not layouts.has("map_pin_text") or not models.has(target.resource): return
	if not is_instance_valid(editor):
		editor=NoteEditor.new(); add_child(editor); editor.configure(self,layouts.map_pin_text,models)
		if not editor.failure.is_empty(): report_failure(editor.failure); return
	if definition.get("resource","")!=target.resource or displayed_level!=level: publish(target)
	if layout_ready and auto_center: follow_player()
func prepared(id: int,result: Dictionary) -> void:
	if closed or not jobs.has(id): return
	var name: String=jobs[id]; jobs.erase(id)
	if not str(result.get("error","")).is_empty(): report_failure(name+": "+str(result.error)); return
	if name.begins_with("@"): layouts[name.substr(1)]=result.value.root
	else: models[name]=result.value
func picture(parent: Control) -> TextureRect:
	var value:=TextureRect.new(); parent.add_child(value); value.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; value.stretch_mode=TextureRect.STRETCH_SCALE; value.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var id:=value.get_instance_id(); value.tree_exiting.connect(func():image_requests.erase(id),CONNECT_ONE_SHOT); return value
func image(value: TextureRect,resource: String,rect: Rect2) -> void:
	value.position=rect.position; value.size=rect.size
	var key: String=frame.art.request_model(resource,""); image_requests[value.get_instance_id()]={"owner":weakref(value),"key":key}
	if frame.art.textures.has(key): value.texture=frame.art.textures[key]
func loaded(key: String,texture: Texture2D,_bounds: Dictionary) -> void:
	if closed: return
	for entry in image_requests.values():
		var value: Object=entry.owner.get_ref()
		if entry.key==key and is_instance_valid(value): value.texture=texture
func publish(target: Dictionary) -> void:
	var next:=Plan.parse(target,models)
	if not str(next.error).is_empty(): report_failure(str(next.error)); return
	definition=next; displayed_level=level; panel.board.native_view=true; panel.board.zoom=Plan.PIXELS[level]; panel.board.resize_map()
	panel.window_column.hide(); panel.add_theme_stylebox_override("panel",StyleBoxEmpty.new()); panel.custom_minimum_size=definition.size; panel.size=definition.size
	if not is_instance_valid(stage):
		stage=Control.new(); panel.add_child(stage); stage.mouse_filter=Control.MOUSE_FILTER_IGNORE
		main_image=picture(stage); main_image.modulate.a=0.5
		panel.scroll.reparent(stage); panel.scroll.custom_minimum_size=Vector2.ZERO; panel.scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_SHOW_NEVER; panel.scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_SHOW_NEVER
		drag_header=Control.new(); stage.add_child(drag_header); drag_header.mouse_filter=Control.MOUSE_FILTER_STOP; drag_header.gui_input.connect(panel._title_input)
		for hook in Plan.TOOLS:
			var button: Button=PinSource.new() if hook=="pinbutton" else panel.close_button if hook=="xbutton" else Button.new()
			if button.get_parent()==null: stage.add_child(button)
			if hook=="pinbutton": button.owner_ref=weakref(self)
			frame.button(button,definition.controls[hook],stage,models,false); buttons[hook]=button
			if int(definition.controls[hook].tooltip)>=0: button.tooltip_text=desktop.owner_ui.text.raw({"strRef":int(definition.controls[hook].tooltip)})
		buttons.upbutton.pressed.connect(func():set_level(level+1)); buttons.downbutton.pressed.connect(func():set_level(level-1))
		for horizontal in [false,true]:
			var bar:=Panbar.new(); stage.add_child(bar); bar.configure(frame,models.ctl_map_panbar,panel.scroll.get_h_scroll_bar() if horizontal else panel.scroll.get_v_scroll_bar(),horizontal); bars.append(bar)
	stage.size=definition.size; image(main_image,definition.resource,Rect2(Vector2.ZERO,definition.size))
	panel.scroll.position=definition.viewport.position; panel.scroll.size=definition.viewport.size
	drag_header.position=Vector2(55,1); drag_header.size=Vector2(maxf(1,definition.size.x-73),17)
	for hook in buttons:
		var data: Dictionary=frame.button_geometry[buttons[hook].get_instance_id()]; data.offset=definition.controls[hook].offset; data.rect=definition.controls[hook].rect; frame.update_button(buttons[hook].get_instance_id())
	buttons.upbutton.disabled=not target.zoom_in; buttons.downbutton.disabled=not target.zoom_out
	bars[0].arrange(definition.vertical,definition.viewport.size.y); bars[1].arrange(definition.horizontal,definition.viewport.size.x)
	layout_ready=true; shape_signature=[panel.board.columns,panel.board.rows,level]; auto_center=true; panel._clamp(); desktop.prepare_map_level(level)
func map_changed() -> void:
	var now:=scope()
	if context!=now: pending.clear(); overlays.clear(); claimed_adds.clear(); context=now
	close_editor(); auto_center=true; shape_signature=[]
	if layout_ready: panel.board.native_view=true; panel.board.zoom=Plan.PIXELS[level]; panel.board.resize_map(); desktop.prepare_map_level(level)
func reset_view() -> void:
	pending.clear(); overlays.clear(); claimed_adds.clear(); context=[]; close_editor(); auto_center=true; shape_signature=[]
func report_failure(reason: String) -> void:
	if not failure.is_empty(): return
	failure=reason; panel.note.text=reason
	if is_instance_valid(desktop.target_prompt): desktop.target_prompt.text=reason; desktop.target_prompt.show()
func set_zoom(pixels: int) -> void:
	var desired:=Plan.PIXELS.find(pixels)
	if desired>=0: set_level(desired)
func set_level(value: int) -> void:
	level=clampi(value,0,2)
func follow_player() -> void:
	if panel.board.point.is_empty(): return
	var center: Vector2=panel.board.center(panel.board.point)
	# Original894af0 keeps the marker within the central20% of the view.
	var visible: Vector2=panel.scroll.size; var current:=Vector2(panel.scroll.scroll_horizontal,panel.scroll.scroll_vertical)
	for axis in 2:
		var difference: float=center[axis]-(current[axis]+visible[axis]/2)
		var limit: float=visible[axis]*0.1
		if absf(difference)>limit: current[axis]+=difference-signf(difference)*limit
	panel.scroll.scroll_horizontal=roundi(current.x); panel.scroll.scroll_vertical=roundi(current.y)
func pan(relative: Vector2) -> void:
	if not layout_ready: return
	auto_center=false; panel.scroll.scroll_horizontal-=roundi(relative.x); panel.scroll.scroll_vertical-=roundi(relative.y)
func valid_drag(data: Dictionary) -> bool:
	return panel.wanted and layout_ready and data.get("kind","")=="native-map-note" and int(data.get("viewId",-1))==panel.view_id and data.get("scope",[])==scope()
func drop_note(at: Vector2,data: Dictionary) -> void:
	if not valid_drag(data) or not editor.layout_ready: return
	var local: Vector2=at-panel.board.origin()-Vector2(panel.board.columns,panel.board.rows)*panel.board.zoom/2.0
	var world:=Plan.local_to_world(panel.board.columns,panel.board.rows,panel.board.zoom,[local.x/100.0,-local.y/100.0,0])
	editor.open({"viewId":panel.view_id,"scope":scope(),"type":-1,"position":world,"text":""})
func pin_selected(pin: Dictionary) -> void:
	if not panel.wanted or not layout_ready or not pin.get("visible",false): return
	if pin.get("scope",[])!=scope() or int(pin.get("viewId",-1))!=panel.view_id or pin not in panel.board.pins: return
	if int(pin.get("type",-1))==1: editor.open({"viewId":panel.view_id,"scope":scope(),"type":1,"reference":pin.reference,"position":pin.position,"text":pin.text})
	elif int(pin.get("type",-1))==0: send({"operation":"click","reference":int(pin.reference),"editorSerial":-1})
func send(value: Dictionary) -> void:
	serial+=1; var operation:=value.duplicate(true); operation.scope=scope(); operation.requestId=serial; operation.deadline=Time.get_ticks_msec()+15000; operation.sent=false; operation.before=panel.board.pins.map(func(pin):return pin.get("key","")); pending[serial]=operation
	var message: Dictionary={"kind":"native-map","operation":value.operation,"requestId":serial}
	for key in ["reference","position","text"]:
		if value.has(key): message[key]=value[key]
	desktop.command(message)
func submit_note(value: Dictionary) -> bool:
	if not panel.wanted or not layout_ready or value.get("scope",[])!=scope() or int(value.get("viewId",-1))!=panel.view_id: return false
	send(value); return true
func receive(message: Dictionary) -> void:
	var id:=int(message.get("requestId",-1))
	if not pending.has(id): return
	var operation: Dictionary=pending[id]
	if operation.scope!=[int(message.get("generation",-1)),int(message.get("areaId",-1)),int(message.get("actorId",-1))] or operation.scope!=scope(): return
	if not message.get("accepted",false):
		pending.erase(id)
		if is_instance_valid(editor) and int(operation.get("editorSerial",-1))==editor.serial: editor.reject(str(message.get("text","Map note could not be sent.")))
		else: desktop.target_prompt.text=str(message.get("text","Map action could not be sent.")); desktop.target_prompt.show()
		return
	operation.sent=true
	if operation.operation=="add": return # Only received Added is confirmation.
	if operation.operation in ["change","delete"]:
		overlays[str(operation.reference)]=operation.duplicate(true); desktop.signatures.erase("map-exploration"); desktop.dirty=true
	if is_instance_valid(editor) and int(operation.get("editorSerial",-1))==editor.serial: editor.cancel()
	pending.erase(id)
func apply_overlays(rows: Array) -> Array:
	var result: Array=[]; var present: Dictionary={}
	for original in rows:
		var row: Dictionary=original
		if int(row.get("type",-1))==1: present[str(row.reference)]=true
		if int(row.get("type",-1))==1 and overlays.has(str(row.reference)):
			var operation: Dictionary=overlays[str(row.reference)]
			if operation.operation=="delete": continue
			if row.text==operation.text: overlays.erase(str(row.reference))
			else: row=row.duplicate(true); row.text=operation.text; row.rich=desktop.owner_ui.text.rich({"text":row.text},desktop.actor_id); row.unconfirmed=true
		result.append(row)
	for key in overlays.keys():
		if not present.has(key): overlays.erase(key)
	return result
func observe_pending() -> void:
	for id in pending.keys():
		var operation: Dictionary=pending[id]
		if operation.scope!=scope(): pending.erase(id); continue
		if operation.operation!="add": continue
		var confirmed:=false
		var confirmed_key:=""
		for pin in panel.board.pins:
			if int(pin.get("type",-1))!=1 or pin.get("key","") in operation.before or claimed_adds.has(pin.get("key","")) or pin.get("text","")!=operation.text or pin.get("position",[]).size()!=3: continue
			confirmed=true
			for axis in 3:
				if absf(float(pin.position[axis])-float(operation.position[axis]))>0.0001: confirmed=false
			if confirmed: confirmed_key=str(pin.key); break
		if confirmed:
			claimed_adds[confirmed_key]=id; pending.erase(id)
			if is_instance_valid(editor) and int(operation.get("editorSerial",-1))==editor.serial: editor.cancel()
		elif Time.get_ticks_msec()>=int(operation.deadline) and not operation.get("uncertain",false):
			operation.uncertain=true
			if is_instance_valid(editor) and int(operation.get("editorSerial",-1))==editor.serial: editor.uncertain("The server has not confirmed this note. Close this window to keep waiting.")
func close_editor() -> void:
	if is_instance_valid(editor): editor.cancel()
func blocks_pointer(point: Vector2) -> bool:
	return (panel.visible and panel.get_global_rect().has_point(point)) or (is_instance_valid(editor) and is_instance_valid(editor.panel) and editor.panel.visible and editor.panel.get_global_rect().has_point(point))
func snapshot() -> Dictionary:
	return {"ready":layout_ready,"failure":failure,"pending_assets":jobs.size(),"level":level,"displayed_level":displayed_level,"resource":definition.get("resource",""),"pending_actions":pending.size(),"claimed_adds":claimed_adds.size(),"unconfirmed_edits":overlays.size(),"native_only":true,"full_map_parity":false}
func close() -> void:
	if closed: return
	closed=true; pending.clear(); overlays.clear(); claimed_adds.clear(); image_requests.clear(); assets.close()
	for bar in bars: bar.close()
	if is_instance_valid(editor): editor.close()
	if frame.art.loaded.is_connected(loaded): frame.art.loaded.disconnect(loaded)
