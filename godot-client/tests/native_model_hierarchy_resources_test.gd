extends "res://tests/native_model_control_resources_test.gd"
func configure_pose_candidate(animation,candidate: bool) -> void:
	animation.pose.compiled_controls=true;animation.pose.direct_flush=true;animation.pose.root_hierarchy=true;animation.pose.bulk_evaluation=candidate
func resource_evidence(a: Dictionary,b: Dictionary) -> Dictionary:
	check(a.animation.pose.bulk_calls==0 and b.animation.pose.bulk_calls>0,"Only candidate uses native bulk hierarchy")
	check(b.animation.pose.bulk_controls>0 and b.animation.pose.bulk_failures==0,"Actual native bulk controls execute without failure")
	check(a.animation.pose.compiled_controls and b.animation.pose.compiled_controls,"Both resource paths retain compiled controller arithmetic")
	return {"bulk_calls":b.animation.pose.bulk_calls,"bulk_controls":b.animation.pose.bulk_controls,"bulk_empty_controls":b.animation.pose.bulk_empty_controls,"bulk_failures":b.animation.pose.bulk_failures,"reference_controls":"compiled","candidate_controls":"compiled"}
func resource_scope() -> String:
	return "Eleven original installed resources, all 68 admitted clips and 1632 fixed frames, with exact Part bytes/local transforms/run events across reverse playback, loops, manual gates and cleanup. Both paths keep compiled controller arithmetic, direct publication and root-quantized hierarchy; only private bulk traversal/dispatch differs. Full scenes and GPU pixels remain separate."
