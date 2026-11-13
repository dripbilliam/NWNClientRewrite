extends "res://tests/native_level_up_recommended_test.gd"
# Actual fallback controller/panel and pointer input. Session transaction
# preservation is checked separately by test/native-level-up-gui.test.js.
func fallback_begin(value: Dictionary,new_token: int) -> void:
	controller.source_runtime.retire()
	controller.source_configured=false
	panel.reset()
	panel.open()
	var received:=value.duplicate(true)
	received.token=new_token
	controller.receive_result(ReplyFixture.echo(desktop,{"accepted":true,"operation":"begin","result":received}))
	controller.draft.ability=0
	controller.step=6
	controller.render()
	await frames(3)

func extra_cases(begin: Dictionary,_received: Dictionary,_before: Dictionary,_tables: Dictionary) -> void:
	cancel_on_press=false
	await fallback_begin(begin,901)
	check(panel.wanted and not panel.source_active and panel.visible and controller.errors().is_empty(),"Authored valid fallback reaches actual Review controls")
	check(panel.finish.visible and not panel.finish.disabled,"Valid fallback proposal is available through actual Finish")
	var count: int=desktop.commands.size()
	await click(panel.finish)
	check(desktop.commands.size()==count+1 and desktop.commands.back().operation=="submit" and controller.submitting,"Physical Finish submits once and waits for server")
	var submitted: Dictionary=desktop.commands.back().duplicate(true)
	var submitted_index: int=desktop.commands.size()-1
	var proposal_before: Dictionary=submitted.proposal.duplicate(true)
	check(not panel.state.canEdit and panel.finish.disabled and panel.back.disabled and panel.next.disabled,"Pending proposal keeps editing and navigation disabled")
	check(panel.state.canCancel and not panel.cancel.disabled,"Pending fallback keeps actual Cancel enabled like native Summary")
	count=desktop.commands.size()
	await click(panel.finish)
	check(desktop.commands.size()==count,"Disabled Finish cannot send a duplicate proposal")
	await click(panel.cancel)
	check(not panel.wanted and not panel.visible and not controller.submitting,"Physical pending Cancel closes fallback presentation")
	check(desktop.commands.size()==count+1 and desktop.commands.back().operation=="cancel" and desktop.commands.back().token==901,"Cancel emits the scoped native GUI cancellation request")
	check(controller.snapshot.is_empty() and controller.draft.is_empty() and not controller.reply_scope.is_open(),"Closing retires only local presentation and reply correlation")
	check(desktop.commands[submitted_index].proposal==proposal_before,"Closing cannot mutate the detached proposal already sent to Session")
	controller.receive_result({"accepted":true,"operation":"submit","levelRequest":submitted.levelRequest.duplicate(true),"result":{"accepted":true}})
	check(not panel.wanted and not panel.visible and controller.snapshot.is_empty(),"Delayed accepted result cannot reopen the cancelled presentation")
	await fallback_begin(begin,902)
	var next_serial: int=panel.view_id
	controller.receive_result({"accepted":false,"operation":"submit","levelRequest":submitted.levelRequest.duplicate(true),"text":"Old rejected transaction"})
	check(panel.wanted and panel.view_id==next_serial and controller.token==902 and panel.status.text!="Old rejected transaction","Old result cannot replace a newly opened transaction")
	await click(panel.finish)
	check(controller.submitting and panel.state.canCancel,"Second transaction also preserves pending cancellation")
	count=desktop.commands.size()
	# NativeGameDesktop's Escape dispatch emits this same actual close signal.
	# This checks the signal route, not a physical OS Escape press.
	panel.close_requested.emit()
	await frames(2)
	check(not panel.wanted and desktop.commands.size()==count+1 and desktop.commands.back().operation=="cancel" and desktop.commands.back().token==902,"Escape-equivalent close signal cancels the current pending view")
	observations.append({"kind":"pending-fallback-cancel","physicalFinishAndCancel":true,"escapeCloseSignal":true,"serverAcknowledgementAuthored":true,"sessionPreservationSeparate":true,"pixelsAccepted":false})
