extends SceneTree
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Art=preload("res://systems/native_ui_art.gd")
const Buffs=preload("res://systems/server_buffs.gd")
const Frame=preload("res://systems/native_effect_bar.gd")
var checks:=0
var failures: Array=[]
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label); print("FAIL ",label)
func wait_for(predicate: Callable) -> bool:
	var end:=Time.get_ticks_msec()+90000
	while not predicate.call() and Time.get_ticks_msec()<end: await process_frame
	return predicate.call()
func send(buff,view_id: int,rows: Array) -> void:
	buff.receive({"kind":"buff-begin","viewId":view_id,"actorId":9,"count":rows.size()})
	buff.receive({"kind":"buff-rows","viewId":view_id,"rows":rows})
	buff.receive({"kind":"buff-commit","viewId":view_id})
func run() -> void:
	var install:=""; var report:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--install="): install=arg.substr(10)
		if arg.begins_with("--report="): report=arg.substr(9)
	if install.is_empty() or report.is_empty() or FileAccess.file_exists(report): quit(2); return
	root.size=Vector2i(900,700)
	var catalog:=Catalog.new(); check(catalog.mount_install(install),"Original installed content mounts")
	var art:=Art.new(); root.add_child(art); art.configure(catalog,ProjectSettings.globalize_path("user://native-prepared-v2"))
	var host:=Control.new(); root.add_child(host); host.size=root.size
	var buffs:=Buffs.new(); host.add_child(buffs); buffs.setup()
	var frame:=Frame.new(); root.add_child(frame); frame.configure(buffs,art,catalog,ProjectSettings.globalize_path("user://native-prepared-v2"))
	check(await wait_for(func():return frame.layout_ready or not frame.failure.is_empty()) and frame.layout_ready,"Original effect bar models prepare")
	check(not buffs.visible and not frame.stage.visible,"Empty effect bar remains hidden")
	var acid:={"id":1,"state":false,"resource":"is_acidfog","label":"Acid Fog","serial":1}
	send(buffs,1,[acid])
	check(not buffs.visible and frame.admission_pending and not frame.stage.visible,"First effect set stays hidden while its original icon prepares")
	check(await wait_for(func():return buffs.visible or not buffs.art_error.is_empty()) and buffs.visible and buffs.art_error.is_empty(),"First effect set appears after icon and frame art are ready")
	var first_icon=buffs.buttons[1].get_node("Icon")
	check(first_icon.art_ready() and not catalog.ui_asset_owner().lookup("raster","is_acidfog").is_empty(),"First icon is complete and strongly resident in the catalog UI owner")
	var second:={"id":2,"state":false,"resource":"iashsw","label":"Second effect","serial":2}
	send(buffs,2,[second,acid])
	check(not buffs.visible and frame.admission_pending and not frame.stage.visible,"Changed effect set hides all existing icons until its addition is ready")
	check(await wait_for(func():return buffs.visible or not buffs.art_error.is_empty()) and buffs.visible and buffs.art_error.is_empty(),"Changed effect set is admitted as one complete set")
	check(buffs.buttons.size()==2 and buffs.buttons[1].get_node("Icon").art_ready() and buffs.buttons[2].get_node("Icon").art_ready() and not catalog.ui_asset_owner().lookup("raster","iashsw").is_empty(),"Both changed-set icons and their original rasters are ready")
	check(not frame.is_processing(),"Nonflashing admitted effect set has no per-frame readiness scans")
	var missing:={"id":3,"state":false,"resource":"nwn84_missing_effect_icon","label":"Missing effect","serial":3}
	send(buffs,3,[missing,acid])
	check(await wait_for(func():return not buffs.art_error.is_empty()) and buffs.visible and not frame.stage.visible and frame.notice.visible and frame.notice.text.contains("nwn84_missing_effect_icon"),"Missing original icon shows failure without a partial effect set")
	check(not frame.admission_pending and not frame.is_processing(),"Failed art stops readiness polling")
	buffs.reset(); check(not buffs.visible and not frame.stage.visible and buffs.art_error.is_empty(),"Reset retires the failed set and notice")
	var diagnostics:={"frame_failure":frame.failure,"owner":catalog.ui_asset_owner().snapshot(),"art_failed":art.failed.keys()}
	frame.close(); frame.free(); buffs.free(); host.free(); art.close(); art.free(); await process_frame
	var file:=FileAccess.open(report,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"diagnostics":diagnostics},"  ")+"\n"); file.close(); quit(0 if failures.is_empty() else 1)
