extends Control
# Applied only to otherwise scriptless source controls. It changes no input,
# focus, sizing, signals or tooltip_text; the shared native router owns display.
func _get_tooltip(_position: Vector2) -> String:
	return "" if get_meta("native_tooltip_managed",false) else tooltip_text
