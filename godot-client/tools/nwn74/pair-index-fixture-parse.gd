extends SceneTree

func _initialize() -> void:
	call_deferred("_check")

func _check() -> void:
	var fixture: Script=load("res://tools/nwn74/pair-index-gpu-fixture.gd")
	var ok:=fixture!=null and ClassDB.class_exists("NwnFrameProbe")
	print(JSON.stringify({"issue":"NWN-74","fixture_loaded":fixture!=null,"probe_available":ClassDB.class_exists("NwnFrameProbe"),"ok":ok}))
	quit(0 if ok else 1)
