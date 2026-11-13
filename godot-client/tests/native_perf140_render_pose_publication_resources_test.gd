extends "res://tests/native_model_control_resources_test.gd"

func configure_pose_candidate(animation, compiled: bool) -> void:
	# Both sides use the same compiled controller arithmetic and original three
	# native Node setters. Only the candidate retains stabilized republication.
	animation.pose.compiled_controls = true
	animation.pose.bulk_evaluation = true
	animation.pose.prepared_plan = true
	animation.pose.direct_flush = true
	animation.pose.root_hierarchy = true
	animation.pose.native_storage = compiled

func resource_evidence(a: Dictionary, b: Dictionary) -> Dictionary:
	check(a.animation.pose.native_context == null and b.animation.pose.native_context != null, "Distinct original publication and private native retained-publication paths")
	var statistics: Dictionary = b.animation.pose.storage_statistics()
	check(statistics.has("publication_live_checks"), "Private publication counters exist only at explicit statistics boundary")
	return {"publication_statistics": statistics}

func resource_scope() -> String:
	return "Eleven actual installed original resources, all original clips and exact Part/transform/event/lifetime comparisons. Both sides use compiled controller arithmetic; original publication is the reference. This is a headless component gate, not multiplayer, GPU or whole-room FPS acceptance."
