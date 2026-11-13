extends Control
# Original CG_MAIN frame. The controller owns draft/rule changes, child panes
# and the embedded creation-mode character sheet; this view sends no packet.
signal prepared
signal action_requested(tag: String,scope: Array)
const Assets=preload("res://systems/native_data/asset_service.gd")
const Plan=preload("res://systems/native_data/creation_main_layout.gd")
const SummaryPlan=preload("res://systems/native_data/character_summary_layout.gd")
var frame
var text_owner
var assets
var models: Dictionary={}
var source: Dictionary={}
var jobs: Dictionary={}
var requested: Dictionary={}
var definition: Dictionary={}
var buttons: Dictionary={}
var captions: Dictionary={}
var enabled: Dictionary={}
var completed: Dictionary={}
var encouraged: Dictionary={}
var scope: Array=[]
var held: Dictionary={}
var revision:=0
var summary_host: Control
var summary_view
var summary_index:=0
var started:=false
var closed:=false
var layout_ready:=false
var failure:=""
func configure(painter,text,catalog,cache_path: String) -> void:
	frame=painter; text_owner=text; mouse_filter=Control.MOUSE_FILTER_STOP; hide()
	assets=Assets.new(); add_child(assets); assets.configure(catalog); assets.cache_directory=cache_path; assets.maximum_workers=2; assets.completed.connect(received)
func start() -> void:
	if closed or started: return
	started=true; jobs[assets.request("cg_main",2047,"gff")]="@layout"
func request_models(node: Dictionary) -> void:
	var name:=str(node.get("Obj_ResRef","")).to_lower()
	if not name.is_empty() and not requested.has(name): requested[name]=true; jobs[assets.request(name,2002,"actor-model")]=name
	for child in node.get("Obj_ChildList",[]): request_models(child)
func received(id: int,result: Dictionary) -> void:
	if closed or not jobs.has(id): return
	var name: String=jobs[id]; jobs.erase(id)
	if not str(result.get("error","")).is_empty(): failure=name+": "+str(result.error); return
	if name=="@layout":
		source=result.value.root; request_models(source)
		for resource in SummaryPlan.RESOURCES:
			if not requested.has(resource): requested[resource]=true; jobs[assets.request(resource,2002,"actor-model")]=resource
	else: models[name]=result.value
	if not jobs.is_empty() or source.is_empty() or not failure.is_empty(): return
	definition=Plan.parse(source,models)
	if not str(definition.error).is_empty(): failure=str(definition.error); return
	build()
func build() -> void:
	if closed or layout_ready: return
	size=definition.size; custom_minimum_size=size
	frame.image(definition.resource,definition.main,self)
	var goldbar: Dictionary=definition.entries.ctl_cg_goldbar; frame.image(goldbar.resource,goldbar.rect,self)
	var title: Dictionary=definition.entries.titlelabel; frame.create_label(title,self,caption(title))
	for tag in Plan.BUTTONS:
		var entry: Dictionary=definition.entries[tag]; var button: Button=frame.create_button(entry,self,models); buttons[tag]=button; captions[tag]=frame.button_caption(button,caption(entry))
		button.button_down.connect(capture.bind(tag)); button.pressed.connect(invoke.bind(tag))
	summary_host=Control.new(); add_child(summary_host); summary_host.position=definition.summary_origin; summary_host.mouse_filter=Control.MOUSE_FILTER_IGNORE
	summary_view=preload("res://systems/native_character_summary_view.gd").new(); summary_host.add_child(summary_view); summary_view.configure(frame,text_owner,models)
	if not summary_view.failure.is_empty(): failure=summary_view.failure; return
	summary_view.labels.title.text=text_owner.raw({"strRef":0xf182})+", "
	summary_view.page_down.connect(func(index):capture("summary:"+str(index))); summary_view.page_pressed.connect(invoke_summary)
	layout_ready=true; refresh(); prepared.emit()
func caption(entry: Dictionary) -> String:
	var value: Dictionary=entry.get("caption",{}); var ref:=int(value.get("Obj_StrRef",4294967295))
	return text_owner.raw({"strRef":ref}) if ref!=4294967295 else str(value.get("AurString_Text",""))
func set_context(value: Array,availability: Dictionary,completion: Dictionary,encouragement: Dictionary) -> void:
	if closed: return
	if scope!=value or enabled!=availability: retire_input()
	scope=value.duplicate(); enabled=availability.duplicate(); completed=completion.duplicate(); encouraged=encouragement.duplicate(); refresh()
func refresh() -> void:
	if closed or not layout_ready: return
	for tag in buttons:
		var flow_tag: String=Plan.FLOW_TAGS.get(tag,tag.trim_suffix("button")); var button: Button=buttons[tag]
		button.disabled=not bool(enabled.get(flow_tag,false)); button.set_meta("creation_complete",bool(completed.get(flow_tag,false)))
		captions[tag].add_theme_color_override("font_color",Color(0.5,0.5,0.5,1) if button.disabled else Color.WHITE)
		var data: Dictionary=frame.button_geometry[button.get_instance_id()]; var clip: String="encouraged" if encouraged.get(flow_tag,false) else "up"
		if data.styles.normal[1]!=clip:
			data.styles.normal[1]=clip; frame.art.bind(data.styles.normal[0],data.resource,"texture",true,clip)
		button.queue_redraw()
func capture(tag: String) -> void:
	if closed or not is_visible_in_tree(): return
	held[tag]={"scope":scope.duplicate(),"revision":revision}
func invoke(tag: String) -> void:
	var press: Dictionary=held.get(tag,{}); held.erase(tag)
	if closed or not is_visible_in_tree() or not layout_ready or not buttons.has(tag) or buttons[tag].disabled or press.is_empty(): return
	if press.scope!=scope or int(press.revision)!=revision: return
	action_requested.emit(tag,scope.duplicate())
func invoke_summary(index: int) -> void:
	var key:="summary:"+str(index); var press: Dictionary=held.get(key,{}); held.erase(key)
	if closed or not is_visible_in_tree() or not layout_ready or index<0 or index>=4 or press.is_empty() or summary_view.tabs[index].disabled: return
	if press.scope!=scope or int(press.revision)!=revision: return
	summary_index=index; summary_view.set_page(index)
func retire_input() -> void:
	revision+=1; held.clear()
	for button in buttons.values():
		var unavailable: bool=button.disabled; button.disabled=true; button.disabled=unavailable
func dismiss() -> void: retire_input(); hide()
func source_art_ready() -> bool:
	return not closed and layout_ready and failure.is_empty() and preload("res://systems/native_menu_builder.gd").source_ready(self,frame)
func snapshot() -> Dictionary:
	return {"ready":layout_ready,"source_art_ready":source_art_ready(),"failure":failure,"buttons":buttons.keys(),"scope":scope.duplicate(),"native_only":true,"embedded_summary_frame_ready":is_instance_valid(summary_view) and summary_view.failure.is_empty(),"embedded_summary_accepted":false,"full_creation_ui_parity":false}
func close() -> void:
	if closed: return
	dismiss(); closed=true
	if is_instance_valid(summary_view): summary_view.close()
	if is_instance_valid(assets): assets.close()
	if is_instance_valid(frame):
		for button in buttons.values(): frame.button_geometry.erase(button.get_instance_id())
	jobs.clear(); models.clear(); held.clear(); text_owner=null; frame=null
func _exit_tree() -> void: close()
