extends "res://tests/native_model_plan_resources_test.gd"
func configure_pose_candidate(animation,candidate: bool) -> void:
	animation.pose.compiled_controls=true;animation.pose.direct_flush=true;animation.pose.bulk_evaluation=true
	if not candidate:animation.pose.prepared_plan=false
func resource_evidence(a: Dictionary,b: Dictionary) -> Dictionary:
	var result:=super.resource_evidence(a,b)
	check(OS.get_environment("NWN_MODEL_PLAN").is_empty() and not OS.get_cmdline_user_args().has("--model-plan=prepared") and b.animation.pose.prepared_plan,"Default original-model owner selects and actually executes prepared plans without a launch/test override")
	result.default_selection=true;return result
