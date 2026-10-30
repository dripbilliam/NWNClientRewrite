extends "res://tests/native_quickbar_frame_test.gd"
const Browser=preload("res://systems/server_browser.gd")
const Painter=preload("res://systems/native_gui_painter.gd")
const Policy=preload("res://systems/native_data/player_profile.gd")
func press(code: Key) -> void:
	await key(code,true); await key(code,false)
func capture(output: String,suffix: String,painter) -> void:
	if DisplayServer.get_name()=="headless": return
	check(await wait_until(func():return painter.art.waiting.is_empty() and painter.art.models.pending.is_empty() and not painter.art.models.active and painter.fonts.pending.is_empty()),"Profile original artwork/fonts complete before visual capture: "+suffix)
	await RenderingServer.frame_post_draw
	check(surface.get_texture().get_image().save_png(output.trim_suffix(".json")+suffix+".png")==OK,"Native profile viewport saved: "+suffix)
func run() -> void:
	var output:=""; var install:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
		if arg.begins_with("--install="): install=arg.substr(10)
	if output.is_empty() or install.is_empty() or FileAccess.file_exists(output): quit(2); return
	var oracle_path:=ProjectSettings.globalize_path("res://../backups/animations/native-player-profile-observations-v1.json")
	var oracle: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(oracle_path))
	check(oracle.binarySha256=="3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a" and oracle.rows.size()==781,"Original unchanged-instruction name-validation oracle identifies the exact client and corpus")
	for row in oracle.rows:
		check(Policy.confirmed(row.input)=={"name":row.name,"notice":int(row.notice),"accepted":row.accepted},"Original profile callback result: "+str(row.inputBytes))
	root.size=Vector2i(1200,850); surface=SubViewport.new(); surface.size=root.size; surface.render_target_update_mode=SubViewport.UPDATE_ALWAYS; surface.gui_disable_input=false; surface.handle_input_locally=true; root.add_child(surface); surface.notify_mouse_entered()
	var catalog:=Catalog.new(); check(catalog.mount_install(install),"Original profile resources mount read-only")
	var text=preload("res://systems/native_data/talk_text.gd").new(); check(text.base.open_file(install.path_join("lang/en/data/dialog.tlk")),"Original profile captions and notices use installed TLK")
	var painter:=Painter.new(); surface.add_child(painter); painter.configure_source(catalog,ProjectSettings.globalize_path("user://native-prepared-v2"))
	var ui:=Browser.new(); surface.add_child(ui); ui.request.connect(func(message):requests.append(message.duplicate(true))); ui.configure_native(painter,text,catalog,ProjectSettings.globalize_path("user://native-prepared-v2"))
	var dialog=ui.profile_dialog
	check(await wait_until(func():return dialog.layout_ready or not dialog.failure.is_empty()),"Native profile preparation terminates")
	check(dialog.layout_ready and dialog.failure.is_empty(),"Original profile and OK notice layouts prepare: "+dialog.failure)
	if dialog.layout_ready:
		check(dialog.definition.entries.size()==9 and dialog.labels.size()==4 and dialog.buttons.size()==4 and dialog.edits.size()==1,"All original profile controls, including the nested checkbox caption, are represented")
		check(dialog.labels.tguilabel3.text=="Save As Default" and dialog.labels.tguireason.text.is_empty(),"Checkbox uses modern original wording and clears the source's placeholder reason")
		check(dialog.edits.pnameeditbox.max_length==0,"Original profile edits are corrected on confirmation rather than silently blocked at32 characters")
		ui.open(true)
		var view:={"kind":"browser-view","connection":0,"viewId":1,"tab":"Direct","direct":{"host":"127.0.0.1","port":5125,"name":"Previous"},"canJoin":true,"localOnly":true,"hasSavedCdKey":true,"page":0,"pages":1,"rows":[],"busy":false}
		ui.receive(view); await process_frame
		check(dialog.visible and not ui.panel.visible and ui.profile_first and surface.gui_get_focus_owner()==dialog.edits.pnameeditbox,"Multiplayer entry shows native Player Name before browsing and focuses its edit")
		await capture(output,"-profile",painter)
		dialog.edits.pnameeditbox.text=""; await press(KEY_ENTER)
		check(dialog.notice.visible and dialog.notice_ref==66256 and dialog.notice_body.text==text.raw({"strRef":66256}) and requests.back().operation=="open","Empty name displays the original OK notice without updating identity or contacting a server")
		check(dialog.notice_shield.visible and dialog.buttons.values().all(func(button):return not button.disabled) and not dialog.buttons.passwordcheck.button_pressed,"A modal notice blocks underlying input without inventing disabled button artwork or a checked Save As Default state")
		await capture(output,"-notice",painter)
		await press(KEY_ENTER)
		check(not dialog.notice.visible and dialog.visible and surface.gui_get_focus_owner()==dialog.edits.pnameeditbox,"Notice Enter returns focus to the original profile edit")
		dialog.edits.pnameeditbox.text=" .Scary@ Bill"; await press(KEY_ENTER)
		check(dialog.edits.pnameeditbox.text=="Scary Bill" and dialog.notice_ref==66104 and requests.back().operation=="open","Invalid bytes and leading dots/spaces are removed with an original warning and require another confirmation")
		await click(dialog.notice_button.get_global_rect().get_center())
		await click(dialog.buttons.passwordcheck.get_global_rect().get_center())
		check(dialog.buttons.passwordcheck.button_pressed,"Actual original checkbox input selects Save As Default")
		await press(KEY_ENTER)
		check(requests.back().operation=="profile" and requests.back().values=={"name":"Scary Bill","saveDefault":true} and dialog.pending and dialog.buttons.okbutton.disabled,"Second confirmation issues a scoped profile request and waits for the storage owner")
		var pending_escape:=ui.escape()
		check(pending_escape and ui.name_edit.text=="Previous" and dialog.visible,"Pending profile changes do not fabricate a new accepted identity or dismiss on Escape")
		view.viewId=2; view.busy=true; ui.receive(view)
		ui.receive({"kind":"browser-profile-result","connection":0,"requestViewId":0,"accepted":true,"name":"Wrong"})
		check(dialog.pending and ui.name_edit.text=="Previous","A stale profile acknowledgment cannot commit another presentation")
		ui.receive({"kind":"browser-profile-result","connection":0,"requestViewId":1,"accepted":true,"name":"Scary Bill","savedDefault":true})
		check(not dialog.visible and not ui.profile_first and ui.panel.visible and ui.name_edit.text=="Scary Bill","Authoritative profile acknowledgment commits the identity and opens the browser")
		view.viewId=3; view.busy=false; view.direct.name="Scary Bill"; ui.receive(view); await process_frame
		await click(ui.profile_button.get_global_rect().get_center()); dialog.edits.pnameeditbox.text="A".repeat(33); await press(KEY_ENTER)
		check(dialog.notice_ref==66104 and dialog.edits.pnameeditbox.text=="A".repeat(32),"A33-byte name is visibly shortened to32 and warns before acceptance")
		check(ui.escape() and not dialog.notice.visible and dialog.visible,"Escape closes the correction notice before dismissing Player Name")
		dialog.edits.pnameeditbox.text="Other"; await press(KEY_ENTER)
		ui.receive({"kind":"browser-profile-result","connection":0,"requestViewId":3,"accepted":false,"text":"Authored storage refusal"})
		view.viewId=4; ui.receive(view)
		check(dialog.notice.visible and dialog.notice_body.text=="Authored storage refusal" and ui.name_edit.text=="Scary Bill" and not dialog.pending,"Storage refusal uses the source notice and preserves the previously accepted identity")
		await press(KEY_ENTER); await press(KEY_ENTER)
		check(requests.back().operation=="profile" and requests.back().viewId==4 and dialog.pending,"Retry after a refusal uses the new authoritative browser view")
		ui.reset(1); ui.receive({"kind":"browser-profile-result","connection":0,"requestViewId":4,"accepted":true,"name":"Retired"})
		check(not dialog.visible and not ui.wanted and not dialog.pending,"Reset retires pending profile state and rejects its late acknowledgment")
	var diagnostic: Dictionary=dialog.snapshot(); var window_state: Dictionary={"focused":root.has_focus(),"unfocusable":root.unfocusable,"screen":root.current_screen,"primary":DisplayServer.get_primary_screen(),"mouse_mode":Input.mouse_mode}; ui.close_native()
	check(dialog.closed and dialog.assets.running.is_empty() and ui.direct_dialog.closed and ui.direct_dialog.assets.running.is_empty(),"Both private connection dialogs join workers before shared painter shutdown")
	ui.free(); painter.close(); painter.free(); text.close(); await process_frame; await process_frame
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"originalCases":oracle.rows.size(),"oracleSha256":FileAccess.get_sha256(oracle_path),"profile":diagnostic,"window":window_state,"publicConnections":0,"physicalMouseWarped":false,"visualAccepted":false,"authoritativeServerAccepted":false,"fullUiParity":false,"scope":"Original executed profile-validation corpus and native source controls/input/request/refusal/lifecycle only. Persistent backend behavior has independent service tests. Visual original-client comparison and a real owned local-server admission through this flow remain required."},"  ")+"\n"); file.close(); quit(0 if failures.is_empty() else 1)
