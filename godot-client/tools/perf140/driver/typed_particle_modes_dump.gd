extends RefCounted
# One explicit export after the measured interval; never a frame hook.
const Existing=preload("res://tools/perf140/driver/particle_modes_dump.gd")
static func capture(world: Node) -> Dictionary:
	var result: Dictionary=Existing.capture(world)
	result.input_mode_requested="typed" if OS.get_cmdline_user_args().has("--particle-inputs=typed") else "ordinary"
	if not is_instance_valid(world) or not world.has_meta("native_particle_stream_group"):return result
	var group: Variant=world.get_meta("native_particle_stream_group")
	if not is_instance_valid(group):return result
	var kernel: Variant=group.get("native")
	if is_instance_valid(kernel):result.typed_inputs=kernel.call("dispatch",16,{})
	return result
