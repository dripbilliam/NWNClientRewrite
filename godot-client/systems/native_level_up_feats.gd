extends "res://systems/native_feats_chooser.gd"
# Mode1 uses its private feat adapter, never creation's first-level draft.
func refresh() -> void:
	super.refresh()
	if layout_ready and buttons.has("cancelbutton"):
		buttons.cancelbutton.disabled=modal_active
		buttons.cancelbutton.get_child(0).modulate=Color(.5,.5,.5,1) if modal_active else Color.WHITE
func invoke(tag: String) -> void:
	if tag=="cancelbutton":
		if valid_press(tag) and not modal_active:
			var identity:=scope.duplicate();dismiss();finished.emit(false,identity)
		return
	super.invoke(tag)
func _input(event: InputEvent) -> void:
	# An active group/info popup owns Escape before its parent. Keep the
	# inherited admission check and popup lifetime semantics intact.
	if available() and not modal_active and event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_ESCAPE:
		var identity:=scope.duplicate();dismiss();finished.emit(false,identity);get_viewport().set_input_as_handled();return
	super._input(event)
