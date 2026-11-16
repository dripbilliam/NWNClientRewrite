extends SceneTree
const Party=preload("res://systems/native_data/native_network_party.gd")

func _initialize()->void:
	var parsed: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://tests/nwn79_party_fixture.json"))
	if not parsed is Dictionary or int(parsed.get("schema",0))!=1 or not parsed.get("cases") is Array:fail("Party oracle fixture unavailable");return
	var cases: Array=parsed.cases
	var origins: Dictionary={}
	var by_minor: Dictionary={}
	for row in cases:
		var packet: PackedByteArray=str(row.packet).hex_decode()
		var actual: Dictionary=Party.decode_packet(packet)
		if actual.has("error") or canonical(actual)!=canonical(row.expected):fail("Party oracle differs at "+str(row.name)+": "+str(actual.get("error","fields")));return
		origins[str(row.origin)]=int(origins.get(str(row.origin),0))+1
		var minor_key:=str(int(row.expected.major))+"/"+str(int(row.expected.minor))
		by_minor[minor_key]=int(by_minor.get(minor_key,0))+1
		for length in range(packet.size()):
			if not Party.decode_packet(packet.slice(0,length)).has("error"):fail("Truncated party packet accepted at "+str(row.name)+" length "+str(length));return
		var overlong:=packet.duplicate();overlong.append_array(PackedByteArray([0,0]))
		if not Party.decode_packet(overlong).has("error"):fail("Trailing party bytes accepted at "+str(row.name));return
	if cases.size()!=323 or int(origins.get("original native sender fixture",0))!=315 or int(origins.get("captured native packet",0))!=2 or int(origins.get("authored original-format writer",0))!=6:fail("Party fixture coverage changed");return
	for minor in ["14/1","14/3","14/4","36/3"]:
		if int(by_minor.get(minor,0))<3:fail("Party packet family missing "+minor);return
	for mutation in [PackedByteArray(),PackedByteArray([80,14,2]),PackedByteArray([80,36,4]),PackedByteArray([112,14,1])]:
		if not Party.decode_packet(mutation).has("error"):fail("Unsupported party envelope accepted");return
	var zero_count: PackedByteArray=PackedByteArray()
	var invitation: PackedByteArray=PackedByteArray()
	for row in cases:
		if str(row.name)=="signed-count-0":zero_count=str(row.packet).hex_decode()
		if str(row.name)=="invitation-Arelith":invitation=str(row.packet).hex_decode()
	if zero_count.size()<11 or invitation.size()<12:fail("Malformed party fixture unavailable");return
	zero_count.encode_s32(7,0x7fffffff)
	if not Party.decode_packet(zero_count).has("error"):fail("Unbounded party count accepted");return
	invitation.encode_u32(7,0x7fffffff)
	if not Party.decode_packet(invitation).has("error"):fail("Unbounded invitation string accepted");return
	print("NWN79 Godot party decoder PASS: native_roster=315 captured_roster=2 authored=6 by_minor="+str(by_minor)+" malformed_checked=true")
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
	printerr("NWN79 Godot party decoder failed: "+reason)
	quit(1)
