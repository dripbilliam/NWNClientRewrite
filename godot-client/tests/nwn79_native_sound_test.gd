extends SceneTree
const Sound=preload("res://systems/native_data/native_network_sound.gd")

func _initialize()->void:
	var parsed: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://tests/nwn79_sound_fixture.json"))
	if not parsed is Dictionary or int(parsed.get("schema",0))!=1 or not parsed.get("cases") is Array:fail("Sound oracle fixture unavailable");return
	var cases: Array=parsed.cases
	var by_minor: Dictionary={}
	var create_packet:=PackedByteArray()
	for row in cases:
		var packet: PackedByteArray=str(row.packet).hex_decode()
		var actual: Dictionary=Sound.decode_packet(packet)
		if actual.has("error") or canonical(actual)!=canonical(row.expected):fail("Sound oracle differs at "+str(row.name)+": "+str(actual.get("error","fields")));return
		var minor_key:=str(int(row.expected.minor));by_minor[minor_key]=int(by_minor.get(minor_key,0))+1
		if minor_key=="6" and create_packet.is_empty():create_packet=packet.duplicate()
		for length in range(packet.size()):
			if not Sound.decode_packet(packet.slice(0,length)).has("error"):fail("Truncated sound packet accepted at "+str(row.name)+" length "+str(length));return
		var overlong:=packet.duplicate();overlong.append_array(PackedByteArray([0,0]))
		if not Sound.decode_packet(overlong).has("error"):fail("Trailing sound bytes accepted at "+str(row.name));return
	if cases.size()!=192:fail("Sound oracle coverage changed");return
	for minor in ["2","3","4","5","6","7"]:
		if int(by_minor.get(minor,0))!=32:fail("Sound packet family missing "+minor);return
	for mutation in [PackedByteArray(),PackedByteArray([80,23,1]),PackedByteArray([80,23,8]),PackedByteArray([112,23,6])]:
		if not Sound.decode_packet(mutation).has("error"):fail("Unsupported sound envelope accepted");return
	if create_packet.size()<69 or create_packet.decode_u16(67)!=4:fail("Sound reference fixture unavailable");return
	create_packet.encode_u16(67,0xffff)
	if not Sound.decode_packet(create_packet).has("error"):fail("Unbounded sound-reference count accepted");return
	print("NWN79 Godot sound-object decoder PASS: cases=192 six_minors=32_each malformed_checked=true")
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
	printerr("NWN79 Godot sound-object decoder failed: "+reason)
	quit(1)
