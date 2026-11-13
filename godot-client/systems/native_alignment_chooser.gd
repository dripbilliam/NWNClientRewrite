extends "res://systems/native_source_modal.gd"
signal finished(accepted: bool,selected: int,ticket: Array)
const State=preload("res://systems/native_data/creation_alignment_state.gd")
const Layout=preload("res://systems/native_data/creation_alignment_layout.gd")
var state:=State.new()
var data_text
var can_recommend:=true
var help
var title: Label
func _init() -> void:resource="cg_alignment";extra_models=["scrollbar_simple","pb_scrl_up","pb_scrl_down"]
func parse_layout() -> Dictionary:return Layout.parse(source,models)
func assemble() -> void:
	frame.image(plan.resource,plan.main,self);title=frame.create_label(plan.entries.title,self,caption(plan.entries.title));title.mouse_filter=Control.MOUSE_FILTER_STOP
	title.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
			if event.pressed:capture("general-help")
			elif valid_press("general-help"):state.general_help();refresh())
	help=preload("res://systems/native_source_help.gd").new();add_child(help);help.configure(frame,models,plan.entries.helpedit)
	if not help.failure.is_empty():failure=help.failure;return
	var group:=ButtonGroup.new()
	for tag in State.TAGS:
		var entry: Dictionary=plan.entries[tag].duplicate();entry.disabled_checked_state=true
		var button:=make_button(tag,entry,null,true);button.button_group=group
	for tag in Layout.BUTTONS:make_button(tag,plan.entries[tag])
func set_context(data: Dictionary,id: int,good: int,law: int,recommended: bool,active_text,value_scope: Array) -> void:
	if closed:return
	var replaced_scope:=scope!=value_scope
	if replaced_scope:retire_modal_owner()
	retire_input();scope=value_scope.duplicate();state.reset(data,id,good,law);can_recommend=recommended;data_text=active_text
	if is_instance_valid(help):help.invalidate()
	refresh()
	if replaced_scope:register_modal_owner()
func refresh() -> void:
	if closed or not layout_ready:return
	for index in State.TAGS.size():
		var button: Button=buttons[State.TAGS[index]];button.disabled=not state.enabled[index];button.set_pressed_no_signal(state.selected==index);button.get_child(button.get_child_count()-1).modulate=Color.WHITE if state.enabled[index] else Color(.5,.5,.5,1)
	buttons.recommendbutton.disabled=not can_recommend;buttons.recommendbutton.get_child(0).modulate=Color.WHITE if can_recommend else Color(.5,.5,.5,1)
	help.present(data_text if data_text!=null else text_owner,state.help_title,state.help_description)
func _input(event: InputEvent) -> void:
	if available() and event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_ESCAPE:
		complete(false);get_viewport().set_input_as_handled()
func invoke(tag: String) -> void:
	if not valid_press(tag):refresh();return
	var index:=State.TAGS.find(tag)
	if index>=0:
		if state.enabled[index]:state.select_index(index)
		refresh()
	elif tag=="recommendbutton" and can_recommend:state.recommend();refresh()
	elif tag in ["okbutton","cancelbutton"]:complete(tag=="okbutton")
func complete(accepted: bool) -> void:
	var ticket:=scope.duplicate();var selected:=state.selected;dismiss();finished.emit(accepted,selected,ticket)
func retire_input() -> void:
	super.retire_input()
	if is_instance_valid(help):help.retire_input()
func close() -> void:
	if closed:return
	if is_instance_valid(help):help.close()
	data_text=null;super.close()
