extends "res://tests/native_character_lobby_frame_test.gd"
func acknowledge() -> void:
	var selected: Dictionary=ui.native_selection.duplicate()
	state.selected=selected.key; state.selectionAck={"key":selected.key,"requestId":selected.requestId}; await present(ui.connection)
func run() -> void:
	var output:=""; var install:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
		if arg.begins_with("--install="): install=arg.substr(10)
	if output.is_empty() or install.is_empty() or FileAccess.file_exists(output): quit(2); return
	root.size=Vector2i(1200,850); surface=SubViewport.new(); surface.size=root.size; surface.render_target_update_mode=SubViewport.UPDATE_ALWAYS; surface.gui_disable_input=false; surface.handle_input_locally=true; root.add_child(surface); surface.notify_mouse_entered()
	var catalog:=Catalog.new(); check(catalog.mount_install(install),"Original chooser resources mount read-only for key input")
	var text=preload("res://systems/native_data/talk_text.gd").new(); check(text.base.open_file(install.path_join("lang/en/data/dialog.tlk")),"Chooser uses original localized text")
	var painter:=Painter.new(); surface.add_child(painter); painter.configure_source(catalog,ProjectSettings.globalize_path("user://native-prepared-v2"))
	ui=Lobby.new(); surface.add_child(ui); ui.request.connect(func(message):requests.append(message.duplicate(true))); ui.configure_native(painter,text,catalog,ProjectSettings.globalize_path("user://native-prepared-v2")); native=ui.native_chooser
	var choices: Array=[]
	for at in range(39,-1,-1): choices.append({"key":"server:%02d"%at,"label":"Character %02d"%at,"source":"server","serverSource":2})
	state={"phase":"character-selection","connected":true,"canSelect":true,"canCreate":true,"selected":null,"choices":choices}; await present()
	check(await wait_until(func():return native.layout_ready and native.rows.size()==40 and native.has_focus()),"Original hidden-edit behavior gives the visible chooser internal GUI keyboard ownership")
	check(requests.back().kind=="lobby-choose" and requests.back().key=="server:00" and not ui.native_selection.is_empty() and native.buttons.playbutton.disabled,"Original automatic selection requests the first sorted character and keeps Play pending until acknowledgment")
	var old: Dictionary=ui.native_selection.duplicate(); await key(KEY_RIGHT); await key(KEY_RIGHT,false)
	check(requests.back().key=="server:01" and ui.native_selection.requestId>old.requestId,"Rapid cursor input advances from the pending selection rather than stale received state")
	state.selected=old.key; state.selectionAck={"key":old.key,"requestId":old.requestId}; await present()
	check(ui.native_selection.key=="server:01" and native.buttons.playbutton.disabled,"An older selection acknowledgment cannot release the current pending choice")
	await acknowledge()
	check(ui.native_selection.is_empty() and native.rows[1].button_pressed and not native.buttons.playbutton.disabled,"Matching authoritative state selects the row and releases Play once")
	var count:=requests.size(); await key(KEY_LEFT); await key(KEY_LEFT,false)
	check(requests.size()==count+1 and requests.back().key=="server:00","Left requests one previous row; key release issues no selection")
	await acknowledge(); await key(KEY_UP); await key(KEY_UP,false)
	check(requests.back().key=="server:00","Up at the first row stays at the boundary without wrapping")
	await acknowledge(); await click(native.tabs[1].get_global_rect().get_center()); await key(KEY_DOWN); await key(KEY_DOWN,false)
	check(native.page_index==0 and requests.back().kind=="lobby-choose" and requests.back().key=="server:01","Cursor selection from Server Info restores Character like the original callback")
	await acknowledge(); var edit:=LineEdit.new(); surface.add_child(edit); edit.position=Vector2(5,5); edit.size=Vector2(90,25); edit.grab_focus(); count=requests.size(); await key(KEY_DOWN); await key(KEY_DOWN,false)
	check(requests.size()==count,"The chooser does not intercept keys from another focused text control")
	edit.free(); await process_frame; check(await wait_until(func():return native.has_focus()),"Chooser restores internal keyboard ownership when the other control releases it")
	state.selected="server:00"; state.selectionAck=null; await present(2); native.list.scroll_vertical=0
	for at in 12: await key(KEY_DOWN); await key(KEY_DOWN,false)
	check(requests.back().key=="server:12" and native.list.scroll_vertical>0,"Repeated cursor input crosses the viewport using original row-sized scroll requests")
	await acknowledge(); var row_rect: Rect2=native.rows[12].get_global_rect(); var list_rect: Rect2=native.list.get_global_rect()
	check(row_rect.position.y>=list_rect.position.y-1 and row_rect.end.y<=list_rect.end.y+1,"Acknowledged keyboard selection is visible in the original viewport")
	ui.panel.scale=Vector2(1.25,1.25); ui.panel.position=Vector2(50,40); await process_frame; await key(KEY_UP); await key(KEY_UP,false)
	check(requests.back().key=="server:11","Cursor movement still advances exactly one row at125-percent scale")
	await acknowledge(); count=requests.size(); ui.panel.hide(); await key(KEY_DOWN); await key(KEY_DOWN,false)
	check(requests.size()==count and not native.has_focus(),"Hidden chooser releases keyboard ownership and cannot submit selections")
	ui.panel.show(); await process_frame; state.canSelect=false; await present(2); count=requests.size(); await key(KEY_DOWN); await key(KEY_DOWN,false)
	check(requests.size()==count,"Unavailable/busy character selection ignores cursor requests")
	state.canSelect=true; state.choices=[]; state.selected=null; state.selectionAck=null; await present(3); count=requests.size(); await key(KEY_DOWN); await key(KEY_DOWN,false)
	check(requests.size()==count,"An empty catalog never requests a nonexistent character")
	check(not requests.any(func(message):return message.kind=="lobby-play"),"Cursor navigation never fabricates Play or enters a world")
	var window_state:={"focused":root.has_focus(),"unfocusable":root.unfocusable,"screen":root.current_screen,"primary":DisplayServer.get_primary_screen(),"mouse_mode":Input.mouse_mode}
	ui.close_native(); ui.free(); painter.close(); painter.free(); await process_frame; await process_frame
	var out:=FileAccess.open(output,FileAccess.WRITE); out.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"window":window_state,"publicConnections":0,"fullUiParity":false,"fullCharacterLobbyParity":false,"scope":"Actual native cursor input, pending/matching/stale selection acknowledgments, boundaries, original scrolling, page return,125-percent and hidden/text-focus/empty guards. Service states are fixtures; real local admission remains separate."},"  ")+"\n"); out.close(); quit(0 if failures.is_empty() else 1)
