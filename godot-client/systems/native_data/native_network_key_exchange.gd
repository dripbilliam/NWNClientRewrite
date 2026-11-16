extends RefCounted
var crypto: RefCounted
var expected_server_public_key:=PackedByteArray()
var stage:=0
var identity:=0
var have_session_keys:=false
var connection_error:=0
var server_public_key:=PackedByteArray()
var failed:=false

func _init(owner: RefCounted,expected_key: PackedByteArray=PackedByteArray())->void:
	crypto=owner
	expected_server_public_key=expected_key.duplicate()

static func packet(tag: String,body: PackedByteArray=PackedByteArray())->PackedByteArray:
	var bytes:=tag.to_ascii_buffer();bytes.append_array(body);return bytes

func begin()->Dictionary:
	if stage!=0 or failed:return {"error":"NWN key exchange has already started"}
	var result: Dictionary=crypto.start()
	if not result.has("bytes") or result.bytes.size()!=32:return {"error":result.get("error","Invalid NWN key exchange packet 1")}
	stage=1
	return {"send":packet("BNK1",result.bytes)}

func abort(reason: String)->Dictionary:
	crypto.reset();stage=0;identity=0;have_session_keys=false;connection_error=0x13;server_public_key.fill(0);server_public_key=PackedByteArray();failed=true
	return {"accepted":true,"send":packet("BNK0"),"failed":true,"reason":reason}

func receive(bytes: PackedByteArray)->Dictionary:
	if bytes.size()<4:return {"accepted":false,"reason":"Truncated key exchange packet"}
	var tag:=bytes.slice(0,4).get_string_from_ascii()
	if tag=="BNK0":
		if stage>=3:return {"accepted":false,"reason":"Key reset after one-sided completion"}
		crypto.reset();stage=0;identity=0;have_session_keys=false;connection_error=0x13;server_public_key.fill(0);server_public_key=PackedByteArray();failed=true
		return {"accepted":true,"failed":true}
	if tag=="BNK2":
		if bytes.size()!=84 or stage>=3 or failed:return {"accepted":false,"reason":"Invalid packet 2 length or stage"}
		var result: Dictionary=crypto.finish(bytes.slice(4))
		if not result.has("packet3") or not result.has("server_public_key") or result.packet3.size()!=48 or result.server_public_key.size()!=32:return abort("Key exchange authentication failed")
		if not expected_server_public_key.is_empty() and expected_server_public_key!=result.server_public_key:return abort("Server cryptographic identity mismatch")
		stage=3;have_session_keys=true;server_public_key=result.server_public_key.duplicate()
		return {"accepted":true,"send":packet("BNK3",result.packet3)}
	if tag=="BNK4":
		if bytes.size()!=8 or not have_session_keys or stage<3 or identity!=0 or failed:return {"accepted":false,"reason":"Invalid completion length or stage"}
		identity=int(bytes.decode_u32(4))
		return {"accepted":true,"ready_for_login":true,"identity":identity}
	return {"accepted":false,"reason":"Unsupported key exchange packet"}
