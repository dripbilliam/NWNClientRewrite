extends SceneTree
const Probe=preload("res://tests/native_live_associate_record_probe.gd")
func _initialize()->void:call_deferred("run")
func run()->void:
	var probe=Probe.new()
	var success:bool=probe.has_method("run") and probe.has_method("inspect_row") and probe.has_method("open_creature") and probe.has_method("same_scope")
	var output:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):output=arg.substr(9)
	var result:={"success":success,"checks":1,"scope":"New composed native probe compiles with inherited actual-input helpers; no server, GUI callback, pixels or gameplay acceptance."}
	var file:=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify(result)+"\n");file.close();probe=null;quit(0 if success else 1)
