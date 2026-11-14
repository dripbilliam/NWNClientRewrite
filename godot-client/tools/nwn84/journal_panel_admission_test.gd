extends "res://tests/native_quickbar_frame_test.gd"

const JournalPlan=preload("res://systems/native_data/journal_layout.gd")

func run() -> void:
	var install:=""; var report:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--install="): install=arg.substr(10)
		if arg.begins_with("--report="): report=arg.substr(9)
	if install.is_empty() or report.is_empty(): quit(2); return
	root.size=Vector2i(1200,900); root.set_flag(Window.FLAG_NO_FOCUS,true)
	if DisplayServer.get_screen_count()>1: root.current_screen=1
	surface=SubViewport.new(); surface.size=root.size; surface.render_target_update_mode=SubViewport.UPDATE_ALWAYS; root.add_child(surface)
	var catalog:=Catalog.new(); check(catalog.mount_install(install),"Original installed journal catalog mounts")
	var ui:=Gameplay.new(); surface.add_child(ui); ui.configure(catalog,install,ProjectSettings.globalize_path("res://.cache/nwn84-journal-preload"),report+".layout.cfg")
	var journal=ui.desktop.journal; var skin=ui.desktop.journal_frame; var frame=ui.inventory.frame_skin
	check(not skin.requested and skin.jobs.size()>=JournalPlan.RESOURCES.size()+7,"Installed journal models and three GUI layouts start before first open")
	journal.open(); check(journal.wanted and not journal.visible,"Cold first-open journal remains hidden while source art prepares")
	journal.receive({"kind":"journal-view","viewId":1,"page":0,"loaded":true,"entries":[]})
	check(await wait_until(func():return skin.layout_ready or not skin.failure.is_empty()),"Original journal model and layout preparation completes")
	check(await wait_until(func():return journal.visible or not skin.failure.is_empty()),"Original journal appears after first-open admission")
	check(skin.failure.is_empty() and skin.display_ready(),"Journal is displayed only with current art and named font ready")
	check(frame.fonts.fonts.has(JournalPlan.FONT),"Original named journal font stays in its shared font owner")
	var resident:=0
	for data in skin.image_requests.values():
		var target: Object=data.target.get_ref()
		if is_instance_valid(target) and not target.is_queued_for_deletion():
			check(not frame.art.ui_assets.lookup("model",str(data.key)).is_empty(),"Visible journal image has shared strong residency"); resident+=1
	var before: int=skin.assets.serial
	journal.close_journal(); journal.open()
	check(journal.visible and skin.display_ready() and skin.assets.serial==before,"Warm reopen uses resident original journal resources without fresh source requests")
	skin.failure="Injected original-art failure"; journal.present_if_ready()
	check(journal.visible and journal.window_column.visible and journal.body.get_child_count()>0 and journal.body.get_child(0).get_parsed_text().contains("Injected original-art failure"),"Terminal preparation failure is visible rather than leaving a hidden panel")
	journal.receive({"kind":"journal-view","viewId":2,"page":0,"loaded":true,"entries":[]})
	check(journal.body.get_child_count()==1 and journal.body.get_child_count()>0 and journal.body.get_child(0).get_parsed_text().contains("Injected original-art failure"),"A later server view preserves the explicit art failure")
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"residentImages":resident,"sourceRequestsBeforeOpen":before,"originalFont":JournalPlan.FONT,"scope":"Installed journal layout, native font, original frame textures, first-open admission and warm reopen. No public server or FPS measurement."}
	ui.close(); ui.free(); await process_frame; await process_frame
	var file:=FileAccess.open(report,FileAccess.WRITE); file.store_string(JSON.stringify(result,"  ")+"\n"); file.close()
	print(JSON.stringify(result)); quit(0 if failures.is_empty() else 1)
