extends SceneTree
const Store=preload("res://systems/native_data/client_settings_store.gd")
func _initialize()->void:
	var appdata:=OS.get_environment("APPDATA")
	var directory:=appdata.path_join("nwn-model-viewer-research")
	var settings=Store.new()
	if not settings.open(directory):printerr("NWN79 existing profile open failed: ",settings.error);quit(1);return
	var status: Dictionary=settings.status()
	var key: Dictionary=settings.cd_key()
	var valid:=not key.has("error") and RegEx.create_from_string("^[A-Z0-9]{5}(-[A-Z0-9]{5}){6}$").search(str(key.get("cdKey","")))!=null
	settings.close()
	print(JSON.stringify({"readOnly":true,"profiles":status.loginProfiles.size(),"activeKeyReadable":valid}))
	quit(0 if valid else 1)
