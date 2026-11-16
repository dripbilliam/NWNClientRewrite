extends SceneTree
const Feedback=preload("res://systems/native_data/native_network_feedback.gd")

func _initialize()->void:
	var parsed: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://tests/nwn79_feedback_fixture.json"))
	if not parsed is Dictionary or int(parsed.get("schema",0))!=1 or not parsed.get("cases") is Array:fail("Feedback oracle fixture unavailable");return
	var cases: Array=parsed.cases
	var minors: Dictionary={}
	for row in cases:
		var packet: PackedByteArray=str(row.packet).hex_decode()
		var actual: Dictionary=Feedback.decode_packet(packet,row.build)
		if actual.has("error") or canonical(actual)!=canonical(row.expected):fail("Feedback oracle differs at "+str(row.name)+": "+str(actual.get("error","fields")));return
		var minor_key:=str(int(row.expected.minor))
		minors[minor_key]=int(minors.get(minor_key,0))+1
		for length in range(packet.size()):
			if not Feedback.decode_packet(packet.slice(0,length),row.build).has("error"):fail("Truncated feedback packet accepted at "+str(row.name)+" length "+str(length));return
		var overlong:=packet.duplicate();overlong.append_array(PackedByteArray([0,0]))
		if not Feedback.decode_packet(overlong,row.build).has("error"):fail("Trailing feedback bytes accepted at "+str(row.name));return
	for minor in ["3","5","6","8","11","14"]:
		if int(minors.get(minor,0))<3:fail("Feedback family coverage missing "+minor);return
	for mutation in [PackedByteArray(),PackedByteArray([80,18,1]),PackedByteArray([80,19,3]),PackedByteArray([112,18,3])]:
		if not Feedback.decode_packet(mutation,{"number":8193,"revision":37,"postfix":17}).has("error"):fail("Unsupported feedback envelope accepted");return
	for row in cases:
		if int(row.expected.minor) in [3,11] and not Feedback.decode_packet(str(row.packet).hex_decode()).has("error"):fail("Missing feedback server build accepted");return
	print("NWN79 Godot feedback decoder PASS: cases="+str(cases.size())+" by_minor="+str(minors)+" malformed_checked=true")
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
	printerr("NWN79 Godot feedback decoder failed: "+reason)
	quit(1)
