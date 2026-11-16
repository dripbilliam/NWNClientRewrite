extends SceneTree
const Permission=preload("res://systems/native_data/native_network_dm_permission.gd")

func _initialize()->void:
	var parsed: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://tests/nwn79_dm_permission_fixture.json"))
	if not parsed is Dictionary or int(parsed.get("schema",0))!=1 or not parsed.get("cases") is Array:fail("DM permission oracle fixture unavailable");return
	var cases: Array=parsed.cases
	var origins: Dictionary={}
	var saw_true:=false
	var saw_false:=false
	var saw_minimum:=false
	var saw_maximum:=false
	for row in cases:
		var packet: PackedByteArray=str(row.packet).hex_decode()
		var actual: Dictionary=Permission.decode_packet(packet)
		if actual.has("error") or canonical(actual)!=canonical(row.expected):fail("DM permission oracle differs at "+str(row.name)+": "+str(actual.get("error","fields")));return
		origins[str(row.origin)]=int(origins.get(str(row.origin),0))+1
		saw_true=saw_true or int(actual.permission)==1;saw_false=saw_false or int(actual.permission)==0
		saw_minimum=saw_minimum or int(actual.parameter)==-2147483648;saw_maximum=saw_maximum or int(actual.parameter)==2147483647
		if actual.has("actorId") or actual.has("skillOverride") or actual.has("dmRole") or actual.has("areaId"):
			fail("Permission decoder invented actor, skill, or role authority");return
		for length in range(packet.size()):
			if not Permission.decode_packet(packet.slice(0,length)).has("error"):fail("Truncated DM permission packet accepted at "+str(row.name)+" length "+str(length));return
		var overlong:=packet.duplicate();overlong.append_array(PackedByteArray([0,0]))
		if not Permission.decode_packet(overlong).has("error"):fail("Trailing DM permission bytes accepted at "+str(row.name));return
	if cases.size()!=96 or int(origins.get("authored original-format writer checked against original native receiver observation",0))!=96 or int(parsed.get("capturedNative",-1))!=0 or int(parsed.get("originalReceiver",-1))!=96 or int(parsed.get("originalWriter",-1))!=0 or int(parsed.get("authoredWriter",-1))!=96 or not saw_true or not saw_false or not saw_minimum or not saw_maximum:
		fail("DM permission provenance or scalar coverage changed");return
	for mutation in [PackedByteArray(),PackedByteArray([80,31,22]),PackedByteArray([80,31,21,7,0,0,0,0]),PackedByteArray([80,30,22,7,0,0,0,0]),PackedByteArray([112,31,22,7,0,0,0,0])]:
		if not Permission.decode_packet(mutation).has("error"):fail("Unsupported DM permission envelope accepted");return
	print("NWN79 Godot DM permission decoder PASS: original_receiver=96 authored_writer=96 captured_native=0 malformed_checked=true")
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
	printerr("NWN79 Godot DM permission decoder failed: "+reason)
	quit(1)
