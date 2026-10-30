extends "res://tests/native_character_lobby_frame_test.gd"
func run() -> void:
	var output:=""; var install:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
		if arg.begins_with("--install="): install=arg.substr(10)
	if output.is_empty() or install.is_empty() or FileAccess.file_exists(output): quit(2); return
	root.size=Vector2i(1200,850); surface=SubViewport.new(); surface.size=root.size; surface.render_target_update_mode=SubViewport.UPDATE_ALWAYS; surface.gui_disable_input=false; surface.handle_input_locally=true; root.add_child(surface); surface.notify_mouse_entered()
	var catalog:=Catalog.new(); check(catalog.mount_install(install),"Original lobby page resources mount read-only")
	var text=preload("res://systems/native_data/talk_text.gd").new(); check(text.base.open_file(install.path_join("lang/en/data/dialog.tlk")),"Lobby page labels use original TLK")
	text.tables={"classes":{"orderedRows":[{"Name":16777217}]} }; text.overrides={16777217:"Server custom class",8135:"Server-custom module label"}
	var painter:=Painter.new(); surface.add_child(painter); painter.configure_source(catalog,ProjectSettings.globalize_path("user://native-prepared-v2"))
	ui=Lobby.new(); surface.add_child(ui); ui.request.connect(func(message):requests.append(message.duplicate(true))); ui.configure_native(painter,text,catalog,ProjectSettings.globalize_path("user://native-prepared-v2")); native=ui.native_chooser
	check(await wait_until(func():return native.layout_ready or not native.failure.is_empty()),"Original server/player page owners prepare")
	check(native.failure.is_empty(),"All original server/player attachment hooks validate: "+native.failure)
	if native.layout_ready:
		state={"phase":"character-selection","connected":true,"canSelect":true,"canLobbyPages":true,"selected":"server:z","endpoint":{"host":"owned.example","port":5125},"choices":[{"key":"server:z","label":"Zulu","source":"server","serverSource":17,"classes":[]}],"serverInfo":{"moduleName":"Owned room","address":"127.0.0.1","playerCount":2,"maximumPlayers":8,"minimumLevel":1,"maximumLevel":40,"pvpSetting":1,"serverVersion":"8193.37"}}
		await present(); check(not native.tabs[1].disabled and not native.tabs[2].disabled,"Admitted lobby exposes the native Server Info and Player List tabs")
		await click(native.tabs[1].get_global_rect().get_center()); var pages=native.extra_pages
		check(requests.back()=={"kind":"lobby-page","page":1,"connection":1} and pages.info.visible and not native.record.visible,"A real Server Info tab click requests only the owned page and displays its source model")
		var body: String=pages.info_text.get_parsed_text()
		check(body.begins_with("Server-custom module label: Owned room\nPlayers: 2 / 8\nLevels: 1 - 40\nIP Address: 127.0.0.1:5125\n") and body.contains("PvP Zone: Party Protected") and body.contains("Server Version: 8193.37"),"Source label references, field order, resolved address and active custom TLK format reported server metadata")
		check(body.ends_with("Server status: \n") and not body.contains("Running, login at will"),"Unreported server status remains unknown instead of inventing Running")
		for index in 3:
			state.serverInfo.pvpSetting=index; await present(); check(pages.info_text.get_parsed_text().contains(["No PvP","Party Protected","Full PvP"][index]),"Original PvP mapping"+str(index))
		state.serverInfo.serverStatus=2; await present(); check(pages.info_text.get_parsed_text().contains("Server status: Running, login at will"),"An explicitly reported status uses the source status string")
		await click(native.tabs[2].get_global_rect().get_center())
		check(requests.back()=={"kind":"lobby-page","page":2,"connection":1} and pages.players.visible and not pages.info.visible,"A real Player List tab click requests its authoritative subscription page")
		var players: Array=[]
		for index in 20: players.append({"id":index+7,"firstName":{"text":"Player "+str(index)},"lastName":{"text":"Test"},"portraitRef":"po_clsbard_","classes":[{"id":0,"level":index+1}]})
		state.players=players; await present()
		check(pages.rows.size()==20 and pages.rows.all(func(row):return row.disabled),"Received player records render as disabled source rows, never selectable vault entries")
		var labels: Array=pages.rows[0].get_children().filter(func(node):return node is Label)
		check(labels[0].text=="Player 0 Test" and labels[1].text=="Server custom class(1) " and labels.all(func(node):return node.modulate.is_equal_approx(Color(0.5,0.5,0.5))),"Player names/class levels use original row hooks, class/TLK data and disabled half-intensity captions")
		check(pages.player_geometry.portrait.bounds.size.is_equal_approx(Vector2(16,25)),"Player portraits retain the original16x25 mesh proportions")
		var count:=requests.size(); await click(pages.rows[0].get_global_rect().get_center()); check(requests.size()==count and ui.state.selected=="server:z","Clicking a connected player cannot select, preview or play their character")
		check(await wait_until(func():return pages.player_bar.art_ready or not pages.player_bar.failure.is_empty()),"Original Player List scrollbar artwork prepares before input")
		var before: int=pages.player_scroll.scroll_vertical; await click(pages.player_bar.down.get_global_rect().get_center()); check(pages.player_scroll.scroll_vertical==before+44,"Original Player List scrollbar advances one44-pixel received row")
		state.players=players.slice(1); state.players[0].firstName={"text":"Updated"}; await present(); check(pages.rows.size()==19 and int(pages.rows[0].get_meta("player_id"))==8 and pages.rows[0].get_children().filter(func(node):return node is Label)[0].text=="Updated Test","Received removal and replacement retire old row identity and text")
		if DisplayServer.get_name()!="headless":
			check(await wait_until(func():return painter.art.waiting.is_empty() and painter.art.models.pending.is_empty() and not painter.art.models.active and painter.fonts.pending.is_empty()),"Source player page artwork and fonts settle")
			check(pages.info_text.get_meta("native_font_applied","")=="ttf fnt_default 14" and painter.fonts.fonts.has("ttf fnt_default 14"),"Server Info uses the original default-dialog TTF instead of a Godot fallback font")
			await RenderingServer.frame_post_draw; check(surface.get_texture().get_image().save_png(output.trim_suffix(".json")+"-players.png")==OK,"Native player page saved for review")
		await row_down("server:z"); check(native.page_index==0 and native.record.visible and requests.any(func(message):return message.kind=="lobby-page" and message.page==0),"Selecting a vault row returns to Character Info and requests subscription shutdown")
		await click(native.tabs[2].get_global_rect().get_center()); count=requests.size(); ui.panel.hide(); await process_frame
		check(requests.size()==count+1 and requests.back().kind=="lobby-page" and requests.back().page==0 and native.page_index==0,"Hiding the chooser retires its open Player List subscription intent")
		await present(); await click(native.tabs[1].get_global_rect().get_center()); count=requests.size(); var point: Vector2=native.tabs[2].get_global_rect().get_center(); await motion(point); await mouse(point,true); await present(2); await mouse(point,false)
		check(requests.size()==count and native.page_index==0,"A held tab press cannot activate a page on a replacement connection")
		point=native.buttons.cancelbutton.get_global_rect().get_center(); count=requests.size(); await motion(point); await mouse(point,true); await present(3); await mouse(point,false)
		check(requests.size()==count,"A held footer press cannot disconnect a replacement connection")
		count=requests.size(); await motion(point); await mouse(point,true); state.serverInfo.playerCount=3; await present(3); await mouse(point,false)
		check(requests.size()==count+1 and requests.back()=={"kind":"lobby-disconnect","saveCharacter":false,"connection":3},"An unrelated metadata update does not swallow a valid held Cancel on the same connection")
		point=native.buttons.playbutton.get_global_rect().get_center(); count=requests.size(); await motion(point); await mouse(point,true); state.choices.append({"key":"server:other","label":"Other","source":"server","serverSource":17}); state.selected="server:other"; await present(3); await mouse(point,false)
		check(requests.size()==count+1 and requests.back().kind=="lobby-choose" and requests.back().key=="server:other" and not ui.native_selection.activate,"A catalog rebuild selects its new first row but a held Play cannot submit that replacement character")
		await click(native.tabs[1].get_global_rect().get_center()); state.pageError="Owned metadata request failed"; await present(3)
		check(native.notice.text=="Owned metadata request failed","Metadata failure is visible without fabricating page success or disconnecting the session")
		if DisplayServer.get_name()!="headless":
			await RenderingServer.frame_post_draw; check(surface.get_texture().get_image().save_png(output.trim_suffix(".json")+"-server.png")==OK,"Native server page saved for review")
	var window_state:={"focused":root.has_focus(),"unfocusable":root.unfocusable,"screen":root.current_screen,"primary":DisplayServer.get_primary_screen(),"mouse_mode":Input.mouse_mode}
	ui.close_native(); check(native.closed and native.assets.running.is_empty() and native.extra_pages.closed and native.extra_pages.player_bar.closed,"Private page workers/scrollbar retire before the shared source painter")
	ui.free(); painter.close(); painter.free(); text.close(); await process_frame; await process_frame
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"window":window_state,"publicConnections":0,"fullUiParity":false,"fullCharacterLobbyParity":false,"scope":"Native server/player source pages, metadata/class/TLK fields, actual pointer/tab/scroll/disabled-row behavior, update/removal presentation and held/dismiss/replacement ownership. Protocol/local server evidence is separate; full original role/state/scale/audio and record/local editing parity remain open."},"  ")+"\n"); file.close(); quit(0 if failures.is_empty() else 1)
