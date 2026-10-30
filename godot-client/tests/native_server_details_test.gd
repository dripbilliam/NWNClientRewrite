extends "res://tests/native_quickbar_frame_test.gd"
const Browser=preload("res://systems/server_browser.gd")
const Painter=preload("res://systems/native_gui_painter.gd")
func capture(output: String,painter) -> void:
	if DisplayServer.get_name()=="headless": return
	check(await wait_until(func():return painter.art.waiting.is_empty() and painter.art.models.pending.is_empty() and not painter.art.models.active and painter.fonts.pending.is_empty()),"Original Details art/fonts settle")
	await RenderingServer.frame_post_draw; check(surface.get_texture().get_image().save_png(output.trim_suffix(".json")+".png")==OK,"Source Details viewport saved for review")
func run() -> void:
	var output:=""; var install:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
		if arg.begins_with("--install="): install=arg.substr(10)
	if output.is_empty() or install.is_empty() or FileAccess.file_exists(output): quit(2); return
	root.size=Vector2i(1200,850); surface=SubViewport.new(); surface.size=root.size; surface.render_target_update_mode=SubViewport.UPDATE_ALWAYS; surface.gui_disable_input=false; surface.handle_input_locally=true; root.add_child(surface); surface.notify_mouse_entered()
	var catalog:=Catalog.new(); check(catalog.mount_install(install),"Original Details/password resources mount read-only")
	var text=preload("res://systems/native_data/talk_text.gd").new(); check(text.base.open_file(install.path_join("lang/en/data/dialog.tlk")),"Details labels and pending state resolve from installed TLK")
	var painter:=Painter.new(); surface.add_child(painter); painter.configure_source(catalog,ProjectSettings.globalize_path("user://native-prepared-v2"))
	var ui:=Browser.new(); surface.add_child(ui); ui.request.connect(func(message):requests.append(message.duplicate(true))); ui.configure_native(painter,text,catalog,ProjectSettings.globalize_path("user://native-prepared-v2"))
	var dialog=ui.details_dialog; var password=ui.password_dialog
	check(await wait_until(func():return dialog.layout_ready and password.layout_ready and ui.native_browser.layout_ready or not dialog.failure.is_empty() or not password.failure.is_empty()),"Original Details and password owners prepare")
	check(dialog.layout_ready and password.layout_ready and dialog.failure.is_empty() and password.failure.is_empty(),"Required source control geometry is available: "+dialog.failure+password.failure)
	if dialog.layout_ready and password.layout_ready:
		check(dialog.definition.entries.size()==22 and dialog.definition.labels.size()==18 and dialog.checks.size()==6 and dialog.fields.size()==11 and dialog.buttons.size()==4,"All40 Details children survive, including the duplicate LegalCharCheck label identity")
		check(dialog.definition.entries.nextbutton.callback=="0x1408d0a50" and dialog.definition.entries.prevbutton.callback=="0x1408d15f0" and dialog.definition.entries.connectbutton.callback=="0x1408ce150","Original navigation and Connect actions remain paired with source controls")
		ui.open(false,true); ui.entry_stage="browser"
		var first:={"entryId":0,"host":"127.0.0.1","port":5125,"serverName":"Owned one","moduleName":"Prelude","playerCount":1,"maximumPlayers":6,"minimumLevel":1,"maximumLevel":40,"passwordRequired":false,"selected":true,"allowed":true}
		var second:={"entryId":1,"host":"127.0.0.1","port":5126,"serverName":"Owned two","moduleName":"Chapter 1","passwordRequired":true,"selected":false,"allowed":true}
		var view:={"kind":"browser-view","connection":0,"viewId":1,"tab":"Internet","sourcePage":true,"direct":{"host":"127.0.0.1","port":5125,"name":"Nibs"},"hasSessionProfile":true,"canJoin":true,"canDiscover":false,"localOnly":true,"hasSavedCdKey":true,"page":0,"pages":1,"rows":[first,second],"busy":false,"detailsPosition":{"index":0,"total":2,"canPrevious":false,"canNext":true}}
		ui.receive(JSON.parse_string(JSON.stringify(view))); ui.open_details(); await process_frame
		check(dialog.visible and ui.native_browser.visible and ui.modal_shield.visible and ui.state.busy and requests.back().operation=="inspect","Details opens immediately over the source list and starts its actual query")
		check(dialog.fields.servernameedit.text=="Owned one" and dialog.fields.ipedit.text=="127.0.0.1:5125" and dialog.fields.numplayersedit.text=="1" and dialog.fields.maxplayersedit.text=="6" and dialog.pending,"Known fields remain available while extended information is pending")
		await click(dialog.buttons.closebutton.get_global_rect().get_center())
		check(not dialog.visible and not ui.details_wanted and requests.back().operation=="cancel-inspect","Close can cancel the pending lookup without retiring the browser")
		view.viewId=2; ui.receive(JSON.parse_string(JSON.stringify(view))); ui.open_details(); view.viewId=3; view.details=first.duplicate(); view.details.merge({"description":"<c\u0001ÿ\u0001>Long owned description</c>\n"+"Full description remains scrollable.\n".repeat(80),"serverVersion":"8193.37","gameType":0,"extendedReceived":true,"pauseAndPlay":true,"onePartyOnly":false,"itemLevelRestrictions":true,"enforceLegalCharacters":false,"allowLocalVaultCharacters":true,"syncAvailable":false}); ui.receive(JSON.parse_string(JSON.stringify(view))); await process_frame
		check(dialog.visible and not dialog.pending and not ui.profile_dialog.visible,"Received information updates Details instead of spawning an interim OK notice")
		check(dialog.fields.serverversionedit.text=="8193.37" and dialog.fields.gametypeedit.text==text.raw({"strRef":10713}) and dialog.fields.syncedit.text=="Need","Extended version/type and explicit sync state populate their source fields")
		check(dialog.checks.pausecheckbox.disabled and dialog.checks.pausecheckbox.button_pressed and not dialog.checks.onepartycheckbox.button_pressed and dialog.checks.itemcheckbox.button_pressed,"All rule indicators are read-only and retain the received checked/unchecked values")
		check(dialog.fields.values().all(func(field):return not field.editable),"Every source information field is read-only")
		check(dialog.body.get_parsed_text().contains("Long owned description") and not dialog.body.get_parsed_text().contains("</c>"),"Native description formatting parses original color bytes without interpreting server BBCode")
		check(await wait_until(func():return painter.fonts.pending.is_empty()),"Caption metrics finish loading before text-fit verification")
		var overflowing:=0; var all_fit:=true; var anchors_match:=true; var bounded_title:=false
		for entry in dialog.definition.labels:
			var label: Label=dialog.labels[entry.path]
			if entry.floating:
				var extent:=label.get_combined_minimum_size()
				if extent.x>entry.rect.size.x: overflowing+=1
				all_fit=all_fit and not label.clip_text and label.size.x>=extent.x and label.size.y>=extent.y
				var align:=Vector2(float(entry.caption.get("AurString_AlignH",0)),float(entry.caption.get("AurString_AlignV",0)))
				anchors_match=anchors_match and (label.position+extent*align).distance_to(entry.anchor)<0.01
			else: bounded_title=entry.tag=="title" and label.clip_text and label.size.is_equal_approx(entry.rect.size)
		check(overflowing>=4 and all_fit and anchors_match,"Long original rule captions render in full at their text anchors after asynchronous font publication")
		check(bounded_title,"Only the explicitly bounded original Details title retains its source clipping rectangle")
		await capture(output,painter)
		if DisplayServer.get_name()!="headless":
			check(painter.button_geometry[dialog.checks.pausecheckbox.get_instance_id()].drawn.state=="normal_checked" and painter.button_geometry[dialog.checks.onepartycheckbox.get_instance_id()].drawn.state=="normal","Disabled indicators paint SetChecked's original final pose instead of a misleading universal disabled X")
		var before: int=dialog.scroll.scroll_vertical; await mouse(dialog.scroll.get_global_rect().get_center(),true,MOUSE_BUTTON_WHEEL_DOWN); await mouse(dialog.scroll.get_global_rect().get_center(),false,MOUSE_BUTTON_WHEEL_DOWN)
		check(dialog.scroll.scroll_vertical>before,"Long descriptions remain readable through the original attached scrollbar")
		check(dialog.buttons.prevbutton.disabled and not dialog.buttons.nextbutton.disabled,"Navigation availability comes from the authoritative full-list position")
		await click(dialog.buttons.nextbutton.get_global_rect().get_center()); check(requests.back().operation=="details-step" and requests.back().direction==1 and ui.state.busy,"Next requests authoritative adjacent-server selection")
		view.viewId=4; first.selected=false; second.selected=true; view.details=second.duplicate(); view.details.merge({"description":"Second description","extendedReceived":true}); view.detailsPosition={"index":1,"total":2,"canPrevious":true,"canNext":false}; ui.receive(JSON.parse_string(JSON.stringify(view)))
		check(dialog.fields.servernameedit.text=="Owned two" and not dialog.buttons.prevbutton.disabled and dialog.buttons.nextbutton.disabled and dialog.scroll.scroll_vertical==0,"A different selected endpoint replaces the fields, bounds navigation and resets its description scroll")
		var count:=requests.size(); await click(dialog.buttons.connectbutton.get_global_rect().get_center())
		check(password.visible and dialog.visible and ui.details_shield.visible and requests.size()==count,"Password-protected Connect opens its original child modal without attempting a passwordless login")
		check(password.edits.passwordeditbox.secret and password.edits.passwordeditbox.secret_character=="*" and password.edits.passwordeditbox.has_focus(),"Original password masking and initial edit focus are retained")
		password.edits.passwordeditbox.text="discarded test value"; await click(password.buttons.cancelbutton.get_global_rect().get_center())
		check(not password.visible and dialog.visible and password.edits.passwordeditbox.text.is_empty() and requests.size()==count,"Password Cancel clears the draft and returns to Details without a request")
		await click(dialog.buttons.connectbutton.get_global_rect().get_center()); password.edits.passwordeditbox.text="owned-test-password"; await key(KEY_ENTER); await key(KEY_ENTER,false)
		check(requests.back().operation=="join" and not requests.back().direct and requests.back().entryId==1 and requests.back().values.password=="owned-test-password" and requests.back().values.name=="Nibs","Password OK reaches the existing canonical scoped join request with the selected server identity")
		check(password.edits.passwordeditbox.text.is_empty() and not password.visible and not dialog.visible,"Submitting a join retires both modal owners and clears the visible password")
		ui.reset(1); check(not ui.details_wanted and not ui.modal_shield.visible and not ui.details_shield.visible,"Connection replacement retires all Details/password input ownership")
	var window_state:={"focused":root.has_focus(),"unfocusable":root.unfocusable,"screen":root.current_screen,"primary":DisplayServer.get_primary_screen(),"mouse_mode":Input.mouse_mode}
	ui.close_native(); check(dialog.closed and password.closed and dialog.assets.running.is_empty() and password.assets.running.is_empty() and dialog.scrollbar.closed,"Private Details/password workers and description scrolling retire before the shared painter")
	ui.free(); painter.close(); painter.free(); text.close(); await process_frame; await process_frame
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"window":window_state,"publicConnections":0,"fullUiParity":false,"fullServerDetailsParity":false,"scope":"Source Details/password controls, immediate/pending/readonly/scroll/next/close/child-password/scoped-join input and lifetime. Extended wire decoding/local original-server queries are checked separately; complete refusal/role/build compatibility/PvP/NWSync/scale/audio/original-client comparison remains open."},"  ")+"\n"); file.close(); quit(0 if failures.is_empty() else 1)
