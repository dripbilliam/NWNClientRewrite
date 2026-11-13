extends Control
# Persistent replicated widgets. Cancel sends the received WORD type/group;
# only a server update removes an action. Local serials never go on the wire.
signal cancel_requested(action_id: int,group_id: int)
const Plan=preload("res://systems/native_data/action_queue_layout.gd")
const Assets=preload("res://systems/native_data/asset_service.gd")
const Painter=preload("res://systems/native_gui_painter.gd")
var rows: Array=[]
var buttons: Dictionary={}
var pending: Dictionary={}
var owner_ui
var assets
var painter
var models: Dictionary={}
var jobs: Dictionary={}
var definition: Dictionary={}
var requested:=false
var layout_ready:=false
var closed:=false
var epoch:=0
var failure:=""
func setup(owner) -> void:
	owner_ui=owner; mouse_filter=Control.MOUSE_FILTER_IGNORE; hide()
	painter=Painter.new(); add_child(painter); painter.art=owner_ui.art
	if is_instance_valid(owner_ui.owner_ui) and is_instance_valid(owner_ui.owner_ui.inventory): painter.borrow_tooltips(owner_ui.owner_ui.inventory.item_tooltips)
	owner_ui.art.loaded.connect(painter.art_loaded)
	assets=Assets.new(); add_child(assets); assets.configure(owner_ui.art.catalog); assets.maximum_workers=2
func _process(_delta: float) -> void:
	if closed or requested or layout_ready: return
	requested=true; set_process(false); assets.completed.connect(prepared)
	for name in Plan.RESOURCES:
		var id: int=assets.request(name,2002,"mdl-original")
		if id<0: failure=str(assets.failure); return
		jobs[id]=name
func prepared(id: int,result: Dictionary) -> void:
	if closed or not jobs.has(id): return
	var name: String=jobs[id]; jobs.erase(id)
	if not str(result.get("error","")).is_empty(): failure=name+": "+str(result.error); return
	models[name]=result.value
	if jobs.is_empty() and failure.is_empty(): activate()
func activate() -> void:
	definition=Plan.parse(models)
	if not str(definition.error).is_empty(): failure=str(definition.error); return
	layout_ready=true; present(rows)
func retire(serial: int) -> void:
	if not buttons.has(serial): return
	var button: Button=buttons[serial]; buttons.erase(serial); pending.erase(serial)
	if is_instance_valid(painter.tooltips): painter.tooltips.unregister_control(button)
	owner_ui.art.unbind(button.get_node("Icon"))
	var data: Dictionary=painter.button_geometry.get(button.get_instance_id(),{})
	for pair in data.get("styles",{}).values(): owner_ui.art.unbind(pair[0])
	remove_child(button); button.queue_free()
func reset() -> void:
	epoch+=1
	for serial in buttons.keys(): retire(int(serial))
	rows.clear(); pending.clear(); hide()
func identity(row: Dictionary) -> Array: return [int(row.type)&65535,int(row.group)&65535,bool(row.get("special",false))]
func present(entries: Array) -> void:
	if closed: return
	rows=entries.duplicate(true)
	for serial in buttons.keys():
		var current: Array=rows.filter(func(row):return int(row.widgetSerial)==int(serial))
		if current.is_empty() or buttons[serial].get_meta("action_identity")!=identity(current[0]): retire(int(serial))
	if not layout_ready: return
	for index in rows.size():
		var row: Dictionary=rows[index]; var serial:=int(row.widgetSerial); var entry:=Plan.slot(definition,index)
		if not buttons.has(serial):
			var button:=Button.new(); button.name="Action%d"%serial; add_child(button); buttons[serial]=button; button.set_meta("action_identity",identity(row))
			painter.button(button,entry,self,models,false)
			var icon:=TextureRect.new(); icon.name="Icon"; icon.mouse_filter=Control.MOUSE_FILTER_IGNORE; icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; icon.stretch_mode=TextureRect.STRETCH_SCALE; button.add_child(icon)
			button.pressed.connect(cancel.bind(serial,button,epoch))
		var button: Button=buttons[serial]; var icon: TextureRect=button.get_node("Icon")
		# Reordering retains the pressed widget and its pending state.
		move_child(button,index+2); painter.button_geometry[button.get_instance_id()].offset=entry.offset; painter.button_geometry[button.get_instance_id()].rect=entry.rect
		button.position=entry.rect.position; button.size=entry.rect.size; painter.update_button(button.get_instance_id())
		icon.position=entry.icon.position-entry.rect.position; icon.size=entry.icon.size
		var resource:=str(row.get("icon",""))
		if str(icon.get_meta("resource","<unbound>"))!=resource:
			icon.set_meta("resource",resource); icon.texture=null; owner_ui.art.bind(icon,resource)
		button.tooltip_text=str(row.get("label","")); button.modulate.a=0.5 if pending.has(serial) else 1.0
	visible=not rows.is_empty()
func cancel(serial: int,button: Button,captured_epoch: int) -> void:
	if closed or epoch!=captured_epoch or buttons.get(serial)!=button or pending.has(serial): return
	var current: Array=rows.filter(func(row):return int(row.widgetSerial)==serial)
	if current.is_empty() or identity(current[0])!=button.get_meta("action_identity"): return
	pending[serial]=true; button.modulate.a=0.5
	cancel_requested.emit(int(current[0].type)&65535,int(current[0].group)&65535)
func rejected() -> void:
	pending.clear()
	for button in buttons.values(): button.modulate.a=1.0
func blocks_pointer(point: Vector2) -> bool:
	if closed or not is_visible_in_tree(): return false
	for button in buttons.values():
		if button.get_global_rect().has_point(point): return true
	return false
func close() -> void:
	if closed: return
	reset(); closed=true
	if is_instance_valid(assets): assets.close()
	if is_instance_valid(painter): painter.close()
	jobs.clear(); models={}; owner_ui=null
func _exit_tree() -> void: close()
