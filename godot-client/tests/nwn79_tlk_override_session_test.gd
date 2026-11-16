extends SceneTree
const Session=preload("res://systems/native_data/native_network_session.gd")

class FakePeer extends RefCounted:
	var payloads: Array[PackedByteArray]=[]
	func poll()->Dictionary:
		var result: Dictionary={"payloads":payloads.duplicate()}
		payloads.clear();return result
	func close()->void:pass

func _initialize()->void:
	var fixture: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://tests/nwn79_runtime_52_54_fixture.json"))
	if not fixture is Dictionary or not fixture.get("cases") is Array:fail("Native TLK packet fixture unavailable");return
	var session=Session.new();root.add_child(session)
	var peer=FakePeer.new();session.peer=peer;session.phase="area-loading";session.deadline=Time.get_ticks_msec()+30000
	session.world_state.area_id=9;session.world_state.area={"id":9};session.world_state.module={"name":"fixture"}
	var emitted: Array[Dictionary]=[]
	session.ui_message_ready.connect(func(message: Dictionary):emitted.append(message.duplicate(true)))
	var expected: Dictionary={};var version:=0;var count:=0;var captured:=0;var nonempty:=0
	for row in fixture.cases:
		if int(row.expected.major)!=52:continue
		var packet: PackedByteArray=str(row.packet).hex_decode()
		peer.payloads.append(packet);session._process(0.0)
		if session.phase!="area-loading":fail("Valid native TLK override changed session phase: "+str(row.name));return
		for entry in row.expected.entries:
			var ref:=int(entry.strRef);var value:=str(entry.text)
			if value.is_empty():expected.erase(ref)
			else:expected[ref]=value
		if not row.expected.entries.is_empty():version+=1;nonempty+=1
		if session.world_state.tlk_override_version!=version or session.world_state.tlk_overrides!=expected or emitted.size()!=nonempty:
			fail("Native TLK override order/remove/empty-list diverged: "+str(row.name));return
		if str(row.origin)=="captured native packet":captured+=1
		count+=1
	if count!=13 or captured!=1 or nonempty!=11:fail("Original/captured native TLK coverage changed");return
	var header: Dictionary=session.world_state.presentation(true)
	if header.has("error") or header.ui.tlkOverrideVersion!=version or header.ui.tlkOverrides!=expected:fail("Connection TLK overrides missing from world header");return
	# Ordinary area travel retains connection overrides; only disconnect resets.
	session.world_state.area_id=10
	if session.world_state.tlk_overrides!=expected:fail("Area travel discarded connection TLK overrides");return
	var first: PackedByteArray=PackedByteArray()
	for row in fixture.cases:
		if int(row.expected.major)==52:first=str(row.packet).hex_decode();break
	var malformed: PackedByteArray=first.duplicate();malformed.append(0)
	peer.payloads.append(malformed);session._process(0.0)
	if session.phase!="failed" or not session.error.contains("Invalid native TLK override") or not session.world_state.tlk_overrides.is_empty():fail("Malformed TLK packet did not fail/reset connection");return
	print("NWN79 TLK override session PASS: server_packets=13 captured_native=1 ordered_remove_empty=true connection_reset=true")
	quit(0)

func fail(reason: String)->void:
	printerr("NWN79 TLK override session failed: "+reason)
	quit(1)
