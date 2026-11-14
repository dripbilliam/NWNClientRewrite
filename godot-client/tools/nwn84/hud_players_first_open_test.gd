extends SceneTree
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Gameplay=preload("res://systems/native_gameplay_ui.gd")
var checks:=0
var failures: Array=[]
var reveals: Array=[]
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label); print("FAIL ",label)
func wait_for(predicate: Callable) -> bool:
	var end:=Time.get_ticks_msec()+90000
	while not predicate.call() and Time.get_ticks_msec()<end: await process_frame
	return predicate.call()
func run() -> void:
	var report:=""; var install:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): report=arg.substr(9)
		if arg.begins_with("--install="): install=arg.substr(10)
	if report.is_empty() or install.is_empty() or FileAccess.file_exists(report): quit(2); return
	root.size=Vector2i(1000,720)
	var surface:=SubViewport.new(); surface.size=root.size; surface.render_target_update_mode=SubViewport.UPDATE_ALWAYS; surface.gui_disable_input=false; surface.handle_input_locally=true; root.add_child(surface)
	var display:=TextureRect.new(); root.add_child(display); display.texture=surface.get_texture(); display.size=root.size; display.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var catalog:=Catalog.new(); check(catalog.mount_install(install),"Original player window install mounts read-only")
	var ui:=Gameplay.new(); surface.add_child(ui); ui.configure(catalog,install,ProjectSettings.globalize_path("user://native-prepared-v2"),report+".layout.cfg")
	check(await wait_for(func():return ui.tables_ready),"Installed rules and text prepare")
	var actor:={"id":42,"objectType":5,"areaId":55,"replicated":{"name":{"text":"Player Tester"},"position":[5,5,0],"party":{"singleton":1,"leader":1,"field7DC":0}}}
	var other:={"id":84,"objectType":5,"areaId":55,"replicated":{"reaction":1}}
	var players:=[[1,{"playerId":1,"objectId":42,"isDM":0,"name":"Own account","character":{"id":42,"firstName":{"text":"Player"}}}],[7,{"playerId":7,"objectId":84,"isDM":0,"name":"Friend account","character":{"id":84,"firstName":{"text":"Friend"}}}]]
	ui.set_world(1,55,42,[actor,other],{}, {"area":{"pvp":1},"ui":{"players":players,"party":[],"playerAttitudes":[]}})
	var desktop=ui.desktop; var panel=desktop.players; var skin=desktop.players_frame
	check(not panel.visible and skin.requested.has("pnl_ig_pvp"),"Closed panel prewarms original source models during desktop setup")
	panel.visibility_changed.connect(func():if panel.visible:reveals.append({"ready":skin.admission_ready(),"cards":skin.cards.size(),"fonts":ui.inventory.frame_skin.fonts.fonts.has("fnt_galahad14"),"art":skin.images.size()}))
	var sources_before: int=skin.requested.size(); desktop.panel("pvp")
	check(panel.wanted and skin.requested.size()==sources_before and (not panel.visible or skin.admission_ready()),"First open adds no source requests and reveals only prepared original art")
	check(await wait_for(func():return panel.visible or not skin.failure.is_empty()),"First player view reaches an admitted or explicit failure state")
	check(panel.visible and skin.admission_ready() and skin.failure.is_empty(),"Player frame, popup, scrollbar, row art and fonts are ready at first reveal")
	check(reveals.size()==1 and bool(reveals[0].ready) and int(reveals[0].cards)==1 and bool(reveals[0].fonts),"The only first-open reveal contains its original row and font")
	var owner=catalog.ui_asset_owner(); var resident:=true
	for entry in skin.images.values():
		if owner.lookup("model",str(entry.key)).is_empty(): resident=false
	check(resident and skin.images.size()>=2,"Original player and invitation images remain strongly owned for the session")
	var sources: int=skin.requested.size(); panel.close_players(); desktop.panel("pvp")
	check(panel.visible and skin.admission_ready() and skin.requested.size()==sources and reveals.all(func(row):return bool(row.ready) and int(row.cards)==1),"Reopen rebuilds its row before revealing resident original art")
	var missing_key: String=str(skin.images.values()[0].key); panel.hide(); ui.inventory.frame_skin.art.failed[missing_key]=true
	await process_frame
	check(not panel.visible and skin.failure.contains(missing_key),"A missing original player image is reported while the hidden panel awaits admission")
	ui.inventory.frame_skin.art.failed.erase(missing_key); skin.failure=""
	check(await wait_for(func():return panel.visible),"A hidden player panel admits after its original image is restored")
	var diagnostic:={"reveals":reveals,"skin":skin.snapshot(),"source_models":sources,"resident":resident,"owner":owner.snapshot()}
	ui.close(); ui.free(); await process_frame
	var file:=FileAccess.open(report,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"diagnostic":diagnostic},"  ")+"\n"); file.close(); quit(0 if failures.is_empty() else 1)
