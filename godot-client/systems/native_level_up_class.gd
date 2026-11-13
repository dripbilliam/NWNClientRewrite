extends "res://systems/native_class_chooser.gd"
const LevelState=preload("res://systems/native_data/level_up_class_state.gd")
var waiting_message:=""
func _init() -> void:super();state=LevelState.new()
func title_caption() -> String:return caption(plan.entries.title)
func set_context(values: Dictionary,recommended: bool,active_text,art,value_scope: Array) -> void:
	waiting_message="";super.set_context(values,recommended,active_text,art,value_scope)
func set_waiting(message: String) -> void:
	retire_input();waiting_message=message;can_recommend=false;refresh()
func refresh() -> void:
	super.refresh()
	if not closed and layout_ready and not waiting_message.is_empty():
		set_button_available("okbutton",false);set_button_available("recommendbutton",false)
		for row in row_buttons:
			row.disabled=true
			if row.get_child_count()>0:row.get_child(0).modulate=Color(.5,.5,.5,1)
		help_region.present_content(data_text if data_text!=null else text_owner,4294967295,4294967295,waiting_message)
func invoke(tag: String) -> void:
	if not waiting_message.is_empty() and tag!="cancelbutton":return
	super.invoke(tag)
func complete(accepted: bool) -> void:
	if accepted and not waiting_message.is_empty():return
	super.complete(accepted)
