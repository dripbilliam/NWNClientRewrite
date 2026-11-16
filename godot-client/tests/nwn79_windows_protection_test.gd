extends SceneTree
const Protection=preload("res://systems/native_data/windows_protection.gd")

func _initialize()->void:
	var api=Protection.new()
	var exe:=ProjectSettings.globalize_path("res://.cache/nwn79/windows-profile.exe")
	if not api.open(exe):
		printerr("NWN79 Windows protection helper unavailable");quit(1);return
	var input: PackedByteArray="synthetic-test-only".to_utf8_buffer()
	var protected: Dictionary=api.protect(input)
	if protected.has("error"):
		printerr("NWN79 protection failed");api.close();quit(1);return
	var unprotected: Dictionary=api.unprotect(protected.bytes)
	if unprotected.has("error") or unprotected.bytes!=input:
		printerr("NWN79 roundtrip failed");api.close();quit(1);return
	api.close()
	print("NWN79 Godot-owned Windows protection PASS")
	quit(0)
