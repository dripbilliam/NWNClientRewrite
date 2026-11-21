extends RefCounted
# BN discovery/key-exchange packets are raw; session data uses the native
# encrypted envelope: 'I', little-endian identity, libhydrogen ciphertext.
var crypto: RefCounted
var identity:=0
func _init(owner: RefCounted,session_identity: int)->void:
	crypto=owner
	identity=session_identity

static func requires_encryption(bytes: PackedByteArray)->bool:
	return bytes.size()<4 or bytes[0]!=66 or bytes[1]!=78 or bytes[2]==67 or bytes[2]==86

func encode(plain: PackedByteArray)->Dictionary:
	if identity<0 or identity>0xffffffff:return {"error":"Invalid native cryptographic identity"}
	if not requires_encryption(plain):return {"bytes":plain.duplicate()}
	var result: Dictionary=await crypto.seal(plain)
	if not result.has("bytes"):return result
	var wire:=PackedByteArray();wire.resize(5);wire[0]=73;wire.encode_u32(1,identity);wire.append_array(result.bytes)
	return {"bytes":wire}

func decode(wire: PackedByteArray)->Dictionary:
	if wire.size()<41 or wire[0]!=73:return {"error":"Invalid native encrypted peer envelope"}
	if int(wire.decode_u32(1))!=identity:return {"error":"Native encrypted peer identity mismatch"}
	return await crypto.unseal(wire.slice(5))
