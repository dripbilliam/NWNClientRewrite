extends "res://tests/native_level_up_random_runtime_test.gd"
var packet_observations: Array=[]
func numeric_summary(begin: Dictionary,token: int,module: Dictionary,late: Dictionary={},edit: bool=false) -> bool:
	active_text.tables=active_rules;desktop.state.module=module.duplicate(true)
	var value:=begin.duplicate(true);value.token=token;panel.reset();panel.open();controller.receive_result(ReplyFixture.echo(desktop,{"accepted":true,"operation":"begin","result":value}))
	if not await ready("class"):return false
	entry_draws=int(runtime.hit_die_owner.stream.draws);await click(front.panes["class"].buttons.okbutton)
	if not await ready("attributes"):return false
	await click(front.panes.attributes.buttons.dexupbutton);await click(front.panes.attributes.buttons.okbutton)
	if not await ready("skills"):return false
	if edit:await click(front.panes.skills.buttons["up:0"])
	if not late.is_empty():desktop.state.module=late.duplicate(true)
	await click(front.panes.skills.buttons.okbutton)
	return await wait_for(func():return front.panes.has("summary") and front.panes.summary.wanted and front.panes.summary.content_ready and front.panes.summary.layout_ready)
func extra_cases(begin: Dictionary,received: Dictionary,before: Dictionary,tables: Dictionary) -> void:
	await super.extra_cases(begin,received,before,tables)
	var fixture_path:=""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--fixture="):fixture_path=argument.trim_prefix("--fixture=")
	var fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(fixture_path));var retained:=fixture.duplicate(true)
	var entries: Array=fixture.cases.filter(func(row):return int(row.revision)==37)
	check(entries.size()==4,"Actual decoded modern module packets cover all incoming force/hide bit combinations")
	for at in entries.size():
		var row: Dictionary=entries[at];var token:=101+at
		if not gate(await numeric_summary(begin,token,row.module),"Actual decoded numeric module flags enter source level4 controls "+str(at)):continue
		var stream=runtime.hit_die_owner.stream;var count: int=stream.draws;var state: int=stream.state;var die: int=private_owner.finalization.hitDie
		check(panel.source_active and not panel.visible and runtime.active and runtime.module_context.forceMaximum==row.expected.forceMaximum and runtime.module_context.hideHitPointGain==row.expected.hideHitPointGain,"Canonical numeric packet bits drive exact native module context without generic fallback "+str(at))
		check(count==entry_draws+1 and die==8 if row.expected.forceMaximum else count==entry_draws+1 and die>=4 and die<=8,"Numeric force-maximum applies only after the one required native draw "+str(at))
		check(private_owner.finalization.hiddenHitPointGain==row.expected.hideHitPointGain and (front.panes.summary.summary.contains(active_text.raw({"strRef":6389})+" : ?")==bool(row.expected.hideHitPointGain)),"Numeric hidden-gain bit affects actual native Summary text "+str(at))
		await click(front.panes.summary.buttons.okbutton);await click(front.panes.summary.buttons.okbutton)
		var sent: Array=desktop.commands.filter(func(command):return command.operation=="submit" and command.token==token)
		check(sent.size()==1 and sent[0].proposal.hitDie==die and stream.draws==count and stream.state==state,"Actual numeric-module Summary sends once with its prepared die and cannot reroll "+str(at))
		packet_observations.append({"token":token,"module":row.module.duplicate(true),"expected":row.expected.duplicate(),"hitDie":die,"receipt":runtime.hit_die_owner.receipt.duplicate(true)})
		await click(front.panes.summary.buttons.cancelbutton)
	var normal: Dictionary=entries[0].module;var forced_hidden: Dictionary=entries[3].module
	if gate(await numeric_summary(begin,110,normal,forced_hidden),"Numeric flags received after begin are used at current Summary finalization"):
		check(private_owner.finalization.hitDie==8 and private_owner.finalization.hiddenHitPointGain and runtime.hit_die_owner.plan.forceMaximum,"Current module reader observes raw numeric replacement rather than freezing begin-time values")
		await click(front.panes.summary.buttons.cancelbutton)
	if gate(await numeric_summary(begin,111,normal,{},true),"A current numeric-module source draft can retain manual skill edits"):
		var edited: Array=private_owner.skills.changes();var stream=runtime.hit_die_owner.stream;var draws: int=stream.draws;var state: int=stream.state;desktop.state.module=forced_hidden.duplicate(true);await click(front.panes.summary.buttons.okbutton)
		check(await wait_for(func():return not runtime.active and panel.visible) and controller.draft.skills==edited and edited[0]>0,"Changed numeric module rules retire stale Summary before submit while preserving private edits")
		check(stream.draws==draws and stream.state==state and desktop.commands.all(func(command):return command.operation!="submit" or command.token!=111),"Module replacement cannot submit under obsolete flags or consume a replacement draw")
		panel.reset()
	check(fixture==retained and received==before,"Actual packet modules and received actor snapshot remain byte-for-value unchanged")
	active_text.tables=tables;desktop.state.module={"serverFlags":{"field158":false,"field164":false}};observations.append({"kind":"actual-decoded-numeric-module-flags","cases":packet_observations})
