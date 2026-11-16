extends SceneTree
const Session=preload("res://systems/native_data/native_network_session.gd")

class FakePeer extends RefCounted:
	var payloads: Array=[]
	func poll()->Dictionary:
		var result:={"payloads":payloads.duplicate()};payloads.clear();return result
	func close()->void:pass

func _initialize()->void:
	var fixture: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://tests/nwn79_sound_fixture.json"))
	if not fixture is Dictionary:fail("Original sound oracle unavailable");return
	var packets: Dictionary={}
	for row in fixture.cases:
		var operation:=int(row.expected.operation)
		if not packets.has(operation):packets[operation]=row
	var session:=Session.new();root.add_child(session);var peer:=FakePeer.new();session.peer=peer;session.phase="playing"
	var world=session.world_state;var create: Dictionary=packets[6].expected;var id:=int(create.objectId);var area_id:=int(create.areaId)
	world.area_id=area_id;world.area={"id":area_id,"sounds":[]};world.registry[area_id]={"id":area_id,"objectType":4,"state":{"sounds":[]},"replicationRemoved":false}
	var before:=session.world_revision
	peer.payloads=[str(packets[6].packet).hex_decode()];session._process(0.0)
	if session.world_revision!=before+1 or int(world.registry.get(id,{}).get("objectType",0))!=16 or world.area.sounds.size()!=1 or world.registry[area_id].state.sounds.size()!=1:fail("Original create did not register one area sound");return
	var initial_height:=float(create.sound.position[2])
	if float(world.registry[id].nativeSoundHeight)!=initial_height:fail("Initial sound height not retained");return
	for operation in [2,3,4,5]:
		peer.payloads=[str(packets[operation].packet).hex_decode()];session._process(0.0)
	if int(world.registry[id].state.fields["308"])!=0 or int(world.registry[id].state.fields["314"])!=int(packets[4].expected.volume):fail("Sound play/volume commands not applied");return
	var position: Array=packets[5].expected.position
	var expected_z: float=world.native_f32(world.native_f32(float(position[2]))+world.native_f32(initial_height))
	if world.registry[id].state.position!=[world.native_f32(float(position[0])),world.native_f32(float(position[1])),expected_z] or world.area.sounds[0].position!=world.registry[id].state.position:fail("Relative sound position or area mirror differs");return
	var revision:=session.world_revision
	peer.payloads=[str(packets[6].packet).hex_decode()];session._process(0.0)
	if session.world_revision!=revision or world.area.sounds.size()!=1:fail("Duplicate create changed world");return
	peer.payloads=[str(packets[7].packet).hex_decode()];session._process(0.0)
	if world.registry.has(id) or not world.area.sounds.is_empty() or not world.registry[area_id].state.sounds.is_empty():fail("Sound destroy did not retire area membership");return
	revision=session.world_revision;peer.payloads=[str(packets[7].packet).hex_decode()];session._process(0.0)
	if session.world_revision!=revision:fail("Missing destroy changed world");return
	var wrong: Dictionary=create.duplicate(true);wrong.areaId=area_id+1
	if world.apply_sound_object(wrong) or world.registry.has(id):fail("Wrong-area create admitted");return
	session.close()
	if not session.world_state.registry.is_empty():fail("Sound state survived connection close");return
	print("NWN79 Godot sound world PASS: original create/play/volume/move/destroy, duplicate/wrong-area restraint, lifecycle")
	quit(0)

func fail(reason: String)->void:
	printerr("NWN79 Godot sound world failed: "+reason)
	quit(1)
