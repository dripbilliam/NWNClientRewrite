extends SceneTree
const Cipher=preload("res://systems/native_data/native_network_packet_cipher.gd")
class FixtureCrypto extends RefCounted:
	func seal(plain: PackedByteArray)->Dictionary:
		var bytes:=PackedByteArray();bytes.resize(36);bytes.append_array(plain);return {"bytes":bytes}
	func unseal(bytes: PackedByteArray)->Dictionary:return {"bytes":bytes.slice(36)}
func _initialize()->void:
	var cipher=Cipher.new(FixtureCrypto.new(),0x12345678)
	var raw:=PackedByteArray([66,78,75,48])
	var plain:=PackedByteArray([77,1,2,3,4])
	var raw_result: Dictionary=cipher.encode(raw)
	var encrypted: Dictionary=cipher.encode(plain)
	if not raw_result.has("bytes") or raw_result.bytes!=raw or not encrypted.has("bytes") or encrypted.bytes.size()!=plain.size()+41 or encrypted.bytes[0]!=73 or encrypted.bytes.decode_u32(1)!=0x12345678:fail("encode");return
	var recovered: Dictionary=cipher.decode(encrypted.bytes)
	if not recovered.has("bytes") or recovered.bytes!=plain:fail("decode");return
	var wrong: PackedByteArray=encrypted.bytes.duplicate();wrong[1]=0
	if not cipher.decode(wrong).has("error") or not Cipher.requires_encryption(PackedByteArray([66,78,67,82])):fail("boundary");return
	print("NWN79 Godot packet cipher PASS")
	quit(0)
func fail(stage: String)->void:
	printerr("NWN79 Godot packet cipher failed: "+stage)
	quit(1)
