extends SceneTree
const Nui=preload("res://systems/native_data/native_network_nui.gd")

func _initialize()->void:
	var packets: Dictionary={
		"create":"50370158000000090000000400000074657374010000003d0000007b6904726f6f747b690269645369046e65787469056c6162656c53690454657374690474797065536906627574746f6e7d690776657273696f6e69017d60",
		"resource":"5037012b0000000a000000080000006a75692d74657374000000006e75695f6578616d706c65000000000060",
		"destroy":"5037020b0000000900000060",
		"binds":"5037043a0000000200000009000000050000006c6162656c0a000000536907557064617465640900000007000000656e61626c6564010000004660",
		"replacement":"50370532000000090000000500000067726f75701a0000007b69086368696c6472656e5b5d690474797065536903726f777d60",
		"invalidCount":"5037040b000000ffffff7f60"}
	for key in ["create","resource","destroy","binds","replacement"]:
		var decoded: Dictionary=Nui.decode_packet(str(packets[key]).hex_decode())
		if decoded.has("error"):fail("Original JS NUI packet "+key+" rejected: "+str(decoded.error));return
		match key:
			"create":
				if decoded.kind!="nui-create" or decoded.token!=9 or decoded.id!="test" or decoded.format!=1 or decoded.layout.root.id!="next":fail("Original JS inline create differs");return
			"resource":
				if decoded.kind!="nui-create" or decoded.token!=10 or decoded.format!=0 or decoded.resref!="nui_example" or decoded.layout!={}:fail("Original JS JUI create differs");return
			"destroy":
				if decoded.kind!="nui-destroy" or decoded.token!=9:fail("Original JS destroy differs");return
			"binds":
				if decoded.kind!="nui-binds" or decoded.updates.size()!=2 or decoded.updates[0].value!="Updated" or decoded.updates[1].value!=false:fail("Original JS bind batch differs");return
			"replacement":
				if decoded.kind!="nui-layout" or decoded.element!="group" or decoded.layout.type!="row":fail("Original JS layout replacement differs");return
	for packet in [str(packets.invalidCount).hex_decode(),str(packets.create).hex_decode().slice(0,-3),str(packets.binds).hex_decode().slice(0,-2)]:
		if not Nui.decode_packet(packet).has("error"):fail("Malformed original-format NUI packet admitted");return
	var path:=ProjectSettings.globalize_path("res://../backups/animations/native-nui-wire-v1.json")
	var oracle: Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
	if not oracle is Dictionary or oracle.get("cases",[]).size()!=12:fail("Original native NUI wire oracle unavailable");return
	var checks:=0
	for row in oracle.cases:
		if row.entries.is_empty():continue
		var events: Array=[];var binds: Array=[]
		for entry in row.entries:
			var value: Dictionary=entry.duplicate(true)
			if row.kind=="events":value.payload=value.value;events.append(value)
			else:binds.append(value)
		var result: Dictionary=Nui.input_packet(3,events,binds,row.indexed)
		if result.has("error"):fail("Original native NUI input rejected: "+str(result.error));return
		var expected:=str(row.packet).hex_decode()
		if result.bytes.size()!=expected.size() or result.bytes.slice(0,-1)!=expected.slice(0,-1) or (result.bytes[-1]&0xe0)!=(expected[-1]&0xe0):fail("Original native NUI input bytes differ "+str(row.kind)+" indexed="+str(row.indexed)+" actual="+result.bytes.hex_encode()+" expected="+expected.hex_encode());return
		checks+=1
	if checks!=8 or not Nui.input_packet(3,[],[],true).has("error") or not Nui.input_packet(0,[{"type":"open","element":"_window_"}],[],true).has("error") or not Nui.input_packet(3,[{"type":"open","element":"_window_"}],[{"bind":"x","value":1}],true).has("error"):fail("NUI input validation differs");return
	print("NWN79 Godot NUI packet PASS: server=5 malformed=3 native-writer=8")
	quit(0)

func fail(reason: String)->void:
	printerr("NWN79 Godot NUI packet failed: "+reason)
	quit(1)
