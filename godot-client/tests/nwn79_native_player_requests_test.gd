extends SceneTree
const Requests=preload("res://systems/native_data/native_player_requests.gd")
const Session=preload("res://systems/native_data/native_network_session.gd")
const InventoryResponse=preload("res://systems/native_data/native_inventory_response.gd")
const GffText=preload("res://systems/native_data/native_gff_text.gd")
class FakePeer extends RefCounted:
	var sent: Array[PackedByteArray]=[]
	func close()->void:pass
	func send_game_message(bytes: PackedByteArray)->bool:
		sent.append(bytes.duplicate())
		return true

func _initialize()->void:
	var path:=ProjectSettings.globalize_path("res://../backups/animations/native-network-walk-observations.json")
	var fixture: Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
	if not fixture is Dictionary:fail("Original waypoint fixture unavailable");return
	var checked:=0
	for row in fixture.cases:
		var sample: Dictionary=row.case
		if int(sample.get("format",-1))!=1:continue
		var actual: Dictionary=Requests.waypoint(int(sample.areaId),sample.point,int(sample.sequence),bool(sample.run),bool(sample.get("clientPath",false)),int(sample.get("fractional",0)),int(sample.get("targetId",Requests.INVALID)))
		var expected: PackedByteArray=str(row.packet).hex_decode()
		if actual.has("error") or actual.bytes.size()!=expected.size() or actual.bytes.slice(0,-1)!=expected.slice(0,-1) or (int(actual.bytes[-1]) & 0xf8)!=(int(expected[-1]) & 0xf8):fail("Original waypoint packet differs at case "+str(checked));return
		checked+=1
	if checked<3 or not Requests.waypoint(0x80000001,[1.0,2.0],1,true).has("error") or not Requests.waypoint(0x80000001,[INF,2.0,3.0],1,true).has("error"):fail("Native waypoint coverage or validation failed");return
	var drive_path:=ProjectSettings.globalize_path("res://../backups/animations/native-network-drive-v1.json")
	var drive_fixture: Variant=JSON.parse_string(FileAccess.get_file_as_string(drive_path))
	if not drive_fixture is Dictionary:fail("Original keyboard fixture unavailable");return
	var drive_checked:=0
	for row in drive_fixture.cases:
		var sample: Dictionary=row.case
		var kind:=str(sample.kind)
		var actual: Dictionary=Requests.drive(int(sample.areaId),sample.position,int(sample.heading),int(sample.sequence),int(sample.flags)) if kind=="drive" else Requests.abort_drive() if kind=="abort" else Requests.orientation(sample.position)
		var expected: PackedByteArray=str(row.packet).hex_decode()
		if actual.has("error") or actual.bytes.size()!=expected.size():fail("Original keyboard packet size differs at case "+str(drive_checked));return
		if kind=="abort":
			if actual.bytes!=expected:fail("Original keyboard abort packet differs");return
		else:
			var mask:=0xfe if kind=="drive" else 0xe0
			if actual.bytes.slice(0,-1)!=expected.slice(0,-1) or (int(actual.bytes[-1])&mask)!=(int(expected[-1])&mask):fail("Original keyboard packet differs at case "+str(drive_checked));return
		drive_checked+=1
	if drive_checked<10 or not Requests.drive(0x80000001,[1.0,2.0],3600,1,3).has("error") or not Requests.drive(0x80000001,[INF,2.0],0,1,3).has("error") or not Requests.orientation([2.0,0.0]).has("error"):fail("Native keyboard coverage or validation failed");return
	var target_id:=0x80000005
	var target_cases: Array=[
		[Requests.target(target_id,"examine"),"7006050b0000000500008060"],
		[Requests.target(target_id,"talk"),"7006080b0000000500008060"],
		[Requests.target(target_id,"attack"),"7006020b0000000500008060"],
		[Requests.door(target_id,true),"7006030d00000005000080150060"],
		[Requests.door(target_id,false),"7006030d00000005000080160060"],
		[Requests.use_object(target_id,true),"70060b0b00000005000080a8"],
		[Requests.use_object(target_id,false),"70060b0b00000005000080a0"]]
	for row in target_cases:
		if row[0].has("error") or row[0].bytes!=str(row[1]).hex_decode():fail("Original target-action sender differs from native byte oracle");return
	if not Requests.target(-1,"examine").has("error") or not Requests.target(target_id,"unknown").has("error") or not Requests.door(-1,true).has("error"):fail("Native target-action input validation failed");return
	var session:=Session.new();var peer:=FakePeer.new();session.peer=peer;session.phase="playing"
	session.world_state.area_id=0x80000001;session.world_state.local_object_id=0x80000002
	session.world_state.registry[0x80000002]={"id":0x80000002,"objectType":5,"areaId":0x80000001,"replicationRemoved":false}
	var first: Dictionary=session.walk_to([6.0,3.0,0.0],true)
	var second: Dictionary=session.walk_to([6.0,4.0,0.0],false)
	if first.get("sequence")!=1 or second.get("sequence")!=2 or peer.sent.size()!=2 or peer.sent[0]!=Requests.waypoint(0x80000001,[6.0,3.0,0.0],1,true).bytes:fail("Godot session did not send the original waypoint sequence");return
	session.world_state.registry[0x80000002].replicationRemoved=true
	if not session.walk_to([7.0,3.0,0.0],true).has("error") or peer.sent.size()!=2:fail("Retired controlled creature sent a waypoint");return
	if not session.keyboard_move(0x80000002,"drive",[6.0,3.0],0,3).has("error") or peer.sent.size()!=2:fail("Retired controlled creature sent a keyboard drive");return
	session.world_state.registry[0x80000002].replicationRemoved=false
	if not session.keyboard_move(0x80000003,"drive",[6.0,3.0],0,3).has("error"):fail("Old actor controlled the native keyboard");return
	var held: Dictionary=session.keyboard_move(0x80000002,"drive",[6.0,3.0],0,3,false)
	var driven: Dictionary=session.keyboard_move(0x80000002,"drive",[6.0,3.0],900,3)
	var turned: Dictionary=session.keyboard_move(0x80000002,"turn",[1.0,0.0])
	var stopped: Dictionary=session.keyboard_move(0x80000002,"stop")
	if held.get("sent")!=false or held.get("sequence")!=3 or driven.get("sent")!=true or driven.get("sequence")!=4 or turned.get("sent")!=true or stopped.get("sent")!=true or peer.sent.size()!=5 or peer.sent[2]!=Requests.drive(0x80000001,[6.0,3.0],900,4,3).bytes or peer.sent[3]!=Requests.orientation([1.0,0.0]).bytes or peer.sent[4]!=Requests.abort_drive().bytes:fail("Godot session keyboard sequencing or send differed");return
	session.world_state.registry[0x80000003]={"id":0x80000003,"objectType":5,"areaId":0x80000001,"replicationRemoved":false}
	session.world_state.registry[0x80000004]={"id":0x80000004,"objectType":10,"areaId":0x80000001,"replicationRemoved":false,"replicated":{"position":[1.0,2.0,3.0],"hasTransition":true}}
	session.world_state.registry[0x80000005]={"id":0x80000005,"objectType":9,"areaId":0x80000001,"replicationRemoved":false}
	if session.target_action(0x80000003,"conversation.start").has("error") or session.target_action(0x80000003,"combat.attack").has("error") or session.target_action(0x80000004,"door.open").has("error") or session.target_action(0x80000004,"door.close").has("error") or session.target_action(0x80000005,"object.use").has("error") or session.target_action(0x80000005,"examine").has("error"):fail("Godot session did not send native target actions");return
	if peer.sent.size()!=11 or peer.sent[5]!=Requests.target(0x80000003,"talk").bytes or peer.sent[6]!=Requests.target(0x80000003,"attack").bytes or peer.sent[7]!=Requests.door(0x80000004,true).bytes or peer.sent[8]!=Requests.door(0x80000004,false).bytes or peer.sent[9]!=Requests.use_object(0x80000005,true).bytes or peer.sent[10]!=Requests.target(0x80000005,"examine").bytes:fail("Godot target-action dispatch differs from original sender");return
	if not session.target_action(0x80000005,"combat.attack").has("error") or not session.target_action(0x80000008,"examine").has("error") or peer.sent.size()!=11:fail("Godot sent a stale or invalid target action");return
	var inventory_path:=ProjectSettings.globalize_path("res://../backups/animations/native-network-inventory-window-observations.json")
	var inventory_fixture: Variant=JSON.parse_string(FileAccess.get_file_as_string(inventory_path))
	if not inventory_fixture is Dictionary:fail("Original inventory sender fixture unavailable");return
	var inventory_checked:=0
	for row in inventory_fixture.cases:
		var sample: Dictionary=row.case
		if int(sample.get("format",-1))!=1:continue
		var actual: Dictionary=Requests.inventory_window(int(sample.ownerId),bool(sample.open)) if sample.kind=="window" else Requests.inventory_panel(int(sample.panel),bool(sample.self))
		var expected: PackedByteArray=str(row.packet).hex_decode()
		if actual.has("error") or actual.bytes.size()!=expected.size() or actual.bytes.slice(0,-1)!=expected.slice(0,-1) or (int(actual.bytes[-1])&0xf0)!=(int(expected[-1])&0xf0):fail("Original inventory GUI sender differs at case "+str(inventory_checked));return
		inventory_checked+=1
	if inventory_checked<12 or not Requests.inventory_window(-1,true).has("error") or not Requests.inventory_panel(256).has("error"):fail("Native inventory GUI sender coverage or validation failed");return
	if session.inventory_window(true).has("error") or session.inventory_panel(2).has("error") or session.inventory_window(false).has("error"):fail("Godot session did not send self-inventory requests");return
	if peer.sent.size()!=14 or peer.sent[11]!=Requests.inventory_window(0x80000002,true).bytes or peer.sent[12]!=Requests.inventory_panel(2,true).bytes or peer.sent[13]!=Requests.inventory_window(0x80000002,false).bytes:fail("Godot inventory GUI dispatch differs from original sender");return
	if not session.inventory_window(true,0x80000003).has("error") or not session.inventory_panel(2,0x80000003).has("error") or peer.sent.size()!=14:fail("Godot sent an inventory request for a stale owner");return
	var item_path:=ProjectSettings.globalize_path("res://../backups/animations/native-network-item-actions-observations.json")
	var item_fixture: Variant=JSON.parse_string(FileAccess.get_file_as_string(item_path))
	if not item_fixture is Dictionary:fail("Original item-action fixture unavailable");return
	var item_checked:=0
	for row in item_fixture.cases:
		var sample: Dictionary=row.case
		if int(sample.get("format",-1))!=1:continue
		var item_id:=int(sample.itemId);var operation:=str(sample.kind)
		var actual: Dictionary={}
		match operation:
			"equip":actual=Requests.item_equip(item_id,int(sample.destinationId),int(sample.slot))
			"drop":actual=Requests.item_drop(item_id,sample.position)
			_:actual=Requests.item_repository(item_id,operation,int(sample.destinationId),int(sample.x),int(sample.y))
		var expected: PackedByteArray=str(row.packet).hex_decode()
		var used: int=int(expected[-1])>>5
		var mask: int=(255 << (8-used)) & 255
		if actual.has("error") or actual.bytes.size()!=expected.size() or actual.bytes.slice(0,-1)!=expected.slice(0,-1) or (int(actual.bytes[-1])&mask)!=(int(expected[-1])&mask):fail("Original item-action sender differs at case "+str(item_checked));return
		item_checked+=1
	if item_checked!=115 or not Requests.item_repository(-1,"move",0x80000002).has("error") or not Requests.item_repository(0x80000002,"move",0x80000002,256).has("error") or not Requests.item_drop(0x80000002,[INF,0.0,0.0]).has("error"):fail("Native item-action fixture coverage or validation failed");return
	var toggle_path:=ProjectSettings.globalize_path("res://../backups/animations/native-network-item-toggle-observations.json")
	var toggle_fixture: Variant=JSON.parse_string(FileAccess.get_file_as_string(toggle_path))
	if not toggle_fixture is Dictionary:fail("Original equipment-toggle fixture unavailable");return
	var toggle_checked:=0
	for row in toggle_fixture.cases:
		var sample: Dictionary=row.case
		if int(sample.get("format",-1))!=1:continue
		var actual: Dictionary=Requests.item_toggle(0x80000002,int(sample.secondId))
		var expected: PackedByteArray=str(row.packet).hex_decode()
		var used: int=int(expected[-1])>>5
		var mask: int=(255 << (8-used)) & 255
		if actual.has("error") or actual.bytes.size()!=expected.size() or actual.bytes.slice(0,-1)!=expected.slice(0,-1) or (int(actual.bytes[-1])&mask)!=(int(expected[-1])&mask):fail("Original equipment-toggle sender differs at case "+str(toggle_checked));return
		toggle_checked+=1
	if toggle_checked<100 or not Requests.item_toggle(-1).has("error"):fail("Native equipment-toggle coverage or validation failed");return
	session.world_state.registry[0x80000010]={"id":0x80000010,"objectType":6,"areaId":Requests.INVALID,"replicationRemoved":false,"inventoryLocation":{"channel":"R","ownerId":0x80000002},"item":{"stackSize":4}}
	session.world_state.registry[0x80000011]={"id":0x80000011,"objectType":6,"areaId":0x80000001,"replicationRemoved":false}
	session.world_state.registry[0x80000012]={"id":0x80000012,"objectType":6,"areaId":Requests.INVALID,"replicationRemoved":false,"inventoryLocation":{"channel":"R","ownerId":0x80000003}}
	if session.item_action({"itemId":0x80000010,"operation":"equip","slot":16}).has("error") or session.item_action({"itemId":0x80000010,"operation":"split","amount":2}).has("error") or session.item_action({"itemId":0x80000011,"operation":"pickup"}).has("error"):fail("Godot session did not send admitted item actions");return
	if peer.sent.size()!=17 or peer.sent[14]!=Requests.item_equip(0x80000010,0x80000002,16).bytes or peer.sent[15]!=Requests.item_split(0x80000010,2).bytes or peer.sent[16]!=Requests.item_repository(0x80000011,"pickup",0x80000002).bytes:fail("Godot session item-action dispatch differs from original sender");return
	if not session.item_action({"itemId":0x80000012,"operation":"equip","slot":16}).has("error") or not session.item_action({"itemId":0x80000010,"operation":"split","amount":5}).has("error") or not session.item_action({"itemId":0x80000011,"operation":"drop"}).has("error") or peer.sent.size()!=17:fail("Godot sent a stale or unowned item action");return
	var result_path:=ProjectSettings.globalize_path("res://../backups/animations/native-network-item-results-observations.json")
	var result_fixture: Variant=JSON.parse_string(FileAccess.get_file_as_string(result_path))
	if not result_fixture is Dictionary:fail("Original inventory-result fixture unavailable");return
	var result_checked:=0
	for row in result_fixture.cases:
		var sample: Dictionary=row.case
		if int(sample.get("format",-1))!=1:continue
		var expected_operation:=str(sample.operation).trim_suffix("-cancel")
		var bytes: PackedByteArray=str(row.packet).hex_decode()
		var actual: Dictionary=InventoryResponse.decode_packet(bytes)
		if actual.has("error") or actual.get("kind")!="inventory-result" or actual.get("operation")!=expected_operation or actual.get("success")!=not str(sample.operation).ends_with("-cancel") or actual.get("alternate")!=bool(sample.alternate) or int(actual.get("itemId",-1))!=(int(sample.itemId) | 0x80000000 if int(sample.itemId)!=Requests.INVALID else Requests.INVALID):fail("Original inventory result differs at case "+str(result_checked));return
		if expected_operation=="equip" and int(actual.get("slot",-1))!=int(sample.slot):fail("Original equip result slot differs");return
		if not InventoryResponse.decode_packet(bytes.slice(0,-1)).has("error"):fail("Truncated inventory result was accepted");return
		result_checked+=1
	if result_checked<100:fail("Original inventory-result coverage is incomplete");return
	var chat_path:=ProjectSettings.globalize_path("res://../backups/animations/native-network-chat-input-observations.json")
	var chat_fixture: Variant=JSON.parse_string(FileAccess.get_file_as_string(chat_path))
	if not chat_fixture is Dictionary:fail("Original chat sender fixture unavailable");return
	var chat_checked:=0
	for row in chat_fixture.cases:
		if int(row.get("format",-1))!=1:continue
		var kind:=str(row.kind)
		var channel: int={"talk":1,"shout":2,"whisper":3,"party":6,"dm":14,"tell-id":4,"tell-name":4}.get(kind,-1)
		var message:=GffText.decode(str(row.textHex).hex_decode())
		var actual: Dictionary=Requests.chat(channel,message,int(row.recipient) if kind=="tell-id" else -1,str(row.recipient) if kind=="tell-name" else "")
		var expected: PackedByteArray=str(row.packet).hex_decode()
		var used: int=int(expected[-1])>>5
		var mask: int=(255 << (8-used)) & 255
		if actual.has("error") or actual.bytes.size()!=expected.size() or actual.bytes.slice(0,-1)!=expected.slice(0,-1) or (int(actual.bytes[-1])&mask)!=(int(expected[-1])&mask):fail("Original chat sender differs at case "+str(chat_checked));return
		chat_checked+=1
	if chat_checked<20 or not Requests.chat(5,"forged").has("error") or not Requests.chat(4,"hello").has("error") or not Requests.chat(1,"hello",7).has("error") or not Requests.chat(4,"hello",7,"name").has("error"):fail("Native chat coverage or validation failed");return
	session.world_state.players[7]={"name":"Remote Account"}
	if session.chat({"actorId":0x80000002,"channel":1,"text":"Godot original server"}).has("error") or session.chat({"actorId":0x80000002,"channel":4,"text":"Hello","playerId":7,"playerAccount":"Remote Account"}).has("error") or peer.sent.size()!=19 or peer.sent[17]!=Requests.chat(1,"Godot original server").bytes or peer.sent[18]!=Requests.chat(4,"Hello",7).bytes:fail("Godot session chat dispatch differs from original sender");return
	if not session.chat({"actorId":0x80000003,"channel":1,"text":"stale"}).has("error") or not session.chat({"actorId":0x80000002,"channel":4,"text":"stale","playerId":7,"playerAccount":"Different Account"}).has("error") or peer.sent.size()!=19:fail("Godot sent stale controlled-actor or Tell chat");return
	session.close();session.free()
	print("NWN79 Godot player requests PASS: waypoint_cases=",checked," keyboard_cases=",drive_checked," target_cases=",target_cases.size()," inventory_cases=",inventory_checked," item_cases=",item_checked," toggle_cases=",toggle_checked," result_cases=",result_checked," chat_cases=",chat_checked)
	quit(0)

func fail(reason: String)->void:
	printerr("NWN79 Godot waypoint request failed: "+reason)
	quit(1)
