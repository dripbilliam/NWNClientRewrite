extends "res://tests/native_quickbar_frame_test.gd"
const Browser=preload("res://systems/server_browser.gd")
const Painter=preload("res://systems/native_gui_painter.gd")
func art_ready(painter) -> bool:
	return painter.art.waiting.is_empty() and painter.art.models.pending.is_empty() and not painter.art.models.active and painter.fonts.pending.is_empty()
func capture(output: String,suffix: String,painter) -> void:
	if DisplayServer.get_name()=="headless": return
	check(await wait_until(func():return art_ready(painter)),"Source browser art/fonts settle: "+suffix)
	await RenderingServer.frame_post_draw; check(surface.get_texture().get_image().save_png(output.trim_suffix(".json")+suffix+".png")==OK,"Original browser viewport saved: "+suffix)
func run() -> void:
	var output:=""; var install:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
		if arg.begins_with("--install="): install=arg.substr(10)
	if output.is_empty() or install.is_empty() or FileAccess.file_exists(output): quit(2); return
	root.size=Vector2i(1200,850); surface=SubViewport.new(); surface.size=root.size; surface.render_target_update_mode=SubViewport.UPDATE_ALWAYS; surface.gui_disable_input=false; surface.handle_input_locally=true; root.add_child(surface); surface.notify_mouse_entered()
	var catalog:=Catalog.new(); check(catalog.mount_install(install),"Original browser resources mount read-only")
	var text=preload("res://systems/native_data/talk_text.gd").new(); check(text.base.open_file(install.path_join("lang/en/data/dialog.tlk")),"Source browser captions resolve through installed TLK")
	var painter:=Painter.new(); surface.add_child(painter); painter.configure_source(catalog,ProjectSettings.globalize_path("user://native-prepared-v2"))
	var ui:=Browser.new(); surface.add_child(ui); ui.request.connect(func(message):requests.append(message.duplicate(true))); ui.configure_native(painter,text,catalog,ProjectSettings.globalize_path("user://native-prepared-v2"))
	var native=ui.native_browser
	check(await wait_until(func():return native.layout_ready and ui.entry_menu.art_ready() and ui.filter_dialog.layout_ready and ui.profile_dialog.layout_ready and ui.direct_dialog.layout_ready and ui.details_dialog.layout_ready and ui.password_dialog.layout_ready or not native.failure.is_empty()),"All original browser/navigation source resources prepare")
	check(native.layout_ready and native.failure.is_empty(),"The three native page definitions are usable: "+native.failure)
	if native.layout_ready and ui.entry_menu.art_ready():
		check(native.tabs.size()==3 and native.definition.entries.size()==5 and native.pages.size()==3,"The five original tab definitions retain the three available visible page controls")
		check(native.definition.attachment.distance_to(Vector2(0,19))<0.001 and native.definition.size.is_equal_approx(Vector2(792,537)),"Header page attachment produces original fixed page/window extents")
		check(native.definition.pages.Internet.clip.size.is_equal_approx(Vector2(625,366)) and native.definition.pages.History.clip.size.is_equal_approx(Vector2(785,415)),"Internet and saved-server pages use distinct original list viewports")
		check(native.definition.pages.Internet.columns.size()==6 and native.definition.pages.History.columns[0].size.x>native.definition.pages.Internet.columns[0].size.x,"Nested source columns are present and saved pages retain their wider name column")
		ui.open(false,true); var view:={"kind":"browser-view","connection":0,"viewId":1,"tab":"Direct","direct":{"host":"127.0.0.1","port":5125,"name":"Nibs"},"hasSessionProfile":true,"canJoin":true,"canDiscover":false,"localOnly":true,"hasSavedCdKey":true,"page":0,"pages":1,"rows":[],"busy":false}
		ui.receive(view); await click(ui.entry_menu.buttons.intjoinbutton.get_global_rect().get_center())
		check(requests.back().operation=="tab" and requests.back().sourcePage and requests.back().tab=="Internet","The source Multiplayer action requests original-page service ownership without Internet discovery")
		view.viewId=2; view.tab="Internet"; view.sourcePage=true; view.sourceSort={"header":2}; view.filters={"local":true,"server":true,"password":true}; view.advancedFilters={"hideEmpty":false,"hideFull":false,"module":""}
		for index in 40: view.rows.append({"entryId":index,"host":"127.0.0.1","port":5125+index,"serverName":"Owned server %02d"%index,"moduleName":"Prelude","playerCount":index,"maximumPlayers":64,"minimumLevel":1,"maximumLevel":40,"pvpSetting":1,"passwordRequired":index==3,"allowed":true,"selected":false})
		ui.receive(view); await process_frame
		check(native.visible and not ui.panel.visible and ui.browser_visible(),"Main-flow Internet uses the native page instead of the generic form")
		check(native.refresh_servers.visible and native.refresh_servers.disabled,"Explicit discovery remains available as a source-styled extension but respects local-only policy")
		var page: Dictionary=native.pages.Internet
		check(page.rows.size()==40 and page.buttons.playersbutton.button_pressed and page.bar.line_step==20,"All rows share the original20px line step and initial Players header presentation")
		await click(page.rows[3].get_global_rect().get_center())
		check(requests.back().operation=="select" and requests.back().entryId==3 and ui.state.busy,"Actual native row input sends its scoped private handle")
		view.viewId=3; view.rows[3].selected=true; ui.receive(view); await process_frame
		check(not page.buttons.connectbutton.disabled and not page.buttons.srvdetailsbutton.disabled,"Only an authoritative selected row enables Connect and Details")
		await capture(output,"-internet",painter)
		check(painter.art.failed.is_empty(),"No original browser model pose silently failed to render")
		var scroll_before: int=page.scroll.scroll_vertical; await mouse(page.scroll.get_global_rect().get_center(),true,MOUSE_BUTTON_WHEEL_DOWN); await mouse(page.scroll.get_global_rect().get_center(),false,MOUSE_BUTTON_WHEEL_DOWN)
		check(page.scroll.scroll_vertical>scroll_before and page.rows[3].get_child_count()>=6,"Wheel input scrolls one shared body containing all six aligned columns")
		await click(page.buttons.hidepasswords.get_global_rect().get_center())
		check(requests.back().operation=="filter" and not requests.back().filters.password,"The source Hide Passwords checkbox reaches real browser filtering")
		view.viewId=4; view.filters.password=false; ui.receive(view); await click(page.buttons.filtersbutton.get_global_rect().get_center())
		check(ui.filter_dialog.visible and ui.modal_shield.visible and native.visible,"Native Filters opens over the source browser while the global shield owns input")
		ui.escape(); await click(page.buttons.playersbutton.get_global_rect().get_center())
		check(requests.back().operation=="sort-column" and requests.back().column==2,"Original header input reaches the native sort request")
		view.viewId=5; ui.receive(view); await click(native.tabs.tab2.get_global_rect().get_center())
		check(requests.back().tab=="History" and requests.back().sourcePage,"The History tab keeps source-page ownership")
		view.viewId=6; view.tab="History"; view.rows=view.rows.slice(0,5); ui.receive(view); await process_frame
		var history: Dictionary=native.pages.History
		check(history.stage.visible and not page.stage.visible and history.buttons.srvnamebutton.disabled and history.buttons.playersbutton.disabled,"History replaces the page and disables its original sorting headers")
		await capture(output,"-history",painter)
		await click(history.buttons.favoritesbutton.get_global_rect().get_center()); check(requests.back().operation=="favorite" and requests.back().on,"Add Favorite sends explicit addition rather than toggling an existing favorite off")
		view.viewId=7; ui.receive(view); await click(native.tabs.tab3.get_global_rect().get_center()); view.viewId=8; view.tab="Favorites"; ui.receive(view); await process_frame
		var favorites: Dictionary=native.pages.Favorites
		await click(favorites.buttons.rmfavoritebutton.get_global_rect().get_center()); check(requests.back().operation=="favorite" and not requests.back().on,"Favorites uses its original Remove action")
		view.viewId=9; ui.receive(view); await click(favorites.buttons.srvdetailsbutton.get_global_rect().get_center()); check(requests.back().operation=="inspect" and requests.back().entryId==3,"Server Details queries the selected canonical server")
		view.viewId=10; view.status="Server information received"; view.details=view.rows[3].duplicate(); view.details.description="Owned server description"; ui.receive(view)
		check(ui.details_dialog.visible and ui.details_dialog.body.get_parsed_text().contains("Owned server description") and not ui.profile_dialog.visible,"Received server data remains visible in the original Server Details owner")
		ui.escape(); view.status=""; await click(favorites.buttons.dirconnectbutton.get_global_rect().get_center())
		check(ui.direct_dialog.visible and native.visible,"Direct Connect retains the native browser behind its modal")
		ui.escape(); var before:=requests.size(); var point: Vector2=favorites.buttons.connectbutton.get_global_rect().get_center(); await motion(point); await mouse(point,true); ui.back(); view.viewId=11; view.tab="Direct"; ui.receive(view); await mouse(point,false)
		check(ui.entry_menu.visible and not native.visible and requests.size()==before+1 and requests.back().operation=="return-menu","A held Connect cannot join after browser Cancel retires the owner")
	var window_state:={"focused":root.has_focus(),"unfocusable":root.unfocusable,"screen":root.current_screen,"primary":DisplayServer.get_primary_screen(),"mouse_mode":Input.mouse_mode}
	ui.close_native(); check(native.closed and native.assets.running.is_empty() and native.pages.values().all(func(page):return page.bar.closed),"All native page workers and scroll owners retire before shared rendering resources")
	ui.free(); painter.close(); painter.free(); text.close(); await process_frame; await process_frame
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"window":window_state,"publicConnections":0,"fullUiParity":false,"fullServerBrowserParity":false,"scope":"Original Internet/History/Favorites frames, source page/tab/column/viewport attachments, native pointer/modal/wheel action routing and lifetime. Game-type selection, complete details/password/connection panels, double-click/keyboard, PvP/NWSync words, original-client comparisons and all roles/scales/audio remain incomplete."},"  ")+"\n"); file.close(); quit(0 if failures.is_empty() else 1)
