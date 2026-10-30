extends "res://tests/native_quickbar_frame_test.gd"
const Browser=preload("res://systems/server_browser.gd")
const Painter=preload("res://systems/native_gui_painter.gd")
const DialogPlan=preload("res://systems/native_data/connection_dialog_layout.gd")
func press(code: Key) -> void:
	await key(code,true); await key(code,false)
func capture(output: String,painter) -> void:
	if DisplayServer.get_name()=="headless": return
	check(await wait_until(func():return painter.art.waiting.is_empty() and painter.art.models.pending.is_empty() and not painter.art.models.active and painter.fonts.pending.is_empty()),"Direct Connect artwork/fonts complete before visual capture")
	await RenderingServer.frame_post_draw
	check(surface.get_texture().get_image().save_png(output.trim_suffix(".json")+"-direct.png")==OK,"Original Direct Connect native viewport saved")
func run() -> void:
	var output:=""; var install:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
		if arg.begins_with("--install="): install=arg.substr(10)
	if output.is_empty() or install.is_empty() or FileAccess.file_exists(output): quit(2); return
	root.size=Vector2i(1200,850); surface=SubViewport.new(); surface.size=root.size; surface.render_target_update_mode=SubViewport.UPDATE_ALWAYS; surface.gui_disable_input=false; surface.handle_input_locally=true; root.add_child(surface); surface.notify_mouse_entered()
	var catalog:=Catalog.new(); check(catalog.mount_install(install),"Original Direct Connect resources mount read-only")
	var text=preload("res://systems/native_data/talk_text.gd").new(); check(text.base.open_file(install.path_join("lang/en/data/dialog.tlk")),"Original dialog text opens without server tables")
	var painter:=Painter.new(); surface.add_child(painter); painter.configure_source(catalog,ProjectSettings.globalize_path("user://native-prepared-v2"))
	var ui:=Browser.new(); surface.add_child(ui); ui.request.connect(func(message):requests.append(message.duplicate(true)))
	ui.configure_native(painter,text,catalog,ProjectSettings.globalize_path("user://native-prepared-v2"))
	var dialog=ui.direct_dialog
	check(await wait_until(func():return dialog.layout_ready or not dialog.failure.is_empty()),"Original Direct Connect GUI/model preparation terminates")
	check(dialog.failure.is_empty() and dialog.layout_ready,"Source Direct Connect frame and every required control prepare: "+dialog.failure)
	if dialog.layout_ready:
		var entries: Dictionary=dialog.definition.entries
		check(entries.size()==8 and dialog.buttons.size()==3 and dialog.edits.size()==2 and dialog.labels.size()==3,"All eight original Direct Connect controls are retained")
		check(dialog.labels.tguilabel.text=="Server IP Address" and dialog.labels.tguilabel2.text=="Direct Connect" and dialog.labels.passwordlabel.text=="Player Password:","Source caption references resolve from installed TLK")
		check(entries.okbutton.callback=="0x1408d1000" and entries.cancelbutton.callback==entries.xbutton.callback,"Original confirmation and shared Cancel/X callbacks stay paired with source buttons")
		check(dialog.edits.ipeditbox.position.is_equal_approx(entries.ipeditbox.text_rect.position) and dialog.edits.ipeditbox.size.x>=entries.ipeditbox.text_rect.size.x-0.01,"Address editor uses original text hooks, not a generic row")
		var mutated: Dictionary=dialog.source.duplicate(true)
		for child in mutated.Obj_ChildList:
			if str(child.Obj_Tag).to_lower()=="ipeditbox": child.Obj_X+=0.25
		var moved:=DialogPlan.parse(mutated,dialog.models)
		check(str(moved.error).is_empty() and moved.entries.ipeditbox.text_rect.position.distance_to(entries.ipeditbox.text_rect.position+Vector2(25,0))<0.001,"Catalog-supplied GUI edit placement controls native input geometry")
		mutated=dialog.source.duplicate(true); mutated.Obj_ChildList.pop_front()
		check(not str(DialogPlan.parse(mutated,dialog.models).error).is_empty(),"Missing original controls fail explicitly before displaying a partial source dialog")
		ui.open()
		var view:={"kind":"browser-view","connection":0,"viewId":1,"tab":"Direct","direct":{"host":"127.0.0.1","port":5125,"name":"Dialog Tester"},"canJoin":true,"localOnly":true,"hasSavedCdKey":true,"page":0,"pages":1,"rows":[],"busy":false}
		ui.receive(view); await process_frame
		ui.password_edit.text="transient password"; ui.key_edit.text="transient key"
		await click(ui.connect_button.get_global_rect().get_center())
		check(dialog.visible and not ui.panel.visible and requests.back().operation=="open","Actual browser Connect opens original dialog without sending a network join")
		check(dialog.edits.ipeditbox.text=="127.0.0.1:5125" and dialog.edits.passwordeditbox.text=="transient password" and ui.password_edit.text.is_empty(),"Dialog takes the current endpoint/password draft and clears the old password editor")
		check(surface.gui_get_focus_owner()==dialog.edits.ipeditbox,"Opening focuses the original address field without moving the physical pointer")
		await capture(output,painter)
		await click(dialog.buttons.cancelbutton.get_global_rect().get_center())
		check(not dialog.visible and ui.panel.visible and dialog.edits.passwordeditbox.text.is_empty() and requests.back().operation=="open","Original Cancel returns to browser, discards password and never connects")
		ui.open_direct(); await process_frame
		await click(dialog.buttons.xbutton.get_global_rect().get_center())
		check(not dialog.visible and ui.panel.visible and requests.back().operation=="open","Original X uses the same no-connect dismissal as Cancel")
		ui.open_direct(); await process_frame; var point: Vector2=dialog.buttons.okbutton.get_global_rect().get_center(); await motion(point); await mouse(point,true)
		dialog.dismiss(); ui.panel.show(); ui.open_direct(); await mouse(point,false)
		check(dialog.visible and requests.back().operation=="open","A held confirmation cannot act on a reopened dialog presentation")
		await click(dialog.buttons.cancelbutton.get_global_rect().get_center())
		check(ui.panel.visible and not dialog.visible,"A fresh Cancel remains usable after a retired held confirmation")
		ui.open_direct(); await process_frame; dialog.edits.passwordeditbox.text="send once"
		await press(KEY_ENTER)
		check(requests.back().operation=="join" and requests.back().direct and requests.back().values.host=="127.0.0.1" and requests.back().values.port==5125 and requests.back().values.name=="Dialog Tester","Address Enter issues the canonical current-view direct join with current player identity")
		var sent_values: Dictionary=requests.back().get("values",{})
		check(sent_values.get("password")=="send once" and sent_values.get("cdKey")=="transient key" and requests.back().get("viewId")==1,"Confirmation forwards transient credentials only through the existing scoped connection request")
		check(not dialog.visible and dialog.edits.passwordeditbox.text.is_empty() and ui.key_edit.text.is_empty() and ui.connect_button.disabled,"Sending clears credential editors and disables duplicate submission")
		var count:=requests.size(); dialog.invoke("okbutton"); ui.confirm_direct("127.0.0.1:5125","stale",[0,0])
		check(requests.size()==count,"Hidden duplicate confirmation and stale view cannot send another login")
		view.viewId=2; view.reopen=true; view.status="Authoritative rejection"; ui.receive(view); ui.open_direct(); await process_frame
		check(ui.escape() and ui.panel.visible and not dialog.visible and ui.status.text=="Authoritative rejection","Escape returns from native dialog without closing its current retry browser")
		ui.open_direct(); await process_frame; dialog.edits.passwordeditbox.text="retire"
		view.viewId=3; ui.receive(view)
		check(not dialog.visible and dialog.edits.passwordeditbox.text.is_empty() and ui.panel.visible,"An advanced backend view retires the stale native dialog and clears its password")
		view.viewId=4; view.busy=true; ui.receive(view); ui.open_direct()
		check(not dialog.visible and ui.direct_button.disabled and ui.connect_button.disabled,"A pending backend operation disables both Direct Connect entry paths")
		view.viewId=5; view.busy=false; view.canJoin=false; ui.receive(view); ui.open_direct()
		check(not dialog.visible and ui.direct_button.disabled,"Current admission capability gates the native dialog")
		view.viewId=6; view.canJoin=true; view.tab="Favorites"; ui.receive(view); await process_frame
		await click(ui.direct_button.get_global_rect().get_center())
		check(dialog.visible and ui.selected==-1,"Direct Connect is usable from a saved-server page without selecting a list row")
		await click(dialog.buttons.cancelbutton.get_global_rect().get_center())
		ui.open_direct(); await process_frame; ui.reset(1)
		check(not dialog.visible and not ui.panel.visible and not ui.wanted,"Session replacement retires browser and dialog together")
		for row in [["127.0.0.1",5121],["127.0.0.1:5125",5125],["owned.invalid:  +5125trailing",5125],["owned.invalid:0",5121],["owned.invalid:65537",1]]:
			check(DialogPlan.endpoint(row[0]).port==row[1],"Original connection-constructor decimal/default/16-bit port rule: "+row[0])
	var source_hashes: Dictionary={"directconnect":FileAccess.get_sha256(ProjectSettings.globalize_path("res://../backups/animations/rea-native-connection-dialogs-v1.json"))}
	source_hashes.gui=preload("res://systems/native_data/prepared_cache.gd").digest(catalog.get_resource("directconnect",2047))
	for name in dialog.models: source_hashes[name]=preload("res://systems/native_data/prepared_cache.gd").digest(catalog.get_resource(name,2002))
	var diagnostic: Dictionary=dialog.snapshot(); ui.close_native()
	check(dialog.closed and dialog.assets.running.is_empty() and dialog.jobs.is_empty(),"Dialog resource workers join before the shared pregame painter retires")
	ui.free(); painter.close(); painter.free(); text.close(); await process_frame; await process_frame
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"dialog":diagnostic,"sourceSha256":source_hashes,"publicConnections":0,"physicalMouseWarped":false,"authoritativeServerCheck":false,"visualAccepted":false,"fullConnectionUiParity":false,"scope":"Original installed Direct Connect layout, actual native pointer/key dispatch, canonical browser request and lifecycle checks. Full original browser/profile/CD-key/password/connection/selection surfaces, live local server and visual acceptance remain required."},"  ")+"\n"); file.close(); quit(0 if failures.is_empty() else 1)
