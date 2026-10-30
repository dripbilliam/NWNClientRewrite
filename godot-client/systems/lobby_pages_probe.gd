extends RefCounted
var client
var running:=true
var checks: Array=[]
func stop() -> void: running=false
func check(value: bool,label: String) -> bool:
	checks.append({"label":label,"passed":value}); print("NATIVE_LOBBY_PAGE_CHECK ",value," ",label); return value
func wait_until(predicate: Callable,seconds: float=30) -> bool:
	var end:=Time.get_ticks_msec()+int(seconds*1000)
	while running and is_instance_valid(client) and not client.closing and Time.get_ticks_msec()<end:
		if predicate.call(): return true
		await client.process_frame
	return false
func click(button: Button) -> void:
	var point:=button.get_global_rect().get_center(); var motion:=InputEventMouseMotion.new(); motion.position=point; motion.global_position=point; client.root.push_input(motion,true); await client.process_frame
	for pressed in [true,false]:
		var event:=InputEventMouseButton.new(); event.position=point; event.global_position=point; event.button_index=MOUSE_BUTTON_LEFT; event.pressed=pressed; event.button_mask=MOUSE_BUTTON_MASK_LEFT if pressed else 0; client.root.push_input(event,true); await client.process_frame
func run(tree) -> void:
	client=tree
	var ui=client.character_lobby; var native=ui.native_chooser; var raw_id:=-1
	var ready: bool=await wait_until(func():return native.layout_ready and native.extra_pages.player_bar.art_ready and client.gameplay_ui.tables_ready and native.frame.fonts.pending.is_empty() and not native.row_keys.is_empty() and native.automatic_selection.is_empty() and ui.native_selection.is_empty() and ui.state.get("selected")==native.row_keys[0])
	check(ready,"Owned native chooser and original page artwork/rules prepare before live input")
	if ready:
		var initial_key: Variant=ui.state.get("selected")
		check(not is_instance_valid(client.world) and initial_key==native.row_keys[0],"Observer remains unadmitted after the original automatic first-row selection")
		check(not client.gameplay_ui.presentation_enabled and not client.gameplay_ui.chat.is_visible_in_tree() and not client.label.visible and native.is_visible_in_tree(),"Native chooser stays visible without gameplay chat or stale renderer status")
		for code in [KEY_I,KEY_C,KEY_ENTER,KEY_KP_ENTER,KEY_ESCAPE,KEY_TAB]:
			for pressed in [true,false]:
				var event:=InputEventKey.new(); event.keycode=code; event.physical_keycode=code; event.pressed=pressed; client.root.push_input(event,true); await client.process_frame
		check(not client.gameplay_ui.inventory.ui.wanted and not client.gameplay_ui.desktop.sheet.wanted and not client.render_menu.panel.visible and native.has_focus() and client.root.gui_get_focus_owner()!=client.gameplay_ui.chat.entry and ui.state.get("selected")==initial_key and not is_instance_valid(client.world),"Original focused pregame edit keys retain chooser focus without opening gameplay/menu/chat or submitting a character")
		await click(native.tabs[1])
		check(await wait_until(func():return not ui.state.get("serverInfoPending",true) and ui.state.get("serverInfo",{}).get("extendedReceived",false)),"Source Server Info tab receives the owned original server's extended response")
		check(native.extra_pages.info.visible and str(ui.state.get("serverInfo",{}).get("serverVersion","")).begins_with("8193") and int(ui.state.get("serverInfo",{}).get("serverStatus",-1))==2 and native.extra_pages.info_text.get_parsed_text().contains("127.0.0.1:5125\n"),"Native page shows the real server version, integer endpoint and received running status")
		await click(native.tabs[2])
		check(await wait_until(func():return int(ui.state.get("lobbyPage",-1))==2),"Source Player List tab reaches the active subscription owner")
		client.send({"kind":"test-lobby-participant","operation":"start"})
		var added: bool=await wait_until(func():return client.test_lobby_participant.get("ready",false) and ui.state.get("players",[]).size()==1 and native.extra_pages.rows.size()==1,45)
		check(added,"Original server addition creates one disabled native roster row for the second participant")
		if added:
			var received: Dictionary=ui.state.players[0]; raw_id=int(received.id); var expected: Dictionary=client.test_lobby_participant.expected
			check(client.gameplay_ui.text.name({"firstName":received.firstName,"lastName":received.lastName},raw_id)==client.gameplay_ui.text.name({"firstName":expected.firstName,"lastName":expected.lastName},raw_id) and received.classes==expected.classes,"Received roster identity/class levels match the owned submitted character")
			var row: Button=native.extra_pages.rows[0]; check(row.disabled and int(row.get_meta("player_id"))==raw_id,"Native row retains the original server's raw roster ID without admitting an entity")
			var expected_caption:=""
			for item in expected.classes: expected_caption+=native.extra_pages.rules.title("classes",int(item.id))+"("+str(int(item.level))+") "
			check(row.get_children().filter(func(child):return child is Label)[1].text==expected_caption,"Live JSON class levels render as original integers without decimal suffixes")
			check(await wait_until(func():return row.get_children().any(func(child):return child is TextureRect and child.texture!=null)),"Live received portrait resolves through the native catalog")
			await click(row); check(ui.state.get("selected")==initial_key and not is_instance_valid(client.world),"Clicking a connected player preserves the selected vault character without entering the world")
			await RenderingServer.frame_post_draw; var image_path: String=str(client.args.get("report","")).trim_suffix(".json")+".lobby-roster.png"; check(client.root.get_texture().get_image().save_png(image_path)==OK,"Live native roster viewport saved for visual review")
		client.send({"kind":"test-lobby-participant","operation":"close"})
		check(await wait_until(func():return client.test_lobby_participant.get("closed",false) and ui.state.get("players",[]).is_empty() and native.extra_pages.rows.is_empty()),"Original server removal retires the disconnected participant's native row")
		await click(native.tabs[0]); check(await wait_until(func():return int(ui.state.get("lobbyPage",-1))==0),"Returning to Character Info stops the live roster subscription")
		await click(native.tabs[2]); check(await wait_until(func():return int(ui.state.get("lobbyPage",-1))==2 and ui.state.get("players",[]).is_empty()),"Reopening the live roster cannot resurrect a retired player")
		await click(native.tabs[0]); check(await wait_until(func():return int(ui.state.get("lobbyPage",-1))==0),"Final page dismissal leaves no roster subscription before normal admission")
	var proof:={"success":checks.size()==18 and checks.all(func(item):return item.passed),"checks":checks,"rosterId":raw_id,"publicConnections":0,"endpoint":"127.0.0.1:5125","scope":"Real native pointer/key events, pregame presentation gating and original local-server roster addition/removal/metadata before the regular authoritative gameplay checks. Original-client pixel/role/scale/audio comparison remains open."}
	client.report.lobby_pages=proof; client.send({"kind":"native-lobby-pages-proof","success":proof.success,"checks":checks,"rosterId":raw_id}); running=false
