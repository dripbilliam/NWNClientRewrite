extends RefCounted
# Explicit post-window witness; no per-frame Variant readback is introduced.
const Existing=preload("res://tools/perf140/driver/particle_modes_dump.gd")
static func capture(world: Node) -> Dictionary:
	var result: Dictionary=Existing.capture(world)
	result.engine_reads={"available":false,"reason":"native readback unavailable"}
	if ClassDB.class_exists(&"NwnParticleKernel") and ClassDB.class_has_method(&"NwnParticleKernel",&"engine_read_snapshot"):
		var snapshot: Variant=ClassDB.class_call_static(&"NwnParticleKernel",&"engine_read_snapshot")
		result.engine_reads=snapshot if snapshot is Dictionary else {"available":false,"reason":"native readback type invalid"}
	return result
