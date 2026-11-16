extends SceneTree
const Session=preload("res://systems/native_data/native_network_session.gd")

class FakePeer extends RefCounted:
	var payloads: Array=[]
	func poll()->Dictionary:
		var result:={"payloads":payloads.duplicate()};payloads.clear();return result
	func close()->void:pass

func _initialize()->void:
	var fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/nwn79_creature_voice_fixture.json"))
	var voice: Dictionary={};var quick: Dictionary={}
	for row in fixture.cases:
		if row.expected.kind=="voice-play" and voice.is_empty():voice=row
		if row.expected.kind=="quick-chat" and quick.is_empty():quick=row
	if voice.is_empty() or quick.is_empty():fail("Original native voice oracle unavailable");return
	var session=Session.new();root.add_child(session);var peer=FakePeer.new();session.peer=peer;session.phase="playing"
	var world=session.world_state;world.area_id=0x80000009
	var id:=int(voice.expected.objectId);world.registry[id]={"id":id,"objectType":5,"areaId":world.area_id,"nativeLifetime":11,"replicationRemoved":false}
	var quick_id:=int(quick.expected.objectId);world.registry[quick_id]={"id":quick_id,"objectType":5,"areaId":world.area_id,"nativeLifetime":12,"replicationRemoved":false}
	var delivered: Array[Dictionary]=[];session.creature_voice_ready.connect(func(message: Dictionary):delivered.append(message.duplicate(true)))
	var revision: int=session.world_revision
	peer.payloads=[str(voice.packet).hex_decode(),str(quick.packet).hex_decode()];session._process(0.0)
	if delivered.size()!=2 or delivered[0].kind!="voice-play" or delivered[1].kind!="quick-chat" or session.world_revision!=revision:fail("Original voice packets changed state or order");return
	session.phase="area-presenting";session.deadline=Time.get_ticks_msec()+10000;peer.payloads=[str(quick.packet).hex_decode()];session._process(0.0)
	if delivered.size()!=2 or session.pending_creature_voice.size()!=1:fail("Pre-admission voice was delivered early");return
	world.registry[quick_id].nativeLifetime=13;session.phase="playing";session.drain_creature_voice()
	if delivered.size()!=2 or not session.pending_creature_voice.is_empty():fail("Replaced actor received queued voice");return
	var malformed: PackedByteArray=str(voice.packet).hex_decode();malformed.append(0)
	peer.payloads=[malformed];session._process(0.0)
	if session.phase!="failed" or not session.error.contains("Invalid native creature voice"):fail("Malformed original voice did not fail closed");return
	print("NWN79 Godot creature voice session PASS: original voice/quick-chat order, no state mutation, queued lifetime and malformed rejection")
	quit(0)

func fail(reason: String)->void:
	printerr("NWN79 Godot creature voice session failed: "+reason)
	quit(1)
