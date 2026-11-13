extends "res://tests/native_quickbar_frame_test.gd"
const Lobby=preload("res://systems/character_lobby.gd")
func run() -> void:
	var output:=""; var install:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
		if arg.begins_with("--install="): install=arg.substr(10)
	if output.is_empty() or install.is_empty() or FileAccess.file_exists(output): quit(2); return
	root.size=Vector2i(1200,850); surface=SubViewport.new(); surface.size=root.size; surface.render_target_update_mode=SubViewport.UPDATE_ALWAYS; surface.gui_disable_input=false; surface.handle_input_locally=true; root.add_child(surface); surface.notify_mouse_entered()
	var catalog:=Catalog.new(); check(catalog.mount_install(install),"Original UI catalog mounts read-only")
	var ui:=Gameplay.new(); surface.add_child(ui); ui.configure(catalog,install,ProjectSettings.globalize_path("user://native-prepared-v2"),output+".layout.cfg"); ui.request.connect(func(message):requests.append(message.duplicate(true)))
	ui.set_gameplay_visible(false)
	var lobby:=Lobby.new(); surface.add_child(lobby); lobby.configure_native(ui.inventory.frame_skin,ui.text,catalog,ui.assets.cache_directory)
	lobby.apply_state({"connection":1,"state":{"phase":"character-selection","connected":true,"canSelect":true,"canCreate":true,"selected":null,"choices":[{"key":"server:test","label":"Phase fixture","source":"server","serverSource":17}]}})
	check(await wait_until(func():return ui.tables_ready and lobby.native_chooser.layout_ready and lobby.native_chooser.frame.fonts.pending.is_empty()),"Shared original tables, chooser artwork and fonts prepare while gameplay is hidden")
	check(lobby.native_chooser.is_visible_in_tree() and not ui.chat.is_visible_in_tree() and not ui.layer.visible,"Independent original chooser draws without the gameplay chat canvas")
	check(not ui.blocks_pointer(ui.chat.get_global_rect().get_center()),"Hidden gameplay UI contributes no pointer-blocking region")
	for code in [KEY_I,KEY_C,KEY_ENTER]: await key(code); await key(code,false)
	check(not ui.inventory.ui.wanted and not ui.desktop.sheet.wanted and surface.gui_get_focus_owner()!=ui.chat.entry,"Actual pregame key events cannot open hidden inventory/sheet or focus chat")
	check(requests.is_empty(),"Hidden gameplay shortcuts issue no gameplay request")
	if DisplayServer.get_name()!="headless":
		check(await wait_until(func():return ui.inventory.frame_skin.art.waiting.is_empty() and ui.inventory.frame_skin.art.models.pending.is_empty() and not ui.inventory.frame_skin.art.models.active),"Borrowed chooser artwork completes without enabling the game canvas")
		await RenderingServer.frame_post_draw; check(surface.get_texture().get_image().save_png(output.trim_suffix(".json")+"-chooser.png")==OK,"Hidden-gameplay chooser viewport saved for review")
	lobby.panel.hide(); ui.creator.open(1); await process_frame
	check(ui.creator.phase!="closed" and ui.creator.view.panel.is_visible_in_tree() and not ui.chat.is_visible_in_tree(),"Independent character creator stays visible while gameplay is hidden")
	check(requests.any(func(message):return message.kind=="native-creation-begin"),"Visible creator retains its scoped native creation request")
	ui.creator.cancel(); await process_frame
	check(ui.creator.phase=="closed" and not ui.creator.view.panel.is_visible_in_tree(),"Creator cancellation retires its independent canvas")
	ui.set_gameplay_visible(true); await process_frame
	check(await wait_until(func():return ui.chat_skin.layout_ready),"Original chat resources also prepare through the actual gameplay owner")
	check(ui.chat.is_visible_in_tree() and ui.is_processing_unhandled_key_input() and ui.desktop.is_processing_unhandled_key_input(),"World presentation restores chat and gameplay shortcut owners")
	ui.chat.entry.text="Retained draft"; ui.chat.entry.grab_focus(); await process_frame
	check(surface.gui_get_focus_owner()==ui.chat.entry,"Visible gameplay chat receives normal native focus")
	ui.inventory.ui.position=Vector2(117,91); var retained: Vector2=ui.inventory.ui.position
	ui.desktop.radial.open_at(Vector2(410,410),42,Vector3.ZERO,false)
	ui.inventory.item_context.wheel.open_at(Vector2(700,410),43,Vector3.ZERO,false)
	ui.chat_skin.open_context(0,Vector2(200,410)); check(ui.chat_skin.context.active,"Native chat context opens in admitted gameplay")
	check(ui.desktop.radial.stage.is_visible_in_tree() and ui.inventory.item_context.wheel.stage.is_visible_in_tree(),"Both independent radial canvases are presented before the transition gate")
	ui.set_gameplay_visible(false); await process_frame
	check(surface.gui_get_focus_owner()!=ui.chat.entry and not ui.chat.is_visible_in_tree(),"Hiding gameplay releases its focused entry")
	check(not ui.desktop.radial.stage.is_visible_in_tree() and not ui.inventory.item_context.wheel.stage.is_visible_in_tree(),"Transition gate also hides both independent radial canvases")
	check(not ui.chat_skin.context.active and not ui.chat_skin.context.visible and not ui.chat_skin.context.can_process(),"Transition gate immediately retires chat's independent radial canvas and input")
	check(not ui.desktop.radial.can_process() and not ui.inventory.item_context.wheel.can_process() and not ui.desktop.quickbar.can_process(),"Hidden radial and quickbar input trees stop processing")
	var before:=requests.size(); await click(Vector2(10,10)); await key(KEY_ENTER); await key(KEY_ENTER,false)
	check(requests.size()==before and surface.gui_get_focus_owner()!=ui.chat.entry,"Hidden active wheels and chat cannot consume clicks/Enter or dispatch requests")
	ui.desktop.radial.reset(); ui.inventory.item_context.wheel.reset(); ui.set_gameplay_visible(true); await process_frame
	check(ui.chat.entry.text=="Retained draft" and ui.inventory.ui.position==retained,"Presentation gating preserves the draft and retained window placement")
	check(ui.desktop.quickbar.can_process() and ui.inventory.item_context.wheel.can_process() and ui.mouse_cursor.is_processing_input(),"Revealing gameplay restores input processing")
	var state:=ui.startup_snapshot(); check(state.gameplay_visible and state.gameplay_canvas_visible and state.chat_visible_in_tree,"Diagnostics report effective gameplay presentation")
	ui.set_gameplay_visible(false); state=ui.startup_snapshot(); check(not state.gameplay_visible and not state.gameplay_canvas_visible and not state.chat_visible_in_tree,"Diagnostics distinguish hidden gameplay from prepared resources")
	var window_state:={"focused":root.has_focus(),"unfocusable":root.unfocusable,"screen":root.current_screen,"primary":DisplayServer.get_primary_screen(),"mouse_mode":Input.mouse_mode}
	lobby.close_native(); lobby.free(); ui.close(); ui.free(); await process_frame; await process_frame
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"window":window_state,"publicConnections":0,"fullUiParity":false,"scope":"Native pregame/gameplay canvas separation, shared source preparation, actual viewport keyboard/pointer events, focus retirement, independent creator/radial ownership and retained placement/draft. Authoritative admission and original-client comparison are separate."},"  ")+"\n"); file.close(); quit(0 if failures.is_empty() else 1)
