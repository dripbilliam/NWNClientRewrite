extends "res://tests/native_quickbar_frame_test.gd"
const Menu=preload("res://systems/native_main_menu.gd")
const Session=preload("res://native_session_world.gd")
func press_key(code: Key) -> void:
	var event:=InputEventKey.new(); event.keycode=code; event.pressed=true; surface.push_input(event,true); await process_frame
	event=event.duplicate(); event.pressed=false; surface.push_input(event,true); await process_frame
func run() -> void:
	var output:=""; var install:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report=" ): output=arg.substr(9)
		if arg.begins_with("--install=" ): install=arg.substr(10)
	if output.is_empty() or install.is_empty() or FileAccess.file_exists(output): quit(2); return
	var entry_owner_hash:=FileAccess.get_sha256(ProjectSettings.globalize_path("res://native_session_world.gd"))
	var entry_script: Script=Session
	check(entry_script.can_instantiate(),"Current native session entry owner and its dependencies compile alongside the menu")
	root.size=Vector2i(1200,850); surface=SubViewport.new(); surface.size=root.size; surface.render_target_update_mode=SubViewport.UPDATE_ALWAYS; surface.gui_disable_input=false; surface.handle_input_locally=true; root.add_child(surface); surface.notify_mouse_entered()
	var display:=TextureRect.new(); root.add_child(display); display.texture=surface.get_texture(); display.size=root.size; display.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var catalog:=Catalog.new(); check(catalog.mount_install(install),"Original menu resources mount read-only")
	var ui:=Gameplay.new(); surface.add_child(ui); ui.configure(catalog,install,ProjectSettings.globalize_path("user://native-prepared-v2"),output+".layout.cfg")
	check(await wait_until(func():return ui.tables_ready and ui.inventory.frame_skin.fonts!=null),"Native table and shared source-font owner prepare")
	var world:=WorldInput.new(); surface.add_child(world)
	var menu:=Menu.new(); surface.add_child(menu); menu.layout_path=output+".layout.cfg"; menu.playing_query=func():return true; menu.connection_query=func():return true
	var events: Array=[]; menu.options_requested.connect(func():events.append("options")); menu.export_requested.connect(func():events.append("export")); menu.disconnect_requested.connect(func():events.append("disconnect")); menu.exit_requested.connect(func():events.append("exit"))
	menu.configure_native(ui.inventory.frame_skin,ui.text,catalog,ProjectSettings.globalize_path("user://native-prepared-v2"),[1,1,55,42]); menu.observe_lobby({"connected":true,"busy":false,"phase":"playing"}); menu.open(true)
	var view=menu.native_frame
	check(await wait_until(func():return view.art_ready() and view.visible or not view.failure.is_empty()),"Original in-game menu and exit confirmation prepare and present source art and fonts")
	var diagnostic: Dictionary={"failure":view.failure}
	if view.layout_ready and view.failure.is_empty():
		ui.inventory.frame_skin.art.waiting["@unrelated-preparation"]=[]
		check(view.art_ready(),"This original menu is ready independently of unrelated shared-painter preparation")
		ui.inventory.frame_skin.art.waiting.erase("@unrelated-preparation")
		check(menu.panel.visible and not menu.fallback.visible and view.definition.size==Vector2(429,447),"Generic in-game menu is replaced by its original429x447 panel")
		check(view.buttons.size()==9 and not view.buttons.has("soundoptionsbutton") and view.definition.entries.soundoptionsbutton.model_deleted_after_init,"Original removed legacy Sound model is not exposed as a new active control")
		check(view.captions.savecharbutton.text==ui.text.raw({"strRef":0x19a0}) and view.captions.videooptionsbutton.text==ui.text.raw({"strRef":0x1baf}),"Menu captions use original runtime Export and Resolution wording")
		check(view.buttons.loadbutton.disabled and view.buttons.savebutton.disabled and view.buttons.controlsbutton.disabled and view.buttons.videooptionsbutton.disabled,"Unimplemented host and child-page capabilities cannot claim functional buttons")
		check(not view.buttons.savecharbutton.disabled and not view.buttons.exitbutton.disabled and not view.buttons.gamebutton.disabled,"Connected idle context enables actual Export, End Game and current settings routing")
		check(view.buttons.gamebutton.size==Vector2(360,42) and ui.inventory.frame_skin.button_geometry[view.buttons.gamebutton.get_instance_id()].styles.hover[1]=="hilite","Original button proportions and hover pose are retained")
		var title: Label=view.stage.get_children().filter(func(child):return child is Label and child.text==ui.text.raw({"strRef":195}))[0]
		check(not title.clip_text and title.size.x>31,"Original unbounded title text is not clipped to the ignored stored label width")
		await shot(output,"-normal")
		var before: int=world.movement; await press_key(KEY_W); check(world.movement==before+1,"WASD remains available while the source menu is open")
		before=world.middle; await mouse(Vector2(1110,80),true,MOUSE_BUTTON_MIDDLE); await mouse(Vector2(1110,80),false,MOUSE_BUTTON_MIDDLE); check(world.middle==before+1,"Middle-mouse world input remains available outside the menu")
		before=world.clicks; await click(Vector2(1110,80)); check(world.clicks==before+1 and not menu.blocks_pointer(Vector2(1110,80)),"Clicks outside the native menu still reach world input")
		await click(view.buttons.savecharbutton.get_global_rect().get_center()); check(events==["export"] and not menu.panel.visible,"Actual original Export control emits its action once and dismisses the menu")
		menu.open(true); menu.observe_lobby({"connected":true,"busy":true,"phase":"playing"}); await process_frame
		await click(view.buttons.savecharbutton.get_global_rect().get_center()); check(events==["export"] and view.buttons.savecharbutton.disabled and view.buttons.exitbutton.disabled,"An authoritative busy/export state prevents duplicate saves and leaving during the pending operation")
		menu.observe_lobby({"connected":true,"busy":false,"phase":"playing"}); await click(view.buttons.exitbutton.get_global_rect().get_center())
		check(view.confirmation.visible and not view.stage.visible and events==["export"],"Original End Game opens its own Yes/No dialog before issuing any disconnect")
		check(view.confirm_body.text==ui.text.raw({"strRef":0x2844}) and not view.confirm_body.text.is_empty(),"Ordinary join-client exit confirmation uses the original message reference")
		await shot(output,"-confirmation")
		await click(view.confirm_buttons.cancelbutton.get_global_rect().get_center()); check(not view.confirmation.visible and view.stage.visible and menu.panel.visible and events==["export"],"Actual No returns to the original menu without leaving the server")
		await click(view.buttons.exitbutton.get_global_rect().get_center()); await press_key(KEY_ESCAPE); check(not view.confirmation.visible and menu.panel.visible and events==["export"],"Escape cancels the exit dialog before dismissing its parent")
		await press_key(KEY_ESCAPE); check(not menu.panel.visible,"A second Escape dismisses the in-game menu")
		menu.open(true); await click(view.buttons.exitbutton.get_global_rect().get_center()); await click(view.confirm_buttons.okbutton.get_global_rect().get_center())
		check(events==["export","disconnect"] and not menu.panel.visible,"Actual Yes emits one disconnect action without exiting the application")
		menu.open(true); await click(view.buttons.gamebutton.get_global_rect().get_center()); check(events==["export","disconnect","options"] and not menu.panel.visible,"Original Game control reaches the current native settings route")
		menu.child_closed(); check(menu.panel.visible and view.visible and events.size()==3,"Closing a child settings page restores its original menu parent in the same connection")
		menu.open(true); await click(view.buttons.resumegamebutton.get_global_rect().get_center()); check(not menu.panel.visible and events.size()==3,"Resume dismisses the menu without a server request")
		menu.open(true); var point: Vector2=view.buttons.savecharbutton.get_global_rect().get_center(); await motion(point); await mouse(point,true)
		menu.set_native_scope([2,1,55,42]); menu.open(true); await mouse(point,false)
		check(events.size()==3,"A held Export press cannot retarget after the connection scope changes")
		await click(view.buttons.exitbutton.get_global_rect().get_center()); point=view.confirm_buttons.okbutton.get_global_rect().get_center(); await motion(point); await mouse(point,true)
		menu.set_native_scope([2,2,77,99]); menu.open(true); view.ask_exit(); await mouse(point,false)
		check(events.size()==3,"A held Yes cannot confirm a replacement world or controlled character")
		view.cancel_confirmation(); var start: Vector2=menu.panel.position; var grip: Vector2=title.get_global_rect().get_center(); await motion(grip); await mouse(grip,true); await motion(grip+Vector2(90,35),Vector2(90,35),true); await mouse(grip+Vector2(90,35),false)
		check(menu.panel.position.distance_to(start+Vector2(90,35))<1,"Dragging the original title moves the native menu without capturing the pointer")
		var remembered: Vector2=menu.panel.position; menu.dismiss(); menu.open(true); check(menu.panel.position==remembered,"Reopening the menu retains its last dragged position")
		var stored:=ConfigFile.new(); check(stored.load(menu.layout_path)==OK and stored.get_value("positions","ingame_options",Vector2.ZERO)==remembered,"Menu placement is persisted with the other native window positions")
		menu.panel.scale=Vector2(1.25,1.25); menu.retained_position=Vector2.INF; menu.place(); await shot(output,"-scaled"); await click(view.buttons.resumegamebutton.get_global_rect().get_center()); check(not menu.panel.visible and events.size()==3,"Original source-menu input remains correct at125percent scale")
		menu.panel.scale=Vector2.ONE; menu.open(true); menu.observe_lobby({"connected":false,"busy":false,"phase":"menu"}); await process_frame; check(view.buttons.savecharbutton.disabled and view.buttons.exitbutton.disabled,"A disconnected context cannot export or end a retired session")
		menu.open(false); check(menu.fallback.visible and not view.visible and not menu.disconnect_button.visible and menu.fallback.get_children().filter(func(node):return node is Button and node.visible).is_empty(),"A missing pregame source owner presents only status instead of resurrecting the prototype menu")
		diagnostic=view.snapshot(); diagnostic.art_failures=ui.inventory.frame_skin.art.failed.keys(); diagnostic.physicalMouseWarped=false
	menu.detach_native(); await process_frame; check(not is_instance_valid(menu.native_frame),"Session retirement releases the menu owner before its borrowed resource services")
	menu.free(); world.free(); ui.close(); ui.free(); await process_frame; await process_frame
	check(entry_owner_hash==FileAccess.get_sha256(ProjectSettings.globalize_path("res://native_session_world.gd")),"Native session owner remains unchanged throughout the menu input check")
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"events":events,"diagnostic":diagnostic,"entryOwnerSha256":entry_owner_hash,"publicConnections":0,"fullEntryMenuParity":false,"scope":"Actual isolated native source-art menu input and ordinary join-client confirmation only. Real server export/disconnect, original-client comparison, pregame and complete child/config/host/role flows remain separate unfinished gates."},"  ")+"\n"); file.close(); quit(0 if failures.is_empty() else 1)
