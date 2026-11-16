extends SceneTree
const Runtime=preload("res://systems/native_data/native_runtime_messages.gd")

func _initialize()->void:
	var path:=ProjectSettings.globalize_path("res://../backups/animations/network-runtime-captured-v1.json")
	var fixture: Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
	if not fixture is Dictionary:fail("Original runtime packet fixture unavailable");return
	var echoes:=0
	for hex in fixture.packets:
		var packet: PackedByteArray=str(hex).hex_decode()
		if packet.size()<3 or packet[0]!=80 or packet[1]!=54 or packet[2]!=2:continue
		var decoded: Dictionary=Runtime.device_echo_request(packet)
		if decoded.has("error") or not decoded.data.is_empty():fail("Original empty device echo differs");return
		var response: Dictionary=Runtime.device_echo_response(decoded.data)
		if response.has("error") or response.bytes!=PackedByteArray([112,54,3,11,0,0,0,0,0,0,0,0x60]):fail("Original device echo response differs");return
		echoes+=1
	if echoes<3:fail("Original device echo coverage is unavailable");return
	var filled: Dictionary=Runtime.device_echo_response(PackedByteArray([1,2,3,255]))
	var incoming: PackedByteArray=filled.bytes.duplicate();incoming[0]=80;incoming[2]=2
	var decoded: Dictionary=Runtime.device_echo_request(incoming)
	if decoded.has("error") or decoded.data!=PackedByteArray([1,2,3,255]):fail("Opaque device echo bytes changed");return
	if not Runtime.login_waypoint_response("").bytes.is_empty() or Runtime.login_waypoint_response("Arrival").bytes.slice(0,3)!=PackedByteArray([112,2,13]):fail("Native login waypoint policy differs");return
	print("NWN79 Godot runtime messages PASS: captured_echoes=",echoes)
	quit(0)

func fail(reason: String)->void:
	printerr("NWN79 Godot runtime messages failed: "+reason)
	quit(1)
