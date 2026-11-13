extends SceneTree
const API=preload("res://systems/client_api/client_api.gd")
const Server=preload("res://systems/client_api/rest_server.gd")
const Options=preload("res://systems/client_api/rest_options.gd")
const WireJson=preload("res://systems/client_api/rest_json.gd")
var checks:=0
var failures: Array=[]
var objects: Dictionary={}
var motion: Dictionary={}
var lookups:=0
var api: Node
var provider: RefCounted
var binding: RefCounted
var port:=0
var credential:="" # Never printed, placed in a command line, or written to receipts.
var discovery_path:=""
var test_directory:=""
var max_frame_read:=0
var max_frame_write:=0
var max_frame_requests:=0
var transport_failures: Array=[]
var report_path:=""
var request_path:=""
var request_number:=0
var transport_failure_probe:=false
func _initialize() -> void: call_deferred("run")
func check(value: bool,label: String) -> bool:
	checks+=1
	if not value: failures.append(label); push_error(label)
	return value
func row(id: int,kind: int=5,area: int=7,life: int=1) -> Dictionary:
	return {"id":id,"objectType":kind,"areaId":area,"nativeLifetime":life,"replicated":{"name":{"text":"Actor "+str(id)},"position":[1,2,3],"stats":{"armorClass":null}},"appearance":{"parts":[{"id":3}]}}
func publish(rows: Array,removed: Array=[],full: bool=false,connection: int=1,generation: int=1,area: int=7,controlled: Variant=1,player: Dictionary={}) -> bool:
	if full: objects.clear()
	for id in removed: objects.erase(int(id))
	for item in rows: objects[int(item.id)]=item
	return binding.commit(connection,generation,area,{"bridgeMode":"full" if full else "delta","objects":rows,"removedObjectIds":removed,"controlledId":controlled},player)
func request(target: String,extra: String="",auth: String="valid",method: String="GET",host: String="") -> Dictionary:
	request_path=target.get_slice("?",0).left(256); request_number+=1
	var authorization:="Authorization: Bearer "+(credential if auth=="valid" else "invalid")+"\r\n" if auth!="none" else ""
	var header:="%s %s HTTP/1.1\r\nHost: %s\r\n%s%s\r\n"%[method,target,"127.0.0.1:"+str(port) if host.is_empty() else host,authorization,extra]
	var response: Dictionary={}
	for attempt in 12:
		response=await exchange(header.to_utf8_buffer())
		if response.status!=429: return response
		await create_timer(0.12).timeout
	return response
func observe_work() -> void:
	var server: Node=api.get_node_or_null("EntityRest") if is_instance_valid(api) else null
	if server==null: return
	var data: Dictionary=server.diagnostics()
	max_frame_read=maxi(max_frame_read,int(data.last_frame_read)); max_frame_write=maxi(max_frame_write,int(data.last_frame_written)); max_frame_requests=maxi(max_frame_requests,int(data.last_frame_requests))
func connect_client() -> StreamPeerTCP:
	var peer:=StreamPeerTCP.new()
	var began:=Time.get_ticks_msec()
	var code:=peer.connect_to_host("127.0.0.1",port)
	var before:=peer.get_status(); var poll_code:=OK; var polls:=0; var reason:=""
	if code!=OK: reason="connect_error"
	var deadline:=Time.get_ticks_msec()+1500
	while reason.is_empty():
		poll_code=peer.poll(); polls+=1; observe_work()
		var current:=peer.get_status()
		if current==StreamPeerTCP.STATUS_CONNECTED: return peer
		if current==StreamPeerTCP.STATUS_NONE: reason="NONE"; break
		if current==StreamPeerTCP.STATUS_ERROR: reason="ERROR"; break
		if Time.get_ticks_msec()>=deadline: reason="TIMEOUT"; break
		await process_frame
	var context:={"reason":reason,"connect_result":code,"status_before_poll":before,"status_after_poll":peer.get_status(),"poll_result":poll_code,"polls":polls,"elapsed_ms":Time.get_ticks_msec()-began,"listener":api.rest_status().listening}
	var server: Node=api.get_node_or_null("EntityRest")
	if server!=null: context.server=server.diagnostics()
	if transport_failures.size()<8: transport_failures.append(context)
	return peer
func exchange(bytes: PackedByteArray,fragment: int=0) -> Dictionary:
	var peer: StreamPeerTCP=await connect_client()
	if peer.get_status()!=StreamPeerTCP.STATUS_CONNECTED:
		await abort_transport("connect",peer,{})
		return {}
	var offset:=0; var deadline:=Time.get_ticks_msec()+5500
	if fragment>0:
		var sent:=peer.put_partial_data(bytes.slice(0,fragment)); offset=int(sent[1])
		for frame in 3: await process_frame
	while offset<bytes.size() and Time.get_ticks_msec()<deadline:
		peer.poll(); observe_work()
		var sent:=peer.put_partial_data(bytes.slice(offset,mini(offset+4096,bytes.size())))
		if sent[0]!=OK and sent[0]!=ERR_BUSY: break
		offset+=int(sent[1]); await process_frame
	var response:=PackedByteArray()
	while Time.get_ticks_msec()<deadline:
		peer.poll(); observe_work()
		var available:=peer.get_available_bytes()
		if available>0:
			var packet:=peer.get_partial_data(mini(available,8192))
			response.append_array(packet[1])
		var end:=-1
		for index in maxi(0,response.size()-3):
			if response[index]==13 and response[index+1]==10 and response[index+2]==13 and response[index+3]==10: end=index; break
		if end>=0:
			var lines:=response.slice(0,end).get_string_from_ascii().split("\r\n"); var headers: Dictionary={}
			for line in lines.slice(1):
				var colon:=line.find(":")
				if colon>0: headers[line.substr(0,colon).to_lower()]=line.substr(colon+1).strip_edges()
			if response.size()>=end+4+int(headers.get("content-length",0)):
				var payload:=response.slice(end+4).get_string_from_utf8()
				var body: Variant=JSON.parse_string(payload) if str(headers.get("content-type","")).begins_with("application/json") else null
				peer.disconnect_from_host()
				return {"status":int(lines[0].split(" ")[1]),"headers":headers,"body":body if body is Dictionary else {},"text":payload}
		if peer.get_status()!=StreamPeerTCP.STATUS_CONNECTED and available==0: break
		await process_frame
	peer.disconnect_from_host()
	await abort_transport("response",peer,{"sent_bytes":offset,"response_bytes":response.size()})
	return {}
func abort_transport(stage: String,peer: StreamPeerTCP,details: Dictionary) -> void:
	var context:={"stage":stage,"request_path":request_path,"request_number":request_number,"completed_checks":checks,"peer_status":peer.get_status(),"listener":api.rest_status().listening}
	context.merge(details)
	var server: Node=api.get_node_or_null("EntityRest")
	if server!=null: context.server=server.diagnostics()
	if transport_failures.size()<8: transport_failures.append(context)
	peer.disconnect_from_host()
	check(false,"HTTP transport failed at "+stage+" for request "+str(request_number))
	await finish(report_path)
	# finish() has requested engine exit. Keep the caller suspended so an absent
	# HTTP body cannot cause a second error before the main loop processes quit.
	await process_frame
func load_discovery() -> void:
	var status: Dictionary=api.rest_status(); discovery_path=status.get("discovery_path","")
	var document: Variant=JSON.parse_string(FileAccess.get_file_as_string(discovery_path)) if not discovery_path.is_empty() else null
	if document is Dictionary:
		credential=str(document.get("bearer_token","")); port=int(status.get("port",0))
func run() -> void:
	var output:=""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="): output=argument.trim_prefix("--report=")
		if argument=="--test-fail-transport=true": transport_failure_probe=true
	report_path=output
	test_directory=output.get_base_dir()
	check(not Options.parse([]).enabled,"REST defaults off without opening sockets")
	check(Options.parse(["--entity-api-rest=true","--entity-api-rest-port=0"]).enabled,"Explicit CLI opt-in and ephemeral port parse")
	check(Options.parse([],{"NWN_ENTITY_API_REST":"true","NWN_ENTITY_API_REST_PORT":"9876"}).port==9876,"Normal-launch environment opt-in is supported without launcher changes")
	check(not Options.parse(["--entity-api-rest=false"],{"NWN_ENTITY_API_REST":"true"}).enabled,"Explicit CLI option overrides inherited environment")
	for bad in [["--entity-api-rest=yes"],["--entity-api-rest=true","--entity-api-rest=false"],["--entity-api-rest-port=-1"],["--entity-api-rest-port=65536"],["--entity-api-rest-port=1.5"],["--entity-api-rest-discovery=relative.json"],["--entity-api-rest-unknown=true"]]:
		check(Options.parse(bad).has("error"),"Invalid launch option is nonfatal and rejected")
	api=API.install(root); provider=api.entities
	if not check(api.rest_status().listening,"Actual ClientAPI ready hook starts the opt-in listener"): await finish(output); return
	load_discovery()
	check(credential.length()==64 and port>0,"Discovery supplies a generated per-launch token and selected loopback port")
	check(not JSON.stringify(api.rest_status()).contains(credential),"Public status never exposes the bearer token")
	if transport_failure_probe:
		# An authored refused connection verifies failure classification/receipt
		# and prevents regressions to missing-body errors or the outer timeout.
		api.stop_rest()
		await request("/api/v1/scope")
		return
	binding=api.bind_native(func(id):lookups+=1; return objects.get(id),func(id):return motion.get(id))
	var response: Dictionary=await request("/api/v1/scope")
	if not check(response.status==200 and not response.body.scope.active,"HTTP scope is available before any world owner is populated"): await finish(output); return
	response=await request("/api/v1/controlled")
	if not check(response.status==200 and not response.body.result.available and response.body.result.object_id==null,"Missing control is explicit null and availability over HTTP"): await finish(output); return
	var bare:={"id":2,"nativeLifetime":2}
	var actor:=row(1); actor.replicated.counter=9223372036854775806
	check(publish([actor,bare,row(3,7,8,3),row(4,5,7,4),row(5,5,7,5)],[],true),"Authored raw owner publication accepted")
	motion[1]={"lifetime":55,"position":Vector3(9,8,7),"render":Vector3(8,8,7),"orientation":Vector3(1,0,0),"active":true}
	var before:=lookups
	response=await request("/api/v1/entities?limit=2")
	if not check(response.status==200 and response.body.items.map(func(item):return int(item.object_id))==[1,2] and response.body.page.has_more,"HTTP reference enumeration is sorted and page limited"): await finish(output); return
	var cursor: String=response.body.page.next_cursor
	response=await request("/api/v1/entities?limit=2&cursor="+cursor)
	check(response.status==200 and response.body.items.map(func(item):return int(item.object_id))==[3,4],"Cursor advances the same scoped enumeration")
	response=await request("/api/v1/entities?limit=2&cursor="+str(response.body.page.next_cursor))
	check(response.status==200 and response.body.items.size()==1 and not response.body.page.has_more and response.body.page.next_cursor==null,"Last page has an explicit null next cursor")
	response=await request("/api/v1/entities?object_type=5&current_area=true&area_id=7")
	check(response.status==200 and response.body.items.map(func(item):return int(item.object_id))==[1,4,5],"HTTP type/current-area/area filters combine")
	check(lookups==before,"Pagination reads compact metadata without copying/looking up entity payloads")
	response=await request("/api/v1/entities/1?presentation=true")
	check(response.status==200 and response.body.entity.presentation.value.position["$type"]=="Vector3" and response.body.entity.presentation.value.position.value.map(func(v):return int(v))==[9,8,7],"JSON motion preserves tagged NWN x/y/z values")
	check(response.body.entity.replicated.value.position.map(func(v):return int(v))==[1,2,3] and response.body.entity.presentation.coordinates=="NWN","Received positions remain separate from simulated motion")
	check(response.body.entity.replicated.value.counter["$type"]=="int64" and response.body.entity.replicated.value.counter.value=="9223372036854775806","Large integers retain exact decimal precision")
	var original_reference: String=response.body.reference
	response.body.entity.replicated.value.position[0]=999
	check(objects[1].replicated.position[0]==1,"Mutating a decoded HTTP view cannot mutate the native owner")
	response=await request("/api/v1/references/"+original_reference)
	check(response.status==200 and response.body.entity.presentation.reason=="not_requested","Opaque exact-integer reference resolves and presentation defaults off")
	response=await request("/api/v1/entities/2")
	check(response.status==200 and not response.body.entity.replicated.available and response.body.entity.replicated.value==null,"Previsual missing fields remain unavailable instead of invented stats")
	response=await request("/api/v1/entities/1")
	check(response.body.entity.character.value.stats.available and response.body.entity.character.value.stats.value.armorClass==null,"Explicit received null remains distinct from absent data")
	response=await request("/api/v1/player-character")
	check(response.status==200 and response.body.result.reason=="identity_not_received","Unavailable player-character provenance survives HTTP")
	publish([],[],false,1,1,7,4,{"available":true,"object_id":1,"provenance":"authored_explicit_identity"})
	response=await request("/api/v1/controlled")
	check(response.status==200 and int(response.body.result.object_id)==4,"Possessed control can differ from player-character identity")
	response=await request("/api/v1/player-character")
	check(response.status==200 and int(response.body.result.object_id)==1 and response.body.result.provenance=="authored_explicit_identity","Explicit player identity remains separate and attributed")
	for case in [["/api/v1/entities?limit=0",400],["/api/v1/entities?limit=101",400],["/api/v1/entities?limit=1.5",400],["/api/v1/entities?limit=2&limit=3",400],["/api/v1/entities?current_area=1",400],["/api/v1/entities?area_id=-1",400],["/api/v1/entities?cursor=bad",400],["/api/v1/entities/01",400],["/api/v1/entities/2130706432",400],["/api/v1/entities/99",404],["/api/v1/references/not-a-reference",400],["/api/v1/scope?token=anything",400],["/api/v1/entities?object_type=%35",400],["/unknown",404]]:
		response=await request(case[0]); check(response.status==case[1],"Strict query/path parsing: "+case[0]+" expected "+str(case[1])+", received "+str(response.status))
	response=await request("/api/v1/scope","","none")
	check(response.status==401 and response.headers.get("www-authenticate")=="Bearer","Every HTTP route requires bearer authorization")
	response=await request("/api/v1/scope","","invalid")
	check(response.status==401 and not JSON.stringify(response).contains(credential),"Wrong-token errors cannot reveal the launch token")
	for asset in [["/explorer/","text/html"],["/explorer/app.js","text/javascript"],["/explorer/style.css","text/css"],["/explorer/favicon.svg","image/svg+xml"]]:
		response=await request(asset[0],"","none")
		check(response.status==200 and str(response.headers.get("content-type","")).begins_with(asset[1]) and not response.text.contains(credential),"Public explorer asset contains no per-launch bearer and has a fixed MIME type")
		check(response.headers.get("content-security-policy","").contains("connect-src 'self'") and response.headers.get("referrer-policy")=="no-referrer" and not response.headers.has("access-control-allow-origin"),"Explorer assets use same-origin CSP, no-referrer and no CORS")
	var origin:="http://127.0.0.1:"+str(port)
	var same_origin:="Origin: "+origin+"\r\nSec-Fetch-Site: same-origin\r\nSec-Fetch-Mode: same-origin\r\nSec-Fetch-Dest: empty\r\n"
	response=await request("/api/v1/scope",same_origin)
	check(response.status==200 and not response.headers.has("access-control-allow-origin"),"Exact same-origin authenticated browser fetch works without CORS")
	response=await request("/api/v1/scope",same_origin,"none")
	check(response.status==401,"Same-origin browser access never bypasses API bearer authentication")
	response=await request("/api/v1/scope",same_origin.replace(origin,"http://localhost:"+str(port)),"valid","GET","localhost:"+str(port))
	check(response.status==200,"Localhost page uses its exact same Host/Origin while discovery may name127.0.0.1")
	response=await request("/api/v1/scope",same_origin,"valid","GET","localhost:"+str(port))
	check(response.status==403,"Equivalent loopback hostnames do not bypass exact Origin matching")
	for browser_header in ["Origin: null\r\n","Origin: https://example.invalid\r\n","Sec-Fetch-Site: same-site\r\nSec-Fetch-Mode: cors\r\nSec-Fetch-Dest: \r\n","Sec-Fetch-Site: none\r\nSec-Fetch-Mode: navigate\r\nSec-Fetch-Dest: document\r\n","Sec-Fetch-Mode: cors\r\n"]:
		response=await request("/api/v1/scope",browser_header)
		check(response.status==403,"Foreign/null/non-fetch/incomplete browser contexts remain forbidden")
	response=await request("/explorer/","Sec-Fetch-Site: none\r\nSec-Fetch-Mode: navigate\r\nSec-Fetch-Dest: document\r\n","none")
	check(response.status==200,"A direct browser navigation can load the credential-free explorer document")
	response=await request("/explorer/app.js","Sec-Fetch-Site: cross-site\r\nSec-Fetch-Mode: cors\r\nSec-Fetch-Dest: script\r\n","none")
	check(response.status==403,"Foreign pages cannot load explorer script as an allowed browser context")
	response=await request("/explorer/discovery.json","","none")
	check(response.status==401,"Static routing cannot expose the discovery file or arbitrary local paths")
	for header in ["Origin: https://example.invalid\r\n","Origin: null\r\n","Sec-Fetch-Site: cross-site\r\n"]:
		response=await request("/api/v1/scope",header)
		check(response.status==403 and not response.headers.has("access-control-allow-origin"),"Browser cross-origin requests are denied without CORS")
	response=await request("/api/v1/scope","","valid","GET","evil.invalid:"+str(port))
	check(response.status==403,"Unexpected Host cannot use the loopback service")
	response=await request("/api/v1/scope","Authorization: Bearer invalid\r\n")
	check(response.status==400,"Duplicate authorization is rejected instead of choosing a header")
	response=await request("/api/v1/scope","","valid","POST")
	check(response.status==405 and response.headers.get("allow")=="GET","HTTP cannot issue gameplay or mutation commands")
	for header in ["Content-Length: 1\r\n","Transfer-Encoding: chunked\r\n","Expect: 100-continue\r\n"]:
		response=await request("/api/v1/scope",header)
		check(response.status in [400,417],"Body/transfer/expectation mechanisms are unsupported")
	var valid:="GET /api/v1/scope HTTP/1.1\r\nHost: 127.0.0.1:%d\r\nAuthorization: Bearer %s\r\n\r\n"%[port,credential]
	response=await exchange(valid.to_utf8_buffer(),20)
	check(response.status==200,"Fragmented headers are assembled incrementally")
	response=await exchange(valid.replace("HTTP/1.1","HTTP/1.0").to_utf8_buffer())
	check(response.status==505,"Unsupported HTTP version is explicit")
	response=await request("/api/v1/"+"x".repeat(2050))
	check(response.status==414,"Oversized request target is rejected")
	response=await request("/api/v1/scope","X-Large: "+"a".repeat(9000)+"\r\n")
	check(response.status==431,"Oversized headers cannot grow connection buffers without limit")
	response=await exchange("GET /api/v1/scope HTTP/1.1\r\nHost:".to_utf8_buffer())
	check(response.status==408,"An unfinished slow request is bounded by a timeout")
	var excess:=row(8,5,7,8); excess.replicated.large="a".repeat(WireJson.MAX_STRING_CHARS+1); publish([excess])
	response=await request("/api/v1/entities/8")
	check(response.status==422 and response.body.error.code=="representation_limit","Oversized entity representations are refused without truncating stats")
	var wide:=row(10,5,7,10); wide.replicated.values=range(100000); publish([wide])
	var budget:={"max_nodes":128,"max_text_chars":65536}
	var bounded: Variant=provider.get_by_id(10,false,budget)
	check(bounded==null and budget.exceeded and budget.nodes<=129,"Source copy stops at its node budget before copying a large entity")
	response=await request("/api/v1/entities/10")
	check(response.status==422 and not response.body.has("entity"),"Bounded source-copy rejection returns no partial/truncated entity data")
	var unicode:=row(9,5,7,9); unicode.replicated.text="é".repeat(20000); publish([unicode])
	response=await request("/api/v1/entities/9")
	check(response.status==200 and response.body.entity.replicated.value.text.length()==20000,"A large UTF-8 response is written incrementally with an exact byte length")
	var reserved: Dictionary=WireJson.encode({"$type":"source-data","value":1}).value
	check(reserved["$type"]=="Dictionary","Reserved JSON type tags cannot collide with received dictionary keys")
	var nonfinite: Dictionary=WireJson.encode({"n":NAN,"i":INF}).value
	check(nonfinite.n["$type"]=="float" and nonfinite.n.value=="NaN" and nonfinite.i.value=="Infinity","Non-finite numbers are explicit tagged values, never zero")
	publish([], [1]); response=await request("/api/v1/references/"+original_reference)
	check(response.status==410,"Removal invalidates external scoped references")
	publish([row(1,5,7,20)]); response=await request("/api/v1/references/"+original_reference)
	check(response.status==410,"ID reuse cannot resolve an old HTTP reference to another entity")
	response=await request("/api/v1/entities/1"); var before_transition: String=response.body.reference
	publish([row(1,5,8,20)],[],true,1,2,8)
	response=await request("/api/v1/references/"+before_transition)
	check(response.status==410,"Area generation invalidates old HTTP references")
	response=await request("/api/v1/entities?limit=2&cursor="+cursor)
	check(response.status==410,"Enumeration cursors cannot cross area scopes")
	response=await request("/api/v1/entities/1"); var before_reconnect: String=response.body.reference
	publish([row(1,5,8,20)],[],true,2,0,8)
	response=await request("/api/v1/references/"+before_reconnect)
	check(response.status==410,"Reconnect invalidates the previous connection reference")
	var second:=Server.new(); root.add_child(second)
	var preexisting: Dictionary=second.start(provider,{"port":0,"discovery_path":discovery_path})
	check(not preexisting.listening and preexisting.error=="discovery_exists" and JSON.parse_string(FileAccess.get_file_as_string(discovery_path)).bearer_token==credential,"Startup cannot overwrite a pre-existing discovery file")
	var bind_result: Dictionary=second.start(provider,{"port":port,"discovery_path":test_directory.path_join("bind-error-discovery.json")})
	check(not bind_result.listening and bind_result.error=="bind_failed" and provider.get_scope().active,"Bind error disables only the extra endpoint, preserving API/game state")
	second.free(); response=await request("/api/v1/scope")
	check(response.status==200,"Bind failure cannot stop an already-running endpoint")
	var server: Node=api.get_node("EntityRest")
	var rate_before: int=server.diagnostics().rate_limited; var held: Array[StreamPeerTCP]=[]
	for index in Server.MAX_CLIENTS:
		var peer: StreamPeerTCP=await connect_client(); held.append(peer)
	for peer in held: peer.put_partial_data(valid.to_utf8_buffer())
	for frame in 30: observe_work(); await process_frame
	check(server.diagnostics().rate_limited>rate_before,"Sustained concurrent valid requests hit the conservative global request rate")
	for peer in held: peer.disconnect_from_host()
	held.clear()
	for frame in 4: observe_work(); await process_frame
	var rejected_before: int=server.diagnostics().rejected
	for index in Server.MAX_CLIENTS+2:
		var peer: StreamPeerTCP=await connect_client(); held.append(peer)
	for frame in 4: observe_work(); await process_frame
	check(server.diagnostics().clients<=Server.MAX_CLIENTS and server.diagnostics().rejected>rejected_before,"Sustained idle clients cannot exceed bounded socket admission")
	for peer in held: peer.disconnect_from_host()
	held.clear()
	for frame in 4: await process_frame
	# An unread large response must release its server-side slot, even if the OS
	# send buffer absorbs it before the timeout; no reader is required for cleanup.
	var slow_row:=row(9,5,8,99); slow_row.replicated.text="é".repeat(20000)
	publish([slow_row],[],false,2,0,8)
	await create_timer(0.5).timeout
	var slow_written_before: int=server.diagnostics().written_bytes
	var slow: StreamPeerTCP=await connect_client()
	var slow_request:=valid.replace("/api/v1/scope","/api/v1/entities/9")
	slow.put_partial_data(slow_request.to_utf8_buffer())
	await create_timer((Server.WRITE_TIMEOUT_MS+500)/1000.0).timeout
	check(server.diagnostics().clients==0 and server.diagnostics().written_bytes>slow_written_before+Server.WRITE_QUANTUM,"A large slow/unread response uses partial writes and cannot retain a server socket past its deadline")
	slow.disconnect_from_host()
	before=lookups
	for frame in 20: await process_frame
	check(lookups==before,"Idle REST frames never scan/copy the canonical world")
	var diagnostics: Dictionary=server.diagnostics()
	check(diagnostics.capacity_rejected>0 and diagnostics.request_timeouts>0 and diagnostics.response_complete>0 and diagnostics.values().all(func(value):return value is int or value is bool),"Close-reason diagnostics retain fixed numeric counters without request/header/history capture")
	check(max_frame_read>0 and max_frame_write>0 and max_frame_requests>0 and max_frame_read<=Server.MAX_READ_PER_FRAME and max_frame_write<=Server.MAX_WRITE_PER_FRAME and max_frame_requests<=Server.MAX_REQUESTS_PER_FRAME and diagnostics.clients<=Server.MAX_CLIENTS,"Observed active socket/frame work stays within fixed limits")
	var pending: StreamPeerTCP=await connect_client(); pending.put_partial_data("GET ".to_utf8_buffer()); await process_frame
	var old_token:=credential
	api.stop_rest(); pending.poll()
	check(not api.rest_status().listening and not FileAccess.file_exists(discovery_path),"Stop closes the listener and removes its own credential discovery file")
	for frame in 3: pending.poll(); await process_frame
	check(pending.get_status()!=StreamPeerTCP.STATUS_CONNECTED,"Stop cleans up an unfinished accepted connection")
	pending.disconnect_from_host()
	var restart: Dictionary=api.start_rest_from_arguments(["--entity-api-rest=true","--entity-api-rest-port=0","--entity-api-rest-discovery="+discovery_path])
	load_discovery()
	check(restart.listening and credential!=old_token,"A fresh service launch rotates the bearer token")
	var rotated_token:=credential; credential=old_token
	response=await request("/api/v1/scope")
	check(response.status==401,"The retired bearer cannot authenticate after token rotation")
	credential=rotated_token; response=await request("/api/v1/scope")
	check(response.status==200,"The new bearer authenticates after token rotation")
	var foreign:=FileAccess.open(discovery_path,FileAccess.WRITE); foreign.store_string('{"kind":"foreign-owner"}'); foreign.close()
	api.stop_rest()
	check(FileAccess.file_exists(discovery_path),"Cleanup cannot delete a discovery file replaced by another owner")
	DirAccess.remove_absolute(discovery_path)
	await finish(output)
func finish(output: String) -> void:
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"transportFailureProbe":transport_failure_probe,"transport_failures":transport_failures,"observedFrameWork":{"readBytes":max_frame_read,"writtenBytes":max_frame_write,"requests":max_frame_requests},"gameServerConnections":0,"publicConnections":0,"nativeBuilds":0,"scope":"Real native HTTP sockets bound to IPv4 loopback, per-launch discovery/auth, strict queries, JSON values, pagination, lifetimes, bounded copies, sustained/slow clients, rate limits, bind errors and cleanup; canonical entity owners are authored fixtures. No live client or game-server acceptance."}
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify(result,"  ")+"\n"); file.close()
	credential=""
	if is_instance_valid(api): api.stop_rest(); api.free()
	await process_frame
	print("ENTITY_API_REST_RESULT ",JSON.stringify(result)); quit(0 if failures.is_empty() else 1)
