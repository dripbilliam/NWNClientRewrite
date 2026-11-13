extends SceneTree
# Compile the exact future entry/probe graph; never instantiate a session,
# gameplay world, socket, key owner or server merely to validate source.
const Entry=preload("res://tests/native_script_floating_world.gd")
func _initialize()->void:
	var output:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):output=arg.trim_prefix("--report=")
	if output.is_empty() or FileAccess.file_exists(output):quit(2);return
	var success: bool=Entry!=null
	var file:=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify({"success":success,"checks":1,"failures":[] if success else ["Current native test entry did not compile"],"scope":"Current full native SessionWorld/custom ScriptFloating entry and final live-probe source compile only; no runtime world/server/key/GPU instance."})+"\n");file.close();quit(0 if success else 1)
