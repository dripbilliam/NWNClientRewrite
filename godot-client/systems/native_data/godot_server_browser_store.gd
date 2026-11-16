extends RefCounted
# Reads the former host's native-server-browser.json without Node or Electron.
var file: String=""
var state: Dictionary={}
var error: String=""

func open(path: String)->bool:
	if not path.is_absolute_path():error="Server browser storage path is invalid";return false
	file=path
	state={"version":1,"history":[],"favorites":[],"browserFilters":{"hideEmpty":false,"hideFull":false,"module":""},"profileDefault":"","last":{"host":"127.0.0.1","port":5121,"name":"GodotLocalTest"}}
	if not FileAccess.file_exists(file):return true
	var parsed: Variant=JSON.parse_string(FileAccess.get_file_as_string(file))
	if not parsed is Dictionary or int(parsed.get("version",0))!=1 or not parsed.get("history") is Array or not parsed.get("favorites") is Array:
		error="Saved server browser data is invalid";return false
	state.history=normalized_rows(parsed.history)
	state.favorites=normalized_rows(parsed.favorites)
	var last: Variant=parsed.get("last",{})
	if last is Dictionary:
		var endpoint:=normalized_endpoint(last)
		if not endpoint.is_empty():state.last={"host":endpoint.host,"port":endpoint.port,"name":str(last.get("name","GodotLocalTest")).left(64)}
	var filters: Variant=parsed.get("browserFilters")
	if filters is Dictionary and filters.get("hideEmpty") is bool and filters.get("hideFull") is bool and filters.get("module") is String:
		state.browserFilters={"hideEmpty":filters.hideEmpty,"hideFull":filters.hideFull,"module":str(filters.module).left(1024)}
	state.profileDefault=str(parsed.get("profileDefault",state.last.name)).left(32)
	return true

func normalized_endpoint(value: Dictionary)->Dictionary:
	var host:=str(value.get("host","")).strip_edges().to_lower().trim_suffix(".")
	if host=="localhost":host="127.0.0.1"
	var port: Variant=value.get("port",0)
	if host.is_empty() or host.length()>253 or not port is int and not port is float or int(port)<1 or int(port)>65535 or float(port)!=float(int(port)):return {}
	if RegEx.create_from_string("^[a-z0-9][a-z0-9.-]*[a-z0-9]$").search(host)==null and RegEx.create_from_string("^[a-z0-9]$").search(host)==null:return {}
	if RegEx.create_from_string("^[0-9.]+$").search(host)!=null and not host.is_valid_ip_address():return {}
	for part in host.split("."):
		if part.is_empty() or part.length()>63 or part.begins_with("-") or part.ends_with("-"):return {}
	return {"host":host,"port":int(port)}

func normalized_row(value: Variant)->Dictionary:
	if not value is Dictionary:return {}
	var endpoint:=normalized_endpoint(value)
	if endpoint.is_empty():return {}
	var row: Dictionary={"host":endpoint.host,"port":endpoint.port,"serverName":str(value.get("serverName","")).left(256),"moduleName":str(value.get("moduleName","")).left(256),"description":str(value.get("description","")).left(65535)}
	for name in ["serverVersion"]:
		if value.get(name) is String:row[name]=str(value[name]).left(256)
	for name in ["playerCount","maximumPlayers","minimumLevel","maximumLevel","pvpSetting","latency","gameType"]:
		var number: Variant=value.get(name)
		if (number is int or number is float) and float(number)==float(int(number)) and int(number)>=(-1 if name=="gameType" else 0) and int(number)<=(32767 if name=="gameType" else 65535):row[name]=int(number)
	for name in ["passwordRequired","allowLocalVaultCharacters","pauseAndPlay","onePartyOnly","enforceLegalCharacters","itemLevelRestrictions","extendedReceived","syncAvailable","sync"]:
		if value.get(name) is bool:row[name]=value[name]
	return row

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
		var row: Dictionary=source[index].duplicate(true);row.entryId=index;row.allowed=true;result.append(row)
	return result

func favorite(row: Dictionary,on: bool)->bool:
	var normalized:=normalized_row(row)
	if normalized.is_empty():error="Invalid favorite server";return false
	var next: Dictionary=state.duplicate(true);var key:=str(normalized.host)+":"+str(normalized.port)
	var remaining: Array=[]
	for value in next.favorites:
		if str(value.host)+":"+str(value.port)!=key:remaining.append(value)
	if on:remaining.push_front(normalized)
	next.favorites=remaining.slice(0,100)
	return commit(next)

func remember(row: Dictionary,player_name: String)->bool:
	var normalized:=normalized_row(row)
	if normalized.is_empty():error="Invalid recent server";return false
	var next: Dictionary=state.duplicate(true);var key:=str(normalized.host)+":"+str(normalized.port)
	var remaining: Array=[]
	for value in next.history:
		if str(value.host)+":"+str(value.port)!=key:remaining.append(value)
	remaining.push_front(normalized)
	next.history=remaining.slice(0,100)
	next.last={"host":normalized.host,"port":normalized.port,"name":player_name.left(64)}
	return commit(next)

func valid_profile_name(player_name: String)->bool:
	if player_name.is_empty() or player_name.length()>32 or player_name.strip_edges().is_empty():error="Invalid default player name";return false
	for ch in player_name.to_utf8_buffer():
		if ch<32 or ch==127:error="Invalid default player name";return false
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
