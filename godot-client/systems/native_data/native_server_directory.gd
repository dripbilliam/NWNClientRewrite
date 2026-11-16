extends Node
# Godot-owned Internet server list. The response schema and size cap follow
# the former browser owner; no Node, Electron or local proxy is involved.
signal completed(rows: Array[Dictionary],error: String)
const ENDPOINT:="https://api.nwn.beamdog.net/v1/servers"
const MAX_BYTES:=8*1024*1024
var client: HTTPRequest
var active:=false

static func parse_rows(bytes: PackedByteArray)->Dictionary:
	if bytes.size()>MAX_BYTES:return {"error":"Internet server list exceeds the supported size"}
	var parsed: Variant=JSON.parse_string(bytes.get_string_from_utf8())
	if not parsed is Array or parsed.size()>10000:return {"error":"Invalid Internet server list"}
	var rows: Array[Dictionary]=[]
	for item in parsed:
		if not item is Dictionary or not item.get("host") is String or str(item.host).is_empty() or str(item.host).length()>255:continue
		var port_value: Variant=item.get("port")
		if not (port_value is int or port_value is float) or not is_finite(float(port_value)) or float(port_value)!=floorf(float(port_value)) or int(port_value)<1 or int(port_value)>65535:continue
		rows.append({"entryId":rows.size(),"host":str(item.host),"port":int(item.port),"serverName":str(item.get("session_name"," ")).left(256),"moduleName":str(item.get("module_name"," ")).left(256),"description":str(item.get("module_description","")).left(8192),"playerCount":item.get("current_players"),"maximumPlayers":item.get("max_players"),"minimumLevel":item.get("min_level"),"maximumLevel":item.get("max_level"),"pvpSetting":item.get("pvp"),"gameType":item.get("game_type"),"allowLocalVaultCharacters":not bool(item.get("servervault",true)),"passwordRequired":bool(item.get("passworded",false)),"latency":item.get("latency"),"allowed":true})
	return {"rows":rows}

func refresh()->void:
	if active:return
	if client==null:
		client=HTTPRequest.new();add_child(client)
		client.body_size_limit=MAX_BYTES;client.timeout=20.0;client.use_threads=true
		client.request_completed.connect(_on_completed)
	active=true
	var code:=client.request(ENDPOINT)
	if code!=OK:
		active=false
		var empty: Array[Dictionary]=[]
		completed.emit(empty,"Internet server list request could not start")

func _on_completed(result: int,response_code: int,_headers: PackedStringArray,body: PackedByteArray)->void:
	active=false
	if result!=HTTPRequest.RESULT_SUCCESS or response_code!=200:
		var empty: Array[Dictionary]=[]
		completed.emit(empty,"Internet server list request failed" if result!=HTTPRequest.RESULT_SUCCESS else "Internet server list returned HTTP "+str(response_code))
		return
	var parsed: Dictionary=parse_rows(body)
	if parsed.has("error"):
		var empty: Array[Dictionary]=[]
		completed.emit(empty,str(parsed.error))
	else:completed.emit(parsed.rows,"")

func close()->void:
	if client!=null:
		if active:client.cancel_request()
		client.queue_free();client=null
	active=false
