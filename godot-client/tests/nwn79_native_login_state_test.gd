extends SceneTree
const Login=preload("res://systems/native_data/native_network_login.gd")
const Identity=preload("res://systems/native_data/native_login_identity.gd")
class FixtureCrypto extends RefCounted:
	func start()->Dictionary:
		var bytes:=PackedByteArray();bytes.resize(32);return {"bytes":bytes}
	func finish(packet2: PackedByteArray)->Dictionary:
		if packet2.size()!=80:return {"error":"bad packet"}
		var packet3:=PackedByteArray();packet3.resize(48)
		var key:=PackedByteArray();key.resize(32)
		return {"packet3":packet3,"server_public_key":key}
	func reset()->bool:return true
func _initialize()->void:
	var fixture: String=ProjectSettings.globalize_path("res://../backups/animations/native-network-login-packets-observations.json")
	var file:=FileAccess.open(fixture,FileAccess.READ)
	if file==null:fail("fixture unavailable");return
	var observed: Dictionary=JSON.parse_string(file.get_as_text());file.close()
	var connect: Dictionary={};var challenge:=PackedByteArray();var admitted:=PackedByteArray()
	for row in observed.cases:
		var sample: Dictionary=row["case"]
		if sample.tag=="BNCS" and connect.is_empty():connect=sample.duplicate(true)
		if sample.tag=="BNCR" and not sample.reason and challenge.is_empty() and not sample.passwordRequired:challenge=str(row.calls[0][1]).hex_decode()
		if sample.tag=="BNVR" and not sample.reason and admitted.is_empty():admitted=str(row.calls[0][1]).hex_decode()
	connect.platformId=2
	var identity=Identity.new()
	if not identity.configure("A".repeat(41)):fail("identity");return
	var login=Login.new(FixtureCrypto.new(),identity,connect)
	if not login.begin().has("send") or login.phase!="key-exchange":fail("begin");return
	var key2:=PackedByteArray();key2.resize(84);key2.encode_u32(0,0x324b4e42)
	if not login.receive(key2).has("send"):fail("key exchange");return
	var key4:=PackedByteArray([66,78,75,52,1,0,0,0])
	var request: Dictionary=login.receive(key4)
	if not request.has("send") or request.send.slice(0,4).get_string_from_ascii()!="BNCS" or login.phase!="connect":fail("connect request");return
	var validation: Dictionary=login.receive(challenge)
	if not validation.has("send") or validation.send.slice(0,4).get_string_from_ascii()!="BNVS" or login.phase!="validate":fail("challenge");return
	var accepted: Dictionary=login.receive(admitted)
	if not accepted.get("admitted",false) or login.phase!="admitted":fail("admission");return
	identity.dispose()
	print("NWN79 Godot login state PASS")
	quit(0)
func fail(stage: String)->void:
	printerr("NWN79 Godot login state failed: "+stage)
	quit(1)
