extends SceneTree
# Compile the actual gameplay entry and instantiated local action probes, so a
# nested preload failure cannot be mistaken for a completed server-input run.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var output:=""; var failures: Array=[]; var checks:=0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.trim_prefix("--report=")
	if output.is_empty() or FileAccess.file_exists(output): quit(2); return
	for path in ["res://tests/native_live_item_tooltip_probe.gd","res://tests/native_live_hud_probe.gd","res://tests/native_live_actions_probe.gd","res://native_session_world.gd"]:
		var script=load(path); checks+=1
		if script==null or not script.can_instantiate(): failures.append(path); continue
		# RefCounted probes must construct, not merely parse. Scene owners are
		# checked without entering the tree or opening a connection/window.
		if path.ends_with("native_live_item_tooltip_probe.gd") or path.ends_with("native_live_hud_probe.gd"):
			var probe=script.new(); checks+=1
			if probe==null: failures.append(path+": instantiate")
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Actual live entry/probe dependency compilation and RefCounted construction; no server, window or gameplay acceptance."},"\t")); file.close(); quit(0 if failures.is_empty() else 1)
