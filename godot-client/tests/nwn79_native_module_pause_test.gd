extends SceneTree
const Pause=preload("res://systems/native_data/native_network_module_pause.gd")

func _initialize()->void:
	var parsed: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://tests/nwn79_module_pause_fixture.json"))
	if not parsed is Dictionary or int(parsed.get("schema",0))!=1 or not parsed.get("cases") is Array:fail("Module-pause oracle fixture unavailable");return
	var cases: Array=parsed.cases
	var origins: Dictionary={};var masks: Dictionary={};var values: Dictionary={};var repeated_ids:=false
	for row in cases:
		var packet: PackedByteArray=str(row.packet).hex_decode()
		var actual: Dictionary=Pause.decode_packet(packet)
		if actual.has("error") or canonical(actual)!=canonical(row.expected):fail("Module-pause oracle differs at "+str(row.name)+": "+str(actual.get("error","fields")));return
		origins[str(row.origin)]=int(origins.get(str(row.origin),0))+1
		masks[int(actual.mask)]=true;values[int(actual.value)]=true
		var ids: Array=actual.exclusionIds
		for i in range(1,ids.size()):
			if ids[i]==ids[i-1]:repeated_ids=true
		for length in range(packet.size()):
			if not Pause.decode_packet(packet.slice(0,length)).has("error"):fail("Truncated module-pause packet accepted at "+str(row.name)+" length "+str(length));return
		var overlong:=packet.duplicate();overlong.append_array(PackedByteArray([0,0]))
		if not Pause.decode_packet(overlong).has("error"):fail("Trailing module-pause bytes accepted at "+str(row.name));return
	if cases.size()!=104 or int(parsed.get("nativeReceiver",-1))!=96 or int(parsed.get("authoredWriter",-1))!=104 or int(parsed.get("skippedOverflow",-1))!=192 or int(parsed.get("skippedNonWire",-1))!=96 or int(origins.get("original native receiver scalar observation plus original-format authored writer",0))!=96 or int(origins.get("original-format authored writer checked against original JS receiver",0))!=8:
		fail("Module-pause provenance changed");return
	if masks.size()!=4 or values.size()!=2 or not repeated_ids:fail("Module-pause field coverage changed");return
	for mutation in [PackedByteArray(),PackedByteArray([80,3,9]),PackedByteArray([80,3,8,7,0,0,0,0]),PackedByteArray([80,4,9,7,0,0,0,0]),PackedByteArray([112,3,9,7,0,0,0,0])]:
		if not Pause.decode_packet(mutation).has("error"):fail("Unsupported module-pause envelope accepted");return
	if not parsed.get("invalid") is Array or parsed.invalid.size()!=2:fail("Module-pause invalid fixture changed");return
	for row in parsed.invalid:
		if not Pause.decode_packet(str(row.packet).hex_decode()).has("error"):fail("Invalid module-pause count accepted: "+str(row.name));return
	print("NWN79 Godot module-pause decoder PASS: native_receiver=96 authored_writer=104 masks=4 values=2 malformed_checked=true")
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
	printerr("NWN79 Godot module-pause decoder failed: "+reason)
	quit(1)
