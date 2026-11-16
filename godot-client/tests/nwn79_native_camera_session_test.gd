extends SceneTree
const Session=preload("res://systems/native_data/native_network_session.gd")

class FakePeer extends RefCounted:
	var payloads: Array=[]
	func poll()->Dictionary:
		var result:={"payloads":payloads.duplicate()};payloads.clear();return result
	func close()->void:pass

func _initialize()->void:
	var fixture: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://tests/nwn79_camera_fixture.json"))
	if not fixture is Dictionary or not fixture.get("cases") is Array:fail("Camera packet oracle unavailable");return
	var selected: Dictionary={}
	for row in fixture.cases:
		var kind:=str(row.expected.get("kind",""))
		if kind in ["camera-mode","camera-attach"] and not selected.has(kind):selected[kind]=row
	if selected.size()!=2:fail("Camera mode and attach packets unavailable");return
	var session:=Session.new();root.add_child(session)
	var peer:=FakePeer.new();session.peer=peer;session.phase="playing"
	var received: Array[Dictionary]=[]
	session.camera_command_ready.connect(func(message: Dictionary):received.append(message.duplicate(true)))
	var revision:=session.world_revision
	for kind in ["camera-mode","camera-attach"]:
		peer.payloads=[str(selected[kind].packet).hex_decode()]
		session._process(0.0)
		if session.phase!="playing" or received.size()<1 or str(received[-1].kind)!=kind:fail("Camera command was not routed in receipt order: "+kind);return
	if received.size()!=2 or session.world_revision!=revision:fail("Camera presentation changed canonical world state");return
	var malformed: PackedByteArray=str(selected["camera-attach"].packet).hex_decode()
	malformed.append(0)
	peer.payloads=[malformed];session._process(0.0)
	if session.phase!="failed" or received.size()!=2 or not session.error.contains("Invalid native camera command"):fail("Malformed camera packet reached presentation");return
	print("NWN79 Godot camera session PASS: mode/attach ordered, canonical state untouched, malformed packet fails closed")
	quit(0)

func fail(reason: String)->void:
	printerr("NWN79 Godot camera session failed: "+reason)
	quit(1)
