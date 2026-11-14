extends SceneTree
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Gameplay=preload("res://systems/native_gameplay_ui.gd")
var checks:=0
var failures: Array=[]
var requests: Array=[]
var surface: SubViewport
func _initialize() -> void: call_deferred("run")
func check(value: bool,label: String) -> bool:
	checks+=1
	if not value: failures.append(label); print("FAIL ",label)
	return value
func wait_until(predicate: Callable,timeout_ms: int=60000) -> bool:
	var end:=Time.get_ticks_msec()+timeout_ms
	while not predicate.call() and Time.get_ticks_msec()<end: await process_frame
	return predicate.call()
func admitted(sheet,skin) -> bool: return sheet.visible and skin.display_ready()
func mouse(point: Vector2,pressed: bool) -> void:
	var event:=InputEventMouseButton.new(); event.button_index=MOUSE_BUTTON_LEFT; event.pressed=pressed; event.position=point; event.global_position=point; event.button_mask=MOUSE_BUTTON_MASK_LEFT if pressed else 0; surface.push_input(event,true); await process_frame
func click(control: Control) -> void:
	var point:=control.get_global_rect().get_center(); var motion:=InputEventMouseMotion.new(); motion.position=point; motion.global_position=point; surface.push_input(motion,true); await process_frame; await mouse(point,true); await mouse(point,false)
func shot(output: String,suffix: String) -> void:
	for index in 3: await process_frame
	await RenderingServer.frame_post_draw; root.get_texture().get_image().save_png(output.trim_suffix(".json")+suffix+".png")
func additional_checks(_ui,_output: String,_actor: Dictionary) -> Dictionary: return {}
func run() -> void:
	var output:=""; var install:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
		if arg.begins_with("--install="): install=arg.substr(10)
	if output.is_empty() or install.is_empty() or FileAccess.file_exists(output): quit(2); return
	root.size=Vector2i(1200,800); surface=SubViewport.new(); surface.size=root.size; surface.render_target_update_mode=SubViewport.UPDATE_ALWAYS; surface.gui_disable_input=false; surface.handle_input_locally=true; root.add_child(surface); surface.notify_mouse_entered()
	var display:=TextureRect.new(); root.add_child(display); display.texture=surface.get_texture(); display.size=root.size; display.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var catalog:=Catalog.new(); check(catalog.mount_install(install),"Original character-sheet resources mount read-only")
	var ui:=Gameplay.new(); surface.add_child(ui); ui.configure(catalog,install,ProjectSettings.globalize_path("user://native-prepared-v2"),output+".layout.cfg"); ui.request.connect(func(message):requests.append(message.duplicate(true)))
	check(await wait_until(func():return ui.tables_ready and ui.inventory.frame_skin.fonts!=null),"Native record tables and shared font owner prepare")
	var desktop=ui.desktop; var sheet=desktop.sheet; var skin=desktop.sheet_frame
	check(not skin.requested and (not skin.jobs.is_empty() or skin.layout_ready),"Closed record stays unopened while installed character-sheet art prewarms during world entry")
	var actor:={"id":42,"objectType":5,"areaId":55,"nativeLifetime":1,"clientKnownLifetime":1,"replicated":{"name":{"text":"Native character"},"position":[0,0,0],"hitPoints":{"current":10,"maximum":15,"fieldE8":2},"stats":{"racialType":6,"classes":[{"id":10,"level":3}]}},"inventoryStats":{"field94":3000,"skills":[{"index":0,"flag":true,"value":4},{"index":1,"flag":true,"value":6}]},"playerState":{"abilities":{"base":[10,12,10,16,11,8],"current":[10,12,10,16,11,8]},"combat":{"armorClass":12,"canLevelUp":false},"feats":[0,1,2]}}
	ui.set_world(1,55,42,[actor],{},{"area":{"id":55},"ui":{}}); desktop.panel("character")
	check(await wait_until(func():return skin.layout_ready or not skin.failure.is_empty()),"Original programmatic character-sheet models finish bounded preparation")
	var diagnostic: Dictionary={"failure":skin.failure}
	if check(skin.layout_ready and skin.failure.is_empty(),"Original model hooks activate the native character sheet without generic fallback"):
		check(await wait_until(func():return ui.inventory.frame_skin.fonts.fonts.has("fnt_galahad14") and ui.inventory.frame_skin.fonts.fonts.has("ttf fnt_default 14") and ui.inventory.frame_skin.art.models.pending.is_empty() and not ui.inventory.frame_skin.art.models.active),"Original character frame and both original font resources publish")
		check(await wait_until(func():return admitted(sheet,skin)),"The complete original character page is admitted before pointer input")
		check(not sheet.window_column.visible and sheet.size.distance_to(Vector2(360,468))<0.001,"Original360-pixel width and resize-bar attachment bound the window")
		check(sheet.heading.text=="Native character" and sheet.heading.get_meta("native_font_applied","")=="fnt_galahad14","Native title uses actor name and original Galahad font")
		check(skin.labels.armorclass.text=="12" and skin.labels.hitpoints.text=="12/15" and not sheet.level_button.visible,"Native overview uses received AC/HP and hides level-up when unavailable")
		check(not sheet.active_scrolls.details.get_child(0).get_parsed_text().contains(": :"),"Original TLK labels with trailing colon/whitespace do not acquire a duplicate separator")
		check(sheet.image_nodes.portrait.size==Vector2(128,200) and sheet.image_nodes["ability:Str"].size==Vector2(16,16),"Portrait and ability artwork retain original aspect and pixel dimensions")
		check(skin.labels.strscore.position.distance_to(Vector2(303,75))<0.001 and skin.labels.strmodifier.position.distance_to(Vector2(332,75))<0.001,"Ability controls occupy active original model hooks")
		await shot(output,"-character")
		var tab0: Button=sheet.tabs[0]; check(tab0.button_pressed and not tab0.disabled,"Active original tab stays selected and usable as a radio control")
		await click(sheet.tabs[1]); check(sheet.page==1 and requests.any(func(m):return m.kind=="native-panel" and m.panel=="character" and int(m.page)==1),"Native Skills tab sends the existing server-compatible page subscription")
		check(await wait_until(func():return admitted(sheet,skin)),"Original Skills page art and icons finish before row input")
		check(sheet.entry_nodes.size()==2 and sheet.description!=null and sheet.active_scrolls.has("description") and sheet.active_scrolls.has("entries"),"Skills owns separate original description/list regions and live private entry handles")
		if not sheet.entry_nodes.is_empty():
			var first: int=sheet.entry_nodes.keys()[0]; var row: Button=sheet.entry_nodes[first]; await click(row)
			check(sheet.selected.has("1") and not sheet.description.get_parsed_text().is_empty(),"Native skill row click updates its actual rule-table description")
			check(row.size.distance_to(Vector2(331,34))<0.01 and row.image.size==Vector2(32,32),"Original skill row mesh bounds and32px icon replace generic row sizing")
			var old: Variant=row.drag_data(); desktop.refresh_sheet(); check(old==null or not sheet.can_drag(old),"Refreshing the received record invalidates prior private drag payloads")
		await wait_until(func():return admitted(sheet,skin) and ui.inventory.frame_skin.art.models.pending.is_empty() and not ui.inventory.frame_skin.art.models.active); await shot(output,"-skills")
		var received_skills: Array=actor.inventoryStats.skills.duplicate(true); actor.inventoryStats.skills=[]
		for skill_id in ui.text.tables.skills.orderedRows.size(): actor.inventoryStats.skills.append({"index":skill_id,"flag":true,"value":4})
		desktop.refresh_sheet(); await process_frame; await process_frame
		var list_bar=skin.bars[1]
		check(await wait_until(func():return list_bar.maximum()>300 and not list_bar.snapshot().thumb_pending),"A larger received skill fixture prepares its real row-list range and original content-sized thumb")
		var large_admitted:=await wait_until(func():return admitted(sheet,skin) or not skin.failure.is_empty(),120000)
		large_admitted=large_admitted and admitted(sheet,skin)
		if not large_admitted:
			var names: Dictionary=skin.current_icon_bindings(); var missing_icons:=0; var stale_icons:=0
			for target_key in names:
				var retained: Dictionary=ui.catalog.ui_asset_owner().lookup("raster",str(names[target_key]))
				if retained.is_empty(): missing_icons+=1
				elif not sheet.image_nodes.has(target_key) or sheet.image_nodes[target_key].texture!=retained.texture: stale_icons+=1
			print("NWN84_LARGE_SHEET_ADMISSION ",JSON.stringify({"failure":skin.failure,"visible":sheet.visible,"icons":names.size(),"missingIcons":missing_icons,"staleIcons":stale_icons,"pendingModel":ui.inventory.frame_skin.art.models.pending.size(),"activeModel":ui.inventory.frame_skin.art.models.active,"bars":skin.bars.map(func(bar):return bar.snapshot())}))
		check(large_admitted,"Large Skills view admits its resized scrollbar and current icons before wheel input")
		check(list_bar.line_step==36 and skin.bars[0].line_step==17,"Original row lists use linked36-pixel steps while the description retains its17-pixel font line step")
		var wheel:=InputEventMouseButton.new(); wheel.position=sheet.active_scrolls.entries.get_global_rect().get_center(); wheel.global_position=wheel.position; wheel.button_index=MOUSE_BUTTON_WHEEL_DOWN; wheel.pressed=true; surface.push_input(wheel,true); await process_frame; wheel.pressed=false; surface.push_input(wheel,true); await process_frame
		check(list_bar.range_control.value==108,"Wheel over an actual native skill row scrolls three original linked rows")
		await click(list_bar.down); check(list_bar.range_control.value==144,"Original list arrow advances one linked row instead of one font line")
		actor.inventoryStats.skills=received_skills; desktop.refresh_sheet(); await process_frame
		check(await wait_until(func():return admitted(sheet,skin)),"Restored Skills view is ready before tab navigation")
		await click(sheet.tabs[2]); check(sheet.page==2 and sheet.entry_nodes.size()==3 and sheet.tabs[2].button_pressed,"Original Feats tab retains typed navigation and current received feat membership")
		check(await wait_until(func():return admitted(sheet,skin)),"Original Feats view admits its current art and icons")
		await shot(output,"-feats")
		await click(sheet.tabs[0]); actor.playerState.combat.canLevelUp=true; desktop.refresh_sheet(); await process_frame
		check(await wait_until(func():return admitted(sheet,skin)),"Character view is ready before level-up input")
		check(sheet.level_button.visible and not sheet.level_button.disabled,"Received level-up availability exposes the original record button")
		for at in 2: await process_frame
		await click(sheet.level_button); check(desktop.level_up.wanted and requests.any(func(m):return m.kind=="native-level-up" and m.operation=="begin"),"Original level-up artwork invokes the real native level-up request flow")
		desktop.level_up.reset(); actor.playerState.combat.canLevelUp=false; desktop.refresh_sheet(); check(not sheet.level_button.visible,"Revoked availability removes level-up without mutating character state")
		actor.inventoryStats.fields70=[18,12,9,11,255,0]; actor.inventoryStats.fields7d=[4,2,-3,0,-1,1]; actor.inventoryStats.fields76=[14,10,12,11,0,255,-2]; desktop.refresh_sheet()
		check(skin.labels.strmodifier.text=="4" and skin.labels.strscore.get_theme_color("font_color")==Color8(32,255,32) and skin.labels.dexmodifier.text=="-1" and skin.labels.dexmodifier.get_theme_color("font_color")==Color8(255,1,1),"Actual native score/modifier controls display original received-adjustment values and token colors")
		actor.replicated.hitPoints.current=8; ui.set_world(1,55,42,[actor],{},{"area":{"id":55},"ui":{}}); await process_frame; await process_frame
		check(skin.labels.hitpoints.text=="10/15","A standalone received HP change refreshes the open native record")
		await process_frame; var registered: int=ui.inventory.frame_skin.button_geometry.size()
		for update in 8: desktop.refresh_sheet(); await process_frame
		check(ui.inventory.frame_skin.button_geometry.size()<=registered,"Repeated record refreshes retire old scrollbar/button registrations instead of retaining dead controls")
		check(await wait_until(func():return admitted(sheet,skin)),"Refreshed character view is ready before dragging and closing")
		var initial: Vector2=sheet.position; var title_point: Vector2=sheet.heading.get_global_rect().get_center(); await mouse(title_point,true)
		var motion:=InputEventMouseMotion.new(); motion.position=title_point+Vector2(50,35); motion.global_position=motion.position; motion.relative=Vector2(50,35); motion.button_mask=MOUSE_BUTTON_MASK_LEFT; surface.push_input(motion,true); await process_frame; await mouse(motion.position,false)
		check(sheet.position.distance_to(initial+Vector2(50,35))<1 and not sheet.dragging,"Original title input drags and releases the actual native record window")
		var placement:=ConfigFile.new(); check(placement.load(output+".layout.cfg")==OK and placement.get_value("positions","character-sheet",Vector2.ZERO)==sheet.position,"Native title dragging preserves the existing per-window placement storage")
		var before: int=requests.size(); await click(sheet.close_button); check(not sheet.wanted and not sheet.visible and requests.size()==before+1 and requests.back().kind=="native-panel" and not requests.back().open,"Original close control sends the authoritative record unsubscribe")
		desktop.panel("character"); check(await wait_until(func():return admitted(sheet,skin)),"Warm original frame is admitted on reopen"); check(sheet.visible and sheet.tabs[0].button_pressed,"Native frame reopens through the existing record owner")
		diagnostic=skin.snapshot(); diagnostic.list_geometry=str(skin.definition.models.ctl_chr_btnlstbx); diagnostic.art_failure=ui.inventory.frame_skin.art.failed.keys()
		diagnostic.additional=await additional_checks(ui,output,actor)
	ui.close(); ui.free(); await process_frame; await process_frame
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"diagnostic":diagnostic,"publicConnections":0,"scope":"Native original character-sheet frame/resources, actual isolated UI input, typed page/level-up routing, font and aspect checks, stale handles and close/reopen. Fixture state is not an original-server acceptance; full record content, selection/resize/audio/state/scaling parity remain open."},"\t")); file.close(); quit(0 if failures.is_empty() else 1)
