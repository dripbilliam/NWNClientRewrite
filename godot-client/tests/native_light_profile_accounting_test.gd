extends "res://tests/native_particle_schedule_test.gd"
const Profile=preload("res://systems/native_render/frame_profile.gd")
func run() -> void:
	var path:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): path=arg.substr(9)
	if path.is_empty() or FileAccess.file_exists(path): quit(2); return
	var profile:=Profile.new(); profile.viewport=root
	Profile.enabled=true; Profile.phase_frame=Engine.get_process_frames()
	Profile.phases={"callback_root":1.0,"callback_light_history":2.0,"callback_focus_lighting":.2,"callback_native_lighting":.1,"light_history_registry":.6,"light_history_solver":.8,"light_history_publication":.6}
	var now:=Time.get_ticks_usec(); profile.previous=now-20000; profile.frame_started=now-8000
	var row:=profile.collect(now)
	check(is_equal_approx(row.accounted_callback_ms,3.3),"Independent lighting owners count once alongside other callbacks")
	check(is_equal_approx(row.unattributed_callback_ms,4.7),"Lighting callbacks are not left in unassigned main-thread work")
	check(row.callback_overlap_ms==0 and row.outside_callback_ms==12,"Child timings do not inflate callback totals or engine/wait time")
	check(is_equal_approx(row.light_history_registry+row.light_history_solver+row.light_history_publication,row.callback_light_history),"History child spans remain visible without being added twice")
	Profile.enabled=false; Profile.phases.clear(); profile.free()
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"row":row,"publicConnections":0,"scope":"Known disjoint main-thread owner and child-span accounting, not actual workload timing or GPU/FPS acceptance."}
	var file:=FileAccess.open(path,FileAccess.WRITE); file.store_string(JSON.stringify(result,"\t")); file.close(); quit(0 if result.success else 1)
