extends SceneTree
const Session=preload("res://systems/native_data/native_network_session.gd")

class FakePeer extends RefCounted:
	var payloads: Array[PackedByteArray]=[]
	func poll()->Dictionary:
		var result: Dictionary={"payloads":payloads.duplicate()}
		payloads.clear()
		return result
	func close()->void:pass

func _initialize()->void:
	var fixture: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://tests/nwn79_item_caption_fixture.json"))
	if not fixture is Dictionary or not fixture.get("cases") is Array:fail("Original item-caption fixture unavailable");return
	var session=Session.new();root.add_child(session)
	var peer=FakePeer.new();session.peer=peer;session.phase="playing"
	session.world_state.area_id=9
	var production:=0
	var first: Dictionary={}
	for row in fixture.cases:
		if int(row.format)!=1:continue
		if first.is_empty():first=row
		var id:=int(row.expected.itemId)
		if not session.world_state.registry.has(id):session.world_state.registry[id]={"id":id,"objectType":6,"areaId":0x7f000000,"nativeLifetime":4,"clientKnownLifetime":4,"item":{"name":{"text":"Original"},"field2b8":0,"field2c0":""}}
		var revision: int=session.world_revision
		var lifetime: int=int(session.world_state.registry[id].nativeLifetime)
		peer.payloads.append(str(row.packet).hex_decode())
		session._process(0.0)
		var object: Dictionary=session.world_state.registry.get(id,{})
		if session.phase!="playing" or object.is_empty() or int(object.nativeLifetime)!=lifetime or int(object.item.get("field2b8",999))!=int(row.expected.mode) or str(object.item.get("field2c0",""))!=str(row.expected.text) or session.world_revision!=revision+1:
			fail("Original production 24/5 did not update current item: "+str(row.name));return
		production+=1
	if production!=36:fail("Original production item-caption coverage changed");return
	var known_id:=int(first.expected.itemId)
	var known: Dictionary=session.world_state.registry[known_id]
	var packet: PackedByteArray=str(first.packet).hex_decode()
	session.world_state.registry.erase(known_id)
	var revision: int=session.world_revision
	peer.payloads.append(packet);session._process(0.0)
	if session.world_state.registry.has(known_id) or session.world_revision!=revision:fail("Unknown caption target fabricated an item");return
	known.objectType=5;session.world_state.registry[known_id]=known
	peer.payloads.append(packet);session._process(0.0)
	if session.world_revision!=revision or int(session.world_state.registry[known_id].objectType)!=5:fail("Wrong-type caption target changed world");return
	known.objectType=6;known.item={"name":{"text":"New instance"},"field2b8":0,"field2c0":"New"};known.nativeLifetime=5;session.world_state.registry[known_id]=known
	peer.payloads.append(packet);session._process(0.0)
	if int(session.world_state.registry[known_id].nativeLifetime)!=5 or int(session.world_state.registry[known_id].item.field2b8)!=int(first.expected.mode):fail("Caption did not bind to current same-ID item lifetime");return
	var malformed: PackedByteArray=packet.duplicate();malformed.append(0)
	peer.payloads.append(malformed);session._process(0.0)
	if session.phase!="failed" or not session.error.contains("Invalid native item caption"):fail("Malformed 24/5 packet was not rejected by real session");return
	print("NWN79 item caption session PASS: original_sender_production=36 existing_item_only=true current_lifetime=true malformed_rejected=true")
	quit(0)

func fail(reason: String)->void:
	printerr("NWN79 item caption session failed: "+reason)
	quit(1)
