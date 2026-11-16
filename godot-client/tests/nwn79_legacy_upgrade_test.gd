extends SceneTree
const Store=preload("res://systems/native_data/client_settings_store.gd")

func _initialize()->void:
	var directory: String=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--directory="):directory=arg.trim_prefix("--directory=")
	if not directory.is_absolute_path():fail("synthetic directory unavailable");return
	var file:=directory.path_join("client-settings.json")
	var opened:=Store.new()
	if not opened.open(directory):fail("synthetic settings could not open");return
	var changed: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(file))
	changed.serverPreferences.lastServer="New server after first open"
	var modified:=JSON.stringify(changed)+"\n"
	var writer:=FileAccess.open(file,FileAccess.WRITE)
	if writer==null:fail("could not simulate interrupted import");return
	writer.store_string(modified);writer.close()
	if not opened.upgrade_legacy().has("error") or FileAccess.get_file_as_string(file)!=modified:fail("stale importer changed source settings");return
	for name in DirAccess.get_files_at(directory):
		if name.begins_with("client-settings.pre-nwn79-"):fail("failed import created a backup");return
	opened.close()
	var store:=Store.new()
	if not store.open(directory):fail("recovery could not reopen changed settings");return
	var result: Dictionary=store.upgrade_legacy()
	if result.has("error") or not result.get("imported",false) or int(result.get("discardedCredentials",-1))!=3 or not result.get("credentialReentryRequired",false):fail("recovery did not complete one-time import");return
	var backup:=str(result.get("backup",""))
	if not backup.is_absolute_path() or FileAccess.get_file_as_string(backup)!=modified:fail("exact pre-import backup differs");return
	var expected: Dictionary=changed.duplicate(true)
	expected.version=Store.CURRENT_VERSION
	expected.erase("protectedCdKey")
	for row in expected.loginProfiles:row.erase("protectedCdKey")
	var after: Variant=JSON.parse_string(FileAccess.get_file_as_string(file))
	if not after is Dictionary:fail("imported settings could not be parsed");return
	var differences: Array[String]=[]
	compare_fields(expected,after,"settings",differences)
	if not differences.is_empty():fail("non-secret settings changed: "+", ".join(differences));return
	if not store.cd_key().has("error"):fail("retired credential is unexpectedly usable");return
	if not bool(store.upgrade_legacy().get("alreadyCurrent",false)):fail("import marker did not prevent repeated import");return
	store.close()
	print("NWN79 one-time settings import PASS: interrupted_source_preserved=true recovered=true backup_verified=true fields_preserved=true discarded_credentials=3")
	quit(0)

func compare_fields(expected: Variant,actual: Variant,path: String,differences: Array[String])->void:
	if expected is Dictionary and actual is Dictionary:
		for key in expected.keys():
			if not actual.has(key):differences.append(path+"."+str(key));continue
			compare_fields(expected[key],actual[key],path+"."+str(key),differences)
		for key in actual.keys():
			if not expected.has(key):differences.append(path+"."+str(key))
	elif expected is Array and actual is Array:
		if expected.size()!=actual.size():differences.append(path+".length");return
		for index in expected.size():compare_fields(expected[index],actual[index],path+"["+str(index)+"]",differences)
	elif expected!=actual:differences.append(path)

func fail(reason: String)->void:
	printerr("NWN79 one-time settings import failed: "+reason)
	quit(1)
