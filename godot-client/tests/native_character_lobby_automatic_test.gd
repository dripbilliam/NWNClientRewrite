extends "res://tests/native_character_lobby_frame_test.gd"
func run() -> void:
	var output:=""; var install:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
		if arg.begins_with("--install="): install=arg.substr(10)
	if output.is_empty() or install.is_empty() or FileAccess.file_exists(output): quit(2); return
	root.size=Vector2i(1200,850); surface=SubViewport.new(); surface.size=root.size; surface.render_target_update_mode=SubViewport.UPDATE_ALWAYS; surface.gui_disable_input=false; surface.handle_input_locally=true; root.add_child(surface)
	var catalog:=Catalog.new(); check(catalog.mount_install(install),"Automatic selection uses the original read-only GUI catalog")
	var text=preload("res://systems/native_data/talk_text.gd").new(); check(text.base.open_file(install.path_join("lang/en/data/dialog.tlk")),"Automatic-selection fixture uses the original TLK")
	var painter:=Painter.new(); surface.add_child(painter); painter.configure_source(catalog,ProjectSettings.globalize_path("user://native-prepared-v2"))
	ui=Lobby.new(); surface.add_child(ui); ui.request.connect(func(message):requests.append(message.duplicate(true))); ui.configure_native(painter,text,catalog,ProjectSettings.globalize_path("user://native-prepared-v2")); native=ui.native_chooser
	check(await wait_until(func():return native.layout_ready or not native.failure.is_empty()),"Original chooser layout becomes ready")
	check(native.failure.is_empty(),"Original chooser attachments validate")
	if native.layout_ready:
		var first:={"key":"server:a","label":"Alpha","source":"server","serverSource":17,"classes":[]}
		var last:={"key":"server:z","label":"Zulu","source":"server","serverSource":17,"classes":[]}
		state={"phase":"character-selection","connected":true,"canSelect":true,"selected":"server:a","choices":[first,last]}; await present()
		check(requests.is_empty() and ui.native_selection.is_empty() and not native.buttons.playbutton.disabled,"An already selected initial first row does not duplicate its authoritative request")
		state.selected="server:z"; await present(); var count:=requests.size()
		text.revision+=1; await present()
		check(requests.size()==count and ui.native_selection.is_empty() and state.selected=="server:z","A late TLK refresh preserves an explicit later selection")
		var retired: Button=native.rows[native.row_keys.find("server:a")]
		native.row_signature="@invalidate-during-input"
		await row_down("server:a")
		check(not is_instance_valid(retired) and requests.size()==count+1 and requests.back().key=="server:a" and not ui.native_selection.is_empty(),"A row may rebuild during its own native gui_input without freeing the locked signal owner or duplicating selection")
		state.selected="server:a"; state.selectionAck={"requestId":ui.native_selection.requestId,"key":"server:a"}; await present(); count=requests.size()
		state.selected="server:z"; state.selectionAck=null; await present()
		state.canSelect=false; state.choices=[last]; await present()
		check(requests.size()==count and not native.automatic_selection.is_empty() and native.buttons.playbutton.disabled,"An unavailable catalog rebuild defers first-row selection and keeps Play disabled")
		ui.panel.hide(); state.canSelect=true; ui.state.canSelect=true; native.sync(); await process_frame
		check(requests.size()==count and not native.automatic_selection.is_empty(),"A hidden parent cannot issue the deferred selection")
		ui.panel.show(); await process_frame
		check(requests.size()==count+1 and requests.back().kind=="lobby-choose" and requests.back().key=="server:z" and not ui.native_selection.activate and native.automatic_selection.is_empty(),"Showing the now-available chooser performs exactly one deferred selection without Play")
		await process_frame; native.sync()
		check(requests.size()==count+1,"Repeated visible frames do not duplicate the deferred selection")
		state.selectionAck={"requestId":ui.native_selection.requestId,"key":"server:z"}; await present()
		check(ui.native_selection.is_empty() and not native.buttons.playbutton.disabled,"The deferred request still needs its matching authoritative acknowledgment")
		state.choices=[]; await present(); count=requests.size()
		check(native.rows.is_empty() and native.automatic_selection.is_empty() and native.buttons.playbutton.disabled,"Removing every row cannot leave Play enabled for the old selected key")
		state.canSelect=false; state.choices=[first]; await present()
		check(requests.size()==count and not native.automatic_selection.is_empty(),"A later unavailable catalog retains only its current automatic intent")
		state.canSelect=true; state.selected="server:z"; await present(2)
		check(requests.size()==count+1 and requests.back().connection==2 and requests.back().key=="server:a" and ui.native_selection.connection==2 and not ui.native_selection.activate,"Replacing a deferred catalog selects only the new connection's first row")
		check(requests.all(func(message):return message.kind!="lobby-play"),"No automatic rebuild, visibility change or connection replacement submits a character")
		state.canSelect=false; state.choices=[last]; await present(2); check(not native.automatic_selection.is_empty(),"The close-path fixture has a real deferred selection")
	ui.close_native(); check(native.closed and native.automatic_selection.is_empty() and native.assets.running.is_empty(),"Closing the chooser retires its automatic intent and private workers")
	ui.free(); painter.close(); painter.free(); text.close(); await process_frame; await process_frame
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"publicConnections":0,"fullUiParity":false,"scope":"Original first-visible-row rebuild policy through the native owner, including deferred unavailable/hidden catalogs, exact acknowledgment, empty lists, connection replacement, repaint preservation and worker retirement. State is a fixture; authoritative server checks are separate."},"  ")+"\n"); file.close(); quit(0 if failures.is_empty() else 1)
