extends "res://tests/native_level_up_recommended_test.gd"
const AppRandom=preload("res://systems/native_data/native_client_random.gd")
# Actual native frame before a delayed begin reply, without a server token,
# editable choices, synchronous older-editor construction or a random draw.
func extra_cases(begin: Dictionary,_received: Dictionary,_before: Dictionary,_tables: Dictionary) -> void:
	cancel_on_press=false
	controller.close();panel.free()
	var report_path:=""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="):report_path=argument.trim_prefix("--report=")
	panel=RuntimePanel.new();surface.add_child(panel);panel.setup(report_path+".opening.cfg")
	controller=NativeOwner.new();controller.configure(desktop,panel);panel.request.connect(controller.input);controller.configure_source(painter,base_text,catalog,"")
	runtime=controller.source_runtime;front=runtime.frontend;private_owner=runtime.source_owner
	check(front.panes.has("class") and not front.wanted and not front.surface.visible,"Original Class frame is prepared offscreen before first Level Up")
	var count: int=desktop.commands.size();var random=AppRandom.acquire();var draws: int=random.draws
	panel.open()
	var request: Dictionary=desktop.commands.back().duplicate(true);var pending: Array=controller.requesting_ticket.duplicate()
	check(desktop.commands.size()==count+1 and request.operation=="begin" and not panel.visible and panel.source_active,"Same open call hides older panel and requests native presentation immediately")
	check(not pending.is_empty() and front.owns(pending) and front.stage=="class" and not private_owner.wanted and not runtime.active and controller.token==-1 and controller.snapshot.is_empty(),"Pending Class has only a local presentation identity, no invented transaction or received choices")
	var hidden_for_all_frames:=true
	for _frame in 36:
		await frames(1)
		hidden_for_all_frames=hidden_for_all_frames and not panel.visible and panel.source_active and front.owns(pending)
	check(hidden_for_all_frames,"Older menu remains hidden for a delayed half-second server reply")
	var pane=front.panes["class"]
	check(pane.layout_ready and pane.visible and not pane.waiting_message.is_empty() and pane.state.entries.is_empty(),"Waiting uses the original native Class frame with unavailable choices")
	check(pane.buttons.okbutton.disabled and pane.buttons.recommendbutton.disabled and not pane.buttons.cancelbutton.disabled,"Pending native frame disables choices while keeping actual Cancel enabled")
	controller.input({"kind":"level-open"});panel.open();pane.invoke("okbutton");pane.complete(true)
	check(desktop.commands.size()==count+1 and controller.requesting_ticket==pending and controller.token==-1 and random.draws==draws,"Repeated open and synthetic accept cannot duplicate begin, invent a token or roll")
	var value:=begin.duplicate(true);value.token=701
	controller.receive_result(ReplyFixture.echo(desktop,{"accepted":true,"operation":"begin","result":value}))
	if gate(await ready("class"),"Real correlated begin replaces local waiting with native received Class"):
		check(controller.requesting_ticket.is_empty() and controller.token==701 and not panel.visible and panel.source_active and pane.waiting_message.is_empty(),"Server-ready Class takes over without showing older editor")
		var current: Array=front.ticket.duplicate();front.cancelled.emit(pending)
		check(panel.wanted and front.ticket==current and controller.token==701,"Late waiting callback cannot cancel the real received transaction")
	panel.reset();panel.open();var cancelled_request: Dictionary=desktop.commands.back().duplicate(true)
	await frames();count=desktop.commands.size();await click(front.panes["class"].buttons.cancelbutton)
	check(not panel.wanted and controller.requesting_ticket.is_empty() and desktop.commands.size()==count+1 and desktop.commands.back().operation=="cancel" and desktop.commands.back().levelRequest.token==-1,"Physical pending Cancel closes presentation and preserves original cancellation command")
	var late:={"accepted":true,"operation":"begin","levelRequest":cancelled_request.levelRequest.duplicate(true),"result":value}
	controller.receive_result(late);check(not panel.wanted and not front.wanted,"Delayed begin cannot reopen a cancelled waiting frame")
	panel.open();var failed_request: Dictionary=desktop.commands.back().duplicate(true)
	controller.receive_result(ReplyFixture.echo(desktop,{"accepted":false,"operation":"begin","text":"Current authored begin refusal"}))
	check(not panel.visible and panel.source_active and front.panes["class"].waiting_message=="Current authored begin refusal" and not front.panes["class"].buttons.cancelbutton.disabled,"Current refusal stays in native help with Cancel available")
	await key_escape();check(not panel.wanted and controller.requesting_ticket.is_empty(),"Physical Escape cancels native waiting/error frame")
	panel.open();var latest: Array=controller.requesting_ticket.duplicate()
	controller.receive_result({"accepted":false,"operation":"begin","levelRequest":failed_request.levelRequest.duplicate(true),"text":"Stale refusal"})
	check(front.owns(latest) and front.panes["class"].waiting_message!="Stale refusal" and not panel.visible,"Stale refusal cannot replace a new native waiting frame")
	var lifetime: Variant=desktop.actor_value.nativeLifetime;desktop.actor_value.nativeLifetime=int(lifetime)+1;count=desktop.commands.size();controller.observe_received()
	check(not panel.wanted and not front.wanted and desktop.commands.size()==count,"Received actor retirement dismisses waiting without cancelling replacement actor")
	desktop.actor_value.nativeLifetime=lifetime
	check(random.draws==draws,"Waiting, refusal, cancellation and real Class admission never draw HP randomness")
	observations.append({"kind":"native-pre-reply-presentation","framesObserved":36,"genericHidden":hidden_for_all_frames,"serverTokenRequiredBeforeChoices":true,"packetConnections":0,"pixelsAccepted":false})
