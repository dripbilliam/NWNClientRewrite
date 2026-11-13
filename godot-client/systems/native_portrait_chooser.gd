extends Control
# Original portrait pane. The enclosing CG_MAIN flow owns draft/save actions;
# this pane only returns a chosen base ResRef or cancellation.
signal prepared
signal finished(accepted: bool,portrait: String,scope: Array)
const Assets=preload("res://systems/native_data/asset_service.gd")
const Layout=preload("res://systems/native_data/portrait_chooser_layout.gd")
const State=preload("res://systems/native_data/portrait_chooser_state.gd")
const Resources=preload("res://systems/native_data/portrait_resources.gd")
const PortraitImage=preload("res://systems/native_gui_bitmap_plane.gd")
var state:=State.new()
var frame
var text_owner
var portrait_art
var portrait_catalog
var assets
var source: Dictionary={}
var models: Dictionary={}
var jobs: Dictionary={}
var requested: Dictionary={}
var plan: Dictionary={}
var buttons: Dictionary={}
var captions: Dictionary={}
var cells: Array=[]
var preview
var viewport: Control
var scroll: ScrollContainer
var content: Control
var bar
var scope: Array=[]
var held: Dictionary={}
var revision:=0
var range_pending:=false
var started:=false
var layout_ready:=false
var closed:=false
var wanted:=false
var failure:=""
var modal_lease=preload("res://systems/native_data/modal_lease.gd").new()
var modal_kind:=""
func set_modal_owner(order,verified_kind: String="") -> void:
	if modal_lease.order==order and modal_kind==verified_kind:return
	modal_lease.retire();modal_kind=verified_kind;modal_lease.configure(self,order);modal_lease.bind_input(self)
	if not modal_lease.admission_changed.is_connected(modal_admission_changed):modal_lease.admission_changed.connect(modal_admission_changed)
	register_modal_owner()
func register_modal_owner() -> void:
	if not closed and wanted and layout_ready and is_visible_in_tree() and modal_kind in ["other","unknown"]:modal_lease.activate(scope,modal_kind)
func modal_admission_changed(admitted: bool) -> void:
	if not admitted:retire_input()
func available() -> bool:return not closed and wanted and is_visible_in_tree() and modal_lease.admits()
func configure(painter,text,base_catalog,cache_path: String) -> void:
	frame=painter; text_owner=text; mouse_filter=Control.MOUSE_FILTER_STOP; hide(); set_process(false)
	assets=Assets.new(); add_child(assets); assets.configure(base_catalog); assets.cache_directory=cache_path; assets.maximum_workers=2; assets.completed.connect(received)
func start() -> void:
	if closed or started: return
	started=true; jobs[assets.request("cg_portrait",2047,"gff")]="@layout"
	for name in ["ctl_cg_portraits","ctl_cg_mportrait","scrollbar_simple","pb_scrl_up","pb_scrl_down"]: request_model(name)
func request_model(name: String) -> void:
	name=name.to_lower()
	if name.is_empty() or requested.has(name): return
	requested[name]=true; jobs[assets.request(name,2002,"actor-model")]=name
func request_children(node: Dictionary) -> void:
	request_model(str(node.get("Obj_ResRef","")))
	for child in node.get("Obj_ChildList",[]): request_children(child)
func received(id: int,result: Dictionary) -> void:
	if closed or not jobs.has(id): return
	var name: String=jobs[id]; jobs.erase(id)
	if not str(result.get("error","")).is_empty(): failure=name+": "+str(result.error); return
	if name=="@layout": source=result.value.root; request_children(source)
	else: models[name]=result.value
	if not jobs.is_empty() or source.is_empty() or not failure.is_empty(): return
	plan=Layout.parse(source,models)
	if not str(plan.error).is_empty(): failure=str(plan.error); return
	build()
func build() -> void:
	if closed or layout_ready: return
	size=plan.size; custom_minimum_size=size; frame.image(plan.resource,plan.main,self)
	frame.create_label(plan.entries.title,self,caption(plan.entries.title))
	frame.image(plan.grid.resource,plan.grid.rect,self)
	frame.image(plan.entries.portrait.resource,plan.entries.portrait.rect,self)
	preview=PortraitImage.new(); add_child(preview); preview.configure(plan.preview)
	# This empty native scroll owner provides only the range. The 24 real cells
	# belong to a separate clipped viewport, so a row rebind does not also move
	# their geometry by the slider's fractional position.
	scroll=ScrollContainer.new(); add_child(scroll); scroll.position=plan.grid.viewport.position; scroll.size=plan.grid.viewport.size
	scroll.mouse_filter=Control.MOUSE_FILTER_IGNORE; scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_SHOW_NEVER
	content=Control.new(); scroll.add_child(content); content.mouse_filter=Control.MOUSE_FILTER_IGNORE
	viewport=Control.new(); add_child(viewport); viewport.position=plan.grid.viewport.position; viewport.size=plan.grid.viewport.size; viewport.clip_contents=true; viewport.mouse_filter=Control.MOUSE_FILTER_STOP
	bar=preload("res://systems/native_scrollbar.gd").new(); add_child(bar); bar.visible_units_override=State.VISIBLE_UNITS; bar.configure(frame,models,plan.grid,scroll,State.ROW_UNITS)
	viewport.gui_input.connect(func(event):
		if available() and bar.wheel_input(event): viewport.accept_event())
	scroll.get_v_scroll_bar().value_changed.connect(scrolled)
	for tag in ["okbutton","cancelbutton"]:
		var button: Button=frame.create_button(plan.entries[tag],self,models); buttons[tag]=button; captions[tag]=frame.button_caption(button,caption(plan.entries[tag]))
		button.button_down.connect(capture.bind(tag)); button.pressed.connect(invoke.bind(tag))
	layout_ready=true; update_choices(); prepared.emit()
	if wanted: show(); register_modal_owner()
func caption(entry: Dictionary) -> String:
	var value: Dictionary=entry.get("caption",{}); var ref:=int(value.get("Obj_StrRef",4294967295))
	return text_owner.raw({"strRef":ref}) if ref!=4294967295 else str(value.get("AurString_Text",""))
func set_context(values: Array,current: String,value_scope: Array,image_art,catalog) -> void:
	if closed: return
	var changed: bool=scope!=value_scope
	if changed: modal_lease.retire()
	retire_input()
	# A new active catalog can replace an identically named portrait. Retire the
	# previous owner's in-flight bindings before the same controls are reused.
	if is_instance_valid(portrait_art):
		if is_instance_valid(preview): portrait_art.unbind(preview)
		for cell in cells: portrait_art.unbind(cell.bitmap)
	for cell in cells: cell.base=""; cell.bitmap.texture=null
	if is_instance_valid(preview): preview.set_meta("portrait_base",""); preview.texture=null
	scope=value_scope.duplicate(); portrait_art=image_art; portrait_catalog=catalog; state.reset(values,current)
	if layout_ready: update_choices()
	if changed: register_modal_owner()
func update_choices() -> void:
	if closed or not layout_ready: return
	while cells.size()<mini(State.POOL,state.choices.size()):
		var index:=cells.size(); var button:=Button.new(); viewport.add_child(button); button.focus_mode=Control.FOCUS_NONE
		for style in ["normal","hover","pressed","disabled","focus"]: button.add_theme_stylebox_override(style,StyleBoxEmpty.new())
		var border:=TextureRect.new(); button.add_child(border); border.mouse_filter=Control.MOUSE_FILTER_IGNORE; border.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; border.stretch_mode=TextureRect.STRETCH_SCALE; border.size=plan.grid.button.size
		var bitmap:=PortraitImage.new(); button.add_child(bitmap)
		var photo: Dictionary=plan.grid.photo.duplicate(); photo.rect.position-=plan.grid.button.position; bitmap.configure(photo)
		button.position=plan.grid.first-plan.grid.viewport.position+plan.grid.column*(index%State.COLUMNS)+plan.grid.row*(index/State.COLUMNS)+plan.grid.button.position; button.size=plan.grid.button.size
		cells.append({"button":button,"border":border,"bitmap":bitmap,"base":"","pose":""})
		button.button_down.connect(func():capture(str(index)); cell_pose(index,true))
		button.button_up.connect(func():cell_pose(index,false))
		button.pressed.connect(invoke.bind(str(index)))
	content.custom_minimum_size=Vector2(1,plan.grid.viewport.size.y+State.scroll_range(state.choices.size())-1)
	range_pending=true; set_process(true); populate()
func _process(_delta: float) -> void:
	if closed or not range_pending: set_process(false); return
	var range_owner:=scroll.get_v_scroll_bar()
	if absf(range_owner.max_value-range_owner.page-(State.scroll_range(state.choices.size())-1))>0.01: return
	range_pending=false; range_owner.value=state.position; populate(); set_process(false)
func scrolled(value: float) -> void:
	if closed or range_pending: return
	var old:=state.position/State.ROW_UNITS; state.scroll(roundi(value))
	if old!=state.position/State.ROW_UNITS: retire_choice_input(); populate()
func populate() -> void:
	if closed or not layout_ready: return
	var rows:=state.slots()
	for index in cells.size():
		var cell: Dictionary=cells[index]; var row: Dictionary=rows[index] if index<rows.size() else {"base":"","selected":false}
		cell.button.visible=index<rows.size(); cell.button.disabled=str(row.base).is_empty()
		if str(cell.base)!=str(row.base):
			cell.base=str(row.base); cell.bitmap.texture=null
			if is_instance_valid(portrait_art):
				portrait_art.unbind(cell.bitmap)
				if not cell.base.is_empty(): portrait_art.bind(cell.bitmap,Resources.sized(cell.base,3,portrait_catalog.has_resource))
		cell_pose(index,false)
	buttons.okbutton.disabled=not state.can_accept(); captions.okbutton.add_theme_color_override("font_color",Color.WHITE if state.can_accept() else Color(0.5,0.5,0.5,1))
	if is_instance_valid(portrait_art):
		var base:=state.preview()
		if str(preview.get_meta("portrait_base",""))!=base:
			preview.set_meta("portrait_base",base); preview.texture=null; portrait_art.bind(preview,Resources.sized(base,5,portrait_catalog.has_resource))
func cell_pose(index: int,pressed: bool) -> void:
	if closed or index<0 or index>=cells.size(): return
	var cell: Dictionary=cells[index]; var checked: bool=not str(cell.base).is_empty() and cell.base==state.selected
	var pose: String=("checked" if checked else "unchecked")+("down" if pressed else "up")
	if cell.pose==pose: return
	cell.pose=pose
	# Crop the offscreen, back-facing inactive border to the checked footprint.
	# The photograph stays a raw native bitmap with its own exact source UVs;
	# its replacement never prepares 24 new animated models on every scroll.
	frame.art.bind(cell.border,"ctl_cg_mportrait","texture",true,pose,false,{"gui_replace01":"black"},plan.grid.button)
func capture(tag: String) -> void:
	if not available(): return
	held[tag]={"revision":revision,"scope":scope.duplicate(),"base":str(cells[int(tag)].base) if tag.is_valid_int() and int(tag)>=0 and int(tag)<cells.size() else ""}
func invoke(tag: String) -> void:
	var press: Dictionary=held.get(tag,{}); held.erase(tag)
	if not available() or press.is_empty() or int(press.revision)!=revision or press.scope!=scope: return
	if tag.is_valid_int():
		var index:=int(tag)
		if index<0 or index>=cells.size() or press.base!=str(cells[index].base) or not state.choose(index): return
		populate(); return
	if tag not in ["okbutton","cancelbutton"] or tag=="okbutton" and not state.can_accept(): return
	var accepted:=tag=="okbutton"; var selected:=state.selected; var result_scope:=scope.duplicate(); dismiss(); finished.emit(accepted,selected,result_scope)
func open() -> void:
	if closed: return
	wanted=true
	if layout_ready: show(); register_modal_owner()
func retire_choice_input() -> void:
	revision+=1; held.clear()
	for cell in cells:
		var disabled: bool=cell.button.disabled; cell.button.disabled=true; cell.button.disabled=disabled
	for button in buttons.values():
		var disabled: bool=button.disabled; button.disabled=true; button.disabled=disabled
func retire_input() -> void:
	retire_choice_input()
	if is_instance_valid(bar): bar.cancel_drag(); bar.stop_repeat()
func dismiss() -> void:
	modal_lease.retire(); wanted=false; retire_input(); hide()
func snapshot() -> Dictionary:
	return {"ready":layout_ready,"art_ready":art_ready(),"failure":failure,"choices":state.choices.size(),"cells":cells.size(),"selected":state.selected,"position":state.position,"can_accept":state.can_accept(),"range_pending":range_pending,"scope":scope.duplicate(),"native_only":true,"full_character_ui_parity":false}
func art_ready() -> bool:
	if closed or not layout_ready or range_pending or not failure.is_empty() or not is_instance_valid(frame) or not bar.art_ready: return false
	if not preload("res://systems/native_menu_builder.gd").source_ready(self,frame) or preview.texture==null: return false
	for cell in cells:
		if cell.button.visible and not str(cell.base).is_empty() and cell.bitmap.texture==null: return false
	return true
func close() -> void:
	if closed: return
	dismiss(); closed=true; set_process(false)
	if is_instance_valid(bar): bar.close()
	if is_instance_valid(portrait_art):
		if is_instance_valid(preview): portrait_art.unbind(preview)
		for cell in cells: portrait_art.unbind(cell.bitmap)
	if is_instance_valid(assets): assets.close()
	jobs.clear(); models.clear(); cells.clear(); held.clear(); portrait_catalog=null; portrait_art=null; text_owner=null; frame=null; modal_lease.close(); modal_kind=""
func _exit_tree() -> void: close()
