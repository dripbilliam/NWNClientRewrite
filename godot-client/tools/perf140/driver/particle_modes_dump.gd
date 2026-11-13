extends RefCounted
# Explicit post-window readback. dispatch(2) builds diagnostics, so never call
# this from the frame loop or include its cost in a performance interval.
static func capture(world: Node) -> Dictionary:
	var result: Dictionary={"after_measured_window":true,"managed_available":ClassDB.class_exists("NwnParticlePoseLease"),"managed_enabled":false,"scope":null,"frame_pose_reuse":null}
	if ResourceLoader.exists("res://systems/native_render/managed_particle_pose_leases.gd"):
		result.managed_enabled=load("res://systems/native_render/managed_particle_pose_leases.gd").enabled()
	if not is_instance_valid(world):return result
	if world.has_meta("native_particle_pose_lease_scope"):
		var token: Variant=world.get_meta("native_particle_pose_lease_scope")
		if is_instance_valid(token) and token.has_method("snapshot"):result.scope=token.snapshot()
	if world.has_meta("native_particle_eligibility_scope"):
		var token: Variant=world.get_meta("native_particle_eligibility_scope")
		if is_instance_valid(token) and token.has_method("snapshot"):result.eligibility_scope=token.snapshot()
	if not world.has_meta("native_particle_stream_group"):return result
	var group: Variant=world.get_meta("native_particle_stream_group")
	if not is_instance_valid(group):return result
	var supports_snapshot:=false
	for property: Dictionary in group.get_property_list():
		if property.name=="scene_snapshot_mode":supports_snapshot=true
	for property: Dictionary in group.get_property_list():
		if property.name=="native":
			var kernel: Variant=group.get("native")
			if is_instance_valid(kernel) and kernel.has_method("dispatch"):
				var state: Dictionary=kernel.call("dispatch",2,{})
				result.frame_pose_reuse=state.get("frame_pose_reuse")
				if supports_snapshot:result.scene_snapshot=kernel.call("dispatch",14,{})
				if ClassDB.class_exists("NwnParticleEligibilityLease"):result.managed_eligibility=kernel.call("dispatch",15,{})
			break
	return result
