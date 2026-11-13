extends SceneTree
const ActionProbe=preload("res://tests/native_live_actions_probe.gd")
const CombatProbe=preload("res://tests/native_live_combat_presentation_probe.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var output:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
	if output.is_empty() or FileAccess.file_exists(output): quit(2); return
	var probe=CombatProbe.new(); var action=ActionProbe.new()
	var ok: bool=probe.has_method("pose_check") and probe.has_method("exercise") and action.has_method("run")
	action.free(); probe=null; await process_frame
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"success":ok,"checks":3,"scope":"Compile/owner construction of approved local combat probe and existing actions dispatcher only; no server action acceptance."})+"\n"); file.close(); quit(0 if ok else 1)
