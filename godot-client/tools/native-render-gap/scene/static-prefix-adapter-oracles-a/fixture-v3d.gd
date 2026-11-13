extends "res://tools/native-render-gap/scene/static-prefix-adapter-oracles-a/fixture-v3c.gd"
# REQUIRED last-state-retention witness counterexample. Source only/unparsed.
class MutatingPayload extends RefCounted:
	var owner: WeakRef
	var events: Array
	func _notification(what: int)->void:
		if what!=NOTIFICATION_PREDELETE:return
		events.append(["last-state-payload-predelete"])
		var current=owner.get_ref()
		if not is_instance_valid(current):return
		# Original second-group bounds local was already assigned before its
		# state iterator releases the first group's now-detached last state.
		var bounds: Dictionary=current.static_groups.second.bounds
		bounds.min_x=-1.0;bounds.min_y=-1.0;bounds.max_x=1.0;bounds.max_y=1.0
		events.append(["second-far-bounds-made-near"])
class ClearingFirstIndex extends RefCounted:
	var owner: WeakRef
	var events: Array
	func _notification(what: int)->void:
		if what==NOTIFICATION_PREDELETE:events.append(["clearing-first-index-predelete"])
	func query(ticket: Dictionary,a: Vector3,b: Vector3,radius: float,exclude: int,creatures: bool)->Dictionary:
		events.append(["clear-first-state-query",ticket.duplicate(true),a,b,radius,exclude,creatures])
		owner.get_ref().model_bounds.first.clear()
		events.append(["after-prior-state-array-clear"])
		return {"ready":true,"rows":[]}
	func query_flat_control(ticket: Dictionary,a: Vector3,b: Vector3,radius: float,exclude: int,creatures: bool)->Dictionary:return query(ticket,a,b,radius,exclude,creatures)
func build_owner()->Node:
	var owner: Node=super.build_owner()
	if mode!="state-last-removed-makes-far-near":return owner
	var payload:=MutatingPayload.new();payload.owner=weakref(owner);payload.events=events
	var last: Dictionary=state();last.ignored_payload=payload
	owner.model_bounds.first=[state(),last]
	owner.static_groups.second.bounds={"min_x":1000.0,"min_y":1000.0,"max_x":1001.0,"max_y":1001.0}
	owner.static_groups.third.bounds={}
	var index:=ClearingFirstIndex.new();index.owner=weakref(owner);index.events=events
	owner.static_groups.first.index=index
	return owner
