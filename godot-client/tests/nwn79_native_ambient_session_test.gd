extends SceneTree
const Session=preload("res://systems/native_data/native_network_session.gd")

class FakePeer extends RefCounted:
	var payloads: Array=[]
	func poll()->Dictionary:
		var result:={"payloads":payloads.duplicate()};payloads.clear();return result
	func close()->void:pass

func _initialize()->void:
	var fixture: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://tests/nwn79_ambient_fixture.json"))
	if not fixture is Dictionary or not fixture.get("cases") is Array:fail("Ambient oracle unavailable");return
	var selected: Dictionary={}
	for row in fixture.cases:
		var operation:=int(row.expected.operation)
		if not selected.has(operation):selected[operation]=row
	if selected.size()!=8:fail("Eight ambient operations unavailable");return
	var session:=Session.new();root.add_child(session)
	var peer:=FakePeer.new();session.peer=peer;session.phase="playing"
	var received: Array[Dictionary]=[]
	session.ambient_command_ready.connect(func(command: Dictionary):received.append(command.duplicate(true)))
	var revision:=session.world_revision
	for operation in range(1,9):
		peer.payloads=[str(selected[operation].packet).hex_decode()]
		session._process(0.0)
		if session.phase!="playing" or received.size()!=operation or int(received[-1].operation)!=operation:fail("Ambient command not delivered in packet order: "+str(operation));return
	if session.world_revision!=revision:fail("Presentation-only ambient command mutated canonical world revision");return
	var bad: PackedByteArray=str(selected[1].packet).hex_decode()
	bad.append(0)
	peer.payloads=[bad];session._process(0.0)
	if session.phase!="failed" or received.size()!=8 or not session.error.contains("Invalid native ambient command"):fail("Malformed ambient command was not rejected before presentation");return
	if not session.world_state.registry.is_empty():fail("Failed session retained world state");return
	print("NWN79 Godot ambient session PASS: eight received operations ordered, no canonical revision, malformed packet fails closed")
	quit(0)

func fail(reason: String)->void:
	printerr("NWN79 Godot ambient session failed: "+reason)
	quit(1)
