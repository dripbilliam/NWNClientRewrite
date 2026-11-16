extends RefCounted
const Store=preload("res://systems/native_data/client_settings_store.gd")
var store
var send_result: Callable

func open(directory: String,default_mods: String,send_callback: Callable)->bool:
	store=Store.new();send_result=send_callback
	return store.open(directory,default_mods)

func status()->Dictionary:return store.status() if store!=null else {}

func handle(message: Dictionary)->bool:
	if message.get("kind")!="protected-settings-request":return false
	var id: Variant=message.get("id")
	var operation:=str(message.get("operation",""))
	if not (id is int or id is float) or not is_finite(float(id)) or id<1 or float(id)!=floor(float(id)) or operation not in ["status","update","saveProfile","selectProfile","deleteProfile","cdKey"]:return true
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
	if store!=null:store.close();store=null
