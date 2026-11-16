extends SceneTree
const Messages=preload("res://systems/native_data/native_network_messages.gd")
const Inflater=preload("res://systems/native_data/native_network_inflater.gd")
const Area=preload("res://systems/native_data/native_area_state.gd")
func _initialize()->void:
	var path:=ProjectSettings.globalize_path("res://../backups/animations/local-network-character-v5.json")
	var fixture: Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
	if not fixture is Dictionary:fail("Original area fixture unavailable");return
	var expected: Dictionary={}
	for message in fixture.transport.messages:
		if message.get("kind")=="client-area":expected=message;break
	if expected.is_empty():fail("Original area fields unavailable");return
	var assembler:=Messages.new()
	for hex in fixture.transport.applicationFrames:assembler.push(str(hex).hex_decode())
	var inflater:=Inflater.new()
	var found:=false
	for row in assembler.drain():
		var result: Dictionary=inflater.decode(row.bytes)
		if result.has("error"):fail(str(result.error));return
		var bytes: PackedByteArray=result.bytes
		if bytes.size()<3 or bytes[0]!=80 or bytes[1]!=4 or bytes[2]!=1:continue
		var area: Dictionary=Area.decode_packet(bytes,fixture.remote.build)
		if area.has("error"):fail(str(area.error));return
		var mismatch:=compare({"loadingScreen":area.loadingScreen,"position":area.position,"facing":area.facing,"flag":area.flag,"area":area.area},{"loadingScreen":expected.loadingScreen,"position":expected.position,"facing":expected.facing,"flag":expected.flag,"area":expected.area},"area")
		if not mismatch.is_empty():fail("Original area tree differs at "+mismatch);return
		found=true
	inflater.close()
	if not found:fail("Original area packet missing");return
	print("NWN79 Godot native area-state fixture PASS")
	quit(0)
func fail(reason: String)->void:
	printerr("NWN79 Godot area state failed: "+reason)
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
