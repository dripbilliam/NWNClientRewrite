extends RefCounted
# Original7fd6b0 transition owner, with resource/model/colour boundaries.
# WORD attack values and model slotFB are presentation state, never server rules.
const M=preload("res://systems/native_render/particle_math.gd")
static func resource(item_class: String) -> String:
	var name:=item_class
	# Original appends into a fixed CResRef; longer custom rows have undefined
	# buffer behaviour in this build, not an instruction to reproduce corruption.
	return "" if name.length()>13 else (name+"_mb").to_lower()
static func colour(attack_type: int) -> Variant:
	match attack_type&65535:
		6: return [1.0,0.0,0.0]
		17,23: return [0.0,1.0,0.0]
		9,16: return [0.0,0.0,1.0]
		31: return [1.0,M.f(0.2),1.0]
		65000,65001: return [M.f(0.2),1.0,1.0]
		301: return [0.0,0.5,0.5]
	return null
static func transition(state: Dictionary,enabled: int,item: Variant,providers: Dictionary) -> void:
	if int(state.enabled)==enabled: return
	if item==null:
		providers.unarmed.call(enabled)
		if enabled!=1: state.attackType=0
		state.enabled=enabled; return
	if (int(item.get("itemFlag2a8",0))&255)!=0: return
	if (int(item.modelType)&255)!=2: state.enabled=enabled; return
	if enabled==1:
		var model:=resource(str(item.itemClass))
		if model.is_empty() or not providers.exists.call(model): return
		if not providers.load.call(model,251,0): return
		providers.configure.call(251,0,0)
		var rgb: Variant=colour(int(state.attackType))
		if rgb!=null: providers.colour.call(rgb,4,1)
	else:
		providers.remove.call(251); providers.clear_colour.call(4); state.attackType=0
	state.enabled=enabled
