extends "res://tests/native_quickbar_frame_test.gd"
const Browser=preload("res://systems/server_browser.gd")
const Painter=preload("res://systems/native_gui_painter.gd")
func run() -> void:
	var output:=""; var install:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
		if arg.begins_with("--install="): install=arg.substr(10)
	if output.is_empty() or install.is_empty() or FileAccess.file_exists(output): quit(2); return
	root.size=Vector2i(1200,850); surface=SubViewport.new(); surface.size=root.size; surface.gui_disable_input=false; surface.handle_input_locally=true; root.add_child(surface); surface.notify_mouse_entered()
	var catalog:=Catalog.new(); check(catalog.mount_install(install),"Original browser resources mount read-only")
	var text=preload("res://systems/native_data/talk_text.gd").new(); check(text.base.open_file(install.path_join("lang/en/data/dialog.tlk")),"Original captions resolve from installed TLK")
	var painter:=Painter.new(); surface.add_child(painter); painter.configure_source(catalog,ProjectSettings.globalize_path("user://native-prepared-v2"))
	var ui:=Browser.new(); surface.add_child(ui); ui.request.connect(func(message):requests.append(message.duplicate(true))); ui.configure_native(painter,text,catalog,ProjectSettings.globalize_path("user://native-prepared-v2"))
	var native=ui.native_browser
	check(await wait_until(func():return native.layout_ready and ui.details_dialog.layout_ready and ui.filter_dialog.layout_ready or not native.failure.is_empty()),"Native browser and modal owners prepare")
	if native.layout_ready:
		ui.open(false,true); ui.entry_stage="browser"
		var view:={"kind":"browser-view","connection":0,"viewId":1,"tab":"Internet","sourcePage":true,"direct":{"host":"127.0.0.1","port":5125,"name":"Nibs"},"hasSessionProfile":true,"canJoin":true,"canDiscover":false,"localOnly":true,"hasSavedCdKey":true,"page":0,"pages":1,"rows":[],"busy":false}
		for index in 40: view.rows.append({"entryId":index,"host":"127.0.0.1","port":5125+index,"serverName":"Owned %02d"%index,"moduleName":"Prelude","selected":false,"allowed":true})
		ui.receive(view); await process_frame
		var before:=requests.size(); await key(KEY_DOWN); await key(KEY_DOWN,false)
		check(requests.size()==before,"Opening a browser does not steal cursor keys before a list click")
		await click(native.pages.Internet.rows[0].get_global_rect().get_center())
		check(requests.back().operation=="select" and native.has_focus(),"Clicking a real source row captures internal list keyboard ownership")
		view.viewId=2; view.rows[0].selected=true; ui.receive(view); await key(KEY_DOWN); await key(KEY_DOWN,false)
		check(requests.back().operation=="selection-step" and requests.back().direction==1 and ui.selected==0 and ui.state.busy,"Down asks the authoritative catalog for one row without locally inventing selection")
		before=requests.size(); await key(KEY_DOWN); await key(KEY_DOWN,false)
		check(requests.size()==before,"Repeated input cannot submit a stale row step while its acknowledgment is pending")
		view.viewId=3; view.rows[0].selected=false; view.rows[1].selected=true; ui.receive(view); await key(KEY_LEFT); await key(KEY_LEFT,false)
		check(requests.back().operation=="selection-step" and requests.back().direction==-1,"Left shares the original previous-row action")
		view.viewId=4; ui.receive(view); await key(KEY_RIGHT); await key(KEY_RIGHT,false)
		check(requests.back().direction==1,"Right shares the original next-row action")
		view.viewId=5; ui.receive(view); await key(KEY_UP); await key(KEY_UP,false)
		check(requests.back().direction==-1,"Up shares the original previous-row action")
		view.viewId=6; view.rows[1].selected=false; view.rows[39].selected=true; ui.receive(view); await process_frame; await process_frame
		check(native.pages.Internet.scroll.scroll_vertical>0,"An acknowledged offscreen selection scrolls the original shared list viewport to reveal the row")
		ui.open_details(); before=requests.size(); await key(KEY_DOWN); await key(KEY_DOWN,false)
		check(not native.has_focus() and requests.size()==before,"A native Details modal releases the underlying list's keyboard ownership")
		ui.escape(); view.viewId=7; ui.receive(view); native.grab_focus(); native.list_keyboard=true; ui.back(); before=requests.size(); await key(KEY_RIGHT); await key(KEY_RIGHT,false)
		check(requests.size()==before and not native.has_focus(),"Returning to Multiplayer retires list keyboard input")
		check(requests.all(func(message):return message.operation!="join"),"Cursor navigation never initiates a server connection")
	ui.close_native(); check(native.closed and native.assets.running.is_empty(),"Native keyboard owner releases resource workers")
	ui.free(); painter.close(); painter.free(); text.close(); await process_frame; await process_frame
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"publicConnections":0,"fullUiParity":false,"scope":"Headless actual native pointer/key dispatch, scoped authoritative selection and reveal, modal/retirement ownership; no pixels or original-client side-by-side comparison."},"  ")+"\n"); file.close(); quit(0 if failures.is_empty() else 1)
