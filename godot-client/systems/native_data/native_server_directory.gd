extends Node
# Godot-owned Internet server list. The response schema and size cap follow
# the former browser owner; no Node, Electron or local proxy is involved.
signal completed(rows: Array[Dictionary],error: String)
const ENDPOINT:="https://api.nwn.beamdog.net/v1/servers"
const MAX_BYTES:=8*1024*1024
var client: HTTPRequest
var active:=false

static func js_string(value: Variant)->String:
	if value==null:return ""
	if value is Dictionary:return "[object Object]"
	if value is Array:
		var values:=PackedStringArray()
		for part in value:values.append(js_string(part))
		return ",".join(values)
	if value is float and is_finite(value) and value==floorf(value) and absf(value)<9223372036854775807.0:return str(int(value))
	return str(value)

static func js_length(value: String)->int:
	var units:=0
	for byte in value.to_utf8_buffer():
		if (int(byte) & 192)==128:continue
		units+=2 if int(byte)>=240 else 1
	return units

static func js_slice(value: String,limit: int)->String:
	var units:=0;var end:=0
	for index in value.length():
		var width:=js_length(value.substr(index,1))
		if units+width>limit:break
		units+=width;end=index+1
	return value.substr(0,end)

static func parse_rows(bytes: PackedByteArray)->Dictionary:
	if bytes.size()>MAX_BYTES:return {"error":"Internet server list exceeds the supported size"}
	var parsed: Variant=JSON.parse_string(bytes.get_string_from_utf8())
	if not parsed is Array or parsed.size()>10000:return {"error":"Invalid Internet server list"}
	var rows: Array[Dictionary]=[]
	for item in parsed:
		if item==null:return {"error":"Invalid Internet server list"}
		if not item is Dictionary or not item.get("host") is String or js_length(str(item.host))>255:continue
		var port_value: Variant=item.get("port")
		if not (port_value is int or port_value is float) or not is_finite(float(port_value)) or float(port_value)!=floorf(float(port_value)) or int(port_value)<1 or int(port_value)>65535:continue
		rows.append({"entryId":rows.size(),"host":str(item.host),"port":int(item.port),"serverName":js_slice(js_string(item.get("session_name")),256),"moduleName":js_slice(js_string(item.get("module_name")),256),"description":js_slice(js_string(item.get("module_description")),8192),"playerCount":item.get("current_players"),"maximumPlayers":item.get("max_players"),"minimumLevel":item.get("min_level"),"maximumLevel":item.get("max_level"),"pvpSetting":item.get("pvp"),"gameType":item.get("game_type"),"allowLocalVaultCharacters":not bool(item.get("servervault",false)),"passwordRequired":bool(item.get("passworded",false)),"latency":item.get("latency"),"allowed":true})
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
	if result==HTTPRequest.RESULT_BODY_SIZE_LIMIT_EXCEEDED:
		var empty: Array[Dictionary]=[]
		completed.emit(empty,"Internet server list exceeds the supported size")
		return
	if result!=HTTPRequest.RESULT_SUCCESS or response_code<200 or response_code>=300:
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
