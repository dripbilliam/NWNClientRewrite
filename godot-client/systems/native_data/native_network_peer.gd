extends RefCounted
signal diagnostic_event(event: Dictionary)
signal closed_event(event: Dictionary)
signal operation_turn
const Datagram=preload("res://systems/native_data/native_network_datagram.gd")
const CryptoOwner=preload("res://systems/native_data/native_network_crypto.gd")
const Login=preload("res://systems/native_data/native_network_login.gd")
const Packets=preload("res://systems/native_data/native_login_packets.gd")
const Frames=preload("res://systems/native_data/native_network_frames.gd")
const NativeWindow=preload("res://systems/native_data/native_network_window.gd")
const Messages=preload("res://systems/native_data/native_network_messages.gd")
const Inflater=preload("res://systems/native_data/native_network_inflater.gd")
var crypto: RefCounted
var datagram: RefCounted
var login: RefCounted
var closed:=true
var started:=false
var admitted:=false
var deadline:=0
var remote: Dictionary={}
var error: String=""
var window: RefCounted
var assembler: RefCounted
var inflater: RefCounted
var next_window_poll:=0
var pending_login_diagnostics: Array[Dictionary]=[]
var connection_stage: String="validate-options"
var connection_failure: Dictionary={}
var disconnect_reason: Dictionary={}
var disconnecting:=false
var closed_emitted:=false
var next_operation_ticket:=0
var serving_operation_ticket:=0
var operation_active:=false

func acquire_operation()->bool:
	if closed_emitted:return false
	var ticket:=next_operation_ticket
	next_operation_ticket+=1
	while ticket!=serving_operation_ticket and not closed_emitted:await operation_turn
	if closed_emitted:return false
	operation_active=true
	return true

func release_operation()->void:
	if not operation_active:return
	operation_active=false
	serving_operation_ticket+=1
	operation_turn.emit()

static func connection_failure_record(reason: String,stage: String)->Dictionary:
	return preload("res://systems/native_data/native_network_connection_failure.gd").project({"name":"Error","message":reason},stage)

func diagnose(event: Dictionary)->void:
	var observed: Dictionary=event.duplicate(true)
	pending_login_diagnostics.append(observed)
	diagnostic_event.emit(observed.duplicate(true))

func connect_failure(reason: String)->bool:
	error=reason
	connection_failure=connection_failure_record(reason,connection_stage)
	diagnose({"code":"network.connect-failed","reason":"Native connection preparation or admission failed","failure":connection_failure.duplicate(true)})
	finish()
	return false

func connect_to_server(host: String,port: int,identity: RefCounted,metadata: Dictionary,crypto_executable: String,expected_server_key: PackedByteArray=PackedByteArray(),timeout_ms: int=12000)->bool:
	if started or not closed:error="Native network peer has already started";return false
	started=true
	if host.is_empty() or port<1 or port>65535 or timeout_ms<1 or timeout_ms>120000:return connect_failure("Invalid native network connection settings")
	connection_stage="resolve-address"
	datagram=Datagram.new()
	if not datagram.connect_to_server(host,port):
		connection_stage=str(datagram.failure_stage)
		return connect_failure("Native UDP endpoint is unavailable")
	connection_stage="application-identity"
	crypto=CryptoOwner.new()
	if not crypto.open(crypto_executable):return connect_failure("Native network crypto helper is unavailable")
	var ready: Dictionary=metadata.duplicate(true)
	ready.port=datagram.local_port
	if ready.get("applicationId")==null:ready.applicationId=await crypto.application_id()
	if closed_emitted:return false
	if not ready.applicationId is int or int(ready.applicationId)<0:return connect_failure("Native application identity is unavailable")
	connection_stage="platform-identity"
	if ready.get("platformIdentifier") is Callable:
		var platform: Variant=await ready.platformIdentifier.call(crypto)
		if closed_emitted:return false
		if platform is Dictionary:
			if not platform.has("identity"):return connect_failure(str(platform.get("error","Invalid native platform identity output")))
			ready.platformIdentifier=platform.identity
		else:ready.platformIdentifier=platform
	if not ready.get("platformIdentifier") is String:return connect_failure("Invalid native platform identity output")
	connection_stage="login-context"
	login=Login.new(crypto,identity,ready,expected_server_key)
	login.diagnostic_event.connect(func(event: Dictionary):diagnose(event))
	connection_stage="key-exchange"
	var first: Dictionary=await login.begin()
	if closed_emitted:return false
	if not first.has("send"):return connect_failure(str(first.get("error","Native key exchange could not start")))
	connection_stage="send-key-exchange"
	if not await datagram.send(first.send):return connect_failure("Native network send failed")
	if closed_emitted:return false
	connection_stage="await-admission"
	deadline=Time.get_ticks_msec()+timeout_ms
	closed=false
	return true

func poll()->Dictionary:
	if closed:return {"error":error if not error.is_empty() else "Native peer is closed"}
	if not await acquire_operation():return {"error":error if not error.is_empty() else "Native peer is closed"}
	var result: Dictionary=await poll_serial()
	release_operation()
	return result

func poll_serial()->Dictionary:
	if Time.get_ticks_msec()>deadline and not admitted:fail("Native network login timed out");return {"error":error}
	var incoming: Dictionary=await datagram.receive()
	if incoming.has("error"):fail(str(incoming.error));return {"error":error}
	var records: Array[Dictionary]=[]
	var payloads: Array[PackedByteArray]=[]
	var diagnostics: Array[Dictionary]=[]
	var disconnect_reason: Dictionary={}
	var disconnected:=false
	for bytes in incoming.packets:
		if admitted:
			if bytes.size()>=4 and bytes.slice(0,4).get_string_from_ascii()=="BNDP":
				disconnect_reason=Packets.read_disconnect_response(bytes)
				disconnected=true
				break
			if bytes.is_empty() or bytes[0]!=77:continue
			var delivered: Dictionary=window.receive(bytes,Time.get_ticks_msec())
			for response in delivered.send:
				if not await datagram.send(response):fail("Native reliable reply could not be sent");return {"error":error}
			for frame in delivered.delivered:
				if not assembler.push(frame):fail("Invalid native game frame");return {"error":error}
			var assembled: Array=assembler.drain()
			records.append_array(assembled)
			for record in assembled:
				var decoded: Dictionary=inflater.decode(record.bytes)
				if decoded.has("error"):
					diagnose({"code":"network.message-decompression-failed","reason":"Native message decompression failed","length":record.bytes.size()})
					fail("Native message stream failed")
					return {"error":error,"records":records,"payloads":payloads,"diagnostics":diagnostics}
				payloads.append(decoded.bytes)
			continue
		if login.phase=="validate" and datagram.cipher!=null and bytes.size()==12 and bytes[0]==77:
			var frame: Dictionary=Frames.read(bytes)
			if frame.get("kind",-1)==1:
				var ack: Dictionary=Frames.write(1,0,0)
				if ack.has("bytes"):await datagram.send(ack.bytes)
				continue
		var result: Dictionary=await login.receive(bytes)
		diagnostics.append_array(pending_login_diagnostics)
		pending_login_diagnostics.clear()
		if result.has("error"):fail(str(result.error));return {"error":error,"diagnostics":diagnostics}
		if login.exchange.identity!=0 and datagram.cipher==null:
			if not datagram.set_session_crypto(crypto,int(login.exchange.identity)):fail("Native session cipher is unavailable");return {"error":error,"diagnostics":diagnostics}
		if result.has("send") and not await datagram.send(result.send):fail("Native login packet could not be sent");return {"error":error,"diagnostics":diagnostics}
		if result.get("failed",false):fail("Native server rejected login");return {"error":error,"connectionError":login.connection_error,"diagnostics":diagnostics}
		if result.get("admitted",false):
			admitted=true;remote=result.remote.duplicate(true)
			window=NativeWindow.new(Time.get_ticks_msec())
			window.diagnostic_event.connect(func(event: Dictionary):diagnose(event))
			assembler=Messages.new()
			assembler.diagnostic_event.connect(func(event: Dictionary):diagnose(event))
			inflater=Inflater.new();next_window_poll=Time.get_ticks_msec()+100
	if admitted and not disconnected and not disconnecting and Time.get_ticks_msec()>=next_window_poll:
		for response in window.poll(Time.get_ticks_msec()):
			if not await datagram.send(response):fail("Native reliable poll could not be sent");return {"error":error}
		next_window_poll=Time.get_ticks_msec()+100
	if disconnected:
		# The native HandleBNDP path drops the active server before cleanup, so
		# it does not send a local BNDM in response to the server's BNDP.
		self.disconnect_reason=disconnect_reason.duplicate(true)
		var server_closed: Dictionary={"code":"network.server-disconnected","reason":"Native server closed the connection"}
		for key in disconnect_reason:server_closed[key]=disconnect_reason[key]
		diagnose(server_closed)
		diagnostics.append_array(pending_login_diagnostics)
		pending_login_diagnostics.clear()
		error="Native server disconnected"
		finish()
		return {"error":error,"reason":disconnect_reason,"records":records,"payloads":payloads,"diagnostics":diagnostics}
	return {"admitted":admitted,"phase":login.phase,"remote":remote.duplicate(true),"records":records,"payloads":payloads,"diagnostics":diagnostics}

func send_game_message(payload: PackedByteArray)->bool:
	if closed or disconnecting or not admitted or login==null or login.phase!="admitted" or payload.size()<3 or payload[0]!=112:return false
	if not await acquire_operation():return false
	var sent: bool=await send_game_message_serial(payload)
	release_operation()
	return sent

func send_game_message_serial(payload: PackedByteArray)->bool:
	if closed or disconnecting or not admitted or login==null or login.phase!="admitted":return false
	var outgoing: Dictionary=Messages.packetize(payload)
	if not outgoing.has("frames"):return false
	for frame in outgoing.frames:
		var queued: Dictionary=window.enqueue(frame,Time.get_ticks_msec())
		if queued.has("error"):return fail("Native network peer operation failed")
		for response in queued.send:
			if not await datagram.send(response):return fail("Native network peer operation failed")
	return true

func fail(reason: String)->bool:
	if closed_emitted:return false
	error=reason
	diagnose({"code":"network.peer-failed","reason":reason})
	if not admitted and not disconnecting:
		connection_failure=connection_failure_record(reason,connection_stage)
		diagnose({"code":"network.connect-failed","reason":"Native connection preparation or admission failed","failure":connection_failure.duplicate(true)})
	finish(true)
	return false

func close(send_disconnect: bool=true,failed: bool=false)->Dictionary:
	if closed_emitted:return {}
	disconnecting=true
	if not await acquire_operation():return {}
	if closed_emitted:release_operation();return {}
	var outcome: Dictionary={}
	if send_disconnect and admitted:
		if datagram==null or datagram.closed:
			outcome={"error":"Native disconnect packet could not be sent"}
		elif not await datagram.send(Packets.disconnect_request()):
			outcome={"error":"Native disconnect packet could not be sent"}
		if outcome.is_empty() and crypto!=null and not await crypto.reset():
			outcome={"error":str(crypto.last_error) if not str(crypto.last_error).is_empty() else "Native disconnect crypto reset failed"}
	finish(failed)
	release_operation()
	return outcome

func finish(failed: bool=false)->void:
	if closed_emitted:return
	disconnecting=true
	closed=true;admitted=false
	if datagram!=null:datagram.close();datagram=null
	if crypto!=null:crypto.close();crypto=null
	if inflater!=null:inflater.close();inflater=null
	window=null;assembler=null
	closed_emitted=true
	operation_turn.emit()
	var outcome: Dictionary={"failed":failed}
	if not disconnect_reason.is_empty():outcome.reason=disconnect_reason.duplicate(true)
	closed_event.emit(outcome)

func snapshot()->Dictionary:
	var login_phase: String=str(login.phase) if login!=null else "new"
	return {"phase":"closed" if closed else login_phase,"loginPhase":login_phase,"closed":closed,"admitted":login_phase=="admitted" and not closed}
