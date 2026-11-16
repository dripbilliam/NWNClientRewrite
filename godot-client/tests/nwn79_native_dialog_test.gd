extends SceneTree
const Dialog=preload("res://systems/native_data/native_network_dialog.gd")
const Requests=preload("res://systems/native_data/native_player_requests.gd")
const Session=preload("res://systems/native_data/native_network_session.gd")
class FakePeer extends RefCounted:
	var sent: Array[PackedByteArray]=[]
	func close()->void:pass
	func send_game_message(bytes: PackedByteArray)->bool:sent.append(bytes.duplicate());return true

func _initialize()->void:
	var root:=ProjectSettings.globalize_path("res://../backups/animations/")
	var fixture: Variant=JSON.parse_string(FileAccess.get_file_as_string(root+"native-network-dialog-reply-observations.json"))
	if not fixture is Dictionary:fail("Original dialog-reply oracle unavailable");return
	var checked:=0
	for row in fixture.cases:
		var sample: Dictionary=row.case
		if int(sample.get("format",-1))!=1:continue
		var actual: Dictionary=Requests.dialog_reply(int(sample.ownerId),int(sample.entryId),int(sample.replyId),bool(sample.abort))
		var expected: PackedByteArray=str(row.packet).hex_decode()
		if actual.has("error") or actual.bytes.size()!=expected.size() or actual.bytes.slice(0,-1)!=expected.slice(0,-1) or (int(actual.bytes[-1])&0xe0)!=(int(expected[-1])&0xe0):fail("Original dialog-reply sender differs at case "+str(checked));return
		checked+=1
	var capture: Variant=JSON.parse_string(FileAccess.get_file_as_string(root+"local-network-renderer-v11.json"))
	if not capture is Dictionary:fail("Original server dialog capture unavailable");return
	var messages: Array=[]
	for hex in capture.wireMessages:
		var bytes: PackedByteArray=str(hex).hex_decode()
		if bytes.size()<3 or bytes[1]!=20:continue
		var parsed: Dictionary=Dialog.decode_packet(bytes)
		if parsed.has("error"):fail("Original server dialog failed to decode: "+str(parsed.error));return
		messages.append(parsed)
	if messages.size()<2 or messages[0].get("kind")!="dialog-entry" or int(messages[0].get("ownerId",-1))!=0x80000013 or int(messages[0].get("speakerId",-1))!=0x80000013 or messages[0].get("text")!={"gender":0,"strRef":57795} or messages[1].get("kind")!="dialog-replies" or int(messages[1].get("entryId",-1))!=32 or int(messages[1].get("firstCount",-1))!=1 or messages[1].get("replies")!=[{"text":{"text":""},"id":0}]:fail("Original server dialog IDs, text or replies changed");return
	var session:=Session.new();var peer:=FakePeer.new();session.peer=peer;session.phase="playing";session.world_state.area_id=0x80000001;session.world_state.local_object_id=0x80000002
	session.world_state.registry[0x80000002]={"id":0x80000002,"objectType":5,"areaId":0x80000001,"replicationRemoved":false}
	session.current_dialog=messages[0].duplicate(true);session.current_dialog.replies=messages[1].duplicate(true)
	if session.reply_dialog({"entryId":32,"replyId":0,"abort":false}).has("error") or peer.sent.size()!=1 or peer.sent[0]!=Requests.dialog_reply(0x80000013,32,0,false).bytes:fail("Godot session did not send offered original reply");return
	if not session.reply_dialog({"entryId":31,"replyId":0}).has("error") or not session.reply_dialog({"entryId":32,"replyId":17}).has("error") or peer.sent.size()!=1:fail("Godot session sent a stale or unoffered reply");return
	session.close();session.free()
	if checked<20:fail("Original dialog-reply coverage is incomplete");return
	print("NWN79 Godot dialog PASS: sender_cases=",checked," server_messages=",messages.size())
	quit(0)

func fail(reason: String)->void:
	printerr("NWN79 Godot dialog failed: "+reason)
	quit(1)
