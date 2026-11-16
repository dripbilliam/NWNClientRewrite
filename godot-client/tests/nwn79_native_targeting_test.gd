extends SceneTree
const Targeting=preload("res://systems/native_data/native_network_targeting.gd")

func _initialize()->void:
	var parsed: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://tests/nwn79_targeting_fixture.json"))
	if not parsed is Dictionary or int(parsed.get("schema",0))!=1 or not parsed.get("cases") is Array:fail("Targeting oracle fixture unavailable");return
	var cases: Array=parsed.cases
	var families: Dictionary={}
	var origins: Dictionary={}
	for row in cases:
		var packet: PackedByteArray=str(row.packet).hex_decode()
		var actual: Dictionary=Targeting.decode_packet(packet)
		if actual.has("error") or canonical(actual)!=canonical(row.expected):fail("Targeting oracle differs at "+str(row.name)+": "+str(actual.get("error","fields")));return
		families[str(actual.major)+"/"+str(actual.minor)]=int(families.get(str(actual.major)+"/"+str(actual.minor),0))+1
		origins[str(row.origin)]=int(origins.get(str(row.origin),0))+1
		if actual.has("areaId") or actual.has("actorId") or actual.has("targetId") or actual.has("action"):
			fail("Targeting instruction was conflated with selection/action");return
		for length in range(packet.size()):
			if not Targeting.decode_packet(packet.slice(0,length)).has("error"):fail("Truncated targeting packet accepted at "+str(row.name)+" length "+str(length));return
		var overlong:=packet.duplicate();overlong.append_array(PackedByteArray([0,0]))
		if not Targeting.decode_packet(overlong).has("error"):fail("Trailing targeting packet bytes accepted at "+str(row.name));return
	if cases.size()!=14 or int(origins.get("authored original-format writer",0))!=14 or int(parsed.get("capturedNative",-1))!=0 or int(parsed.get("originalReceiverWriter",-1))!=0:
		fail("Targeting fixture provenance changed");return
	if int(families.get("18/23",0))!=5 or int(families.get("57/1",0))!=4 or int(families.get("57/2",0))!=5:fail("Targeting family coverage changed");return
	for mutation in [PackedByteArray(),PackedByteArray([80,18,23]),PackedByteArray([80,18,22,7,0,0,0,0]),PackedByteArray([80,57,0,7,0,0,0,0]),PackedByteArray([80,57,3,7,0,0,0,0]),PackedByteArray([80,18,1,7,0,0,0,0]),PackedByteArray([112,18,23,7,0,0,0,0])]:
		if not Targeting.decode_packet(mutation).has("error"):fail("Unsupported targeting envelope accepted");return
	print("NWN79 Godot targeting decoder PASS: authored_oracle=14 captured_native=0 original_receiver=0 malformed_checked=true")
	quit(0)

func canonical(value: Variant)->Variant:
	if value is bool:return 1.0 if value else 0.0
	if value is int or value is float:return float(value)
	if value is Array:
		var array: Array=[]
		for item in value:array.append(canonical(item))
		return array
	if value is Dictionary:
		var dictionary: Dictionary={}
		for key in value.keys():dictionary[key]=canonical(value[key])
		return dictionary
	return value

func fail(reason: String)->void:
	printerr("NWN79 Godot targeting decoder failed: "+reason)
	quit(1)
