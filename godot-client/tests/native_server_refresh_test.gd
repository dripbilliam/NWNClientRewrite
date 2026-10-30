extends "res://tests/native_server_list_keyboard_test.gd"
func run() -> void:
	var output:=""; var install:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
		if arg.begins_with("--install="): install=arg.substr(10)
	if output.is_empty() or install.is_empty() or FileAccess.file_exists(output): quit(2); return
	root.size=Vector2i(1280,900); surface=SubViewport.new(); surface.size=root.size; surface.render_target_update_mode=SubViewport.UPDATE_ALWAYS; surface.gui_disable_input=false; surface.handle_input_locally=true; root.add_child(surface); surface.notify_mouse_entered()
	var display:=TextureRect.new(); root.add_child(display); display.texture=surface.get_texture(); display.size=root.size; display.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var catalog:=Catalog.new(); check(catalog.mount_install(install),"Original server-browser assets mount locally")
	var text=preload("res://systems/native_data/talk_text.gd").new(); check(text.base.open_file(install.path_join("lang/en/data/dialog.tlk")),"Original server-browser captions load")
	var painter:=Painter.new(); surface.add_child(painter); painter.configure_source(catalog,ProjectSettings.globalize_path("user://native-prepared-v2"))
	var ui:=Browser.new(); surface.add_child(ui); ui.request.connect(func(message):requests.append(message.duplicate(true))); ui.configure_native(painter,text,catalog,ProjectSettings.globalize_path("user://native-prepared-v2"))
	var native=ui.native_browser
	var ready:=await wait_until(func():return native.layout_ready and ui.entry_menu.art_ready() or not native.failure.is_empty())
	check(ready and native.failure.is_empty(),"Original browser and native header refresh icon prepare")
	if ready and native.failure.is_empty():
		ui.open_list(); var view:={"kind":"browser-view","connection":0,"viewId":1,"tab":"Internet","sourcePage":true,"direct":{"host":"127.0.0.1","port":5121,"name":"Tester"},"hasSessionProfile":true,"canJoin":true,"canDiscover":true,"localOnly":false,"hasSavedCdKey":true,"page":0,"pages":1,"total":1,"rows":[{"entryId":0,"host":"127.0.0.1","port":5121,"serverName":"Local fixture result","moduleName":"Prelude","playerCount":3,"maximumPlayers":64,"minimumLevel":1,"maximumLevel":40,"pvpSetting":1,"allowed":true}],"busy":false,"refreshCooldownMs":0}
		ui.receive(JSON.parse_string(JSON.stringify(view))); await process_frame
		var icon: Button=native.refresh_servers
		check(icon.visible and not icon.disabled and icon.tooltip_text=="Refresh servers","Ready Internet page exposes the labeled refresh action")
		check(Rect2(Vector2.ZERO,native.size).encloses(icon.get_rect()) and icon.position.x>native.size.x-60 and icon.position.y<40,"Refresh is inside the browser's top-right header")
		check(native.tabs.values().all(func(tab):return not tab.get_rect().intersects(icon.get_rect())) and icon.size==Vector2(30,30),"Compact refresh icon does not overlap the original tabs or stretch source artwork")
		var at:=requests.size(); var began:=Time.get_ticks_msec(); await click(icon.get_global_rect().get_center())
		check(requests.size()==at+1 and requests.back().operation=="refresh" and icon.disabled,"Actual refresh click immediately disables the icon and sends one scoped request")
		view.viewId+=1; view.refreshCooldownMs=1500; ui.receive(view); await process_frame
		await click(icon.get_global_rect().get_center())
		check(requests.size()==at+1 and icon.disabled,"A quick provider reply cannot permit a second refresh during the local lock")
		view.viewId+=1; view.tab="History"; view.refreshCooldownMs=0; ui.receive(view); await process_frame
		check(not icon.visible,"Refresh is hidden on saved-server pages")
		view.viewId+=1; view.tab="Internet"; ui.receive(view); await process_frame
		check(icon.visible and icon.disabled,"Switching tabs cannot reset the two-second click lock")
		check(await wait_until(func():return not icon.disabled),"The refresh icon unlocks automatically without another provider view")
		check(Time.get_ticks_msec()-began>=2000 and native.refresh_timer.is_stopped(),"The lock lasts at least two seconds and its one-shot timer stops")
		if DisplayServer.get_name()!="headless":
			check(await wait_until(func():return painter.art.waiting.is_empty() and painter.fonts.pending.is_empty()),"Native browser artwork settles before capture")
			await RenderingServer.frame_post_draw; check(surface.get_texture().get_image().save_png(output.trim_suffix(".json")+".png")==OK,"Top-right native refresh icon captured")
		view.viewId+=1; view.busy=true; ui.receive(view); await process_frame
		check(icon.disabled,"Busy discovery remains locked after the cooldown has elapsed")
		view.viewId+=1; view.busy=false; view.canDiscover=false; ui.receive(view); await process_frame
		check(icon.disabled and icon.tooltip_text.contains("disabled for this session"),"Local-only discovery policy still disables the icon")
		view.viewId+=1; view.canDiscover=true; ui.receive(view); await process_frame
		at=requests.size(); await click(icon.get_global_rect().get_center())
		check(requests.size()==at+1 and requests.back().viewId==view.viewId,"Refresh becomes usable again with the current canonical scope")
		ui.close(); check(native.refresh_timer.is_stopped() and not native.visible,"Closing the browser stops its cooldown timer and retires pointer ownership")
	check(requests.all(func(row):return row.operation!="join" and row.operation!="inspect"),"Local UI checks do not query or join game servers")
	ui.close_native(); ui.free(); painter.close(); painter.free(); text.close(); await process_frame; await process_frame
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"publicConnections":0,"scope":"Actual native refresh icon placement and pointer actions, immediate two-second lock, provider-reply/tab changes, timer expiry, busy/policy/stale scope and lifetime. Authored provider replies only."},"  ")+"\n"); file.close(); quit(0 if failures.is_empty() else 1)
