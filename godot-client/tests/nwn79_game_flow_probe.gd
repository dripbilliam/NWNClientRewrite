extends SceneTree
const Messages=preload("res://systems/native_data/native_network_messages.gd")
const Inflater=preload("res://systems/native_data/native_network_inflater.gd")
func _initialize()->void:
	var name: String="local-network-character-v1"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--fixture="):
			var choice:=argument.trim_prefix("--fixture=")
			if choice in ["local-network-character-v1","local-network-character-v2","local-network-character-v3","local-network-character-v5"]:name=choice
	var path:=ProjectSettings.globalize_path("res://../backups/animations/"+name+".json")
	var fixture: Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
	if not fixture is Dictionary:quit(1);return
	var assembler:=Messages.new()
	for hex in fixture.transport.applicationFrames:assembler.push(str(hex).hex_decode())
	var inflater:=Inflater.new()
	var kinds: Array[String]=[]
	for row in assembler.drain():
		var result: Dictionary=inflater.decode(row.bytes)
		if result.has("error"):print("NWN79 game flow decode error: ",result.error);quit(1);return
		var bytes: PackedByteArray=result.bytes
		if bytes.size()>=3 and bytes[0]==80:kinds.append(str(bytes[1])+"/"+str(bytes[2])+"("+str(bytes.size())+")")
	print("NWN79 ",name," message count=",kinds.size()," sequence: "," ".join(kinds.slice(0,80)))
	inflater.close();quit(0)
