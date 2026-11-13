extends RefCounted
# One explicit native readback after measurement, never a frame callback.
const Existing=preload("res://tools/perf140/driver/particle_modes_dump.gd")
static func capture(world: Node) -> Dictionary:
	var result: Dictionary=Existing.capture(world)
	result.pose_slots_requested="indexed" if OS.get_cmdline_user_args().has("--particle-pose-slots=indexed") else "ordinary"
	if not is_instance_valid(world) or not world.has_meta("native_particle_stream_group"):return result
	var group: Variant=world.get_meta("native_particle_stream_group")
	if not is_instance_valid(group):return result
	var kernel: Variant=group.get("native")
	if is_instance_valid(kernel):result.pose_slots=kernel.call("dispatch",17,{})
	return result
