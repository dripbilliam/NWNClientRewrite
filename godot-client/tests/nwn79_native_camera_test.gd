extends SceneTree
const Camera=preload("res://systems/native_data/native_network_camera.gd")

func _initialize()->void:
	var parsed: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://tests/nwn79_camera_fixture.json"))
	if not parsed is Dictionary or int(parsed.get("schema",0))!=1 or not parsed.get("cases") is Array:fail("Camera oracle fixture unavailable");return
	var cases: Array=parsed.cases
	var origins: Dictionary={}
	var minors: Dictionary={}
	for row in cases:
		var packet: PackedByteArray=str(row.packet).hex_decode()
		var actual: Dictionary=Camera.decode_packet(packet)
		if actual.has("error") or canonical(actual)!=canonical(row.expected):fail("Camera oracle differs at "+str(row.name)+": "+str(actual.get("error","fields")));return
		origins[str(row.origin)]=int(origins.get(str(row.origin),0))+1
		minors[int(actual.minor)]=int(minors.get(int(actual.minor),0))+1
		if actual.has("action") or actual.has("areaId") or actual.has("objectType"):
			fail("Camera command was conflated with canonical state at "+str(row.name));return
		for length in range(packet.size()):
			if not Camera.decode_packet(packet.slice(0,length)).has("error"):fail("Truncated camera packet accepted at "+str(row.name)+" length "+str(length));return
		var overlong:=packet.duplicate();overlong.append_array(PackedByteArray([0,0]))
		if not Camera.decode_packet(overlong).has("error"):fail("Trailing camera packet bytes accepted at "+str(row.name));return
	if cases.size()!=160 or int(origins.get("original native receiver/writer fixture",0))!=154 or int(origins.get("authored original-format writer",0))!=4 or int(origins.get("authored original-format empty stream",0))!=2:
		fail("Camera fixture origin coverage changed");return
	for minor in [1,2,3,4,5,6,7,8,9,10,12]:
		if int(minors.get(minor,0))<1:fail("Camera subtype missing: "+str(minor));return
	for mutation in [PackedByteArray(),PackedByteArray([80,16,11]),PackedByteArray([80,16,0,7,0,0,0,0]),PackedByteArray([80,16,11,7,0,0,0,0]),PackedByteArray([80,16,13,7,0,0,0,0]),PackedByteArray([80,17,1,7,0,0,0,0]),PackedByteArray([112,16,1,7,0,0,0,0])]:
		if not Camera.decode_packet(mutation).has("error"):fail("Unsupported camera envelope accepted");return
	print("NWN79 Godot camera decoder PASS: original_native_receiver=154 authored=6 subtypes=11 malformed_checked=true")
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
	printerr("NWN79 Godot camera decoder failed: "+reason)
	quit(1)
