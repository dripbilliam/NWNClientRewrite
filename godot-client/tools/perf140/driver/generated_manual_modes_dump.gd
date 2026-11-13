extends RefCounted
# Explicit end-of-window readback only. Does not add a frame callback or store.
const Existing=preload("res://tools/perf140/driver/particle_modes_dump.gd")
static func capture(world: Node) -> Dictionary:
	var result: Dictionary=Existing.capture(world)
	result.generated_manual_requested="retained" if OS.get_cmdline_user_args().has("--generated-light-manual=retained") else "original"
	result.generated_manual_rigs=[]
	if not is_instance_valid(world):return result
	var pending: Array[Node]=[world]
	while not pending.is_empty():
		var node: Node=pending.pop_back()
		if node.has_method("generated_manual_snapshot"):
			result.generated_manual_rigs.append(node.generated_manual_snapshot())
		pending.append_array(node.get_children())
	return result
