extends RefCounted
# Private experiment. Preserve host admission/recording readiness; detailed
# diagnostics remain in their owners and the explicit/final full snapshot.
const Counters=preload("res://systems/native_render/presentation_counters.gd")
static func capture(world) -> Dictionary:
	var state:=Counters.capture(world)
	state.observation_schema="compact-counts-v1"
	state.hidden=world.hidden.size()
	state.object_visuals_complete=world.failed_objects.is_empty() and world.stats.errors.is_empty() and world.instances.size()+world.hidden.size()==world.desired.size() and world.batches.is_empty()
	state.playable_ms=world.stats.get("playable_ms")
	state.native_rendering=true
	state.full_migration=false
	var references=world.references
	state.native_references={"pending":references.waiting.size()+references.jobs.size()+references.publication.size()} if is_instance_valid(references) else {}
	return state
