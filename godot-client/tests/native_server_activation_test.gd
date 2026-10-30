extends "res://tests/native_quickbar_frame_test.gd"
const Browser=preload("res://systems/server_browser.gd")
const Painter=preload("res://systems/native_gui_painter.gd")
var ui
var native
var view: Dictionary={}
func open_list() -> void:
	ui.reset(0); ui.open(false,true); ui.entry_stage="browser"
	view={"kind":"browser-view","connection":0,"viewId":1,"tab":"Internet","sourcePage":true,"direct":{"host":"127.0.0.1","port":5125,"name":"Nibs"},"hasSessionProfile":true,"canJoin":true,"canDiscover":false,"localOnly":true,"hasSavedCdKey":true,"page":0,"pages":1,"rows":[{"entryId":0,"host":"127.0.0.1","port":5125,"serverName":"Owned one","passwordRequired":false,"selected":false,"allowed":true},{"entryId":1,"host":"127.0.0.1","port":5126,"serverName":"Owned two","passwordRequired":true,"selected":false,"allowed":true}],"busy":false}
	ui.receive(view); await process_frame
func row_down(index: int,double_click: bool=false) -> void:
	var point: Vector2=native.pages.Internet.rows[index].get_global_rect().get_center(); await motion(point)
	var event:=InputEventMouseButton.new(); event.position=point; event.global_position=point; event.button_index=MOUSE_BUTTON_LEFT; event.pressed=true; event.double_click=double_click; event.button_mask=MOUSE_BUTTON_MASK_LEFT; surface.push_input(event,true); await process_frame
func row_up(index: int) -> void:
	await mouse(native.pages.Internet.rows[index].get_global_rect().get_center(),false)
func acknowledge(index: int,origin: int=1,overrides: Dictionary={}) -> void:
	view.viewId=int(view.viewId)+1
	for row in view.rows: row.selected=int(row.entryId)==index
	view.selectionAck={"requestViewId":origin,"host":view.rows[index].host,"port":view.rows[index].port}; view.merge(overrides,true); ui.receive(view)
	await process_frame
func run() -> void:
	var output:=""; var install:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
		if arg.begins_with("--install="): install=arg.substr(10)
	if output.is_empty() or install.is_empty() or FileAccess.file_exists(output): quit(2); return
	root.size=Vector2i(1200,850); surface=SubViewport.new(); surface.size=root.size; surface.gui_disable_input=false; surface.handle_input_locally=true; root.add_child(surface); surface.notify_mouse_entered()
	var catalog:=Catalog.new(); check(catalog.mount_install(install),"Original browser resources mount read-only")
	var text=preload("res://systems/native_data/talk_text.gd").new(); check(text.base.open_file(install.path_join("lang/en/data/dialog.tlk")),"Original captions use installed TLK")
	var painter:=Painter.new(); surface.add_child(painter); painter.configure_source(catalog,ProjectSettings.globalize_path("user://native-prepared-v2"))
	ui=Browser.new(); surface.add_child(ui); ui.request.connect(func(message):requests.append(message.duplicate(true))); ui.configure_native(painter,text,catalog,ProjectSettings.globalize_path("user://native-prepared-v2")); native=ui.native_browser
	check(await wait_until(func():return native.layout_ready and ui.password_dialog.layout_ready and ui.details_dialog.layout_ready or not native.failure.is_empty()),"Original browser/password/Details owners prepare")
	if native.layout_ready:
		await open_list(); var before:=requests.size(); await row_down(0)
		check(requests.size()==before+1 and requests.back().operation=="select" and ui.selected==-1,"A real list mouse-down submits selection before release, matching the original")
		await row_up(0); check(requests.size()==before+1,"Releasing a source row cannot submit a second selection")
		await row_down(0,true); await row_up(0)
		check(requests.size()==before+1 and ui.selection_pending.get("activate",false),"A fast double-click waits for its own outstanding selection without sending an unscoped join")
		await acknowledge(0)
		check(requests.back().operation=="join" and not requests.back().direct and requests.back().entryId==0 and ui.selection_pending.is_empty(),"The exact authoritative endpoint acknowledgment completes the queued double-click through Connect")
		before=requests.size(); ui.receive(view)
		check(requests.size()==before,"A repeated selection reply cannot connect twice")
		await open_list(); await row_down(1,true); await row_up(1); before=requests.size(); await acknowledge(1)
		check(ui.password_dialog.visible and requests.size()==before,"Double-clicking a protected server opens the original password child after selection, without a passwordless join")
		ui.password_dialog.edits.passwordeditbox.text="discarded secret"; ui.escape()
		check(ui.password_dialog.edits.passwordeditbox.text.is_empty() and requests.size()==before,"Canceling the double-click password prompt clears the draft and sends no join")
		await open_list(); await row_down(0,true); await row_up(0); before=requests.size(); await acknowledge(0,0)
		check(requests.size()==before and ui.selection_pending.is_empty(),"An acknowledgment for another request cannot authorize the queued activation")
		await open_list(); await row_down(0,true); await row_up(0); before=requests.size(); await acknowledge(0,1,{"selectionAck":null})
		check(requests.size()==before,"A generic refresh or rejection without a selection acknowledgment cannot auto-connect")
		await open_list(); await row_down(0,true); await row_up(0); before=requests.size(); await acknowledge(1)
		check(requests.size()==before and not ui.password_dialog.visible,"A changed selected endpoint cannot redirect a queued double-click")
		await open_list(); await row_down(0,true); await row_up(0); view.rows[0].allowed=false; before=requests.size(); await acknowledge(0)
		check(requests.size()==before,"A policy-blocked endpoint remains unjoinable after queued activation")
		await open_list(); await row_down(0,true); await row_up(0); before=requests.size(); await acknowledge(0,1,{"canJoin":false})
		check(requests.size()==before,"Authoritative admission refusal disables queued activation")
		await open_list(); await row_down(0,true); await row_up(0); ui.back(); before=requests.size(); await acknowledge(0)
		check(requests.size()==before and ui.selection_pending.is_empty(),"Back cancels a pending double-click even if its selection reply arrives later")
		await open_list(); await row_down(0); await row_up(0); await acknowledge(0); before=requests.size(); await row_down(0,true); await row_up(0)
		check(requests.size()==before+1 and requests.back().operation=="join","Double-clicking an already acknowledged row uses Connect immediately")
		await open_list(); await row_down(0); await row_up(0); before=requests.size(); await key(KEY_ENTER); await key(KEY_ENTER,false)
		check(requests.size()==before and ui.selection_pending.get("activate",false),"Enter can request activation while the clicked selection is pending")
		await acknowledge(0); check(requests.back().operation=="join","Enter uses the same authoritative Connect path after acknowledgment")
		await open_list(); await row_down(0); await row_up(0); await acknowledge(0); await key(KEY_DOWN); await key(KEY_DOWN,false); before=requests.size(); await key(KEY_KP_ENTER); await key(KEY_KP_ENTER,false)
		check(requests.size()==before and ui.selection_pending.get("activate",false),"Keypad Enter can wait for an authoritative cursor-key selection")
		await acknowledge(1,2); check(ui.password_dialog.visible,"Cursor navigation plus Enter respects the newly selected server's password requirement")
		ui.escape(); await row_down(0); await row_up(0); view.viewId=4; view.rows[1].selected=false; view.rows[0].selected=true; view.selectionAck=null; ui.receive(view); ui.open_details(); before=requests.size(); await key(KEY_ENTER); await key(KEY_ENTER,false)
		check(requests.size()==before,"An underlying list cannot activate through the Details modal")
		ui.reset(1); before=requests.size(); await key(KEY_ENTER); await key(KEY_ENTER,false)
		check(requests.size()==before and ui.selection_pending.is_empty(),"Connection replacement retires queued keyboard activation")
	ui.close_native(); check(native.closed and native.assets.running.is_empty(),"Native activation owners release workers cleanly")
	ui.free(); painter.close(); painter.free(); text.close(); await process_frame; await process_frame
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"publicConnections":0,"fullUiParity":false,"scope":"Headless real native mouse/key dispatch and scoped selection/password/join request semantics; no actual login, graphical/original-client comparison or full-role acceptance."},"  ")+"\n"); file.close(); quit(0 if failures.is_empty() else 1)
