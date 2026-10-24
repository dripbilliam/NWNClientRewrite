extends SceneTree
# Cross-language transport only. Does not accept huge visible-widget layout.
const Packets = preload("res://systems/nui_packets.gd")
const Manager = preload("res://systems/server_nui.gd")
var checks := 0
var failures: Array = []
func _initialize() -> void: call_deferred("run")
func check(value: bool, name: String) -> void:
	checks += 1
	if not value: failures.append(name)
func run() -> void:
	var args: Dictionary = {}
	for arg in OS.get_cmdline_user_args():
		var pair := arg.trim_prefix("--").split("=", true, 1)
		if pair.size() == 2: args[pair[0]] = pair[1]
	if not args.has("report") or not args.has("fixture") or not args.has("input") or FileAccess.file_exists(args.report) or FileAccess.file_exists(args.input): quit(2); return
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(args.fixture))
	var codec := Packets.new(); var messages: Array = []
	check(data.messages.all(func(m): return JSON.stringify(m).to_utf8_buffer().size() < Packets.FRAME_BYTES), "Node NUI fragments fit the unchanged bridge limit")
	for message in data.messages:
		if str(message.kind).begins_with("nui-json-"):
			var decoded: Variant = codec.receive(message)
			if decoded != null: messages.append(decoded)
		else: messages.append(message)
	var nodes: Array = []
	for message in messages:
		if message.kind == "nui-nodes": nodes.append_array(message.nodes)
	var label: Dictionary = nodes.filter(func(node): return node.tag == "long")[0]
	var edit: Dictionary = nodes.filter(func(node): return node.tag == "edit")[0]
	var content: String = label.values.tooltip if data.get("tooltip", false) else label.values.label
	check(content.sha256_text() == data.textSha256 and content.to_utf8_buffer().size() > 1048576, "Node-to-Godot reassembly preserves a description larger than one MiB exactly")
	check(codec.pending.is_empty() and codec.failure.is_empty(), "Complete projection releases JSON assembly storage")
	if data.get("tooltip", false):
		var layer := CanvasLayer.new(); root.add_child(layer)
		var manager := Manager.new(); root.add_child(manager); manager.setup(layer)
		for packet in data.messages: manager.receive(packet)
		await process_frame; await process_frame
		var window = manager.windows.values()[0]; var native_label = window.nodes[int(label.controlId)]
		check(native_label.tooltip_text.sha256_text() == data.textSha256 and native_label.widget.text == "Authored large tooltip", "The production native manager commits the exact large tooltip to its real widget owner")
		manager.reset(); await process_frame; await process_frame
		check(manager.json_packets.pending.is_empty() and manager.retired_state().windows == 0, "Reset retires the large-payload widget and its assembly owner")
		manager.free(); layer.free(); await process_frame
	var message := {"kind":"nui-input","operation":"change","connection":1,"windowId":1,"controlId":edit.controlId,"inputRevision":1,"value":data.input}
	var input: Array = codec.encode(message)
	check(JSON.stringify(message).to_utf8_buffer().size() > 1048576 and message.value.sha256_text() == data.inputSha256, "Godot prepares an exact escaped draft larger than the single-frame capacity")
	check(input.size() > 3 and input.all(func(value): return JSON.stringify(value).to_utf8_buffer().size() < Packets.FRAME_BYTES), "Godot-to-Node input fragments remain bounded and lossless")
	var file := FileAccess.open(args.input, FileAccess.WRITE); file.store_string(JSON.stringify(input)); file.close()
	var begin: Dictionary = data.messages.filter(func(value): return value.kind == "nui-json-begin")[0]
	var first: Dictionary = data.messages.filter(func(value): return value.kind == "nui-json-part")[0]
	codec.receive(begin); codec.receive(first)
	check(not codec.pending.is_empty(), "A partial large NUI projection remains staged")
	codec.reset(); check(codec.pending.is_empty(), "Connection retirement releases partially assembled large JSON")
	codec.receive(begin); codec.receive(first); var broken: Dictionary = data.messages.filter(func(value): return value.kind == "nui-json-end")[0].duplicate(); broken.transferId += 1
	check(codec.receive(broken) == null and not codec.failure.is_empty() and codec.pending.is_empty(), "Mismatched JSON completion rejects partial content and releases staging")
	var excessive := begin.duplicate(); excessive.bytes = Packets.PAYLOAD_BYTES + 1
	check(codec.receive(excessive) == null and not codec.failure.is_empty() and codec.pending.is_empty(), "Over-capacity metadata is rejected before accumulation")
	file = FileAccess.open(args.report, FileAccess.WRITE); file.store_string(JSON.stringify({"scope":"Authored cross-language transport only; huge visible widget layout remains unaccepted","checks":checks,"passed":failures.is_empty(),"failures":failures,"input_packets":input.size(),"text_sha256":data.textSha256,"input_sha256":data.inputSha256},"\t")); file.close(); quit(0 if failures.is_empty() else 1)
