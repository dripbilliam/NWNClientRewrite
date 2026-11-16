extends SceneTree
const Controller=preload("res://systems/native_data/godot_login_profile_controller.gd")
const Store=preload("res://systems/native_data/client_settings_store.gd")

func _initialize()->void:
	var directory: String=""
	var expect_prior:=false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--directory="):directory=arg.trim_prefix("--directory=")
		if arg=="--expect-prior":expect_prior=true
	if not directory.is_absolute_path():fail("copied settings directory unavailable");return
	var file:=directory.path_join("client-settings.json")
	var original:=FileAccess.get_file_as_string(file)
	var before: Variant=JSON.parse_string(original)
	if not before is Dictionary or int(before.get("version",0))>=Store.CURRENT_VERSION:fail("copied source is not a prior settings version");return
	var discarded:=0
	var expected: Dictionary=before.duplicate(true)
	expected.version=Store.CURRENT_VERSION
	var rows: Array=[expected]
	rows.append_array(expected.get("loginProfiles",[]))
	for row in rows:
		if row is Dictionary and row.has("protectedCdKey") and not Store.new().current_blob(row.protectedCdKey):row.erase("protectedCdKey");discarded+=1
	if expect_prior and discarded==0 or not expect_prior and discarded!=0:fail("copied source credential format differs from expected version");return
	var controller:=Controller.new()
	if not controller.open(directory,"",0,func(_message: Dictionary):pass,func()->bool:return false,func(_status: Dictionary):pass):fail("copied profile controller could not open");return
	var result: Dictionary=controller.legacy_upgrade
	if result.has("error") or not result.get("imported",false) or int(result.get("discardedCredentials",-1))!=discarded or int(result.get("importedVersion",0))!=Store.CURRENT_VERSION:fail("one-time import failed: "+str(result.get("error","result shape mismatch")));return
	var backup:=str(result.get("backup",""))
	if not backup.is_absolute_path() or FileAccess.get_file_as_string(backup)!=original:fail("one-time import did not preserve exact source backup");return
	var saved:=FileAccess.get_file_as_string(file)
	var after: Variant=JSON.parse_string(saved)
	if not after is Dictionary:fail("imported settings could not be parsed");return
	var changed: Array[String]=[]
	compare_fields(expected,after,"settings",changed)
	if not changed.is_empty():fail("a non-secret settings field changed during import: "+", ".join(changed));return
	if bool(result.get("credentialReentryRequired",false))!=(discarded>0):fail("credential recovery notice differs");return
	if discarded>0 and not controller.store.cd_key().has("error"):fail("retired credential was unexpectedly retained");return
	controller.close()
	# Changing and then removing the former Chromium source must never trigger
	# another import or overwrite any version-3 preference or profile field.
	var local_state:=directory.path_join("Local State")
	var changed_source:="{\"obsolete\":true}"
	var writer:=FileAccess.open(local_state,FileAccess.WRITE)
	if writer==null:fail("could not change copied legacy source");return
	writer.store_string(changed_source);writer.close()
	if not reopen_current(directory,saved):return
	if DirAccess.remove_absolute(local_state)!=OK:fail("could not remove copied legacy source");return
	if not reopen_current(directory,saved):return
	var backup_count:=0
	for name in DirAccess.get_files_at(directory):
		if name.begins_with("client-settings.pre-nwn79-"):backup_count+=1
	if backup_count!=1:fail("later launch wrote another backup");return
	print("NWN79 copied existing-user settings import PASS: prior_v10=",expect_prior," profiles=",after.loginProfiles.size()," discarded_credentials=",discarded," exact_nonsecret_fields=true backup_verified=true later_launches_skip=true")
	quit(0)

func reopen_current(directory: String,saved: String)->bool:
	var controller:=Controller.new()
	if not controller.open(directory,"",0,func(_message: Dictionary):pass,func()->bool:return false,func(_status: Dictionary):pass):fail("version-3 profile could not reopen");return false
	if not bool(controller.legacy_upgrade.get("alreadyCurrent",false)) or FileAccess.get_file_as_string(directory.path_join("client-settings.json"))!=saved:fail("version-3 open repeated import");return false
	controller.close()
	return true

func compare_fields(expected: Variant,actual: Variant,path: String,changed: Array[String])->void:
	if expected is Dictionary and actual is Dictionary:
		for key in expected.keys():
			if not actual.has(key):changed.append(path+"."+str(key));continue
			compare_fields(expected[key],actual[key],path+"."+str(key),changed)
		for key in actual.keys():
			if not expected.has(key):changed.append(path+"."+str(key))
	elif expected is Array and actual is Array:
		if expected.size()!=actual.size():changed.append(path+".length");return
		for index in expected.size():compare_fields(expected[index],actual[index],path+"["+str(index)+"]",changed)
	elif expected!=actual:changed.append(path)

func fail(reason: String)->void:
	printerr("NWN79 copied existing-user settings import failed: "+reason)
	quit(1)
