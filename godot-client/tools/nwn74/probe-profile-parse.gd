extends SceneTree

func _initialize() -> void:
	call_deferred("_check")

func _check() -> void:
	var profile_script: Script=load("res://systems/native_render/frame_profile.gd")
	var ok:=profile_script!=null and ClassDB.class_exists("NwnFrameProbe") and ClassDB.class_has_method("NwnFrameProbe","completed_frame")
	print(JSON.stringify({"issue":"NWN-74", "profile_loaded":profile_script!=null, "probe_available":ClassDB.class_exists("NwnFrameProbe"), "ok":ok}))
	quit(0 if ok else 1)
