extends SceneTree
const Requests=preload("res://systems/native_data/native_player_requests.gd")
const Session=preload("res://systems/native_data/native_network_session.gd")
const Rules=preload("res://systems/native_data/native_object_rules.gd")
class FakePeer extends RefCounted:
	var sent: Array[PackedByteArray]=[]
	func send_game_message(bytes: PackedByteArray)->bool:sent.append(bytes.duplicate());return true
	func close()->void:pass

func _initialize()->void:
	var oracles: Array=[
		[Requests.quick_chat(22),"70160009000000160060"],
		[Requests.associate_command(0x12345678,-19),"70061b0f00000078563412edffffff60"],
		[Requests.cancel_polymorph(0x12345678),"70061e0b0000007856341260"],
		[Requests.possess_familiar(),"700613"]]
	for row in oracles:
		if row[0].has("error") or row[0].bytes!=str(row[1]).hex_decode():fail("original quickbar sender bytes");return
	if not Requests.quick_chat(65536).has("error") or not Requests.associate_command(-1,0).has("error"):fail("invalid quickbar inputs");return
	var session:=Session.new();var peer:=FakePeer.new();session.peer=peer;session.phase="playing"
	session.world_state.area_id=0x80000001;session.world_state.local_object_id=0x80000002
	session.world_state.registry[0x80000002]={"id":0x80000002,"objectType":5,"areaId":0x80000001,"replicationRemoved":false}
	session.world_state.registry[0x80000003]={"id":0x80000003,"objectType":5,"areaId":0x80000001,"replicationRemoved":false,"replicated":{"master":0x80000002}}
	session.world_state.quickbar[0]={"type":42,"intParam":22}
	session.world_state.quickbar[1]={"type":43}
	session.world_state.quickbar[2]={"type":38}
	session.world_state.quickbar[3]={"type":39,"associateType":1,"associateId":0x80000003,"intParam":-19}
	for index in 4:
		if session.quickbar_activate({"index":index,"actorId":0x80000002}).has("error"):fail("quickbar dispatch "+str(index));return
	if peer.sent.size()!=4 or peer.sent[0]!=Requests.quick_chat(22).bytes or peer.sent[1]!=Requests.cancel_polymorph(0x80000002).bytes or peer.sent[2]!=Requests.possess_familiar().bytes or peer.sent[3]!=Requests.associate_command(0x80000003,-19).bytes:fail("quickbar routed packet differs");return
	if not session.quickbar_activate({"index":3,"actorId":0x80000004}).has("error") or not session.quickbar_activate({"index":36}).has("error") or peer.sent.size()!=4:fail("stale quickbar request was sent");return
	if session.simple_native_action({"kind":"native-quickchat","quickChat":22}).has("error") or session.simple_native_action({"kind":"native-associate","targetId":0x80000003,"command":-19}).has("error") or session.simple_native_action({"kind":"native-cancel-polymorph"}).has("error") or session.simple_native_action({"kind":"native-possess"}).has("error") or peer.sent.size()!=8:fail("radial/desktop action dispatch");return
	if not session.simple_native_action({"kind":"native-associate","targetId":0x80000004,"command":-19}).has("error") or not session.simple_native_action({"kind":"native-quickchat","actorId":0x80000004,"quickChat":22}).has("error") or peer.sent.size()!=8:fail("stale desktop action was sent");return
	var rules:=Rules.new();rules.tables={"baseitems":{"orderedRows":[{"Container":"0","EquipableSlots":"0x1"},{"Container":"1","EquipableSlots":"0"}]}}
	session.object_rules=rules
	session.world_state.registry[0x80000010]={"id":0x80000010,"objectType":6,"areaId":0x80000001,"replicationRemoved":false,"item":{"baseItem":0},"inventoryLocation":{"ownerId":0x80000002,"channel":"R"}}
	session.world_state.registry[0x80000011]={"id":0x80000011,"objectType":6,"areaId":0x80000001,"replicationRemoved":false,"item":{"baseItem":1},"inventoryLocation":{"ownerId":0x80000002,"channel":"R"}}
	session.world_state.quickbar[4]={"type":1,"itemId":0x80000010,"secondaryItemId":Requests.INVALID,"intParam":255}
	session.world_state.quickbar[5]={"type":1,"itemId":0x80000011,"secondaryItemId":Requests.INVALID,"intParam":255}
	if session.quickbar_activate({"index":4}).has("error") or session.quickbar_activate({"index":5}).has("error") or peer.sent.size()!=10 or peer.sent[8]!=Requests.item_toggle(0x80000010).bytes or peer.sent[9]!=Requests.use_object(0x80000011,false).bytes:fail("item shortcut dispatch");return
	session.free()
	print("NWN79 Godot quickbar activation PASS")
	quit(0)

func fail(stage: String)->void:
	printerr("NWN79 Godot quickbar activation failed: "+stage)
	quit(1)
