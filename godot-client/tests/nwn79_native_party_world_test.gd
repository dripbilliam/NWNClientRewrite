extends SceneTree
const World=preload("res://systems/native_data/native_network_world.gd")
const Session=preload("res://systems/native_data/native_network_session.gd")

class FakePeer extends RefCounted:
	var payloads: Array=[]
	func poll()->Dictionary:
		var result:={"payloads":payloads.duplicate()};payloads.clear();return result
	func close()->void:pass

func _initialize()->void:
	var world:=World.new();var a:=0x80000011;var b:=0x80000012
	if not world.apply_party({"kind":"party-list","operation":"all","ids":[a,b]}) or not world.apply_party({"kind":"party-list","operation":"all","ids":[b,a]}) or ids(world.party)!=[a,b]:fail("Full party list changed physical order");return
	world.apply_party({"kind":"party-list","operation":"add","ids":[World.INVALID,World.INVALID,0]})
	if ids(world.party)!=[a,b,World.INVALID,World.INVALID,0] or not world.registry.is_empty():fail("Party IDs fabricated proxies or collapsed INVALID duplicates");return
	world.apply_party({"kind":"party-list","operation":"remove","ids":[a,0]})
	if ids(world.party)!=[b,World.INVALID,World.INVALID,0]:fail("Party remove/sweep semantics differ");return
	world.apply_party({"kind":"party-list","operation":"all","ids":[b]})
	if ids(world.party)!=[b,0]:fail("Full party sweep failed to retain ID zero");return
	world.apply_party({"kind":"party-invite-notice","name":"Arelith"});world.apply_party({"kind":"party-invite-notice","name":"Café"})
	if world.party_invite_notice.serial!=2 or world.party_invite_notice.name!="Café" or world.party_list_revision!=5:fail("Party invitation serial or roster revision differs");return
	world.module={"minutesPerHour":5};world.area={"id":0x80000010};world.area_id=0x80000010
	var snapshot: Dictionary=world.presentation(true)
	if snapshot.has("error") or ids(snapshot.ui.party)!=[b,0] or snapshot.ui.partyListRevision!=5 or snapshot.ui.partyInviteNotice.serial!=2 or not world.registry.is_empty():fail("Party snapshot fabricated objects or omitted state");return
	var fixture: Variant=JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://tests/nwn79_party_fixture.json")))
	if not fixture is Dictionary:fail("Original party fixture unavailable");return
	var roster:=PackedByteArray();var invite:=PackedByteArray()
	for row in fixture.cases:
		if row.name=="native-roster-6":roster=str(row.packet).hex_decode()
		if row.name=="invitation-Arelith":invite=str(row.packet).hex_decode()
	if roster.is_empty() or invite.is_empty():fail("Original party packets unavailable");return
	var session:=Session.new();root.add_child(session);var peer:=FakePeer.new();session.peer=peer;session.phase="playing";session.published_revision=session.world_revision
	peer.payloads=[roster,invite];session._process(0.0)
	if ids(session.world_state.party)!=[0x80000065,0x80000064] or session.world_state.party_list_revision!=1 or session.world_state.party_invite_notice.name!="Arelith" or not session.world_state.registry.is_empty():fail("Original party packets did not reach world state");return
	session.close()
	if not session.world_state.party.is_empty() or session.world_state.party_invite_notice!=null:fail("Party state survived connection close");return
	print("NWN79 Godot party world PASS: physical order, sentinel duplicates, ID zero, invitation, original packet session routing, lifecycle")
	quit(0)

func ids(rows: Array)->Array:
	var result: Array=[]
	for row in rows:result.append(int(row.id))
	return result

func fail(reason: String)->void:
	printerr("NWN79 Godot party world failed: "+reason)
	quit(1)
