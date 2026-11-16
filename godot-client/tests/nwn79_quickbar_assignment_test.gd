extends SceneTree
const Requests=preload("res://systems/native_data/native_player_requests.gd")
const Session=preload("res://systems/native_data/native_network_session.gd")
class FakePeer extends RefCounted:
	var sent: Array[PackedByteArray]=[]
	func send_game_message(bytes: PackedByteArray)->bool:sent.append(bytes.duplicate());return true
	func close()->void:pass

func _initialize()->void:
	var samples: Array=[
		[0,{"type":0},"701e0209000000000060"],
		[1,{"type":1,"itemId":0x80000010,"intParam":255},"701e0211000000010110000080ff00000080"],
		[2,{"type":1,"itemId":0x80000010,"intParam":255,"secondaryItemId":0x80000011},"701e0215000000020110000080ff0000001100008090"],
		[3,{"type":2,"classIndex":3,"intParam":100,"metamagic":2,"domainLevel":1},"701e021000000003020364000000020160"],
		[4,{"type":42,"intParam":22},"701e020d000000042a1600000060"],
		[5,{"type":18,"commandLabel":"Hello","commandLine":"World"},"701e021b00000005120500000048656c6c6f05000000576f726c6460"],
		[6,{"type":11,"resRef":"my_icon","toolTip":"Test"},"701e0221000000060b6d795f69636f6e000000000000000000040000005465737460"],
		[7,{"type":39,"intParam":-19,"associateType":1,"associateId":0x80000020},"701e02130000000727edffffff01002000008060"],
		[8,{"type":44,"intParam":100,"domainLevel":2},"701e020e000000082c640000000260"],
		[9,{"type":29,"resRef":"spell001"},"701e0219000000091d7370656c6c303031000000000000000060"]]
	for sample in samples:
		var result: Dictionary=Requests.quickbar_assignment(int(sample[0]),sample[1])
		if result.has("error") or result.bytes!=str(sample[2]).hex_decode():fail("original shortcut packet "+str(sample[0]));return
	if not Requests.quickbar_assignment(36,{"type":0}).has("error") or not Requests.quickbar_assignment(0,{"type":1,"itemId":-1}).has("error") or not Requests.quickbar_assignment(0,{"type":49}).has("error"):fail("invalid shortcut admission");return
	var session:=Session.new();var peer:=FakePeer.new();session.peer=peer;session.phase="playing"
	session.world_state.area_id=0x80000001;session.world_state.local_object_id=0x80000002
	session.world_state.registry[0x80000002]={"id":0x80000002,"objectType":5,"areaId":0x80000001,"replicationRemoved":false}
	session.world_state.registry[0x80000010]={"id":0x80000010,"objectType":6,"areaId":0x80000001,"replicationRemoved":false,"inventoryLocation":{"ownerId":0x80000002,"channel":"R"}}
	if session.quickbar_assign({"index":4,"actorId":0x80000002,"button":{"type":42,"intParam":22}}).has("error") or session.quickbar_assign({"index":1,"actorId":0x80000002,"button":{"type":1,"itemId":0x80000010,"intParam":255}}).has("error"):fail("shortcut session send");return
	if peer.sent.size()!=2 or peer.sent[0]!=Requests.quickbar_assignment(4,{"type":42,"intParam":22}).bytes or peer.sent[1]!=Requests.quickbar_assignment(1,{"type":1,"itemId":0x80000010,"intParam":255,"secondaryItemId":Requests.INVALID}).bytes or int(session.world_state.quickbar[1].secondaryItemId)!=Requests.INVALID:fail("shortcut session packet or local layout");return
	if not session.quickbar_assign({"index":2,"actorId":0x80000003,"button":{"type":0}}).has("error") or not session.quickbar_assign({"index":2,"actorId":0x80000002,"button":{"type":1,"itemId":0x80000011,"intParam":255}}).has("error") or peer.sent.size()!=2:fail("stale shortcut sent");return
	session.free()
	print("NWN79 Godot quickbar assignment PASS: "+str(samples.size())+" original sender cases")
	quit(0)

func fail(stage: String)->void:
	printerr("NWN79 Godot quickbar assignment failed: "+stage)
	quit(1)
