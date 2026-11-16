extends SceneTree
const Session=preload("res://systems/native_data/native_network_session.gd")
const Cui=preload("res://systems/native_data/nui_state.gd")
const CREATE="50370158000000090000000400000074657374010000003d0000007b6904726f6f747b690269645369046e65787469056c6162656c53690454657374690474797065536906627574746f6e7d690776657273696f6e69017d60"
const BINDS="5037043a0000000200000009000000050000006c6162656c0a000000536907557064617465640900000007000000656e61626c6564010000004660"
const DESTROY="5037020b0000000900000060"

class FakePeer extends RefCounted:
	var payloads: Array=[]
	var sent: Array[PackedByteArray]=[]
	func poll()->Dictionary:
		var result:={"payloads":payloads.duplicate()};payloads.clear();return result
	func send_game_message(bytes: PackedByteArray)->bool:sent.append(bytes.duplicate());return true
	func close()->void:pass

class AreaView extends Node:
	var area_id:=0x80000010
	func ready_for_admission()->bool:return true

func _initialize()->void:
	var session:=Session.new();root.add_child(session)
	var peer:=FakePeer.new();session.peer=peer;session.phase="area-presenting";session.deadline=Time.get_ticks_msec()+10000;session.catalog=RefCounted.new();session.world_state.area_id=0x80000010;session.world_state.area={"id":0x80000010};session.world_state.registry[0x80000010]={"id":0x80000010,"objectType":4,"areaId":0x80000010,"state":{},"replicationRemoved":false};session.remote_build={"number":8193,"revision":37,"postfix":17};session.published_revision=session.world_revision
	var presented: Array[Dictionary]=[]
	var area_visuals: Array[Dictionary]=[]
	session.ui_message_ready.connect(func(message: Dictionary):presented.append(message.duplicate(true)))
	session.area_visual_ready.connect(func(message: Dictionary):area_visuals.append(message.duplicate(true)))
	var area_fixture: Variant=JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://tests/nwn79_area_visuals_fixture.json")))
	var original_area_visual: Dictionary={}
	for row in area_fixture.cases:
		if row.name=="area-visual-0":original_area_visual=row;break
	if original_area_visual.is_empty():fail("Original area visual fixture unavailable");return
	peer.payloads=[CREATE.hex_decode(),BINDS.hex_decode(),str(original_area_visual.packet).hex_decode()]
	session._process(0.0)
	if session.phase!="area-presenting" or presented.size()!=0 or session.pending_nui.size()!=2 or session.nui_state.windows.size()!=1 or session.pending_area_visual.size()!=1 or not area_visuals.is_empty():fail("NUI/area admission queue/state differed");return
	var area:=AreaView.new();root.add_child(area)
	if not session.area_ready(area) or session.phase!="playing" or presented.size()!=2 or session.pending_nui.size()!=0 or area_visuals.size()!=1 or area_visuals[0].visualTransform.keys.size()!=1:fail("NUI/area visual admission presentation differed");return
	var ui_state:=Cui.new()
	for message in presented:
		if not ui_state.receive(message):fail("Existing NUI UI state rejected decoded packets");return
	var serial:=int(ui_state.windows[9].serial)
	if serial!=int(session.nui_state.windows[9].serial) or ui_state.windows[9].bindings.label!="Updated":fail("NUI UI/session state diverged");return
	var sent: Dictionary=session.nui_input({"token":9,"serial":serial,"events":[{"type":"click","element":"next","index":2,"payload":{"button":0}}]})
	if sent.has("error") or peer.sent.size()!=2 or peer.sent[1].slice(0,3)!=PackedByteArray([112,55,3]):fail("NUI event was not sent");return
	var bound: Dictionary=session.nui_input({"token":9,"serial":serial,"binds":[{"bind":"label","value":"New","index":-1}]})
	if bound.has("error") or peer.sent.size()!=3 or peer.sent[2].slice(0,3)!=PackedByteArray([112,55,4]) or session.nui_state.windows[9].bindings.label!="New":fail("NUI bind was not sent or retained");return
	peer.payloads=[DESTROY.hex_decode()];session._process(0.0)
	if presented.size()!=3 or session.nui_state.windows.has(9) or not session.nui_input({"token":9,"serial":serial,"events":[{"type":"click","element":"next"}]}).has("error"):fail("Retired NUI token admitted input");return
	session.world_state.registry[area.area_id]={"id":area.area_id,"objectType":4,"areaId":area.area_id,"state":{},"replicationRemoved":false}
	var hud_fixture: Variant=JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://tests/nwn79_hud_messages_fixture.json")))
	var routed_packets: Array=[]
	for row in hud_fixture.cases:
		if row.name in ["journal-quest-entry","attitude-own","timing-on"]:routed_packets.append(str(row.packet).hex_decode())
	for row in area_fixture.cases:
		if row.name in ["weather-1-1","wind-1"]:routed_packets.append(str(row.packet).hex_decode())
	if routed_packets.size()!=5:fail("Original HUD/area state fixtures unavailable");return
	peer.payloads=routed_packets;session._process(0.0)
	if session.world_revision!=5 or session.world_state.journal.entries.size()!=1 or session.world_state.player_attitudes.size()!=1 or session.world_state.timing.version!=1 or session.world_state.area.weather.type!=1 or session.world_state.area.fields.e4!=3:fail("HUD or area state was not applied by session");return
	var fixture: Variant=JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://tests/nwn79_feedback_fixture.json")))
	if not fixture is Dictionary:fail("Original combat feedback fixture unavailable");return
	var initiative: Dictionary={}
	for row in fixture.cases:
		if row.name=="initiative-0":initiative=row;break
	if initiative.is_empty():fail("Original initiative fixture unavailable");return
	peer.payloads=[str(initiative.packet).hex_decode()];session._process(0.0)
	if presented.size()!=4 or presented[3].kind!="initiative-feedback" or session.world_revision!=5:fail("Combat presentation was dropped or mutated world");return
	session.close()
	if not session.nui_state.windows.is_empty() or not session.pending_nui.is_empty():fail("NUI connection state survived close");return
	print("NWN79 Godot NUI session PASS: queued receive, UI state, event/bind send, stale token, close")
	quit(0)

func fail(reason: String)->void:
	printerr("NWN79 Godot NUI session failed: "+reason)
	quit(1)
