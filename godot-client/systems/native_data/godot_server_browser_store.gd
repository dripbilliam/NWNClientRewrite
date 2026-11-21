extends RefCounted
# Keeps the Godot client's own server-browser history and preferences.
const JsText=preload("res://systems/native_data/native_server_directory.gd")
var file: String=""
var state: Dictionary={}
var error: String=""

func open(path: String)->bool:
	if not path.is_absolute_path():error="Server browser storage path is invalid";return false
	file=path
	state={"version":1,"history":[],"favorites":[],"browserFilters":{"hideEmpty":false,"hideFull":false,"module":""},"profileDefault":"","last":{"host":"127.0.0.1","port":5121,"name":"GodotLocalTest"}}
	if FileAccess.file_exists(file):
		var parsed: Variant=JSON.parse_string(FileAccess.get_file_as_string(file))
		if not parsed is Dictionary or not (parsed.get("version") is int or parsed.get("version") is float) or parsed.get("version")!=1 or not parsed.get("history") is Array or not parsed.get("favorites") is Array:
			error="Saved server browser data is invalid";return false
		state.history=normalized_rows(parsed.history)
		state.favorites=normalized_rows(parsed.favorites)
		var last: Variant=parsed.get("last",state.last)
		if last==null:last=state.last
		if not last is Dictionary:error="Enter a server address and UDP port from 1 to 65535";return false
		var endpoint:=normalized_endpoint(last)
		if endpoint.is_empty():error=endpoint_error(last);return false
		var last_name: String=JsText.js_slice(str(last.name),64) if last.get("name") is String else ""
		last_name=last_name.strip_edges()
		state.last={"host":endpoint.host,"port":endpoint.port,"name":last_name if not last_name.is_empty() else "GodotLocalTest"}
		if parsed.has("browserFilters"):
			var filters:=validated_filters(parsed.browserFilters)
			if filters.is_empty():error="Invalid advanced server filters";return false
			state.browserFilters=filters
		state.profileDefault=JsText.js_slice(str(parsed.profileDefault),32) if parsed.get("profileDefault") is String else state.last.name
	return true

func endpoint_error(value: Variant)->String:
	const BAD_ADDRESS="Enter a server address and UDP port from 1 to 65535"
	const BAD_HOST="Enter an IPv4 address or hostname without a URL or port"
	if not value is Dictionary or not value.get("host") is String:return BAD_ADDRESS
	var port: Variant=value.get("port")
	if not (port is int or port is float) or not is_finite(float(port)) or float(port)!=floor(float(port)) or float(port)<1.0 or float(port)>65535.0:return BAD_ADDRESS
	var host:=str(value.host).strip_edges().to_lower().trim_suffix(".")
	if host=="localhost":host="127.0.0.1"
	if host.is_empty() or host.length()>253:return BAD_HOST
	if RegEx.create_from_string("^[a-z0-9][a-z0-9.-]*[a-z0-9]$").search(host)==null and RegEx.create_from_string("^[a-z0-9]$").search(host)==null:return BAD_HOST
	if RegEx.create_from_string("^[0-9.]+$").search(host)!=null and not host.is_valid_ip_address():return BAD_HOST
	for part in host.split("."):
		if part.is_empty() or part.length()>63 or part.begins_with("-") or part.ends_with("-"):return BAD_HOST
	return ""

func normalized_endpoint(value: Dictionary)->Dictionary:
	if not endpoint_error(value).is_empty():return {}
	var host:=str(value.host).strip_edges().to_lower().trim_suffix(".")
	if host=="localhost":host="127.0.0.1"
	return {"host":host,"port":int(value.port)}

func permits_endpoint(value: Dictionary,local_only: bool=false,selected_loopback_port: int=5121)->bool:
	var endpoint:=normalized_endpoint(value)
	if endpoint.is_empty():return false
	return not local_only or endpoint.host=="127.0.0.1" and endpoint.port in [5121,selected_loopback_port]

func normalized_row(value: Variant)->Dictionary:
	if not value is Dictionary:return {}
	var endpoint:=normalized_endpoint(value)
	if endpoint.is_empty():return {}
	var row: Dictionary={"host":endpoint.host,"port":endpoint.port,"serverName":JsText.js_slice(str(value.serverName),256) if value.get("serverName") is String else "","moduleName":JsText.js_slice(str(value.moduleName),256) if value.get("moduleName") is String else "","description":JsText.js_slice(str(value.description),65535) if value.get("description") is String else ""}
	for name in ["serverVersion"]:
		if value.get(name) is String:row[name]=JsText.js_slice(str(value[name]),256)
	for name in ["playerCount","maximumPlayers","minimumLevel","maximumLevel","pvpSetting","latency","gameType"]:
		var number: Variant=value.get(name)
		if not (number is int or number is float) or not is_finite(float(number)):continue
		if name!="latency" and float(number)!=floor(float(number)):continue
		if float(number)<(-1.0 if name=="gameType" else 0.0) or float(number)>(32767.0 if name=="gameType" else 65535.0):continue
		row[name]=number if name=="latency" else int(number)
	for name in ["passwordRequired","allowLocalVaultCharacters","pauseAndPlay","onePartyOnly","enforceLegalCharacters","itemLevelRestrictions","extendedReceived","syncAvailable"]:
		var flag: Variant=value.get(name)
		if flag is bool:row[name]=flag
		elif (flag is int or flag is float) and (flag==0 or flag==1):row[name]=flag==1
	if value.has("sync") or source_truthy(value.get("advertisement")):
		var sync_value: Variant=value.get("sync")
		if sync_value==null and value.get("advertisement") is Dictionary:sync_value=value.advertisement.get("hash")
		row.sync=source_truthy(sync_value)
	return row

func source_truthy(value: Variant)->bool:
	if value==null:return false
	if value is bool:return value
	if value is int or value is float:return not is_nan(float(value)) and float(value)!=0.0
	if value is String:return not value.is_empty()
	return true

func validated_filters(value: Variant)->Dictionary:
	if not value is Dictionary or value.size()!=3:return {}
	for key in value.keys():
		if key not in ["hideEmpty","hideFull","module"]:return {}
	if not value.get("hideEmpty") is bool or not value.get("hideFull") is bool or not value.get("module") is String:return {}
	var module: String=value.module
	if JsText.js_length(module)>1024:return {}
	for ch in module.to_utf8_buffer():
		if ch<32:return {}
	return {"hideEmpty":value.hideEmpty,"hideFull":value.hideFull,"module":module}

func filters(values: Variant)->bool:
	var validated:=validated_filters(values)
	if validated.is_empty():error="Invalid advanced server filters";return false
	var next: Dictionary=state.duplicate(true);next.browserFilters=validated
	return commit(next)

func normalized_rows(values: Array)->Array[Dictionary]:
	var rows: Array[Dictionary]=[];var seen: Dictionary={}
	for value in values:
		var row:=normalized_row(value)
		if row.is_empty():continue
		var key:=str(row.host)+":"+str(row.port)
		if seen.has(key):continue
		seen[key]=true;rows.append(row)
		if rows.size()>=100:break
	return rows

func rows(tab: String)->Array[Dictionary]:
	var result: Array[Dictionary]=[]
	var source: Array=state.get("history",[]) if tab=="History" else state.get("favorites",[]) if tab=="Favorites" else []
	for index in source.size():
		var row: Dictionary=source[index].duplicate(true)
		# Include presentation fields for a newly added endpoint-only row.
		if not row.has("serverName"):row.serverName=""
		if not row.has("moduleName"):row.moduleName=""
		row.entryId=index;row.allowed=true;result.append(row)
	return result

func favorite(row: Dictionary,on: bool)->bool:
	var normalized:=normalized_row(row)
	if normalized.is_empty():error=endpoint_error(row);return false
	var next: Dictionary=state.duplicate(true);var key:=str(normalized.host)+":"+str(normalized.port)
	var remaining: Array=[]
	for value in next.favorites:
		if str(value.host)+":"+str(value.port)!=key:remaining.append(value)
	if on:remaining.push_front(normalized)
	next.favorites=remaining.slice(0,100)
	return commit(next)

func remember(row: Dictionary,player_name: String)->bool:
	var normalized:=normalized_row(row)
	if normalized.is_empty():error=endpoint_error(row);return false
	var next: Dictionary=state.duplicate(true);var key:=str(normalized.host)+":"+str(normalized.port)
	var remaining: Array=[]
	for value in next.history:
		if str(value.host)+":"+str(value.port)!=key:remaining.append(value)
	remaining.push_front(normalized)
	next.history=remaining.slice(0,100)
	next.last={"host":normalized.host,"port":normalized.port,"name":JsText.js_slice(player_name,64)}
	return commit(next)

func valid_profile_name(player_name: String)->bool:
	if player_name.is_empty() or JsText.js_length(player_name)>32:error="Invalid default player name";return false
	for ch in player_name.to_utf8_buffer():
		if ch<32:error="Invalid default player name";return false
	return true

func profile(player_name: String)->bool:
	if not valid_profile_name(player_name):return false
	var next: Dictionary=state.duplicate(true);next.profileDefault=player_name
	return commit(next)

func commit(next: Dictionary)->bool:
	if DirAccess.make_dir_recursive_absolute(file.get_base_dir())!=OK:error="Server browser directory could not be created";return false
	var temp:=file+"."+Crypto.new().generate_random_bytes(8).hex_encode()+".tmp"
	var writer:=FileAccess.open(temp,FileAccess.WRITE)
	if writer==null:error="Server browser data could not be written";return false
	writer.store_string(JSON.stringify(next)+"\n");writer.flush();writer.close()
	if DirAccess.rename_absolute(temp,file)!=OK:
		DirAccess.remove_absolute(temp);error="Server browser data could not be committed";return false
	state=next;error="";return true
