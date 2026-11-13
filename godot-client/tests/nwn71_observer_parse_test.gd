extends SceneTree
const Observer=preload("res://tests/nwn71_app_frame_observer.gd")
const Fence=preload("res://tests/nwn71_presentation_fence.gd")
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var output:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):output=arg.trim_prefix("--report=")
	if output.is_empty() or FileAccess.file_exists(output):quit(2);return
	var script: Script=Observer;var helper: Script=Fence
	var node:=Observer.new();root.add_child(node)
	var passed:=script.can_instantiate() and helper.can_instantiate() and node.headless and not RenderingServer.frame_pre_draw.is_connected(node.before_draw)
	node.free()
	var file:=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify({"passed":passed,"scope":"Tiny isolated observer/helper parser and dummy-renderer non-stranding check; no actual app or GPU acceptance."}));file.close();quit(0 if passed else 1)
