extends "res://tests/native_quickbar_frame_test.gd"
const Menu=preload("res://systems/native_main_menu.gd")
func row_click(owner,id: String,button: MouseButton=MOUSE_BUTTON_LEFT) -> void:
	var row: Button=owner.row_buttons[id]
	owner.scroller.scroll_vertical=maxi(0,int(row.position.y-owner.scroller.size.y*0.5)); await process_frame; await process_frame
	await click(row.get_global_rect().get_center(),button)
func capture(output: String,suffix: String) -> void:
	await RenderingServer.frame_post_draw; surface.get_texture().get_image().save_png(output.trim_suffix(".json")+suffix+".png")
func run() -> void:
	var output:=""; var install:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
		if arg.begins_with("--install="): install=arg.substr(10)
	if output.is_empty() or install.is_empty() or FileAccess.file_exists(output): quit(2); return
	root.size=Vector2i(1424,921); surface=SubViewport.new(); surface.size=root.size; surface.render_target_update_mode=SubViewport.UPDATE_ALWAYS; surface.gui_disable_input=false; surface.handle_input_locally=true; root.add_child(surface); surface.notify_mouse_entered()
	var display:=TextureRect.new(); root.add_child(display); display.texture=surface.get_texture(); display.size=root.size; display.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var catalog:=Catalog.new(); check(catalog.mount_install(install),"Original key editor catalog mounts read-only")
	var ui:=Gameplay.new(); surface.add_child(ui); ui.configure(catalog,install,ProjectSettings.globalize_path("user://native-prepared-v2"),output+".layout.cfg")
	check(await wait_until(func():return ui.tables_ready and ui.inventory.frame_skin.layout_ready and ui.key_bindings.bindings_ready),"Native Keymap, table, font and shared source-art owners prepare")
	var world:=WorldInput.new(); surface.add_child(world)
	var menu:=Menu.new(); surface.add_child(menu); menu.layout_path=output+".layout.cfg"; menu.key_bindings=ui.key_bindings
	menu.playing_query=func():return true
	menu.connection_query=func():return true
	menu.configure_native(ui.inventory.frame_skin,ui.text,catalog,ProjectSettings.globalize_path("user://native-prepared-v2"),[1,1,55,42]); menu.observe_lobby({"connected":true,"busy":false,"phase":"playing"}); menu.open(true)
	var editor=menu.key_owner
	check(await wait_until(func():return menu.native_frame.art_ready() and editor.art_ready() or not editor.failure.is_empty()),"Original key editor frames, tabs, rows, fonts and scrollbar prepare")
	var diagnostic: Dictionary={"failure":editor.failure}
	if editor.layout_ready and editor.failure.is_empty():
		check(not menu.native_frame.buttons.controlsbutton.disabled,"Options exposes Change Key Settings only with a ready native binding owner")
		await click(menu.native_frame.buttons.controlsbutton.get_global_rect().get_center())
		check(editor.visible and not menu.panel.visible and editor.size.distance_to(Vector2(430,447))<0.001,"Actual Controls click opens the complete source-sized key editor")
		check(editor.page==0 and editor.buttons.tab0.button_pressed and not editor.buttons.tab1.button_pressed,"Opening selects the original first tab without changing bindings")
		check(editor.row_buttons.has("normal:90") and editor.row_buttons["normal:56"].disabled and editor.row_buttons["normal:56"].tooltip_text.contains("not available"),"Implemented actions can bind while unsupported original actions remain explicit")
		check(editor.heading.get_meta("native_font_applied","")=="fnt_galahad14","Original key editor title uses native bitmap font metrics")
		check(await wait_until(func():return editor.art_ready()),"Original dynamic row state sprites finish publication before visual review")
		check(editor.row_labels["normal:38"].binding.text=="Right Arrow" and editor.row_labels["normal:38"].binding.get_line_count()==1,"Key-caption terminator does not lift Right Arrow into the preceding row")
		await capture(output,"-movement")
		var before: int=world.movement; await key(KEY_W); await key(KEY_W,false)
		check(world.movement==before+1,"Browsing the key editor keeps WASD available outside assignment capture")
		before=world.middle; await click(Vector2(1200,90),MOUSE_BUTTON_MIDDLE); check(world.middle==before+1,"Key editor leaves outside middle-mouse camera input available")
		before=world.clicks; await click(Vector2(1200,90)); check(world.clicks==before+1 and not menu.blocks_pointer(Vector2(1200,90)) and menu.blocks_pointer(editor.get_global_rect().get_center()),"Only the key editor rectangle blocks click movement")
		var start: Vector2=editor.position; var point: Vector2=editor.heading.get_global_rect().get_center(); await motion(point); await mouse(point,true); await motion(point+Vector2(30,18),Vector2(30,18),true); await mouse(point+Vector2(30,18),false)
		var remembered: Vector2=editor.position; var saved:=ConfigFile.new()
		check(remembered.distance_to(start+Vector2(30,18))<1 and saved.load(menu.layout_path)==OK and saved.get_value("positions","key-settings",Vector2.ZERO)==remembered,"Dragging the original key title saves its independent window position")
		await click(editor.buttons.tab1.get_global_rect().get_center())
		check(editor.page==1 and editor.row_buttons.keys().filter(func(id):return str(id).begins_with("hotbar:")).size()==36,"Game tab includes all36 editable hotbar slots after the original source actions")
		check(range(36).all(func(index):return not editor.row_buttons["hotbar:"+str(index)].disabled),"All hotbar banks expose real editable controls")
		await row_click(editor,"hotbar:35")
		check(ui.key_bindings.capturing and editor.row_labels["hotbar:35"].binding.text.is_empty() and editor.row_labels["hotbar:35"].text.get_theme_color("font_color")==Color(0.8,0.1,0.1),"Actual hotbar click begins capture with original blank/red-caption feedback")
		before=world.movement; await key(KEY_W); await key(KEY_W,false)
		check(world.movement==before and not ui.key_bindings.capturing and ui.key_bindings.pending.hotbar[35].key==KEY_W,"Assignment key updates pending data without leaking WASD to the world")
		check(ui.key_bindings.pending.normal.values[90]==0 and editor.row_labels["hotbar:35"].binding.text=="W","Hotbar assignment clears the conflicting normal run binding and updates the visible caption")
		await row_click(editor,"hotbar:35"); await key(KEY_K,true,true,true); await key(KEY_K,false)
		check(ui.key_bindings.pending.hotbar[35]=={"key":KEY_K,"modifiers":3} and editor.row_labels["hotbar:35"].binding.text=="Ctrl + Shift + K","Native editor captures and displays a custom combined modifier chord")
		await capture(output,"-hotbars")
		await click(editor.buttons.cancelbutton.get_global_rect().get_center())
		check(not editor.visible and menu.panel.visible and ui.key_bindings.active.hotbar[35].key==KEY_F12 and ui.key_bindings.active.normal.values[90]==101,"Cancel restores Options and discards both hotbar and conflicting normal edits")
		await click(menu.native_frame.buttons.controlsbutton.get_global_rect().get_center())
		check(editor.position==remembered,"Reopening restores the last key-editor position")
		await click(editor.buttons.tab1.get_global_rect().get_center()); await row_click(editor,"hotbar:35"); await key(KEY_K,true,true,true); await key(KEY_K,false); await click(editor.buttons.closebutton.get_global_rect().get_center())
		saved.load(menu.layout_path)
		check(not editor.visible and menu.panel.visible and ui.key_bindings.active.hotbar[35]=={"key":KEY_K,"modifiers":3} and saved.get_value("HotbarKeymapping","Slot35")=={"key":KEY_K,"modifiers":3},"Original Close commits the hotbar chord to persistent replacement preferences")
		await click(menu.native_frame.buttons.controlsbutton.get_global_rect().get_center()); await click(editor.buttons.tab1.get_global_rect().get_center()); await row_click(editor,"hotbar:35",MOUSE_BUTTON_RIGHT)
		check(ui.key_bindings.pending.hotbar[35].key==0 and editor.row_labels["hotbar:35"].binding.text.is_empty(),"Right-click clears a hotbar key without modifying its server shortcut")
		await click(editor.buttons.xbutton.get_global_rect().get_center()); check(menu.panel.visible and ui.key_bindings.active.hotbar[35].key==0,"Original X uses the same real commit semantics as Close")
		await click(menu.native_frame.buttons.controlsbutton.get_global_rect().get_center()); await click(editor.buttons.tab1.get_global_rect().get_center()); await row_click(editor,"hotbar:35"); await click(editor.buttons.tab0.get_global_rect().get_center())
		check(not ui.key_bindings.capturing and editor.page==0 and ui.key_bindings.pending.hotbar[35].key==0,"Switching original tabs ends capture without inventing an assignment")
		await row_click(editor,"normal:90"); await key(KEY_T); await key(KEY_T,false)
		check(ui.key_bindings.pending.normal.values[90]==98 and editor.row_labels["normal:90"].binding.text=="T","Original action row captures its physical key and visible source caption")
		await key(KEY_ESCAPE); await key(KEY_ESCAPE,false)
		check(menu.panel.visible and not editor.visible and ui.key_bindings.active.normal.values[90]==101,"Escape discards the native action edit and returns to Options")
		await click(menu.native_frame.buttons.controlsbutton.get_global_rect().get_center()); await click(editor.buttons.defaultbutton.get_global_rect().get_center())
		check(ui.key_bindings.pending.hotbar==ui.key_bindings.hotbar_defaults() and ui.key_bindings.active.hotbar[35].key==0,"Defaults restores every hotbar key in the pending transaction only")
		await click(editor.buttons.closebutton.get_global_rect().get_center()); check(ui.key_bindings.active.hotbar==ui.key_bindings.hotbar_defaults(),"Close applies restored native defaults to all36 slots")
		await click(menu.native_frame.buttons.controlsbutton.get_global_rect().get_center()); await row_click(editor,"normal:90"); await key(KEY_T); await key(KEY_T,false); menu.set_native_scope([1,2,99,42])
		check(not editor.visible and not ui.key_bindings.capturing and ui.key_bindings.pending.is_empty() and ui.key_bindings.active.normal.values[90]==101,"Area/scope retirement discards stale editor edits and capture")
		diagnostic=editor.snapshot(); diagnostic.art_failures=ui.inventory.frame_skin.art.failed.keys(); diagnostic.physicalMouseWarped=false
	menu.dismiss(); menu.detach_native(); menu.free(); ui.close(); ui.free(); world.free(); await process_frame; await process_frame
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"diagnostic":diagnostic,"entryOwnerSha256":FileAccess.get_sha256(ProjectSettings.globalize_path("res://native_session_world.gd")),"publicConnections":0,"fullKeySettingsParity":false,"scope":"Native Controls editor pointer/key input, original source artwork and transaction semantics,36 hotbar rows, conflicts, persistence, movement/camera coexistence, retained position and stale scope. Original-server remapped actions, full role/gesture/custom-resource and original-window comparison remain separate."},"  ")+"\n"); file.close(); quit(0 if failures.is_empty() else 1)
