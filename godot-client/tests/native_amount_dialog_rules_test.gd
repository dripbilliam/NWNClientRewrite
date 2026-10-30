extends SceneTree
const Amount=preload("res://systems/native_data/amount_dialog.gd")
var checks:=0
var failures: Array=[]
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures.append(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var output:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
	if output.is_empty() or FileAccess.file_exists(output): quit(2); return
	var source:=ProjectSettings.globalize_path("res://").path_join("../backups/animations/native-amount-dialog-observations-v2.json").simplify_path()
	var original: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(source))
	check(original.binarySha256=="3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a","Amount oracle uses the pinned original client")
	for row in original.amounts:
		var case: Dictionary=row.case; var expected: Variant=null
		for call in row.calls:
			if call[0]==("callback" if row.action=="confirm" else "text"): expected=int(call[1])
		var result: int=int(case.maximum) if row.action=="all" else Amount.confirmed(case.text,int(case.maximum)) if row.action=="confirm" else Amount.changed(case.text,int(case.maximum),1 if row.action=="up" else -1)
		check(expected!=null and result==expected,"Unchanged original amount arithmetic "+str(row.action)+" "+JSON.stringify(case))
		if row.action=="confirm": check(row.calls[-1][0]=="deactivate" and int(row.calls[-1][1])==0 and row.eventRestored,"Original confirmation deactivates and restores the event owner")
	for row in original.timers:
		var case: Dictionary=row.case; var result:=Amount.tick(int(case.elapsed),bool(case.initial),int(case.delta),case.held)
		var fired: bool=row.calls.any(func(call):return call[0]=="callback")
		check(result.elapsed==int(row.elapsed) and result.initial==bool(row.initial) and result.fired==fired,"Unchanged original timer tick "+JSON.stringify(case))
		check(row.eventRestored,"Timer callback restores the original event owner")
	for row in original.keys: check(Amount.accepts_character(int(row.case.code))==not row.calls.is_empty(),"Original numeric character gate "+str(row.case.code))
	check(int(original.constructor.period)==Amount.PERIOD_US and int(original.constructor.delay)==Amount.DELAY_US,"Original constructor supplies50ms period and500ms initial delay")
	check(int(original.down.elapsed)==0 and bool(original.down.initial) and original.down.calls.filter(func(call):return call[0]=="callback").size()==1,"Original mouse-down resets the timer and immediately invokes its repeat callback")
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"originalAmountCases":original.amounts.size(),"originalTimerCases":original.timers.size(),"originalCharacterCases":original.keys.size(),"publicConnections":0,"scope":"Original amount arithmetic/CRT C-locale decimal parsing, timer and character-gate boundaries. Full edit/clipboard/localized-keyboard behavior and every role/dialog remain separate acceptance."},"  ")+"\n"); file.close(); quit(0 if failures.is_empty() else 1)
