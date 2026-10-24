extends RefCounted
var client
var mode := ""
var started := -1
var checks: Array = []
var base := ""
func check(value: bool,label: String) -> void: checks.append({"passed":value,"name":label})
func run(owner,message: Dictionary) -> void:
	client = owner; mode = str(message.mode); started = client.connection; base = str(message.screenshot)
	await client.get_tree().process_frame
	check(started == int(message.connection),"Recovery probe belongs to the current native transfer connection")
	check(client.generation < 0 and client.owner_scene.camera == null,"The released source world is retired before destination admission")
	check(client.lobby.state.get("canCancelJoin",false) and not client.lobby.state.get("canJoin",true),"Transfer exposes cancellation while blocking unrelated joins")
	check(client.lobby.cancel_button.visible and not client.lobby.cancel_button.disabled,"Actual native Cancel button is enabled during transfer")
	await RenderingServer.frame_post_draw
	check(client.get_viewport().get_texture().get_image().save_png(base+"-pending.png") == OK,"Pending transfer controls are rendered and captured")
	if mode == "cancel": await click(client.lobby.cancel_button)
	var deadline := Time.get_ticks_msec()+35000
	while Time.get_ticks_msec() < deadline and not (client.lobby.state.get("phase","") == "menu" and client.lobby.state.get("canJoin",false)):
		await client.get_tree().process_frame
	check(client.lobby.state.get("phase","") == "menu" and client.lobby.state.get("canJoin",false),"Real cancellation/failure returns to a menu that permits retry")
	check(client.connection == started+(1 if mode == "cancel" else 0),"Recovery retains the expected native connection epoch")
	check(not client.lobby.state.get("busy",true) and not client.lobby.state.get("canCancelJoin",true),"Recovery releases busy and transfer cancellation state")
	check(client.generation < 0 and client.controlled_id < 0 and not client.world_scope.admitted,"No cancelled or failed destination world becomes playable")
	await client.get_tree().process_frame; await client.get_tree().process_frame
	check(client.retired_world_refs.all(func(row): return row.get_ref() == null),"All retired native source owners have actually been freed")
	var error := str(client.lobby.state.get("error",""))
	check(error.contains("destination") if mode == "failure" else error.is_empty(),"Failure explains the destination problem; cancellation clears its status")
	await RenderingServer.frame_post_draw
	check(client.get_viewport().get_texture().get_image().save_png(base+"-recovered.png") == OK,"Recovered native menu is rendered and captured")
	client.send({"kind":"portal-recovery-tested","result":{"completed":checks.all(func(row): return row.passed),"checks":checks,"mode":mode,"startedConnection":started,"recoveredConnection":client.connection,"error":error}})

func click(button: Button) -> void:
	var point := button.get_global_rect().get_center()
	for pressed in [true,false]:
		var move := InputEventMouseMotion.new(); move.position = point; client.get_viewport().push_input(move,true)
		var event := InputEventMouseButton.new(); event.button_index = MOUSE_BUTTON_LEFT; event.position = point; event.global_position = point; event.pressed = pressed
		client.get_viewport().push_input(event,true); await client.get_tree().process_frame

func retry() -> void:
	var from: int = client.connection
	var enabled: bool = client.lobby.panel.visible and not client.lobby.join_button.disabled
	if enabled: await click(client.lobby.join_button)
	var deadline := Time.get_ticks_msec()+10000
	while Time.get_ticks_msec() < deadline and client.connection == from: await client.get_tree().process_frame
	client.send({"kind":"portal-recovery-retry-clicked","result":{"completed":enabled and client.connection == from+1,"from":from,"to":client.connection,"buttonEnabled":enabled,"pointerClick":true}})
