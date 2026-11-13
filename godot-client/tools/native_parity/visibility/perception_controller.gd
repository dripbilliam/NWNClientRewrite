extends RefCounted
# One presentation owner per entity lifetime, not a new world registry.
# Returning an action does not claim the renderer has executed it successfully.
const Latch=preload("res://tools/native_parity/visibility/perception_latch.gd")
var _state: Dictionary={}
var _retired:=false
func observe(scope: Variant,received_flags: Variant) -> Dictionary:
	if _retired:return {"version":1,"available":false,"action":null,"reason":"controller_retired","state":{},"scope_reset":false}
	var incoming:=Latch.scope_value(scope)
	if not _state.is_empty() and not incoming.is_empty() and incoming!=_state.scope:return {"version":1,"available":false,"action":null,"reason":"controller_scope_mismatch","state":{},"scope_reset":false}
	var transition:=Latch.reduce(_state,scope,received_flags)
	if not transition.state.is_empty():_state=transition.state.duplicate(true)
	return transition.duplicate(true)
func snapshot() -> Dictionary:return {"retired":_retired,"state":_state.duplicate(true)}
func retire() -> void:_retired=true;_state.clear()
