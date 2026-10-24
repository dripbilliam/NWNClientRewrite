extends SceneTree
const Frames = preload("res://systems/bridge_frames.gd")
var checks := 0
var failures: Array = []
func expect(value: bool, name: String) -> void:
	checks += 1
	if not value:
		failures.append(name)
func _initialize() -> void:
	var input := ""
	var output := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--fixture="):
			input = arg.substr(10)
		elif arg.begins_with("--report="):
			output = arg.substr(9)
	var bytes := FileAccess.get_file_as_bytes(input)
	for width in [1, 2, 3, 7, 31, 256, 65536]:
		var decoder := Frames.new()
		var messages: Array = []
		for at in range(0, bytes.size(), width):
			messages.append_array(decoder.feed(bytes.slice(at, mini(at + width, bytes.size()))))
		expect(decoder.failure.is_empty() and decoder.pending.is_empty() and messages.size() == 3, "Mixed binary/UTF8 JSON frames preserve boundaries for chunks of %s bytes" % width)
		expect(messages[0].text == "é·" and messages[1].kind == "particle-stream" and messages[2].kind == "particle-complete", "Binary data cannot inject a JSON command")
		var stream: Dictionary = messages[1].streams[0]
		expect(int(messages[1].areaId) == 2147483649 and int(messages[1].epoch) == 7 and int(stream.row.id) == 11, "Unsigned scope and particle identity survive framing")
		expect(stream.positions.size() == 1152 and stream.attributes.size() == 1152 and stream.attributes[0] == 10, "Raw attribute newlines are not interpreted as frame delimiters")
		expect(is_equal_approx(stream.positions.decode_float(4), 0.125), "Position bytes remain little-endian float32")
	for malformed in [PackedByteArray([0x89, 0, 0, 0, 4, 0, 0, 0]), PackedByteArray([0x89, 0x50, 0x41, 0x52, 0xff, 0xff, 0xff, 0x7f]), "null\n".to_utf8_buffer(), "{\"kind\":\"particle-stream\"}\n".to_utf8_buffer()]:
		var decoder := Frames.new()
		expect(decoder.feed(malformed).is_empty() and not decoder.failure.is_empty() and decoder.pending.is_empty(), "Malformed/oversized binary or non-object/spoofed JSON is rejected")
		decoder.feed(bytes)
		expect(decoder.pending.is_empty(), "Failed transport cannot resume with later bytes")
	var oversized := PackedByteArray()
	oversized.resize(1048577)
	oversized.fill(65)
	var decoder := Frames.new()
	decoder.feed(oversized)
	expect(not decoder.failure.is_empty(), "Unterminated JSON remains bounded")
	var result := {"passed": failures.is_empty(), "checks": checks, "failures": failures, "scope": "Actual private bridge decoder with authored mixed binary/JSON packets, byte fragmentation and bounded rejection"}
	if not output.is_empty():
		var file := FileAccess.open(output, FileAccess.WRITE)
		file.store_string(JSON.stringify(result, "\t") + "\n")
	print(JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)
