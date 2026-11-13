extends "res://tools/native-render-gap/scene/static-prefix-adapter-oracles-a/fixture-v3b.gd"
# V3/V3b stay immutable. Distinguishes FIRST vs LAST retained state iterator.
class ElementPayload extends RefCounted:
	var label: String
	var events: Array
	func _notification(what: int)->void:
		if what==NOTIFICATION_PREDELETE:events.append(["state-element-predelete",label])
class ClearingIndex extends RefCounted:
	var owner: WeakRef
	var events: Array
	func _notification(what: int)->void:
		if what==NOTIFICATION_PREDELETE:events.append(["clearing-index-predelete"])
	func query(ticket: Dictionary,a: Vector3,b: Vector3,radius: float,exclude: int,creatures: bool)->Dictionary:
		events.append(["clear-state-query",ticket.duplicate(true),a,b,radius,exclude,creatures])
		owner.get_ref().model_bounds.first.clear()
		events.append(["after-state-array-clear"])
		return {"ready":true,"rows":[]}
	func query_flat_control(ticket: Dictionary,a: Vector3,b: Vector3,radius: float,exclude: int,creatures: bool)->Dictionary:return query(ticket,a,b,radius,exclude,creatures)
func build_owner()->Node:
	var owner: Node=super.build_owner()
	if mode!="state-loop-element-clear":return owner
	var values: Array=[]
	for index in 3:
		var payload:=ElementPayload.new();payload.label=str(index);payload.events=events
		var item: Dictionary=state();item.ignored_payload=payload;values.append(item)
	owner.model_bounds.first=values
	owner.static_groups.second.bounds={};owner.static_groups.third.bounds={}
	var index:=ClearingIndex.new();index.owner=weakref(owner);index.events=events
	owner.static_groups.first.index=index
	return owner
