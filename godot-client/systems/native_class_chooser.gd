extends "res://systems/native_creation_choice.gd"
signal finished(accepted: bool,class_id: int,ticket: Array)
const State=preload("res://systems/native_data/creation_class_state.gd")
const Layout=preload("res://systems/native_data/creation_class_layout.gd")
func _init() -> void:resource="cg_class";list_tag="classlistbox";row_prefix="class:";state=State.new()
func parse_layout() -> Dictionary:return Layout.parse(source,models)
func title_caption() -> String:return text_owner.raw({"strRef":61920}) # Creation-mode bind8ec4b0.
func set_context(values: Dictionary,recommended: bool,active_text,art,value_scope: Array) -> void:
	if closed:return
	var replaced_scope:=scope!=value_scope
	if replaced_scope:retire_modal_owner()
	bind_data(recommended,active_text,art,value_scope);state.reset(values);refresh()
	if replaced_scope:register_modal_owner()
func refresh() -> void:
	super.refresh()
	if layout_ready and not closed:set_button_available("okbutton",state.can_accept())
func _input(event: InputEvent) -> void:
	if available() and event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_ESCAPE:
		complete(false);get_viewport().set_input_as_handled()
func invoke(tag: String) -> void:
	if not valid_press(tag):refresh();return
	if tag.begins_with(row_prefix):state.select_index(int(tag.trim_prefix(row_prefix)));refresh()
	elif tag=="recommendbutton" and can_recommend:state.recommend();refresh()
	elif tag=="cancelbutton":complete(false)
	elif tag=="okbutton" and state.can_accept():complete(true)
func complete(accepted: bool) -> void:
	var ticket:=scope.duplicate();var id: int=state.selected_class();dismiss();finished.emit(accepted,id,ticket)
