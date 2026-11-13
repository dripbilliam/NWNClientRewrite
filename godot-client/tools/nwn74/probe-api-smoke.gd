extends SceneTree

func _initialize() -> void:
	call_deferred("_check")

func _check() -> void:
	var result := {"issue":"NWN-74", "class_available":ClassDB.class_exists("NwnFrameProbe"), "method_available":false, "frame_available":false}
	if result.class_available:
		result.method_available=ClassDB.class_has_method("NwnFrameProbe", "completed_frame") and ClassDB.class_has_method("NwnFrameProbe", "set_enabled")
		if result.method_available:
			ClassDB.class_call_static("NwnFrameProbe", "set_enabled", true)
			var frame: Dictionary=ClassDB.class_call_static("NwnFrameProbe", "completed_frame")
			result.frame_available=bool(frame.get("available", false))
			ClassDB.class_call_static("NwnFrameProbe", "set_enabled", false)
	print(JSON.stringify(result))
	quit(0 if result.method_available else 1)
