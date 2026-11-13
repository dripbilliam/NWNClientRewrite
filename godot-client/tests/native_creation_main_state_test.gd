extends "res://tests/native_particle_schedule_test.gd"
const Flow=preload("res://systems/native_data/creation_main_state.gd")
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("report") or not args.has("oracle") or FileAccess.file_exists(args.report): quit(2); return
	var original: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(args.oracle)); check(original.target==BINARY_SHA,"Original creator callbacks pin the verified binary")
	var flow:=Flow.new()
	for row in original.cases:
		flow.load_state(row.input); flow.result(int(row.input.code),row.input); var diff:=same(flow.snapshot(),row.output)
		check(diff.is_empty(),"Original creator callback "+str([row.input.code,row.input.customizeMode,row.input.recommended])+": "+diff)
	for row in original.resets:
		flow.load_state(row.input); flow.reset(); var diff:=same(flow.snapshot(),row.output)
		check(diff.is_empty(),"Original creator reset "+str(row.input.recommended)+": "+diff)
	flow.initialize(); check(flow.enabled.gender and not flow.enabled.portrait and flow.recommended=="gender" and not flow.completed.gender,"Initial source parent encourages Gender and gates dependent choices")
	var before:=flow.snapshot(); flow.result(0x80000002,{})
	check(flow.snapshot()==before,"The original ignored callback is normalized as signed32 even when supplied as an unsigned alias")
	var classes: Array=[]; classes.resize(7)
	for index in classes.size(): classes[index]={}
	classes[6]={"AlignRestrict":"21","AlignRstrctType":"3","InvertRestrict":"0"}
	check(Flow.paladin_rule_default(classes),"The stock Paladin shortcut reads active classes.2da restriction fields")
	classes[6].AlignRestrict="20"; check(not Flow.paladin_rule_default(classes),"Server replacement of the Paladin alignment mask removes the stock shortcut")
	classes[6].AlignRestrict="21"; classes[6].InvertRestrict="1"; check(not Flow.paladin_rule_default(classes),"Server replacement of alignment inversion removes the stock shortcut")
	classes[6].AlignRestrict="277"; classes[6].AlignRstrctType="259"; classes[6].InvertRestrict="0"
	check(Flow.paladin_rule_default(classes),"Original class loading stores alignment mask/type as bytes and inversion as an integer")
	check(not Flow.paladin_rule_default([]),"Absent active class data never implies stock alignment rules")
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"callback_cases":original.cases.size(),"reset_cases":original.resets.size(),"publicConnections":0,"scope":"Unchanged original CG_MAIN callback/reset state and emitted helper boundaries, plus active class-rule shortcut selection. No original GUI pixels, full creator integration, draft normalization or server admission acceptance."}
	var file:=FileAccess.open(args.report,FileAccess.WRITE); file.store_string(JSON.stringify(result,"\t")); file.close(); quit(0 if result.success else 1)
