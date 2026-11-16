extends SceneTree
const Controller=preload("res://systems/native_data/godot_login_profile_controller.gd")
const KEY="ABCDE-FGHIJ-KLMNO-PQRST-UVWXY-12345-67890"

func _initialize()->void:
	var directory: String=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--directory="):directory=arg.trim_prefix("--directory=")
	if not directory.is_absolute_path():fail("synthetic directory unavailable");return
	var file:=directory.path_join("client-settings.json")
	var original:=FileAccess.get_file_as_string(file)
	var controller:=Controller.new()
	if not controller.open(directory,"",0,func(_message: Dictionary):pass,func()->bool:return false,func(_status: Dictionary):pass):fail("profile controller could not open");return
	var result: Dictionary=controller.legacy_upgrade
	if result.has("error") or not result.get("imported",false) or int(result.get("discardedCredentials",-1))!=3 or not result.get("credentialReentryRequired",false):fail("profile controller did not import settings and flag key re-entry");return
	var backup:=str(result.get("backup",""))
	if not backup.is_absolute_path() or FileAccess.get_file_as_string(backup)!=original:fail("profile import backup differs");return
	if controller.status().hasSavedCdKey or not controller.store.cd_key().has("error"):fail("old key survived settings import");return
	var imported:=FileAccess.get_file_as_string(file)
	controller.handle({"kind":"login-profile-input","connection":0,"requestId":1,"operation":"open"})
	var active: Dictionary=controller.store.active_row(controller.store.state)
	var replacement: Dictionary={"id":active.id,"label":active.label,"playerName":active.playerName,"cdKey":KEY}
	controller.handle({"kind":"login-profile-input","connection":0,"requestId":2,"viewId":controller.view_id,"operation":"save","values":replacement})
	if not replacement.cdKey.is_empty() or controller.legacy_upgrade.get("credentialReentryRequired",true) or not controller.status().hasSavedCdKey:fail("new key was not saved and recovery notice cleared");return
	var unlocked: Dictionary=controller.store.cd_key()
	if unlocked.has("error") or str(unlocked.get("cdKey",""))!=KEY:fail("new Windows-protected key could not be unlocked");return
	unlocked.cdKey=""
	var saved:=FileAccess.get_file_as_string(file)
	if saved==imported or saved.contains(KEY):fail("new key was not stored protected");return
	controller.close()
	var local_state:=directory.path_join("Local State")
	var writer:=FileAccess.open(local_state,FileAccess.WRITE)
	if writer==null:fail("could not change obsolete Chromium source");return
	writer.store_string("broken legacy source");writer.close()
	if not reopen_current(directory,saved):return
	if DirAccess.remove_absolute(local_state)!=OK:fail("could not remove obsolete Chromium source");return
	if not reopen_current(directory,saved):return
	var backups:=0
	for name in DirAccess.get_files_at(directory):
		if name.begins_with("client-settings.pre-nwn79-"):backups+=1
	if backups!=1:fail("later launch repeated settings import");return
	print("NWN79 profile settings import/re-entry PASS: discarded_credentials=3 new_key_protected=true later_launches_skip=true")
	quit(0)

func reopen_current(directory: String,saved: String)->bool:
	var controller:=Controller.new()
	if not controller.open(directory,"",0,func(_message: Dictionary):pass,func()->bool:return false,func(_status: Dictionary):pass):fail("current profile could not reopen");return false
	if not bool(controller.legacy_upgrade.get("alreadyCurrent",false)) or FileAccess.get_file_as_string(directory.path_join("client-settings.json"))!=saved:fail("current profile repeated settings import");return false
	controller.close()
	return true

func fail(reason: String)->void:
	printerr("NWN79 profile settings import/re-entry failed: "+reason)
	quit(1)
