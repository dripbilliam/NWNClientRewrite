extends SceneTree
const Export=preload("res://systems/native_data/native_network_character_export.gd")

func _initialize()->void:
	var parsed: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://tests/nwn79_character_export_fixture.json"))
	if not parsed is Dictionary or int(parsed.get("schema",0))!=1 or not parsed.get("cases") is Array:fail("Character-export oracle fixture unavailable");return
	var cases: Array=parsed.cases
	var lengths: Dictionary={};var localized:=false;var referenced:=false
	for row in cases:
		var packet: PackedByteArray=str(row.packet).hex_decode()
		var actual: Dictionary=Export.decode_packet(packet)
		if actual.has("error"):fail("Character-export oracle rejected "+str(row.name)+": "+str(actual.error));return
		if str(row.origin)!="original native server writer observation with synthetic BIC bytes":fail("Character-export provenance changed");return
		var expected: Dictionary=row.expected
		if actual.data.hex_encode()!=str(expected.dataHex):fail("Opaque character-export bytes changed at "+str(row.name));return
		lengths[actual.data.size()]=true
		localized=localized or actual.firstName.has("text")
		referenced=referenced or actual.firstName.has("strRef")
		if actual.has("characterId") or actual.has("filename") or actual.has("path") or actual.has("effects"):
			fail("Character-export decoder interpreted BIC or invented file identity");return
		actual.erase("data");expected.erase("dataHex")
		if canonical(actual)!=canonical(expected):fail("Character-export name/envelope differs at "+str(row.name));return
		var lengths_to_check: Array=[]
		if packet.size()<=256:
			for length in range(packet.size()):lengths_to_check.append(length)
		else:
			for length in range(0,mini(packet.size(),64)):lengths_to_check.append(length)
			for length in range(packet.size()-2,packet.size()):lengths_to_check.append(length)
		for length in lengths_to_check:
			if not Export.decode_packet(packet.slice(0,length)).has("error"):fail("Truncated character-export packet accepted at "+str(row.name)+" length "+str(length));return
		var overlong:=packet.duplicate();overlong.append_array(PackedByteArray([0,0]))
		if not Export.decode_packet(overlong).has("error"):fail("Trailing character-export bytes accepted at "+str(row.name));return
	if cases.size()!=10 or int(parsed.get("originalNativeServerWriter",-1))!=10 or int(parsed.get("capturedNativeObserved",-1))!=1 or int(parsed.get("capturedNativeReplayed",-1))!=0 or int(parsed.get("authoredInvalid",-1))!=2 or not localized or not referenced:
		fail("Character-export fixture provenance changed");return
	for length in [0,1,7,128,4097]:
		if not lengths.has(length):fail("Character-export length branch missing: "+str(length));return
	if not parsed.get("invalid") is Array or parsed.invalid.size()!=2:fail("Character-export malformed fixture changed");return
	for row in parsed.invalid:
		if not Export.decode_packet(str(row.packet).hex_decode()).has("error"):fail("Malformed character-export size accepted: "+str(row.name));return
	for mutation in [PackedByteArray(),PackedByteArray([80,3,10]),PackedByteArray([80,3,9,7,0,0,0,0]),PackedByteArray([80,4,10,7,0,0,0,0]),PackedByteArray([112,3,10,7,0,0,0,0])]:
		if not Export.decode_packet(mutation).has("error"):fail("Unsupported character-export envelope accepted");return
	print("NWN79 Godot character-export decoder PASS: original_native_writer=10 captured_native_observed=1 captured_replayed=0 opaque_lengths=5 malformed_checked=true")
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
	printerr("NWN79 Godot character-export decoder failed: "+reason)
	quit(1)
