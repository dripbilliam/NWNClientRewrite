extends "res://tests/native_model_control_resources_test.gd"
const Plans=preload("res://systems/native_data/model_control_plan.gd")
func configure_pose_candidate(animation,candidate: bool) -> void:
	animation.pose.compiled_controls=true;animation.pose.direct_flush=true;animation.pose.bulk_evaluation=true;animation.pose.prepared_plan=true;animation.pose.native_storage=candidate
func resource_evidence(a: Dictionary,b: Dictionary) -> Dictionary:
	check(a.animation.pose.native_calls==0 and b.animation.pose.native_calls>0,"Only the candidate executes persistent native Part storage")
	check(b.animation.pose.native_failures==0 and b.animation.pose.bulk_failures==0,"Every original controller frame executes without storage fallback/failure")
	var statistics: Dictionary=b.animation.pose.storage_statistics()
	return {"native_calls":b.animation.pose.native_calls,"native_failures":b.animation.pose.native_failures,"storage":statistics}
func exercise(name: String,result: Dictionary) -> void:
	super.exercise(name,result)
	check(Plans.retained().plans==0,"Closed original owners release persistent state and immutable controller plans")
func resource_scope() -> String:
	return "Eleven installed original models, 68 clips and 1632 frames: prepared compiled math on BOTH sides, persistent storage/native setters only in the candidate. Exact Part bytes/local transforms/events/manual/loop/reverse/diagnostics and cleanup are compared. No performance claim."
