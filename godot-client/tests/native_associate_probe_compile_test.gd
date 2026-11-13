extends SceneTree
const Probe=preload("res://tests/native_live_associate_quickbar_probe.gd")
func _initialize() -> void:
	var output:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):output=arg.trim_prefix("--report=")
	if output.is_empty() or FileAccess.file_exists(output):quit(2);return
	var instance:=Probe.new();var good:=instance.has_method("run")
	var file:=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify({"success":good,"checks":1,"scope":"Exact authored associate probe parse/constructor only; no game server or activation acceptance."}));file.close();quit(0 if good else 1)
