extends "res://tests/native_perf140_particle_controls_test.gd"
func _init() -> void:
	experiment_mode="direct_animating"
	experiment_scope="Independent direct live common.animating lookup versus ordinary Dictionary.has/get, without hoisting. Includes missing values, bool/integer/float truth conversion, same-call mutation, callbacks, state/geometry/RNG, failure/retry and lifetime regressions. No graphical or FPS acceptance."
func common_controls(delta: float) -> Dictionary:
	var input:=super.common_controls(delta)
	match oracle_context.frame%8:
		0:input.erase("animating")
		1:input.animating=false
		2:input.animating=true
		3:input.animating=0
		4:input.animating=-1
		5:input.animating=0.0
		6:input.animating=0.125
		7:input.animating=-0.0
	return input
