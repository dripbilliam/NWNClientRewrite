extends RefCounted
const Exchange=preload("res://systems/native_data/native_network_key_exchange.gd")
const Packets=preload("res://systems/native_data/native_login_packets.gd")
var identity: RefCounted
var metadata: Dictionary={}
var exchange: RefCounted
var phase: String="new"
var connection_error:=0
var remote: Dictionary={}

func _init(crypto: RefCounted,login_identity: RefCounted,login_metadata: Dictionary,expected_server_key: PackedByteArray=PackedByteArray())->void:
	identity=login_identity
	metadata=login_metadata.duplicate(true)
	exchange=Exchange.new(crypto,expected_server_key)

func begin()->Dictionary:
	if phase!="new":return {"error":"Native login has already started"}
	var result: Dictionary=exchange.begin()
	if result.has("send"):phase="key-exchange"
	return result

func reject(error_code: int)->Dictionary:
	phase="rejected";connection_error=error_code
	return {"accepted":true,"failed":true,"connectionError":error_code}

func receive(bytes: PackedByteArray)->Dictionary:
	if bytes.size()<4:return {"accepted":false,"reason":"Truncated login packet"}
	var tag:=bytes.slice(0,4).get_string_from_ascii()
	if phase=="key-exchange":
		if tag not in ["BNK0","BNK2","BNK4"]:return {"accepted":false,"reason":"Unexpected packet during key exchange"}
		var result: Dictionary=exchange.receive(bytes)
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
		if response.has("error"):return {"accepted":false,"reason":"Invalid native connection response"}
		if response.kind=="rejected":return reject(int(response.connectionError))
		var proof: Dictionary=identity.respond(response)
		if proof.has("error"):return {"accepted":false,"reason":"Invalid native login identity operation"}
		var validation: Dictionary=Packets.validation_response(proof)
		if not validation.has("bytes"):return {"accepted":false,"reason":"Invalid native validation response"}
		connection_error=int(proof.connectionError);phase="validate"
		return {"accepted":true,"send":validation.bytes,"passwordRequired":response.passwordRequired}
	if tag=="BNVR" and phase=="validate":
		var response: Dictionary=Packets.read_validation_response(bytes)
		if response.has("error"):return {"accepted":false,"reason":"Invalid native validation response"}
		if response.kind=="rejected":return reject(int(response.connectionError))
		remote={"applicationId":response.applicationId,"build":response.build.duplicate(true)}
		phase="admitted";connection_error=0
		return {"accepted":true,"admitted":true,"remote":remote.duplicate(true)}
	return {"accepted":false,"reason":"Packet is outside the current login phase"}
