extends SceneTree
var output:=""
var iterations:=100000
var warmup:=2000
var value:=17
func _initialize()->void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):output=arg.trim_prefix("--report=")
		if arg.begins_with("--iterations="):iterations=int(arg.trim_prefix("--iterations="))
		if arg.begins_with("--warmup="):warmup=int(arg.trim_prefix("--warmup="))
	call_deferred("run")
func run()->void:
	if output.is_empty() or FileAccess.file_exists(output) or iterations<240 or warmup<1:quit(2);return
	if not ClassDB.class_exists("NwnFramePacing"):quit(3);return
	# --headless --rendering-method dummy guarantees no graphical/GPU workload.
	# --fixed-fps 1000 disables real-time synchronization and OS frame delay;
	# this is a CPU overhead fixture, never a headless FPS performance claim.
	if ClassDB.class_exists("NwnFrameProbe"):ClassDB.class_call_static("NwnFrameProbe","set_enabled",false)
	var start:=0
	for frame in warmup+iterations:
		if frame==warmup:start=Time.get_ticks_usec()
		value=(value*1664525+1013904223)&0x7fffffff
		value=(value*1103515245+12345)&0x7fffffff
		RenderingServer.force_draw(false,.001)
		await process_frame
	var elapsed:=Time.get_ticks_usec()-start
	RenderingServer.force_sync()
	var pacing: Dictionary=ClassDB.class_call_static("NwnFramePacing","snapshot",256)
	var report: Dictionary={"success":true,"scope":"Deterministic dummy-renderer CPU overhead fixture. Fixed simulation rate bypasses frame-delay throttling; wall and outer-process CPU are separate. No graphical or target-FPS claim.","iterations":iterations,"warmup":warmup,"checksum":value,"workload_wall_us":elapsed,"display":DisplayServer.get_name(),"rendering_method":RenderingServer.get_current_rendering_method(),"max_fps":Engine.max_fps,"low_processor_mode":OS.low_processor_usage_mode,"pacing":pacing}
	var file:=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify(report));file.close();quit()
