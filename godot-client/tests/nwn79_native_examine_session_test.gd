extends SceneTree
const Session=preload("res://systems/native_data/native_network_session.gd")

class FakePeer extends RefCounted:
	var payloads: Array=[]
	func poll()->Dictionary:
		var result:={"payloads":payloads.duplicate()};payloads.clear();return result
	func close()->void:pass

func _initialize()->void:
	var fixture: Variant=JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://tests/nwn79_examine_fixture.json")))
	if not fixture is Dictionary:fail("Original examination oracle unavailable");return
	var item:=PackedByteArray();var close:=PackedByteArray();var trap:=PackedByteArray()
	for row in fixture.cases:
		if row.name=="local-network-examine-v93.json-3":item=str(row.packet).hex_decode()
		if row.name=="item-close":close=str(row.packet).hex_decode()
		if row.name=="trap-0":trap=str(row.packet).hex_decode()
	if item.is_empty() or close.is_empty() or trap.is_empty():fail("Original item/close/trap packets unavailable");return
	var session:=Session.new();root.add_child(session);var peer:=FakePeer.new();session.peer=peer;session.phase="playing";session.remote_build={"number":8193,"revision":37,"postfix":17};session.published_revision=session.world_revision
	var id:=2147484308;session.world_state.registry[id]={"id":id,"objectType":6,"item":{"identified":0,"baseItem":1}}
	var received: Array[Dictionary]=[]
	session.ui_message_ready.connect(func(message: Dictionary):received.append(message.duplicate(true)))
	peer.payloads=[item];session._process(0.0)
	if session.world_revision!=1 or received.size()!=1 or received[0].kind!="examine" or received[0].description.strRef!=64104 or session.world_state.registry[id].item.identified!=1 or session.world_state.registry[id].item.canUse!=1 or session.world_state.registry[id].item.has("description"):fail("Original item examination did not update only disclosed canonical fields");return
	peer.payloads=[item];session._process(0.0)
	if session.world_revision!=1 or received.size()!=2:fail("Duplicate examination caused redundant world publication");return
	peer.payloads=[close,trap];session._process(0.0)
	if received.size()!=4 or not received[2].close or received[3].type!="trap" or session.world_revision!=1:fail("Close/trap examination routing differed");return
	var missing:=2147489999;session.world_state.registry.erase(id);peer.payloads=[item];session._process(0.0)
	if session.world_revision!=1 or session.world_state.registry.has(missing) or session.world_state.registry.has(id) or received.size()!=5:fail("Examination fabricated an absent item");return
	session.close()
	print("NWN79 Godot examination session PASS: original item disclosure, duplicate/no-work, close/trap, absent-item restraint")
	quit(0)

func fail(reason: String)->void:
	printerr("NWN79 Godot examination session failed: "+reason)
	quit(1)
