extends "res://systems/native_render/focus_lighting_native_input_candidate.gd"
# Existing adapter/solver/publication code is inherited unchanged. This new
# engine class remains opt-in; no ordinary instantiation path is changed.
func _init() -> void:
	super()
	if OS.get_cmdline_user_args().has("--light-input-registry=builtin"):
		if ClassDB.class_exists("NwnBuiltinLightInputRegistry"):
			input_registry = ClassDB.instantiate("NwnBuiltinLightInputRegistry")
		else:
			push_error("Requested optional builtin light input registry is unavailable")
