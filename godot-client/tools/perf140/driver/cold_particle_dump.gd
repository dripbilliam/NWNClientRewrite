extends RefCounted
# Called once by a private benchmark's shutdown after its measured interval.
static func read_meta(node: Variant,key: String) -> Variant:
	return node.get_meta(key) if node is Node and node.has_meta(key) else null
static func capture(world: Node3D) -> Dictionary:
	var group: Variant=read_meta(world,"native_particle_stream_group")
	if not is_instance_valid(group) or not group.has_method("cold_particle_census"):return {"error":"No cold particle census owner"}
	var result: Dictionary=group.cold_particle_census()
	if result.has("error"):return result
	for row: Dictionary in result.get("emitters",[]):
		var member: Dictionary=group.members.get(int(row.id),{})
		var handle: Variant=member.get("emitter")
		var emitter: Variant=handle.get_ref() if handle is WeakRef else null
		var source: Variant=emitter.get("source") if is_instance_valid(emitter) else null
		row.direct_tile_index=read_meta(source,"native_tile_index")
		var script: Variant=source.get_script() if source is Node else null
		row.source_script=str(script.resource_path) if script is Script else null
		var parent: Variant=source.get_parent() if source is Node else null
		row.source_parent_tile_index=read_meta(parent,"native_tile_index")
		var parent_script: Variant=parent.get_script() if parent is Node else null
		row.source_parent_script=str(parent_script.resource_path) if parent_script is Script else null
		row.source_parent_model=read_meta(parent,"native_model_name")
	result.capture_scope="One detached cold export after the measurement; no per-frame scan or state mutation"
	return result
