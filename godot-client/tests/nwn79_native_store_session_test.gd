extends SceneTree
const Session=preload("res://systems/native_data/native_network_session.gd")
const Store=preload("res://systems/native_data/native_network_store.gd")

class FakePeer extends RefCounted:
	var payloads: Array=[]
	var sent: Array[PackedByteArray]=[]
	func poll()->Dictionary:
		var result:={"payloads":payloads.duplicate()};payloads.clear();return result
	func send_game_message(bytes: PackedByteArray)->bool:sent.append(bytes.duplicate());return true
	func close()->void:pass

func _initialize()->void:
	var oracle: Variant=JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://../backups/animations/native-network-store-observations.json")))
	if not oracle is Dictionary:fail("Original store fixture unavailable");return
	var open_packet:=PackedByteArray();var transaction_packet:=PackedByteArray()
	for row in oracle.cases:
		if int(row.format)!=1:continue
		if row.kind=="open" and open_packet.is_empty():open_packet=str(row.packet).hex_decode()
		if row.kind=="transaction" and transaction_packet.is_empty():transaction_packet=str(row.packet).hex_decode()
	if open_packet.is_empty() or transaction_packet.is_empty():fail("Original store server packets unavailable");return
	var session:=Session.new();root.add_child(session)
	var peer:=FakePeer.new();session.peer=peer;session.phase="playing";session.world_state.area_id=0x80000010;session.world_state.area={"id":0x80000010};session.world_state.module={"minutesPerHour":5};session.world_state.local_object_id=0x80000011;session.published_revision=session.world_revision
	var actor_id:=0x80000011;var stock_id:=0x80000012;var owned_id:=0x80000013
	session.world_state.registry[actor_id]={"id":actor_id,"objectType":5,"areaId":session.world_state.area_id,"replicationRemoved":false}
	var received: Array[Dictionary]=[]
	session.ui_message_ready.connect(func(message: Dictionary):received.append(message.duplicate(true)))
	peer.payloads=[open_packet];session._process(0.0)
	if not session.world_state.store is Dictionary or not session.world_state.store.open or session.world_state.store.generation!=1 or session.world_state.store.has("id") or not session.world_state.inventories.has("M"):fail("Original store-open did not create server-owned view");return
	var record: Dictionary={"channel":"M","operation":"A","id":stock_id,"x":0,"y":0,"item":{"cost":123,"baseItem":1}}
	if not session.world_state.apply_inventory(session.world_state.registry,session.world_state.inventories,record,actor_id):fail("Merchant stock staging failed");return
	if session.world_state.registry[stock_id].inventoryLocation.ownerId!=null:fail("Merchant stock gained a fabricated owner");return
	session.world_state.registry[owned_id]={"id":owned_id,"objectType":6,"areaId":Store.INVALID,"replicationRemoved":false,"inventoryLocation":{"channel":"R","ownerId":actor_id,"x":2,"y":3},"item":{"cost":100}}
	var snapshot: Dictionary=session.world_state.presentation(true)
	if snapshot.has("error") or not snapshot.inventory.store.open or snapshot.inventory.store.generation!=1 or snapshot.inventory.store.has("id"):fail("Store state omitted from inventory snapshot");return
	var stale: Dictionary={"storeGeneration":0,"operation":"buy","itemId":stock_id}
	if not session.store_input(stale).has("error"):fail("Old store generation admitted");return
	var buy: Dictionary=session.store_input({"storeGeneration":1,"operation":"buy","itemId":stock_id})
	if buy.has("error") or peer.sent.size()!=1 or peer.sent[0].slice(0,3)!=PackedByteArray([112,7,1]) or session.world_state.store.gold!=-1 or not session.world_state.inventories.M.entries.any(func(entry):return int(entry.id)==stock_id):fail("Buy altered server-owned item or gold");return
	if not session.store_input({"storeGeneration":1,"operation":"sell","itemId":stock_id}).has("error") or not session.store_input({"storeGeneration":1,"operation":"buy","itemId":owned_id}).has("error"):fail("Wrong ownership admitted for store action");return
	var sell: Dictionary=session.store_input({"storeGeneration":1,"operation":"sell","itemId":owned_id})
	if sell.has("error") or peer.sent.size()!=2 or peer.sent[1].slice(0,3)!=PackedByteArray([112,7,2]):fail("Owned item sell did not send");return
	var identify: Dictionary=session.store_input({"storeGeneration":1,"operation":"identify","itemId":owned_id})
	if identify.has("error") or peer.sent.size()!=4 or peer.sent[2].slice(0,3)!=PackedByteArray([112,7,7]) or peer.sent[3].slice(0,3)!=PackedByteArray([112,6,5]):fail("Identify did not follow with original examine");return
	session.world_state.inventories.M.pageCount=2
	if session.store_input({"storeGeneration":1,"operation":"page","page":1}).has("error") or session.world_state.store.page!=1 or not session.world_state.inventories.M.entries.is_empty() or peer.sent[-1].slice(0,3)!=PackedByteArray([112,7,5]):fail("Merchant page navigation differed");return
	if session.store_input({"storeGeneration":1,"operation":"panel","panel":3}).has("error") or session.world_state.store.panel!=3 or session.world_state.store.page!=0 or peer.sent[-1].slice(0,3)!=PackedByteArray([112,7,4]):fail("Merchant panel navigation differed");return
	peer.payloads=[transaction_packet];session._process(0.0)
	if received.size()!=1 or received[0].kind!="store-transaction" or received[0].has("success") or session.world_state.store.gold!=-1 or not session.world_state.store.has("lastTransaction"):fail("Transaction receipt implied success or was not presented");return
	if session.store_input({"storeGeneration":1,"operation":"close"}).has("error") or session.world_state.store.open or session.world_state.inventories.has("M") or peer.sent[-1]!=PackedByteArray([112,7,6]):fail("Local store close failed");return
	if not session.store_input({"storeGeneration":1,"operation":"buy","itemId":stock_id}).has("error"):fail("Closed store admitted input");return
	peer.payloads=[open_packet];session._process(0.0)
	if session.world_state.store.generation!=2:fail("Reopened store generation did not advance");return
	peer.payloads=[PackedByteArray([80,7,6])];session._process(0.0)
	if session.world_state.store.open or session.world_state.inventories.has("M") or received[-1].kind!="store-close":fail("Server store close was not applied");return
	session.close()
	if session.world_state.store!=null:fail("Store survived connection close");return
	print("NWN79 Godot store session PASS: native open/transaction/close, stock/owned actions, identify, navigation, stale generation, lifecycle")
	quit(0)

func fail(reason: String)->void:
	printerr("NWN79 Godot store session failed: "+reason)
	quit(1)
