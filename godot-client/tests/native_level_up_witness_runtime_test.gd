extends "res://tests/native_level_up_recommended_test.gd"
const LiveDriver=preload("res://tests/native_live_level_up_source_probe.gd")
class InputDesktop extends RefCounted:
	var level_owner
	var level_up
func extra_cases(begin: Dictionary,received: Dictionary,before: Dictionary,tables: Dictionary) -> void:
	panel.reset()
	var driver_tables:=tables.duplicate();driver_tables.ruleset=tables.ruleset.duplicate(true)
	for row in driver_tables.ruleset.orderedRows:
		if row.Label=="MIN_LEVEL_FOR_MAX_HP":row.Value="3"
	active_text.tables=driver_tables
	var adapter:=InputDesktop.new();adapter.level_owner=controller;adapter.level_up=panel
	var driver:=LiveDriver.new();surface.add_child(driver);driver.bind_desktop(adapter)
	for turn in 2:
		var current:=begin.duplicate(true);current.token=901+turn;current.snapshot.feats=[40]
		panel.reset();panel.open();controller.receive_result(ReplyFixture.echo(desktop,{"accepted":true,"operation":"begin","result":JSON.parse_string(JSON.stringify(current))}))
		var scope: Array=controller.source_identity()+[controller.token]
		if turn==1:
			check(not runtime.enable_source_probe_diagnostics(controller.source_identity()+[901]),"Old token cannot enable diagnostic capture")
			check(runtime.enable_source_probe_diagnostics(scope),"Opt-in captures only the active source scope")
		var draws: int=runtime.hit_die_owner.stream.draws
		var accepted: bool=await driver.drive_to_summary(3,1)
		check(accepted and driver.failures.is_empty(),"Actual source Class/Attributes/Skills/Summary reaches diagnostic boundary")
		if not accepted:break
		var ticket: Array=private_owner.navigation.ticket.duplicate();var value: Dictionary=runtime.finalization_diagnostic(ticket)
		if turn==0:
			check(runtime.diagnostic_scope.is_empty() and runtime.finalization_diagnostics.is_empty() and not value.ready,"Production default stores no diagnostic graph")
		else:
			check(value.ready and value.scope==scope and value.ticket==ticket and value.vitals.raw[1]==15,"Actual private finalization vectors and ticket are witnessed")
			check(value.primaryFeats.has(40) and value.literalInt40Membership.primary and value.primaryTypes.all(func(kind):return kind==TYPE_INT),"Real JSON-owned Toughness reaches finalization as native integer IDs")
			value.vitals.raw[0]=99
			check(runtime.finalization_diagnostic(ticket).vitals.raw[0]==14,"Diagnostic getter cannot mutate actual private state")
			var stale:=ticket.duplicate();stale[3]=901
			check(not runtime.finalization_diagnostic(stale).ready,"Getter rejects retired Summary token")
			observations.append({"kind":"opt-in-finalization-witness","witness":runtime.finalization_diagnostic(ticket),"authority":false})
		check(runtime.hit_die_owner.stream.draws==draws+1,"Diagnostic capture adds no RNG calls")
		await driver.click(front.panes.summary.buttons.cancelbutton,"Witness actual Summary Cancel")
		check(not panel.wanted and runtime.diagnostic_scope.is_empty() and runtime.finalization_diagnostics.is_empty() and not runtime.finalization_diagnostic(ticket).ready,"Actual cancellation retires scope and detached witness")
	check(received==before and not driver.completed,"Authored controls/witness tests never claim real server acceptance or mutate received actor")
	driver.queue_free();await frames()
