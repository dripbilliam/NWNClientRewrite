extends "res://tests/native_character_sheet_frame_test.gd"
func motion_resize(point: Vector2,relative: Vector2=Vector2.ZERO) -> void:
	var event:=InputEventMouseMotion.new(); event.position=point; event.global_position=point; event.relative=relative; event.button_mask=MOUSE_BUTTON_MASK_LEFT; surface.push_input(event,true)
func ready_bars(skin) -> bool:
	return skin.bars.all(func(bar):return bar.art_ready and not bar.snapshot().layout_pending and not bar.snapshot().thumb_pending and bar.failure.is_empty())
func additional_checks(ui,output: String,_actor: Dictionary) -> Dictionary:
	var skin=ui.desktop.sheet_frame; var sheet=ui.desktop.sheet
	check(await wait_until(func():return ready_bars(skin)),"Original character scroll geometry settles before the resize input test")
	var original_size: Vector2=sheet.size; var original_position: Vector2=sheet.position; var original_view: int=sheet.view_id; var portrait: TextureRect=sheet.image_nodes.portrait; var sent_before:=requests.size()
	var start: Vector2=skin.footer.get_global_rect().get_center(); await mouse(start,true)
	motion_resize(start+Vector2(70,100),Vector2(70,100)); await process_frame
	check(skin.resizing and sheet.size==original_size+Vector2(0,100) and sheet.position==original_position,"Dragging the original footer resizes vertically without moving the window or stretching its width")
	await mouse(start+Vector2(70,100),false)
	check(not skin.resizing and not skin.footer.is_pressed(),"Footer release ends resizing and clears the real Button pressed/capture state")
	check(await wait_until(func():return ready_bars(skin)),"Original resized rail and thumb geometry publish together")
	var details: Dictionary=skin.resizable_scrolls.details
	check(absf(details.scroll.position.y+details.scroll.size.y-(sheet.size.y-59-11))<0.001 and absf(details.entry.model.hooks.scrollmax.y-details.entry.model.hooks.text1.y+14)<0.001,"In-game resize applies original world-anchor footer11 and scrollbar14 offsets")
	check(sheet.view_id==original_view and sheet.image_nodes.portrait==portrait and requests.size()==sent_before,"Resizing preserves current private view/image controls and sends no gameplay request")
	var config:=ConfigFile.new(); check(config.load(output+".layout.cfg")==OK and config.get_value("sizes","character-sheet",Vector2.ZERO)==sheet.size,"Original-framed resize persists the native window size beside its placement")
	await shot(output,"-grown")
	var bar=skin.bars[0]; var previous_packets: int=bar.layout_requests; start=skin.footer.get_global_rect().get_center(); await mouse(start,true)
	for at in range(1,65): motion_resize(start+Vector2(0,at*0.5))
	check(bar.layout_requests==previous_packets,"A burst of64 raw mouse motions coalesces before scheduling native scrollbar models")
	await mouse(start+Vector2(0,32),false)
	check(await wait_until(func():return ready_bars(skin)) and bar.layout_requests==previous_packets+1,"The latest burst geometry publishes as one bounded layout packet")
	var burst_packets: int=bar.layout_requests-previous_packets
	var grown: Vector2=sheet.size; start=skin.footer.get_global_rect().get_center(); await mouse(start,true); motion_resize(start+Vector2(0,20)); await process_frame
	skin.notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT); await mouse(start+Vector2(0,20),false)
	check(not skin.resizing and sheet.size.y==grown.y+20,"Focus loss ends resize input without leaving a stuck capture or reverting the moved original footer")
	await wait_until(func():return ready_bars(skin))
	await click(sheet.tabs[1]); check(await wait_until(func():return sheet.page==1 and not sheet.entry_nodes.is_empty() and ready_bars(skin)),"Original Skills page reopens at the resized height with settled native scroll geometry")
	var selected_id: int=sheet.entry_nodes.keys()[0]; await click(sheet.entry_nodes[selected_id]); var selected_entry: Button=sheet.entry_nodes[selected_id]; var selected_view: int=sheet.view_id; var description: String=sheet.description.get_parsed_text(); var description_size: Vector2=sheet.active_scrolls.description.size; sent_before=requests.size()
	start=skin.footer.get_global_rect().get_center(); await mouse(start,true); motion_resize(start+Vector2(0,30)); await process_frame; await mouse(start+Vector2(0,30),false); await wait_until(func():return ready_bars(skin))
	check(sheet.entry_nodes[selected_id]==selected_entry and selected_entry.current() and sheet.view_id==selected_view and sheet.description.get_parsed_text()==description,"Resizing Skills preserves the selected private entry and description without rebuilding page controls")
	var list_view: Dictionary=skin.resizable_scrolls.entries
	check(sheet.active_scrolls.description.size==description_size and absf(list_view.entry.model.hooks.bottom.y-(sheet.size.y-59-155-11))<0.001 and absf(list_view.entry.model.hooks.bottom.y-list_view.entry.model.hooks.scrollmax.y-14)<0.001,"Original description region stays fixed while the lower row viewport follows its footer/scrollbar world anchors")
	check(requests.size()==sent_before,"Resizing a populated Skills page does not send a new panel subscription or gameplay request")
	await shot(output,"-skills-grown")
	var retained: Vector2=sheet.size; sheet.close_sheet(); ui.desktop.panel("character"); await process_frame
	check(sheet.size==retained and sheet.visible,"Reopening retains the native resized height")
	var fresh_sheet:=preload("res://systems/server_character_sheet.gd").new(); ui.controls.add_child(fresh_sheet); fresh_sheet.setup(output+".layout.cfg"); fresh_sheet.wanted=true
	var fresh_skin:=preload("res://systems/native_character_sheet_frame.gd").new(); root.add_child(fresh_skin); fresh_skin.configure(fresh_sheet,ui.catalog,ProjectSettings.globalize_path("user://native-prepared-v2"),ui.text,ui.inventory.frame_skin)
	fresh_sheet.receive(sheet.state.duplicate(true))
	check(await wait_until(func():return fresh_skin.layout_ready or not fresh_skin.failure.is_empty()) and fresh_skin.layout_ready and fresh_skin.failure.is_empty() and fresh_sheet.size==retained,"A fresh native record owner reloads persisted size from disk without JS presentation state")
	fresh_skin.close(); fresh_skin.free(); fresh_sheet.free(); await process_frame
	skin.set_height(original_size.y); await wait_until(func():return ready_bars(skin)); sheet.position=Vector2(30,40); ui.controls.scale=Vector2(1.25,1.25); await process_frame
	start=skin.footer.get_global_rect().get_center(); await mouse(start,true); motion_resize(start+Vector2(50,50)); await process_frame; await mouse(start+Vector2(50,50),false)
	check(absf(sheet.size.y-original_size.y-40)<0.001 and sheet.size.x==360,"At125-percent UI scale,50 screen pixels resize40 original GUI pixels with unchanged artwork width")
	check(await wait_until(func():return ready_bars(skin)),"Scaled resize settles its actual original scrollbar models")
	await shot(output,"-scaled")
	ui.controls.scale=Vector2.ONE; await process_frame; skin.set_height(100000); await process_frame
	check(sheet.get_global_rect().end.y<=surface.size.y+0.001,"Resize height stays within the current viewport without moving/capturing the physical mouse")
	skin.set_height(1); await process_frame; check(sheet.size.y>=71 and skin.footer.get_global_rect().position.y>=sheet.heading.get_global_rect().end.y,"Structural minimum keeps the original title/close/footer controls reachable")
	skin.set_height(original_size.y); sheet.position=original_position; await wait_until(func():return ready_bars(skin)); await shot(output,"-restored")
	var end: Dictionary=skin.snapshot(); var ownership_before: int=ui.inventory.frame_skin.button_geometry.size()
	start=skin.footer.get_global_rect().get_center(); await mouse(start,true); motion_resize(start+Vector2(0,40)); await process_frame; sheet.close_sheet(); await mouse(start+Vector2(0,40),false)
	check(not skin.resizing and not sheet.visible,"Closing the record retires an active resize while its native artwork may still be preparing")
	ui.desktop.panel("character"); await process_frame; await wait_until(func():return ready_bars(skin))
	check(ui.inventory.frame_skin.button_geometry.size()<=ownership_before,"Reopening after resize does not retain obsolete native scrollbar/button registrations")
	return {"scope":"Actual isolated original-footer resize input, world-hook offsets, coalescing, focus/reopen/fresh-owner persistence,125% scale, viewport/minimum guards and close-during-preparation. Original-client capture/minimum/scene clipping parity remains unaccepted.","before":str(original_size),"grown":str(retained),"settled":end,"packet_burst":burst_packets,"physicalMouseWarped":false}
