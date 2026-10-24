extends SceneTree
const Manager = preload("res://systems/server_nui.gd")
var checks := 0
var failures: Array = []
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message)
func run() -> void:
	var args: Dictionary = {}
	for arg in OS.get_cmdline_user_args():
		var pair := arg.trim_prefix("--").split("=", true, 1)
		if pair.size() == 2: args[pair[0]] = pair[1]
	if not args.has("report") or not args.has("fixture") or FileAccess.file_exists(args.report): quit(2); return
	if DisplayServer.get_name() == "headless": quit(2); return
	root.size = Vector2i(700, 240)
	RenderingServer.set_default_clear_color(Color.BLACK)
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(args.fixture))
	var layer := CanvasLayer.new(); root.add_child(layer)
	var manager := Manager.new(); root.add_child(manager); manager.setup(layer)
	for message in fixture.messages: manager.receive(message)
	await process_frame; await process_frame
	var window = manager.windows.values()[0]
	var element = window.nodes.values()[0]
	check(element.foreground.commands.size() == fixture.cases.size() + 8, "All eight primitives reach the production drawing canvas with nullable numeric fields")
	var projected_pixels: Image
	for raw in [false, true]:
		if raw:
			element.background.commands = fixture.raw
			element.foreground.commands = fixture.raw
			element.background.queue_redraw(); element.foreground.queue_redraw()
		await process_frame; await RenderingServer.frame_post_draw
		var pixels := root.get_texture().get_image()
		if not raw: projected_pixels = pixels
		else:
			check(projected_pixels.get_data() == pixels.get_data(), "Raw nullable fields draw exactly the same pixels as normalized finite defaults")
		for index in fixture.cases.size():
			var row: Dictionary = fixture.cases[index]
			var center: Vector2 = element.foreground.global_position + Vector2(28 + index * 48, 28)
			var color := pixels.get_pixelv(Vector2i(center))
			check((color.r > 0.8 and color.g < 0.1) == row.expected, ("raw" if raw else "projected") + " draw-fill center: " + row.name)
			var edge: Vector2 = element.foreground.global_position + Vector2(10 + index * 48, 28)
			check(pixels.get_pixelv(Vector2i(edge)).r > 0.5, ("raw" if raw else "projected") + " retains outline: " + row.name)
		if raw: pixels.save_png(args.report.get_basename() + ".png")
	manager.reset(); await process_frame; await process_frame
	check(manager.retired_state().windows == 0 and manager.retired_state().resources == 0, "Retirement releases all regression window/resource owners")
	manager.free(); layer.free(); await process_frame
	var file := FileAccess.open(args.report, FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed": failures.is_empty(), "checks": checks, "failures": failures, "gpu": true, "scope": fixture.scope}, "\t")); file.close()
	quit(0 if failures.is_empty() else 1)
