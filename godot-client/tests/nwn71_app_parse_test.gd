extends SceneTree
const App=preload("res://native_session_world.gd")
const Loading=preload("res://systems/native_loading_screen.gd")
const Observer=preload("res://tests/nwn71_app_frame_observer.gd")
func _initialize() -> void:
	var report:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):report=arg.trim_prefix("--report=")
	if report.is_empty() or FileAccess.file_exists(report):quit(2);return
	var app_script: Script=App;var loading_script: Script=Loading;var observer_script: Script=Observer
	var passed:=app_script.can_instantiate() and loading_script.can_instantiate() and observer_script.can_instantiate()
	var file:=FileAccess.open(report,FileAccess.WRITE);file.store_string(JSON.stringify({"passed":passed,"scope":"Actual complete application script/extension parser closure only. No application startup, render fence completion, GPU behavior or performance claim."}));file.close();quit(0 if passed else 1)
