extends SceneTree
const Access=preload("res://systems/native_data/native_network_gui_access.gd")

func _initialize()->void:
	var oracle: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://tests/nwn79_gui_outbound_oracle.json"))
	if not oracle is Dictionary or not oracle.get("cases") is Array or oracle.cases.size()!=5:fail("Original GUI outbound oracle unavailable");return
	for row in oracle.cases:
		var result: Dictionary=Access.attempt_request(row.guiPanelId,row.targetId,row.includePosition) if row.panel=="blocked-attempt" else Access.context_request(row.sourceKind,row.targetId,row.position,row.includePosition)
		if result.has("error") or not result.get("bytes") is PackedByteArray or result.bytes.hex_encode()!=str(row.hex):fail("GUI outbound packet differed from original writer: "+str(row.name)+" "+str(result));return
	for invalid in [Access.attempt_request(0,Access.INVALID,false),Access.attempt_request(23,Access.INVALID,false),Access.attempt_request(8,-1,false),Access.attempt_request(8,Access.INVALID,1),Access.context_request("ground",7,[0,0,0],true),Access.context_request("creature",Access.INVALID,[0,0,0],true),Access.context_request("creature",42,[1,0,0],true),Access.context_request("missing",42,[0,0,0],false),Access.context_request("ground",Access.INVALID,[INF,0,0],true)]:
		if not invalid.has("error"):fail("Invalid GUI outbound input was accepted");return
	print("NWN79 GUI outbound writer PASS: original_js_packets=5 invalid_cases=9 blocked_and_context=true")
	quit(0)

func fail(reason: String)->void:
	printerr("NWN79 GUI outbound writer failed: "+reason)
	quit(1)
