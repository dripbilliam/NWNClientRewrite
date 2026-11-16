extends SceneTree
const Messages=preload("res://systems/native_data/native_network_messages.gd")
const Inflater=preload("res://systems/native_data/native_network_inflater.gd")
const Updates=preload("res://systems/native_data/native_object_updates.gd")
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Parser=preload("res://systems/native_data/two_da.gd")
const ObjectRules=preload("res://systems/native_data/native_object_rules.gd")

func _initialize()->void:
	var path:=ProjectSettings.globalize_path("res://../backups/animations/local-network-character-v5.json")
	var fixture: Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
	if not fixture is Dictionary:fail("Original session fixture unavailable");return
	var expected: Array=[]
	for message in fixture.transport.messages:
		if message.get("kind")=="object-updates":expected.append(message)
	if expected.is_empty():fail("Original object updates unavailable");return
	var catalog:=Catalog.new()
	if not catalog.mount_install(ProjectSettings.globalize_path("res://../../FullDecomp/NwnRootInstall")):fail("Original install catalog unavailable: "+catalog.failure);return
	var tables: Dictionary={}
	for name in ["baseitems","classes","visualeffects","skills"]:
		var bytes: PackedByteArray=catalog.get_resource(name,2017)
		if bytes.is_empty():fail("Original "+name+" table unavailable");return
		tables[name]=Parser.new().parse(bytes.get_string_from_utf8())
	var rules:=ObjectRules.new()
	if not rules.configure(tables):fail("Original object rules unavailable");return
	var providers: Dictionary=rules.providers()
	var assembler:=Messages.new()
	for hex in fixture.transport.applicationFrames:assembler.push(str(hex).hex_decode())
	var inflater:=Inflater.new();var matched:=0
	for row in assembler.drain():
		var decoded: Dictionary=inflater.decode(row.bytes)
		if decoded.has("error"):fail(str(decoded.error));return
		var bytes: PackedByteArray=decoded.bytes
		if bytes.size()<3 or bytes[0]!=80 or bytes[1]!=5 or bytes[2]!=1:continue
		if matched>=expected.size():fail("Extra original object-update packet");return
		var actual: Dictionary=Updates.decode_packet(bytes,fixture.remote.build,providers)
		if actual.has("error"):fail("Packet "+str(matched)+": "+str(actual.error));return
		var original: Dictionary=expected[matched]
		var mismatch:=compare(actual.records.slice(0,original.records.size()),original.records,"packet["+str(matched)+"].records")
		if mismatch.is_empty() and not actual.complete:mismatch="packet["+str(matched)+"] remains incomplete"
		if not mismatch.is_empty():fail(mismatch+" "+str(actual.get("unhandled",{})));return
		matched+=1
	inflater.close()
	if matched!=expected.size():fail("Object-update packet count differs: "+str(matched)+"/"+str(expected.size()));return
	print("NWN79 Godot native object-update fixture PASS (",matched," packets)")
	quit(0)

func fail(reason: String)->void:
	printerr("NWN79 Godot object updates failed: "+reason)
	quit(1)

func compare(actual: Variant,expected: Variant,path: String)->String:
	if actual is Dictionary and expected is Dictionary:
		for key in expected:
			if not actual.has(key):return path+"."+str(key)+"(missing)"
			var mismatch:=compare(actual[key],expected[key],path+"."+str(key))
			if not mismatch.is_empty():return mismatch
		return ""
	if actual is Array and expected is Array:
		if actual.size()!=expected.size():return path+".length "+str(actual.size())+"/"+str(expected.size())
		for index in range(actual.size()):
			var mismatch:=compare(actual[index],expected[index],path+"["+str(index)+"]")
			if not mismatch.is_empty():return mismatch
		return ""
	if (actual is int or actual is float or actual is bool) and (expected is int or expected is float or expected is bool):
		return "" if absf(float(actual)-float(expected))<0.0001 else path+"="+str(actual)+"/"+str(expected)
	return "" if actual==expected else path+"="+str(actual)+"/"+str(expected)
