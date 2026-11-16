extends SceneTree
const Messages=preload("res://systems/native_data/native_network_messages.gd")
func _initialize()->void:
	var file:=FileAccess.open(ProjectSettings.globalize_path("res://../backups/animations/native-network-frame-observations.json"),FileAccess.READ)
	if file==null:fail("fixture unavailable");return
	var native: Dictionary=JSON.parse_string(file.get_as_text());file.close()
	for row in native.assembly:
		var assembler=Messages.new()
		for hex in row.frames:
			if not assembler.push(str(hex).hex_decode()):fail("frame input");return
		var actual: Array=assembler.drain().map(func(message):return message.bytes.hex_encode())
		var expected: Array=[]
		for call in row.calls:
			if call[0]=="message":expected.append(call[2])
		if actual!=expected or assembler.queues["high" if row.high else "low"].size()!=int(row.remaining) or assembler.rejected!=0:fail("native assembly");return
	for row in native.packetization:
		var packet: Dictionary=Messages.packetize(str(row.payload).hex_decode())
		if not packet.has("frames"):fail("packetization input");return
		var actual: Array=packet.frames.map(func(frame):return frame.hex_encode())
		var expected: Array=[]
		for call in row.calls:
			if call[0]=="queue":expected.append(call[3])
		if row.get("pending",null):expected.append(row.pending)
		if actual!=expected:fail("native packetization");return
	print("NWN79 Godot message assembly PASS")
	quit(0)
func fail(stage: String)->void:
	printerr("NWN79 Godot message assembly failed: "+stage)
	quit(1)
