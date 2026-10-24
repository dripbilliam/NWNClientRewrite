extends SceneTree
# Opt-in million-character widget stress. Native v2/v3 attempts are unaccepted:
# embedded NUL is not valid native text, and huge widget shaping exceeds the
# bounded test window. Passing the transport-only suite does not accept this.
const Manager = preload("res://systems/server_nui.gd")
const Packets = preload("res://systems/nui_packets.gd")
var checks := 0
var failures: Array = []
func _initialize() -> void: call_deferred("run")
func check(value: bool, name: String) -> void:
	checks += 1
	if not value: failures.append(name)
func run() -> void:
	var args: Dictionary = {}
	for arg in OS.get_cmdline_user_args():
		var parts := arg.trim_prefix("--").split("=", true, 1)
		if parts.size() == 2: args[parts[0]] = parts[1]
	if not args.has("report") or not args.has("fixture") or not args.has("input") or FileAccess.file_exists(args.report) or FileAccess.file_exists(args.input): quit(2); return
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(args.fixture))
	var layer := CanvasLayer.new(); root.add_child(layer)
	var manager := Manager.new(); root.add_child(manager); manager.setup(layer)
	check(data.messages.all(func(m): return JSON.stringify(m).to_utf8_buffer().size() < Packets.FRAME_BYTES), "Node output fragments fit the unchanged ordinary bridge frame limit")
	for message in data.messages: manager.receive(message)
	await process_frame; await process_frame
	var window = manager.windows.values()[0]; var label = window.nodes.values().filter(func(node): return node.spec.tag == "long")[0]
	check(label.widget.text.sha256_text() == data.textSha256, "A server control larger than one MiB reaches the native widget with exact Unicode text")
	check(window.nodes.size() == 3 and manager.json_packets.pending.is_empty(), "Large NUI text commits once without allocating extra hidden controls or retaining assembly bytes")
	var edit = window.nodes.values().filter(func(node): return node.spec.tag == "edit")[0]
	var received: Array = []; manager.request.connect(func(value): received.append(value))
	edit.widget.text = data.input; edit.widget.text_changed.emit(edit.widget.text)
	var message: Dictionary = received.filter(func(value): return value.get("operation") == "change").back(); message.connection = 1
	var codec := Packets.new(); var input: Array = codec.encode(message)
	check(JSON.stringify(message).to_utf8_buffer().size() > 1048576 and message.value.sha256_text() == data.inputSha256, "A real native edit emits an exact escaped payload beyond the single-frame limit")
	check(input.size() > 3 and input.all(func(value): return JSON.stringify(value).to_utf8_buffer().size() < Packets.FRAME_BYTES), "Native input fragments stay bounded without truncating the draft")
	var file := FileAccess.open(args.input, FileAccess.WRITE); file.store_string(JSON.stringify(input)); file.close()
	var begin: Dictionary = data.messages.filter(func(value): return value.kind == "nui-json-begin")[0]
	var first: Dictionary = data.messages.filter(func(value): return value.kind == "nui-json-part")[0]
	manager.receive(begin); manager.receive(first)
	check(not manager.json_packets.pending.is_empty(), "A partial large NUI projection remains staged")
	manager.reset(); await process_frame; await process_frame
	check(manager.json_packets.pending.is_empty() and manager.windows.is_empty(), "Connection reset releases staged large JSON as well as native controls")
	codec.receive(begin); codec.receive(first); var broken: Dictionary = data.messages.filter(func(value): return value.kind == "nui-json-end")[0].duplicate(); broken.transferId += 1
	check(codec.receive(broken) == null and not codec.failure.is_empty() and codec.pending.is_empty(), "Mismatched JSON completion releases staging without publishing a partial menu")
	var excessive := begin.duplicate(); excessive.bytes = Packets.PAYLOAD_BYTES + 1
	check(codec.receive(excessive) == null and not codec.failure.is_empty() and codec.pending.is_empty(), "Over-capacity metadata is rejected before accumulating data")
	manager.free(); layer.free(); await process_frame
	file = FileAccess.open(args.report, FileAccess.WRITE); file.store_string(JSON.stringify({"checks":checks,"passed":failures.is_empty(),"failures":failures,"input_packets":input.size(),"text_sha256":data.textSha256,"input_sha256":data.inputSha256},"\t")); file.close(); quit(0 if failures.is_empty() else 1)
