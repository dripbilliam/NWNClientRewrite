extends RefCounted
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

func connect_to_server(host: String,port: int,identity: RefCounted,metadata: Dictionary,crypto_executable: String,expected_server_key: PackedByteArray=PackedByteArray(),timeout_ms: int=12000)->bool:
	if started or not closed or timeout_ms<1 or timeout_ms>120000:return false
	started=true
	crypto=CryptoOwner.new()
	if not crypto.open(crypto_executable):return fail("Native network crypto helper is unavailable")
	datagram=Datagram.new()
	if not datagram.connect_to_server(host,port):return fail("Native UDP endpoint is unavailable")
	var ready: Dictionary=metadata.duplicate(true)
	ready.port=datagram.local_port
	ready.applicationId=crypto.application_id()
	if int(ready.applicationId)<0:return fail("Native application identity is unavailable")
	login=Login.new(crypto,identity,ready,expected_server_key)
	var first: Dictionary=login.begin()
	if not first.has("send") or not datagram.send(first.send):return fail("Native key exchange could not start")
	deadline=Time.get_ticks_msec()+timeout_ms
	closed=false
	return true

func poll()->Dictionary:
	if closed:return {"error":error if not error.is_empty() else "Native peer is closed"}
	if Time.get_ticks_msec()>deadline and not admitted:fail("Native network login timed out");return {"error":error}
	var incoming: Dictionary=datagram.receive()
	if incoming.has("error"):fail(str(incoming.error));return {"error":error}
	var records: Array[Dictionary]=[]
	var payloads: Array[PackedByteArray]=[]
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
				if not datagram.send(response):fail("Native reliable reply could not be sent");return {"error":error}
			for frame in delivered.delivered:
				if not assembler.push(frame):fail("Invalid native game frame");return {"error":error}
			records.append_array(assembler.drain())
			continue
		if login.phase=="validate" and datagram.cipher!=null and bytes.size()==12 and bytes[0]==77:
			var frame: Dictionary=Frames.read(bytes)
			if frame.get("kind",-1)==1:
				var ack: Dictionary=Frames.write(1,0,0)
				if ack.has("bytes"):datagram.send(ack.bytes)
				continue
		var result: Dictionary=login.receive(bytes)
		if result.has("error"):fail(str(result.error));return {"error":error}
		if login.exchange.identity!=0 and datagram.cipher==null:
			if not datagram.set_session_crypto(crypto,int(login.exchange.identity)):fail("Native session cipher is unavailable");return {"error":error}
		if result.has("send") and not datagram.send(result.send):fail("Native login packet could not be sent");return {"error":error}
		if result.get("failed",false):fail("Native server rejected login");return {"error":error,"connectionError":login.connection_error}
		if result.get("admitted",false):
			admitted=true;remote=result.remote.duplicate(true)
			window=NativeWindow.new(Time.get_ticks_msec());assembler=Messages.new();inflater=Inflater.new();next_window_poll=Time.get_ticks_msec()+100
	if admitted and not disconnected and Time.get_ticks_msec()>=next_window_poll:
		for response in window.poll(Time.get_ticks_msec()):
			if not datagram.send(response):fail("Native reliable poll could not be sent");return {"error":error}
		next_window_poll=Time.get_ticks_msec()+100
	for record in records:
		var decoded: Dictionary=inflater.decode(record.bytes)
		if decoded.has("error"):fail(str(decoded.error));return {"error":error}
		payloads.append(decoded.bytes)
	if disconnected:
		# The native HandleBNDP path drops the active server before cleanup, so
		# it does not send a local BNDM in response to the server's BNDP.
		error="Native server disconnected"
		close(false)
		return {"error":error,"reason":disconnect_reason,"records":records,"payloads":payloads}
	return {"admitted":admitted,"phase":login.phase,"remote":remote.duplicate(true),"records":records,"payloads":payloads}

func send_game_message(payload: PackedByteArray)->bool:
	if closed or not admitted or payload.size()<3 or payload[0]!=112:return false
	var outgoing: Dictionary=Messages.packetize(payload)
	if not outgoing.has("frames"):return false
	for frame in outgoing.frames:
		var queued: Dictionary=window.enqueue(frame,Time.get_ticks_msec())
		if queued.has("error"):return fail(str(queued.error))
		for response in queued.send:
			if not datagram.send(response):return fail("Native game message could not be sent")
	return true

func fail(reason: String)->bool:
	error=reason
	close()
	return false

func close(send_disconnect: bool=true)->void:
	if closed and datagram==null and crypto==null:return
	if send_disconnect and admitted and datagram!=null and not datagram.closed:datagram.send(Packets.disconnect_request())
	closed=true;admitted=false
	if datagram!=null:datagram.close();datagram=null
	if crypto!=null:crypto.close();crypto=null
	if inflater!=null:inflater.close();inflater=null
	window=null;assembler=null
