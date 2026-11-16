extends SceneTree
const Controller=preload("res://systems/native_data/godot_login_profile_controller.gd")
const Store=preload("res://systems/native_data/client_settings_store.gd")

func _initialize()->void:
	var directory: String=""
	var expect_unlock:=false
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--directory="):directory=argument.trim_prefix("--directory=")
		if argument=="--expect-unlock":expect_unlock=true
	if not directory.is_absolute_path():fail("disposable settings directory unavailable");return
	var file:=directory.path_join("client-settings.json")
	var original:=FileAccess.get_file_as_bytes(file)
	var parsed: Variant=JSON.parse_string(original.get_string_from_utf8())
	if not parsed is Dictionary or int(parsed.get("version",0))!=Store.CURRENT_VERSION:fail("expected current settings copy");return
	var controller:=Controller.new()
	if not controller.open(directory,"",0,func(_message: Dictionary):pass,func()->bool:return false,func(_status: Dictionary):pass):fail("profile controller could not open current copy");return
	if not bool(controller.legacy_upgrade.get("alreadyCurrent",false)):fail("current copy started an old-format import");return
	var result: Dictionary=controller.store.cd_key()
	var unlocked:=not result.has("error")
	if unlocked:
		var key: String=str(result.get("cdKey",""))
		unlocked=Store.valid_cd_key_bytes(key.to_utf8_buffer())
		key=""
		result.cdKey=""
	if unlocked!=expect_unlock:fail("saved key unlock result differed from expected Windows identity");return
	controller.close()
	if FileAccess.get_file_as_bytes(file)!=original:fail("disposable settings copy changed");return
	for name in DirAccess.get_files_at(directory):
		if name.begins_with("client-settings.pre-nwn79-"):fail("current copy wrote an upgrade backup");return
	print("NWN79 disposable current-key check PASS: unlock_matched_expected=true one_time_import_skipped=true copy_unchanged=true")
	quit(0)

func fail(reason: String)->void:
	printerr("NWN79 disposable current-key check failed: "+reason)
	quit(1)
