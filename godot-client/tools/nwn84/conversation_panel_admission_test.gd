extends "res://tests/native_quickbar_frame_test.gd"

const Plan=preload("res://systems/native_data/conversation_layout.gd")

func receive_dialog(ui,message: Dictionary) -> void:
	ui.receive(message,1)
	await process_frame

func run() -> void:
	var install:=""; var report:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--install="): install=arg.substr(10)
		if arg.begins_with("--report="): report=arg.substr(9)
	if install.is_empty() or report.is_empty(): quit(2); return
	root.size=Vector2i(1200,900); root.set_flag(Window.FLAG_NO_FOCUS,true)
	if DisplayServer.get_screen_count()>1: root.current_screen=1
	surface=SubViewport.new(); surface.size=root.size; surface.render_target_update_mode=SubViewport.UPDATE_ALWAYS; root.add_child(surface)
	var catalog:=Catalog.new(); check(catalog.mount_install(install),"Installed original conversation catalog mounts")
	var ui:=Gameplay.new(); surface.add_child(ui); ui.configure(catalog,install,ProjectSettings.globalize_path("res://.cache/nwn84-conversation-preload"),report+".layout.cfg")
	var dialog=ui.conversation; var skin=ui.conversation_skin; var frame=ui.inventory.frame_skin
	check(skin.requested and skin.jobs.size()==Plan.RESOURCES.size() and not dialog.opened,"Static conversation models start before any server dialogue")
	check(await wait_until(func():return ui.tables_ready and skin.layout_ready or not skin.failure.is_empty()),"Original conversation models and portrait rules prepare")
	var portraits: Array=[]; var portrait_resources: Dictionary={}
	for id in ui.text.tables.portraits.orderedRows.size():
		var base: String=ui.desktop.rules.cell(ui.desktop.rules.row("portraits",id),"BaseResRef","")
		if not base.is_empty() and base!="****" and not portrait_resources.has(base) and not catalog.raster_location("po_"+base+"m").is_empty():
			portraits.append(id); portrait_resources[base]=true
			if portraits.size()==2: break
	check(portraits.size()==2,"Two installed speaker portraits are available")
	if portraits.size()==2 and skin.failure.is_empty():
		var actors: Array=[]
		for at in 3:
			actors.append({"id":42+at,"objectType":5,"areaId":55,"replicated":{"name":{"text":"Speaker "+str(at)},"portrait":portraits[clampi(at-1,0,1)],"hitPoints":{"current":10,"maximum":10},"stats":{"racialType":6,"classes":[{"id":10,"level":1}]}},"playerState":{}})
		ui.set_world(1,55,42,actors,{}, {"area":{"id":55}})
		await receive_dialog(ui,{"kind":"dialog-entry","ownerId":43,"speakerId":43,"tokenObjectId":43,"text":{"text":"First entry"}})
		check(dialog.opened and not dialog.visible,"Cold conversation does not expose partial frame or portrait")
		await receive_dialog(ui,{"kind":"dialog-replies","entryId":7,"end":false,"firstCount":1,"secondCount":0,"tokenObjectId":43,"replies":[{"id":1,"text":{"text":"First answer"}}]})
		check(await wait_until(func():return dialog.visible or not skin.art_failure().is_empty()),"First dialogue appears after current art and font admission")
		check(dialog.visible and skin.display_ready() and not dialog.window_column.visible,"Visible conversation has current native frame and portrait")
		check(frame.art.ui_assets.lookup("model",skin.background_key).texture==skin.background.texture,"Background is strongly resident under the original catalog owner")
		check(await wait_until(func():return skin.portrait.visible or frame.art.failed.has(skin.portrait_key)),"Current speaker portrait prepares on demand")
		check(portrait_matches(skin,frame),"Current portrait is strongly resident and bound")
		var old_key: String=skin.portrait_key
		await receive_dialog(ui,{"kind":"dialog-entry","ownerId":44,"speakerId":44,"tokenObjectId":44,"text":{"text":"New speaker"}})
		check(skin.portrait_key!=old_key and (not skin.portrait.visible or portrait_matches(skin,frame)),"Changed speaker cannot expose the previous portrait")
		await receive_dialog(ui,{"kind":"dialog-replies","entryId":8,"end":false,"firstCount":1,"secondCount":0,"tokenObjectId":44,"replies":[{"id":2,"text":{"text":"Second answer"}}]})
		check(await wait_until(func():return dialog.visible or not skin.art_failure().is_empty()),"Changed speaker portrait and background reach admission")
		check(dialog.visible and skin.display_ready(),"Second speaker can speak while its portrait prepares")
		check(await wait_until(func():return skin.portrait.visible or frame.art.failed.has(skin.portrait_key)),"Second speaker portrait prepares on demand")
		check(portrait_matches(skin,frame),"Second speaker uses its own bound original portrait")
		var before: int=skin.assets.serial
		await receive_dialog(ui,{"kind":"dialog-close"})
		await receive_dialog(ui,{"kind":"dialog-entry","ownerId":44,"speakerId":44,"tokenObjectId":44,"text":{"text":"Reopened"}})
		await receive_dialog(ui,{"kind":"dialog-replies","entryId":9,"end":false,"firstCount":1,"secondCount":0,"tokenObjectId":44,"replies":[{"id":3,"text":{"text":"Reopened answer"}}]})
		check(await wait_until(func():return dialog.visible and skin.display_ready()),"Warm reopen admits original conversation art")
		check(skin.assets.serial==before,"Warm conversation uses prepared models without new source reads")
		skin.failure="Injected original art failure"; dialog.present_if_ready()
		check(dialog.visible and dialog.window_column.visible and failure_notice_text(dialog).contains("Injected original art failure"),"Original-art failure is explained in the conversation panel")
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Installed original conversation models, fonts, speaker portraits, first-open admission, warm reopen and explicit failure; no FPS measurement."}
	ui.close(); ui.free(); await process_frame; await process_frame
	var file:=FileAccess.open(report,FileAccess.WRITE); file.store_string(JSON.stringify(result,"  ")+"\n"); file.close()
	print(JSON.stringify(result)); quit(0 if failures.is_empty() else 1)

func failure_notice_text(dialog) -> String:
	return dialog.failure_notice.get_parsed_text()

func portrait_matches(skin,frame) -> bool:
	var shared: Dictionary=frame.art.ui_assets.lookup("raster",skin.portrait_key)
	return skin.portrait.visible and skin.portrait.texture is AtlasTexture and not shared.is_empty() and skin.portrait.texture.atlas==shared.texture
