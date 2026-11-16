extends SceneTree
const Adapter=preload("res://systems/native_data/native_module_pause_state.gd")
const Decoder=preload("res://systems/native_data/native_network_module_pause.gd")

func _initialize()->void:
	var fixture: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://tests/nwn79_module_pause_fixture.json"))
	if not fixture is Dictionary or int(fixture.get("schema",0))!=1 or int(fixture.get("nativeReceiver",-1))!=96 or not fixture.get("cases") is Array:
		fail("Original module-pause fixture unavailable");return
	var adapter=Adapter.new()
	if not adapter.begin_connection(7,88,1):fail("Could not scope connection");return
	var previous: Dictionary={};var duplicates:=0;var values: Dictionary={};var masks: Dictionary={}
	for row in fixture.cases:
		var message: Dictionary=Decoder.decode_packet(str(row.packet).hex_decode())
		if message.has("error"):fail("Original pause packet failed decode: "+str(row.name));return
		var result: Dictionary=adapter.apply(message,7,88,1)
		if not result.get("accepted",false):fail("Original pause message rejected: "+str(row.name));return
		if int(result.deliveryOrder)!=int(adapter.snapshot().deliveryOrder) or result.clockEvent.type!="module-pause-state" or int(result.clockEvent.mask)!=int(row.expected.mask) or int(result.clockEvent.value)!=int(row.expected.value) or ids(result.clockEvent.exclusionIds)!=ids(row.expected.exclusionIds):
			fail("Clock service event differs: "+str(row.name));return
		var same:=not previous.is_empty() and int(previous.mask)==int(message.mask) and int(previous.value)==int(message.value) and ids(previous.exclusionIds)==ids(message.exclusionIds)
		if result["duplicate"]!=same:fail("Duplicate pause packet ordering changed");return
		if same:duplicates+=1
		previous=message;values[int(message.value)]=true;masks[int(message.mask)]=true
	if duplicates<1 or not values.has(0) or not values.has(1) or not masks.has(1) or not masks.has(2):fail("Pause/unpause/mask fixture coverage changed");return
	var count: int=adapter.delivery_order
	var latest: Dictionary=Decoder.decode_packet(str(fixture.cases[4].packet).hex_decode())
	if adapter.apply(latest,8,88,1).get("accepted",false) or adapter.apply(latest,7,87,1).get("accepted",false) or adapter.apply(latest,7,88,0).get("accepted",false) or adapter.delivery_order!=count:
		fail("Stale connection/area affected pause order");return
	if not adapter.set_area(89,2) or adapter.apply(latest,7,88,1).get("accepted",false) or not adapter.apply(latest,7,89,2).get("accepted",false):fail("Area transition scope failed");return
	var raw: Array=latest.exclusionIds
	var copied: Dictionary=adapter.apply(latest,7,89,2)
	if not copied.get("accepted",false) or not copied["duplicate"]:fail("Repeated native packet was discarded");return
	if not copied.clockEvent.exclusionIds.is_empty():copied.clockEvent.exclusionIds[0]=123456
	if not raw.is_empty() and int(adapter.snapshot().last.exclusionIds[0])!=int(raw[0]):fail("Adapter exposed owned pause exclusions");return
	var bad: Dictionary=latest.duplicate(true);bad.mask=4
	if adapter.apply(bad,7,89,2).get("accepted",false):fail("Invalid pause mask accepted");return
	bad=latest.duplicate(true);bad.exclusionIds=[4294967296]
	if adapter.apply(bad,7,89,2).get("accepted",false):fail("Invalid exclusion ID accepted");return
	adapter.reset()
	if adapter.snapshot().connection!=-1 or adapter.apply(latest,7,89,2).get("accepted",false):fail("Reconnect reset retained stale pause scope");return
	if not adapter.begin_connection(8,88,1) or not adapter.apply(latest,8,88,1).get("accepted",false) or adapter.delivery_order!=1:fail("Fresh connection pause admission failed");return
	print("NWN79 Godot module-pause adapter PASS: original_receiver=96 duplicate_order=true area_reconnect=true clock_event=true")
	quit(0)

func ids(values: Array)->Array:
	var result: Array=[]
	for value in values:result.append(int(value))
	return result

func fail(reason: String)->void:
	printerr("NWN79 Godot module-pause adapter failed: "+reason)
	quit(1)
