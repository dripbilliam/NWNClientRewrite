extends "res://tests/native_actor_visual_failure_test.gd"
func actor_batch(world,catalog,rows: Array)->Dictionary:
	# The inherited authored World omits real shadow services. Supply its
	# explicit unavailable weak handle, rather than trigger a missing-meta log.
	if not world.has_meta("native_point_shadow_budget"):
		var absent:=Node.new();world.set_meta("native_point_shadow_budget",weakref(absent));absent.free()
	return await super.actor_batch(world,catalog,rows)
