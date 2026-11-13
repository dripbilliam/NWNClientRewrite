func accepted_bundle_shutdown_snapshot() -> Dictionary:
	# This function runs once after the timed window closes, before world owners
	# are retired. No new per-frame scan, cache, clock or authored callback.
	var core: Dictionary=runtime_feature_report.render_core_observation()
	var out: Dictionary={"version":1,"enabled":not core.flags.is_empty(),"flags":core.flags,"scope":"One cold final normal-bundle receipt; zero use can be legitimate outside the matched heavy-world acceptance cohort"}
	if not out.enabled:return out
	out.engine_features=core.feature_totals
	out.diagnostics={"profiling":FrameProfile.enabled,"pacing":{}}
	if ClassDB.class_exists("NwnFramePacing") and ClassDB.class_has_method("NwnFramePacing","snapshot"):
		out.diagnostics.pacing=ClassDB.class_call_static("NwnFramePacing","snapshot",1)
	out.skin_owners=[]
	if not is_instance_valid(world):return out
	if is_instance_valid(world.focus_lighting) and world.focus_lighting._input_registry.native!=null:
		out.light_inputs=world.focus_lighting._input_registry.native.call("dispatch",9,{})
	if is_instance_valid(world.particle_stream_group) and world.particle_stream_group.native!=null:
		var native_owner: RefCounted=world.particle_stream_group.native
		out.particle_boundary=native_owner.call("dispatch",13,{})
		out.particle_setup=native_owner.call("dispatch",16,{})
		out.hot_parameters=native_owner.call("dispatch",18,{})
	for owner: Node in world.find_children("*","Node",true,false):
		if owner.get_script()==preload("res://systems/model_rigs.gd"):
			out.skin_owners.append(owner.call("native_skin_publication_snapshot"))
	return out

