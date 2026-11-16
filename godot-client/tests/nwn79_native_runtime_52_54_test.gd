extends SceneTree
const Runtime=preload("res://systems/native_data/native_network_runtime_52_54.gd")

func _initialize()->void:
	var parsed: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://tests/nwn79_runtime_52_54_fixture.json"))
	if not parsed is Dictionary or int(parsed.get("schema",0))!=1 or not parsed.get("cases") is Array:fail("Runtime oracle fixture unavailable");return
	var cases: Array=parsed.cases
	var origins: Dictionary={};var subtypes: Dictionary={}
	for row in cases:
		var packet: PackedByteArray=str(row.packet).hex_decode()
		var actual: Dictionary=Runtime.decode_packet(packet)
		if actual.has("error"):fail("Runtime oracle rejected "+str(row.name)+": "+str(actual.error));return
		var expected: Dictionary=row.expected
		if actual.kind=="device-echo-request":
			if actual.data.hex_encode()!=str(expected.dataHex):fail("Opaque echo differs at "+str(row.name));return
			actual.erase("data");expected.erase("dataHex")
		if canonical(actual)!=canonical(expected):fail("Runtime oracle fields differ at "+str(row.name));return
		origins[str(row.origin)]=int(origins.get(str(row.origin),0))+1
		subtypes[str(actual.major)+"/"+str(actual.minor)]=int(subtypes.get(str(actual.major)+"/"+str(actual.minor),0))+1
		for length in range(packet.size()):
			if not Runtime.decode_packet(packet.slice(0,length)).has("error"):fail("Truncated runtime packet accepted at "+str(row.name)+" length "+str(length));return
		var overlong:=packet.duplicate();overlong.append_array(PackedByteArray([0,0]))
		if not Runtime.decode_packet(overlong).has("error"):fail("Trailing runtime bytes accepted at "+str(row.name));return
	if cases.size()!=382 or int(parsed.get("originalSenderWriter",-1))!=18 or int(parsed.get("capturedNative",-1))!=364 or int(origins.get("original native sender/writer fixture",0))!=18 or int(origins.get("captured native packet",0))!=364:
		fail("Runtime provenance changed");return
	for subtype in ["52/2","52/3","54/2"]:
		if int(subtypes.get(subtype,0))==0:fail("Runtime subtype missing: "+subtype);return
	for mutation in [PackedByteArray(),PackedByteArray([80,52,2]),PackedByteArray([80,52,1,7,0,0,0,0]),PackedByteArray([80,54,1,7,0,0,0,0]),PackedByteArray([80,54,3,7,0,0,0,0]),PackedByteArray([112,54,2,7,0,0,0,0])]:
		if not Runtime.decode_packet(mutation).has("error"):fail("Unsupported runtime envelope accepted");return
	var echo: PackedByteArray=str(cases[0].packet).hex_decode()
	# A huge declared opaque length must fail before allocation or slicing.
	for row in cases:
		if int(row.expected.major)==54:
			echo=str(row.packet).hex_decode();break
	var oversized_echo:=echo.duplicate();oversized_echo.encode_u32(7,0xffffffff)
	if not Runtime.decode_packet(oversized_echo).has("error"):fail("Oversized device echo accepted");return
	var list_packet:=PackedByteArray()
	for row in cases:
		if int(row.expected.major)==52 and int(row.expected.minor)==3:
			list_packet=str(row.packet).hex_decode();break
	if list_packet.is_empty():fail("TLK list fixture missing");return
	var oversized_list:=list_packet.duplicate();oversized_list.encode_u32(7,0xffffffff)
	if not Runtime.decode_packet(oversized_list).has("error"):fail("Oversized TLK list accepted");return
	print("NWN79 Godot runtime 52/54 decoder PASS: original_native_sender=18 captured_native=364 subtypes=52/2,52/3,54/2 malformed_checked=true")
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
	printerr("NWN79 Godot runtime 52/54 decoder failed: "+reason)
	quit(1)
