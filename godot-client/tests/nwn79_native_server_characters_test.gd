extends SceneTree
const Characters=preload("res://systems/native_data/native_server_characters.gd")
const Session=preload("res://systems/native_data/native_network_session.gd")
class FakePeer extends RefCounted:
	var sent: Array[PackedByteArray]=[]
	func send_game_message(bytes: PackedByteArray)->bool:sent.append(bytes.duplicate());return true
	func close()->void:pass

func _initialize()->void:
	var path:=ProjectSettings.globalize_path("res://../backups/animations/native-server-vault-observations.json")
	var fixture: Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
	if not fixture is Dictionary: fail("Native character fixture is unavailable");return
	for row in fixture.get("lists",[]):
		var packet: PackedByteArray=str(row.packet).hex_decode()
		var actual: Dictionary=Characters.decode_packet(packet)
		if actual.has("error"): fail(str(actual.error));return
		if actual.characters.size()!=row.characters.size(): fail("character count differs");return
		for index in range(actual.characters.size()):
			var candidate: Dictionary=actual.characters[index]
			var expected: Dictionary=row.characters[index]
			for key in ["resref","source","portrait","portraitRef"]:
				if candidate[key]!=expected[key]: fail("native character field differs: "+key);return
			if candidate.classes.size()!=expected.classes.size(): fail("native class count differs");return
			for class_index in range(candidate.classes.size()):
				if int(candidate.classes[class_index].id)!=int(expected.classes[class_index].id) or int(candidate.classes[class_index].level)!=int(expected.classes[class_index].level): fail("native class differs");return
	for row in fixture.get("requests",[]):
		var result: Dictionary=Characters.preview_request(int(row.source),str(row.resref)) if row.kind=="preview" else Characters.play_request(int(row.source),str(row.resref))
		if result.has("error"):fail("native character request rejected");return
		var actual: PackedByteArray=result.bytes
		var expected: PackedByteArray=str(row.packet).hex_decode()
		if actual.size()!=expected.size():fail("native character request length differs");return
		for index in range(actual.size()):
			var mask:=0xe0 if index==actual.size()-1 else 0xff
			if (int(actual[index]) & mask)!=(int(expected[index]) & mask):fail("native character request byte differs");return
	var upload_fixture: Variant=JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://../backups/animations/native-network-character-observations.json")))
	if not upload_fixture is Dictionary:fail("Native character upload fixture is unavailable");return
	for row in upload_fixture.cases:
		var result: Dictionary=Characters.upload_request(str(row.blob).hex_decode(),int(row.subtype))
		var expected: PackedByteArray=str(row.packet).hex_decode()
		if result.has("error") or result.bytes.size()!=expected.size() or result.bytes.slice(0,-1)!=expected.slice(0,-1) or (int(result.bytes[-1])&0xe0)!=(int(expected[-1])&0xe0):fail("Native character upload differs from original sender");return
	if not Characters.upload_request(PackedByteArray()).has("error") or not Characters.upload_request(PackedByteArray([1]),2).has("error"):fail("Native upload accepted invalid input");return
	var local_bic:=PackedByteArray([66,73,67,32,1,2,3])
	var restricted:=Session.new();var restricted_peer:=FakePeer.new()
	if restricted.local_vault_allowed or not restricted.set_server_vault_policy({"host":"fixture","port":5121,"allowLocalVaultCharacters":false},"fixture",5121):fail("Server-vault-only policy was not admitted from the original server-info result");return
	restricted.peer=restricted_peer;restricted.phase="character-selection";restricted.catalog=RefCounted.new()
	if restricted.play_local_character(local_bic) or not restricted_peer.sent.is_empty():fail("Server-vault-only session uploaded a local character");return
	if not restricted.play_local_character(local_bic,true) or restricted_peer.sent.size()!=1 or restricted_peer.sent[0]!=Characters.upload_request(local_bic,19).bytes:fail("Server-vault-only character creation did not preserve original subtype 19");return
	restricted.close();restricted.free()
	var session:=Session.new();var peer:=FakePeer.new()
	if not session.set_server_vault_policy({"host":"fixture","port":5121,"allowLocalVaultCharacters":true},"fixture",5121):fail("Local-vault policy was not admitted from the original server-info result");return
	session.peer=peer;session.phase="character-selection";session.catalog=RefCounted.new()
	if not session.play_local_character(local_bic) or session.phase!="character-loading" or peer.sent.size()!=1 or peer.sent[0]!=Characters.upload_request(local_bic).bytes:fail("Godot local character admission did not send the original packet");return
	if session.play_local_character(local_bic) or peer.sent.size()!=1:fail("Godot session uploaded a local character twice");return
	session.close();session.free()
	print("NWN79 Godot native server character and upload fixtures PASS: uploads=",upload_fixture.cases.size())
	quit(0)

func fail(reason: String)->void:
	printerr("NWN79 server character-list fixture failed: "+reason)
	quit(1)
