extends SceneTree
const Creator=preload("res://systems/native_creation.gd")
const Gameplay=preload("res://systems/native_gameplay_ui.gd")
func _initialize() -> void:
	var output:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):output=arg.trim_prefix("--report=")
	if output.is_empty() or FileAccess.file_exists(output):quit(2);return
	var file:=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify({"success":Creator!=null and Gameplay!=null,"checks":1}));file.close();quit()
