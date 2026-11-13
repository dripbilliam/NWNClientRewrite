extends "res://systems/native_creation_choice.gd"
signal finished(operation: String,package_id: int,ticket: Array)
const State=preload("res://systems/native_data/creation_package_state.gd")
const Layout=preload("res://systems/native_data/creation_package_layout.gd")
var busy:=false
var operation_status:=""
func _init() -> void:resource="cg_package";list_tag="classlistbox";row_prefix="package:";state=State.new()
func parse_layout() -> Dictionary:return Layout.parse(source,models)
func set_context(value: Dictionary,recommended: bool,active_text,art,value_scope: Array) -> void:
	if closed:return
	var replaced_scope:=scope!=value_scope
	if replaced_scope:retire_modal_owner()
	bind_data(recommended,active_text,art,value_scope);state.reset(value);busy=false;operation_status="";refresh()
	if replaced_scope:register_modal_owner()
func refresh() -> void:
	super.refresh()
	if closed or not layout_ready:return
	set_button_available("okbutton",not busy and state.can_accept());set_button_available("configurepckg",not busy);set_button_available("cancelbutton",true);set_button_available("recommendbutton",not busy and can_recommend)
	for button in row_buttons:button.disabled=busy
	if not operation_status.is_empty():
		help_title.text="";preload("res://systems/server_text.gd").set_text(help_body,preload("res://systems/native_data/rich_text.gd").parse(operation_status))
func set_operation_status(message: String) -> void:
	if operation_status==message:return
	operation_status=message;help_refs=[];refresh()
func set_busy(value: bool) -> void:retire_input();busy=value;refresh()
func _input(event: InputEvent) -> void:
	if available() and event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_ESCAPE:complete("cancel");get_viewport().set_input_as_handled()
func invoke(tag: String) -> void:
	if not valid_press(tag) or busy and tag!="cancelbutton":return
	if tag=="cancelbutton":complete("cancel");return
	set_operation_status("")
	if tag.begins_with(row_prefix):state.select_index(int(tag.trim_prefix(row_prefix)));refresh()
	elif tag=="recommendbutton" and can_recommend:state.recommend();refresh()
	elif tag=="configurepckg":complete("configure")
	elif tag=="okbutton" and state.can_accept():complete("automatic")
func complete(operation: String) -> void:
	var identity:=scope.duplicate();var selected: int=state.configure_package() if operation=="configure" else state.selected_package()
	if operation=="cancel":dismiss()
	else:set_busy(true)
	finished.emit(operation,selected,identity)
