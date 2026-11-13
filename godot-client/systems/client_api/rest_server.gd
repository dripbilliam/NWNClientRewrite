extends Node
# Minimal HTTP/1.1 GET transport. Every socket operation is partial/nonblocking.
const Routes=preload("res://systems/client_api/rest_routes.gd")
const Explorer=preload("res://systems/client_api/explorer_assets.gd")
const MAX_CLIENTS:=8
const MAX_ACCEPTS_PER_FRAME:=2
const MAX_REQUESTS_PER_FRAME:=2
const REQUESTS_PER_SECOND:=10.0
const REQUEST_BURST:=4.0
const MAX_READ_PER_FRAME:=16384
const MAX_WRITE_PER_FRAME:=32768
const READ_QUANTUM:=1024
const WRITE_QUANTUM:=4096
const MAX_HEADER_BYTES:=8192
const MAX_RESPONSE_BYTES:=524288
const FRAME_BUDGET_USEC:=1500
const REQUEST_TIMEOUT_MS:=3000
const WRITE_TIMEOUT_MS:=3000
const STATUS_NAMES:={200:"OK",400:"Bad Request",401:"Unauthorized",403:"Forbidden",404:"Not Found",405:"Method Not Allowed",408:"Request Timeout",410:"Gone",414:"URI Too Long",417:"Expectation Failed",422:"Unprocessable Content",429:"Too Many Requests",431:"Request Header Fields Too Large",503:"Service Unavailable",505:"HTTP Version Not Supported"}
var _listener:=TCPServer.new()
var _crypto:=Crypto.new()
var _routes: RefCounted
var _clients: Array=[]
var _token:=""
var _expected_auth:=PackedByteArray()
var _discovery_path:=""
var _port:=0
var _enabled:=false
var _error:=""
var _cursor:=0
var _tokens:=REQUEST_BURST
var _refilled_at:=0
var _stats:={"accepted":0,"requests":0,"asset_requests":0,"rate_limited":0,"rejected":0,"capacity_rejected":0,"peer_rejected":0,"poll_errors":0,"status_closes":0,"read_errors":0,"write_errors":0,"request_timeouts":0,"write_timeouts":0,"response_complete":0,"frames":0,"read_bytes":0,"written_bytes":0,"last_frame_read":0,"last_frame_written":0,"last_frame_requests":0}
func _init() -> void:
	set_process(false); process_mode=Node.PROCESS_MODE_ALWAYS
func start(entities: RefCounted,options: Dictionary) -> Dictionary:
	if _listener.is_listening(): return status()
	_enabled=true; _error=""
	var port: Variant=options.get("port",8765)
	if not (port is int or port is float) or not is_finite(float(port)) or float(port)!=floor(float(port)) or port<0 or port>65535:
		_error="invalid_rest_port"; return status()
	var path:=str(options.get("discovery_path",""))
	if path.is_empty() or (not path.begins_with("user://") and not path.is_absolute_path()):
		_error="invalid_rest_discovery_path"; return status()
	_discovery_path=ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(_discovery_path): _error="discovery_exists"; return status()
	var random:=_crypto.generate_random_bytes(32)
	if random.size()!=32: _error="random_unavailable"; return status()
	_token=random.hex_encode(); _expected_auth=("Bearer "+_token).to_utf8_buffer()
	var bound:=_listener.listen(int(port),"127.0.0.1")
	if bound!=OK:
		_error="bind_failed"; _token=""; _expected_auth=PackedByteArray(); return status()
	_port=_listener.get_local_port()
	_tokens=REQUEST_BURST; _refilled_at=Time.get_ticks_usec()
	_routes=Routes.new(entities)
	if not _write_discovery():
		_error="discovery_write_failed"; stop(); return status()
	set_process(true)
	return status()
func status() -> Dictionary:
	return {"enabled":_enabled,"listening":_listener.is_listening(),"address":"127.0.0.1","port":_port if _listener.is_listening() else null,"discovery_path":_discovery_path if not _discovery_path.is_empty() else null,"error":_error if not _error.is_empty() else null}
func diagnostics() -> Dictionary:
	var result: Dictionary=_stats.duplicate()
	result.clients=_clients.size(); result.listening=_listener.is_listening()
	return result
func _write_discovery() -> bool:
	if DirAccess.make_dir_recursive_absolute(_discovery_path.get_base_dir())!=OK: return false
	var temporary:=_discovery_path+".tmp-"+_crypto.generate_random_bytes(8).hex_encode()
	var file:=FileAccess.open(temporary,FileAccess.WRITE)
	if file==null: return false
	file.store_string(JSON.stringify({"kind":"nwn-client-entity-api-rest","api_version":1,"pid":OS.get_process_id(),"base_url":"http://127.0.0.1:"+str(_port)+"/api/v1","bearer_token":_token,"started_utc":Time.get_datetime_string_from_system(true)},"  ")+"\n")
	var error:=file.get_error(); file.close()
	if error!=OK or FileAccess.file_exists(_discovery_path) or DirAccess.rename_absolute(temporary,_discovery_path)!=OK:
		DirAccess.remove_absolute(temporary); return false
	return true
func _remove_discovery() -> void:
	if _discovery_path.is_empty() or _token.is_empty() or not FileAccess.file_exists(_discovery_path): return
	var file:=FileAccess.open(_discovery_path,FileAccess.READ)
	if file==null: return
	if file.get_length()>8192: file.close(); return
	var stored: Variant=JSON.parse_string(file.get_as_text()); file.close()
	if stored is Dictionary and stored.get("kind")=="nwn-client-entity-api-rest" and stored.get("pid")==OS.get_process_id() and stored.get("bearer_token")==_token:
		DirAccess.remove_absolute(_discovery_path)
func stop() -> void:
	set_process(false); _listener.stop()
	for client in _clients: client.peer.disconnect_from_host()
	_clients.clear(); _remove_discovery(); _token=""; _expected_auth=PackedByteArray(); _routes=null
func _exit_tree() -> void: stop()
func _process(_delta: float) -> void: poll_frame()
func poll_frame() -> void:
	if not _listener.is_listening(): return
	var began:=Time.get_ticks_usec()
	_tokens=minf(REQUEST_BURST,_tokens+maxi(0,began-_refilled_at)/1000000.0*REQUESTS_PER_SECOND); _refilled_at=began
	_stats.frames+=1; _stats.last_frame_read=0; _stats.last_frame_written=0; _stats.last_frame_requests=0
	for attempt in MAX_ACCEPTS_PER_FRAME:
		if not _listener.is_connection_available() or Time.get_ticks_usec()-began>=FRAME_BUDGET_USEC: break
		var peer:=_listener.take_connection()
		if peer==null: break
		if peer.get_connected_host()!="127.0.0.1" or _clients.size()>=MAX_CLIENTS:
			_stats["peer_rejected" if peer.get_connected_host()!="127.0.0.1" else "capacity_rejected"]+=1
			peer.disconnect_from_host(); _stats.rejected+=1; continue
		peer.set_no_delay(true)
		_clients.append({"peer":peer,"input":PackedByteArray(),"ready":false,"target":"","output":PackedByteArray(),"offset":0,"closed":false,"deadline":Time.get_ticks_msec()+REQUEST_TIMEOUT_MS})
		_stats.accepted+=1
	var count:=_clients.size()
	for visit in count:
		if Time.get_ticks_usec()-began>=FRAME_BUDGET_USEC: break
		var client: Dictionary=_clients[(_cursor+visit)%count]
		var peer: StreamPeerTCP=client.peer
		var poll_error:=peer.poll()
		if poll_error!=OK:
			_stats.poll_errors+=1; client.closed=true; continue
		if peer.get_status()!=StreamPeerTCP.STATUS_CONNECTED:
			_stats.status_closes+=1
			client.closed=true; continue
		if Time.get_ticks_msec()>int(client.deadline):
			if client.output.is_empty():
				_stats.request_timeouts+=1; _respond(client,Routes.error(408,"request_timeout"))
			else:
				_stats.write_timeouts+=1; client.closed=true
		if client.closed: continue
		if client.output.is_empty() and not client.ready and _stats.last_frame_read<MAX_READ_PER_FRAME:
			var available:=mini(peer.get_available_bytes(),mini(READ_QUANTUM,MAX_READ_PER_FRAME-int(_stats.last_frame_read)))
			if available>0:
				var packet:=peer.get_partial_data(available)
				if packet[0]!=OK and packet[0]!=ERR_BUSY:
					_stats.read_errors+=1; client.closed=true; continue
				var bytes: PackedByteArray=packet[1]
				_stats.last_frame_read+=bytes.size(); _stats.read_bytes+=bytes.size()
				_read(client,bytes)
		if client.ready and client.output.is_empty() and _stats.last_frame_requests<MAX_REQUESTS_PER_FRAME:
			_stats.last_frame_requests+=1
			# A public bootstrap cannot retry a missing script after429. Fixed
			# static bytes share all socket/frame caps, never the data-query quota.
			if Explorer.is_target(client.target):
				_stats.asset_requests+=1; _respond(client,Explorer.response(client.target))
			elif _tokens<1.0:
				_stats.rate_limited+=1; _respond(client,Routes.error(429,"rate_limited"))
			else:
				_tokens-=1.0; _stats.requests+=1; _respond(client,_routes.dispatch(client.target))
		if not client.output.is_empty() and _stats.last_frame_written<MAX_WRITE_PER_FRAME:
			var amount:=mini(WRITE_QUANTUM,MAX_WRITE_PER_FRAME-int(_stats.last_frame_written))
			var result:=peer.put_partial_data(client.output.slice(client.offset,mini(client.offset+amount,client.output.size())))
			if result[0]!=OK and result[0]!=ERR_BUSY:
				_stats.write_errors+=1; client.closed=true; continue
			client.offset+=int(result[1]); _stats.last_frame_written+=int(result[1]); _stats.written_bytes+=int(result[1])
			if client.offset>=client.output.size():
				_stats.response_complete+=1; client.closed=true
	_cursor=(_cursor+1)%maxi(1,count)
	var retained: Array=[]
	for client in _clients:
		if client.closed: client.peer.disconnect_from_host()
		else: retained.append(client)
	_clients=retained
func _read(client: Dictionary,bytes: PackedByteArray) -> void:
	for byte in bytes:
		if byte>126 or byte<32 and byte not in [9,10,13]: _respond(client,Routes.error(400,"invalid_header_bytes")); return
	client.input.append_array(bytes)
	if client.input.size()>MAX_HEADER_BYTES: _respond(client,Routes.error(431,"headers_too_large")); return
	var text: String=client.input.get_string_from_ascii()
	var end:=text.find("\r\n\r\n")
	if end<0: return
	if end+4!=text.length(): _respond(client,Routes.error(400,"request_body_not_allowed")); return
	var request:=_parse_headers(text.substr(0,end))
	if request.has("status"): _respond(client,request); return
	client.input=PackedByteArray(); client.target=request.target; client.ready=true
func _parse_headers(text: String) -> Dictionary:
	var lines:=text.split("\r\n",true)
	if lines.size()<2 or lines.size()>33: return Routes.error(400,"invalid_headers")
	var request:=lines[0].split(" ",true)
	if request.size()!=3 or request[0].is_empty() or request[1].is_empty(): return Routes.error(400,"invalid_request_line")
	if request[1].length()>2048: return Routes.error(414,"target_too_long")
	if request[2]!="HTTP/1.1": return Routes.error(505,"http_version_not_supported")
	var headers: Dictionary={}
	for line in lines.slice(1):
		var colon:=line.find(":")
		if colon<1: return Routes.error(400,"invalid_headers")
		var name:=line.substr(0,colon)
		for index in name.length():
			var character:=name.unicode_at(index)
			if not (character>=65 and character<=90 or character>=97 and character<=122 or character>=48 and character<=57 or character==45): return Routes.error(400,"invalid_headers")
		name=name.to_lower()
		if headers.has(name): return Routes.error(400,"duplicate_header")
		headers[name]=line.substr(colon+1).strip_edges()
	if headers.get("host","") not in ["127.0.0.1:"+str(_port),"localhost:"+str(_port)]: return Routes.error(403,"host_not_allowed")
	var explorer:=Explorer.is_target(request[1])
	var origin: String="http://"+str(headers.host)
	if headers.has("origin") and headers.origin!=origin: return Routes.error(403,"origin_not_allowed")
	var site: String=headers.get("sec-fetch-site","")
	var mode: String=headers.get("sec-fetch-mode","")
	var destination: String=headers.get("sec-fetch-dest","")
	var browser_metadata: bool=headers.has("sec-fetch-site") or headers.has("sec-fetch-mode") or headers.has("sec-fetch-dest") or headers.has("sec-fetch-user")
	if explorer:
		var document: bool=request[1] in ["/explorer","/explorer/"]
		if browser_metadata and (site not in (["same-origin","none"] if document else ["same-origin"])): return Routes.error(403,"browser_context_not_allowed")
		if browser_metadata and document and (mode!="navigate" or destination!="document"): return Routes.error(403,"browser_context_not_allowed")
		if not document:
			var wanted: String="script" if request[1].ends_with(".js") else ("style" if request[1].ends_with(".css") else "image")
			if browser_metadata and (mode not in ["cors","no-cors","same-origin"] or destination!=wanted or headers.has("sec-fetch-user")): return Routes.error(403,"browser_context_not_allowed")
	else:
		if browser_metadata and (site!="same-origin" or mode not in ["same-origin","cors"] or destination!="empty" or headers.has("sec-fetch-user")): return Routes.error(403,"browser_context_not_allowed")
		if not _crypto.constant_time_compare(_expected_auth,str(headers.get("authorization","")).to_utf8_buffer()): return Routes.error(401,"unauthorized")
	if request[0]!="GET": return Routes.error(405,"method_not_allowed")
	if headers.has("transfer-encoding") or headers.get("content-length","0")!="0": return Routes.error(400,"request_body_not_allowed")
	if headers.has("expect"): return Routes.error(417,"expectation_not_supported")
	return {"target":request[1]}
func _respond(client: Dictionary,response: Dictionary) -> void:
	var body: PackedByteArray=response.bytes if response.has("bytes") else JSON.stringify(response.body).to_utf8_buffer()
	if body.size()>MAX_RESPONSE_BYTES:
		response=Routes.error(422,"representation_limit"); body=JSON.stringify(response.body).to_utf8_buffer()
	var code:=int(response.status)
	var header:="HTTP/1.1 %d %s\r\nContent-Type: %s\r\nContent-Length: %d\r\nConnection: close\r\nCache-Control: no-store\r\nX-Content-Type-Options: nosniff\r\nCross-Origin-Resource-Policy: same-origin\r\nReferrer-Policy: no-referrer\r\nContent-Security-Policy: %s\r\n"%[code,STATUS_NAMES.get(code,"Error"),str(response.get("content_type","application/json; charset=utf-8")),body.size(),str(response.get("policy","default-src 'none'; frame-ancestors 'none'"))]
	if code==401: header+="WWW-Authenticate: Bearer\r\n"
	if code==405: header+="Allow: GET\r\n"
	if code==429: header+="Retry-After: 1\r\n"
	client.output=(header+"\r\n").to_utf8_buffer(); client.output.append_array(body); client.offset=0; client.ready=false
	client.deadline=Time.get_ticks_msec()+WRITE_TIMEOUT_MS
	if code>=400: _stats.rejected+=1
