extends SceneTree
const Session=preload("res://systems/native_data/native_network_session.gd")
const Identity=preload("res://systems/native_data/native_login_identity.gd")
const Characters=preload("res://systems/native_data/native_server_characters.gd")

class FakePeer extends RefCounted:
	var payloads: Array=[]
	var sent: Array[PackedByteArray]=[]
	var next_error: String=""
	func poll()->Dictionary:
		var result:={"payloads":payloads.duplicate()};payloads.clear()
		if not next_error.is_empty():result.error=next_error;next_error=""
		return result
	func send_game_message(packet: PackedByteArray)->bool:sent.append(packet.duplicate());return true
	func close()->void:pass

func _initialize()->void:
	var fixture: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://tests/nwn79_portal_fixture.json"))
	if not fixture is Dictionary or not fixture.get("cases") is Array:fail("Portal fixture unavailable");return
	var rows: Dictionary={}
	for row in fixture.cases:rows[str(row.name)]=row
	for name in ["native-activation-0","native-activation-1","native-character-0","local-bic"]:
		if not rows.has(name):fail("Portal oracle missing "+name);return
	var old:=Session.new();root.add_child(old)
	var peer:=FakePeer.new();old.peer=peer;old.phase="playing";old.character_confirmed=true;old.player_name="Portal Tester"
	old.identity=Identity.new()
	if not old.identity.configure("A".repeat(41),"old-password","community"):fail("Old login identity unavailable");return
	var handoffs: Array[Dictionary]=[]
	old.portal_handoff_ready.connect(func(handoff: Dictionary):handoffs.append(handoff))
	peer.payloads=[str(rows["native-activation-0"].packet).hex_decode()]
	old._process(0.0)
	if old.phase!="transferring" or peer.sent.size()!=1 or peer.sent[0]!=PackedByteArray([112,43,1]) or not handoffs.is_empty():fail("Activation did not request one old-server character download");return
	peer.payloads=[str(rows["native-character-0"].packet).hex_decode()]
	peer.next_error="Native server disconnected"
	old._process(0.0)
	if old.phase!="portal-ready" or handoffs.size()!=1 or int(handoffs[0].character.source)!=2 or str(handoffs[0].host)!="127.0.0.1" or int(handoffs[0].port)!=5122:fail("Coalesced disconnect lost the original destination or character");return
	var handoff: Dictionary=handoffs[0]
	old.close()
	if handoff.identity.disposed:fail("Old connection disposed destination identity");return
	var destination:=Session.new();root.add_child(destination)
	if not destination.configure_portal(handoff.identity,handoff.character,str(handoff.waypoint)):fail("Destination reference could not be configured");return
	destination.peer=FakePeer.new();destination.phase="portal-character-pending";destination.catalog=RefCounted.new()
	if not destination.submit_portal_character() or destination.phase!="character-loading" or destination.peer.sent.size()!=1 or destination.peer.sent[0]!=Characters.play_request(2,str(handoff.character.resref)).bytes:fail("Destination did not submit original reference without a character list");return
	destination.close()
	if not handoff.identity.disposed:fail("Destination did not dispose inherited identity");return
	var local:=Session.new();root.add_child(local)
	var local_identity:=Identity.new();local_identity.configure("A".repeat(41))
	var bic: Dictionary=rows["local-bic"].expected
	if not local.configure_portal(local_identity,{"data":PackedByteArray(bic.data)},""):fail("Original-format local BIC handoff was rejected");return
	local.peer=FakePeer.new();local.phase="portal-character-pending";local.catalog=RefCounted.new()
	if not local.submit_portal_character() or local.peer.sent.size()!=1 or local.peer.sent[0].slice(0,3)!=PackedByteArray([112,2,1]):fail("Destination did not upload portal BIC through original 2/1 request");return
	local.close()
	if not local_identity.disposed:fail("Local destination identity was retained");return
	print("NWN79 Godot portal session PASS: old download request, coalesced disconnect handoff, destination play and BIC upload, secret disposal")
	quit(0)

func fail(reason: String)->void:
	printerr("NWN79 Godot portal session failed: "+reason)
	quit(1)
