extends SceneTree
const Probe=preload("res://tests/native_live_world_radial_probe.gd")
const Owner=preload("res://tests/native_live_actions_probe.gd")
func _initialize()->void:
	var output:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):output=arg.trim_prefix("--report=")
	if output.is_empty() or FileAccess.file_exists(output):quit(2);return
	var probe:=Probe.new();var owner:=Owner.new()
	var valid:bool=probe is RefCounted and owner is Node
	owner.free();probe=null
	var file:=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify({"success":valid,"checks":1,"scope":"Compile and construct the exact source live probe closure only; no server/GPU/gameplay outcome."})+"\n");file.close();quit(0 if valid else 1)
