extends SceneTree
const Options = preload("res://systems/native_options.gd")
const Client = preload("res://systems/local_connection.gd")
class Probe extends Client:
	var sent: Array = []
	func send(value: Dictionary) -> void: sent.append(value.duplicate(true))
var checks := 0
var failures: Array = []
func check(value: bool, text: String) -> void:
	checks += 1
	if not value: failures.append(text)
func _initialize() -> void: call_deferred("run")
func click(point: Vector2) -> void:
	for pressed in [true,false]:
		var event := InputEventMouseButton.new(); event.position = point; event.global_position = point; event.button_index = MOUSE_BUTTON_LEFT; event.pressed = pressed
		root.push_input(event,true); await process_frame
func run() -> void:
	var output := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output = arg.trim_prefix("--report=")
	if output.is_empty() or FileAccess.file_exists(output): quit(2); return
	root.size = Vector2i(1000,850)
	var first := Options.new(); root.add_child(first); first.setup("",output + ".cfg"); first.show(); await process_frame; await process_frame
	check(first.floating_feedback and not first.damage_totals_only,"Absent preferences use the original floating/grouped defaults")
	var probe := Probe.new(); root.add_child(probe); probe.set_process(false); probe.options = first; probe.authenticated = true; probe.connection = 3
	first.feedback_preference.connect(func(_values): probe._send_feedback_preferences())
	await click(first.floating_toggle.get_global_rect().get_center())
	check(not first.floating_feedback and probe.sent.back().values == {"floatingFeedback":false,"damageTotalsOnly":false},"Actual native floating-feedback checkbox sends the complete updated local preference")
	await click(first.totals_toggle.get_global_rect().get_center())
	check(first.damage_totals_only and probe.sent.back().values.damageTotalsOnly,"Actual native total-only checkbox updates independently of disabled floating feedback")
	check(first.floating_toggle.focus_mode == Control.FOCUS_NONE and first.totals_toggle.focus_mode == Control.FOCUS_NONE,"Feedback toggles do not take keyboard text focus")
	first.hide(); first.free(); probe.options = null
	var second := Options.new(); root.add_child(second); second.setup("",output + ".cfg")
	check(not second.floating_feedback and second.damage_totals_only,"Both native feedback settings survive a new Options owner")
	probe.options = second; probe._send_feedback_preferences()
	check(probe.sent.back().values == second.feedback_values(),"A replacement connection can resynchronize the persisted complete preference")
	probe.receive({"kind":"feedback-options","connection":2,"values":{"floatingFeedback":true,"damageTotalsOnly":false}})
	check(probe.feedback_ack.is_empty(),"Retired connection acknowledgements cannot replace current preferences")
	probe.receive({"kind":"feedback-options","connection":3,"values":second.feedback_values()})
	check(probe.feedback_ack == second.feedback_values(),"Current local acknowledgement confirms applied preferences")
	probe.authenticated = false; var count := probe.sent.size(); probe._send_feedback_preferences()
	check(probe.sent.size() == count,"An unauthenticated native UI cannot send preferences")
	second.free(); probe.options = null; probe.free(); await process_frame
	var malformed := ConfigFile.new(); malformed.set_value("feedback","floating","false"); malformed.set_value("feedback","total_damage",1); malformed.save(output + ".malformed.cfg")
	var third := Options.new(); root.add_child(third); third.setup("",output + ".malformed.cfg")
	check(third.floating_feedback and not third.damage_totals_only,"Malformed preference types fall back to original defaults")
	third.free(); await process_frame; await process_frame
	var report := FileAccess.open(output,FileAccess.WRITE); report.store_string(JSON.stringify({"checks":checks,"failures":failures,"scope":"Authored native feedback controls, persistent ConfigFile and scoped local preference routing; not actual combat outcomes"},"\t")); report.close()
	quit(0 if failures.is_empty() else 1)
