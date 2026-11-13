extends Node
# No OS input, pose, clock, resources or synthetic native outcome is injected.
const COMMAND="-native-direct-handoff"
var client
var busy:=false
static func instance_id_token(value: Object)->String:
	return str(value.get_instance_id())
static func positive_integer(value: Variant)->bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)>0.0 and float(value)==floor(float(value))
func wait_until(predicate: Callable,seconds: float=35.0)->bool:
	var deadline:=Time.get_ticks_msec()+int(seconds*1000.0)
	while is_instance_valid(client) and not client.closing and Time.get_ticks_msec()<deadline:
		if predicate.call():return true
		await get_tree().process_frame
	return false
func current(connection: int)->bool:
	return is_instance_valid(client) and not client.closing and client.session_connection==connection and client.cancelled_connection!=connection
func retired_alive()->int:
	var alive:=0
	for ref in client.direct_retired_refs:
		if ref.get_ref()!=null:alive+=1
	return alive
func click(button: Button)->bool:
	if not is_instance_valid(button) or button.disabled or not button.is_visible_in_tree():return false
	var point:=button.get_global_rect().get_center()
	var motion:=InputEventMouseMotion.new()
	motion.position=point;motion.global_position=point
	get_viewport().push_input(motion,true)
	await get_tree().process_frame
	for pressed in [true,false]:
		var event:=InputEventMouseButton.new()
		event.button_index=MOUSE_BUTTON_LEFT;event.position=point;event.global_position=point;event.pressed=pressed
		get_viewport().push_input(event,true)
		await get_tree().process_frame
	return true
func run(value,message: Dictionary)->void:
	if busy:return
	client=value;busy=true
	var connection:=int(message.connection)
	var mode:=str(message.get("mode","observe"))
	if mode=="observe":await observe(connection,message)
	elif mode=="chat":
		if current(connection) and is_instance_valid(client.world) and client.epoch==message.get("generation") and client.world.area_id==message.get("areaId") and is_instance_valid(client.gameplay_ui):
			client.gameplay_ui.chat.submit(COMMAND)
			client.send({"kind":"direct-handoff-command","mode":mode,"connection":connection,"generation":client.epoch,"areaId":client.world.area_id,"text":COMMAND})
	elif mode in ["cancel","recover"]:await recovery_control(connection,mode,int(message.get("requestId",-1)))
	busy=false
func observe(connection: int,message: Dictionary)->void:
	var ready:=await wait_until(func():
		return current(connection) and is_instance_valid(client.world) and client.world.ready_for_control() and is_instance_valid(client.gameplay_ui) and client.initialized and retired_alive()==0)
	var result:={"success":false,"failures":[],"scope":{"connection":connection,"generation":client.epoch,"areaId":client.world.area_id if is_instance_valid(client.world) else -1}}
	if not ready:result.failures.append("Actual current world or retired owners not ready")
	if ready:
		var ui=client.gameplay_ui
		var id:=int(client.world.controlled_id)
		var row: Dictionary=ui.text.objects.get(id,{})
		result.source={"id":id,"objectType":row.get("objectType"),"nativeLifetime":row.get("nativeLifetime"),"knownLifetime":row.get("clientKnownLifetime")}
		result.worldReady=client.world.ready_for_control()
		result.guiOwned=ui.controlled_id==id and ui.native_connection_query.is_valid() and ui.native_connection_query.call()==connection
		result.catalogInstance=instance_id_token(client.catalog)
		result.module=client.module_name
		result.worldInstance=instance_id_token(client.world)
		result.gameplayInstance=instance_id_token(ui)
		result.retiredAlive=retired_alive()
		result.position=row.get("replicated",{}).get("position")
		if row.get("objectType")!=5 or row.get("replicationRemoved",false) or not positive_integer(row.get("nativeLifetime")) or not positive_integer(row.get("clientKnownLifetime")):result.failures.append("Actual controlled source identity unavailable")
		if not result.guiOwned:result.failures.append("Gameplay connection owner unavailable")
		if message.get("generation")!=client.epoch or message.get("areaId")!=client.world.area_id:result.failures.append("Actual probe scope changed")
		result.success=result.failures.is_empty()
	client.send({"kind":"direct-handoff-observed","connection":connection,"result":result})
func cancel_button()->Button:
	if not is_instance_valid(client.character_lobby):return null
	var lobby=client.character_lobby
	if is_instance_valid(lobby.native_wait_cancel) and lobby.native_wait_cancel.is_visible_in_tree():return lobby.native_wait_cancel
	return lobby.cancel_button if is_instance_valid(lobby.cancel_button) and lobby.cancel_button.is_visible_in_tree() else null
func recovery_control(connection: int,mode: String,request_id: int)->void:
	if mode=="cancel":
		var ready:=await wait_until(func():
			var button: Button=cancel_button()
			return current(connection) and is_instance_valid(button) and not button.disabled and client.character_lobby.state.get("canCancelJoin",false) and not is_instance_valid(client.world))
		var pressed:=false
		if ready:pressed=await click(cancel_button())
		if pressed:
			await wait_until(func():
				return not is_instance_valid(client.world) and retired_alive()==0 and is_instance_valid(client.character_lobby) and str(client.character_lobby.state.get("phase",""))=="menu" and not client.character_lobby.state.get("busy",false))
		client.send({"kind":"direct-handoff-control","connection":connection,"requestId":request_id,"mode":mode,"pointerClick":pressed,"sourceWorldRetired":not is_instance_valid(client.world),"retiredAlive":retired_alive(),"resultConnection":client.session_connection,"phase":str(client.character_lobby.state.get("phase","")) if is_instance_valid(client.character_lobby) else "unavailable"})
		return
	var ready:=await wait_until(func():
		if not current(connection) or not is_instance_valid(client.character_lobby) or is_instance_valid(client.world) or retired_alive()!=0:return false
		var browser=client.server_browser
		return str(client.character_lobby.state.get("phase",""))=="menu" and client.character_lobby.state.get("canJoin",false) and not client.character_lobby.state.get("busy",false) and is_instance_valid(browser) and browser.wanted and browser.entry_context and browser.entry_stage=="browser" and not browser.state.get("busy",false) and is_instance_valid(browser.native_browser) and browser.native_browser.is_visible_in_tree() and browser.native_browser.layout_ready)
	var menu_usable:=ready
	var back_pressed:=false
	var direct_pressed:=false
	var confirm_pressed:=false
	if ready:
		var browser=client.server_browser
		var page: Dictionary=browser.native_browser.pages.get(browser.native_browser.active_tab,{})
		var back: Button=page.get("buttons",{}).get("cancelbutton")
		back_pressed=await click(back)
		if back_pressed:
			ready=await wait_until(func():
				return current(connection) and browser.entry_stage=="entry" and not browser.state.get("busy",false) and is_instance_valid(browser.entry_menu) and browser.entry_menu.is_visible_in_tree() and browser.entry_menu.buttons.has("dirconnectbutton") and not browser.entry_menu.buttons.dirconnectbutton.disabled)
		if ready and back_pressed:direct_pressed=await click(browser.entry_menu.buttons.dirconnectbutton)
		if direct_pressed:
			ready=await wait_until(func():
				return current(connection) and is_instance_valid(browser.direct_dialog) and browser.direct_dialog.layout_ready and browser.direct_dialog.is_visible_in_tree() and browser.direct_dialog.buttons.has("okbutton") and not browser.direct_dialog.buttons.okbutton.disabled)
		if ready and direct_pressed:
			# Owned test input in the genuine Direct Connect edit; no browser
			# request, join callback or production outcome is synthesized here.
			browser.direct_dialog.edits.ipeditbox.text="127.0.0.1:5129"
			browser.direct_dialog.edits.passwordeditbox.clear()
			confirm_pressed=await click(browser.direct_dialog.buttons.okbutton)
	client.send({"kind":"direct-handoff-control","connection":connection,"requestId":request_id,"mode":mode,"menuUsable":menu_usable,"backPointer":back_pressed,"directPointer":direct_pressed,"confirmPointer":confirm_pressed,"sourceWorldRetired":not is_instance_valid(client.world),"retiredAlive":retired_alive(),"resultConnection":client.session_connection,"phase":str(client.character_lobby.state.get("phase","")) if is_instance_valid(client.character_lobby) else "unavailable"})
