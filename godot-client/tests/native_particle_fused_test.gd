extends "res://tests/native_particle_simulation_test.gd"
# Reuse the full moving-emitter GD comparison with the fused C++ entry. All
# scene/resource/randomization providers remain the real callbacks under test.
func make_owner(compiled: bool,kind: String,flags: int,spatial: bool,chunk: bool) -> Dictionary:
	var owner:=super.make_owner(compiled,kind,flags,spatial,chunk)
	owner.providers.native_update_kind=kind
	if compiled:
		owner.providers.updateEmitter=func(_e,_delta):check(false,"Fused frame unexpectedly crossed the update adapter")
		owner.providers.moveParticles=func(_e,_delta):check(false,"Fused frame unexpectedly crossed the movement adapter")
	return owner
func apply(operation: String,e: Dictionary,delta: float,p: Dictionary,part: Dictionary={},factor: float=1.0) -> Dictionary:
	return super.apply("animate_"+str(p.native_update_kind) if operation=="animate" else operation,e,delta,p,part,factor)
