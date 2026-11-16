extends SceneTree
const WindowStatus=preload("res://systems/native_data/native_inventory_window_status.gd")
const ContainerStatus=preload("res://systems/native_data/native_container_status.gd")
const Requests=preload("res://systems/native_data/native_player_requests.gd")
const World=preload("res://systems/native_data/native_network_world.gd")
const Session=preload("res://systems/native_data/native_network_session.gd")
const INVALID:=0x7f000000
const AREA:=0x80000004
const PC:=0xffffffff
const NPC:=0x80000002
class FakePeer extends RefCounted:
	var sent: Array[PackedByteArray]=[]
	var payloads: Array[PackedByteArray]=[]
	func send_game_message(bytes: PackedByteArray)->bool:sent.append(bytes.duplicate());return true
	func poll()->Dictionary:
		var ready:=payloads.duplicate();payloads.clear();return {"payloads":ready}
	func close()->void:pass

func _initialize()->void:
	var inventory_file:=ProjectSettings.globalize_path("res://../backups/animations/native-inventory-window-observations-v1.json")
	var oracle: Variant=JSON.parse_string(FileAccess.get_file_as_string(inventory_file))
	if not oracle is Dictionary or oracle.get("cases",[]).size()!=96:fail("original 13/1 oracle unavailable");return
	for row in oracle.cases:
		var bytes:=str(row.packet).hex_decode()
		var decoded: Dictionary=WindowStatus.decode_packet(bytes)
		if decoded.get("kind")!="inventory-window-status" or bool(decoded.open)!=(int(row.case.open)!=0) or int(decoded.ownerId)!=int(row.case.ownerId):fail("original 13/1 packet differs");return
		if not WindowStatus.decode_packet(bytes.slice(0,bytes.size()-1)).has("error"):fail("truncated 13/1 packet admitted");return
	var container_file:=ProjectSettings.globalize_path("res://../backups/animations/native-network-container-observations.json")
	var container_oracle: Variant=JSON.parse_string(FileAccess.get_file_as_string(container_file))
	if not container_oracle is Dictionary:fail("original 25/1 oracle unavailable");return
	var status_cases:=0
	for row in container_oracle.cases:
		if row.kind!="status":continue
		status_cases+=1
		var bytes:=str(row.packet).hex_decode()
		var decoded: Dictionary=ContainerStatus.decode_packet(bytes)
		var expected_id:=int(row.targetId) if int(row.targetId)==INVALID else int(row.targetId)|0x80000000
		if decoded.get("kind")!="container-status" or int(decoded.targetId)!=expected_id or bool(decoded.primary)!=(int(row.primary)!=0):fail("original 25/1 packet differs");return
		if not ContainerStatus.decode_packet(bytes.slice(0,bytes.size()-1)).has("error"):fail("truncated 25/1 packet admitted");return
	if status_cases!=16 or ContainerStatus.request("next").bytes!=PackedByteArray([112,25,2]) or ContainerStatus.request("previous").bytes!=PackedByteArray([112,25,3]) or ContainerStatus.request("close",NPC).bytes!="7019010b0000000200008065".hex_decode():fail("original container senders differ");return
	var world:=World.new();world.area_id=AREA;world.local_object_id=PC
	world.registry[PC]={"id":PC,"objectType":5,"areaId":AREA,"replicationRemoved":false}
	world.registry[NPC]={"id":NPC,"objectType":5,"areaId":AREA,"replicationRemoved":false}
	world.registry[0x80000003]={"id":0x80000003,"objectType":6,"inventoryLocation":{"channel":"r","ownerId":PC}}
	world.inventories.r={"entries":[{"id":0x80000003}],"stats":{"field8c":12}}
	if not world.observe_inventory_window({"open":true,"ownerId":NPC}):fail("alternate open rejected");return
	var first: Dictionary=world.inventory_window_snapshot().alternate
	if not first.open or first.ownerId!=NPC or int(world.inventories.r.ownerId)!=NPC or int(world.registry[0x80000003].inventoryLocation.ownerId)!=NPC:fail("alternate owner did not bind received inventory");return
	world.observe_inventory_window({"open":true,"ownerId":NPC})
	if int(world.inventory_windows.alternate.serial)!=int(first.serial) or int(world.inventory_windows.alternate.receiptSerial)<=int(first.receiptSerial):fail("duplicate alternate receipt changed serial");return
	world.observe_inventory_window({"open":true,"ownerId":INVALID})
	var primary_serial:=int(world.inventory_windows.primary.serial)
	world.observe_inventory_window({"open":true,"ownerId":INVALID})
	if int(world.inventory_windows.primary.serial)<=primary_serial or int(world.inventory_windows.primary.ownerId)!=PC:fail("raw INVALID did not force primary refresh");return
	var session:=Session.new();var peer:=FakePeer.new();session.peer=peer;session.phase="playing";session.world_state=world
	var alt: Dictionary=world.inventory_windows.alternate
	if session.inventory_panel(1,NPC,"alternate",int(alt.serial),int(alt.receiptSerial)).has("error") or peer.sent.back()!=Requests.inventory_panel(1,false).bytes:fail("alternate panel request differs");return
	if session.inventory_window(false,NPC,"alternate",int(alt.serial),int(alt.receiptSerial)).has("error") or peer.sent.back()!=Requests.inventory_window(NPC,false).bytes or world.inventory_windows.alternate.open:fail("alternate close did not retire owner");return
	if not session.inventory_window(false,NPC,"alternate",int(alt.serial),int(alt.receiptSerial)).has("error") or peer.sent.size()!=2:fail("retired alternate close was sent twice");return
	world.observe_inventory_window({"open":true,"ownerId":0x80000005})
	var rejected: Dictionary=world.inventory_window_snapshot().rejected
	if rejected.is_empty() or session.inventory_window(false,0x80000005,"rejected",-1,int(rejected.receiptSerial)).has("error") or not session.inventory_window(false,0x80000005,"rejected",-1,int(rejected.receiptSerial)).has("error") or peer.sent.size()!=3:fail("rejected owner reply lifetime differs");return
	world.apply_container_status({"kind":"container-status","targetId":NPC,"primary":true})
	if not world.apply_inventory(world.registry,world.inventories,{"channel":"C","operation":"A","id":0x80000006,"x":2,"y":6,"item":{"baseItem":0}},PC) or int(world.registry[0x80000006].inventoryLocation.ownerId)!=NPC:fail("container item did not bind received owner");return
	world.apply_container_status({"kind":"container-status","targetId":0x80000007,"primary":false})
	if int(world.containers.C)!=NPC or int(world.containers.c)!=0x80000007 or world.inventories.C.entries.size()!=1:fail("alternate container changed primary view");return
	if session.container_input("next",NPC,PC).has("error") or peer.sent.back()!=ContainerStatus.request("next").bytes or not world.inventories.C.entries.is_empty():fail("container page request differs");return
	if session.container_input("close",NPC,PC).has("error") or peer.sent.back()!=ContainerStatus.request("close",NPC).bytes or int(world.containers.C)!=INVALID or not session.container_input("next",NPC,PC).has("error"):fail("container close and stale page differ");return
	var window_events: Array[Dictionary]=[]
	session.ui_message_ready.connect(func(message: Dictionary):window_events.append(message))
	peer.payloads=["500d010b000000ffffffff95".hex_decode(),"5019010b0000000100008095".hex_decode()]
	session._process(0.0)
	if session.phase!="playing" or window_events.size()!=1 or window_events[0].get("kind")!="inventory-window-status" or int(world.containers.get("C",-1))!=0x80000001 or int(world.inventory_windows.primary.receiptSerial)<1:fail("original status packets did not reach the Godot UI/world owners");return
	session.free()
	print("NWN79 Godot inventory-window protocol PASS: original13/1=96 original25/1=16 stale-owner=true")
	quit(0)

func fail(reason: String)->void:
	printerr("NWN79 Godot inventory-window protocol failed: "+reason)
	quit(1)
