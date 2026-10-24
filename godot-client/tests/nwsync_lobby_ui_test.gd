extends SceneTree
const Lobby = preload("res://systems/character_lobby.gd")
var checks := 0
var failures: Array = []
func _initialize() -> void: call_deferred("run")
func check(v: bool,label: String) -> void:
	checks += 1
	if not v: failures.append(label)
func run() -> void:
	var output := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output = arg.trim_prefix("--report=")
	if output.is_empty() or FileAccess.file_exists(output): quit(2); return
	root.size = Vector2i(1200,850)
	var lobby := Lobby.new(); root.add_child(lobby); var requests: Array = []; var progress: Array = []
	lobby.request.connect(func(v): requests.append(v)); lobby.resource_progress.connect(func(v): progress.append(v))
	var state := {"phase":"resources","busy":false,"canCancelJoin":true,"canSelect":false,"connected":true,"resourceProgress":{"phase":"server-content","completed":2,"total":13,"downloadedBytes":1572864}}
	lobby.apply_state({"connection":3,"state":state}); await process_frame; await process_frame
	check(lobby.download_label.visible and lobby.download_bar.visible,"Actual native lobby shows NWSync controls")
	check(lobby.download_label.text.contains("2 / 13") and lobby.download_label.text.contains("1.5 MiB"),"Resource and byte counters appear in the native label")
	check(not lobby.download_bar.indeterminate and lobby.download_bar.max_value == 13 and lobby.download_bar.value == 2,"Known resource count uses determinate progress")
	check(lobby.play_button.disabled and lobby.create_button.disabled,"Unadmitted server resources cannot start a character")
	check(lobby.cancel_button.visible and not lobby.cancel_button.disabled,"Cancel remains available after login's initial busy state ends")
	var point := lobby.cancel_button.get_global_rect().get_center()
	for pressed in [true,false]:
		var motion := InputEventMouseMotion.new(); motion.position = point; root.push_input(motion,true)
		var event := InputEventMouseButton.new(); event.button_index = MOUSE_BUTTON_LEFT; event.position = point; event.pressed = pressed; root.push_input(event,true); await process_frame
	check(requests.any(func(v): return v.kind == "lobby-cancel-join" and v.connection == 3),"Native pointer click sends current-connection download cancellation")
	check(progress.size() == 1 and progress[0].canCancel and not progress[0].canPlay,"Progress observers preserve actual admission/cancel state")
	state.resourceProgress = {"phase":"server-manifest","completed":0,"total":0,"downloadedBytes":0}; lobby.apply_state({"connection":3,"state":state})
	check(lobby.download_bar.indeterminate and lobby.download_label.text.contains("manifest"),"Manifest phase has an indeterminate native control")
	state.resourceProgress = {"phase":"server-content","completed":13,"total":13,"downloadedBytes":0}; lobby.apply_state({"connection":3,"state":state})
	check(lobby.download_label.text.contains("Checking cached"),"Cache checks are labeled without claiming a download")
	state.phase = "character-selection"; state.canSelect = true; state.canCancelJoin = false; lobby.apply_state({"connection":3,"state":state})
	check(not lobby.download_bar.visible and not lobby.download_label.visible,"Download UI retires once resources are admitted")
	state.phase = "resources-unavailable"; state.error = "Required server content could not be loaded"; state.canSelect = false; state.canCancelJoin = true; lobby.apply_state({"connection":3,"state":state})
	check(lobby.message.text.contains("could not be loaded") and lobby.cancel_button.visible,"Failed content has visible feedback and cancellation")
	lobby.apply_state({"connection":4,"state":{"phase":"menu","canJoin":true}})
	check(not lobby.download_bar.visible and lobby.join_button.disabled == false and lobby.cancel_button.visible == false,"A new menu owner retires download state and permits retry")
	lobby.free(); await process_frame
	var file := FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"checks":checks,"failures":failures,"passed":failures.is_empty(),"scope":"Authored native NWSync progress, gate, pointer cancellation, failure/cache/retry controls; actual HTTP/admission tested separately"},"\t")); file.close(); quit(0 if failures.is_empty() else 1)
