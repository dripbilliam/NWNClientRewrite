extends Control
# Original CG_SEX presentation. Choice remains private until the scoped owner
# commits OK; cancellation never mutates the draft or emits a network request.
signal prepared
signal finished(accepted: bool,selected: int,scope: Array)
const Assets=preload("res://systems/native_data/asset_service.gd")
const Layout=preload("res://systems/native_data/creation_gender_layout.gd")
const State=preload("res://systems/native_data/creation_gender_state.gd")
const Text=preload("res://systems/server_text.gd")
const Rich=preload("res://systems/native_data/rich_text.gd")
var state:=State.new()
var frame
var text_owner
var assets
var models: Dictionary={}
var source: Dictionary={}
var plan: Dictionary={}
var jobs: Dictionary={}
var requested: Dictionary={}
var buttons: Dictionary={}
var scope: Array=[]
var held: Dictionary={}
var revision:=0
var help_title: Label
var help_body: RichTextLabel
var help_scroll: ScrollContainer
var bar
var help_refs: Array=[]
var started:=false
var layout_ready:=false
var wanted:=false
var closed:=false
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
func configure(painter,text,catalog,cache_path: String) -> void:
	frame=painter;text_owner=text;mouse_filter=Control.MOUSE_FILTER_STOP;hide()
	assets=Assets.new();add_child(assets);assets.configure(catalog);assets.cache_directory=cache_path;assets.maximum_workers=2;assets.completed.connect(received)
func start() -> void:
	if closed or started:return
	started=true;jobs[assets.request("cg_sex",2047,"gff")]="@layout"
	for name in ["scrollbar_simple","pb_scrl_up","pb_scrl_down"]:request_model(name)
func request_model(name: String) -> void:
	name=name.to_lower()
	if name.is_empty() or requested.has(name):return
	requested[name]=true;jobs[assets.request(name,2002,"actor-model")]=name
func request_children(node: Dictionary) -> void:
	request_model(str(node.get("Obj_ResRef","")))
	for child in node.get("Obj_ChildList",[]):request_children(child)
func received(id: int,result: Dictionary) -> void:
	if closed or not jobs.has(id):return
	var name: String=jobs[id];jobs.erase(id)
	if not str(result.get("error","")).is_empty():failure=name+": "+str(result.error);return
	if name=="@layout":source=result.value.root;request_children(source)
	else:models[name]=result.value
	if not jobs.is_empty() or source.is_empty() or not failure.is_empty():return
	plan=Layout.parse(source,models)
	if not str(plan.error).is_empty():failure=str(plan.error);return
	build()
func caption(entry: Dictionary) -> String:
	var value: Dictionary=entry.get("caption",{});var ref:=int(value.get("Obj_StrRef",4294967295))
	return text_owner.raw({"strRef":ref}) if ref!=4294967295 else str(value.get("AurString_Text",""))
func build() -> void:
	if closed or layout_ready:return
	size=plan.size;custom_minimum_size=size;frame.image(plan.resource,plan.main,self)
	frame.create_label(plan.entries.title,self,caption(plan.entries.title))
	var help: Dictionary=plan.entries.helpbox;frame.image(help.resource,help.rect,self)
	var title_entry:={"rect":plan.help_title,"caption":help.caption.duplicate(true)};title_entry.caption.AurString_AlignV=.5
	help_title=frame.create_label(title_entry,self)
	help_scroll=ScrollContainer.new();add_child(help_scroll);help_scroll.position=plan.help_body.position;help_scroll.size=plan.help_body.size;help_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	help_body=RichTextLabel.new();help_scroll.add_child(help_body);help_body.fit_content=true;help_body.scroll_active=false;help_body.custom_minimum_size.x=plan.help_body.size.x;Text.style(help_body);frame.font_style(help_body,help.caption)
	bar=preload("res://systems/native_scrollbar.gd").new();add_child(bar);bar.configure(frame,models,help,help_scroll)
	if not bar.failure.is_empty():failure=bar.failure;return
	var group:=ButtonGroup.new()
	for tag in Layout.BUTTONS:
		var radio: bool=tag in ["malebutton","femalebutton"];var button: Button=frame.create_button(plan.entries[tag],self,models,radio);buttons[tag]=button;frame.button_caption(button,caption(plan.entries[tag]))
		if radio:button.button_group=group
		button.button_down.connect(capture.bind(tag));button.pressed.connect(invoke.bind(tag))
	layout_ready=true;refresh();prepared.emit()
	if wanted:show();register_modal_owner()
func set_context(gender: int,value_scope: Array) -> void:
	if closed:return
	var changed: bool=scope!=value_scope
	if changed:modal_lease.retire()
	retire_input();scope=value_scope.duplicate();state.reset(gender);help_refs=[];refresh()
	if changed:register_modal_owner()
func refresh() -> void:
	if closed or not layout_ready:return
	for index in 2:
		var button: Button=buttons[["malebutton","femalebutton"][index]];var checked: bool=state.selected==index
		if button.button_pressed!=checked:button.set_pressed_no_signal(checked)
	var next: Array=[state.help_title,state.help_description]
	if help_refs!=next:
		help_refs=next;help_title.text=text_owner.raw({"strRef":state.help_title});Text.set_text(help_body,Rich.parse(text_owner.raw({"strRef":state.help_description})));help_scroll.scroll_vertical=0
func capture(tag: String) -> void:
	if not available():return
	held[tag]={"revision":revision,"scope":scope.duplicate()}
func invoke(tag: String) -> void:
	var press: Dictionary=held.get(tag,{});held.erase(tag)
	if not available() or press.is_empty() or int(press.revision)!=revision or press.scope!=scope:refresh();return
	if tag in ["malebutton","femalebutton"]:state.select(0 if tag=="malebutton" else 1);refresh();return
	if tag not in ["okbutton","cancelbutton"]:return
	var selected:=state.selected;var result_scope:=scope.duplicate();dismiss();finished.emit(tag=="okbutton",selected,result_scope)
func open() -> void:
	if closed:return
	wanted=true
	if layout_ready:show();register_modal_owner()
func retire_input() -> void:
	revision+=1;held.clear()
	for button in buttons.values():
		var disabled: bool=button.disabled;button.disabled=true;button.disabled=disabled
	if is_instance_valid(bar):bar.cancel_drag();bar.stop_repeat()
func dismiss() -> void:modal_lease.retire();wanted=false;retire_input();hide()
func snapshot() -> Dictionary:return {"ready":layout_ready,"failure":failure,"selected":state.selected,"help":help_refs.duplicate(),"scope":scope.duplicate(),"full_creation_parity":false}
func close() -> void:
	if closed:return
	dismiss();closed=true
	if is_instance_valid(bar):bar.close()
	if is_instance_valid(assets):assets.close()
	if is_instance_valid(frame):
		for button in buttons.values():frame.button_geometry.erase(button.get_instance_id())
	jobs.clear();models.clear();text_owner=null;frame=null;modal_lease.close();modal_kind=""
func _exit_tree() -> void:close()
