extends "res://systems/model_rigs.gd"
# Optional private prototype; production model_rigs.gd is not patched.
var _nwb_enabled:=bool(ProjectSettings.get_setting("nwn/rig_animation_batch",false)) and ClassDB.class_exists("NwnRigAnimationBatch")
var _nwb_contexts: Dictionary={}
func _nwb_context(id: int,entry: Dictionary) -> Variant:
	var binding: Array=_nwb_contexts.get(id,[])
	if binding.is_empty() or not is_same(binding[0],entry):
		var context: RefCounted=ClassDB.instantiate("NwnRigAnimationBatch")
		binding=[entry,context];_nwb_contexts[id]=binding
	return binding[1]
func _nwb_release_binding(id: int,entry: Dictionary) -> void:
	var binding: Array=_nwb_contexts.get(id,[])
	if not binding.is_empty() and is_same(binding[0],entry) and (not entities.has(id) or not is_same(entities[id],entry)):_nwb_contexts.erase(id)
func forget_entity(id: int) -> void:
	_nwb_contexts.erase(id)
	super.forget_entity(id)
func _exit_tree() -> void:
	_nwb_contexts.clear()
	super._exit_tree()
func native_batch_snapshot() -> Dictionary:
	var result:={"enabled":_nwb_enabled,"contexts":_nwb_contexts.size(),"totals":{}}
	for binding in _nwb_contexts.values():
		var info: Dictionary=binding[1].inspect()
		for key in ["calls","models","advances","empty_models","interval_models","event_rows","fallbacks","post_fallbacks","reentrant","failures"]:result.totals[key]=int(result.totals.get(key,0))+int(info[key])
	return result
