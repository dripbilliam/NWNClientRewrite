extends RefCounted
signal diagnostic_event(event: Dictionary)
const Exchange=preload("res://systems/native_data/native_network_key_exchange.gd")
const Packets=preload("res://systems/native_data/native_login_packets.gd")
var identity: RefCounted
var metadata: Dictionary={}
var exchange: RefCounted
var phase: String="new"
var connection_error:=0
var remote: Dictionary={}
var expected_key_invalid:=false

func _init(crypto: RefCounted,login_identity: RefCounted,login_metadata: Dictionary,expected_server_key: PackedByteArray=PackedByteArray())->void:
	identity=login_identity
	metadata=login_metadata.duplicate(true)
	expected_key_invalid=not expected_server_key.is_empty() and expected_server_key.size()!=32
	exchange=Exchange.new(crypto,expected_server_key)

func begin()->Dictionary:
	if phase!="new":return {"error":"Native login has already started"}
	if expected_key_invalid:return {"error":"Invalid expected server public key"}
	var result: Dictionary=await exchange.begin()
	if result.has("send"):phase="key-exchange"
	return result

func reject(error_code: int,tag: String="")->Dictionary:
	phase="rejected";connection_error=error_code
	diagnostic_event.emit({"code":"network.login-rejected","reason":"Native server rejected login","tag":tag,"connectionError":error_code})
	return {"accepted":true,"failed":true,"connectionError":error_code}

func unsupported(reason: String,tag: String)->Dictionary:
	diagnostic_event.emit({"code":"network.login-unhandled","reason":reason,"tag":tag,"phase":phase})
	return {"accepted":false}

func with_exchange_diagnostic(result: Dictionary,tag: String)->Dictionary:
	if result.has("error"):return result
	if result.get("failed",false):
		diagnostic_event.emit({"code":"network.key-exchange-failed","reason":"Server rejected key exchange" if tag=="BNK0" else str(result.get("reason","Key exchange authentication failed"))})
		result.erase("reason")
	elif not result.get("accepted",false):
		var reason:=str(result.get("reason",""))
		if reason=="Invalid packet 2 length or stage":reason="Invalid packet2 length or stage"
		diagnostic_event.emit({"code":"network.key-exchange-rejected","reason":reason,"tag":tag,"stage":int(exchange.stage)})
		result={"accepted":false}
	return result

func receive(bytes: PackedByteArray)->Dictionary:
	if bytes.size()<4:return unsupported("Truncated login packet","")
	var tag:=bytes.slice(0,4).get_string_from_ascii()
	if phase=="key-exchange":
		if tag not in ["BNK0","BNK2","BNK4"]:return unsupported("Unexpected packet during key exchange",tag)
		var result: Dictionary=with_exchange_diagnostic(await exchange.receive(bytes),tag)
		if result.get("failed",false):phase="rejected";connection_error=exchange.connection_error;return result
		if result.get("ready_for_login",false):
			var request: Dictionary=metadata.duplicate(true);request.publicKey=identity.public_key
			var connect: Dictionary=Packets.connect_request(request)
			if not connect.has("bytes"):return {"error":connect.get("error","Invalid native connect request")}
			phase="connect"
			return {"accepted":true,"send":connect.bytes}
		return result
	if tag=="BNCR" and phase in ["connect","validate"]:
		var response: Dictionary=Packets.read_connect_response(bytes)
		if response.has("error"):return unsupported("Invalid native login response or identity operation",tag)
		if response.kind=="rejected":return reject(int(response.connectionError),tag)
		var trailing: Dictionary={}
		if int(response.get("trailingBytes",0))>0:
			trailing={"code":"network.login-trailing-bytes","reason":"Native connection response has trailing bytes","tag":tag,"count":int(response.trailingBytes)}
			diagnostic_event.emit(trailing)
		var proof: Dictionary=identity.respond(response)
		if proof.has("error") or not proof.has("connectionError"):return unsupported("Invalid native login response or identity operation",tag)
		var validation: Dictionary=Packets.validation_response(proof)
		if not validation.has("bytes"):return unsupported("Invalid native login response or identity operation",tag)
		connection_error=int(proof.connectionError);phase="validate"
		return {"accepted":true,"send":validation.bytes,"passwordRequired":response.passwordRequired}
	if tag=="BNVR" and phase=="validate":
		var response: Dictionary=Packets.read_validation_response(bytes)
		if response.has("error"):return unsupported("Invalid native login response or identity operation",tag)
		if response.kind=="rejected":return reject(int(response.connectionError),tag)
		remote={"applicationId":response.applicationId,"build":response.build.duplicate(true)}
		phase="admitted";connection_error=0
		return {"accepted":true,"admitted":true,"remote":remote.duplicate(true)}
	return unsupported("Packet is outside the current login phase",tag)
