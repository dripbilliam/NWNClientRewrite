extends "res://tools/native-render-gap/scene/static-prefix-adapter-oracles-a/fixture-v3.gd"
# V3 is immutable. These two added cases directly target the original compiler
# inner state FOR @container and Object-key pending-prefix early-return lifetime.
class StatePayload extends RefCounted:
	var label: String
	var events: Array
	func _notification(what: int)->void:
		if what==NOTIFICATION_PREDELETE:events.append(["state-payload-predelete",label])
func build_owner()->Node:
	var requested: String=mode
	if requested=="state-loop-container-replacement":mode="replace-states-then-all-far"
	var owner: Node=super.build_owner()
	mode=requested
	if requested=="state-loop-container-replacement":
		for key in ["first","second","third"]:
			var payload:=StatePayload.new();payload.label=key;payload.events=events
			owner.model_bounds[key][0].ignored_payload=payload
	elif requested=="object-key-pending-prefix":
		var keys: Array=owner.static_groups.keys()
		owner.model_bounds[keys[-1]][0].pending=true
	return owner
