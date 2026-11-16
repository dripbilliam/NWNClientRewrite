extends SceneTree
const Store=preload("res://systems/native_data/client_settings_store.gd")

func _initialize()->void:
	var directory: String=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--directory="):directory=arg.trim_prefix("--directory=")
	if directory.is_empty() or not directory.is_absolute_path():fail("copied profile directory unavailable");return
	var source:=FileAccess.get_file_as_string(directory.path_join("client-settings.json"))
	var store:=Store.new()
	if not store.open(directory):fail("copied profile could not open");return
	var before: Dictionary=store.status()
	var result: Dictionary=store.upgrade_legacy()
	if result.has("error"):fail("copied profile could not upgrade: "+str(result.error));return
	var after: Dictionary=store.status()
	if before.loginProfiles.size()!=after.loginProfiles.size() or before.activeProfileId!=after.activeProfileId:fail("copied profile metadata changed");return
	var credential: Dictionary=store.cd_key()
	if credential.has("error") or RegEx.create_from_string("^[A-Z0-9]{5}(-[A-Z0-9]{5}){6}$").search(str(credential.get("cdKey","")))==null:fail("copied active key is unavailable");return
	if int(result.get("migrated",0))>0:
		var backup:=str(result.get("backup",""))
		if not backup.is_absolute_path() or FileAccess.get_file_as_string(backup)!=source or FileAccess.get_file_as_string(directory.path_join("client-settings.json")).contains(str(credential.cdKey)):fail("copied profile upgrade did not preserve ciphertext");return
	store.close()
	print("NWN79 existing profile copy PASS: profiles=",after.loginProfiles.size()," migrated=",result.get("migrated",0)," active_key_readable=true")
	quit(0)

func fail(reason: String)->void:
	printerr("NWN79 existing profile copy failed: "+reason)
	quit(1)
