extends "res://tests/native_quickbar_frame_test.gd"
const Browser=preload("res://systems/server_browser.gd")
const Painter=preload("res://systems/native_gui_painter.gd")
func wait_cohorts(predicate: Callable) -> bool:
	var end:=Time.get_ticks_msec()+15000
	while not predicate.call() and Time.get_ticks_msec()<end: await process_frame
	return predicate.call()
func press(code: Key) -> void:
	await key(code,true); await key(code,false)
func run() -> void:
	var output:=""; var install:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
		if arg.begins_with("--install="): install=arg.substr(10)
	if output.is_empty() or install.is_empty() or FileAccess.file_exists(output): quit(2); return
	root.size=Vector2i(1200,850); surface=SubViewport.new(); surface.size=root.size; surface.render_target_update_mode=SubViewport.UPDATE_ALWAYS; surface.gui_disable_input=false; surface.handle_input_locally=true; root.add_child(surface); surface.notify_mouse_entered()
	var catalog:=Catalog.new(); check(catalog.mount_install(install),"Original browser filter resources mount read-only")
	var text=preload("res://systems/native_data/talk_text.gd").new(); check(text.base.open_file(install.path_join("lang/en/data/dialog.tlk")),"Filter captions resolve from original TLK")
	var painter:=Painter.new(); surface.add_child(painter); painter.configure_source(catalog,ProjectSettings.globalize_path("user://native-prepared-v2"))
	var ui:=Browser.new(); surface.add_child(ui); ui.request.connect(func(message):requests.append(message.duplicate(true))); ui.configure_native(painter,text,catalog,ProjectSettings.globalize_path("user://native-prepared-v2"))
	var dialog=ui.filter_dialog
	check(await wait_cohorts(func():return dialog.art_ready() and ui.profile_dialog.art_ready() or not dialog.cohort_snapshot().failures.is_empty()),"Filter and refusal-notice image/font cohorts prepare")
	check(dialog.art_ready(),"All required filter controls and artwork are present: "+str(dialog.cohort_snapshot().failures))
	if dialog.art_ready() and ui.profile_dialog.art_ready():
		check(dialog.definition.entries.size()==10 and dialog.buttons.size()==5 and dialog.labels.size()==4 and dialog.edits.size()==1,"Original nested labels, two checkboxes, edit and all three dismissal/accept controls are retained")
		check(dialog.definition.entries.okbutton.callback=="0x1408d0b10" and dialog.definition.entries.cancelbutton.callback=="0x1408cdda0" and dialog.definition.entries.xbutton.callback=="0x1408cdda0","Original filter action associations are distinct from Direct Connect")
		ui.open(); var view:={"kind":"browser-view","connection":0,"viewId":1,"tab":"Internet","direct":{"host":"127.0.0.1","port":5125,"name":"Nibs"},"hasSessionProfile":true,"canJoin":true,"canDiscover":false,"localOnly":true,"hasSavedCdKey":true,"page":0,"pages":1,"rows":[],"busy":false,"advancedFilters":{"hideEmpty":false,"hideFull":false,"module":""}}
		ui.receive(view); await process_frame; var count:=requests.size(); await click(ui.filter_button.get_global_rect().get_center())
		check(dialog.visible and ui.modal_shield.visible and not ui.panel.visible and requests.size()==count,"Filters opens the source modal without saving preferences or contacting any server")
		check(ui.blocks_pointer(Vector2(1,1)),"The modal prevents click-through across the viewport")
		await click(dialog.buttons.havepeoplebox.get_global_rect().get_center()); await click(dialog.buttons.notfullbox.get_global_rect().get_center()); dialog.edits.moduleedit.text="Prelude"
		check(dialog.buttons.havepeoplebox.button_pressed and dialog.buttons.notfullbox.button_pressed,"Both source checkboxes change from real native pointer input")
		if DisplayServer.get_name()!="headless":
			check(await wait_until(func():return painter.art.waiting.is_empty() and painter.art.models.pending.is_empty() and not painter.art.models.active and painter.fonts.pending.is_empty()),"Filter artwork and bitmap fonts settle")
			await RenderingServer.frame_post_draw; check(surface.get_texture().get_image().save_png(output.trim_suffix(".json")+".png")==OK,"Filter viewport saved for visual review")
		await click(dialog.buttons.cancelbutton.get_global_rect().get_center())
		check(not dialog.visible and ui.panel.visible and not ui.modal_shield.visible and requests.size()==count,"Cancel discards the draft and restores the browser without a protocol request")
		ui.open_filters(); check(not dialog.buttons.havepeoplebox.button_pressed and not dialog.buttons.notfullbox.button_pressed and dialog.edits.moduleedit.text.is_empty(),"Reopening restores authoritative preferences rather than the canceled draft")
		await click(dialog.buttons.havepeoplebox.get_global_rect().get_center()); dialog.edits.moduleedit.text="Prelude"; await click(dialog.buttons.okbutton.get_global_rect().get_center())
		check(requests.back().operation=="advanced-filter" and requests.back().viewId==1 and requests.back().values=={"hideEmpty":true,"hideFull":false,"module":"Prelude"} and not dialog.visible and ui.state.busy,"OK sends the scoped draft and waits for backend persistence before re-enabling controls")
		view.viewId=2; view.busy=true; ui.receive(view); check(ui.filter_button.disabled,"A pending authoritative save cannot open conflicting filter input")
		view.viewId=3; view.busy=false; view.advancedFilters={"hideEmpty":true,"hideFull":false,"module":"Prelude"}; ui.receive(view); ui.open_filters()
		check(dialog.visible and dialog.buttons.havepeoplebox.button_pressed and dialog.edits.moduleedit.text=="Prelude","The committed backend view supplies subsequent dialog state")
		var point: Vector2=dialog.buttons.okbutton.get_global_rect().get_center(); await motion(point); await mouse(point,true); view.viewId=4; ui.receive(view); await mouse(point,false)
		check(not dialog.visible and requests.back().operation=="advanced-filter","A superseding view retires the draft and its held OK cannot submit stale values")
		ui.open_filters(); check(ui.escape() and not dialog.visible and ui.wanted,"Escape dismisses the filter instead of leaving the browser")
		ui.open_filters(); await click(dialog.buttons.xbutton.get_global_rect().get_center()); check(not dialog.visible and ui.wanted,"The original X shares the cancel path")
		ui.open_filters(); await click(dialog.buttons.okbutton.get_global_rect().get_center()); view.viewId=5; view.status="Filter storage refused"; ui.receive(view)
		check(ui.profile_dialog.external_notice and ui.profile_dialog.visible and ui.profile_dialog.notice_body.text==view.status and not ui.filter_pending,"Storage refusal appears through the original OK notice rather than implying success")
		await press(KEY_ENTER); check(ui.panel.visible and not ui.profile_dialog.visible and not ui.modal_shield.visible,"Acknowledging failure restores usable browser controls")
		ui.open_filters(); ui.reset(1); check(not dialog.visible and not ui.modal_shield.visible and not ui.wanted,"Session replacement retires the filter and all modal input")
	var window_state:={"focused":root.has_focus(),"unfocusable":root.unfocusable,"screen":root.current_screen,"primary":DisplayServer.get_primary_screen(),"mouse_mode":Input.mouse_mode}
	ui.close_native(); check(dialog.closed and dialog.assets.running.is_empty(),"Filter workers join before the shared native painter retires")
	ui.free(); painter.close(); painter.free(); text.close(); await process_frame; await process_frame
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"window":window_state,"publicConnections":0,"fullUiParity":false,"fullServerBrowserParity":false,"scope":"Original Filters GUI/model/font geometry and native modal draft/accept/cancel/stale/refusal lifecycle. Provider metadata filtering and persistence are verified separately; entire server browser, input limits, all scales/roles/audio and original-client visual comparison remain open."},"  ")+"\n"); file.close(); quit(0 if failures.is_empty() else 1)
