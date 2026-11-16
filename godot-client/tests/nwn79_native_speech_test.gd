extends SceneTree
const Speech=preload("res://systems/native_data/native_network_speech.gd")

func _initialize()->void:
	var root:=ProjectSettings.globalize_path("res://../backups/animations/")
	var writer: Variant=JSON.parse_string(FileAccess.get_file_as_string(root+"native-network-chat-writer-observations.json"))
	var one_liner: Variant=JSON.parse_string(FileAccess.get_file_as_string(root+"native-network-speech-observations.json"))
	if not writer is Dictionary or not one_liner is Dictionary:fail("Original speech fixtures unavailable");return
	var chat_checked:=0
	for row in writer.cases:
		if int(row.case.get("format",-1))!=1:continue
		for hex in row.packets:
			var bytes: PackedByteArray=str(hex).hex_decode()
			var actual: Dictionary=Speech.decode_packet(bytes)
			if actual.has("error") or actual.get("kind")!="server-speech" or int(actual.get("channel",-1))!=int(bytes[2]):fail("Original server chat differs at case "+str(chat_checked)+": "+str(actual.get("error","")));return
			if str(row.case.kind)=="strref":
				if int(actual.get("text",{}).get("strRef",-1))!=57779:fail("Original server strref was lost");return
			elif str(actual.get("text",{}).get("text",""))!="Native chat €é <unsafe>":fail("Original server chat text was lost");return
			if not Speech.decode_packet(bytes.slice(0,-1)).has("error"):fail("Truncated original server chat was accepted");return
			chat_checked+=1
	var one_checked:=0
	for row in one_liner.cases:
		if int(row.case.get("format",-1))!=1:continue
		var actual: Dictionary=Speech.decode_packet(str(row.packet).hex_decode())
		if actual.has("error") or actual.get("kind")!="server-speech" or int(actual.get("channel",-1))!=(12 if bool(row.case.oneLiner) else 11) or int(actual.get("objectId",-1))!=0x80000013 or int(actual.get("contextId",-1))!=0xffffffff or int(actual.get("soundObjectId",-1))!=0xffffffff or str(actual.get("sound",""))!=str(row.case.sound) or bool(actual.get("soundFlag",false))!=bool(row.case.soundFlag):fail("Original server one-liner differs at case "+str(one_checked)+": "+str(actual.get("error","")));return
		one_checked+=1
	if chat_checked!=43 or one_checked!=32:fail("Original speech fixture coverage is incomplete");return
	print("NWN79 Godot speech PASS: chat_packets=",chat_checked," one_liners=",one_checked)
	quit(0)

func fail(reason: String)->void:
	printerr("NWN79 Godot speech failed: "+reason)
	quit(1)
