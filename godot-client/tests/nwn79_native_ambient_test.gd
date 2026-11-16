extends SceneTree
const Ambient=preload("res://systems/native_data/native_network_ambient.gd")

func _initialize()->void:
	var parsed: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://tests/nwn79_ambient_fixture.json"))
	if not parsed is Dictionary or int(parsed.get("schema",0))!=1 or not parsed.get("cases") is Array:fail("Ambient oracle fixture unavailable");return
	var cases: Array=parsed.cases
	var by_minor: Dictionary={}
	for row in cases:
		var packet: PackedByteArray=str(row.packet).hex_decode()
		var actual: Dictionary=Ambient.decode_packet(packet)
		if actual.has("error") or canonical(actual)!=canonical(row.expected):fail("Ambient oracle differs at "+str(row.name)+": "+str(actual.get("error","fields")));return
		var minor_key:=str(int(row.expected.minor));by_minor[minor_key]=int(by_minor.get(minor_key,0))+1
		for length in range(packet.size()):
			if not Ambient.decode_packet(packet.slice(0,length)).has("error"):fail("Truncated ambient packet accepted at "+str(row.name)+" length "+str(length));return
		var overlong:=packet.duplicate();overlong.append_array(PackedByteArray([0,0]))
		if not Ambient.decode_packet(overlong).has("error"):fail("Trailing ambient bytes accepted at "+str(row.name));return
	if cases.size()!=128:fail("Ambient oracle coverage changed");return
	for minor in ["1","2","3","4","5","6","7","8"]:
		if int(by_minor.get(minor,0))!=16:fail("Ambient operation missing "+minor);return
	for mutation in [PackedByteArray(),PackedByteArray([80,40,0]),PackedByteArray([80,40,9]),PackedByteArray([112,40,1])]:
		if not Ambient.decode_packet(mutation).has("error"):fail("Unsupported ambient envelope accepted");return
	var invalid_boundary: PackedByteArray=str(cases[0].packet).hex_decode()
	invalid_boundary.encode_u32(3,0x7fffffff)
	if not Ambient.decode_packet(invalid_boundary).has("error"):fail("Invalid ambient fragment offset accepted");return
	print("NWN79 Godot ambient decoder PASS: cases=128 eight_minors=16_each malformed_checked=true")
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
	printerr("NWN79 Godot ambient decoder failed: "+reason)
	quit(1)
