extends SceneTree
const Session=preload("res://systems/native_data/native_network_session.gd")
const Barter=preload("res://systems/native_data/native_network_barter.gd")

class FakePeer extends RefCounted:
	var payloads: Array=[]
	var sent: Array[PackedByteArray]=[]
	func poll()->Dictionary:
		var result:={"payloads":payloads.duplicate()};payloads.clear();return result
	func send_game_message(bytes: PackedByteArray)->bool:sent.append(bytes.duplicate());return true
	func close()->void:pass

func _initialize()->void:
	var fixture: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://tests/nwn79_barter_fixture.json"))
	if not fixture is Dictionary:fail("Barter oracle unavailable");return
	var packets: Dictionary={}
	for row in fixture.server:
		var kind:=str(row.expected.kind)
		if not packets.has(kind):packets[kind]=str(row.packet).hex_decode()
	var session:=Session.new();root.add_child(session)
	var peer:=FakePeer.new();session.peer=peer;session.phase="playing"
	var world=session.world_state;var actor_id:=int(fixture.server[0].expected.firstId);var partner_id:=int(fixture.server[0].expected.secondId)
	world.area_id=0x80000010;world.area={"id":world.area_id};world.module={"minutesPerHour":5};world.local_object_id=actor_id
	world.registry[actor_id]={"id":actor_id,"objectType":5,"areaId":world.area_id,"replicationRemoved":false}
	world.registry[partner_id]={"id":partner_id,"objectType":5,"areaId":world.area_id,"replicationRemoved":false}
	session.published_revision=session.world_revision
	var received: Array[Dictionary]=[]
	session.ui_message_ready.connect(func(message: Dictionary):received.append(message.duplicate(true)))
	peer.payloads=[packets["barter-start"]];session._process(0.0)
	if not world.barter is Dictionary or not world.barter.open or world.barter.serial!=1 or world.barter.partnerId!=partner_id or not world.barter.initiator or not world.inventories.has("A") or not world.inventories.has("B"):fail("Original start did not create an owned trade");return
	if session.barter_input({"operation":"close","serial":0,"targetId":partner_id}).get("error","")=="":fail("Stale serial admitted");return
	if session.barter_input({"operation":"start","targetId":partner_id}).has("error") or peer.sent[-1].slice(0,3)!=PackedByteArray([112,35,1]):fail("Original start request not sent");return
	var item_id:=0x80000044
	world.registry[item_id]={"id":item_id,"objectType":6,"replicationRemoved":false,"item":{"baseItem":1},"inventoryLocation":{"channel":"R","ownerId":actor_id,"x":1,"y":1}}
	world.inventories["R"]={"entries":[{"id":item_id,"x":1,"y":1}]}
	if session.barter_input({"operation":"add","serial":1,"targetId":partner_id,"itemId":item_id,"x":0,"y":0}).has("error") or peer.sent[-1].slice(0,3)!=PackedByteArray([112,35,5]) or world.registry[item_id].inventoryLocation.channel!="R":fail("Add predicted movement or failed to send");return
	if not session.barter_input({"operation":"accept","serial":1,"targetId":partner_id,"value":true}).has("error"):fail("Acceptance before both locks admitted");return
	peer.payloads=[packets["barter-lock"]];session._process(0.0)
	if received[-1].nativeBarterSerial!=1 or received[-1].nativeBarterRevision!=2 or world.barter.revision!=2:fail("Lock receipt did not carry world serial/revision");return
	var own_offer:=0x80000045
	world.registry[own_offer]={"id":own_offer,"objectType":6,"inventoryLocation":{"channel":"B","ownerId":actor_id,"x":0,"y":0},"item":{}}
	world.inventories["B"].entries.append({"id":own_offer,"x":0,"y":0})
	var other_offer:=0x80000046
	world.registry[other_offer]={"id":other_offer,"objectType":6,"inventoryLocation":{"channel":"A","ownerId":partner_id,"x":0,"y":0},"item":{}}
	world.inventories["A"].entries.append({"id":other_offer,"x":0,"y":0})
	peer.payloads=[packets["barter-close"]];session._process(0.0)
	if world.barter.open or world.inventories.has("A") or world.inventories.has("B") or world.registry[own_offer].inventoryLocation!=null or world.registry[other_offer].inventoryLocation!=null or not world.registry.has(own_offer):fail("Close did not retire offers without deleting canonical items");return
	if not session.barter_input({"operation":"add","serial":1,"targetId":partner_id,"itemId":item_id}).has("error"):fail("Closed trade admitted item action");return
	peer.payloads=[packets["barter-start"]];session._process(0.0)
	if world.barter.serial!=2:fail("New trade did not advance serial");return
	var snapshot: Dictionary=world.presentation(true)
	if snapshot.has("error") or snapshot.ui.barter.serial!=2 or not snapshot.ui.barter.open:fail("Barter state omitted from UI snapshot");return
	session.close()
	if session.world_state.barter!=null:fail("Barter state survived session close");return
	print("NWN79 Godot barter session PASS: original start/lock/close, requests, stale serial, offer retirement, snapshot, lifecycle")
	quit(0)

func fail(reason: String)->void:
	printerr("NWN79 Godot barter session failed: "+reason)
	quit(1)
