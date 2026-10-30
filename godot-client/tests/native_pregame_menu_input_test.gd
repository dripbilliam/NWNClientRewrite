extends "res://tests/native_quickbar_frame_test.gd"
const Menu=preload("res://systems/native_main_menu.gd")
const WindowSettings=preload("res://systems/native_window_settings.gd")
func press(code: Key) -> void:
	await key(code,true); await key(code,false)
func capture(output: String,suffix: String) -> void:
	await RenderingServer.frame_post_draw
	check(surface.get_texture().get_image().save_png(output.trim_suffix(".json")+suffix+".png")==OK,"Pregame native viewport is retained "+suffix)
func run() -> void:
	var output:=""; var install:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
		if arg.begins_with("--install="): install=arg.substr(10)
	if output.is_empty() or install.is_empty() or FileAccess.file_exists(output): quit(2); return
	root.size=Vector2i(1424,921); surface=SubViewport.new(); surface.size=root.size; surface.render_target_update_mode=SubViewport.UPDATE_ALWAYS; surface.gui_disable_input=false; surface.handle_input_locally=true; root.add_child(surface); surface.notify_mouse_entered()
	var display:=TextureRect.new(); root.add_child(display); display.texture=surface.get_texture(); display.size=root.size; display.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var settings:=WindowSettings.new(); root.add_child(settings); settings.configure(root,output+".settings.cfg")
	var menu:=Menu.new(); surface.add_child(menu); menu.layout_path=output+".layout.cfg"; menu.window_settings=settings
	var events: Array=[]; menu.multiplayer_requested.connect(func():events.append("multiplayer")); menu.options_requested.connect(func():events.append("settings")); menu.exit_requested.connect(func():events.append("exit"))
	menu.configure_pregame({"install":install,"modsDirectory":"","disabledMods":[]},ProjectSettings.globalize_path("user://native-prepared-v2")); menu.open(false)
	var ui=menu.pregame
	check(ui.wanted and not menu.panel.visible and not is_instance_valid(menu.native_frame),"Pregame opens before a game world or borrowed in-game UI exists")
	check(await wait_until(func():return not ui.failure.is_empty() or is_instance_valid(ui.main) and is_instance_valid(ui.options) and ui.main.art_ready() and ui.main.visible and ui.options.art_ready() and ui.keys.layout_ready and ui.bindings.bindings_ready and is_instance_valid(ui.video) and ui.video.layout_ready),"Independent original pregame catalog, art, fonts and child controls finish native preparation and present the main page")
	check(ui.failure.is_empty(),"Pregame resource preparation succeeds: "+ui.failure)
	if is_instance_valid(ui.main) and ui.main.layout_ready and ui.failure.is_empty():
		check(ui.main.visible and not ui.options.visible and ui.main.buttons.size()==7 and not menu.fallback.is_visible_in_tree(),"Actual original seven-button main menu replaces the generic pregame fallback")
		check(not ui.main.buttons.multibutton.disabled and not ui.main.buttons.optionsbutton.disabled and not ui.main.buttons.exitbutton.disabled,"Supported original main-menu actions are enabled")
		check(ui.main.buttons.newbutton.disabled and ui.main.buttons.loadbutton.disabled and ui.main.buttons.moviesbutton.disabled and ui.main.buttons.reponewsbutton.disabled,"Unported local campaign/movie/news actions remain explicit rather than inert enabled controls")
		check(ui.main.captions.reponewsbutton.text=="News" and ui.main.definition.entries.reponewsbutton.caption.AurString_Text=="News","The original literal News caption is rendered instead of leaving a blank menu button")
		await capture(output,"-main")
		await click(ui.main.buttons.optionsbutton.get_global_rect().get_center())
		check(ui.page=="options" and ui.options.visible and not ui.main.visible,"Original Options button opens the distinct pregame source panel")
		check(ui.options.buttons.has("nwsyncbutton") and ui.options.captions.nwsyncbutton.text=="Storage" and ui.options.buttons.nwsyncbutton.disabled,"Original Storage label is retained without substituting a different folder-picker action")
		check(not ui.options.buttons.has("soundbutton") and ui.options.definition.entries.soundbutton.model_deleted_after_init,"Pregame follows the original removed legacy Sound control")
		await capture(output,"-options")
		await click(ui.options.buttons.videooptsbutton.get_global_rect().get_center())
		check(ui.page=="video" and ui.video.visible and not ui.options.visible,"Actual pregame Video action opens the native resolution/scaling owner")
		await click(ui.video.buttons.cancelbutton.get_global_rect().get_center())
		check(ui.page=="options" and ui.options.visible and not ui.video.visible,"Native Video Cancel returns to its pregame Options parent")
		await click(ui.options.buttons.controlbutton.get_global_rect().get_center())
		check(ui.page=="keys" and ui.keys.visible and ui.bindings.valid_transaction(ui.keys.ticket),"Actual pregame Controls opens the source key editor with a private pending transaction")
		await click(ui.keys.buttons.tab1.get_global_rect().get_center())
		check(ui.keys.row_buttons.keys().filter(func(id):return str(id).begins_with("hotbar:")).size()==36,"Pregame key editor exposes all36 user-rebindable hotbar slots")
		await press(KEY_ESCAPE)
		check(ui.page=="options" and ui.options.visible and not ui.keys.visible and not ui.bindings.capturing,"Escape discards pregame key edits and returns to Options")
		await click(ui.options.buttons.gamebutton.get_global_rect().get_center())
		check(events==["settings"] and ui.page=="client-settings" and not ui.options.visible,"Original Game entry reaches the current replacement settings without inventing a complete original ConfigWindow")
		menu.child_closed(); check(ui.options.visible and ui.page=="options","Closing replacement settings restores the pregame Options parent")
		await click(ui.options.buttons.closebutton.get_global_rect().get_center())
		check(ui.main.visible and not ui.options.visible and ui.page=="main","Original Close returns to Main Menu")
		await click(ui.main.buttons.multibutton.get_global_rect().get_center())
		check(events==["settings","multiplayer"] and not ui.visible and not ui.wanted,"Original Multiplayer emits one existing browser route and dismisses pregame UI")
		var presses: Array=[]
		ui.main.buttons.optionsbutton.button_down.connect(func():presses.append({"event":"down","held":ui.main.held.duplicate(true),"revision":ui.main.revision,"scope":ui.scope()}))
		ui.main.buttons.optionsbutton.pressed.connect(func():presses.append({"event":"pressed","held":ui.main.held.duplicate(true),"revision":ui.main.revision,"scope":ui.scope()}))
		ui.main.buttons.optionsbutton.gui_input.connect(func(event):
			if event is InputEventMouseButton: presses.append({"event":"raw-mouse","pressed":event.pressed,"button":event.button_index}))
		menu.open(false); var point: Vector2=ui.main.buttons.optionsbutton.get_global_rect().get_center(); await motion(point); await mouse(point,true)
		menu.dismiss(); menu.open(false); await mouse(point,false)
		check(ui.page=="main" and not ui.options.visible,"A held pregame press cannot act after its presentation scope is retired")
		await click(ui.main.buttons.optionsbutton.get_global_rect().get_center())
		var receivers: Array=[]
		var windows: Array=[]
		for window in root.find_children("*","Window",true,false): windows.append({"path":str(window.get_path()),"visible":window.visible,"exclusive":window.exclusive})
		for control in menu.find_children("*","Control",true,false):
			if control.is_visible_in_tree() and control.mouse_filter!=Control.MOUSE_FILTER_IGNORE and control.get_global_rect().has_point(point): receivers.append({"path":str(control.get_path()),"mouse":control.mouse_filter,"actual_button":control==ui.main.buttons.optionsbutton})
		check(ui.page=="options" and ui.options.visible,"A fresh original Options press remains usable after a retired held press: "+JSON.stringify({"presses":presses,"windows":windows,"pressed":ui.main.buttons.optionsbutton.is_pressed(),"main_visible":ui.main.is_visible_in_tree(),"stage_visible":ui.main.stage.is_visible_in_tree(),"disabled":ui.main.buttons.optionsbutton.disabled,"point":str(ui.main.buttons.optionsbutton.get_global_rect()),"receivers":receivers,"panel_visible":menu.panel.visible,"fallback_visible":menu.fallback.is_visible_in_tree(),"mouse_point":str(surface.get_mouse_position())}))
		await press(KEY_ESCAPE)
		check(ui.page=="main" and ui.main.visible,"Escape returns from pregame Options without issuing a connection or exit: "+JSON.stringify(ui.snapshot()))
		await click(ui.main.buttons.exitbutton.get_global_rect().get_center())
		check(events==["settings","multiplayer","exit"] and not ui.wanted,"Original Exit routes only the application exit request")
	var diagnostic: Dictionary=ui.snapshot(); menu.close_pregame(); await process_frame
	check(not is_instance_valid(menu.pregame),"Pregame joins and releases its independent resource owners before session shutdown")
	check(menu.pregame_cleanup.get("closed",false) and int(menu.pregame_cleanup.get("workers_running",-1))==0,"Every private pregame catalog/art/font/page worker is joined on retirement")
	menu.free(); settings.close(); settings.free(); await process_frame; await process_frame
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"events":events,"pregame":diagnostic,"publicConnections":0,"physicalMouseWarped":false,"fullEntryMenuParity":false,"scope":"Actual installed-resource pregame Main/Options and Video/Controls/Settings return input without a world. Campaign/movie/news/storage/full original modern configuration and broader browser/login/selection parity remain required."},"  ")+"\n"); file.close(); quit(0 if failures.is_empty() else 1)
