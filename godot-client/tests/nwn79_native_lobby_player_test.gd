extends SceneTree
const Lobby=preload("res://systems/native_data/native_network_lobby_player.gd")

func _initialize()->void:
	var parsed: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://tests/nwn79_lobby_player_fixture.json"))
	if not parsed is Dictionary or int(parsed.get("schema",0))!=1 or not parsed.get("cases") is Array:fail("Lobby-player oracle fixture unavailable");return
	var cases: Array=parsed.cases
	var absent:=0;var present:=0;var max_classes:=false;var localized:=false;var custom_portrait:=false;var western:=false
	for row in cases:
		var packet: PackedByteArray=str(row.packet).hex_decode()
		var actual: Dictionary=Lobby.decode_packet(packet)
		if actual.has("error") or canonical(actual)!=canonical(row.expected):fail("Lobby-player oracle differs at "+str(row.name)+": "+str(actual.get("error","fields")));return
		if str(row.origin)!="authored original-format writer checked against original-receiver JS reconstruction":fail("Lobby-player provenance changed");return
		if actual.present:
			present+=1
			max_classes=max_classes or actual.character.classes.size()==255
			localized=localized or actual.character.firstName.has("strRef")
			custom_portrait=custom_portrait or actual.character.has("portraitRef")
			western=western or str(actual.character.firstName.get("text","")).contains("é")
		else:
			absent+=1
			if actual.character.size()!=1 or not actual.character.has("id"):fail("Absent lobby player gained invented fields");return
		if actual.character.has("source") or actual.character.has("resref") or actual.character.has("objectType"):
			fail("Lobby player conflated with playable character or world object");return
		for length in range(packet.size()):
			if not Lobby.decode_packet(packet.slice(0,length)).has("error"):fail("Truncated lobby-player packet accepted at "+str(row.name)+" length "+str(length));return
		var overlong:=packet.duplicate();overlong.append_array(PackedByteArray([0,0]))
		if not Lobby.decode_packet(overlong).has("error"):fail("Trailing lobby-player bytes accepted at "+str(row.name));return
	if cases.size()!=9 or int(parsed.get("originalNativeReceiverExecution",-1))!=0 or int(parsed.get("originalNativeSenderWriterExecution",-1))!=0 or int(parsed.get("capturedNative",-1))!=0 or int(parsed.get("authoredWriter",-1))!=9 or absent!=3 or present!=6 or not max_classes or not localized or not custom_portrait or not western:
		fail("Lobby-player fixture coverage changed");return
	if not parsed.get("invalid") is Array or parsed.invalid.size()!=2:fail("Lobby-player malformed fixture changed");return
	for row in parsed.invalid:
		if not Lobby.decode_packet(str(row.packet).hex_decode()).has("error"):fail("Malformed lobby-player classes accepted: "+str(row.name));return
	for mutation in [PackedByteArray(),PackedByteArray([80,49,3]),PackedByteArray([80,49,2,7,0,0,0,0]),PackedByteArray([80,48,3,7,0,0,0,0]),PackedByteArray([112,49,3,7,0,0,0,0])]:
		if not Lobby.decode_packet(mutation).has("error"):fail("Unsupported lobby-player envelope accepted");return
	print("NWN79 Godot lobby-player decoder PASS: authored_writer=9 captured_native=0 present=6 absent=3 malformed_checked=true")
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
	printerr("NWN79 Godot lobby-player decoder failed: "+reason)
	quit(1)
