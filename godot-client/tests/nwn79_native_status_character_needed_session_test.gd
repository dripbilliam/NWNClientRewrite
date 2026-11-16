extends SceneTree
const Session=preload("res://systems/native_data/native_network_session.gd")

class FakePeer extends RefCounted:
	var payloads: Array=[]
	func poll()->Dictionary:
		var result:={"payloads":payloads.duplicate()};payloads.clear();return result
	func close()->void:pass

func _initialize()->void:
	var loading=Session.new();root.add_child(loading)
	var peer=FakePeer.new();loading.peer=peer;loading.phase="resources";loading.deadline=Time.get_ticks_msec()+10000
	var statuses: Array=[];loading.server_status_ready.connect(func(status: Dictionary):statuses.append(status.duplicate(true)))
	peer.payloads=[PackedByteArray([80,1,1])];loading._process(0.0)
	if loading.phase!="resources" or loading.server_status!="server-loading" or statuses.size()!=1 or statuses[0].kind!="server-loading":fail("Server-loading status did not preserve the resource wait");return
	peer.payloads=[PackedByteArray([80,1,2])];loading._process(0.0)
	if loading.phase!="failed" or statuses.size()!=2 or statuses[1].kind!="server-unavailable" or not loading.error.contains("unavailable"):fail("Server-unavailable did not retire admission with a retryable error");return
	var malformed=Session.new();root.add_child(malformed)
	var malformed_peer=FakePeer.new();malformed.peer=malformed_peer;malformed.phase="resources";malformed.deadline=Time.get_ticks_msec()+10000
	malformed_peer.payloads=[PackedByteArray([80,1,1,0])];malformed._process(0.0)
	if malformed.phase!="failed" or not malformed.error.contains("Invalid native server status"):fail("Malformed server status was accepted");return
	var choosing=Session.new();root.add_child(choosing)
	var choice_peer=FakePeer.new();choosing.peer=choice_peer;choosing.phase="character-loading";choosing.deadline=Time.get_ticks_msec()+10000
	var choices: Array[Dictionary]=[{"source":17,"resref":"fighter"}]
	choosing.characters=choices
	choosing.character_confirmed=true;choosing.module_information={"name":"old"};choosing.module_ready_sent=true;choosing.pending_preview={"resref":"old"}
	choosing.world_state.registry[123]={"id":123,"objectType":5}
	var needed: Array=[];choosing.character_needed_ready.connect(func(message: Dictionary):needed.append(message.duplicate(true)))
	choice_peer.payloads=[PackedByteArray([80,2,16])];choosing._process(0.0)
	if choosing.phase!="character-selection" or needed.size()!=1 or needed[0].kind!="character-needed" or choosing.character_confirmed or choosing.module_ready_sent or not choosing.module_information.is_empty() or not choosing.pending_preview.is_empty() or not choosing.world_state.registry.is_empty() or choosing.characters.size()!=1:fail("Character-needed did not restore an unconfirmed selection without replaying the choice");return
	choice_peer.payloads=[PackedByteArray([80,2,16,0])];choosing.phase="character-loading";choosing._process(0.0)
	if choosing.phase!="failed" or not choosing.error.contains("Invalid native character-needed"):fail("Malformed character-needed was accepted");return
	print("NWN79 Godot status/character-needed session PASS: resource wait, unavailable, chooser reset and malformed rejection")
	quit(0)

func fail(reason: String)->void:
	printerr("NWN79 Godot status/character-needed session failed: "+reason)
	quit(1)
