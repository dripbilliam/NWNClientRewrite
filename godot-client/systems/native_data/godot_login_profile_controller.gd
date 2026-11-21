extends RefCounted
# Owns the existing login-profile UI protocol entirely inside Godot.
const Store=preload("res://systems/native_data/client_settings_store.gd")
const MAX_SAFE_ID:=9007199254740991
var store
var send_result: Callable
var locked: Callable
var changed: Callable
var connection:=0
var view_id:=0
var view_connection:=-1
var visible:=false
var error: String=""

func open(directory: String,default_mods: String,owner_connection: int,send_callback: Callable,locked_callback: Callable,changed_callback: Callable,helper: String="")->bool:
	store=Store.new();send_result=send_callback;locked=locked_callback;changed=changed_callback;connection=owner_connection
	if not store.open(directory,default_mods,helper):error=store.error;return false
	return true

func status()->Dictionary:
	return store.status() if store!=null else {}

func active_player_name()->String:
	if store==null:return ""
	var active: Dictionary=store.active_row(store.state)
	return str(active.get("playerName",""))

func publish(request_id: int,current: Dictionary,operation: String)->void:
	view_id+=1
	view_connection=connection
	send_result.call({"kind":"login-profiles-view","connection":connection,"requestId":request_id,"viewId":view_id,"operation":operation,"activeProfileId":current.activeProfileId,"profiles":current.loginProfiles,"hasLegacyCdKey":current.hasLegacyCdKey,"protectedStorageAvailable":current.protectedStorageAvailable,"locked":locked.call()})

func notice(request_id: int,message: String)->void:
	send_result.call({"kind":"login-profiles-notice","connection":connection,"requestId":request_id,"text":message})

func clear_submitted_key(message: Dictionary)->void:
	var values: Variant=message.get("values")
	if values is Dictionary and values.get("cdKey") is String:values.cdKey=""

static func valid_serial(value: Variant)->bool:
	if value is int:return value>=0 and value<=MAX_SAFE_ID
	return value is float and is_finite(value) and value==floorf(value) and value>=0 and value<=MAX_SAFE_ID

func command_error(message: Dictionary,operation: Variant)->String:
	if not valid_serial(message.get("requestId")) or operation not in ["open","close","save","select","delete"]:
		return "Invalid native login-profile operation"
	if operation not in ["open","close"] and not valid_serial(message.get("viewId")):
		return "Invalid native login-profile view"
	if operation=="save":
		var values: Variant=message.get("values")
		if not values is Dictionary or values.keys().any(func(key):return key not in ["id","label","playerName","cdKey"]):
			return "Invalid native login-profile values"
		if values.has("id") and not store.valid_id(values.id) or not store.valid_label(values.get("label")) or not store.valid_label(values.get("playerName")):
			return "Invalid native login-profile values"
		if values.has("cdKey") and (not values.cdKey is String or store.js_length(values.cdKey)>41):
			return "Invalid native login-profile values"
	if operation in ["select","delete"]:
		var id: Variant=message.get("profileId")
		var manual: bool=operation=="select" and message.has("profileId") and id==null
		if not manual and not store.valid_id(id):return "Invalid native login-profile selection"
	return ""

func handle(message: Dictionary)->bool:
	if message.get("kind")!="login-profile-input":return false
	var incoming_connection: Variant=message.get("connection")
	if store==null or not valid_serial(incoming_connection) or int(incoming_connection)!=connection:clear_submitted_key(message);return true
	var operation: Variant=message.get("operation")
	var raw_request_id: Variant=message.get("requestId")
	var request_id:=int(raw_request_id) if valid_serial(raw_request_id) else -1
	var invalid:=command_error(message,operation)
	if not invalid.is_empty():clear_submitted_key(message);notice(request_id,invalid);return true
	if operation=="close":visible=false;view_connection=-1;clear_submitted_key(message);return true
	if operation=="open":visible=true;clear_submitted_key(message);publish(request_id,store.status(),"open");return true
	if not visible or view_connection!=connection or int(message.viewId)!=view_id:clear_submitted_key(message);notice(request_id,"This login-profile view is no longer current");return true
	if locked.call():clear_submitted_key(message);notice(request_id,"Disconnect before switching or changing login profiles");return true
	var owner=store
	var owner_connection:=connection
	var owner_view:=view_id
	var success:=false
	match operation:
		"save":success=owner.save_profile(message.values)
		"select":success=owner.select_profile(message.profileId)
		"delete":success=owner.delete_profile(message.profileId)
	clear_submitted_key(message)
	if not success:
		notice(request_id,owner.error)
		return true
	var current: Dictionary=owner.status()
	changed.call(current)
	if store==owner and visible and connection==owner_connection and view_id==owner_view:publish(request_id,current,operation)
	return true

func close()->void:
	visible=false
	view_connection=-1
	if store!=null:store.close();store=null
