extends SceneTree
const Needed=preload("res://systems/native_data/native_network_character_needed.gd")

func _initialize()->void:
	var parsed: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://tests/nwn79_character_needed_fixture.json"))
	if not parsed is Dictionary or int(parsed.get("schema",0))!=1 or not parsed.get("cases") is Array:fail("Character-needed oracle fixture unavailable");return
	var cases: Array=parsed.cases
	for row in cases:
		var packet: PackedByteArray=str(row.packet).hex_decode()
		var actual: Dictionary=Needed.decode_packet(packet)
		if actual.has("error") or canonical(actual)!=canonical(row.expected):fail("Character-needed fixture differs at "+str(row.name));return
		if str(row.origin)!="authored exact header checked against original-receiver JS reconstruction; no original native packet capture":fail("Character-needed provenance changed");return
		if actual.has("characterId") or actual.has("reason") or actual.has("characters") or actual.has("name"):
			fail("Character-needed decoder invented admission fields");return
		for length in range(packet.size()):
			if not Needed.decode_packet(packet.slice(0,length)).has("error"):fail("Truncated character-needed header accepted");return
		var overlong:=packet.duplicate();overlong.append(0)
		if not Needed.decode_packet(overlong).has("error"):fail("Overlong character-needed header accepted");return
	if cases.size()!=1 or int(parsed.get("originalNativeReceiverExecution",-1))!=0 or int(parsed.get("originalNativeWriter",-1))!=0 or int(parsed.get("capturedNative",-1))!=0 or int(parsed.get("authoredPacket",-1))!=1:
		fail("Character-needed fixture coverage changed");return
	for mutation in [PackedByteArray(),PackedByteArray([80,2,5]),PackedByteArray([80,2,18]),PackedByteArray([80,2,15]),PackedByteArray([80,3,16]),PackedByteArray([112,2,16]),PackedByteArray([80,2,16,0])]:
		if not Needed.decode_packet(mutation).has("error"):fail("Unsupported character-needed envelope accepted");return
	print("NWN79 Godot character-needed decoder PASS: authored_original_header=1 original_native_execution=0 captured_native=0 malformed_checked=true")
	quit(0)

func canonical(value: Variant)->Variant:
	if value is int or value is float:return float(value)
	if value is Dictionary:
		var dictionary: Dictionary={}
		for key in value.keys():dictionary[key]=canonical(value[key])
		return dictionary
	return value

func fail(reason: String)->void:
	printerr("NWN79 Godot character-needed decoder failed: "+reason)
	quit(1)
