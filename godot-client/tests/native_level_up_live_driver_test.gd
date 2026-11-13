extends "res://tests/native_level_up_recommended_test.gd"
const LiveDriver=preload("res://tests/native_live_level_up_source_probe.gd")
class InputDesktop extends RefCounted:
	var level_owner
	var level_up
func extra_cases(begin: Dictionary,received: Dictionary,before: Dictionary,tables: Dictionary) -> void:
	panel.reset()
	# The parent Recommended fixture intentionally uses threshold4. This
	# detached adapter explicitly exercises the original threshold3 RNG path,
	# just like native_level_up_random_runtime_test; live rules are not edited.
	var driver_tables:=tables.duplicate();driver_tables.ruleset=tables.ruleset.duplicate(true)
	for row in driver_tables.ruleset.orderedRows:
		if row.Label=="MIN_LEVEL_FOR_MAX_HP":row.Value="3"
	active_text.tables=driver_tables
	var current:=begin.duplicate(true);current.token=901
	panel.reset();panel.open();controller.receive_result(ReplyFixture.echo(desktop,{"accepted":true,"operation":"begin","result":current}))
	var adapter:=InputDesktop.new();adapter.level_owner=controller;adapter.level_up=panel
	var driver:=LiveDriver.new();surface.add_child(driver);driver.bind_desktop(adapter)
	var accepted: bool=await driver.drive_to_summary(3,1)
	check(accepted and driver.failures.is_empty(),"The unchanged authority driver uses real level4 Class/Attributes/Skills/Summary controls")
	check(driver.presentations.map(func(value):return value.stage)==["class","attributes","skills","summary"],"Exact source pane class/ownership/ticket evidence is captured before every stage")
	check(panel.source_active and not panel.visible and runtime.owns() and received==before,"Actual source driver neither opens generic controls nor edits received actor storage")
	var proposal: Dictionary=private_owner.proposal()
	check(proposal.get("ready",false) and proposal.proposal.ability==1 and proposal.proposal.skills[0]==1 and runtime.hit_die_owner.receipt.randomCalls==1,"Real source arrows produce the typed private proposal and one above-threshold roll")
	check(not driver.local_submit_refusal(901),"Fail-fast cannot trigger before a physical submit attempt")
	if accepted:await driver.submit_summary(901)
	check(controller.submitting and desktop.commands[-1].operation=="submit" and not driver.local_submit_refusal(901),"Actual physical Summary submission stays pending until a scoped result")
	controller.receive_result(ReplyFixture.echo(desktop,{"accepted":false,"operation":"submit","text":"Authored local validation refusal"}))
	check(driver.local_submit_refusal(901) and not driver.local_submit_refusal(902) and panel.source_active and panel.wanted and not panel.visible,"Current local refusal is detected without accepting another token or generic fallback")
	var count: int=desktop.commands.size()
	if accepted:await driver.click(front.panes.summary.buttons.cancelbutton,"Offline actual source Summary Cancel")
	check(not panel.wanted and desktop.commands.size()==count+1 and desktop.commands[-1].operation=="cancel" and desktop.commands[-1].token==901,"The authority driver's physical Summary Cancel sends the existing current-token command")
	check(received==before and not driver.completed,"Offline adapter stops at typed intent/authored refusal; it fabricates no admission, server acceptance, completion proof or received mutation")
	observations.append({"kind":"actual-live-driver-offline","checks":driver.checks,"failures":driver.failures.duplicate(true),"presentations":driver.presentations.duplicate(true),"typedProposal":proposal,"authority":false})
	driver.queue_free();await frames()
