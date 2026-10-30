extends "res://native_session_world.gd"
const Painter=preload("res://systems/native_gui_painter.gd")
const Talk=preload("res://systems/native_data/talk_text.gd")
var checks:=0
var failures: Array=[]
var requests: Array=[]
func check(ok: bool,description: String) -> bool:
	checks+=1
	if not ok: failures.append(description); print("FAIL ",description)
	return ok
func wait_for(predicate: Callable) -> bool:
	var deadline:=Time.get_ticks_msec()+30000
	while not predicate.call() and Time.get_ticks_msec()<deadline: await process_frame
	return predicate.call()
func click(button: Control) -> void:
	var point:=button.get_global_rect().get_center()
	for pressed in [true,false]:
		var event:=InputEventMouseButton.new(); event.position=point; event.global_position=point; event.button_index=MOUSE_BUTTON_LEFT; event.pressed=pressed
		root.push_input(event,true); await process_frame
func list_view(connection: int,id: int,tab: String) -> Dictionary:
	return {"kind":"browser-view","connection":connection,"viewId":id,"tab":tab,"sourcePage":tab!="Direct","direct":{"host":"127.0.0.1","port":5121,"name":"Local Tester"},"hasSessionProfile":true,"canJoin":true,"canDiscover":false,"localOnly":true,"hasSavedCdKey":true,"page":0,"pages":1,"total":0,"rows":[],"busy":false}
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("report") or not args.has("install") or FileAccess.file_exists(args.report): quit(2); return
	root.size=Vector2i(1280,850)
	host=Node3D.new(); root.add_child(host); label=Label.new(); host.add_child(label)
	world_retirement=WorldRetirement.new(); host.add_child(world_retirement); catalog_retirement=WorldRetirement.new(); host.add_child(catalog_retirement)
	loading_screen=preload("res://systems/native_loading_screen.gd").new(); host.add_child(loading_screen)
	render_menu=MainMenu.new(); host.add_child(render_menu)
	server_browser=Browser.new(); host.add_child(server_browser); server_browser.request.connect(send); server_browser.closed.connect(server_browser_closed)
	character_lobby=Lobby.new(); host.add_child(character_lobby); character_lobby.native_frontend=true; character_lobby.preferences.open_file(""); character_lobby.request.connect(lobby_request)
	receive({"kind":"lobby","connection":1,"state":{"phase":"menu","connected":false,"busy":false,"canJoin":true,"choices":[]}})
	check(not character_lobby.panel.visible,"Native frontend keeps an idle character lobby hidden")
	var base:=Catalog.new(); check(base.mount_install(args.install),"Installed native UI assets mount read-only")
	var text:=Talk.new(); check(text.base.open_file(str(args.install).path_join("lang/en/data/dialog.tlk")),"Installed original labels open read-only")
	var painter:=Painter.new(); host.add_child(painter); painter.configure_source(base,ProjectSettings.globalize_path("user://native-prepared-v2"))
	server_browser.configure_native(painter,text,base,ProjectSettings.globalize_path("user://native-prepared-v2")); character_lobby.prepare_native_frontend(painter,text,base,ProjectSettings.globalize_path("user://native-prepared-v2"))
	var ready:=await wait_for(func():return server_browser.native_browser.layout_ready and server_browser.entry_menu.art_ready() and character_lobby.native_chooser.art_ready())
	check(ready,"Original server pages, Multiplayer menu and chooser prepare without a connection")
	if ready:
		server_browser.open_list(); receive(list_view(1,11,"History")); await process_frame
		check(server_browser.native_browser.visible and not server_browser.panel.visible and server_browser.last_list_tab=="History","Initial canonical native History page is visible without the prototype")
		receive({"kind":"browser-closed","connection":1})
		receive({"kind":"lobby","connection":1,"state":{"phase":"character-selection","connected":true,"canSelect":true,"busy":false,"choices":[]}}); await process_frame
		check(character_lobby.panel.visible and character_lobby.native_chooser.visible and not character_lobby.window_column.visible,"Actual original character chooser is the active surface before Cancel")
		var at:=requests.size(); await click(character_lobby.native_chooser.buttons.cancelbutton)
		check(requests.size()==at+1 and requests.back().kind=="lobby-disconnect" and requests.back().connection==1 and not requests.back().saveCharacter,"Original Cancel issues exactly one scoped disconnect without exporting a server character")
		check(not character_lobby.panel.visible and cancelled_connection==1,"Cancel immediately retires the chooser without flashing prototype controls")
		receive({"kind":"lobby","connection":2,"state":{"phase":"disconnecting","connected":true,"busy":true,"choices":[]}})
		check(not character_lobby.panel.visible and not server_browser.wanted,"Disconnect acknowledgment shows neither retired picker nor a premature browser")
		receive({"kind":"lobby","connection":2,"state":{"phase":"menu","connected":false,"busy":false,"canJoin":true,"choices":[]}})
		check(requests.back().kind=="browser-input" and requests.back().operation=="open" and requests.back().listTab=="History" and requests.back().connection==2,"Authoritative leave completion requests the previous native list on the new connection")
		check(server_browser.entry_context and server_browser.entry_stage=="browser" and not server_browser.panel.visible and not character_lobby.panel.visible and label.text.is_empty(),"Pending browser opening cannot expose either prototype or stale disconnect status")
		receive(list_view(2,12,"History")); await process_frame
		check(server_browser.native_browser.visible and not server_browser.entry_menu.visible and not server_browser.panel.visible and not character_lobby.panel.visible,"Character Cancel returns directly to the native server browser")
		if DisplayServer.get_name()!="headless":
			check(await wait_for(func():return painter.art.waiting.is_empty() and painter.fonts.pending.is_empty()),"Returned server-list artwork settles")
			await RenderingServer.frame_post_draw
			check(root.get_texture().get_image().save_png(str(args.report).trim_suffix(".json")+"-returned.png")==OK,"Returned native server browser captured")
		await click(server_browser.native_browser.pages.History.buttons.cancelbutton)
		check(server_browser.entry_stage=="entry" and requests.back().operation=="return-menu" and not character_lobby.panel.visible,"Server-list Back returns to the original Multiplayer entry, never character selection")
		receive(list_view(2,13,"Direct")); await process_frame
		check(server_browser.entry_menu.visible and not server_browser.panel.visible,"Original Multiplayer entry is the only visible browser-owned surface")
		await click(server_browser.entry_menu.buttons.cancelbutton)
		check(not server_browser.wanted and not character_lobby.panel.visible and render_menu.panel.visible,"Multiplayer Cancel exits to Main Menu without reviving a retired character lobby")
		receive({"kind":"lobby","connection":2,"state":{"phase":"menu","connected":false,"busy":false,"choices":[]}})
		check(not character_lobby.panel.visible,"A later idle lobby update cannot resurrect prototype character selection")
		server_browser.return_to_main=false; server_browser_closed()
		check(not character_lobby.panel.visible and render_menu.panel.visible,"Legacy dismissal also cannot return a disconnected user to character selection")
	character_lobby.close_native(); character_lobby.native_preview.close(); character_lobby.local_catalog.close(); server_browser.close_native(); painter.close(); text.close()
	world_retirement.close(); catalog_retirement.close(); host.free(); await process_frame; await process_frame
	var file:=FileAccess.open(args.report,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"publicConnections":0,"requests":requests,"scope":"Actual source-defined Cancel/Back controls through the native session owner; authoritative lobby/browser replies are local fixtures. No public or game-server connection."},"  ")+"\n"); file.close(); quit(0 if failures.is_empty() else 1)
func send(value: Dictionary) -> void:
	var scoped:=value.duplicate(true); scoped.connection=session_connection; requests.append(scoped)
