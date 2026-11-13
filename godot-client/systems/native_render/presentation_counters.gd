extends RefCounted
# Small HUD/readiness view. Detailed diagnostic owners keep their existing
# snapshot contract and are sampled only when an observation is actually sent.
static func capture(world) -> Dictionary:
	var errors: Array=world.stats.errors.duplicate(true)
	if is_instance_valid(world.surface): errors.append_array(world.surface.stats.errors.duplicate(true))
	return {
		"area_id":world.area_id,"generation":world.generation,"controlled_id":world.controlled_id,
		"entities":world.instances.size(),"desired":world.desired.size(),"pending_batches":world.batches.size(),
		"ready":world.ready_for_control(),"admission_ready":world.ready_for_admission(),
		"errors":errors,"failed_objects":world.failed_objects.duplicate(true),
		"terrain":{"tiles":world.terrain.definition.get("tiles",[]).size(),"rendered_tiles":world.terrain.completed_tiles} if is_instance_valid(world.terrain) else {},
		"pool":{"meshes_created":world.pool.stats.meshes_created,"textures_created":world.pool.stats.textures_created}
	}
