extends SceneTree
const Token=preload("res://systems/native_data/native_network_custom_token.gd")

func _initialize()->void:
	var parsed: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://tests/nwn79_custom_token_fixture.json"))
	if not parsed is Dictionary or int(parsed.get("schema",0))!=1 or not parsed.get("cases") is Array:fail("Custom-token oracle fixture unavailable");return
	var cases: Array=parsed.cases
	var origins: Dictionary={};var negative:=false;var leading_nul:=false;var embedded_nul:=false;var western:=false
	for row in cases:
		var packet: PackedByteArray=str(row.packet).hex_decode()
		var actual: Dictionary=Token.decode_packet(packet)
		var expected: Dictionary=row.expected
		if actual.has("error"):fail("Custom-token oracle rejected "+str(row.name)+": "+str(actual.error));return
		if actual.textBytes.hex_encode()!=str(expected.textHex):fail("Native custom-token bytes differ at "+str(row.name));return
		negative=negative or int(actual.id)<0
		leading_nul=leading_nul or str(row.name).begins_with("native-sender-") and actual.textBytes.is_empty()
		embedded_nul=embedded_nul or not actual.textComplete and actual.textBytes.has(0)
		western=western or (actual.text is String and (str(actual.text).contains("€") or str(actual.text).contains("é")))
		if str(row.name)=="writer-edge-1" and (actual.text!=null or actual.textBytes.size()!=12 or actual.textBytes[9]!=0):
			fail("Embedded NUL was not retained as native token bytes");return
		actual.erase("textBytes");expected.erase("textHex")
		if canonical(actual)!=canonical(expected):fail("Custom-token oracle differs at "+str(row.name));return
		origins[str(row.origin)]=int(origins.get(str(row.origin),0))+1
		for length in range(packet.size()):
			if not Token.decode_packet(packet.slice(0,length)).has("error"):fail("Truncated custom-token packet accepted at "+str(row.name)+" length "+str(length));return
		var overlong:=packet.duplicate();overlong.append_array(PackedByteArray([0,0]))
		if not Token.decode_packet(overlong).has("error"):fail("Trailing custom-token bytes accepted at "+str(row.name));return
	if cases.size()!=40 or int(parsed.get("originalNativeSender",-1))!=36 or int(parsed.get("capturedNative",-1))!=0 or int(parsed.get("authoredWriter",-1))!=40 or int(origins.get("original native sender scalar observation plus original-format authored writer",0))!=36 or int(origins.get("original-format authored writer checked against original JS receiver",0))!=4:
		fail("Custom-token provenance changed");return
	if not negative or not leading_nul or not embedded_nul or not western:fail("Custom-token field coverage changed");return
	for mutation in [PackedByteArray(),PackedByteArray([80,50,1]),PackedByteArray([80,50,0,7,0,0,0,0]),PackedByteArray([80,49,1,7,0,0,0,0]),PackedByteArray([112,50,1,7,0,0,0,0])]:
		if not Token.decode_packet(mutation).has("error"):fail("Unsupported custom-token envelope accepted");return
	var excessive: PackedByteArray=str(cases[0].packet).hex_decode()
	excessive.encode_u32(11,0xffffffff)
	if not Token.decode_packet(excessive).has("error"):fail("Oversized custom-token text accepted");return
	print("NWN79 Godot custom-token decoder PASS: native_sender=36 authored_writer=40 captured_native=0 malformed_checked=true")
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
	printerr("NWN79 Godot custom-token decoder failed: "+reason)
	quit(1)
