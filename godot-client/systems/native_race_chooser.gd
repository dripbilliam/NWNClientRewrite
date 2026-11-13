extends "res://systems/native_creation_choice.gd"
signal finished(accepted: bool,race_id: int,subrace: Variant,ticket: Array)
const State=preload("res://systems/native_data/creation_race_state.gd")
const Layout=preload("res://systems/native_data/creation_race_layout.gd")
var current_subrace:=""
var modal: Control
var subrace
var subrace_scope: Array=[]
var subrace_accepted:=false
func _init() -> void:
	resource="cg_race";list_tag="racelistbox";row_prefix="race:";state=State.new()
func configure(painter,text,catalog,cache_path: String) -> void:
	super.configure(painter,text,catalog,cache_path)
	modal=Control.new();add_child(modal);modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);modal.mouse_filter=Control.MOUSE_FILTER_STOP;modal.hide()
	subrace=preload("res://systems/native_generic_edit.gd").new();modal.add_child(subrace);subrace.configure(painter,text,catalog,cache_path);subrace.prepared.connect(place_subrace);subrace.finished.connect(subrace_result);subrace.start()
func parse_layout() -> Dictionary:return Layout.parse(source,models)
func assemble() -> void:
	super.assemble();modal.move_to_front()
func set_context(values: Array,current: int,current_text: String,recommended: bool,active_text,art,value_scope: Array) -> void:
	if closed:return
	var replaced_scope:=scope!=value_scope
	if replaced_scope:retire_modal_owner()
	bind_data(recommended,active_text,art,value_scope);state.reset(values,current);current_subrace=current_text;subrace_accepted=false;refresh()
	if replaced_scope:register_modal_owner()
func modal_admission_changed(admitted: bool) -> void:
	# Lower-parent input retirement must not cancel the new owned child.
	# Actual context/dismiss/close still use this chooser's full retire_input.
	if not admitted:super.retire_input()
func available() -> bool:return super.available() and not (is_instance_valid(subrace) and subrace.wanted)
func _input(event: InputEvent) -> void:
	# Race vtable+140 ->8e34a0 cancels this child with result2.
	if available() and event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_ESCAPE:
		complete(false,null);get_viewport().set_input_as_handled()
func invoke(tag: String) -> void:
	if not valid_press(tag):refresh();return
	if tag.begins_with(row_prefix):state.select_index(int(tag.trim_prefix(row_prefix)));refresh()
	elif tag=="recommendbutton" and can_recommend:state.recommend();refresh()
	elif tag=="subracebutton":
		retire_input();subrace_scope=scope+[revision,"subrace"];subrace.set_context(current_subrace,8185,20,subrace_scope);modal.show();modal.move_to_front();place_subrace();subrace.open()
	elif tag=="cancelbutton":complete(false,null)
	elif tag=="okbutton" and state.selected_race()>=0:complete(true,current_subrace if subrace_accepted else null)
func complete(accepted: bool,value: Variant) -> void:
	var ticket:=scope.duplicate();var id: int=state.selected_race();dismiss();finished.emit(accepted,id,value,ticket)
func subrace_result(accepted: bool,value: String,ticket: Array) -> void:
	if closed or not wanted or subrace_scope!=ticket:return
	subrace_scope=[];modal.hide()
	if accepted:subrace_accepted=true;complete(true,value)
func place_subrace() -> void:
	if is_instance_valid(subrace):subrace.position=(size-subrace.size)*.5
func retire_input() -> void:
	super.retire_input()
	if is_instance_valid(subrace):subrace.dismiss()
	subrace_scope=[]
	if is_instance_valid(modal):modal.hide()
func close() -> void:
	if closed:return
	if is_instance_valid(subrace):subrace.close()
	super.close()
