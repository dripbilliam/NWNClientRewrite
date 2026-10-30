extends "res://tests/native_character_lobby_keyboard_frame_test.gd"
class UnhandledKeys extends Node:
	var pressed: Array=[]
	func _unhandled_key_input(event: InputEvent) -> void:
		if event is InputEventKey and event.pressed: pressed.append(event.keycode)
func run() -> void:
	var output:=""; var install:=""; var oracle:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
		if arg.begins_with("--install="): install=arg.substr(10)
		if arg.begins_with("--oracle="): oracle=arg.substr(9)
	if output.is_empty() or install.is_empty() or oracle.is_empty() or FileAccess.file_exists(output): quit(2); return
	var observed: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(oracle))
	check(observed.get("target")=="3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a" and observed.rows.size()==64,"Hidden-edit observations identify the exact original binary and64 cases")
	for row in observed.rows:
		check(row.handled==1 and row.constructor.submitCallback=="0x1401e58c0" and row.constructor.cancelCallback=="0x1401e58c0" and row.constructor.next==0 and row.constructor.previous==0,"Original base edit consumes the key with initially unassigned callbacks/focus links: "+str(row.case))
	root.size=Vector2i(1200,850); surface=SubViewport.new(); surface.size=root.size; surface.render_target_update_mode=SubViewport.UPDATE_ALWAYS; surface.gui_disable_input=false; surface.handle_input_locally=true; root.add_child(surface)
	var catalog:=Catalog.new(); check(catalog.mount_install(install),"Original chooser resources mount read-only")
	var text=preload("res://systems/native_data/talk_text.gd").new(); check(text.base.open_file(install.path_join("lang/en/data/dialog.tlk")),"Native hidden-edit behavior uses the installed chooser TLK")
	var painter:=Painter.new(); surface.add_child(painter); painter.configure_source(catalog,ProjectSettings.globalize_path("user://native-prepared-v2"))
	ui=Lobby.new(); surface.add_child(ui); ui.request.connect(func(message):requests.append(message.duplicate(true))); ui.configure_native(painter,text,catalog,ProjectSettings.globalize_path("user://native-prepared-v2")); native=ui.native_chooser
	var observer:=UnhandledKeys.new(); surface.add_child(observer)
	var neighbor:=LineEdit.new(); neighbor.position=Vector2(5,5); neighbor.size=Vector2(100,25); surface.add_child(neighbor)
	check(await wait_until(func():return native.layout_ready or not native.failure.is_empty()),"Original chooser layout becomes ready for actual key input")
	check(native.failure.is_empty(),"Original hidden-edit layout has no preparation failure")
	if native.layout_ready:
		state={"phase":"character-selection","connected":true,"canSelect":true,"selected":"server:a","choices":[{"key":"server:a","label":"Alpha","source":"server","serverSource":17}]}; await present()
		native.focus_next=neighbor.get_path(); native.focus_previous=neighbor.get_path(); native.grab_focus(); var count:=requests.size()
		for pair in [[13,KEY_ENTER],[10,KEY_KP_ENTER],[27,KEY_ESCAPE],[9,KEY_TAB],[8,KEY_BACKSPACE],[0x123,KEY_END],[0x124,KEY_HOME],[0x12e,KEY_DELETE],[65,KEY_A],[32,KEY_SPACE]]:
			for shift in [false,true]:
				native.grab_focus(); observer.pressed.clear(); await key(pair[1],true,shift); await key(pair[1],false,shift)
				var original: Array=observed.rows.filter(func(row):return int(row.case.key)==pair[0] and bool(row.case.shift)==shift and not row.case.links)
				check(original.size()==1 and original[0].handled==1 and native.has_focus() and observer.pressed.is_empty() and requests.size()==count,"Original hidden-edit key stays owned without triggering another menu, Tab target or Play: "+str(pair[0])+" shift="+str(shift))
		neighbor.grab_focus(); await key(KEY_A); await key(KEY_A,false)
		check(neighbor.has_focus() and requests.size()==count,"The chooser does not capture a different focused text control")
		native.grab_focus(); state.canSelect=false; await present(); observer.pressed.clear(); await key(KEY_ESCAPE); await key(KEY_ESCAPE,false); await key(KEY_TAB); await key(KEY_TAB,false)
		check(native.has_focus() and observer.pressed.is_empty() and requests.size()==count,"An unavailable chooser still owns its edit keys without selecting or canceling")
		state.canSelect=true; state.choices=[]; state.selected=null; await present(); observer.pressed.clear(); await key(KEY_ENTER); await key(KEY_ENTER,false)
		check(native.has_focus() and observer.pressed.is_empty() and requests.size()==count,"An empty chooser consumes Enter without submitting an absent character")
		ui.panel.hide(); observer.pressed.clear(); await key(KEY_ESCAPE); await key(KEY_ESCAPE,false)
		check(not native.has_focus() and observer.pressed==[KEY_ESCAPE],"A hidden chooser releases edit ownership so other UI can handle Escape")
		ui.panel.show(); await process_frame; ui.panel.scale=Vector2(1.25,1.25); native.grab_focus(); observer.pressed.clear(); await key(KEY_TAB,true,true); await key(KEY_TAB,false,true)
		check(native.has_focus() and observer.pressed.is_empty(),"The original no-target Shift-Tab behavior survives125-percent UI scale")
	var window_state:={"focused":root.has_focus(),"unfocusable":root.unfocusable,"screen":root.current_screen,"primary":DisplayServer.get_primary_screen(),"mouse_mode":Input.mouse_mode}
	ui.close_native(); ui.free(); painter.close(); painter.free(); text.close(); await process_frame; await process_frame
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"window":window_state,"publicConnections":0,"fullUiParity":false,"fullCharacterLobbyParity":false,"scope":"Original constructor/base-edit observations plus actual native focused key consumption. Hidden text-buffer internals are not reproduced; no submit/cancel/Tab action is invented. Full UI/source-state parity and authoritative local checks remain separate."},"  ")+"\n"); file.close(); quit(0 if failures.is_empty() else 1)
