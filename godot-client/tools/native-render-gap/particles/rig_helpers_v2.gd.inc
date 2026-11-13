# This table is separate from entities: a publisher retains its input entry,
# and putting the publisher inside that entry would create a reference cycle.
static func configured_native_skin_publisher() -> bool:
	return ClassDB.class_exists("NwnRigSkinPublisher") and OS.get_cmdline_user_args().has("--rig-skin-publisher=native")
var use_native_skin_publisher: bool=configured_native_skin_publisher()
var native_skin_publishers: Dictionary={}
var native_skin_reentrant_fallbacks: int=0

func _publish_skin_native(id: int,entry: Dictionary) -> Variant:
	if not use_native_skin_publisher:return 1
	var binding: Array=native_skin_publishers.get(id,[])
	if binding.is_empty() or not is_same(binding[0],entry):
		var publisher: RefCounted=ClassDB.instantiate("NwnRigSkinPublisher")
		if not bool(publisher.call("configure",entry)):return 1
		binding=[entry,publisher];native_skin_publishers[id]=binding
	var status: int=int(binding[1].call("publish"))
	# Existing ModelRigs allows a force-update listener to recurse into _update.
	# The engine rejects before touching its outer scratch, so this nested call
	# must use the original script branch and its own local rigid array.
	if status==3:
		native_skin_reentrant_fallbacks+=1
		return 1
	if status==2:
		var continuation: Dictionary=binding[1].call("take_continuation")
		if not continuation.is_empty():return continuation
	if status>1:
		var message: String="Native skin publication interrupted at a callback boundary: "+str(status)
		if not stats.failures.has(message):stats.failures.append(message)
		push_error(message)
	return status

func native_skin_snapshot(id: int) -> Dictionary:
	var binding: Array=native_skin_publishers.get(id,[])
	return binding[1].call("inspect") if not binding.is_empty() else {}

func native_skin_publication_snapshot() -> Dictionary:
	var out: Dictionary={"enabled":use_native_skin_publisher,"publishers":native_skin_publishers.size(),"reentrant_fallbacks":native_skin_reentrant_fallbacks,"totals":{},"entries":[]}
	for id: int in native_skin_publishers:
		var row: Dictionary=native_skin_snapshot(id)
		for key: String in ["calls","completed","fallbacks","partial_failures","continuations","node_reads","bone_writes","force_calls"]:out.totals[key]=int(out.totals.get(key,0))+int(row.get(key,0))
		row.id=id;out.entries.append(row)
	return out

