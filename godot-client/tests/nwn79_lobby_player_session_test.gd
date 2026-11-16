extends SceneTree
const Session=preload("res://systems/native_data/native_network_session.gd")

class FakePeer extends RefCounted:
	var payloads: Array=[]
	var sent: Array[PackedByteArray]=[]
	func poll()->Dictionary:
		var result:={"payloads":payloads.duplicate()};payloads.clear();return result
	func send_game_message(packet: PackedByteArray)->bool:
		sent.append(packet.duplicate());return true
	func close()->void:pass

func _initialize()->void:
	var fixture: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://tests/nwn79_lobby_player_fixture.json"))
	if not fixture is Dictionary:fail("Original-format lobby-player fixture unavailable");return
	var present: Dictionary={};var absent: Dictionary={}
	for row in fixture.cases:
		if row.expected.present and present.is_empty():present=row
		if not row.expected.present and absent.is_empty():absent=row
	if present.is_empty() or absent.is_empty():fail("Original-format lobby-player cases unavailable");return
	var session=Session.new();root.add_child(session);var peer=FakePeer.new();session.peer=peer;session.phase="character-selection"
	var views: Array=[];session.lobby_players_ready.connect(func(players: Array):views.append(players.duplicate(true)))
	var opened: Dictionary=session.lobby_player_subscription(true)
	if not opened.get("sent",false) or peer.sent.size()!=1 or peer.sent[0]!=PackedByteArray([112,49,1]) or not session.lobby_players.subscribed:fail("Player page did not send original 49/1 subscription");return
	peer.payloads=[str(present.packet).hex_decode()];session._process(0.0)
	if views.size()!=2 or views[-1].size()!=1 or int(views[-1][0].id)!=int(present.expected.character.id):fail("49/3 was not projected as a separate subscribed lobby player");return
	if not session.characters.is_empty() or not session.world_state.registry.is_empty():fail("Lobby-player record leaked into playable or world registry");return
	var closed: Dictionary=session.lobby_player_subscription(false)
	if not closed.get("sent",false) or peer.sent[-1]!=PackedByteArray([112,49,2]) or session.lobby_players.subscribed or session.lobby_players.list().size()!=1:fail("Player page close did not send 49/2 while retaining the connection map");return
	peer.payloads=[str(absent.packet).hex_decode()];session._process(0.0)
	if session.lobby_players.list().size()!=1:fail("Unsubscribed lobby record mutated the current map");return
	var choices: Array[Dictionary]=[{"source":17,"resref":"fighter"}];session.characters=choices
	if not session.lobby_player_subscription(true).get("sent",false) or not session.play_character(17,"fighter"):fail("Playable character submission failed after subscription");return
	if peer.sent.size()<5 or peer.sent[-2]!=PackedByteArray([112,49,2]) or session.phase!="character-loading" or session.lobby_players.subscribed:fail("Character submission did not retire lobby subscription before Play");return
	session.close()
	if session.lobby_players.subscribed or not session.lobby_players.list().is_empty():fail("Connection close retained lobby players");return
	print("NWN79 lobby-player session PASS: 49/1, subscribed 49/3, 49/2, Play ordering and reset")
	quit(0)

func fail(reason: String)->void:
	printerr("NWN79 lobby-player session failed: "+reason)
	quit(1)
