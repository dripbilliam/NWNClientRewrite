extends "res://systems/native_school_chooser.gd"
#9c9860 preserves the edited school if Packages cannot load.
signal recommendation_requested(ticket: Array)
const Post=preload("res://systems/native_data/level_up_post_recommendation.gd")
var busy:=false
func set_context(model: Dictionary,recommended: bool,active_text,value_scope: Array,retain_selection: bool=false) -> void:
	busy=false;super.set_context(model,recommended,active_text,value_scope,retain_selection)
func begin_recommendation() -> bool:
	return not closed and wanted and not busy and can_recommend and state.model.get("ready",false)
func apply_recommendation(value: Dictionary) -> Dictionary:
	if closed or not wanted or not state.model.get("ready",false):return {"ready":false,"reason":"The school pane retired."}
	var applied: Dictionary=Post.apply("school",value,state);refresh();return applied
func set_busy(value: bool) -> void:
	if value and not busy:retire_input()
	busy=value;refresh()
func refresh() -> void:
	super.refresh()
	if closed or not layout_ready:return
	buttons.recommendbutton.disabled=not state.model.get("ready",false) or not can_recommend or busy or recommendation_requested.get_connections().is_empty()
	if busy:
		for tag in buttons:buttons[tag].disabled=true
	buttons.cancelbutton.disabled=false
	for tag in buttons:buttons[tag].get_child(0).modulate=Color(.5,.5,.5,1) if buttons[tag].disabled else Color.WHITE
func invoke(tag: String) -> void:
	if tag=="cancelbutton":
		if valid_press(tag):complete(false)
		return
	if tag=="recommendbutton":
		if valid_press(tag) and not busy and state.model.get("ready",false) and can_recommend and buttons.has(tag) and not buttons[tag].disabled:recommendation_requested.emit(scope.duplicate())
		return
	if busy:return
	super.invoke(tag)
func dismiss() -> void:
	busy=false;super.dismiss()
