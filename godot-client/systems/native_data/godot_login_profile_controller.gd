extends RefCounted
# Owns the existing login-profile UI protocol entirely inside Godot.
const Store=preload("res://systems/native_data/client_settings_store.gd")
var store
var send_result: Callable
var locked: Callable
var changed: Callable
var connection:=0
var view_id:=0
var visible:=false
var error: String=""
var legacy_upgrade: Dictionary={}

func open(directory: String,default_mods: String,owner_connection: int,send_callback: Callable,locked_callback: Callable,changed_callback: Callable,helper: String="")->bool:
	store=Store.new();send_result=send_callback;locked=locked_callback;changed=changed_callback;connection=owner_connection
	if not store.open(directory,default_mods,helper):error=store.error;return false
	# Import prior settings once, with an exact backup. Old Chromium credentials
	# are retired and can be replaced in this profile view or by a temporary key.
	legacy_upgrade=store.upgrade_legacy() if int(store.state.get("version",0))<Store.CURRENT_VERSION else {"alreadyCurrent":true,"imported":false,"discardedCredentials":0,"credentialReentryRequired":false}
	return true

func status()->Dictionary:
	return store.status() if store!=null else {}

func active_player_name()->String:
	if store==null:return ""
	var active: Dictionary=store.active_row(store.state)
	return str(active.get("playerName",""))

func publish(request_id: int,operation: String)->void:
	view_id+=1
	var current: Dictionary=store.status()
	send_result.call({"kind":"login-profiles-view","connection":connection,"requestId":request_id,"viewId":view_id,"operation":operation,"activeProfileId":current.activeProfileId,"profiles":current.loginProfiles,"hasLegacyCdKey":current.hasLegacyCdKey,"protectedStorageAvailable":current.protectedStorageAvailable,"locked":locked.call()})

func notice(request_id: int,message: String)->void:
	send_result.call({"kind":"login-profiles-notice","connection":connection,"requestId":request_id,"text":message})

func clear_submitted_key(message: Dictionary)->void:
	var values: Variant=message.get("values")
	if values is Dictionary and values.has("cdKey"):values.cdKey=""

func handle(message: Dictionary)->bool:
	if message.get("kind")!="login-profile-input":return false
	var request_id:=int(message.get("requestId",-1))
	var operation:=str(message.get("operation",""))
	if store==null or int(message.get("connection",-1))!=connection or request_id<1:clear_submitted_key(message);return true
	if operation=="close":visible=false;view_id+=1;clear_submitted_key(message);return true
	if operation=="open":visible=true;publish(request_id,"open");clear_submitted_key(message);return true
	if not visible or int(message.get("viewId",-1))!=view_id:notice(request_id,"This login-profile view is no longer current");clear_submitted_key(message);return true
	if locked.call():notice(request_id,"Disconnect before switching or changing login profiles");clear_submitted_key(message);return true
	var success:=false
	match operation:
		"save":
			var values: Variant=message.get("values")
			if values is Dictionary:
				success=store.save_profile(values)
			else:error="Invalid login profile"
		"select":success=store.select_profile(message.get("profileId"))
		"delete":success=store.delete_profile(message.get("profileId"))
		_:error="Unsupported login-profile operation"
	clear_submitted_key(message)
	if not success:
		notice(request_id,store.error if not store.error.is_empty() else error)
		return true
	# A recovery edit on an interrupted older settings file can finish its
	# one-time import. Current settings never revisit the old-format path.
	if int(store.state.get("version",0))<Store.CURRENT_VERSION:legacy_upgrade=store.upgrade_legacy()
	elif legacy_upgrade.get("credentialReentryRequired",false) and store.status().hasSavedCdKey:legacy_upgrade.credentialReentryRequired=false
	changed.call(store.status())
	publish(request_id,operation)
	if legacy_upgrade.has("error"):notice(request_id,str(legacy_upgrade.error))
	return true

func close()->void:
	visible=false
	if store!=null:store.close();store=null
