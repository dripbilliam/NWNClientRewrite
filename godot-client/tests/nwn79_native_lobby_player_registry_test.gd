extends SceneTree
const Registry=preload("res://systems/native_data/native_lobby_player_registry.gd")
const Decoder=preload("res://systems/native_data/native_network_lobby_player.gd")

func _initialize()->void:
	var fixture: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://tests/nwn79_lobby_player_fixture.json"))
	if not fixture is Dictionary or int(fixture.get("schema",0))!=1 or fixture.cases.size()!=9 or int(fixture.get("capturedNative",-1))!=0:
		fail("Original-format lobby-player fixture unavailable");return
	var messages: Array[Dictionary]=[]
	for row in fixture.cases:
		if str(row.origin)!="authored original-format writer checked against original-receiver JS reconstruction":fail("Lobby fixture provenance changed");return
		var decoded: Dictionary=Decoder.decode_packet(str(row.packet).hex_decode())
		if decoded.has("error"):fail("Lobby-player fixture failed decoding");return
		messages.append(decoded)
	var registry=Registry.new()
	if registry.apply(messages[3]) or not registry.list().is_empty():fail("Unsubscribed lobby accepted a player");return
	registry.set_subscribed(true)
	for index in [3,4,5]:
		if not registry.apply(messages[index]):fail("Subscribed player update rejected");return
	if not ids(registry.list())==[305419896,2130706432,1]:fail("Initial Map insertion order changed");return
	var localized: Dictionary=registry.lookup(2130706432)
	if not localized.found or int(localized.character.firstName.strRef)!=2147483649 or str(localized.character.portraitRef)!="p_male" or not localized.character.classes.is_empty():fail("Localized name/portrait/class metadata changed");return
	var source: Dictionary=messages[4].duplicate(true)
	source.character.lastName={"text":"Replaced"};source.character.classes=[{"id":42,"level":7}]
	if not registry.apply(source) or ids(registry.list())!=[305419896,2130706432,1]:fail("Upsert moved existing player");return
	source.character.lastName.text="Mutated"
	if str(registry.lookup(2130706432).character.lastName.text)!="Replaced":fail("Registry retained caller-owned nested state");return
	var returned: Array[Dictionary]=registry.list();returned[1].classes[0].level=99
	if int(registry.lookup(2130706432).character.classes[0].level)!=7:fail("Registry exposed mutable row state");return
	var remove: Dictionary=messages[0].duplicate(true);remove.character.id=305419896
	if not registry.apply(remove) or ids(registry.list())!=[2130706432,1]:fail("Removal identity/order changed");return
	if not registry.apply(messages[3]) or ids(registry.list())!=[2130706432,1,305419896]:fail("Reinserted player did not append");return
	var before: int=registry.revision
	if not registry.apply(messages[1]) or registry.revision!=before:fail("Unknown removal mutated state");return
	registry.set_subscribed(false)
	if registry.apply(remove) or ids(registry.list())!=[2130706432,1,305419896]:fail("Unsubscribe did not gate packets or preserve Map");return
	registry.set_subscribed(true)
	if not registry.apply(remove) or ids(registry.list())!=[2130706432,1]:fail("Reopened subscription failed");return
	var high: Dictionary=messages[3].duplicate(true);high.character.id=4294967295
	if not registry.apply(high) or not registry.lookup(4294967295).found or not registry.apply(messages[1]) or registry.lookup(4294967295).found:fail("Unsigned player ID roundtrip failed");return
	var malformed: Dictionary=messages[3].duplicate(true);malformed.character.classes=[{"id":256,"level":1}]
	if registry.apply(malformed):fail("Malformed class metadata was accepted");return
	var old_revision: int=registry.revision
	registry.reset()
	if registry.snapshot().subscribed or not registry.list().is_empty() or registry.revision!=old_revision+1 or registry.apply(messages[5]):fail("Disconnect/reconnect reset retained player state");return
	registry.set_subscribed(true)
	if not registry.apply(messages[5]) or ids(registry.list())!=[1]:fail("Fresh connection did not accept player");return
	print("NWN79 Godot lobby-player registry PASS: authored_writer=9 captured_native=0 map_order=true subscription_gate=true metadata=true reset=true")
	quit(0)

func ids(rows: Array[Dictionary])->Array:
	var result: Array=[]
	for row in rows:result.append(int(row.id))
	return result

func fail(reason: String)->void:
	printerr("NWN79 Godot lobby-player registry failed: "+reason)
	quit(1)
