extends "res://tests/native_perf140_particle_combined_test.gd"
var census_windows:=0
func _init() -> void:
	experiment_mode="direct_animating"
	experiment_scope="Profile-only particle census partition invariants plus all-off/all-on exact native state/geometry/RNG/mutation/failure oracle. Counts are instrumented diagnostics; no graphical or FPS acceptance."
func check_frame_output(group: Dictionary,output: Dictionary) -> void:
	if output.has("error") or not output.has("phases"):return
	var p: Dictionary=output.phases
	var c:={}
	for field in ["registered","disabled","ineligible","eligible","missing_source","readiness_probes","waiting_ready","actor_clocks","static_modulo_clocks","static_unbounded_clocks","empty_before","empty_after","nonempty_after","zero_birth_after","zero_life_after","paused_after","chunk_after","wind_after","geometry_emitters","pose_reuse_hits","pose_live_reads","pose_invalidations"]:
		check(p.has("count_particle_native_"+field),"Profile census publishes "+field)
		c[field]=int(p.get("count_particle_native_"+field,-1))
	check(c.registered==5 and c.disabled+c.ineligible+c.eligible==c.registered,"Eligibility partitions every registered identity")
	check(output.prepared+output.fallbacks+c.missing_source+c.waiting_ready==c.eligible,"Live source/readiness partitions every eligible identity")
	check(c.actor_clocks+c.static_modulo_clocks+c.static_unbounded_clocks==output.prepared,"Clock categories partition successfully prepared owners")
	check(c.empty_after+c.nonempty_after==output.prepared,"Post-step activity categories partition owners")
	check(c.empty_before<=output.prepared and c.zero_birth_after<=output.prepared and c.zero_life_after<=output.prepared and c.paused_after<=output.prepared,"Inactive/paused diagnostics stay inside prepared owners")
	check(c.geometry_emitters<=output.prepared-output.culled,"Only admitted prepared owners can publish vertices")
	check(c.pose_reuse_hits>=0 and c.pose_live_reads>=0 and c.pose_invalidations>=0,"Pose sharing counters are nonnegative")
	if not group.reuse:check(c.pose_reuse_hits==0,"Full ordinary oracle has no shared pose reads")
	census_windows+=1
func finish_experiment(groups: Array) -> void:
	super.finish_experiment(groups)
	check(census_windows>50,"Profiled census path actually executes")
