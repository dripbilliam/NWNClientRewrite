extends SceneTree
const Status=preload("res://systems/native_data/native_network_server_status.gd")

func _initialize()->void:
	var parsed: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://tests/nwn79_server_status_fixture.json"))
	if not parsed is Dictionary or int(parsed.get("schema",0))!=1 or not parsed.get("cases") is Array:fail("Server-status oracle fixture unavailable");return
	var cases: Array=parsed.cases
	var seen: Dictionary={}
	for row in cases:
		var packet: PackedByteArray=str(row.packet).hex_decode()
		var actual: Dictionary=Status.decode_packet(packet)
		if actual.has("error") or canonical(actual)!=canonical(row.expected):fail("Server-status oracle differs at "+str(row.name));return
		if str(row.origin)!="original native status/resource coordinator observation with synthetic module":fail("Server-status provenance changed");return
		seen[str(actual.kind)]=true
		for length in range(packet.size()):
			if not Status.decode_packet(packet.slice(0,length)).has("error"):fail("Truncated server-status packet accepted at "+str(row.name));return
		var overlong:=packet.duplicate();overlong.append(0)
		if not Status.decode_packet(overlong).has("error"):fail("Overlong server-status packet accepted at "+str(row.name));return
	if cases.size()!=2 or int(parsed.get("originalNativeStatusCoordinator",-1))!=2 or int(parsed.get("capturedNative",-1))!=0 or int(parsed.get("authoredWriter",-1))!=0 or not seen.has("server-loading") or not seen.has("server-unavailable"):
		fail("Server-status fixture coverage changed");return
	for mutation in [PackedByteArray(),PackedByteArray([80,1,0]),PackedByteArray([80,1,3]),PackedByteArray([80,2,1]),PackedByteArray([112,1,1]),PackedByteArray([80,1,1,0])]:
		if not Status.decode_packet(mutation).has("error"):fail("Unsupported server-status envelope accepted");return
	print("NWN79 Godot server-status decoder PASS: original_native_status_coordinator=2 captured_native=0 malformed_checked=true")
	quit(0)

func canonical(value: Variant)->Variant:
	if value is int or value is float:return float(value)
	if value is Dictionary:
		var dictionary: Dictionary={}
		for key in value.keys():dictionary[key]=canonical(value[key])
		return dictionary
	return value

func fail(reason: String)->void:
	printerr("NWN79 Godot server-status decoder failed: "+reason)
	quit(1)
