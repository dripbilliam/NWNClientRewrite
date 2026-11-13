extends "res://systems/native_render/native_client_support_scene_parts.gd"
# Separate private activation target; old accepted adapter/Part fixtures stay
# unchanged. Full native BSP ordering/transform parity is still a boundary.
const BoxTrace=preload("res://systems/native_render/native_support_part_trace_box.gd")

func _init() -> void:
	_part_trace=BoxTrace.new()

func snapshot() -> Dictionary:
	var result:=super.snapshot()
	if main_thread():result.ordinary_policy="authored-bounds/no-material-mask/zero-normal"
	return result
