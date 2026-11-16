extends SceneTree
const Barter=preload("res://systems/native_data/native_network_barter.gd")

func _initialize()->void:
	var parsed: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://tests/nwn79_barter_fixture.json"))
	if not parsed is Dictionary or int(parsed.get("schema",0))!=1 or not parsed.get("server") is Array or not parsed.get("client") is Array:fail("Barter oracle fixture unavailable");return
	var server: Array=parsed.server;var client: Array=parsed.client
	var server_minors: Dictionary={};var operations: Dictionary={}
	for row in server:
		var packet: PackedByteArray=str(row.packet).hex_decode()
		var actual: Dictionary=Barter.decode_packet(packet)
		if actual.has("error") or canonical(actual)!=canonical(row.expected):fail("Barter reply oracle differs at "+str(row.name)+": "+str(actual.get("error","fields")));return
		var minor_key:=str(int(row.expected.minor));server_minors[minor_key]=int(server_minors.get(minor_key,0))+1
		for length in range(packet.size()):
			if not Barter.decode_packet(packet.slice(0,length)).has("error"):fail("Truncated barter reply accepted at "+str(row.name)+" length "+str(length));return
		var overlong:=packet.duplicate();overlong.append_array(PackedByteArray([0,0]))
		if not Barter.decode_packet(overlong).has("error"):fail("Trailing barter reply bytes accepted at "+str(row.name));return
	for row in client:
		var request: Dictionary=row.request
		var original: PackedByteArray=str(row.packet).hex_decode()
		var result: Dictionary=Barter.request(str(request.operation),int(request.targetId),int(request.itemId),bool(request.value),int(request.x),int(request.y))
		if result.has("error") or result.bytes.size()!=original.size() or result.bytes.slice(0,-1)!=original.slice(0,-1):fail("Barter request oracle differs at "+str(row.name));return
		var used:=int(original[original.size()-1])>>5
		var mask: int=(255 << (8-used)) & 255 if used>0 else 0
		if (int(result.bytes[result.bytes.size()-1]) & mask)!=(int(original[original.size()-1]) & mask):fail("Barter request fragment differs at "+str(row.name));return
		var operation:=str(request.operation);operations[operation]=int(operations.get(operation,0))+1
	if server.size()!=124 or client.size()!=128:fail("Barter fixture coverage changed");return
	for minor in ["2","4","8","10","11"]:
		if int(server_minors.get(minor,0))<4:fail("Barter reply family missing "+minor);return
	for operation in ["start","close","add","remove","lock","accept","window","move"]:
		if int(operations.get(operation,0))!=16:fail("Barter request family missing "+operation);return
	for mutation in [PackedByteArray(),PackedByteArray([80,35,1]),PackedByteArray([80,35,9]),PackedByteArray([112,35,2])]:
		if not Barter.decode_packet(mutation).has("error"):fail("Unsupported barter reply envelope accepted");return
	for bad in [Barter.request("unknown"),Barter.request("start",-1),Barter.request("add",Barter.INVALID,Barter.INVALID,false,256,0),Barter.request("move",Barter.INVALID,Barter.INVALID,false,0,-1)]:
		if not bad.has("error"):fail("Invalid barter request accepted");return
	print("NWN79 Godot barter codec PASS: server_replies=124 client_requests=128 server_minors="+str(server_minors)+" malformed_checked=true")
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
	printerr("NWN79 Godot barter codec failed: "+reason)
	quit(1)
