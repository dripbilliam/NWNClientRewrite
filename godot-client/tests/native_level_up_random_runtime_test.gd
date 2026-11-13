extends "res://tests/native_level_up_recommended_test.gd"
var active_rules: Dictionary={}
var entry_draws:=0
var roll_observations: Array=[]
func summary(begin: Dictionary,token: int,force: bool,hide: bool,edit_skill: bool=false,change_before_finish: bool=false) -> bool:
	active_text.tables=active_rules;desktop.state.module={"serverFlags":{"field158":force,"field164":hide}}
	var value:=begin.duplicate(true);value.token=token;panel.reset();panel.open();controller.receive_result(ReplyFixture.echo(desktop,{"accepted":true,"operation":"begin","result":JSON.parse_string(JSON.stringify(value))}))
	if not await ready("class"):return false
	entry_draws=int(runtime.hit_die_owner.stream.draws);await click(front.panes["class"].buttons.okbutton)
	if not await ready("attributes"):return false
	await click(front.panes.attributes.buttons.dexupbutton);await click(front.panes.attributes.buttons.okbutton)
	if not await ready("skills"):return false
	if edit_skill:await click(front.panes.skills.buttons["up:0"])
	if change_before_finish:desktop.state.module={"serverFlags":{"field158":true,"field164":true}}
	await click(front.panes.skills.buttons.okbutton)
	return await wait_for(func():return front.panes.has("summary") and front.panes.summary.wanted and front.panes.summary.layout_ready and front.panes.summary.content_ready)
func extra_cases(begin: Dictionary,received: Dictionary,before: Dictionary,tables: Dictionary) -> void:
	cancel_on_press=false;active_rules=tables.duplicate();active_rules.ruleset=tables.ruleset.duplicate(true)
	for row in active_rules.ruleset.orderedRows:
		if row.Label=="MIN_LEVEL_FOR_MAX_HP":row.Value="3"
	if not gate(await summary(begin,71,false,false),"Actual original-threshold level4 Class→Attributes→Skills→Summary stays in native controls"):return
	var stream=runtime.hit_die_owner.stream;var receipt: Dictionary=runtime.hit_die_owner.receipt.duplicate(true);var ticket: Array=private_owner.navigation.ticket.duplicate();var state: int=stream.state;var count: int=stream.draws
	check(count==entry_draws+1 and receipt.hitDie>=4 and receipt.hitDie<=8 and private_owner.finalization.hitDie==receipt.hitDie and not receipt.serverAcknowledged,"Native Summary owns one original-range client-proposed die and no fabricated acceptance")
	roll_observations.append({"token":71,"receipt":receipt.duplicate(true),"plan":runtime.hit_die_owner.plan.duplicate()})
	runtime.finalize({},ticket);runtime.reopen();await frames()
	check(stream.state==state and stream.draws==count and private_owner.finalization.hitDie==receipt.hitDie,"Duplicate current finalization and surface reopen reuse the same roll")
	await click(front.panes.summary.buttons.cancelbutton)
	check(not panel.wanted and stream.state==state and stream.draws==count and desktop.commands.any(func(value):return value.operation=="cancel" and value.token==71),"Physical Summary Cancel sends existing typed cancellation without restoring the random stream")
	if not gate(await summary(begin,72,true,false),"Fresh level4 draft uses received force-maximum rules"):return
	stream=runtime.hit_die_owner.stream;count=stream.draws;state=stream.state
	check(count==entry_draws+1 and private_owner.finalization.hitDie==8 and runtime.hit_die_owner.receipt.randomCalls==1,"Force-maximum still consumes exactly one original draw before overriding its value")
	roll_observations.append({"token":72,"receipt":runtime.hit_die_owner.receipt.duplicate(true),"plan":runtime.hit_die_owner.plan.duplicate()})
	await click(front.panes.summary.buttons.okbutton);await click(front.panes.summary.buttons.okbutton)
	var submitted: Array=desktop.commands.filter(func(value):return value.operation=="submit" and value.token==72)
	check(submitted.size()==1 and submitted[0].proposal.hitDie==8 and stream.draws==count and stream.state==state,"Actual source Summary emits one typed current-token proposal with its prepared die")
	controller.receive_result(ReplyFixture.echo(desktop,{"accepted":true,"operation":"submit","result":{"accepted":false}}));runtime.finalize({},private_owner.navigation.ticket);await frames()
	check(runtime.active and front.panes.summary.submitted and private_owner.navigation.result_received and stream.draws==count and not front.panes.summary.buttons.cancelbutton.disabled,"Authored rejection/duplicate finalize cannot reroll or re-enable submitted Summary")
	await click(front.panes.summary.buttons.cancelbutton)
	if not gate(await summary(begin,73,false,true,true),"Received hidden-gain level4 Summary prepares with private skill edits"):return
	stream=runtime.hit_die_owner.stream;count=stream.draws;state=stream.state;var edited: Array=private_owner.skills.changes()
	check(count==entry_draws+1 and private_owner.finalization.hiddenHitPointGain and front.panes.summary.summary.contains(active_text.raw({"strRef":6389})+" : ?"),"Hide-gain affects original Summary text without suppressing random consumption")
	desktop.state.module={"serverFlags":{"field158":false,"field164":false}};await click(front.panes.summary.buttons.okbutton)
	check(await wait_for(func():return panel.visible and not panel.source_active and not runtime.active),"Changed current module flags retire an already prepared Summary before emission")
	check(controller.draft.skills==edited and edited[0]==1 and stream.draws==count and stream.state==state and desktop.commands.all(func(value):return value.operation!="submit" or value.token!=73),"Module retirement preserves manual choices and neither rerolls nor fabricates a sent proposal")
	panel.reset()
	if not gate(await summary(begin,74,false,false,false,true),"Flags received after begin are read at actual Summary finalization"):return
	stream=runtime.hit_die_owner.stream;count=stream.draws
	check(count==entry_draws+1 and private_owner.finalization.hitDie==8 and private_owner.finalization.hiddenHitPointGain and runtime.hit_die_owner.plan.forceMaximum,"Current received force/hide values replace obsolete begin-time presentation flags without changing the snapshot")
	var retired_scope: Array=runtime.rules_scope.duplicate();runtime.defer_fallback("Retired prior-token preparation");panel.reset();desktop.state.module={"serverFlags":{"field158":false,"field164":false}}
	var reopened:=begin.duplicate(true);reopened.token=76;panel.reset();panel.open();controller.receive_result(ReplyFixture.echo(desktop,{"accepted":true,"operation":"begin","result":reopened}))
	check(await ready("class") and runtime.active and runtime.rules_scope!=retired_scope and panel.source_active,"A deferred fallback from the same actor cannot retire the newly opened token")
	check(stream.draws==count and runtime.hit_die_owner.receipt.is_empty(),"Retired callback/new Class entry cannot consume or reuse the old Summary roll")
	await click(front.panes["class"].buttons.cancelbutton)
	var unavailable:=begin.duplicate(true);unavailable.token=75;desktop.state.module={};panel.reset();panel.open();controller.receive_result(ReplyFixture.echo(desktop,{"accepted":true,"operation":"begin","result":unavailable}));await frames()
	check(panel.wanted and panel.visible and not panel.source_active and not runtime.active and stream.draws==count,"Unavailable received flags preserve explicit usable fallback without inventing false or drawing")
	check(received==before and desktop.commands.all(func(value):return value.operation!="submit" or value.token==72),"Received actor remains exact; only the reviewed current-token proposal was emitted")
	panel.reset();active_text.tables=tables;desktop.state.module={"serverFlags":{"field158":false,"field164":false}};observations.append({"kind":"native-level4-random","entries":roll_observations})
