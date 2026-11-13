extends "res://tests/native_portrait_chooser_test.gd"
const Associate=preload("res://systems/native_associate_chooser.gd")
class PortraitArt extends HeadlessArt:
	func bind_portrait(target: Object,resource: String) -> void:bind(target,resource)
func associate_model(count: int=1024,name: String="Owned name") -> Dictionary:
	var entries: Array=[]
	for index in count:entries.append({"id":index*2,"title":index+1,"name":"Associate %04d"%index,"base":"serverpet_","description":10000+index})
	return {"choices":{"ready":true,"entries":entries,"arcane":2,"level":3},"storedType":0,"name":name}
func wait_associate(predicate: Callable) -> bool:
	var deadline:=Time.get_ticks_msec()+20000
	while Time.get_ticks_msec()<deadline:
		if predicate.call():return true
		await process_frame
	return false
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has_all(["install","report"]) or FileAccess.file_exists(args.report):quit(2);return
	var catalog:=Catalog.new();check(catalog.mount_install(args.install),"Read-only original catalog")
	surface=SubViewport.new();surface.size=Vector2i(1200,800);surface.disable_3d=true;surface.render_target_update_mode=SubViewport.UPDATE_DISABLED;root.add_child(surface);surface.notify_mouse_entered()
	var painter:=Painter.new();var art:=PortraitArt.new();var fonts:=HeadlessFonts.new();painter.art=art;painter.fonts=fonts;painter.add_child(art);painter.add_child(fonts);art.loaded.connect(painter.art_loaded);surface.add_child(painter)
	var captions=preload("res://systems/native_data/talk_text.gd").new();check(captions.base.open_file(str(args.install).path_join("lang/en/data/dialog.tlk")),"Original caption TLK")
	var text=preload("res://systems/native_data/talk_text.gd").new();text.overrides[10000]="Server-specific associate description"
	var pane:=Associate.new();surface.add_child(pane);pane.position=Vector2(20,20);pane.configure(painter,captions,catalog,"")
	var actions: Array=[];var results: Array=[];var samples: Array=[]
	pane.action_requested.connect(func(operation,value,ticket):actions.append([operation,value.duplicate(true),ticket.duplicate()]))
	pane.finished.connect(func(accepted,value,ticket):results.append([accepted,value.duplicate(true),ticket.duplicate()]))
	pane.set_context(associate_model(),text,art,[400,1]);pane.open();pane.start()
	check(await wait_associate(func():return pane.layout_ready or not pane.failure.is_empty()) and pane.layout_ready and pane.failure.is_empty(),"Original Familiar, controls,420px mode-zero sheet and all model workers prepare: "+pane.failure)
	var pool_count:=0
	if pane.layout_ready and pane.failure.is_empty():
		await frames();pool_count=pane.rows.size()
		check(pool_count<20 and pane.state.entries.size()==1024 and pane.rows[0].label.text=="Associate 0000","1024 custom rows use a bounded original-control pool")
		check(pane.summary_view.size.y==420 and pane.summary_view.position==pane.plan.summary_origin,"Original private summary height and attachment")
		check(pane.name_edit.text=="Owned name" and not pane.buttons.okbutton.disabled,"Existing name and selected visible row enable original OK")
		await click(pane.buttons["row:1"]);check(pane.state.selected==1 and actions[-1][0]=="preview" and actions[-1][1].resource=="serverpet_03" and actions[-1][1].physicalId==2,"Actual row click selects physical ID and requests exact level-suffixed UTC")
		var selection:=pane.preview_serial
		check(not pane.present_preview({"ready":true,"labels":{"title":{"text":"STALE"}}},[400,1],selection-1),"Retired selection cannot publish a private preview")
		check(pane.present_preview({"ready":true,"labels":{"title":{"text":"Private associate"},"strstat":{"text":"12"}},"portrait":"owned_portrait_","lists":{}},[400,1],selection),"Current detached template projection reaches existing summary owner")
		check(pane.summary_view.labels.title.text=="Private associate" and pane.summary_view.labels.strstat.text=="12","Summary displays supplied template data")
		await click(pane.summary_view.tabs[1]);check(pane.summary_view.pages[1].visible,"Physical summary tab uses the current private selection")
		pane.rows[0].helper.show();await click(pane.rows[0].helper)
		check(await wait_associate(func():return pane.info_popup.layout_ready or not pane.info_popup.failure.is_empty()) and pane.info_popup.layout_ready and pane.info_popup.failure.is_empty(),"Distinct original OKSCROLLPANEL prepares: "+pane.info_popup.failure)
		if pane.info_popup.layout_ready:
			await frames();check(pane.modal_active and pane.state.selected==0 and pane.info_popup.description.get_parsed_text()=="Server-specific associate description","Help selects its row first and uses the active description in original read-only owner")
			var before:=actions.size();await click(pane.buttons["row:1"]);check(actions.size()==before and pane.state.selected==0,"Actual help modal blocks underlying selections")
			await click(pane.info_popup.buttons.okbutton);check(not pane.modal_active and not pane.info_popup.wanted,"Actual help OK restores parent")
		var nodes: Array=pane.rows.map(func(cell):return cell.button.get_instance_id());var previous:=pane.state.selected
		await mouse(pane.buttons["row:1"],true);pane.list.scroll_vertical=2200;await frames();await mouse(pane.buttons["row:1"],false);await frames()
		check(pane.state.selected==previous and pane.rows[1].id!=2,"Scrolling a held pooled row cannot commit a replacement entity")
		check(nodes==pane.rows.map(func(cell):return cell.button.get_instance_id()),"Scroll retains original row/helper instances")
		pane.list.scroll_vertical=0;await frames()
		for index in 12:
			var began:=Time.get_ticks_usec();pane.capture("row:1");pane.invoke("row:1");samples.append((Time.get_ticks_usec()-began)/1000.0)
		check(samples.max()<50.0,"1024-entry row handlers avoid an obnoxious synchronous stall: "+str(samples))
		pane.name_edit.text="Typed name";pane.name_edit.text_changed.emit("Typed name");check(pane.state.current_name=="Typed name" and actions[-1][0]=="name","Actual edit callback supplies current scoped draft name")
		await click(pane.buttons.gennamebutton);var revision:=pane.name_revision
		check(pane.generating and pane.buttons.okbutton.disabled and not pane.buttons.cancelbutton.disabled,"Native name request keeps Cancel available")
		check(not pane.name_result({"ready":true,"name":"Wrong lifetime"},[400,2],revision),"Old lifetime name completion is rejected")
		check(pane.name_result({"ready":true,"name":"Generated name"},[400,1],revision) and pane.name_edit.text=="Generated name","Only current generator completion updates the edit")
		await click(pane.buttons.gennamebutton);revision=pane.name_revision;pane.name_edit.text_changed.emit("Newer user edit")
		check(not pane.name_result({"ready":true,"name":"Late generator"},[400,1],revision) and pane.state.current_name=="Newer user edit","Typing supersedes an outstanding name request")
		await click(pane.buttons.okbutton);check(results.size()==1 and results[0][0] and results[0][1].field=="familiar" and results[0][1].id==2 and results[0][1].name=="Newer user edit" and results[0][2]==[400,1],"Original OK returns raw-Arcane storage branch, physical ID, name and scope")
		pane.set_context(associate_model(2),text,art,[400,2]);pane.open();await frames();await mouse(pane.buttons.okbutton,true);pane.set_context(associate_model(1),text,art,[400,3]);await frames();await mouse(pane.buttons.okbutton,false);await frames()
		check(results.size()==1,"OK held across replacement cannot finish next draft")
		await click(pane.buttons.cancelbutton);check(results.size()==2 and not results[-1][0] and results[-1][2]==[400,3],"Physical Cancel returns only active lifetime")
		pane.set_context(associate_model(1,""),text,art,[401,1]);pane.open();await frames();await click(pane.buttons.okbutton)
		if not pane.generating:pane.request_name(true)
		revision=pane.name_revision;check(pane.generating,"Empty name requests native generator")
		pane.name_result({"ready":false,"reason":"Missing active LTR"},[401,1],revision,true);check(results.size()==2 and pane.state.current_name.is_empty(),"Missing name data does not invent a default or accept")
		pane.request_name(true);revision=pane.name_revision;pane.name_result({"ready":true,"name":"Owned native name"},[401,1],revision,true)
		check(results.size()==3 and results[-1][0] and results[-1][1].name=="Owned native name","Empty-name OK completes only after exact generation request")
	pane.close();pane.free();check(painter.button_geometry.is_empty(),"Close and deletion retire summary, pooled rows and helpers metadata");painter.free();surface.queue_free();await frames(6)
	var file:=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"handlerMs":samples,"pooledRows":pool_count,"scope":"Installed CG_FAMILIAR/OKSCROLLPANEL/model controls and existing420px mode-zero private summary; physical row/help/edit/tab/OK/Cancel,1024-row pool, detached preview/name results, scope and cleanup. Controlled art/fonts; generator/template callbacks supplied by fixture. No actual creator/BIC/save/server/original-pixel/level-up acceptance.","gpu":false,"serverConnections":0},"\t"));file.close();quit(0 if failures.is_empty() else 1)
