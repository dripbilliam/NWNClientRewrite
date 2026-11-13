extends "res://systems/native_skills_chooser.gd"
# Same original CG_SKILLS controls, supplied by the separate mode1 owner.
# Cancel remains an owner action when rule preparation becomes unavailable.
func refresh() -> void:
	super.refresh()
	if layout_ready and buttons.has("cancelbutton"):buttons.cancelbutton.disabled=false
func invoke(tag: String) -> void:
	if tag=="cancelbutton":
		if valid_press(tag):
			var identity:=scope.duplicate();dismiss();finished.emit(false,identity)
		return
	super.invoke(tag)
func _input(event: InputEvent) -> void:
	if available() and event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_ESCAPE:
		var identity:=scope.duplicate();dismiss();finished.emit(false,identity);get_viewport().set_input_as_handled();return
	super._input(event)
