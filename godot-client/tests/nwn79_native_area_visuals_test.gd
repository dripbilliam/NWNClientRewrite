extends SceneTree
const AreaVisuals=preload("res://systems/native_data/native_network_area_visuals.gd")

func _initialize()->void:
	var parsed: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://tests/nwn79_area_visuals_fixture.json"))
	if not parsed is Dictionary or int(parsed.get("schema",0))!=1 or not parsed.get("cases") is Array:fail("Area visual oracle fixture unavailable");return
	var cases: Array=parsed.cases
	var origins: Dictionary={}
	for row in cases:
		var packet: PackedByteArray=str(row.packet).hex_decode()
		var actual: Dictionary=AreaVisuals.decode_packet(packet,row.build)
		if actual.has("error") or canonical(actual)!=canonical(row.expected):fail("Area visual oracle differs at "+str(row.name)+": "+str(actual.get("error","fields")));return
		origins[str(row.origin)]=int(origins.get(str(row.origin),0))+1
		for length in range(packet.size()):
			if not AreaVisuals.decode_packet(packet.slice(0,length),row.build).has("error"):fail("Truncated area visual packet accepted at "+str(row.name)+" length "+str(length));return
		var overlong:=packet.duplicate();overlong.append_array(PackedByteArray([0,0]))
		if not AreaVisuals.decode_packet(overlong,row.build).has("error"):fail("Trailing area visual bytes accepted at "+str(row.name));return
	if cases.size()!=14 or int(origins.get("authored original-format writer",0))!=9 or int(origins.get("original native sender fixture",0))!=3 or int(origins.get("captured native packet",0))!=2:fail("Area visual fixture coverage changed");return
	for mutation in [PackedByteArray(),PackedByteArray([80,4,1]),PackedByteArray([80,99,2]),PackedByteArray([112,4,2])]:
		if not AreaVisuals.decode_packet(mutation,{"number":8193,"revision":37,"postfix":17}).has("error"):fail("Unsupported area visual envelope accepted");return
	var captured: PackedByteArray=PackedByteArray()
	var current: Dictionary={"number":8193,"revision":37,"postfix":17}
	for row in cases:
		if str(row.name)=="area-visual-0":captured=str(row.packet).hex_decode();break
	if captured.size()<25:fail("Captured area visual unavailable");return
	if not AreaVisuals.decode_packet(captured).has("error"):fail("Missing area visual server build accepted");return
	for count in [-1,0x7fffffff]:
		var invalid_count:=captured.duplicate();invalid_count.encode_s32(21,count)
		if not AreaVisuals.decode_packet(invalid_count,current).has("error"):fail("Unbounded visual-transform key count accepted");return
		invalid_count=captured.duplicate();invalid_count.encode_s32(29,count)
		if not AreaVisuals.decode_packet(invalid_count,current).has("error"):fail("Unbounded visual-transform entry count accepted");return
	print("NWN79 Godot area visual decoder PASS: weather=8 native_wind=3 captured_visual=2 pre14_visual=1 malformed_checked=true")
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
	printerr("NWN79 Godot area visual decoder failed: "+reason)
	quit(1)
