extends "res://tests/native_quickbar_frame_test.gd"
const Lobby=preload("res://systems/character_lobby.gd")
const Loading=preload("res://systems/native_loading_screen.gd")
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
	var world_wheel=ui.desktop.radial
	await exercise_radial_phase(ui,world_wheel,"World",Vector2(410,410),func():world_wheel.open_at(Vector2(410,410),42,Vector3.ZERO,false))
	var item_wheel=ui.inventory.item_context.wheel
	await exercise_radial_phase(ui,item_wheel,"Inventory",Vector2(700,410),func():item_wheel.open_at(Vector2(700,410),43,Vector3.ZERO,false))
	var chat_wheel=ui.chat_skin.context
	await exercise_radial_phase(ui,chat_wheel,"Chat",Vector2(200,410),func():ui.chat_skin.open_context(0,Vector2(200,410)))
	check(ui.chat.entry.text=="Retained draft" and ui.inventory.ui.position==retained,"Presentation gating preserves the draft and retained window placement")
	check(ui.desktop.quickbar.can_process() and ui.inventory.item_context.wheel.can_process() and ui.mouse_cursor.is_processing_input(),"Revealing gameplay restores input processing")
	var state:=ui.startup_snapshot(); check(state.gameplay_visible and state.gameplay_canvas_visible and state.chat_visible_in_tree,"Diagnostics report effective gameplay presentation")
	ui.set_gameplay_visible(false); state=ui.startup_snapshot(); check(not state.gameplay_visible and not state.gameplay_canvas_visible and not state.chat_visible_in_tree,"Diagnostics distinguish hidden gameplay from prepared resources")
	var loading:=Loading.new(); surface.add_child(loading)
	var actor:={"id":42,"objectType":5,"areaId":55,"replicated":{"name":{"text":"Controlled"},"position":[0,0,0],"hitPoints":{"current":10,"maximum":15},"stats":{"classes":[]}}}
	var header:={"area":{"id":55},"module":{"areas":[{"id":55,"name":"First room"},{"id":56,"name":"Second room"}]}}
	ui.set_world(1,55,42,[actor],{},header)
	ui.set_gameplay_visible(true)
	var spell_binding:={"type":2,"intParam":0,"spellId":-1}
	ui.desktop.begin_target(spell_binding)
	check(not ui.desktop.target.is_empty() and ui.mouse_cursor.hovered_selection(ui.chat.entry,false).id==31,"Ordinary GUI hover preserves the armed spell cursor")
	var requests_before_target_hide:=requests.size()
	ui.set_gameplay_visible(false); loading.begin(2,"Second room"); await process_frame
	check(ui.desktop.target.is_empty() and not ui.desktop.target_prompt.visible and ui.mouse_cursor.hovered_selection(loading.back,false).id==1,
		"Gameplay retirement clears the old targeting prompt and cursor before the next area is received")
	check(requests.size()==requests_before_target_hide,"Retiring the old spell target emits no gameplay command")
	actor.areaId=56; header.area.id=56
	ui.set_world(2,56,42,[actor],{},header)
	loading.reset(); ui.set_gameplay_visible(true); await process_frame
	ui.desktop.begin_target(spell_binding)
	check(ui.desktop.area_id==56 and not ui.desktop.target.is_empty() and ui.desktop.target_prompt.visible
		and ui.mouse_cursor.hovered_selection(ui.chat.entry,false).id==31,"The next admitted area can arm a new spell target")
	ui.desktop.cancel_target()
	header.ui={"scriptTargeting":{"version":9,"objectMask":4,"cursor":29,"badCursor":31}}
	ui.update_world(2,56,42,[],[],{},header)
	check(await wait_until(func():return ui.desktop.target.get("type",0)==45),"The accepted server state owns scripted targeting")
	check(ui.mouse_cursor.hovered_selection(ui.chat.entry,false).id==31,"An admitted server target keeps its configured cursor")
	requests_before_target_hide=requests.size()
	ui.set_gameplay_visible(false); loading.begin(3,"Third room"); await process_frame
	var hover_cursor: int=ui.mouse_cursor.hovered_selection(loading.back,false).id
	ui.mouse_cursor.world_pointer({},true)
	var blocked_cursor: int=ui.mouse_cursor.desired.id
	ui.mouse_cursor.world_pointer({"id":42},false)
	check(hover_cursor==1 and blocked_cursor==1 and ui.mouse_cursor.desired.id==1 and not ui.desktop.target_prompt.is_visible_in_tree(),
		"Hidden server targeting cannot replace the ordinary loading cursor on GUI or world pointer paths")
	check(ui.desktop.target.get("version",0)==9 and requests.size()==requests_before_target_hide,
		"Hiding server targeting preserves the received mode and sends no command")
	loading.free()
	var window_state:={"focused":root.has_focus(),"unfocusable":root.unfocusable,"screen":root.current_screen,"primary":DisplayServer.get_primary_screen(),"mouse_mode":Input.mouse_mode}
	lobby.close_native(); lobby.free(); ui.close(); ui.free(); await process_frame; await process_frame
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"window":window_state,"publicConnections":0,"fullUiParity":false,"scope":"Native pregame/gameplay canvas separation, shared source preparation, actual viewport keyboard/pointer events, focus retirement, independent creator/radial ownership and retained placement/draft. Authoritative admission and original-client comparison are separate."},"  ")+"\n"); file.close(); quit(0 if failures.is_empty() else 1)

func exercise_radial_phase(ui,wheel,label: String,point: Vector2,open_menu: Callable) -> void:
	open_menu.call()
	# The normal error receipt exposes the actual radial canvas without GPU
	# artwork. A wheel awaiting its first reply intentionally stays hidden.
	wheel.receive({"kind":"action-error","requestId":wheel.request_id,"text":"Fixture action unavailable"})
	check(wheel.active and wheel.stage.is_visible_in_tree() and wheel.can_process() and ui.blocks_pointer(point),
		label+" radial is presented as a live input owner before the transition")
	ui.chat.entry.grab_focus(); await process_frame
	check(surface.gui_get_focus_owner()==ui.chat.entry,label+" transition begins with a genuinely focused chat entry")
	var wheel_requests: Array=[]
	var track_request:=func(message):wheel_requests.append(message)
	wheel.request.connect(track_request)
	ui.set_gameplay_visible(false); await process_frame
	check(not wheel.stage.is_visible_in_tree() and not wheel.can_process() and not ui.blocks_pointer(point),
		label+" radial canvas, input and pointer region are hidden by the phase gate")
	check(not ui.chat.is_visible_in_tree() and surface.gui_get_focus_owner()!=ui.chat.entry and not ui.desktop.quickbar.can_process(),
		label+" transition hides quickbar and chat and releases the chat entry")
	if wheel==ui.chat_skin.context:check(not wheel.active and not wheel.visible,"The transition immediately retires the live chat context")
	var before:=requests.size()
	await click(point); await key(KEY_ESCAPE); await key(KEY_ESCAPE,false); await key(KEY_ENTER); await key(KEY_ENTER,false)
	check(wheel_requests.is_empty() and requests.size()==before and surface.gui_get_focus_owner()!=ui.chat.entry,
		label+" hidden radial and chat cannot consume pointer or keyboard input as gameplay commands")
	wheel.request.disconnect(track_request)
	if wheel.active:wheel.reset()
	ui.set_gameplay_visible(true); await process_frame
