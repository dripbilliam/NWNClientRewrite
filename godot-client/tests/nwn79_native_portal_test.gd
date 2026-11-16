extends SceneTree
const Portal=preload("res://systems/native_data/native_network_portal.gd")

func _initialize()->void:
	var parsed: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://tests/nwn79_portal_fixture.json"))
	if not parsed is Dictionary or int(parsed.get("schema",0))!=1 or not parsed.get("cases") is Array or not parsed.get("malformed") is Array:fail("Portal oracle fixture unavailable");return
	if Portal.character_request().hex_encode()!=str(parsed.downloadRequest):fail("Portal character request differs from native");return
	var cases: Array=parsed.cases
	var origins: Dictionary={};var by_family: Dictionary={}
	for row in cases:
		var packet: PackedByteArray=str(row.packet).hex_decode()
		var actual: Dictionary=Portal.decode_packet(packet)
		if actual.has("error") or canonical(actual)!=canonical(row.expected):fail("Portal oracle differs at "+str(row.name)+": "+str(actual.get("error","fields")));return
		origins[str(row.origin)]=int(origins.get(str(row.origin),0))+1
		var family:=str(int(row.expected.major))+"/"+str(int(row.expected.minor))
		by_family[family]=int(by_family.get(family,0))+1
		for length in range(packet.size()):
			if not Portal.decode_packet(packet.slice(0,length)).has("error"):fail("Truncated portal packet accepted at "+str(row.name)+" length "+str(length));return
		var overlong:=packet.duplicate();overlong.append_array(PackedByteArray([0,0]))
		if not Portal.decode_packet(overlong).has("error"):fail("Trailing portal bytes accepted at "+str(row.name));return
	if cases.size()!=23 or int(origins.get("original native server sender fixture",0))!=20 or int(origins.get("authored original-format writer",0))!=3:fail("Portal fixture coverage changed");return
	if int(by_family.get("42/1",0))!=17 or int(by_family.get("43/3",0))!=4 or int(by_family.get("43/2",0))!=2:fail("Portal packet family missing");return
	for row in parsed.malformed:
		if not Portal.decode_packet(str(row.packet).hex_decode()).has("error"):fail("Malformed portal accepted at "+str(row.name));return
	for mutation in [PackedByteArray(),PackedByteArray([80,42,2]),PackedByteArray([80,43,1]),PackedByteArray([80,43,4]),PackedByteArray([112,42,1])]:
		if not Portal.decode_packet(mutation).has("error"):fail("Unsupported portal envelope accepted");return
	print("NWN79 Godot portal decoder PASS: native=20 authored=3 malformed=6 by_family="+str(by_family)+" truncation_checked=true")
	quit(0)

func canonical(value: Variant)->Variant:
	if value is bool:return 1.0 if value else 0.0
	if value is int or value is float:return float(value)
	if value is PackedByteArray:
		var array: Array=[]
		for item in value:array.append(float(item))
		return array
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
	printerr("NWN79 Godot portal decoder failed: "+reason)
	quit(1)
