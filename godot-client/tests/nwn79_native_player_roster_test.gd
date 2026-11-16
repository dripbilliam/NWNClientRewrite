extends SceneTree
const Messages=preload("res://systems/native_data/native_network_messages.gd")
const Inflater=preload("res://systems/native_data/native_network_inflater.gd")
const Roster=preload("res://systems/native_data/native_player_roster.gd")

func _initialize()->void:
	var path:=ProjectSettings.globalize_path("res://../backups/animations/local-network-character-v5.json")
	var fixture: Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
	if not fixture is Dictionary:fail("Original session fixture unavailable");return
	var expected: Array=[]
	for message in fixture.transport.messages:
		if str(message.get("kind","")) in ["player-list-all","player-list-add","player-list-delete","object-control"]:expected.append(message)
	if expected.is_empty():fail("Original roster messages unavailable");return
	var assembler:=Messages.new()
	for hex in fixture.transport.applicationFrames:assembler.push(str(hex).hex_decode())
	var inflater:=Inflater.new();var matched:=0
	for row in assembler.drain():
		var decoded: Dictionary=inflater.decode(row.bytes)
		if decoded.has("error"):fail(str(decoded.error));return
		var bytes: PackedByteArray=decoded.bytes
		if bytes.size()<3 or bytes[0]!=80 or not (bytes[1]==10 and int(bytes[2]) in [1,2,3] or bytes[1]==5 and bytes[2]==2):continue
		var actual: Dictionary=Roster.decode_packet(bytes)
		if actual.has("error"):fail(str(actual.error));return
		if matched>=expected.size():fail("More roster packets than original decoded messages");return
		var original: Dictionary=expected[matched]
		for key in actual:
			if not original.has(key):fail("Roster packet "+str(matched)+" missing "+str(key));return
			var mismatch:=compare(actual[key],original[key],str(key))
			if not mismatch.is_empty():fail("Roster packet "+str(matched)+" differs at "+mismatch);return
		matched+=1
	inflater.close()
	if matched!=expected.size():fail("Roster packet count differs: "+str(matched)+"/"+str(expected.size()));return
	print("NWN79 Godot native roster fixture PASS (",matched," packets)")
	quit(0)

func fail(reason: String)->void:
	printerr("NWN79 Godot roster failed: "+reason)
	quit(1)

func compare(actual: Variant,expected: Variant,path: String)->String:
	if actual is Dictionary and expected is Dictionary:
		if actual.size()!=expected.size():return path+".keys"
		for key in expected:
			if not actual.has(key):return path+"."+str(key)+"(missing)"
			var mismatch:=compare(actual[key],expected[key],path+"."+str(key))
			if not mismatch.is_empty():return mismatch
		return ""
	if actual is Array and expected is Array:
		if actual.size()!=expected.size():return path+".length"
		for index in range(actual.size()):
			var mismatch:=compare(actual[index],expected[index],path+"["+str(index)+"]")
			if not mismatch.is_empty():return mismatch
		return ""
	if (actual is int or actual is float or actual is bool) and (expected is int or expected is float or expected is bool):
		return "" if absf(float(actual)-float(expected))<0.00001 else path+"="+str(actual)+"/"+str(expected)
	return "" if actual==expected else path+"="+str(actual)+"/"+str(expected)
