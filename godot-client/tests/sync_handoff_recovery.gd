extends RefCounted
var client
var watch
var running := true
var checks: Array = []
func stop() -> void: running = false
func check(value: bool, name: String) -> void:
	checks.append({"name":name,"passed":value}); print("NATIVE_SYNC_RECOVERY ",value," ",name)
func wait_until(predicate: Callable, seconds: float = 35) -> bool:
	var deadline := Time.get_ticks_msec()+int(seconds*1000)
	while running and is_instance_valid(client) and Time.get_ticks_msec()<deadline:
		if predicate.call(): return true
		await client.get_tree().process_frame
	return false
func click(button: Button) -> void:
	var point := button.get_global_rect().get_center()
	for pressed in [true,false]:
		var move := InputEventMouseMotion.new();move.position=point;client.get_viewport().push_input(move,true)
		var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.position=point;event.global_position=point;event.pressed=pressed
		client.get_viewport().push_input(event,true);await client.get_tree().process_frame
func run(owner, observer, message: Dictionary) -> void:
	client=owner;watch=weakref(observer);var mode:=str(message.mode)
	var reached:=await wait_until(func():
		if client.connection!=2:return false
		if mode=="failure":return client.lobby.state.get("phase")=="resources-unavailable"
		return watch.get_ref().observations.any(func(v):return int(v.connection)==2 and v.phase=="server-content" and v.completed>0 and v.completed<v.total),70)
	check(reached and client.connection==2,"Recovery observes the real destination content stage")
	if not reached:finish(mode,"",0,0);return
	var failed_text:=str(client.lobby.state.get("error",""));var began:=Time.get_unix_time_from_system()*1000.0
	await client.get_tree().process_frame;await client.get_tree().process_frame
	check(client.generation<0 and client.owner_scene.camera==null,"Source world is gone before destination content admission")
	check(client.nui.windows.is_empty() and client.nui.resources.is_empty(),"Source menus and resources retire during the real transfer")
	check(client.retired_world_refs.all(func(v):return v.get_ref()==null),"Retired source scene owners are freed")
	check(client.lobby.state.get("canCancelJoin",false) and not client.lobby.state.get("canJoin",true),"Content stage permits cancellation while blocking another join")
	check(client.lobby.cancel_button.visible and not client.lobby.cancel_button.disabled and client.lobby.play_button.disabled,"Native Cancel is usable and Play is disabled")
	check(failed_text.contains("content") if mode=="failure" else client.lobby.download_bar.visible,"Failed content has explanatory feedback; live downloads show progress")
	var progress: Array=watch.get_ref().snapshot(2).progress
	check(not progress.is_empty() and progress.all(func(v):return not v.canPlay and v.canCancel),"Destination content never opens character admission")
	await RenderingServer.frame_post_draw
	check(client.get_viewport().get_texture().get_image().save_png(str(message.screenshot)+"-"+mode+"-pending.png")==OK,"Actual destination content controls are rendered and captured")
	await click(client.lobby.cancel_button)
	check(await wait_until(func():return client.connection==3 and client.lobby.state.get("phase")=="menu" and client.lobby.state.get("canJoin",false)),"Pointer cancellation completes real cleanup and returns to a usable menu")
	check(client.generation<0 and client.controlled_id<0 and not client.world_scope.admitted,"Cancelled destination never becomes a playable world")
	check(client.nui.windows.is_empty() and client.nui.resources.is_empty() and client.nui.transfers.is_empty(),"Cancelled destination retains no native menus or partial resources")
	var before: int=watch.get_ref().snapshot(2).progress.size();await client.get_tree().create_timer(0.3).timeout
	check(watch.get_ref().snapshot(2).progress.size()==before,"Retired destination cannot publish late progress")
	check(not client.lobby.state.get("busy",true) and not client.lobby.state.get("canCancelJoin",true),"Cleanup releases transfer and busy state")
	check(str(client.lobby.state.get("error","")).is_empty(),"Cancelled content failure leaves no stale menu error")
	await RenderingServer.frame_post_draw
	check(client.get_viewport().get_texture().get_image().save_png(str(message.screenshot)+"-"+mode+"-menu.png")==OK,"Recovered menu is rendered and captured")
	var enabled: bool=client.lobby.panel.visible and not client.lobby.join_button.disabled
	check(enabled,"Actual native Connect button is enabled for retry")
	var recovered:=Time.get_unix_time_from_system()*1000.0
	if enabled:await click(client.lobby.join_button)
	check(await wait_until(func():return client.connection==4,10),"Pointer Connect starts a fresh retry connection")
	finish(mode,failed_text,began,recovered)
func finish(mode: String, failed_text: String, began: float, recovered: float) -> void:
	if running:client.send({"kind":"sync-handoff-recovery-tested","result":{"completed":checks.all(func(v):return v.passed),"checks":checks,"mode":mode,"startedConnection":2,"menuConnection":3,"retryConnection":client.connection,"failureText":failed_text,"beganAt":began,"recoveredAt":recovered,"progress":watch.get_ref().snapshot(2).progress}})
