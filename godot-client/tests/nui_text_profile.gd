extends SceneTree
# Investigation only: timed real-widget operations, no acceptance promotion.
var output: FileAccess
var count := 20000
var ascii := false
var selected := "all"
var bulk := false
var explicit_fallback := false
var style_first := false
var edit_document := false
var pattern := "mixed"
func _initialize() -> void: call_deferred("run")
func record(stage: String, began: int) -> void:
	output.store_line(JSON.stringify({"stage":stage,"milliseconds":(Time.get_ticks_usec()-began)/1000.0,"characters":count,"ascii":ascii,"pattern":pattern,"bulk":bulk,"style_first":style_first,"explicit_fallback":explicit_fallback,"edit_document":edit_document,"engine":Engine.get_version_info().string,"display":DisplayServer.get_name(),"text_server":TextServerManager.get_primary_interface().get_name()})); output.flush()
func run() -> void:
	var filename := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): filename = arg.trim_prefix("--report=")
		elif arg.begins_with("--characters="): count = int(arg.trim_prefix("--characters="))
		elif arg.begins_with("--kind="): selected = arg.trim_prefix("--kind=")
		elif arg == "--ascii": ascii = true
		elif arg == "--bulk": bulk = true
		elif arg == "--explicit-fallback": explicit_fallback = true
		elif arg == "--style-first": style_first = true
		elif arg == "--edit": edit_document = true
		elif arg.begins_with("--pattern="): pattern = arg.trim_prefix("--pattern=")
	if filename.is_empty() or FileAccess.file_exists(filename) or count < 1 or count > 2000000: quit(2); return
	output = FileAccess.open(filename, FileAccess.WRITE); root.size = Vector2i(1200, 850)
	var patterns := {"mixed":"é💎\\ \"", "bmp":"éßΩ\\ ", "astral":"💎", "rtl":"عربى ", "zwj":"👨‍👩‍👧‍👦 "}
	if not patterns.has(pattern): quit(2); return
	var unit: String = "abcdef " if ascii else patterns[pattern]
	var profile_font: Font = ThemeDB.fallback_font.duplicate()
	if explicit_fallback:
		var fallback := SystemFont.new(); fallback.font_names = PackedStringArray(["Segoe UI Emoji"]); fallback.allow_system_fallback = false; profile_font.fallbacks = [fallback]
	var text := unit.repeat(ceili(count/float(unit.length()))).left(count)
	for kind in ["label", "lineedit", "textedit", "richtext"]:
		if selected != "all" and selected != kind: continue
		var widget: Control
		if kind == "label": widget = Label.new(); widget.clip_text = true
		elif kind == "lineedit": widget = LineEdit.new(); widget.max_length = 2000000
		elif kind == "textedit": widget = TextEdit.new(); widget.wrap_mode = TextEdit.LINE_WRAPPING_NONE
		else: widget = RichTextLabel.new(); widget.fit_content = false
		widget.size = Vector2(780, 40); root.add_child(widget)
		var began := Time.get_ticks_usec(); record(kind+":before_text", began)
		if not style_first: widget.text = text
		record(kind+":assigned", began)
		began = Time.get_ticks_usec()
		if bulk: widget.begin_bulk_theme_override()
		for name in (["normal_font", "bold_font", "italics_font", "bold_italics_font", "mono_font"] if kind == "richtext" else ["font"]) if bulk else ["font", "normal_font", "bold_font", "italics_font", "bold_italics_font", "mono_font"]: widget.add_theme_font_override(name, profile_font)
		for name in (["normal_font_size", "bold_font_size", "italics_font_size", "bold_italics_font_size", "mono_font_size"] if kind == "richtext" else ["font_size"]) if bulk else ["font_size", "normal_font_size", "bold_font_size", "italics_font_size", "bold_italics_font_size", "mono_font_size"]: widget.add_theme_font_size_override(name, 17)
		if bulk: widget.end_bulk_theme_override()
		record(kind+":styled", began); began = Time.get_ticks_usec()
		if style_first: widget.text = text
		record(kind+":assigned_after_style", began); began = Time.get_ticks_usec()
		widget.size = Vector2(780,40); await process_frame; await process_frame; record(kind+":laid_out", began)
		if edit_document and widget is LineEdit:
			began = Time.get_ticks_usec(); widget.caret_column = text.length(); record(kind+":caret", began)
			began = Time.get_ticks_usec(); widget.insert_text_at_caret("Ω"); record(kind+":edited", began)
		began = Time.get_ticks_usec(); widget.text = ""; widget.free(); record(kind+":released", began)
	output.close(); quit(0)
