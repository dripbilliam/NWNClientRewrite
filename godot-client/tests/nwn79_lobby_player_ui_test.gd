extends SceneTree
const Lobby=preload("res://systems/character_lobby.gd")
const NativeLobby=preload("res://systems/native_character_lobby.gd")
const Registry=preload("res://systems/native_data/native_lobby_player_registry.gd")
const Decoder=preload("res://systems/native_data/native_network_lobby_player.gd")
var failures: Array=[]
var checks:=0

func _initialize()->void:call_deferred("run")
func check(value: bool,label: String)->void:
	checks+=1
	if not value:failures.append(label)
func ids(rows: Array)->Array:
	var values: Array=[]
	for row in rows:values.append(int(row.id))
	return values

func run()->void:
	var fixture: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://tests/nwn79_lobby_player_fixture.json"))
	if not fixture is Dictionary or int(fixture.get("capturedNative",-1))!=0 or fixture.cases.size()!=9:
		printerr("NWN79 lobby-player UI fixture unavailable");quit(1);return
	var registry:=Registry.new();registry.set_subscribed(true)
	for index in [3,4,5]:
		check(registry.apply(Decoder.decode_packet(str(fixture.cases[index].packet).hex_decode())),"original-format-player-event-"+str(index))
	var original: Array[Dictionary]=registry.list()
	check(ids(original)==[305419896,2130706432,1],"registry-insertion-order")
	var lobby:=Lobby.new();root.add_child(lobby);await process_frame
	var state:={"phase":"character-selection","connected":true,"canSelect":true,"choices":[],"selected":null,"players":[{"id":999,"firstName":{"text":"Obsolete"}}],"lobbyPlayers":original}
	lobby.apply_state({"connection":7,"state":state})
	check(ids(lobby.lobby_players)==[305419896,2130706432,1] and lobby.keys.is_empty(),"49-3-player-map-distinct-from-playable-choices")
	var native:=NativeLobby.new();native.owner_ui=lobby
	var page: Dictionary=native.player_page_state()
	check(ids(page.players)==[305419896,2130706432,1] and int(page.players[0].id)!=999,"native-player-page-uses-only-lobbyPlayers")
	check(int(page.players[1].firstName.strRef)==2147483649 and str(page.players[1].portraitRef)=="p_male","raw-localized-name-and-portrait-reach-ui-edge")
	var legacy_state: Dictionary=state.duplicate(true);legacy_state.erase("lobbyPlayers")
	lobby.apply_state({"connection":7,"state":legacy_state})
	check(ids(native.player_page_state().players)==[999] and lobby.keys.is_empty(),"prior-Godot-player-snapshot-uses-same-page-only-when-49-3-absent")
	lobby.apply_state({"connection":7,"state":state})
	check(ids(native.player_page_state().players)==[305419896,2130706432,1],"authoritative-49-3-resumes-precedence-over-prior-input")
	original[0].firstName={"text":"Mutated at source"};page.players[1].portraitRef="mutated"
	check(lobby.lobby_players[0].firstName!=original[0].firstName and str(lobby.lobby_players[1].portraitRef)=="p_male","state-and-page-projection-deep-copied")
	var duplicate: Array=registry.list();duplicate.append(duplicate[0].duplicate(true))
	check(Registry.copy_snapshot(duplicate)==null and Registry.copy_snapshot([{"id":-1}])==null,"malformed-or-duplicate-player-snapshot-rejected")
	state.lobbyPlayers=registry.list()
	lobby.apply_state({"connection":7,"state":state})
	check(ids(lobby.lobby_players)==[305419896,2130706432,1],"same-connection-full-snapshot-replaces-without-sort")
	var closed_state: Dictionary=state.duplicate(true);closed_state.phase="playing"
	lobby.apply_state({"connection":7,"state":closed_state})
	check(lobby.lobby_players.is_empty() and native.player_page_state().players.is_empty(),"lobby-close-clears-player-presentation")
	lobby.apply_state({"connection":8,"state":{"phase":"character-selection","connected":true,"canSelect":false,"choices":[]}})
	check(lobby.lobby_players.is_empty() and native.player_page_state().players.is_empty(),"reconnect-has-no-stale-player-rows")
	lobby.apply_state({"connection":8,"state":state})
	check(ids(lobby.lobby_players)==[305419896,2130706432,1],"fresh-connection-accepts-new-player-snapshot")
	lobby.close_native();check(lobby.lobby_players.is_empty(),"native-lobby-close-retires-player-snapshot")
	native.free();lobby.free();await process_frame
	if failures.is_empty():print("NWN79 lobby-player UI PASS checks=",checks," original_format_cases=3 captured_native=0")
	else:printerr("NWN79 lobby-player UI FAIL ",JSON.stringify(failures))
	quit(0 if failures.is_empty() else 1)
