extends "res://systems/native_source_modal.gd"
# Source-owned fixed School controls; the connection draft owns commit/reset.
signal finished(accepted: bool,selected: int,ticket: Array)
const State=preload("res://systems/native_data/creation_school_state.gd")
const Layout=preload("res://systems/native_data/creation_school_layout.gd")
var state:=State.new()
var data_text
var help
var can_recommend:=true
func _init() -> void:resource="cg_school";extra_models=["scrollbar_simple","pb_scrl_up","pb_scrl_down"]
func parse_layout() -> Dictionary:return Layout.parse(source,models)
func assemble() -> void:
	frame.image(plan.resource,plan.main,self);frame.create_label(plan.entries.title,self,caption(plan.entries.title))
	help=preload("res://systems/native_source_help.gd").new();add_child(help);help.configure(frame,models,plan.entries.helpbox)
	if not help.failure.is_empty():failure=help.failure;return
	var group:=ButtonGroup.new()
	for tag in State.TAGS:
		var button:=make_button(tag,plan.entries[tag],null,true);button.button_group=group
	for tag in Layout.BUTTONS:make_button(tag,plan.entries[tag])
func set_context(model: Dictionary,recommended: bool,active_text,value_scope: Array,retain_selection: bool=false) -> void:
	if closed:return
	var selected:=state.selected;var title:=state.help_title;var description:=state.help_description
	retire_input();scope=value_scope.duplicate();state.reset(model);can_recommend=recommended;data_text=active_text
	if retain_selection:state.selected=selected;state.help_title=title;state.help_description=description
	if is_instance_valid(help):help.invalidate()
	refresh()
func refresh() -> void:
	if closed or not layout_ready:return
	var ready: bool=state.model.get("ready",false)
	for index in State.TAGS.size():
		var button: Button=buttons[State.TAGS[index]];button.disabled=not ready;button.set_pressed_no_signal(state.selected==index)
	for tag in Layout.BUTTONS:buttons[tag].disabled=not ready
	buttons.recommendbutton.disabled=not ready or not can_recommend or not state.model.get("recommended") is int
	for tag in buttons:buttons[tag].get_child(0).modulate=Color(.5,.5,.5,1) if buttons[tag].disabled else Color.WHITE
	help.present(data_text if data_text!=null else text_owner,state.help_title if ready else 4294967295,state.help_description if ready else 4294967295)
func invoke(tag: String) -> void:
	if not valid_press(tag) or not state.model.get("ready",false) or not buttons.has(tag) or buttons[tag].disabled:return
	var index:=State.TAGS.find(tag)
	if index>=0:state.select_index(index);refresh()
	elif tag=="recommendbutton":state.recommend();refresh()
	elif tag in ["okbutton","cancelbutton"]:complete(tag=="okbutton")
func complete(accepted: bool) -> void:
	var identity:=scope.duplicate();var selected:=state.selected;dismiss();finished.emit(accepted,selected,identity)
func _input(event: InputEvent) -> void:
	if available() and event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_ESCAPE:
		complete(false);get_viewport().set_input_as_handled()
func retire_input() -> void:
	super.retire_input()
	if is_instance_valid(help):help.retire_input()
func close() -> void:
	if closed:return
	if is_instance_valid(help):help.close()
	data_text=null;super.close()
