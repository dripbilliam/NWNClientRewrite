extends SceneTree
const Messages=preload("res://systems/native_data/native_network_messages.gd")
const Inflater=preload("res://systems/native_data/native_network_inflater.gd")
func _initialize()->void:
	var path:=ProjectSettings.globalize_path("res://../backups/animations/local-network-character-v1.json")
	var fixture: Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
	if not fixture is Dictionary:fail("Original compressed capture unavailable");return
	var messages:=Messages.new()
	for hex in fixture.transport.applicationFrames:
		if not messages.push(str(hex).hex_decode()):fail("Original frame invalid");return
	var inflater:=Inflater.new()
	var found:=false
	for row in messages.drain():
		var record: PackedByteArray=row.bytes
		var decoded: Dictionary=inflater.decode(record)
		if decoded.has("error"):fail(str(decoded.error));return
		if record.size()<16 or (int(record[7]) & 4)==0:continue
		if decoded.bytes.size()!=157 or decoded.bytes.slice(0,3)!=PackedByteArray([80,3,1]):fail("Original persistent zlib output differs");return
		found=true
	inflater.close()
	if not found:fail("No compressed native fixture");return
	var block_source: PackedByteArray="block".to_utf8_buffer().compress(FileAccess.COMPRESSION_DEFLATE)
	var block:=PackedByteArray();block.resize(16);block[7]=4;block.encode_u32(12,5);block.append_array(block_source)
	var block_decoded: Dictionary=Inflater.new().decode(block)
	if block_decoded.has("error") or block_decoded.bytes.get_string_from_ascii()!="block":fail("Independent block zlib message differs");return
	print("NWN79 Godot native persistent zlib fixture PASS")
	quit(0)
func fail(reason: String)->void:
	printerr("NWN79 Godot native inflater failed: "+reason)
	quit(1)
