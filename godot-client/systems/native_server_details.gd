extends Control
signal prepared
signal action_requested(operation: String,capture: Array)
const Assets=preload("res://systems/native_data/asset_service.gd")
const Plan=preload("res://systems/native_data/server_details_layout.gd")
const Text=preload("res://systems/server_text.gd")
const Rich=preload("res://systems/native_data/rich_text.gd")
const Cohort=preload("res://systems/native_data/constructed_ui_cohort.gd")
var frame
var text_owner
var assets
var jobs: Dictionary={}
var models: Dictionary={}
var source: Dictionary={}
var definition: Dictionary={}
var buttons: Dictionary={}
var fields: Dictionary={}
var checks: Dictionary={}
var held: Dictionary={}
var scope: Array=[]
var endpoint:=""
var revision:=0
var layout_ready:=false
var failure:=""
var closed:=false
var pending:=false
var scroll: ScrollContainer
var body: RichTextLabel
var labels: Dictionary={}
var scrollbar
var notice: Label
var types: Array=[]
var type_table_failure:=""
var static_cohort: Dictionary={}
func configure(painter,text,catalog,cache_path: String) -> void:
	frame=painter; text_owner=text; mouse_filter=Control.MOUSE_FILTER_STOP; hide()
	assets=Assets.new(); add_child(assets); assets.configure(catalog); assets.cache_directory=cache_path; assets.maximum_workers=2; assets.completed.connect(received)
	jobs[assets.request("srv_srvdetails",2047,"gff")]="@layout"; jobs[assets.request("gamespyrooms",2017,"2da")]="@types"
	for name in ["scrollbar_simple","pb_scrl_up","pb_scrl_down"]: request_model(name)
	get_viewport().size_changed.connect(place)
func request_model(name: String) -> void:
	if name.is_empty() or models.has(name): return
	models[name]={}; jobs[assets.request(name,2002,"actor-model")]=name
func collect(node: Dictionary) -> void:
	request_model(str(node.get("Obj_ResRef","")).to_lower())
	for child in node.get("Obj_ChildList",[]): collect(child)
func received(id: int,result: Dictionary) -> void:
	if closed or not jobs.has(id): return
	var name: String=jobs[id]; jobs.erase(id)
	if name=="@types":
		type_table_failure=str(result.get("error",""))
		if type_table_failure.is_empty():
			for row in result.value.get("orderedCells",[]):
				if row.size()>2 and str(row[1]).is_valid_int() and str(row[2]).is_valid_int(): types.append(int(row[1]))
	elif not str(result.get("error","")).is_empty(): failure=name+": "+str(result.error); return
	elif name=="@layout": source=result.value.root; collect(source)
	else: models[name]=result.value
	if jobs.is_empty() and not source.is_empty() and failure.is_empty(): build()
func build() -> void:
	definition=Plan.parse(source,models)
	if not str(definition.error).is_empty(): failure=str(definition.error); return
	size=definition.size; custom_minimum_size=size; frame.image(definition.resource,definition.main,self)
	for entry in definition.labels:
		var label: Label=frame.create_label(entry,self); label.text=text_owner.raw({"strRef":int(entry.caption.get("Obj_StrRef",-1))}); label.tooltip_text=label.text
		labels[entry.path]=label
	for tag in Plan.FIELDS:
		var entry: Dictionary=definition.entries[tag]
		if entry.model.drawn: frame.image(entry.resource,entry.rect,self)
		var edit:=LineEdit.new(); add_child(edit); edit.editable=false; edit.custom_minimum_size=Vector2.ZERO; edit.position=entry.text_rect.position; edit.size=entry.text_rect.size; fields[tag]=edit
		for mode in ["normal","focus","read_only"]: edit.add_theme_stylebox_override(mode,StyleBoxEmpty.new())
		frame.font_style(edit,entry.caption); edit.add_theme_color_override("font_uneditable_color",edit.get_theme_color("font_color"))
	for tag in Plan.CHECKS:
		var button: Button=frame.create_button(definition.entries[tag],self,models,true); button.toggle_mode=true; button.disabled=true; checks[tag]=button
	for tag in Plan.BUTTONS:
		var entry: Dictionary=definition.entries[tag]; var button: Button=frame.create_button(entry,self,models); frame.button_caption(button,text_owner.raw({"strRef":int(entry.caption.get("Obj_StrRef",-1))})); buttons[tag]=button
		button.button_down.connect(func():held[tag]={"scope":scope.duplicate(),"revision":revision}); button.pressed.connect(invoke.bind(tag))
	var entry: Dictionary=definition.entries.desceditbox
	if entry.model.drawn: frame.image(entry.resource,entry.rect,self)
	scroll=ScrollContainer.new(); add_child(scroll); scroll.position=entry.text_rect.position; scroll.size=entry.text_rect.size; scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_SHOW_NEVER
	body=Text.label({},entry.text_rect.size.x); scroll.add_child(body); frame.font_style(body,entry.caption)
	scrollbar=preload("res://systems/native_scrollbar.gd").new(); add_child(scrollbar); scrollbar.configure(frame,models,entry,scroll)
	if not scrollbar.failure.is_empty(): failure=scrollbar.failure; return
	notice=Label.new(); add_child(notice); frame.font_style(notice,{"AurString_Font":"fnt_galahad14"}); notice.position=Vector2(0,size.y+4); notice.size=Vector2(size.x,40); notice.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; notice.clip_text=true; notice.mouse_filter=Control.MOUSE_FILTER_IGNORE
	static_cohort=Cohort.capture("srv_srvdetails+gamespyrooms",self,frame,models,[scrollbar])
	layout_ready=true; place(); prepared.emit()
func cohort_snapshot() -> Dictionary: return Cohort.snapshot(static_cohort,frame,failure if type_table_failure.is_empty() else type_table_failure)
func art_ready() -> bool: return bool(cohort_snapshot().ready)
func place() -> void:
	if layout_ready: position=((get_viewport_rect().size-size)*0.5).max(Vector2.ZERO)
func present(view: Dictionary) -> bool:
	if closed or not art_ready(): return false
	var data: Dictionary=view.get("details",{}) if view.get("details") is Dictionary else {}
	if data.is_empty():
		for row in view.get("rows",[]):
			if row.get("selected",false): data=row; break
	if data.is_empty(): return false
	var next_scope: Array=[int(view.connection),int(view.viewId)]; var next_endpoint:=preload("res://systems/native_data/browser_numbers.gd").endpoint(data)
	if scope!=next_scope: revision+=1
	if endpoint!=next_endpoint: scroll.scroll_vertical=0
	scope=next_scope; endpoint=next_endpoint; pending=view.get("busy",false)
	for tag in Plan.FIELDS:
		var key: String=Plan.FIELDS[tag]; var value: Variant=data.get(key)
		var rendered:=str(value) if value!=null else ""
		if value is int or value is float: rendered=preload("res://systems/native_data/character_record_values.gd").integer_text(value)
		if key=="endpoint": rendered=str(data.host)+":"+preload("res://systems/native_data/character_record_values.gd").integer_text(data.port)
		elif key=="syncAvailable": rendered="OK" if value==true else "Need" if value==false else ""
		elif key=="gameType": rendered=text_owner.raw({"strRef":types[int(value)]}) if value!=null and int(value)>=0 and int(value)<types.size() else ""
		fields[tag].text=rendered; fields[tag].tooltip_text=rendered
	for tag in Plan.CHECKS:
		var value: Variant=data.get(Plan.CHECKS[tag]); checks[tag].set_pressed_no_signal(value==true); checks[tag].tooltip_text="Not reported by this server" if value==null else ""
	var description:=str(data.get("description",""))
	if pending and not data.get("extendedReceived",false) and description.is_empty(): description=text_owner.raw({"strRef":0x10497})
	Text.set_text(body,Rich.parse(description))
	var navigation: Dictionary=view.get("detailsPosition",{}); buttons.prevbutton.disabled=pending or not navigation.get("canPrevious",false); buttons.nextbutton.disabled=pending or not navigation.get("canNext",false); buttons.connectbutton.disabled=pending or not view.get("canJoin",false) or not data.get("allowed",true); buttons.closebutton.disabled=false
	notice.text=str(view.get("status","")) if str(view.get("status",""))!="Server information received" else ""
	show(); place(); return true
func invoke(tag: String) -> void:
	if closed or not visible or not buttons.has(tag) or buttons[tag].disabled: return
	var capture: Dictionary=held.get(tag,{"scope":scope,"revision":revision}); held.erase(tag)
	if capture.scope!=scope or int(capture.revision)!=revision: return
	action_requested.emit({"closebutton":"close","connectbutton":"join","nextbutton":"next","prevbutton":"previous"}[tag],scope.duplicate())
func dismiss() -> void:
	revision+=1; hide()
	if is_instance_valid(scrollbar): scrollbar.cancel_drag(); scrollbar.stop_repeat()
	for button in buttons.values(): var disabled: bool=button.disabled; button.disabled=true; button.disabled=disabled
	for edit in fields.values(): if edit.has_focus(): edit.release_focus()
func close() -> void:
	if closed: return
	dismiss(); closed=true
	if is_instance_valid(assets): assets.close()
	if is_instance_valid(scrollbar): scrollbar.close()
	jobs.clear(); models.clear(); frame=null; text_owner=null
func _exit_tree() -> void: close()
