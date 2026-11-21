extends RefCounted
# src/network_associates.js: server-owned master links, with no inferred scan.
const OBJECT_INVALID:=0x7f000000
static func apply_network_associate_state(actor: Dictionary,state: Dictionary,lookup: Callable) -> void:
	if not state.has("master"):return
	var owner: Variant=lookup.call(state.master)
	if owner is Dictionary and int(owner.get("objectType",0))==5:
		if state.get("field908") is int and int(state.field908)==2:owner.companionId=actor.id
		elif state.get("field908") is int and int(state.field908)==3:owner.familiarId=actor.id
	if state.get("field910") is int and int(state.field910)==0:actor.companionId=OBJECT_INVALID
	if state.get("field914") is int and int(state.field914)==0:actor.familiarId=OBJECT_INVALID
static func network_familiar(registry: Dictionary,actor: Variant) -> Variant:
	var id: Variant=actor.get("familiarId",OBJECT_INVALID) if actor is Dictionary else OBJECT_INVALID
	var familiar: Variant=registry.get(id)
	return familiar if familiar is Dictionary and int(familiar.get("objectType",0))==5 and not bool(familiar.get("replicationRemoved",false)) else null
