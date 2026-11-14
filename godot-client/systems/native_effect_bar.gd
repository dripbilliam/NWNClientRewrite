extends Node
# CPanelPlayerStateBar: source40px leftward widgets; normal/flash from raw state.
const Assets=preload("res://systems/native_data/asset_service.gd")
const Plan=preload("res://systems/native_data/effect_bar_layout.gd")
const Icon=preload("res://systems/native_effect_icon.gd")
var panel
var art
var assets
var models: Dictionary={}
var jobs: Dictionary={}
var definition: Dictionary={}
var stage: Control
var notice: Label
var requested:=false
var layout_ready:=false
var closed:=false
var epoch:=0
var failure:=""
var flashing: Array=[]
var admission_pending:=false
var tooltips
func configure(target,owner,catalog,cache_path: String,tooltip_scope=null) -> void:
	panel=target; panel.native_skin=self; panel.hide_tip(); panel.scroll.hide(); art=owner
	tooltips=tooltip_scope
	stage=Control.new(); panel.add_child(stage); stage.mouse_filter=Control.MOUSE_FILTER_IGNORE
	notice=Label.new(); panel.add_child(notice); notice.mouse_filter=Control.MOUSE_FILTER_IGNORE; notice.add_theme_color_override("font_color",Color("f0d6a5")); notice.hide()
	art.loaded.connect(art_loaded)
	assets=Assets.new(); add_child(assets); assets.configure(catalog); assets.cache_directory=cache_path; assets.maximum_workers=2; assets.completed.connect(prepared)
	panel.get_viewport().size_changed.connect(place)
func _process(delta: float) -> void:
	if closed: return
	if not requested and not layout_ready:
		requested=true
		for name in Plan.RESOURCES:
			var id: int=assets.request(name,2002,"actor-model" if name=="ctl_ig_plreffect" else "mdl-original")
			if id<0: failure=str(assets.failure); set_process(false); return
			jobs[id]=name
		return
	if not layout_ready: return
	if admission_pending:
		try_admit()
		if admission_pending: return
	if not panel.is_visible_in_tree(): return
	for button in flashing:
		var icon: Control=button.get_node("Icon")
		icon.advance(delta)
func prepared(id: int,result: Dictionary) -> void:
	if closed or not jobs.has(id): return
	var name: String=jobs[id]; jobs.erase(id)
	if not str(result.get("error","")).is_empty(): failure=name+": "+str(result.error); set_process(false); return
	models[name]=result.value
	if jobs.is_empty() and failure.is_empty(): activate()
func activate() -> void:
	definition=Plan.parse(models)
	if not str(definition.error).is_empty(): failure=str(definition.error); set_process(false); return
	layout_ready=true; present(); place()
func art_loaded(_key: String,_texture: Texture2D,_bounds: Dictionary) -> void:
	if admission_pending and not closed: call_deferred("try_admit")
func try_admit() -> void:
	if closed or not admission_pending: return
	for id in panel.buttons:
		var icon=panel.buttons[id].get_node("Icon")
		if icon.art_ready(): continue
		var resource: String=str(panel.rows[id].resource).to_lower()
		var border: String=""
		for part in definition.parts:
			if part.resource!="gui_replace01": border=str(part.resource).to_lower()
		if art.failed.has(resource) or (not border.is_empty() and art.failed.has(border)):
			failure="Original effect icon unavailable: "+(resource if art.failed.has(resource) else border)
			panel.art_error=failure; admission_pending=false; stage.hide(); notice.text=failure; notice.show(); panel.show(); set_process(false); return
		return
	admission_pending=false; panel.art_error=""; failure=""; notice.hide(); stage.show(); panel.visible=not panel.rows.is_empty(); set_process(not flashing.is_empty()); place()
func reset() -> void:
	epoch+=1
	flashing.clear()
	admission_pending=false; panel.art_error=""; notice.hide(); stage.hide()
	for id in panel.buttons.keys(): retire(int(id))
	panel.rows.clear(); panel.images.clear(); panel.staged.clear(); panel.view_id=-1; panel.actor_id=-1; panel.hide_tip(); panel.hide()
	if layout_ready: set_process(false)
func receive(message: Dictionary) -> void:
	if closed: return
	match str(message.kind):
		"buff-begin":
			if int(message.viewId)<=panel.view_id: return
			panel.staged={"id":int(message.viewId),"actor":int(message.actorId),"count":int(message.count),"rows":[]}
		"buff-rows":
			if int(message.viewId)==int(panel.staged.get("id",-1)): panel.staged.rows.append_array(message.rows)
		"buff-commit":
			if int(message.viewId)!=int(panel.staged.get("id",-1)) or panel.staged.rows.size()!=int(panel.staged.count): return
			if panel.actor_id!=-1 and panel.actor_id!=int(panel.staged.actor):
				var next: Dictionary=panel.staged.duplicate(true); reset(); panel.staged=next
			panel.rows={}
			for row in panel.staged.rows: panel.rows[int(row.id)]=row.duplicate(true)
			panel.view_id=int(panel.staged.id); panel.actor_id=int(panel.staged.actor); panel.staged.clear(); present()
func retire(id: int) -> void:
	if not panel.buttons.has(id): return
	var button: Button=panel.buttons[id]; panel.buttons.erase(id); panel.images.erase(id)
	if is_instance_valid(tooltips): tooltips.unregister_control(button)
	button.get_node("Icon").close(); stage.remove_child(button); button.queue_free()
func present() -> void:
	if closed or not layout_ready: return
	panel.hide(); stage.hide(); notice.hide(); panel.art_error=""; failure=""; admission_pending=false
	for id in panel.buttons.keys():
		if not panel.rows.has(id) or int(panel.buttons[id].get_meta("serial",-1))!=int(panel.rows[id].get("serial",-1)) or str(panel.buttons[id].get_meta("resource"))!=str(panel.rows[id].resource): retire(int(id))
	var index:=0; flashing.clear()
	for id in panel.rows:
		var row: Dictionary=panel.rows[id]; var rect:=Plan.slot(definition,index); index+=1
		if not panel.buttons.has(id):
			var button:=Button.new(); button.name="Effect%d"%id; button.focus_mode=Control.FOCUS_NONE; button.set_meta("serial",int(row.get("serial",-1))); button.set_meta("resource",str(row.resource)); stage.add_child(button); panel.buttons[id]=button
			for name in ["normal","hover","pressed","disabled","focus"]: button.add_theme_stylebox_override(name,StyleBoxEmpty.new())
			var icon:=Icon.new(); icon.name="Icon"; button.add_child(icon); icon.configure(definition,art,str(row.resource))
			button.pressed.connect(selected.bind(int(id),button,epoch))
			if is_instance_valid(tooltips): tooltips.register_control(button)
		var button: Button=panel.buttons[id]; var icon: Control=button.get_node("Icon"); stage.move_child(button,index-1)
		button.position=rect.position; button.size=rect.size; button.tooltip_text=str(row.get("label","")); icon.set_state(bool(row.state))
		if bool(row.state): flashing.append(button)
	admission_pending=not panel.rows.is_empty(); set_process(admission_pending); try_admit(); place()
func selected(id: int,button: Button,captured_epoch: int) -> void:
	if closed or epoch!=captured_epoch or panel.buttons.get(id)!=button or not panel.rows.has(id): return
	panel.effect_selected.emit(id)
func place() -> void:
	if closed or not layout_ready or not is_instance_valid(panel.get_parent()) or not panel.get_parent() is Control: return
	var viewport: Rect2=panel.get_viewport_rect(); var inverse: Transform2D=panel.get_parent().get_global_transform_with_canvas().affine_inverse()
	# Original895b20 reserves the party bar's80 screen pixels at the right edge.
	panel.position=inverse*(viewport.position+Vector2(viewport.size.x-80,0)); panel.size=Vector2.ZERO
func blocks_pointer(point: Vector2) -> bool:
	if closed or not panel.is_visible_in_tree() or not stage.visible: return false
	for button in panel.buttons.values():
		if button.get_global_rect().has_point(point) and panel.get_viewport_rect().has_point(point): return true
	return false
func close() -> void:
	if closed: return
	reset(); closed=true; set_process(false); assets.close()
	if is_instance_valid(art) and art.loaded.is_connected(art_loaded): art.loaded.disconnect(art_loaded)
	if panel.get_viewport().size_changed.is_connected(place): panel.get_viewport().size_changed.disconnect(place)
	jobs.clear(); models={}; definition={}; art=null; tooltips=null
func _exit_tree() -> void: close()
