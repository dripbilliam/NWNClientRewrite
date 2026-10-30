extends "res://tests/native_server_list_keyboard_test.gd"
func run() -> void:
	var output:=""; var install:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
		if arg.begins_with("--install="): install=arg.substr(10)
	if output.is_empty() or install.is_empty() or FileAccess.file_exists(output): quit(2); return
	root.size=Vector2i(1280,900); surface=SubViewport.new(); surface.size=root.size; surface.render_target_update_mode=SubViewport.UPDATE_ALWAYS; surface.gui_disable_input=false; surface.handle_input_locally=true; root.add_child(surface); surface.notify_mouse_entered()
	var display:=TextureRect.new(); root.add_child(display); display.texture=surface.get_texture(); display.size=root.size; display.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var catalog:=Catalog.new(); check(catalog.mount_install(install),"Original browser assets mount locally")
	var text=preload("res://systems/native_data/talk_text.gd").new(); check(text.base.open_file(install.path_join("lang/en/data/dialog.tlk")),"Original browser captions load")
	var painter:=Painter.new(); surface.add_child(painter); painter.configure_source(catalog,ProjectSettings.globalize_path("user://native-prepared-v2"))
	var ui:=Browser.new(); surface.add_child(ui); ui.request.connect(func(value):requests.append(value.duplicate(true))); ui.configure_native(painter,text,catalog,ProjectSettings.globalize_path("user://native-prepared-v2"))
	var native=ui.native_browser
	check(await wait_until(func():return native.layout_ready),"The source-defined browser prepares")
	ui.open(false,true); ui.entry_stage="browser"
	var view:={"kind":"browser-view","connection":0,"viewId":1,"tab":"Internet","sourcePage":true,"direct":{"host":"127.0.0.1","port":5125,"name":"Owned"},"hasSessionProfile":true,"canJoin":true,"canDiscover":false,"localOnly":true,"hasSavedCdKey":true,"page":0,"pages":1,"total":128,"rows":[],"busy":false}
	for index in 128: view.rows.append({"entryId":index,"host":"127.0.0.1","port":5125+index,"serverName":"" if index==0 else "Owned %d"%index,"moduleName":"Prelude","playerCount":24,"maximumPlayers":256,"minimumLevel":1,"maximumLevel":40,"pvpSetting":2,"latency":12,"selected":false,"allowed":true})
	var presented: Dictionary=JSON.parse_string(JSON.stringify(view)); ui.receive(presented); await process_frame
	var page: Dictionary=native.pages.Internet; var first: Button=page.rows[0]; var cells: Array=first.get_meta("browser_labels"); var ids: Array=page.rows.map(func(button):return button.get_instance_id())
	check(typeof(presented.rows[0].port)==TYPE_FLOAT and cells[0].text=="127.0.0.1:5125" and cells[2].text=="24/256" and cells[3].text=="1-40" and cells[4].text=="2","Actual JSON float fields display as integer ports/counts/levels/PvP")
	check(ui.fallback_list_builds==0,"The hidden prototype Tree is not constructed alongside the original list")
	var updates: int=native.view_updates
	for index in 8: ui.refresh_entry()
	check(native.view_updates==updates and native.duplicate_views_skipped>=8 and native.row_nodes_created==128,"Repeated visibility refreshes do not republish or rebuild an identical view")
	await click(first.get_global_rect().get_center())
	check(requests.back().operation=="select" and ui.state.busy and page.rows[0]==first,"A real row click keeps its control alive during local acknowledgment")
	for update in 30:
		view.viewId+=1
		for index in 128: view.rows[index].selected=index==update%4
		ui.receive(JSON.parse_string(JSON.stringify(view)))
	check(page.rows.map(func(button):return button.get_instance_id())==ids and native.row_nodes_created==128,"Thirty selection/status views reuse all128 row controls and their labels")
	check(native.row_updates<200,"Selection changes update the changed rows instead of repainting all128 records")
	check(ui.fallback_list_builds==0,"Acknowledgments never build the unused fallback list")
	var old_scope: Array=native.scope.duplicate(); var old_revision: int=native.revision
	view.rows.reverse(); view.viewId+=1; ui.receive(JSON.parse_string(JSON.stringify(view))); await process_frame
	var before:=requests.size(); var event:=InputEventMouseButton.new(); event.button_index=MOUSE_BUTTON_LEFT; event.pressed=true
	native.row_input(event,0,old_scope,old_revision)
	check(requests.size()==before,"An explicitly retired row capture remains rejected after list reordering")
	await click(first.get_global_rect().get_center())
	check(requests.back().entryId==127 and int(ui.selection_pending.endpoint.port)==5252,"The retained first control selects the current canonical endpoint after sorting, without a stale row binding")
	view.rows=view.rows.slice(0,2); view.viewId+=1; ui.receive(JSON.parse_string(JSON.stringify(view))); await process_frame
	check(page.rows.size()==2 and page.rows[0]==first and page.body.get_child_count()==2,"Shrinking the list retires only removed rows")
	native.dismiss(); ui.refresh_entry(); await process_frame; before=requests.size(); await click(first.get_global_rect().get_center())
	check(requests.size()==before+1 and requests.back().operation=="select","Reopening the same view rebinds its current revision while retaining row controls")
	view.viewId+=1; ui.receive(JSON.parse_string(JSON.stringify(view))); ui.entry_context=false; view.viewId+=1; ui.receive(JSON.parse_string(JSON.stringify(view)))
	var item:=ui.tree.get_root().get_first_child()
	check(ui.fallback_list_builds==1 and item.get_text(0).ends_with(":5252") and item.get_text(2)=="24 / 256" and item.get_text(3)=="1–40" and item.get_text(6)=="12" and ui.paging.text=="Page 1 / 1 · 128 servers","The explicit fallback path also formats real JSON numbers without decimal suffixes")
	check(requests.all(func(value):return value.operation!="join" and value.operation!="inspect"),"Selection/view updates never initiate a remote query or connection")
	var metrics: Dictionary=native.snapshot(); ui.close_native(); ui.free(); painter.close(); painter.free(); text.close(); await process_frame; await process_frame
	var report:={"success":failures.is_empty(),"checks":checks,"failures":failures,"publicConnections":0,"metrics":metrics,"scope":"128-row original browser with actual native pointer input, repeated JSON snapshots, stable row/label instances, stale-capture/sort/reopen guards, row retirement and fallback numeric formatting. Authored replies, not a clean frame-rate or remote latency benchmark."}
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify(report,"  ")+"\n"); file.close(); quit(0 if failures.is_empty() else 1)
