extends "res://tests/native_model_control_resources_test.gd"
const Pose=preload("res://systems/model_native_pose.gd")
class CountedPose extends Pose:
	var read_arrays:=0
	func read(part: Dictionary,offset: int,count: int) -> Array:
		read_arrays+=1
		return super.read(part,offset,count)
func configure_pose_candidate(animation,compiled: bool) -> void:
	animation.pose=CountedPose.new(); animation.pose.compiled_controls=compiled
	animation.pose.root_hierarchy=compiled; animation.pose.direct_flush=compiled
func resource_evidence(a: Dictionary,b: Dictionary) -> Dictionary:
	check(a.animation.pose.read_arrays>0 and b.animation.pose.read_arrays==0,"Actual original model publication constructs no direct-path read Arrays")
	check(b.animation.pose.direct_flush_calls>0 and b.animation.pose.root_hierarchy_calls>0,"Original clips actually use both candidate paths")
	return {"reference_read_arrays":a.animation.pose.read_arrays,"candidate_read_arrays":b.animation.pose.read_arrays,"direct_flush_calls":b.animation.pose.direct_flush_calls,"root_hierarchy_calls":b.animation.pose.root_hierarchy_calls,"allocation_scope":"Actual read Array constructions observed through a test-only override, not total engine allocation counts."}
