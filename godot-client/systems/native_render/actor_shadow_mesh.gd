extends MeshInstance3D

signal shadow_input_changed(state_changed: bool)

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		shadow_input_changed.emit(false)
	elif what == NOTIFICATION_VISIBILITY_CHANGED or what == NOTIFICATION_ENTER_TREE or what == NOTIFICATION_EXIT_TREE:
		shadow_input_changed.emit(true)

static func invalidate(mesh: MeshInstance3D) -> void:
	if mesh.has_signal("shadow_input_changed"):
		mesh.emit_signal("shadow_input_changed", true)
