extends SceneTree
const Table=preload("res://systems/native_data/native_custom_token_table.gd")

func _initialize()->void:
	var parsed: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://tests/nwn79_custom_token_table_fixture.json"))
	if not parsed is Dictionary or int(parsed.get("schema",0))!=1 or not parsed.get("cases") is Array:fail("Original token-table oracle unavailable");return
	var cases: Array=parsed.cases
	if cases.size()!=135 or not str(parsed.get("origin","")).begins_with("original native CTlkTable setter observation"):
		fail("Original token-table coverage changed");return
	var negative:=false;var leading_nul:=false;var embedded_nul:=false;var replacement:=false
	for row in cases:
		var table=Table.new()
		for initial_id in row.initial:
			var seed: PackedByteArray=("t"+str(int(initial_id))).to_ascii_buffer()
			if not table.apply(int(initial_id),seed):fail("Initial oracle record rejected");return
		var value: PackedByteArray=str(row.valueHex).hex_decode()
		var before: Array[Dictionary]=table.snapshot()
		var accepted: bool=table.apply(int(row.id),value)
		if accepted!=(int(row.id)>=0):fail("Signed ID behavior differs");return
		if int(row.id)<0:
			negative=true
			if not same_records(before,table.snapshot()):fail("Negative ID changed table");return
		else:
			var stored: Dictionary=table.lookup_bytes(int(row.id))
			if not stored.found:fail("Accepted token missing");return
			leading_nul=leading_nul or (not value.is_empty() and value[0]==0 and (stored.bytes as PackedByteArray).is_empty())
			embedded_nul=embedded_nul or (value.size()>1 and value[0]!=0 and value.has(0) and (stored.bytes as PackedByteArray).has(0))
			replacement=replacement or before.size()==table.snapshot().size()
		if not oracle_matches(row.expected,table.snapshot()):fail("Native table records differ for id="+str(row.id)+" value="+str(row.valueHex)+" expected="+JSON.stringify(row.expected)+" actual="+JSON.stringify(table.snapshot()));return
	if not negative or not leading_nul or not embedded_nul or not replacement:fail("Original oracle edge coverage changed");return
	if not private_copy_and_projection():return
	print("NWN79 Godot custom-token table PASS: original_native_table=135 captured_packets=0 byte_ownership=true ui_projection=true reset=true")
	quit(0)

func oracle_matches(expected: Array,actual: Array[Dictionary])->bool:
	if expected.size()!=actual.size():return false
	for at in expected.size():
		if int(expected[at].id)!=int(actual[at].id) or str(expected[at].valueHex)!=(actual[at].bytes as PackedByteArray).hex_encode():return false
	return true

func same_records(left: Array[Dictionary],right: Array[Dictionary])->bool:
	if left.size()!=right.size():return false
	for at in left.size():
		if left[at].id!=right[at].id or (left[at].bytes as PackedByteArray)!=(right[at].bytes as PackedByteArray):return false
	return true

func private_copy_and_projection()->bool:
	var table=Table.new()
	if not table.apply(0,PackedByteArray([65])) or not table.apply(9,PackedByteArray([66])):fail("Server table incorrectly blocked reserved script IDs");return false
	var input:=PackedByteArray([65,0,66])
	if not table.apply(42,input):fail("Embedded-NUL assignment rejected");return false
	input[0]=90
	var raw: Dictionary=table.lookup_bytes(42)
	if not raw.found or (raw.bytes as PackedByteArray)!=PackedByteArray([65,0,66]):fail("Caller mutation changed table bytes");return false
	var output: PackedByteArray=raw.bytes;output[0]=90
	var records: Array[Dictionary]=table.snapshot();(records[2].bytes as PackedByteArray)[0]=90
	if (table.lookup_bytes(42).bytes as PackedByteArray)!=PackedByteArray([65,0,66]):fail("Lookup/snapshot exposed mutable storage");return false
	if table.project_ui(42).get("ready",true):fail("Embedded NUL was silently projected to UI text");return false
	if not table.apply(43,PackedByteArray([0,65])) or not table.project_ui(43).get("ready",false) or str(table.project_ui(43).text)!="":fail("Leading NUL was not native empty assignment");return false
	if not table.apply(44,PackedByteArray([0x80,0xe9])) or not table.project_ui(44).get("ready",false) or str(table.project_ui(44).text)!="€é":fail("Western UI projection changed text");return false
	if table.apply(2147483648,PackedByteArray([65])) or table.lookup_bytes(2147483648).found:fail("Unsigned overflow ID was accepted");return false
	if not table.apply(45,PackedByteArray([0x81])) or table.project_ui(45,131).get("ready",true):fail("Incomplete multibyte text silently projected");return false
	if table.project_ui(44,999).get("ready",true):fail("Unsupported language silently projected");return false
	if table.project_ui(999).get("ready",true):fail("Missing token silently projected");return false
	var revision_before: int=table.revision
	table.reset()
	if table.revision!=revision_before+1 or not table.snapshot().is_empty() or table.lookup_bytes(42).found:fail("Area/token reset retained old records");return false
	return true

func fail(reason: String)->void:
	printerr("NWN79 Godot custom-token table failed: "+reason)
	quit(1)
