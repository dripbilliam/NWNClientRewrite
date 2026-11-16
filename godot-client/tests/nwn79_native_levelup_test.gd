extends SceneTree
const LevelUp=preload("res://systems/native_data/native_network_levelup.gd")

func _initialize()->void:
	var parsed: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://tests/nwn79_levelup_fixture.json"))
	if not parsed is Dictionary or int(parsed.get("schema",0))!=1 or not parsed.get("cases") is Array:fail("Level-up oracle fixture unavailable");return
	var cases: Array=parsed.cases
	var origins: Dictionary={}
	var bitmap_five:=PackedByteArray()
	for row in cases:
		var packet: PackedByteArray=str(row.packet).hex_decode()
		var actual: Dictionary=LevelUp.decode_packet(packet)
		if actual.has("error") or canonical(actual)!=canonical(row.expected):fail("Level-up oracle differs at "+str(row.name)+": "+str(actual.get("error","fields")));return
		origins[str(row.origin)]=int(origins.get(str(row.origin),0))+1
		if actual.has("actorId") or actual.has("level") or actual.has("experience"):
			fail("Level-up reply was conflated with authoritative character update");return
		if str(row.name)=="class-bitmap-5":bitmap_five=packet
		for length in range(packet.size()):
			if not LevelUp.decode_packet(packet.slice(0,length)).has("error"):fail("Truncated level-up packet accepted at "+str(row.name)+" length "+str(length));return
		var overlong:=packet.duplicate();overlong.append_array(PackedByteArray([0,0]))
		if not LevelUp.decode_packet(overlong).has("error"):fail("Trailing level-up bytes accepted at "+str(row.name));return
	if cases.size()!=11 or int(origins.get("authored original envelope",0))!=3 or int(origins.get("authored original-format writer",0))!=8 or int(parsed.get("capturedNative",-1))!=0 or int(parsed.get("originalReceiverWriter",-1))!=0:
		fail("Level-up fixture origin coverage changed");return
	for mutation in [PackedByteArray(),PackedByteArray([80,29]),PackedByteArray([80,29,0]),PackedByteArray([80,29,5]),PackedByteArray([80,28,1]),PackedByteArray([112,29,1]),PackedByteArray([80,29,4])]:
		if not LevelUp.decode_packet(mutation).has("error"):fail("Unsupported level-up envelope accepted");return
	if bitmap_five.size()<9:fail("Class bitmap fixture missing");return
	var impossible:=bitmap_five.duplicate();impossible[7]=6
	if not LevelUp.decode_packet(impossible).has("error"):fail("Class bitmap count overflow accepted");return
	print("NWN79 Godot level-up decoder PASS: authored_oracle=11 captured_native=0 original_receiver=0 malformed_checked=true")
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
	printerr("NWN79 Godot level-up decoder failed: "+reason)
	quit(1)
