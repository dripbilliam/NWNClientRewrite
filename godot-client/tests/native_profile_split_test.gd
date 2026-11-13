extends SceneTree
const Labels=preload("res://systems/native_render/protocol_profile_labels.gd")
const Profile=preload("res://systems/native_render/frame_profile.gd")
var checks:=0
var failures: Array=[]
func _initialize() -> void:call_deferred("run")
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label)
func run() -> void:
	var report:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):report=arg.substr(9)
	if report.is_empty() or FileAccess.file_exists(report):quit(2);return
	check(Labels.message_kind("replay-movement-input")=="replay-movement-input","Replay preview work has its own label")
	check(Labels.message_kind("movement")=="movement" and Labels.message_kind("drive-ack")=="drive-ack","Live movement and acknowledgments stay distinct")
	check(Labels.message_kind("native-clock-protocol")=="native-clock-protocol" and Labels.message_kind("raw-tile-visibility")=="raw-tile-visibility","Clock and visibility work stay distinct")
	var unexpected: Dictionary={}
	for id in 200:unexpected[Labels.message_kind("untrusted-"+str(id))]=true
	check(unexpected.keys()==["other"] and Labels.message_kind("")=="other","Arbitrary message names cannot grow metric cardinality")
	var profile:=Profile.new();profile.viewport=root
	Profile.enabled=true;Profile.phase_frame=Engine.get_process_frames()
	Profile.phases={"callback_root":2.0,"protocol_apply":1.5,"protocol_message_replay-movement-input_ms":1.2,"protocol_message_movement_ms":.3,"callback_light_history":3.0,"light_history_registry":2.0,"light_history_view_ms":.1,"light_history_input_poll_ms":1.7,"light_history_input_apply_ms":.2,"light_history_solver":.4,"light_history_publication":.6}
	var now:=Time.get_ticks_usec();profile.previous=now-10000;profile.frame_started=now-6000
	var row:=profile.collect(now)
	check(is_equal_approx(row.accounted_callback_ms,5.0) and is_equal_approx(row.unattributed_callback_ms,1.0),"New child spans do not inflate disjoint callback totals")
	check(is_equal_approx(row.light_history_view_ms+row.light_history_input_poll_ms+row.light_history_input_apply_ms,row.light_history_registry),"Registry boundary children survive collection")
	check(is_equal_approx(row["protocol_message_replay-movement-input_ms"]+row.protocol_message_movement_ms,row.protocol_apply),"Replay and live message children survive separately")
	Profile.enabled=false;Profile.phases.clear();Profile.postdraw_phases.clear()
	Profile.finish("light_history_input_poll_ms",Profile.begin())
	check(Profile.phases.is_empty() and Profile.postdraw_phases.is_empty(),"Disabled instrumentation publishes no new timing data")
	profile.free()
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"publicConnections":0,"scope":"Finite message attribution and overlapping child-span accounting; no gameplay or FPS claim"}
	var file:=FileAccess.open(report,FileAccess.WRITE);file.store_string(JSON.stringify(result));file.close();print(JSON.stringify(result));quit(0 if failures.is_empty() else 1)
