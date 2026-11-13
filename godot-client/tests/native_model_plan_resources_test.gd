extends "res://tests/native_model_control_resources_test.gd"
const Plans=preload("res://systems/native_data/model_control_plan.gd")
func configure_pose_candidate(animation,candidate: bool) -> void:
	animation.pose.compiled_controls=true;animation.pose.direct_flush=true;animation.pose.bulk_evaluation=true;animation.pose.prepared_plan=candidate
func resource_evidence(a: Dictionary,b: Dictionary) -> Dictionary:
	check(a.animation.pose.prepared_calls==0 and b.animation.pose.prepared_calls>0,"Only the candidate actually executes prepared immutable keys")
	check(b.animation.pose.prepared_failures==0 and b.animation.pose.plan_prepare_failures==0 and b.animation.pose.bulk_failures==0,"Every admitted original clip prepares and evaluates without fallback/failure")
	return {"prepared_calls":b.animation.pose.prepared_calls,"requests":b.animation.pose.plan_requests,"builds":b.animation.pose.plan_builds,"hits":b.animation.pose.plan_hits,"prepare_ms":b.animation.pose.plan_prepare_ms,"prepare_peak_ms":b.animation.pose.plan_prepare_peak_ms,"plan_bytes":Plans.retained().bytes,"plan_pools":Plans.retained().pools,"plan_key_floats":Plans.retained().key_floats}
func exercise(name: String,result: Dictionary) -> void:
	super.exercise(name,result)
	check(Plans.retained().plans==0,"Closing original model owners releases all cached plan roots and packed storage")
func resource_scope() -> String:
	return "Eleven installed original models, all 68 admitted clips and 1632 frames, with compiled bulk hierarchy and direct publication on BOTH sides. Only typed immutable controller/key preparation differs. Exact Part bytes/local transforms/events/loop/reverse/manual/diagnostics remain equal; cold preparation and weak-cache cleanup are observed. Full scenes/performance are separate."
