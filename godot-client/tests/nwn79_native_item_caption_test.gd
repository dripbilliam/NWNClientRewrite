extends SceneTree
const Caption=preload("res://systems/native_data/native_network_item_caption.gd")

func _initialize()->void:
	var parsed: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://tests/nwn79_item_caption_fixture.json"))
	if not parsed is Dictionary or int(parsed.get("schema",0))!=1 or not parsed.get("cases") is Array:fail("Item caption oracle fixture unavailable");return
	var cases: Array=parsed.cases
	var formats: Dictionary={}
	var origins: Dictionary={}
	var found_color:=false
	var found_empty:=false
	for row in cases:
		var packet: PackedByteArray=str(row.packet).hex_decode()
		var mode:=int(row.format)
		var actual: Dictionary=Caption.decode_packet(packet,mode)
		if actual.has("error") or canonical(actual)!=canonical(row.expected):fail("Item caption oracle differs at "+str(row.name)+": "+str(actual.get("error","fields")));return
		formats[mode]=int(formats.get(mode,0))+1;origins[str(row.origin)]=int(origins.get(str(row.origin),0))+1
		found_color=found_color or str(actual.text).contains(char(1))
		found_empty=found_empty or str(actual.text).is_empty()
		if actual.has("action") or actual.has("objectType") or actual.has("areaId"):
			fail("Caption instruction was conflated with item creation/update");return
		for length in range(packet.size()):
			if not Caption.decode_packet(packet.slice(0,length),mode).has("error"):fail("Truncated item caption packet accepted at "+str(row.name)+" length "+str(length));return
		var overlong:=packet.duplicate();overlong.append_array(PackedByteArray([0,0]))
		if not Caption.decode_packet(overlong,mode).has("error"):fail("Trailing item caption packet bytes accepted at "+str(row.name));return
	if cases.size()!=72 or int(formats.get(0,0))!=36 or int(formats.get(1,0))!=36 or int(origins.get("original native sender/writer fixture",0))!=72 or int(parsed.get("capturedNative",-1))!=0 or int(parsed.get("originalSenderWriter",-1))!=72 or not found_color or not found_empty:
		fail("Item caption provenance or text coverage changed");return
	for mutation in [PackedByteArray(),PackedByteArray([80,24,5]),PackedByteArray([80,24,4,7,0,0,0,0]),PackedByteArray([80,25,5,7,0,0,0,0]),PackedByteArray([112,24,5,7,0,0,0,0])]:
		if not Caption.decode_packet(mutation).has("error"):fail("Unsupported item caption envelope accepted");return
	var production: PackedByteArray=str(cases[36].packet).hex_decode()
	if not Caption.decode_packet(production,2).has("error") or not Caption.decode_packet(production,0).has("error"):
		fail("Invalid or mismatched format accepted");return
	print("NWN79 Godot item caption decoder PASS: original_native_sender=72 production_format=36 captured_live=0 malformed_checked=true")
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
	printerr("NWN79 Godot item caption decoder failed: "+reason)
	quit(1)
