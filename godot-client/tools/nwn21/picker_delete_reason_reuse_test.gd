extends SceneTree
class CountingLobby extends "res://systems/character_lobby.gd":
	var reason_calls:=0
	var reason_text:="Unavailable"
	func delete_reason() -> String:
		reason_calls+=1
		return reason_text
var checks:=0
var failures: Array=[]
func check(ok: bool,label: String)->void:
	checks+=1
	if not ok: failures.append(label)
func _initialize()->void: call_deferred("run")
func run()->void:
	var ui:=CountingLobby.new();root.add_child(ui);ui.preferences.open_file("");ui.enable_picker()
	ui.apply_state({"connection":1,"state":{"phase":"character-selection","connected":true,"canSelect":true,"selected":"server:one","choices":[{"key":"server:one","label":"One","source":"server","classes":[]}]}})
	await process_frame
	ui.reason_calls=0;ui.reason_text="Cannot delete this character";ui.picker.sync()
	check(ui.reason_calls==1,"One delete eligibility lookup per picker sync")
	check(ui.picker.shell.buttons.delete.disabled and ui.picker.shell.buttons.delete.tooltip_text==ui.reason_text,"Rejected delete keeps capability and tooltip in agreement")
	ui.reason_calls=0;ui.reason_text="";ui.picker.sync()
	check(ui.reason_calls==1,"Admitted delete also performs one lookup")
	check(not ui.picker.shell.buttons.delete.disabled and ui.picker.shell.buttons.delete.tooltip_text.is_empty(),"Admitted delete keeps capability and tooltip in agreement")
	ui.free()
	var report:={"success":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Picker eligibility and tooltip reuse in one synchronous presentation; no latency claim."}
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="):
			var file:=FileAccess.open(argument.substr(9),FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close()
	print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
