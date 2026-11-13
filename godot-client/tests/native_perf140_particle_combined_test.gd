extends "res://tests/native_perf140_particle_common_input_test.gd"
var combined_hits:=0
func _init() -> void:
	experiment_mode="direct_animating"
	experiment_scope="All three particle candidates enabled versus all disabled in the same DLL: synchronous callback-bounded pose sharing, intermediate Controls copy elision and live direct common lookup. Exact failure/retry, state, geometry, RNG, pending controls and mutable input; separate scheduled SceneTree mutation/lifetime oracle. No graphical or FPS acceptance."
func mode_fields() -> PackedStringArray:return PackedStringArray(["reuse_controls","direct_animating"])
func owner_options(reuse: bool) -> Dictionary:return {"reuseFramePose":reuse}
func inspect_pair(a: Dictionary,b: Dictionary) -> void:
	check(a.frame_pose_reuse.hits==0,"Full ordinary oracle performs every live pose read")
	combined_hits+=int(b.frame_pose_reuse.hits)
func finish_experiment(_groups: Array) -> void:
	check(combined_hits>0,"Full candidate actually shares poses while both other reductions are enabled")
