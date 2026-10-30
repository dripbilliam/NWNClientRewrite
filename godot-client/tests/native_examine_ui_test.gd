extends "res://tests/native_store_ui_test.gd"
const ThumbRange=preload("res://systems/native_data/gui_scroll_range.gd")
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("report") or not args.has("install") or FileAccess.file_exists(args.report): quit(2); return
	root.size=Vector2i(1424,921); surface=SubViewport.new(); surface.size=root.size; surface.render_target_update_mode=SubViewport.UPDATE_ALWAYS; root.add_child(surface); surface.gui_disable_input=false; surface.handle_input_locally=true; surface.notify_mouse_entered()
	var image:=TextureRect.new(); root.add_child(image); image.texture=surface.get_texture(); image.mouse_filter=Control.MOUSE_FILTER_IGNORE; image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; image.size=root.size
	var catalog:=Catalog.new(); check(catalog.mount_install(args.install),"Original examine resources mount read-only")
	var ui:=Gameplay.new(); surface.add_child(ui); ui.configure(catalog,args.install,ProjectSettings.globalize_path("user://native-prepared-v2"),str(args.report)+".layout.cfg"); ui.request.connect(func(message):requests.append(message.duplicate(true)))
	check(await wait_for(func():return ui.tables_ready and ui.inventory.frame_skin.layout_ready and ui.examine_skin.layout_ready or not ui.examine_skin.failure.is_empty()),"Original basic/item examine GUI and models prepare natively")
	var skin=ui.examine_skin; var view=ui.examine
	if not check(skin.layout_ready and skin.failure.is_empty(),"Original examine layout validates: "+skin.failure):
		var failed:=FileAccess.open(args.report,FileAccess.WRITE); failed.store_string(JSON.stringify({"success":false,"checks":checks,"failures":failures,"examine":skin.snapshot()},"\t")); failed.close(); ui.close(); ui.free(); quit(1); return
	check(await wait_for(func():return skin.scrollbars.item.art_ready and skin.scrollbars.basic.art_ready or not skin.scrollbars.item.failure.is_empty()),"Original skinned rail/thumb artwork prepares for both examine layouts")
	check(skin.scrollbars.item.art_ready and skin.scrollbars.item.failure.is_empty() and skin.scrollbars.basic.failure.is_empty(),"Examine uses native original scrollbar models rather than the generic fallback")
	var thumb_pixels: Image=skin.scrollbars.item.thumb.texture.get_image(); var middle_rows:=0
	for y in range(3,thumb_pixels.get_height()-3):
		for x in range(2,thumb_pixels.get_width()-2):
			var color:=thumb_pixels.get_pixel(x,y)
			if color.a>0.1 and color.r+color.g+color.b>0.4: middle_rows+=1; break
	check(middle_rows>=6 and skin.scrollbars.item.rail.size.y>300,"Original animated vertex andUV samples fill the thumb ribs and full-height rail, not just the end caps")
	var artwork_diagnostic:={"middle_rows":middle_rows,"thumb_size":skin.scrollbars.item.thumb.size,"rail_size":skin.scrollbars.item.rail.size}
	var oracle: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://reports/native-item-icon-oracle-v1.json")); var item: Dictionary=oracle.cases.filter(func(row):return not row.error and int(row.item.baseItem)==49)[0].item.duplicate(true)
	item.name={"text":"Unknown tonic"}; item.cost=100; item.stackSize=1; item.identified=false
	var actor:={"id":42,"objectType":5,"areaId":55,"replicated":{"name":{"firstName":{"text":"Native"},"lastName":{"text":"Examiner"}}},"playerState":{"combat":{"field898":1000}}}
	var target:={"id":11,"objectType":6,"item":item,"inventoryLocation":{"channel":"R","ownerId":42,"x":0,"y":0}}
	var objects: Array=[actor,target,{"id":22,"objectType":5,"areaId":55,"replicated":{"name":{"text":"Native visitor"}}}]
	var store:={"open":true,"generation":7,"panel":0,"page":0,"gold":100000,"identifyPrice":100,"sellRate":125,"buyRate":50,"blackMarketRate":25,"maxBuyPrice":10000,"navigationPending":false}
	var raw:={"store":store,"inventories":[["R",{"entries":[{"id":11,"x":0,"y":0}]}],["I",{"entries":[]}],["M",{"entries":[],"pageCount":1}]],"containers":[]}
	ui.set_world(1,55,42,objects,raw,{"ui":{}})
	var message:={"kind":"examine","type":"item","targetId":11,"actorId":42,"identified":false,"description":{"text":"A tonic whose properties are unknown."},"weight":10,"charges":1,"meetsLevel":true}
	ui.receive(message,1)
	check(await wait_for(func():return view.visible and skin.mode=="item" and view.portrait.texture!=null),"Original item examine frame displays the native original item icon")
	var fonts=ui.inventory.frame_skin.fonts
	check(await wait_for(func():return fonts.fonts.has("fnt_galahad14")),"Original examine bitmap font finishes native preparation")
	check(view.title_text.get_meta("native_font_applied","")=="fnt_galahad14" and view.title_text.get_theme_font("normal_font")==fonts.fonts.get("fnt_galahad14") and view.title_text.get_theme_font_size("normal_font_size")==17,"Examine title uses the original atlas and metrics with no generic font fallback")
	check(skin.fee_label.get_theme_font("normal_font")==fonts.fonts.get("fnt_galahad14") and skin.fee_label.get_theme_font_size("normal_font_size")==17 and skin.fee_label.get_meta("native_text_color",Color.TRANSPARENT).a>0,"Identify fee uses original description font and caption color")
	check(view.body.get_child(0).get_parsed_text().contains("Base Item: Potion\nWeight: 1") and not view.body.get_child(0).get_parsed_text().contains("Weight: 1.") and not view.body.get_child(0).get_parsed_text().contains("Item type:") and view.body.get_child_count()==2,"Visible item examination uses whole-number inline game fields and the server-context Identify fee without generic label/value blocks")
	check(view.body.get_theme_constant("separation")==0 and view.body.get_child(0).get_theme_font_size("normal_font_size")==17,"Original item description uses one native text flow with source line metrics")
	check(not view.window_column.visible and view.size.distance_to(skin.plans.item.size)<0.001,"Original examine panel replaces generic window framing")
	check(view.detail_width==skin.plans.item.entries.description.rect.size.x and view.scroll.horizontal_scroll_mode==ScrollContainer.SCROLL_MODE_DISABLED,"Meshless original description hooks determine the scroll/text bounds")
	check(view.portrait.size.distance_to(view.portrait.texture.get_size())<0.001,"Original item icon keeps its native raster proportions at the panel Icon hook")
	check(skin.identify_button.visible and not skin.identify_button.disabled and skin.fee_label.get_parsed_text().contains("100"),"Original Identify control and localized fee use received merchant and balance context")
	check(not ui.inventory.blocks_pointer(Vector2(1200,500)),"Examine leaves outside world pointer input available")
	await wait_for(func():return ui.inventory.equipment_skin.art.waiting.is_empty()); await RenderingServer.frame_post_draw
	surface.get_texture().get_image().save_png(str(args.report).trim_suffix(".json")+"-item.png")
	var original_description: Dictionary=message.description.duplicate(true); var rows: PackedStringArray=[]
	for index in 80: rows.append("Original scrollbar text row "+str(index))
	message.description={"text":"\n".join(rows)}; ui.receive(message,1)
	var bar=skin.scrollbars.item
	check(await wait_for(func():return bar.maximum()>500 and not bar.snapshot().thumb_pending),"Long examination text creates a real native scroll range and publishes its content-sized thumb")
	var expected_thumb: Dictionary=ThumbRange.thumb(ceili(bar.maximum())+1,roundi(bar.range_control.page),float(bar.plan.length))
	check(view.scroll.vertical_scroll_mode==ScrollContainer.SCROLL_MODE_SHOW_NEVER and absf(bar.thumb.size.x-12)<0.01 and absf(bar.thumb.size.y-float(expected_thumb.pixels))<0.01,"Original content-ratio thumb geometry and12-pixel artwork replace the generic scrollbar without stretching caps")
	check(bar.line_step==17,"Original one-line arrow step follows the loaded font's17-pixel line height")
	await motion(bar.down.get_global_rect().get_center()); await mouse(bar.down.get_global_rect().get_center(),true)
	check(absf(bar.range_control.value-17)<1 and bar.repeat_clock.active,"Original arrow advances on mouse-down and arms held input before release")
	await mouse(bar.down.get_global_rect().get_center(),false)
	check(absf(bar.range_control.value-17)<1 and not bar.repeat_clock.active,"Arrow release ends repeating without sending a second line step")
	await click(bar.up.get_global_rect().get_center()); check(bar.range_control.value==0,"Native up arrow returns actual content to the start")
	await mouse(bar.down.get_global_rect().get_center(),true); await create_timer(0.62).timeout
	check(bar.range_control.value>17,"Holding the original arrow repeats while the real native frame loop runs")
	await mouse(bar.down.get_global_rect().get_center(),false); var held_end: float=bar.range_control.value; await create_timer(0.12).timeout
	check(bar.range_control.value==held_end and not bar.repeat_clock.active and not bar.is_processing(),"Released arrows cannot continue scrolling or retain an idle native frame callback")
	bar.range_control.value=0; var down_point: Vector2=bar.down.get_global_rect().get_center()
	await mouse(down_point,true); await motion(down_point+Vector2(100,0),true); await create_timer(0.56).timeout
	check(absf(bar.range_control.value-17)<1,"A held arrow pauses when its pressed visual is no longer under the pointer")
	await motion(down_point,true); await create_timer(0.08).timeout
	check(bar.range_control.value>17,"Returning over a still-held arrow resumes its original timer without another press")
	await mouse(down_point,false)
	bar.range_control.value=0
	var page_start: Vector2=bar.global_position+Vector2(8,bar.size.y*0.6); await click(page_start)
	check(bar.range_control.value>100,"Clicking the original rail pages the actual native content")
	bar.range_control.value=0; await mouse(page_start,true); await process_frame; var first_page: float=bar.range_control.value; await create_timer(0.46).timeout
	check(bar.range_control.value>first_page and bar.repeat_clock.active,"Holding the original rail repeats page movement on its separate native timer")
	var direction_end: float=bar.range_control.value; await motion(bar.global_position+Vector2(8,25),true); await create_timer(0.15).timeout
	check(bar.range_control.value==direction_end,"Held rail paging cannot reverse direction after the pointer crosses the moving thumb")
	await motion(bar.thumb.get_global_rect().get_center(),true); await create_timer(0.15).timeout
	check(bar.range_control.value==direction_end,"Held rail paging pauses while the pointer is on the actual thumb")
	await mouse(page_start,false); var page_end: float=bar.range_control.value; await create_timer(0.12).timeout
	check(bar.range_control.value==page_end and not bar.repeat_clock.active,"Releasing the original rail retires page repetition")
	bar.range_control.value=0; await process_frame
	var thumb_start: Vector2=bar.thumb.get_global_rect().get_center(); var to: Vector2=thumb_start+Vector2(0,float(bar.plan.travel))
	await motion(thumb_start); await mouse(thumb_start,true); await motion(to,true); await mouse(to,false)
	check(absf(bar.range_control.value-bar.maximum())<1 and not bar.dragging,"Dragging the original thumb reaches the exact end and releases capture")
	bar.range_control.value=100; var focus_start: Vector2=bar.thumb.get_global_rect().get_center()
	await motion(focus_start); await mouse(focus_start,true); await motion(focus_start+Vector2(0,25),true)
	check(bar.range_control.value>100 and bar.dragging,"Native thumb dragging changes the actual content while held")
	bar.notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	check(bar.range_control.value==100 and not bar.dragging and not bar.repeat_clock.active,"Losing mouse focus cancels the original thumb drag back to its starting scroll value")
	await mouse(focus_start+Vector2(0,25),false); bar.range_control.value=bar.maximum()
	var wheel:=InputEventMouseButton.new(); wheel.position=bar.get_global_rect().get_center(); wheel.global_position=wheel.position; wheel.button_index=MOUSE_BUTTON_WHEEL_UP; wheel.pressed=true; surface.push_input(wheel,true); await process_frame; wheel.pressed=false; surface.push_input(wheel,true); await process_frame
	check(absf(bar.range_control.value-(bar.maximum()-51))<1,"Mouse wheel over the native rail scrolls three original font lines")
	bar.range_control.value=200; wheel.position=view.scroll.get_global_rect().get_center(); wheel.global_position=wheel.position; wheel.pressed=true; surface.push_input(wheel,true); await process_frame; wheel.pressed=false; surface.push_input(wheel,true); await process_frame
	check(absf(bar.range_control.value-149)<1,"Mouse wheel over the actual description uses the same three-line step as the original rail")
	await RenderingServer.frame_post_draw; surface.get_texture().get_image().save_png(str(args.report).trim_suffix(".json")+"-scroll.png")
	await wait_for(func():return ui.inventory.equipment_skin.art.models.pending.is_empty() and not ui.inventory.equipment_skin.art.models.active)
	var rendered: int=ui.inventory.equipment_skin.art.models.stats.rendered; var request_count:=requests.size()
	var scale_events: Array=[]
	bar.gui_input.connect(func(event):
		if event is InputEventMouseButton: scale_events.append({"owner":"rail","point":event.position,"pressed":event.pressed}))
	bar.down.gui_input.connect(func(event):
		if event is InputEventMouseButton: scale_events.append({"owner":"down","point":event.position,"pressed":event.pressed}))
	ui.controls.scale=Vector2(1.25,1.25); bar.range_control.value=0; await process_frame; await process_frame; await process_frame
	var scale_before:={"value":bar.range_control.value,"maximum":bar.maximum(),"disabled":bar.down.disabled,"filter":bar.down.mouse_filter,"down_path":str(bar.down.get_path()),"up_path":str(bar.up.get_path()),"down_local":bar.down.get_rect(),"root_global":bar.get_global_rect()}
	await click(bar.down.get_global_rect().get_center())
	check(absf(bar.range_control.value-17)<1 and bar.thumb.get_global_rect().size.distance_to(Vector2(15,float(expected_thumb.pixels)*1.25))<0.01,"Native scrollbar retains font-relative line steps, content-sized geometry and pointer mapping at125-percent UI scale")
	var scale_diagnostic:={"before":scale_before,"value":bar.range_control.value,"thumb_global_size":bar.thumb.get_global_rect().size,"thumb_local_size":bar.thumb.size,"controls_scale":ui.controls.scale,"down_global":bar.down.get_global_rect(),"events":scale_events.duplicate(true),"hovered":str(surface.gui_get_hovered_control().get_path()) if surface.gui_get_hovered_control()!=null else ""}
	await RenderingServer.frame_post_draw; surface.get_texture().get_image().save_png(str(args.report).trim_suffix(".json")+"-scaled.png")
	ui.controls.scale=Vector2.ONE; await process_frame
	check(requests.size()==request_count and ui.inventory.equipment_skin.art.models.stats.rendered==rendered,"Scrolling reuses original model textures and never submits a gameplay request or rerenders a model")
	var hidden_start: float=bar.range_control.value; var hidden_point: Vector2=bar.thumb.get_global_rect().get_center()
	await motion(hidden_point); await mouse(hidden_point,true); await motion(hidden_point+Vector2(0,20),true); view.hide(); await process_frame
	check(not bar.dragging and bar.range_control.value==hidden_start and not bar.repeat_clock.active,"Hiding an examination cancels its active thumb drag and restores the original scroll value")
	await mouse(hidden_point+Vector2(0,20),false)
	message.description=original_description; ui.receive(message,1); await process_frame
	check(await wait_for(func():return bar.maximum()==0 and not bar.snapshot().thumb_pending and absf(bar.thumb.size.y-float(bar.plan.length))<0.01),"Returning to short content fills the original rail with its full-size thumb")
	var before:=requests.size(); await click(skin.identify_button.get_global_rect().get_center())
	check(requests.size()==before+1 and requests.back().kind=="native-store" and requests.back().operation=="identify" and requests.back().itemId==11,"Actual original Identify button sends its validated item request")
	check(not target.item.identified and actor.playerState.combat.field898==1000 and not skin.waiting.is_empty() and skin.identify_button.disabled,"Identify waits for the server without predicting the item flag or gold charge")
	skin.identify_button.pressed.emit(); check(requests.size()==before+1,"Waiting identification cannot send duplicate requests")
	message.identified=true; message.canUse=true; message.properties=[]; ui.receive(message,1)
	target.item.identified=true; actor.playerState.combat.field898=900; ui.update_world(1,55,42,objects,[],raw,{"ui":{}}); await process_frame
	check(view.state.identified and skin.waiting.is_empty() and not ui.inventory.pending.has(11) and skin.identify_button.disabled and not skin.fee_label.visible,"Fresh authoritative item examination retires Identify waiting state and disables the original control")
	message.identified=false; target.item.identified=false; actor.playerState.combat.field898=50; ui.receive(message,1); ui.update_world(1,55,42,objects,[],raw,{"ui":{}}); await process_frame
	check(skin.identify_button.disabled and skin.fee_label.get_parsed_text().contains(ui.text.raw({"strRef":0x14b3b})),"Insufficient received gold disables Identify and shows the original localized warning")
	store.identifyPrice=-1; ui.update_world(1,55,42,objects,[],raw,{"ui":{}}); await process_frame
	check(skin.identify_button.disabled and not skin.fee_label.visible,"Original unavailable-fee sentinel disables identification without inventing a fee")
	store.identifyPrice=100; actor.playerState.combat.field898=1000; ui.update_world(1,55,42,objects,[],raw,{"ui":{}}); await process_frame
	await click(skin.identify_button.get_global_rect().get_center())
	check(not skin.waiting.is_empty() and skin.identify_button.disabled,"A new unidentified examination can issue another authoritative Identify request")
	ui.receive({"kind":"native-action-result","action":"native-store","accepted":false,"reason":"Original request refused"},1); await process_frame
	check(skin.waiting.is_empty() and not ui.inventory.pending.has(11) and not skin.identify_button.disabled and not target.item.identified,"A refused request retires both pending owners and permits retry without identifying locally")
	await click(skin.identify_button.get_global_rect().get_center()); ui.inventory.pending.erase(11); skin.sync()
	check(skin.waiting.is_empty() and not skin.identify_button.disabled,"Inventory request timeout also retires the examine wait without requiring a reopen")
	ui.receive({"kind":"store-close"},1); await process_frame
	check(view.visible and not skin.identify_button.visible,"Explicit store closure retires Identify before an old inventory header is replaced")
	ui.update_world(1,55,42,objects,[],raw,{"ui":{}}); await process_frame
	check(not skin.identify_button.visible,"A stale open header from the retired store generation cannot reactivate Identify")
	store.generation=8; ui.update_world(1,55,42,objects,[],raw,{"ui":{}}); await process_frame
	check(skin.identify_button.visible and not skin.identify_button.disabled,"A new received store generation restores valid Identify context")
	await click(skin.identify_button.get_global_rect().get_center()); ui.set_world(2,55,42,objects,raw,{"ui":{}}); await process_frame
	check(skin.waiting.is_empty() and skin.identify_button.disabled,"Changed session scope retires waiting and rejects a stale examination")
	ui.set_world(1,55,42,objects,raw,{"ui":{}}); ui.receive(message,1); await process_frame
	store.open=false; ui.update_world(1,55,42,objects,[],raw,{"ui":{}}); await process_frame
	check(view.visible and not skin.identify_button.visible,"Closing the merchant removes Identify while preserving the examine window")
	var old_revision:=int(view.state.revision); var old_icon: Texture2D=view.portrait.texture
	check(not view.set_native_portrait(old_icon,12,old_revision),"Late icon delivery for another target is discarded")
	var portrait:=-1
	for index in ui.text.tables.portraits.orderedRows.size():
		var ref:=str(ui.desktop.rules.cell(ui.desktop.rules.row("portraits",index),"BaseResRef",""))
		if not ref.is_empty() and ref!="****" and not catalog.raster_location("po_"+ref+"l").is_empty(): portrait=index; break
	ui.receive({"kind":"examine","type":"creature","targetId":22,"name":{"text":"Native visitor"},"hasDetails":true,"portraitId":portrait,"damageLevel":0,"reaction":1,"description":{"text":"A visitor.\n<c"+String.chr(1)+String.chr(255)+String.chr(1)+">Colored server detail</c>"}},1)
	check(await wait_for(func():return skin.mode=="basic" and view.portrait.texture!=null),"Original basic examine frame receives a native creature portrait")
	check(view.portrait.size==Vector2(64,100) and not skin.identify_button.visible and view.state.description.spans.any(func(span):return span.get("color","")=="#01ff01"),"Native creature portrait and server color spans retain their proportions and content")
	var texture: Texture2D=view.portrait.texture
	check(not view.set_native_portrait(old_icon,11,old_revision) and view.portrait.texture==texture,"A retired item examination cannot overwrite the current creature portrait")
	var start: Vector2=view.position; var from: Vector2=view.title_text.get_global_rect().get_center()
	await motion(from); await mouse(from,true); await motion(from+Vector2(20,15),true); await mouse(from+Vector2(20,15),false)
	check(view.position.distance_to(start+Vector2(20,15))<1,"Original examine title supports native dragging and saved position")
	await wait_for(func():return ui.inventory.equipment_skin.art.waiting.is_empty()); await RenderingServer.frame_post_draw
	surface.get_texture().get_image().save_png(str(args.report).trim_suffix(".json")+"-creature.png")
	var close_button: Button
	for child in skin.stages.basic.get_children():
		if child is Button and ui.inventory.frame_skin.button_geometry[child.get_instance_id()].resource==skin.plans.basic.entries.closebutton.resource: close_button=child
	await click(close_button.get_global_rect().get_center()); check(not view.visible,"Original Close button dismisses the native examine window")
	var snapshot: Dictionary=skin.snapshot(); ui.close(); check(skin.assets.running.is_empty() and skin.assets.pending.is_empty(),"Native examine retirement drains resource workers and detaches shared icon callbacks"); ui.free(); await process_frame; await process_frame
	var file:=FileAccess.open(args.report,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"examine":snapshot,"scale_diagnostic":scale_diagnostic,"artwork_diagnostic":artwork_diagnostic,"requests":requests,"scope":"Original basic/item examine panels and actual injected GUI input with authored server snapshots, original icons/portrait/colors and authoritative Identify guards. Real local-server Identify is separate; full text/scrollbar/font/role parity remains open."},"\t")); file.close(); print("NATIVE_EXAMINE_UI ",checks," checks / ",failures.size()," failures"); quit(0 if failures.is_empty() else 1)
