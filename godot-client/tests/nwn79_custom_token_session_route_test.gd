extends SceneTree
const Session=preload("res://systems/native_data/native_network_session.gd")
const Ui=preload("res://systems/native_gameplay_ui.gd")

class FakePeer extends RefCounted:
	var payloads: Array[PackedByteArray]=[]
	func poll()->Dictionary:
		var result: Dictionary={"payloads":payloads.duplicate()}
		payloads.clear()
		return result
	func close()->void:pass

class Connection extends RefCounted:
	var value:=7
	func current()->int:return value

func _initialize()->void:call_deferred("run")

func run()->void:
	var fixture: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://tests/nwn79_custom_token_fixture.json"))
	if not fixture is Dictionary or not fixture.get("cases") is Array:fail("Original custom-token fixture unavailable");return
	var positive: PackedByteArray=packet(fixture.cases,"native-sender-936")
	var negative: PackedByteArray=packet(fixture.cases,"native-sender-912")
	var embedded: PackedByteArray=packet(fixture.cases,"native-sender-948")
	if positive.is_empty() or negative.is_empty() or embedded.is_empty():fail("Original custom-token cases unavailable");return
	var connection=Connection.new();var ui=Ui.new();ui.native_connection_query=Callable(connection,"current")
	var session=Session.new();root.add_child(session);var peer=FakePeer.new();session.peer=peer
	var kinds: Array[String]=[]
	session.ui_message_ready.connect(func(message: Dictionary):
		kinds.append(str(message.get("kind","")))
		ui.receive(message,1,connection.value))
	session.phase="area-loading";session.deadline=Time.get_ticks_msec()+30000
	peer.payloads.append_array([positive,negative,embedded]);session._process(0.0)
	if kinds!=["custom-token","custom-token","custom-token"]:fail("Original 50/1 packets lost receive order or area-loading admission");return
	var exact: Dictionary=ui.text.server_tokens.lookup_bytes(10)
	if not exact.get("found",false) or exact.bytes!=PackedByteArray([97,0,98]) or ui.text.custom_tokens.has(10) or ui.text.resolve({"text":"<CUSTOM10>"},0)!="<UNAVAILABLE TOKEN>":fail("Session route lost embedded-NUL bytes or displayed lossy token");return
	if ui.custom_token_snapshot().records.size()!=1:fail("Negative custom-token ID changed connection table");return
	connection.value=8
	if not ui.sync_custom_token_connection(8) or not ui.custom_token_snapshot().records.is_empty():fail("Connection reset retained old custom tokens");return
	peer.payloads.append(positive);session.phase="playing";session._process(0.0)
	if ui.text.resolve({"text":"<CUSTOM10>"},0)!="value":fail("Current connection token did not reach actual TalkText");return
	var malformed: PackedByteArray=positive.duplicate();malformed.append(0)
	peer.payloads.append(malformed);session._process(0.0)
	if session.phase!="failed" or not session.error.contains("Invalid native custom token"):fail("Malformed 50/1 packet was not rejected by real session");return
	ui.text.close();ui.free()
	print("NWN79 custom-token session route PASS: ordered area-loading/playing ingress, raw UI bytes, reset, malformed rejection")
	quit(0)

func packet(rows: Array,name: String)->PackedByteArray:
	for row in rows:
		if str(row.name)==name:return str(row.packet).hex_decode()
	return PackedByteArray()

func fail(reason: String)->void:
	printerr("NWN79 custom-token session route failed: "+reason)
	quit(1)
