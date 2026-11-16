extends SceneTree
const Session=preload("res://systems/native_data/native_network_session.gd")

class FakePeer extends RefCounted:
	var payloads: Array=[]
	var sent: Array[PackedByteArray]=[]
	func poll()->Dictionary:
		var result:={"payloads":payloads.duplicate()};payloads.clear();return result
	func send_game_message(bytes: PackedByteArray)->bool:sent.append(bytes.duplicate());return true
	func close()->void:pass

class Rules extends RefCounted:
	func class_info(id: int)->Variant:return {"pickDomains":false,"pickSchool":false} if id==0 else null
	func providers()->Dictionary:return {"skillCount":0}

func _initialize()->void:
	var fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/nwn79_native_levelup_sender_fixture.json"))
	var session=Session.new();root.add_child(session)
	var peer=FakePeer.new();session.peer=peer;session.phase="playing";session.object_rules=Rules.new();session.remote_build={"number":8193,"revision":36,"postfix":0}
	var world=session.world_state;world.area_id=0x80000009;world.local_object_id=0xffffffff
	world.registry[world.local_object_id]={"id":world.local_object_id,"areaId":world.area_id,"objectType":5,"replicationRemoved":false,"nativeLifetime":7,"clientKnownLifetime":8,"replicated":{"stats":{"classes":[{"id":2,"level":1}]}},"playerState":{"combat":{"canLevelUp":true},"abilities":{"base":[10,10,10,10,10,10]},"levelUp":{"skills":[],"fieldE34":255,"fieldE48":"Familiar","fieldE30":2,"fieldE38":"Animal"}}}
	session.published_revision=session.world_revision
	var meta: Dictionary={"areaId":world.area_id,"actorId":world.local_object_id,"nativeLifetime":7,"knownLifetime":8}
	var receipts: Array[Dictionary]=[]
	session.ui_message_ready.connect(func(message: Dictionary):receipts.append(message.duplicate(true)))
	if session.level_up_input({"operation":"begin","levelRequest":meta}).has("error") or peer.sent.size()!=2 or peer.sent[0].slice(0,3)!=PackedByteArray([112,21,1]) or peer.sent[1]!=PackedByteArray([112,29,4]):fail("Session did not send sheet then begin");return
	peer.payloads=["501d040800000004f2".hex_decode()];session._process(0.0)
	if receipts.size()!=1 or not receipts[0].accepted or receipts[0].operation!="begin" or receipts[0].result.available!=[true,false,false,true]:fail("Original class bitmap was not routed to UI");return
	var proposal: Dictionary=fixture.cases[0].case.duplicate(true);proposal.classId=0
	if session.level_up_input({"operation":"submit","levelRequest":meta,"token":receipts[0].result.token,"proposal":proposal}).has("error") or peer.sent[-1].slice(0,3)!=PackedByteArray([112,29,0]):fail("Session did not send original proposal");return
	peer.payloads=[PackedByteArray([80,29,1])];session._process(0.0)
	if receipts.size()!=2 or receipts[1].operation!="submit" or not receipts[1].accepted or not receipts[1].result.accepted:fail("Server acceptance did not retire submit");return
	if not session.level_up_input({"operation":"submit","levelRequest":meta,"token":receipts[0].result.token,"proposal":proposal}).has("error"):fail("Retired draft admitted repeated submit");return
	peer.payloads=[PackedByteArray([80,29,4,0])];session._process(0.0)
	if session.phase!="failed" or not session.error.contains("Invalid native level-up reply"):fail("Malformed server packet did not fail closed");return
	print("NWN79 Godot level-up session PASS: sheet/begin order, original class reply, proposal/result and malformed rejection")
	quit(0)

func fail(reason: String)->void:
	printerr("NWN79 Godot level-up session failed: "+reason)
	quit(1)
