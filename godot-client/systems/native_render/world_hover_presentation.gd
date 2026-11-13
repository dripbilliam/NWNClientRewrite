extends Node
# Pointer-only native doorway presentation. Does not issue an action, change
# received state, create hit/collision geometry or resolve retired IDs anew.
const Hover=preload("res://systems/native_render/transition_door_hover.gd")
var hover_owner:=Hover.new()
var world: WeakRef
var registry: WeakRef
func configure(source: Node,targets: Node) -> void:
	world=weakref(source);registry=weakref(targets)
func select(hit: Dictionary,blocked: bool) -> Dictionary:
	var current: Node=world.get_ref() if world!=null else null
	var targets: Node=registry.get_ref() if registry!=null else null
	if blocked or not is_instance_valid(current) or current.closed or current.retiring or not is_instance_valid(targets):return hover_owner.clear()
	var id:=int(hit.get("id",-1));var entry: Dictionary=current.desired.get(id,{})
	var source: Dictionary=entry.get("object",{})
	var physical: Node3D=current.instances.get(id)
	if int(source.get("objectType",-1))!=10 or not is_instance_valid(physical) or targets.native_owners.get(id)!=physical or str(current.installed.get(id,""))!=str(entry.get("key","")):return hover_owner.clear()
	var actor: Dictionary=current.desired.get(current.controlled_id,{}).get("object",{})
	var controlled: bool=int(actor.get("objectType",-1))==5 and not actor.get("replicationRemoved",false) and int(actor.get("areaId",-1))==current.area_id
	var transition: Variant=source.get("replicated",{}).get("hasTransition")
	if not transition is bool and not ((transition is int or transition is float) and is_finite(float(transition)) and (float(transition)==0.0 or float(transition)==1.0)):
		hover_owner.clear();return {"available":false,"suppress_hover":false,"reason":"received-transition-flag-unavailable"}
	# No replicated Useable field is substituted for native object+11c. Its
	# original constructor default1 is the helper's explicit default gate.
	return hover_owner.update(physical,{"controlled_present":controlled,"has_transition":bool(transition)})
func snapshot() -> Dictionary:return hover_owner.snapshot()
func _exit_tree() -> void:hover_owner.close();world=null;registry=null
