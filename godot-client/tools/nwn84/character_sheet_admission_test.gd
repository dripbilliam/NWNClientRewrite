extends "res://tests/native_character_sheet_frame_test.gd"

const SheetPlan=preload("res://systems/native_data/character_sheet_layout.gd")

func run() -> void:
	var output:=""; var install:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
		if arg.begins_with("--install="): install=arg.substr(10)
	if output.is_empty() or install.is_empty(): quit(2); return
	root.size=Vector2i(1200,800); root.set_flag(Window.FLAG_NO_FOCUS,true)
	if DisplayServer.get_screen_count()>1: root.current_screen=1
	surface=SubViewport.new(); surface.size=root.size; surface.render_target_update_mode=SubViewport.UPDATE_ALWAYS; surface.gui_disable_input=false; surface.handle_input_locally=true; root.add_child(surface); surface.notify_mouse_entered()
	var catalog:=Catalog.new(); check(catalog.mount_install(install),"Original installed sheet catalog mounts")
	var ui:=Gameplay.new(); surface.add_child(ui); ui.configure(catalog,install,ProjectSettings.globalize_path("res://.cache/nwn84-sheet-preload"),output+".layout.cfg"); ui.request.connect(func(message):requests.append(message.duplicate(true)))
	var desktop=ui.desktop; var sheet=desktop.sheet; var skin=desktop.sheet_frame
	check(not skin.requested and skin.jobs.size()==SheetPlan.RESOURCES.size(),"All original sheet models begin before first open")
	check(await wait_until(func():return ui.tables_ready),"Installed record tables prepare")
	var actor:={"id":42,"objectType":5,"areaId":55,"nativeLifetime":1,"clientKnownLifetime":1,"replicated":{"name":{"text":"Admission test"},"position":[0,0,0],"hitPoints":{"current":10,"maximum":15},"stats":{"racialType":6,"classes":[{"id":10,"level":3}]}},"inventoryStats":{"skills":[{"index":0,"flag":true,"value":4}]},"playerState":{"abilities":{"current":[10,12,10,16,11,8]},"combat":{"armorClass":12,"canLevelUp":false},"feats":[0]}}
	ui.set_world(1,55,42,[actor],{}, {"area":{"id":55},"ui":{}}); desktop.panel("character")
	check(await wait_until(func():return sheet.visible or not skin.failure.is_empty()),"First original sheet view eventually passes admission")
	check(skin.failure.is_empty() and skin.display_ready(),"Visible character page has complete original art, fonts and icons")
	check(skin.prewarmed_page_keys.size()==3 and skin.prewarmed_page_keys.all(func(key):return not ui.inventory.frame_skin.art.ui_assets.lookup("model",key).is_empty()),"All installed page backgrounds retain shared strong residency")
	var resident_icons:=0
	for name in skin.current_icon_names():
		if not ui.inventory.frame_skin.art.ui_assets.lookup("raster",name).is_empty(): resident_icons+=1
	check(resident_icons==skin.current_icon_names().size(),"Current ability icons retain shared strong residency")
	var before: int=skin.assets.serial
	sheet.tabs[1].pressed.emit()
	check(await wait_until(func():return sheet.page==1 and sheet.visible or not skin.failure.is_empty()),"Skills page becomes visible after its current art and icons")
	check(skin.failure.is_empty() and skin.display_ready(),"Skills view has no partial art after admission")
	check(skin.current_icon_names().all(func(name):return not ui.inventory.frame_skin.art.ui_assets.lookup("raster",name).is_empty()),"Current skill icons retain shared strong residency")
	var icon_bindings: Dictionary=skin.current_icon_bindings()
	if not icon_bindings.is_empty():
		var icon_key: String=str(icon_bindings.keys()[0]); var icon_target: TextureRect=sheet.image_nodes[icon_key]; var correct: Texture2D=icon_target.texture
		var image:=Image.create(2,2,false,Image.FORMAT_RGBA8); image.fill(Color.RED); icon_target.texture=ImageTexture.create_from_image(image)
		check(not skin.display_ready(),"A stale icon texture cannot pass admission merely because its resource is resident")
		sheet.present_if_ready(); check(not sheet.visible,"A stale current icon hides the page")
		desktop.bind_sheet_art(); sheet.present_if_ready(); check(sheet.visible and icon_target.texture==correct,"Current icon binding restores the admitted resident texture")
	if not sheet.entry_nodes.is_empty():
		await click(sheet.entry_nodes.values()[0])
		check(sheet.selected.has("1") and sheet.description!=null and not sheet.description.get_parsed_text().is_empty(),"An admitted original skill row still accepts real input")
	sheet.close_sheet(); desktop.panel("character")
	check(await wait_until(func():return sheet.visible or not skin.failure.is_empty()),"Warm sheet reopen completes")
	check(skin.assets.serial==before,"Page navigation and reopen do not repeat installed model reads")
	sheet.tabs[0].pressed.emit(); check(await wait_until(func():return sheet.page==0 and sheet.visible and skin.display_ready()),"Character page is admitted before level-up input")
	actor.playerState.combat.canLevelUp=true; desktop.refresh_sheet()
	check(await wait_until(func():return sheet.visible and skin.display_ready()),"Level-up-capable character page admits its current art")
	for at in 2: await process_frame
	await click(sheet.level_button)
	check(desktop.level_up.wanted and requests.any(func(message):return message.kind=="native-level-up" and message.operation=="begin"),"An admitted original level-up control sends the scoped request")
	desktop.level_up.reset()
	skin.failure="Injected original-art failure"; sheet.present_if_ready()
	check(sheet.visible and sheet.window_column.visible and sheet.notice.text.contains("Injected original-art failure"),"Terminal sheet-art failure surfaces explicitly")
	sheet.receive({"kind":"sheet-closed"}); await process_frame
	check(not sheet.wanted and not sheet.visible,"Authoritative closure cannot be reopened by pending admission work")
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"sourceModels":before,"residentAbilityIcons":resident_icons,"scope":"Installed sheet model/font/background and current icon residency; first view, page change and warm reopen admission. No public server or FPS measurement."}
	ui.close(); ui.free(); await process_frame; await process_frame
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify(result,"  ")+"\n"); file.close()
	print(JSON.stringify(result)); quit(0 if failures.is_empty() else 1)
