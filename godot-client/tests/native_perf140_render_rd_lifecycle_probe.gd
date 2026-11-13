extends SceneTree

# No application/native extensions, scenes, effects, assets or RD references.
# It asks RenderingServer only about scheduling, then quits normally.
var frames := 0
var render_observed := false

func _initialize() -> void:
	print("NATIVE_RD_LIFECYCLE " + JSON.stringify({"kind": "initialize", "main_is_render_thread": RenderingServer.is_on_render_thread(), "screen": DisplayServer.window_get_current_screen(), "no_focus": DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS)}))
	RenderingServer.call_on_render_thread(Callable(self, "_render_probe"))

func _render_probe() -> void:
	print("NATIVE_RD_LIFECYCLE " + JSON.stringify({"kind": "render_callback", "on_render_thread": RenderingServer.is_on_render_thread()}))
	call_deferred("_record_render_observed")

func _record_render_observed() -> void:
	render_observed = true

func _process(_delta: float) -> bool:
	frames += 1
	if frames >= 3 and render_observed:
		print("NATIVE_RD_LIFECYCLE " + JSON.stringify({"kind": "normal_quit", "frames": frames, "screen": DisplayServer.window_get_current_screen(), "no_focus": DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS)}))
		quit(0)
	elif frames >= 30:
		print("NATIVE_RD_LIFECYCLE " + JSON.stringify({"kind": "probe_incomplete", "frames": frames}))
		quit(2)
	return false
