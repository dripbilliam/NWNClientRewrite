extends SceneTree
# Authored connection-scoped frame/resource races, using the production receiver.
const Connection = preload("res://systems/local_connection.gd")
const Manager = preload("res://systems/server_nui.gd")
var checks := 0
var failures: Array = []
func _initialize() -> void: call_deferred("run")
func check(value: bool, name: String) -> void:
	checks += 1
	if not value: failures.append(name)
func payload(color: Color) -> Dictionary:
	var image := Image.create(4, 4, false, Image.FORMAT_RGBA8); image.fill(color)
	var bytes := image.save_png_to_buffer(); var hash := HashingContext.new(); hash.start(HashingContext.HASH_SHA256); hash.update(bytes)
	var encoded := Marshalls.raw_to_base64(bytes); var split := encoded.length() / 2
	return {"bytes": bytes.size(), "sha256": hash.finish().hex_encode(), "parts": [encoded.left(split), encoded.substr(split)]}
func begin(client, connection: int, data: Dictionary) -> void:
	client.receive({"kind":"nui-resource-begin","connection":connection,"transferId":7,"resourceId":3,"parts":2,"bytes":data.bytes,"sha256":data.sha256,"meta":{"type":"image"}})
func part(client, connection: int, data: Dictionary, index: int) -> void:
	client.receive({"kind":"nui-resource-part","connection":connection,"transferId":7,"part":index,"data":data.parts[index]})
func frame(client, connection: int, text: String) -> void:
	client.receive({"kind":"nui-frame","connection":connection,"windowId":1,"version":1,"rootId":1,"title":"Pending frame","closable":true,"collapsible":false,"collapsed":false,"header":true,"transparent":false,"border":true,"acceptsInput":true,"resizable":false,"geometry":{"x":10,"y":10,"w":200,"h":100}})
	client.receive({"kind":"nui-nodes","connection":connection,"windowId":1,"version":1,"nodes":[{"controlId":1,"type":"label","tag":"label","index":-1,"children":[],"values":{"enabled":true,"visible":true,"label":text}}]})
func run() -> void:
	var output := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output = arg.substr(9)
	if output.is_empty() or FileAccess.file_exists(output): quit(2); return
	var layer := CanvasLayer.new(); root.add_child(layer)
	var manager := Manager.new(); root.add_child(manager); manager.setup(layer)
	# Receiver is deliberately unconfigured: this isolates its production NUI
	# connection guard without opening a socket or constructing the whole game.
	var client := Connection.new(); client.nui = manager; client.connection = 1
	var old := payload(Color.RED); var fresh := payload(Color.GREEN)
	begin(client, 1, old); part(client, 1, old, 0); frame(client, 1, "Old staged content")
	check(manager.transfers.size() == 1 and manager.resources.is_empty(), "A partial original connection transfer cannot publish an image")
	check(manager.windows.size() == 1 and manager.windows[1].nodes.is_empty(), "A staged NUI frame is not committed early")
	manager.reset(); client.connection = 3; await process_frame; await process_frame
	check(manager.transfers.is_empty() and manager.windows.is_empty() and manager.resources.is_empty(), "Connection reset discards pending image fragments and staged native frames")
	begin(client, 3, fresh); part(client, 3, fresh, 0); frame(client, 3, "Fresh committed content")
	part(client, 1, old, 1); client.receive({"kind":"nui-resource-end","connection":1,"transferId":7})
	client.receive({"kind":"nui-commit","connection":1,"windowId":1,"version":1})
	check(manager.transfers[7].parts.size() == 1 and manager.resources.is_empty() and manager.statistics.failed == 0, "Old connection fragments cannot corrupt a colliding new transfer ID")
	check(manager.windows[1].nodes.is_empty(), "An old commit cannot publish a colliding new window/version")
	part(client, 3, fresh, 1); client.receive({"kind":"nui-resource-end","connection":3,"transferId":7})
	client.receive({"kind":"nui-commit","connection":3,"windowId":1,"version":1}); await process_frame
	check(manager.resources[3].get_image().get_pixel(0, 0) == Color.GREEN and manager.transfers.is_empty(), "Only the complete new connection image passes digest verification and native decoding")
	check(manager.windows[1].nodes[1].widget.text == "Fresh committed content", "Only the new connection commits the reused native window")
	manager.reset(); await process_frame; await process_frame
	check(manager.retired_state().windows == 0 and manager.retired_state().resources == 0, "New resources and popup-capable window owners retire without retained references")
	client.free(); manager.free(); layer.free(); await process_frame
	var file := FileAccess.open(output, FileAccess.WRITE); file.store_string(JSON.stringify({"checks":checks,"passed":failures.is_empty(),"failures":failures},"\t")); file.close(); quit(0 if failures.is_empty() else 1)
