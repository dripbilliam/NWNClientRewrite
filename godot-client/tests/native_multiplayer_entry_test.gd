extends "res://tests/native_quickbar_frame_test.gd"
const Browser=preload("res://systems/server_browser.gd")
const Painter=preload("res://systems/native_gui_painter.gd")
const Plan=preload("res://systems/native_data/entry_menu_layout.gd")
func wait_cohorts(predicate: Callable) -> bool:
	var end:=Time.get_ticks_msec()+15000
	while not predicate.call() and Time.get_ticks_msec()<end: await process_frame
	return predicate.call()
func press(code: Key) -> void:
	await key(code,true); await key(code,false)
func capture(output: String,suffix: String,painter) -> void:
	if DisplayServer.get_name()=="headless": return
	check(await wait_until(func():return painter.art.waiting.is_empty() and painter.art.models.pending.is_empty() and not painter.art.models.active and painter.fonts.pending.is_empty()),"Original Multiplayer artwork/fonts settle: "+suffix)
	await RenderingServer.frame_post_draw
	check(surface.get_texture().get_image().save_png(output.trim_suffix(".json")+suffix+".png")==OK,"Native Multiplayer viewport saved: "+suffix)
func run() -> void:
	var output:=""; var install:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
		if arg.begins_with("--install="): install=arg.substr(10)
	if output.is_empty() or install.is_empty() or FileAccess.file_exists(output): quit(2); return
	root.size=Vector2i(1200,850); surface=SubViewport.new(); surface.size=root.size; surface.render_target_update_mode=SubViewport.UPDATE_ALWAYS; surface.gui_disable_input=false; surface.handle_input_locally=true; root.add_child(surface); surface.notify_mouse_entered()
	var catalog:=Catalog.new(); check(catalog.mount_install(install),"Original multiplayer resources mount read-only")
	var text=preload("res://systems/native_data/talk_text.gd").new(); check(text.base.open_file(install.path_join("lang/en/data/dialog.tlk")),"Original multiplayer captions resolve from installed text")
	var painter:=Painter.new(); surface.add_child(painter); painter.configure_source(catalog,ProjectSettings.globalize_path("user://native-prepared-v2"))
	var ui:=Browser.new(); surface.add_child(ui); ui.request.connect(func(message):requests.append(message.duplicate(true))); ui.configure_native(painter,text,catalog,ProjectSettings.globalize_path("user://native-prepared-v2"))
	var menu=ui.entry_menu
	check(await wait_cohorts(func():return menu.art_ready() and ui.profile_dialog.art_ready() and ui.direct_dialog.art_ready() and ui.native_browser.art_ready() or not menu.cohort_snapshot().failures.is_empty() or not ui.profile_dialog.cohort_snapshot().failures.is_empty()),"Used multiplayer, profile, Direct and browser cohorts prepare before activation")
	check(menu.art_ready() and ui.profile_dialog.art_ready() and ui.direct_dialog.art_ready() and ui.native_browser.art_ready(),"Required original controls and artwork are available: "+str(menu.cohort_snapshot().failures))
	if menu.art_ready() and ui.profile_dialog.art_ready() and ui.direct_dialog.art_ready() and ui.native_browser.art_ready():
		check(menu.buttons.size()==6 and menu.definition.entries.size()==6 and menu.kind=="pre_multiplayer","The complete original six-button Multiplayer resource replaces a generic navigation row")
		check(menu.definition.entries.dirconnectbutton.callback=="0x140710480" and menu.definition.entries.cancelbutton.callback=="0x14070f740" and menu.definition.entries.intjoinbutton.callback=="0x1407107e0","Source controls retain the inspected original action associations")
		ui.open(true,true)
		var view:={"kind":"browser-view","connection":0,"viewId":1,"tab":"Direct","direct":{"host":"127.0.0.1","port":5125,"name":""},"hasSessionProfile":false,"canJoin":true,"canDiscover":false,"localOnly":true,"hasSavedCdKey":true,"page":0,"pages":1,"rows":[],"busy":false}
		ui.receive(view); await process_frame
		check(ui.profile_dialog.visible and not menu.visible and not ui.panel.visible,"An unaccepted current identity opens Player Name before the multiplayer menu")
		ui.profile_dialog.edits.pnameeditbox.text="Nibs"; await press(KEY_ENTER)
		check(requests.back().operation=="profile" and ui.profile_dialog.pending,"Entering Multiplayer waits for real profile acknowledgment")
		check(not ui.profile_dialog.buttons.passwordcheck.button_pressed and not ui.profile_dialog.buttons.passwordcheck.disabled and ui.profile_dialog.notice_shield.visible,"Pending profile storage blocks input without drawing the unchecked checkbox's misleading disabled X")
		view.viewId=2; view.busy=true; ui.receive(view)
		ui.receive({"kind":"browser-profile-result","connection":0,"requestViewId":1,"accepted":true,"name":"Nibs","savedDefault":false})
		view.viewId=3; view.busy=false; view.hasSessionProfile=true; view.direct.name="Nibs"; ui.receive(view); await process_frame
		check(menu.visible and not ui.panel.visible and not ui.profile_dialog.visible and ui.entry_stage=="entry","Accepted profile returns to original Multiplayer rather than jumping past it into the browser")
		check(menu.buttons.newbutton.disabled and menu.buttons.loadbutton.disabled and menu.buttons.lanjoinbutton.disabled and not menu.buttons.intjoinbutton.disabled and not menu.buttons.dirconnectbutton.disabled,"Unsupported hosting/LAN actions are explicit gaps while real browser/direct/cancel routes remain available")
		await capture(output,"-menu",painter)
		var count:=requests.size(); await click(menu.buttons.dirconnectbutton.get_global_rect().get_center())
		check(ui.direct_dialog.visible and menu.visible and ui.modal_shield.visible and requests.size()==count,"Direct Connect opens modally over Multiplayer without sending a query or login")
		check(ui.blocks_pointer(Vector2(1,1)),"The pregame modal shield blocks clicks through to underlying controls")
		await click(Vector2(1,1)); check(ui.direct_dialog.visible and ui.wanted,"An outside modal click cannot dismiss the owner or act on underlying menus")
		await capture(output,"-direct",painter)
		await click(ui.direct_dialog.buttons.cancelbutton.get_global_rect().get_center())
		check(menu.visible and not ui.direct_dialog.visible and not ui.panel.visible and not ui.modal_shield.visible and requests.size()==count,"Original Direct Cancel restores the Multiplayer owner without contacting a server")
		await click(menu.buttons.intjoinbutton.get_global_rect().get_center())
		check(requests.back().operation=="tab" and requests.back().tab=="Internet" and requests.back().sourcePage and not menu.visible,"Join Internet requests the original browser page without automatically querying public services")
		view.viewId=4; view.tab="Internet"; view.busy=true; ui.receive(view); await process_frame
		check(ui.escape() and menu.visible and ui.wanted and ui.entry_stage=="entry" and not ui.panel.visible and requests.back().operation=="return-menu" and menu.buttons.dirconnectbutton.disabled,"Browser Back/Escape requests provider cancellation and waits in its Multiplayer owner")
		view.viewId=5; view.tab="Direct"; view.busy=false; ui.receive(view); await process_frame
		check(not menu.buttons.dirconnectbutton.disabled,"Cancellation acknowledgment restores usable Multiplayer actions")
		await click(menu.buttons.dirconnectbutton.get_global_rect().get_center()); ui.direct_dialog.edits.passwordeditbox.text="discard after send"
		await click(ui.direct_dialog.buttons.okbutton.get_global_rect().get_center())
		check(requests.back().operation=="join" and requests.back().direct and requests.back().values.host=="127.0.0.1" and requests.back().values.port==5125 and requests.back().values.name=="Nibs","The new menu reaches the existing canonical native direct-login request")
		view.viewId=6; view.status="Authoritative login refusal"; view.reopen=true; ui.receive(view); await process_frame
		check(ui.profile_dialog.visible and ui.profile_dialog.external_notice and ui.profile_dialog.notice_body.text==view.status and menu.visible,"A real login refusal remains visible through original OK artwork over the Multiplayer owner")
		await press(KEY_ENTER)
		check(menu.visible and not ui.profile_dialog.visible and ui.entry_stage=="entry" and ui.wanted,"Acknowledging a refused login returns to a usable Multiplayer menu")
		await click(menu.buttons.cancelbutton.get_global_rect().get_center())
		check(not ui.wanted and not menu.visible and ui.return_to_main and requests.back().operation=="close" and requests.back().leaveMultiplayer,"Multiplayer Cancel retires its browser ownership and requests the original identity-reset policy")
		ui.open(true,true); view.viewId=7; view.reopen=false; view.status=""; view.tab="Direct"; ui.receive(view); await process_frame
		check(menu.visible and not ui.profile_dialog.visible and not ui.profile_first,"An already accepted application identity skips the redundant Player Name prompt")
		var point: Vector2=menu.buttons.intjoinbutton.get_global_rect().get_center(); await motion(point); await mouse(point,true); ui.close(); ui.open(true,true); view.viewId=8; ui.receive(view); await mouse(point,false)
		check(menu.visible and ui.entry_stage=="entry" and requests.back().operation=="open","A retired held menu press cannot select a page after reopening")
		await click(menu.buttons.dirconnectbutton.get_global_rect().get_center()); view.viewId=9; ui.receive(view)
		check(menu.visible and not ui.direct_dialog.visible and ui.entry_stage=="entry","A superseded direct dialog returns to a usable parent rather than leaving its controls stranded")
		view.viewId=10; view.busy=true; ui.receive(view)
		check(menu.buttons.intjoinbutton.disabled and menu.buttons.dirconnectbutton.disabled,"Pending backend work disables conflicting source menu actions")
		view.viewId=11; view.busy=false; ui.receive(view); ui.open_direct(); ui.direct_dialog.edits.ipeditbox.text="127.0.0.1:65536"; var before_invalid:=requests.size(); ui.direct_dialog.invoke("okbutton")
		check(requests.size()==before_invalid and ui.profile_dialog.external_notice and ui.profile_dialog.notice_body.text.contains("UDP port") and not ui.state.get("busy",false),"An unencodable port receives a visible source notice without sending an invalid protocol request or stranding controls")
		await press(KEY_ENTER)
		ui.reset(1); check(not ui.wanted and not menu.visible and not ui.modal_shield.visible,"Session replacement retires all Multiplayer presentations together")
		ui.open(); view.connection=1; view.viewId=12; view.direct.name=""; view.hasSessionProfile=false; view.tab="Direct"; ui.receive(view); await process_frame
		await click(ui.connect_button.get_global_rect().get_center())
		check(ui.profile_dialog.visible and not ui.direct_dialog.visible,"Direct Connect with no accepted name first opens the native profile instead of submitting an invalid login")
		ui.profile_dialog.edits.pnameeditbox.text="Fresh Name"; await press(KEY_ENTER)
		ui.receive({"kind":"browser-profile-result","connection":1,"requestViewId":12,"accepted":true,"name":"Fresh Name","savedDefault":false})
		view.viewId=13; view.hasSessionProfile=true; view.direct.name="Fresh Name"; ui.receive(view)
		check(ui.direct_dialog.visible and not ui.profile_dialog.visible and requests.back().operation=="profile","Successful name acknowledgment resumes the intended Direct Connect dialog without automatically joining")
	var window_state: Dictionary={"focused":root.has_focus(),"unfocusable":root.unfocusable,"screen":root.current_screen,"primary":DisplayServer.get_primary_screen(),"mouse_mode":Input.mouse_mode}
	ui.close_native(); check(menu.closed and menu.assets.running.is_empty() and ui.profile_dialog.closed and ui.direct_dialog.closed,"All private multiplayer/dialog workers join before the shared painter retires")
	ui.free(); painter.close(); painter.free(); text.close(); await process_frame; await process_frame
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"window":window_state,"publicConnections":0,"fullUiParity":false,"fullMultiplayerMenuParity":false,"unportedActions":["New/Load hosting","LAN discovery"],"scope":"Original Multiplayer source presentation, native pointer/key modal navigation, authoritative profile/refusal messages and canonical direct-request routing. Real server admission is checked separately; hosting/LAN, original browser pages, role/scale/sound and original-client comparison remain unfinished."},"  ")+"\n"); file.close(); quit(0 if failures.is_empty() else 1)
