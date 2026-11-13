extends SceneTree
# Compile/load integration gate only. Does not open a world or simulate actions.
const Door=preload("res://tools/native_parity/doors/door_instance_candidate.gd")
const Registry=preload("res://tools/native_parity/doors/entity_registry_candidate.gd")
const SupportWorld=preload("res://tools/native_parity/loading/support_world_candidate.gd")
func _initialize() -> void:
	var scripts: Array[Script]=[Door,Registry,SupportWorld]
	var accepted: bool=scripts.all(func(script: Script):return script.can_instantiate())
	print("NATIVE_PARITY_CANDIDATE_LOAD ",3 if accepted else 0," checks ",0 if accepted else 1," failures")
	quit(0 if accepted else 1)
