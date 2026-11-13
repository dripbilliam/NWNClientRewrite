extends SceneTree
const SessionEntry=preload("res://native_session_world.gd")
const SourceProbe=preload("res://tests/native_live_level_up_source_probe.gd")
func _initialize() -> void:
	var output:=""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="):output=argument.trim_prefix("--report=")
	if output.is_empty() or FileAccess.file_exists(output):quit(2);return
	var file:=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify({"success":SessionEntry!=null and SourceProbe!=null,"checks":1,"scope":"Current actual SessionWorld root and source-only level-up driver compile. No application entry, socket, key, game server or user-process action."}));file.close();quit()
