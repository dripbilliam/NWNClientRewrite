extends RefCounted
# Main-thread sidecar for immutable admitted animation roots. Owners retain the
# plan; the shared lookup keeps WeakRefs only and cannot pin retired resources.
# A new resource generation supplies a different root identity and a new plan.
static var live: Array[WeakRef]=[]
var source: Dictionary
var blob: PackedByteArray
var statistics: Dictionary
static func acquire(root_node: Dictionary) -> Dictionary:
	for index in range(live.size()-1,-1,-1):
		var item=live[index].get_ref()
		if item==null: live.remove_at(index)
		elif is_same(item.source,root_node): return {"value":item,"hit":true}
	if not ClassDB.class_exists("NwnParticleKernel") or not ClassDB.class_has_method("NwnParticleKernel","model_prepare"): return {"error":"Native model plan preparation unavailable"}
	var result: Dictionary=ClassDB.class_call_static("NwnParticleKernel","model_prepare",root_node)
	if result.has("error"): return result
	var item=load("res://systems/native_data/model_control_plan.gd").new()
	item.source=root_node;item.blob=result.plan;result.erase("plan");item.statistics=result
	live.append(weakref(item));return {"value":item,"hit":false}
static func retained() -> Dictionary:
	var nodes:=0;var controllers:=0;var pools:=0;var keys:=0;var bytes:=0
	for index in range(live.size()-1,-1,-1):
		var item=live[index].get_ref()
		if item==null: live.remove_at(index);continue
		nodes+=int(item.statistics.nodes);controllers+=int(item.statistics.controllers);pools+=int(item.statistics.pools);keys+=int(item.statistics.key_floats);bytes+=item.blob.size()
	return {"plans":live.size(),"nodes":nodes,"controllers":controllers,"pools":pools,"key_floats":keys,"bytes":bytes}
