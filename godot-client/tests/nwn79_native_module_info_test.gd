extends SceneTree
const Messages=preload("res://systems/native_data/native_network_messages.gd")
const Inflater=preload("res://systems/native_data/native_network_inflater.gd")
const ModuleInfo=preload("res://systems/native_data/native_module_info.gd")
func _initialize()->void:
	var path:=ProjectSettings.globalize_path("res://../backups/animations/local-network-character-v2.json")
	var fixture: Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
	if not fixture is Dictionary:fail("Original module fixture unavailable");return
	var assembler:=Messages.new()
	for hex in fixture.transport.applicationFrames:assembler.push(str(hex).hex_decode())
	var inflater:=Inflater.new()
	var expected: Dictionary={}
	for message in fixture.transport.messages:
		if message.get("kind")=="module-info":expected=message.module;break
	if expected.is_empty():fail("Original module fields unavailable");return
	var found:=false
	var build: Dictionary=fixture.remote.build
	for row in assembler.drain():
		var result: Dictionary=inflater.decode(row.bytes)
		if result.has("error"):fail(str(result.error));return
		var bytes: PackedByteArray=result.bytes
		if bytes.size()<3 or bytes[0]!=80 or bytes[1]!=3 or bytes[2]!=1:continue
		var module: Dictionary=ModuleInfo.decode_packet(bytes,build)
		if module.has("error"):fail(str(module.error));return
		for key in ["resourceName","entryArea","officialCampaign"]:
			if module[key]!=expected[key]:fail("Original module field differs: "+key);return
		if module.areas.size()!=expected.areas.size():fail("Original module area count differs");return
		found=true
	inflater.close()
	if not found:fail("Original compressed module message missing");return
	print("NWN79 Godot native module-information fixture PASS")
	quit(0)
func fail(reason: String)->void:
	printerr("NWN79 Godot module information failed: "+reason)
	quit(1)
