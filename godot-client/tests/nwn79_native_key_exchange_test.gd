extends SceneTree
const Exchange=preload("res://systems/native_data/native_network_key_exchange.gd")
class FixtureCrypto extends RefCounted:
	var resets:=0
	func start()->Dictionary:
		var bytes:=PackedByteArray();bytes.resize(32);bytes.fill(1);return {"bytes":bytes}
	func finish(packet2: PackedByteArray)->Dictionary:
		if packet2.size()!=80:return {"error":"packet 2"}
		var packet3:=PackedByteArray();packet3.resize(48);packet3.fill(2)
		var key:=PackedByteArray();key.resize(32);key.fill(3)
		return {"packet3":packet3,"server_public_key":key}
	func reset()->bool:
		resets+=1;return true
func _initialize()->void:
	var owner:=FixtureCrypto.new()
	var expected:=PackedByteArray();expected.resize(32);expected.fill(3)
	var exchange=Exchange.new(owner,expected)
	var first: Dictionary=exchange.begin()
	if not first.has("send") or first.send.size()!=36 or first.send.slice(0,4).get_string_from_ascii()!="BNK1":fail("packet 1");return
	var second:=PackedByteArray();second.resize(84);second.encode_u32(0,0x324b4e42)
	var third: Dictionary=exchange.receive(second)
	if not third.get("accepted",false) or third.send.size()!=52 or exchange.stage!=3:fail("packet 3");return
	var fourth:=PackedByteArray([66,78,75,52,0x78,0x56,0x34,0x12])
	var ready: Dictionary=exchange.receive(fourth)
	if not ready.get("ready_for_login",false) or ready.identity!=0x12345678:fail("packet 4");return
	var wrong_key:=PackedByteArray();wrong_key.resize(32);wrong_key.fill(4)
	var mismatch=Exchange.new(owner,wrong_key);mismatch.begin()
	var rejected: Dictionary=mismatch.receive(second)
	if not rejected.get("failed",false) or rejected.send.get_string_from_ascii()!="BNK0" or owner.resets!=1:fail("server identity pin");return
	print("NWN79 Godot key exchange PASS")
	quit(0)
func fail(stage: String)->void:
	printerr("NWN79 Godot key exchange failed: "+stage)
	quit(1)
