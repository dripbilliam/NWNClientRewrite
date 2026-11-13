extends "res://tests/native_model_pose_resources_test.gd"
func configure_pose_candidate(animation,compiled: bool) -> void:
	super.configure_pose_candidate(animation,compiled)
	animation.pose.compiled_controls=true
func resource_evidence(a: Dictionary,b: Dictionary) -> Dictionary:
	var result:=super.resource_evidence(a,b)
	check(a.animation.pose.compiled_controls and b.animation.pose.compiled_controls and a.animation.pose.compiled_control_calls>0,"Both original-model paths actually retain compiled controller arithmetic")
	result.reference_controls="compiled"; result.candidate_controls="compiled"
	return result
func resource_scope() -> String:
	return "Eleven actual original resources, 68 clips and exact fixed-frame Part/transform/event comparisons with compiled controller arithmetic in BOTH paths. Only direct pose publishing and root-quantized hierarchy differ. Read Array constructions are observed through a test-only override; they are not all engine allocations or a full-scene performance result."
