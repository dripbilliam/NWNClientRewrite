extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var output:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
	if output.is_empty() or FileAccess.file_exists(output): quit(2); return
	var failures: Array=[]; var paths: Array=["native_map_panbar","native_map_note_editor","native_map_frame","native_gameplay_ui"]
	for path in paths:
		var script: Script=load("res://systems/"+path+".gd")
		if script==null or not script.can_instantiate(): failures.append(path)
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":paths.size(),"failures":failures,"publicConnections":0,"scope":"Native map/UI dependency compilation only; no input, visual or server acceptance."},"  ")+"\n"); file.close(); quit(0 if failures.is_empty() else 1)
