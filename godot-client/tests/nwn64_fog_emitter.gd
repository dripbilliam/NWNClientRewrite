extends "res://systems/native_render/particle_emitter.gd"
# Preserve the complete actual tick/process/lifecycle methods. Only normal
# model/texture setup is bypassed for this prefix fixture's explicit state.
func _ready() -> void:set_process(false)
