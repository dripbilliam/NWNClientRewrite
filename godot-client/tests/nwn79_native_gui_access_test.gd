extends SceneTree
const Access=preload("res://systems/native_data/native_network_gui_access.gd")

func _initialize()->void:
	var parsed: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://tests/nwn79_gui_access_fixture.json"))
	if not parsed is Dictionary or int(parsed.get("schema",0))!=1 or not parsed.get("cases") is Array:fail("GUI access oracle fixture unavailable");return
	var cases: Array=parsed.cases
	var origins: Dictionary={}
	var families: Dictionary={}
	var modern:=PackedByteArray()
	var popup:=PackedByteArray()
	for row in cases:
		var packet: PackedByteArray=str(row.packet).hex_decode()
		var actual: Dictionary=Access.decode_packet(packet,row.build)
		if actual.has("error") or canonical(actual)!=canonical(row.expected):fail("GUI access oracle differs at "+str(row.name)+": "+str(actual.get("error","fields")));return
		origins[str(row.origin)]=int(origins.get(str(row.origin),0))+1
		families[str(actual.major)+"/"+str(actual.minor)]=int(families.get(str(actual.major)+"/"+str(actual.minor),0))+1
		if actual.has("areaId") or actual.has("actorId") or actual.has("action"):
			fail("GUI access instruction was conflated with a local panel action");return
		if str(row.name)=="disabled-35-6-1-42":modern=packet
		if str(row.name)=="popup-6":popup=packet
		for length in range(packet.size()):
			if not Access.decode_packet(packet.slice(0,length),row.build).has("error"):fail("Truncated GUI access packet accepted at "+str(row.name)+" length "+str(length));return
		var overlong:=packet.duplicate();overlong.append_array(PackedByteArray([0,0]))
		if not Access.decode_packet(overlong,row.build).has("error"):fail("Trailing GUI access bytes accepted at "+str(row.name));return
	if cases.size()!=168 or int(origins.get("authored original-format writer",0))!=168 or int(parsed.get("capturedNative",-1))!=0 or int(parsed.get("originalReceiverWriter",-1))!=0:
		fail("GUI access fixture provenance changed");return
	if int(families.get("53/2",0))!=160 or int(families.get("36/4",0))!=8:fail("GUI access family coverage changed");return
	if modern.is_empty() or popup.is_empty():fail("Build-gate fixtures unavailable");return
	if not Access.decode_packet(modern).has("error"):fail("Modern disabled panel without build metadata accepted");return
	if Access.decode_packet(popup).has("error"):fail("Popup incorrectly requires build metadata");return
	for mutation in [PackedByteArray(),PackedByteArray([80,53,2]),PackedByteArray([80,53,1,7,0,0,0,0]),PackedByteArray([80,36,3,7,0,0,0,0]),PackedByteArray([80,36,5,7,0,0,0,0]),PackedByteArray([112,53,2,7,0,0,0,0])]:
		if not Access.decode_packet(mutation,{"number":8193,"revision":35,"postfix":0}).has("error"):fail("Unsupported GUI access envelope accepted");return
	print("NWN79 Godot GUI access decoder PASS: authored_oracle=168 captured_native=0 original_receiver=0 revision_gate=true malformed_checked=true")
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
	printerr("NWN79 Godot GUI access decoder failed: "+reason)
	quit(1)
