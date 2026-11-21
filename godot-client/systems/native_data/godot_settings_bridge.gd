extends RefCounted
const Store=preload("res://systems/native_data/client_settings_store.gd")
const Workshop=preload("res://systems/native_data/workshop_index.gd")
var store
var owns_store:=false
var send_result: Callable
var client_setup_view:=0

func open(directory: String,default_mods: String,send_callback: Callable)->bool:
	store=Store.new();owns_store=true;send_result=send_callback
	return store.open(directory,default_mods)

func attach(existing_store,send_callback: Callable)->void:
	# Direct sessions already own the settings file through their login profile
	# controller. Share that owner so a folder selection cannot stale its writes.
	store=existing_store;send_result=send_callback
	owns_store=false

func status()->Dictionary:return store.status() if store!=null else {}

func handle(message: Dictionary)->bool:
	if message.get("kind")!="protected-settings-request":return false
	var id: Variant=message.get("id")
	var operation:=str(message.get("operation",""))
	if not (id is int or id is float) or not is_finite(float(id)) or id<1 or float(id)>9007199254740991.0 or float(id)!=floor(float(id)) or operation not in ["status","update","saveProfile","selectProfile","deleteProfile","cdKey"]:return true
	id=int(id)
	var value: Variant=message.get("value")
	var result: Variant=null
	var error: String=""
	match operation:
		"status":result=store.status()
		"update":
			if not value is Dictionary:error="Invalid client settings"
			elif store.update(value):result=store.status()
			else:error=store.error
		"saveProfile":
			if not value is Dictionary:error="Invalid login profile"
			elif store.save_profile(value):result=store.status()
			else:error=store.error
		"selectProfile":
			if store.select_profile(value):result=store.status()
			else:error=store.error
		"deleteProfile":
			if store.delete_profile(value):result=store.status()
			else:error=store.error
		"cdKey":
			var key: Dictionary=store.cd_key()
			if key.has("error"):error=str(key.error)
			else:result=str(key.cdKey)
	if value is Dictionary and value.has("cdKey"):value.cdKey=""
	send_result.call({"kind":"protected-settings-result","id":id,"ok":error.is_empty(),"value":result,"error":error})
	return true

func close()->void:
	if store!=null and owns_store:store.close()
	store=null;owns_store=false
func client_setup_notice(request_id: int,reason: String)->Array:
	return [{"kind":"settings-notice","requestId":request_id,"text":reason}]

func client_setup_label(directory: String)->String:
	var hak:=DirAccess.open(directory.path_join("hak"))
	if hak!=null:
		for name in hak.get_files():
			if str(name).to_lower().ends_with(".hak"):return str(name).get_basename()
	var portraits:=DirAccess.open(directory.path_join("portraits"))
	if portraits!=null and not portraits.get_files().is_empty():return "Portraits"
	return "Workshop mod"

func client_setup(message: Dictionary,resources_locked: bool,install_locked: bool=false)->Array:
	var request_id:=int(message.get("requestId",-1))
	if request_id<0:return []
	var operation:=str(message.get("operation",""))
	if operation=="close":client_setup_view+=1;return []
	if store==null:return client_setup_notice(request_id,"Saved settings are unavailable.")
	var status_value: Dictionary=store.status()
	var directory:=str(status_value.get("modsDirectory",""))
	var saved:=false
	match operation:
		"open":pass
		"choose-install":
			if install_locked:return client_setup_notice(request_id,"Disconnect before choosing an installation")
			var selected: Variant=message.get("directory")
			if not selected is String or selected.is_empty() or selected.length()>4096 or selected.to_utf8_buffer().has(0) or not selected.is_absolute_path() or not DirAccess.dir_exists_absolute(selected):return client_setup_notice(request_id,"Select an installation folder.")
			var absolute: String=selected.simplify_path()
			if not store.update({"installDirectory":absolute}):return client_setup_notice(request_id,store.error)
			return [{"kind":"settings-install-selected","requestId":request_id,"directory":absolute}]
		"scan":
			if resources_locked:return client_setup_notice(request_id,"Disconnect before changing mods.")
			var choice: Variant=message.get("directory")
			if not choice is String or choice.length()>4096 or choice.to_utf8_buffer().has(0) or not choice.is_empty() and not choice.is_absolute_path():return client_setup_notice(request_id,"Select a valid Workshop folder.")
			directory=choice.simplify_path() if not choice.is_empty() else ""
		"save":
			if int(message.get("viewId",-1))!=client_setup_view:return client_setup_notice(request_id,"Settings changed; reload before saving.")
			var values: Variant=message.get("values")
			if not values is Dictionary:return client_setup_notice(request_id,"Invalid client settings.")
			if resources_locked and (values.has("modsDirectory") or values.has("disabledMods")):return client_setup_notice(request_id,"Disconnect before changing mods.")
			var update: Dictionary=values.duplicate(true)
			var accepted: bool=store.update(update)
			if update.has("cdKey"):update.cdKey=""
			if values.has("cdKey"):values.cdKey=""
			if not accepted:return client_setup_notice(request_id,store.error)
			status_value=store.status();directory=str(status_value.get("modsDirectory",""));saved=true
		_:return client_setup_notice(request_id,"Unsupported settings request.")
	var workshop:=Workshop.new()
	var roots: Array=workshop.scan(directory,[])
	if not workshop.failure.is_empty():return client_setup_notice(request_id,workshop.failure)
	var disabled: Array=status_value.get("disabledMods",[]) if directory==str(status_value.get("modsDirectory","")) else []
	var rows: Array=[]
	for root in roots:
		var id:=str(root.get("id",""))
		rows.append({"id":id,"directory":str(root.get("directory","")),"label":client_setup_label(str(root.get("directory",""))),"enabled":not disabled.has(id)})
	status_value=status_value.duplicate(true)
	status_value.resourcesLocked=resources_locked
	status_value.installLocked=install_locked
	status_value.modsDirectory=directory
	client_setup_view+=1
	var result: Array=[{"kind":"settings-begin","requestId":request_id,"viewId":client_setup_view,"status":status_value,"count":rows.size()},{"kind":"settings-mods","requestId":request_id,"viewId":client_setup_view,"rows":rows},{"kind":"settings-commit","requestId":request_id,"viewId":client_setup_view}]
	if saved:result.append({"kind":"settings-notice","requestId":request_id,"text":"Settings saved."})
	return result
