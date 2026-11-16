extends SceneTree
const Session=preload("res://systems/native_data/native_network_session.gd")
const Targeting=preload("res://systems/native_data/native_network_targeting.gd")

class FakePeer extends RefCounted:
	var payloads: Array[PackedByteArray]=[]
	var sent: Array[PackedByteArray]=[]
	func poll()->Dictionary:
		var result: Dictionary={"payloads":payloads.duplicate()}
		payloads.clear();return result
	func send_game_message(packet: PackedByteArray)->bool:
		sent.append(packet.duplicate());return true
	func close()->void:pass

func _initialize()->void:
	var fixture: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://tests/nwn79_targeting_fixture.json"))
	if not fixture is Dictionary or not fixture.get("cases") is Array:fail("Original-format targeting fixture unavailable");return
	var session=Session.new();root.add_child(session)
	var peer=FakePeer.new();session.peer=peer;session.phase="playing"
	session.world_state.area_id=9;session.world_state.area={"id":9};session.world_state.module={"name":"fixture"}
	session.world_state.local_object_id=0x8000002a
	session.world_state.registry[0x8000002a]={"id":0x8000002a,"objectType":5,"areaId":9,"nativeLifetime":3,"clientKnownLifetime":3,"replicated":{}}
	var count:=0
	for row in fixture.cases:
		var prior: int=session.world_revision
		peer.payloads.append(str(row.packet).hex_decode());session._process(0.0)
		if session.phase!="playing" or session.world_revision!=prior+1:fail("Targeting instruction did not reach canonical world: "+str(row.name));return
		var expected: Dictionary=row.expected
		if expected.kind=="script-targeting":
			if int(expected.objectMask)==0 and session.world_state.script_targeting!=null:fail("Server cancel did not clear target mode");return
			if int(expected.objectMask)!=0 and (not session.world_state.script_targeting is Dictionary or int(session.world_state.script_targeting.objectMask)!=int(expected.objectMask) or int(session.world_state.script_targeting.areaId)!=9 or int(session.world_state.script_targeting.actorId)!=0x8000002a):fail("Server mode lost area/actor scope");return
		elif expected.kind=="spell-targeting-data" and not session.world_state.spell_targeting_overrides.has(int(expected.spellId)):fail("Spell override missing from canonical world");return
		elif expected.kind=="script-targeting-data" and session.world_state.script_targeting_data.get("spellId")!=expected.spellId:fail("Script preview descriptor missing");return
		count+=1
	if count!=14 or session.world_state.script_target_version!=5:fail("Original targeting family/order coverage changed");return
	var header: Dictionary=session.presentation(true)
	if header.has("error") or int(header.ui.scriptTargeting.version)!=5 or not header.ui.scriptTargetingData is Dictionary or header.ui.spellTargetingOverrides.size()!=4:fail("Targeting state was absent from actual world header");return
	var request: Dictionary={"actorId":0x8000002a,"areaId":9,"version":5,"targetId":0x8000002a,"position":[0,0,0]}
	if not session.script_target_input(request).get("sent",false) or peer.sent[-1].hex_encode()!="700625170000002a00008000000000000000000000000060":fail("Creature selection differs from original JS 112/6/37 writer");return
	if session.world_state.script_targeting!=null or not session.script_target_input(request).has("error"):fail("One-use script target mode was reused");return
	for row in fixture.cases:
		if str(row.name)=="script-mode-2":peer.payloads.append(str(row.packet).hex_decode());break
	session._process(0.0)
	request={"actorId":0x8000002a,"areaId":9,"version":6,"targetId":Targeting.INVALID,"position":[1.25,-2.5,0.5]}
	if not session.script_target_input(request).get("sent",false) or peer.sent[-1].hex_encode()!="700625170000000000007f0000a03f000020c00000003f60":fail("Ground selection differs from original JS 112/6/37 writer");return
	for row in fixture.cases:
		if str(row.name)=="script-mode-1":peer.payloads.append(str(row.packet).hex_decode());break
	session._process(0.0)
	request.version=7;request.targetId=Targeting.INVALID
	if not session.script_target_input(request).has("error"):fail("Disallowed ground target was sent");return
	request.targetId=0x8000002a;request.areaId=10
	if not session.script_target_input(request).has("error"):fail("Stale area target was sent");return
	request.areaId=9
	if not session.world_state.apply_roster({"kind":"object-control","playerId":1,"objectId":0x8000002b}) or session.world_state.script_targeting!=null or not session.script_target_input(request).has("error"):fail("Control change retained one-use target mode");return
	var malformed: PackedByteArray=str(fixture.cases[0].packet).hex_decode();malformed.append(0)
	peer.payloads.append(malformed);session._process(0.0)
	if session.phase!="failed" or not session.error.contains("Invalid native targeting instruction"):fail("Malformed targeting packet did not fail closed");return
	print("NWN79 targeting session PASS: server_packets=14 state_header=true client_6_37_oracles=2 scoped_one_use=true")
	quit(0)

func fail(reason: String)->void:
	printerr("NWN79 targeting session failed: "+reason)
	quit(1)
