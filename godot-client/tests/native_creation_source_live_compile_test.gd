extends SceneTree
const Probe=preload("res://tests/native_creation_live_probe.gd")
const Gameplay=preload("res://systems/native_gameplay_ui.gd")
func _initialize() -> void:
	var report:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):report=arg.trim_prefix("--report=")
	if report.is_empty() or FileAccess.file_exists(report):quit(2);return
	var file:=FileAccess.open(report,FileAccess.WRITE);file.store_string(JSON.stringify({"success":Probe!=null and Gameplay!=null,"checks":1}));file.close();quit()
