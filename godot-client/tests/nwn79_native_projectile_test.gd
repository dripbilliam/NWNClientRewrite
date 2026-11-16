extends SceneTree
const Projectile=preload("res://systems/native_data/native_network_projectile.gd")

func _initialize()->void:
	var parsed: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://tests/nwn79_projectile_fixture.json"))
	if not parsed is Dictionary or int(parsed.get("schema",0))!=1 or not parsed.get("cases") is Array:fail("Projectile oracle fixture unavailable");return
	var cases: Array=parsed.cases
	var origins: Dictionary={}
	var appearances: Dictionary={}
	for row in cases:
		var packet: PackedByteArray=str(row.packet).hex_decode()
		var actual: Dictionary=Projectile.decode_packet(packet)
		if actual.has("error") or canonical(actual)!=canonical(row.expected):fail("Projectile oracle differs at "+str(row.name)+": "+str(actual.get("error","fields")));return
		origins[str(row.origin)]=int(origins.get(str(row.origin),0))+1
		appearances[int(actual.header.appearance)]=int(appearances.get(int(actual.header.appearance),0))+1
		if actual.has("id") or actual.has("action") or actual.has("objectType"):
			fail("Private projectile was conflated with canonical object creation");return
		for length in range(packet.size()):
			if not Projectile.decode_packet(packet.slice(0,length)).has("error"):fail("Truncated projectile packet accepted at "+str(row.name)+" length "+str(length));return
		var overlong:=packet.duplicate();overlong.append_array(PackedByteArray([0,0]))
		if not Projectile.decode_packet(overlong).has("error"):fail("Trailing projectile packet bytes accepted at "+str(row.name));return
	if cases.size()!=128 or int(origins.get("original native sender/writer fixture",0))!=96 or int(origins.get("captured native packet",0))!=32 or int(parsed.get("capturedNative",-1))!=32 or int(parsed.get("originalSenderWriter",-1))!=96:
		fail("Projectile fixture provenance changed");return
	for appearance in [0,1,2,5,6,7,8,255]:
		if int(appearances.get(appearance,0))<6:fail("Projectile appearance branch missing: "+str(appearance));return
	for mutation in [PackedByteArray(),PackedByteArray([80,34,1]),PackedByteArray([80,34,0,7,0,0,0,0]),PackedByteArray([80,33,1,7,0,0,0,0]),PackedByteArray([112,34,1,7,0,0,0,0])]:
		if not Projectile.decode_packet(mutation).has("error"):fail("Unsupported projectile envelope accepted");return
	print("NWN79 Godot projectile decoder PASS: original_native_sender=96 captured_native=32 appearances=8 malformed_checked=true")
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
	printerr("NWN79 Godot projectile decoder failed: "+reason)
	quit(1)
