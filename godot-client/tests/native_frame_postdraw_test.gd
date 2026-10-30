extends SceneTree
const Timing=preload("res://systems/native_render/frame_profile.gd")
var checks:=0
var failures: Array=[]
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label); print("FAIL: ",label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var report:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): report=arg.substr(9)
	if report.is_empty() or FileAccess.file_exists(report): quit(2); return
	var profile:=Timing.new(); root.add_child(profile); profile.configure(root)
	await RenderingServer.frame_post_draw
	check(Timing.collected_frame==Engine.get_process_frames(),"Actual graphical post-draw signal follows the profile collector")
	Timing.record("fixture_cpu_ms",2.5); Timing.count("fixture_count",3)
	check(Timing.postdraw_phases.get("fixture_cpu_ms",0)==2.5,"Late span is retained rather than lost at the next frame boundary")
	await RenderingServer.frame_post_draw
	var matching: Array=[]
	for row in profile.rows:
		if row.has("postdraw_fixture_cpu_ms"): matching.append(row)
	check(matching.size()==1,"Late span is delivered once into the next collected wall interval")
	if not matching.is_empty():
		check(matching[0].postdraw_fixture_cpu_ms==2.5 and matching[0].postdraw_fixture_count==3,"Timing and count values survive the frame boundary exactly")
		check(not matching[0].has("fixture_cpu_ms"),"Late children stay separate from current-frame callback accounting")
	Timing.record("disabled_pending",9.0); profile.set_enabled(false); Timing.record("disabled_record",8.0)
	check(Timing.postdraw_phases.is_empty() and Timing.phases.is_empty(),"Disabling clears pending spans and ignores disabled recordings")
	profile.set_enabled(true)
	await RenderingServer.frame_post_draw
	var stale:=false
	for row in profile.rows:
		stale=stale or row.has("postdraw_disabled_pending") or row.has("disabled_record")
	check(not stale,"Re-enabled profiling never inherits prior-session spans")
	Timing.record("exit_pending",7.0); profile.queue_free(); await process_frame; await process_frame
	check(not Timing.enabled and Timing.postdraw_phases.is_empty() and Timing.collected_frame==-1,"Owner teardown releases static late-span state")
	var output:=FileAccess.open(report,FileAccess.WRITE)
	output.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"publicConnections":0,"scope":"Actual graphical frame_post_draw continuation timing, next-interval delivery, exact values, disable/re-enable and teardown; no GPU performance claim"},"\t")); output.close()
	quit(0 if failures.is_empty() else 1)
