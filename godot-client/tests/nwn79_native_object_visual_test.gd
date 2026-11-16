extends SceneTree
const ObjectVisual=preload("res://systems/native_data/native_network_object_visual.gd")
const INVALID=0x7f000000

func _initialize()->void:
	var parsed: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://tests/nwn79_object_visual_fixture.json"))
	if not parsed is Dictionary or int(parsed.get("schema",0))!=1 or not parsed.get("cases") is Array:fail("Object visual oracle fixture unavailable");return
	var cases: Array=parsed.cases
	var origins: Dictionary={}
	var beam_ids: Dictionary={211:true,212:true}
	var beam:=func(id: int)->bool:return beam_ids.has(id)
	var providers: Dictionary={"isBeam":beam}
	var current: Dictionary={"number":8193,"revision":37,"postfix":17}
	for row in cases:
		var packet: PackedByteArray=str(row.packet).hex_decode()
		var actual: Dictionary=ObjectVisual.decode_packet(packet,row.build,providers)
		if actual.has("error") or canonical(actual)!=canonical(row.expected):fail("Object visual oracle differs at "+str(row.name)+": "+str(actual.get("error","fields")));return
		origins[str(row.origin)]=int(origins.get(str(row.origin),0))+1
		if actual.has("action") or actual.has("id") or int(actual.targetId)!=int(row.expected.targetId):fail("Visual event was conflated with object update at "+str(row.name));return
		for length in range(packet.size()):
			if not ObjectVisual.decode_packet(packet.slice(0,length),row.build,providers).has("error"):fail("Truncated object visual packet accepted at "+str(row.name)+" length "+str(length));return
		var overlong:=packet.duplicate();overlong.append_array(PackedByteArray([0,0]))
		if not ObjectVisual.decode_packet(overlong,row.build,providers).has("error"):fail("Trailing object visual bytes accepted at "+str(row.name));return
	if cases.size()!=13 or int(origins.get("authored original-format writer",0))!=10 or int(origins.get("captured native packet",0))!=3:fail("Object visual fixture coverage changed");return
	for mutation in [PackedByteArray(),PackedByteArray([80,5,1]),PackedByteArray([80,4,3]),PackedByteArray([112,5,3])]:
		if not ObjectVisual.decode_packet(mutation,current,providers).has("error"):fail("Unsupported object visual envelope accepted");return
	var ordinary: PackedByteArray=PackedByteArray()
	var extended: PackedByteArray=PackedByteArray()
	var visual999: PackedByteArray=PackedByteArray()
	for row in cases:
		match str(row.name):
			"ordinary-existing-current":ordinary=str(row.packet).hex_decode()
			"beam-existing-current":extended=str(row.packet).hex_decode()
			"visual999-existing-current":visual999=str(row.packet).hex_decode()
	if ordinary.is_empty() or extended.is_empty() or visual999.is_empty():fail("Core visual fixture missing");return
	if not ObjectVisual.decode_packet(ordinary,current).has("error") or not ObjectVisual.decode_packet(ordinary,{},providers).has("error"):fail("Missing build/classifier accepted");return
	if not ObjectVisual.decode_packet(ordinary,current,{"isBeam":func(_id: int)->Variant:return null}).has("error"):fail("Unknown visual type accepted");return
	if not ObjectVisual.decode_packet(ordinary,current,{"isBeam":func(_id: int)->bool:return true}).has("error"):fail("Wrong extended classification accepted for ordinary visual");return
	if not ObjectVisual.decode_packet(extended,current,{"isBeam":func(_id: int)->bool:return false}).has("error"):fail("Missing beam classification accepted");return
	if ObjectVisual.decode_packet(visual999,current,{"isBeam":func(_id: int)->bool:return false}).has("error"):fail("Visual 999 special branch was lost");return
	for count in [-1,0x7fffffff]:
		var invalid_count:=ordinary.duplicate();invalid_count.encode_s32(25,count)
		if not ObjectVisual.decode_packet(invalid_count,current,providers).has("error"):fail("Unbounded visual key count accepted");return
		invalid_count=ordinary.duplicate();invalid_count.encode_s32(29,count)
		if not ObjectVisual.decode_packet(invalid_count,current,providers).has("error"):fail("Unbounded visual entry count accepted");return
	var event: Dictionary=ObjectVisual.decode_packet(ordinary,current,providers)
	if int(event.targetId)!=0x80000402 or event.has("areaId") or event.has("objectType") or event.has("action"):
		fail("Transient visual packet was conflated with an object or area update");return
	print("NWN79 Godot object visual decoder PASS: original_oracle=13 captured_native=3 extended_and_point=true malformed_checked=true")
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
	printerr("NWN79 Godot object visual decoder failed: "+reason)
	quit(1)
