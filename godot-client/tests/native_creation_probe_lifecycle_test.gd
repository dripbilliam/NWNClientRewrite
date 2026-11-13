extends SceneTree
const Probe=preload("res://tests/native_creation_source_live_probe.gd")
class ObservedProbe extends Probe:
	var observed: Dictionary
	func suspended_wait() -> void:
		await wait_for(func():return false,60)
		observed.late+=1
	func suspended_frames() -> void:
		await frames(60)
		observed.late+=1
var checks:=0
var failures: Array=[]
func _initialize() -> void:call_deferred("run")
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label)
func run() -> void:
	var output:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):output=arg.trim_prefix("--report=")
	if output.is_empty() or FileAccess.file_exists(output):quit(2);return
	var live:=Probe.new();root.add_child(live)
	var frame_count:={"value":0};var count_frames:=func():frame_count.value+=1
	process_frame.connect(count_frames);await live.frames(3);process_frame.disconnect(count_frames)
	check(frame_count.value==3,"Normal source-control frame waits still advance three actual frame signals")
	check(await live.wait_for(func():return true,0),"Already-ready source predicates remain immediate")
	check(not await live.wait_for(func():return false,0),"Expired source predicates remain rejected")
	# Return from the probe's own signal emission before freeing this live
	# normal-completion sample; the separate cases below free while suspended.
	await process_frame
	live.free()
	var observed:={"late":0}
	for turn in 3:
		var parent:=Node.new();root.add_child(parent)
		var probe:=ObservedProbe.new();probe.observed=observed;parent.add_child(probe)
		var id:=probe.get_instance_id()
		# Free first within the same global signal emission, before the copied
		# coroutine callback list reaches these probe-owned function states.
		process_frame.connect(func():parent.free(),CONNECT_ONE_SHOT)
		probe.suspended_wait();probe.suspended_frames()
		await process_frame
		await process_frame;await process_frame
		check(not is_instance_id_valid(id) and observed.late==0,"Immediate owner teardown retires both suspended probe waits "+str(turn))
	var file:=FileAccess.open(output,FileAccess.WRITE)
	file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Actual SourceLiveProbe frame/ready/deadline behavior and three immediate host-free cycles with both central async waits pending; strict engine log separately rejects resumed-freed-instance errors. No application entry/network/server/key."},"\t"));file.close()
	quit(0 if failures.is_empty() else 1)
