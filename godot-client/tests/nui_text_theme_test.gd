extends SceneTree
# Production theme/element regression: count actual native notifications and
# retain Unicode editing semantics. Timings are diagnostics, not FPS acceptance.
const Manager = preload("res://systems/server_nui.gd")
class ThemeProbe extends LineEdit:
	var changes := 0
	func _notification(what: int) -> void:
		if what == NOTIFICATION_THEME_CHANGED: changes += 1
var checks := 0
var failures: Array = []
var observations: Dictionary = {}
var trace: FileAccess
var theme_only := false
func _initialize() -> void: call_deferred("run")
func check(ok: bool, name: String) -> void:
	checks += 1
	if not ok: failures.append(name)
	if trace != null: trace.store_line(JSON.stringify({"check":checks,"passed":ok,"name":name})); trace.flush()
func run() -> void:
	var output := ""
	var fixture := "res://reports/nui-ui-fixture-v2.json"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output = arg.trim_prefix("--report=")
		elif arg.begins_with("--fixture="): fixture = arg.trim_prefix("--fixture=")
		elif arg == "--theme-only": theme_only = true
	if output.is_empty() or FileAccess.file_exists(output): quit(2); return
	trace = FileAccess.open(output + ".stages.jsonl", FileAccess.WRITE)
	root.size = Vector2i(1440, 1000)
	var layer := CanvasLayer.new(); root.add_child(layer)
	var manager := Manager.new(); root.add_child(manager); manager.setup(layer)
	var probe := ThemeProbe.new(); layer.add_child(probe); await process_frame
	probe.changes = 0
	manager.style(probe, "textedit", "(default)", null)
	check(probe.changes == 1, "A complete editor skin publishes one native theme notification")
	check(probe.has_theme_font_override("font") and not probe.has_theme_font_override("normal_font"), "Ordinary controls override only their native font item")
	probe.changes = 0; manager.style(probe, "textedit", "(default)", null)
	check(probe.changes == 0, "Unchanged skin refresh does not reshape native text")
	var rich := RichTextLabel.new(); layer.add_child(rich); manager.style(rich, "text", "(default)", null)
	check(["normal_font", "bold_font", "italics_font", "bold_italics_font", "mono_font"].all(func(name): return rich.get_theme_font(name) == manager.font_for("(default)")), "All rich-text font faces retain the selected original font")
	check(["normal_font_size", "bold_font_size", "italics_font_size", "bold_italics_font_size", "mono_font_size"].all(func(name): return rich.get_theme_font_size(name) == 17), "All rich-text sizes remain native theme values")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(fixture))
	for message in data.messages: manager.receive(message)
	await process_frame; await process_frame
	var window = manager.windows.values()[0]
	var edit = window.nodes.values().filter(func(node): return node.spec.tag == "edit")[0]
	var text := "é💎\\ \"".repeat(4000)
	var row: Dictionary = edit.spec.duplicate(true); row.values.max = 1000000; row.values.value = text
	var began := Time.get_ticks_usec(); edit.apply(row); await process_frame
	observations.assignment_ms = (Time.get_ticks_usec()-began)/1000.0
	check(edit.widget.text == text and edit.widget.text.length() == 20000, "Production native editor preserves all 20,000 Unicode characters")
	check(edit.widget.max_length == 1000000, "Incoming document uses its authoritative length limit before text assignment")
	edit.widget.caret_column = 10; edit.widget.select(2, 9)
	var received: Array = []; manager.request.connect(func(value): received.append(value))
	manager.theming.invalidate(); began = Time.get_ticks_usec()
	manager.style(edit.widget, "textedit", "(default)", {"r":31,"g":200,"b":90,"a":255})
	observations.restyle_ms = (Time.get_ticks_usec()-began)/1000.0
	check(edit.widget.text == text, "Skin changes never truncate or replace the canonical document")
	check(edit.widget.caret_column == 10 and edit.widget.get_selection_from_column() == 2 and edit.widget.get_selection_to_column() == 9, "Theme updates preserve editor caret and selection")
	check(edit.widget.get_selected_text() == text.substr(2, 7), "Selection remains Unicode-indexed after a theme update")
	check(received.is_empty(), "Styling and authoritative text assignment do not emit spurious input")
	edit.apply(row)
	check(edit.widget.caret_column == 10 and edit.widget.has_selection(), "Repeated authoritative projection retains the active native selection")
	if theme_only:
		# The default full test deliberately retains the isolated native large-
		# Unicode insertion failure. This scope accepts only theme behavior.
		await finish(manager, layer, probe, rich, output); return
	edit.widget.deselect(); edit.widget.grab_focus(); edit.widget.caret_column = text.length()
	for pressed in [true, false]:
		var key := InputEventKey.new(); key.unicode = "Ω".unicode_at(0); key.pressed = pressed
		root.push_input(key, true); await process_frame
	check(edit.widget.text == text + "Ω", "Editing after a large Unicode document retains the complete prefix")
	check(received.any(func(value): return value.get("operation") == "change" and value.get("value") == text + "Ω" and int(value.get("inputRevision", 0)) == 1), "Native editor input carries its complete typed value and revision through the private control")
	edit.apply(row)
	check(edit.widget.text == text + "Ω", "An older server projection cannot overwrite the newer native draft")
	row.values.inputAck = 1; row.values.value = "Authoritative replacement"; edit.apply(row)
	check(edit.widget.text == "Authoritative replacement", "Acknowledged server replacements remain authoritative")
	await finish(manager, layer, probe, rich, output)
func finish(manager, layer, probe, rich, output: String) -> void:
	manager.reset(); probe.free(); rich.free(); await process_frame; await process_frame
	check(manager.windows.is_empty() and int(manager.retired_state().windows) == 0, "Text owners retire with the rest of their connection")
	manager.free(); layer.free(); await process_frame
	var file := FileAccess.open(output, FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"passed":failures.is_empty(),"failures":failures,"observations":observations,"scope":"theme-only" if theme_only else "theme-and-native-edit","large_edit_accepted":false}, "\t")); file.close()
	trace.close()
	quit(0 if failures.is_empty() else 1)
