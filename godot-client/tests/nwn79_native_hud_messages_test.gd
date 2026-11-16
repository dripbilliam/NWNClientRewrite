extends SceneTree
const Hud=preload("res://systems/native_data/native_network_hud.gd")

func _initialize()->void:
	var parsed: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://tests/nwn79_hud_messages_fixture.json"))
	if not parsed is Dictionary or int(parsed.get("schema",0))!=1 or not parsed.get("cases") is Array:fail("HUD oracle fixture unavailable");return
	var cases: Array=parsed.cases
	var origins: Dictionary={}
	for row in cases:
		var packet: PackedByteArray=str(row.packet).hex_decode()
		var expected: Dictionary=row.expected
		var actual: Dictionary=Hud.decode_packet(packet)
		if actual.has("error") or canonical(actual)!=canonical(expected):fail("HUD oracle differs at "+str(row.name)+": "+str(actual.get("error","fields")));return
		origins[str(row.origin)]=int(origins.get(str(row.origin),0))+1
		if not Hud.decode_packet(packet.slice(0,-1)).has("error"):fail("Truncated HUD packet accepted at "+str(row.name));return
		var overlong:=packet.duplicate();overlong.append_array(PackedByteArray([0,0]))
		if not Hud.decode_packet(overlong).has("error"):fail("Trailing HUD bytes accepted at "+str(row.name));return
	if cases.size()!=32 or int(origins.get("authored original-format writer",0))!=21 or int(origins.get("captured native packet",0))!=3 or int(origins.get("original native receiver fixture",0))!=8:fail("HUD fixture coverage changed");return
	for mutation in [PackedByteArray(),PackedByteArray([80,28,11]),PackedByteArray([80,99,1]),PackedByteArray([112,28,1])]:
		if not Hud.decode_packet(mutation).has("error"):fail("Unsupported HUD envelope accepted");return
	var full: PackedByteArray=PackedByteArray()
	for row in cases:
		if str(row.name)=="journal-full":full=str(row.packet).hex_decode();break
	if full.size()<12:fail("Full journal fixture unavailable");return
	full.encode_s32(7,0x7fffffff)
	if not Hud.decode_packet(full).has("error"):fail("Unbounded journal entry count accepted");return
	full.encode_s32(7,-1)
	if not Hud.decode_packet(full).has("error"):fail("Negative journal entry count accepted");return
	print("NWN79 Godot HUD decoder PASS: authored=21 captured_journal=3 original_map_pin=8 malformed_checked=true")
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
	printerr("NWN79 Godot HUD decoder failed: "+reason)
	quit(1)
