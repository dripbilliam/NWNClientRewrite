extends RefCounted
# Original965cf0/968590/966170: lowest active scope0..4 wins.
const M=preload("res://systems/native_render/particle_math.gd")
static func create() -> Dictionary:
	return {"present":true,"active":[false,false,false,false,false],"colours":[[0.0,0.0,0.0],[0.0,0.0,0.0],[0.0,0.0,0.0],[0.0,0.0,0.0],[0.0,0.0,0.0]]}
static func set_colour(state: Dictionary,scope: int,rgb: Variant) -> bool:
	scope&=255
	if not state.present or scope>=5: return false
	if rgb==null: state.active[scope]=false
	else: state.colours[scope]=M.values(rgb); state.active[scope]=true
	return true
static func selected(state: Dictionary) -> Variant:
	for i in 5:
		if state.active[i]: return state.colours[i].duplicate()
	return null
