extends SceneTree
const Examine=preload("res://systems/native_data/native_network_examine.gd")

func _initialize()->void:
	var parsed: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://tests/nwn79_examine_fixture.json"))
	if not parsed is Dictionary or int(parsed.get("schema",0))!=1 or not parsed.get("cases") is Array or not parsed.get("malformed") is Array:fail("Examination oracle fixture unavailable");return
	var cases: Array=parsed.cases
	var origins: Dictionary={}
	var by_minor: Dictionary={}
	for row in cases:
		var packet: PackedByteArray=str(row.packet).hex_decode()
		var actual: Dictionary=Examine.decode_packet(packet,row.build)
		if actual.has("error") or canonical(actual)!=canonical(row.expected):fail("Examination oracle differs at "+str(row.name)+": "+str(actual.get("error","fields")));return
		origins[str(row.origin)]=int(origins.get(str(row.origin),0))+1
		var minor_key:=str(int(row.expected.minor))
		by_minor[minor_key]=int(by_minor.get(minor_key,0))+1
		for length in range(packet.size()):
			if not Examine.decode_packet(packet.slice(0,length),row.build).has("error"):fail("Truncated examination packet accepted at "+str(row.name)+" length "+str(length));return
		var overlong:=packet.duplicate();overlong.append_array(PackedByteArray([0,0]))
		if not Examine.decode_packet(overlong,row.build).has("error"):fail("Trailing examination bytes accepted at "+str(row.name));return
	if cases.size()!=15 or int(origins.get("captured native packet",0))!=5 or int(origins.get("authored original-format writer",0))!=10:fail("Examination fixture coverage changed");return
	for minor in ["2","3","4","5","6"]:
		if int(by_minor.get(minor,0))<1:fail("Examination family missing "+minor);return
	for row in parsed.malformed:
		if not Examine.decode_packet(str(row.packet).hex_decode(),row.build).has("error"):fail("Malformed examination accepted at "+str(row.name));return
	for mutation in [PackedByteArray(),PackedByteArray([80,27,1]),PackedByteArray([80,27,7]),PackedByteArray([112,27,2])]:
		if not Examine.decode_packet(mutation,{"number":8193,"revision":37,"postfix":17}).has("error"):fail("Unsupported examination envelope accepted");return
	for row in cases:
		if str(row.name)=="creature-wide-effects" and not Examine.decode_packet(str(row.packet).hex_decode()).has("error"):fail("Creature examination without server build accepted");return
	print("NWN79 Godot examination decoder PASS: captured=5 authored=10 malformed=3 by_minor="+str(by_minor)+" truncation_checked=true")
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
	printerr("NWN79 Godot examination decoder failed: "+reason)
	quit(1)
