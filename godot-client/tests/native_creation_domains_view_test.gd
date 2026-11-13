extends "res://tests/native_portrait_chooser_test.gd"
const Domains=preload("res://systems/native_domains_chooser.gd")
func key_domain(code: int) -> void:
	for pressed in [true,false]:
		var event:=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=pressed;surface.push_input(event,true);await frames()
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has_all(["install","report"]) or FileAccess.file_exists(args.report):quit(2);return
	var catalog:=Catalog.new();check(catalog.mount_install(args.install),"Original Domain catalog mounts read-only")
	check(preload("res://systems/native_data/prepared_cache.gd").digest(catalog.get_resource("cg_domain",2047))=="c40606b4a168cba12c8aa11c5029882ef8cad909ced7d056b3eb148e34028216","Pinned original Domain GFF hierarchy")
	surface=SubViewport.new();surface.size=Vector2i(1200,800);surface.disable_3d=true;surface.render_target_update_mode=SubViewport.UPDATE_DISABLED;root.add_child(surface);surface.notify_mouse_entered()
	var painter:=Painter.new();var art:=HeadlessArt.new();var fonts:=HeadlessFonts.new();painter.art=art;painter.fonts=fonts;painter.add_child(art);painter.add_child(fonts);art.loaded.connect(painter.art_loaded);surface.add_child(painter)
	var captions=preload("res://systems/native_data/talk_text.gd").new();captions.base.open_file(str(args.install).path_join("lang/en/data/dialog.tlk"))
	var text=preload("res://systems/native_data/talk_text.gd").new();var model:={"ready":true,"entries":[],"recommended":[3,0]}
	for id in [0,2,3,5]:model.entries.append({"id":id,"title":9000+id,"description":9100+id,"name":"Server domain "+str(id),"icon":"id_fixture_"+str(id)});text.overrides[9000+id]="Server domain "+str(id);text.overrides[9100+id]="Server domain help "+str(id)
	text.overrides[6011]="Domain introduction";text.overrides[5985]="Choose two domains"
	var pane:=Domains.new();surface.add_child(pane);pane.position=Vector2(30,30);pane.configure(painter,captions,catalog,"");var results: Array=[];pane.finished.connect(func(accepted,selected,ticket):results.append([accepted,selected,ticket.duplicate()]));pane.set_context(model,true,text,art,[300,1]);pane.open();pane.start()
	var deadline:=Time.get_ticks_msec()+20000
	while not pane.layout_ready and pane.failure.is_empty() and Time.get_ticks_msec()<deadline:await process_frame
	check(pane.layout_ready and pane.failure.is_empty(),"Original Domain workers/model helpers prepare: "+pane.failure)
	var samples: Array=[]
	if pane.layout_ready and pane.failure.is_empty():
		await frames()
		check(pane.row_nodes.size()==4 and pane.help_title.text=="Domain introduction" and pane.buttons.okbutton.disabled,"Initial physical rows and original introductory help disable OK")
		var nodes: Dictionary={}
		for id in pane.row_nodes:nodes[id]=pane.row_nodes[id].get_instance_id()
		await click(pane.buttons["domain:2"]);check(pane.help_title.text=="Server domain 2" and pane.help_body.get_parsed_text()=="Server domain help 2" and pane.state.chosen.is_empty(),"Physical available-row click shows active help without choosing")
		await click(pane.buttons["domain:2:add"]);await click(pane.buttons["domain:0:add"])
		check(pane.state.chosen==[2,0] and not pane.buttons.okbutton.disabled and pane.row_nodes[2].get_parent()==pane.chosen_body,"Actual arrow controls move two choices to original selected-domain attachments")
		check(pane.buttons["domain:3:add"].disabled,"A third choice is disabled while two domains are selected")
		await click(pane.buttons["domain:2:remove"])
		check(pane.state.chosen==[0] and pane.state.available_ids==[2,3,5] and pane.row_nodes[2].get_parent()==pane.list_body and pane.buttons.okbutton.disabled,"Original remove shifts chosen slot2 and reinserts the physical domain in source order")
		check(nodes.keys().all(func(id):return nodes[id]==pane.row_nodes[id].get_instance_id()),"Moving choices reuses every row widget and icon binding")
		await click(pane.buttons.recommendbutton);check(pane.state.chosen==[3,0] and pane.help_title.text=="Server domain 3","Recommended preserves current package slot order and first-selected help")
		pane.capture("domain:5:add");pane.set_context(model,true,text,art,[300,2],true);pane.invoke("domain:5:add");check(pane.state.chosen==[3,0],"A reticket retires held input without altering retained candidates")
		pane.scale=Vector2(.6,.6);pane.position=Vector2(10,10);surface.size=Vector2i(640,480);await frames();await click(pane.buttons.okbutton)
		check(results==[[true,[3,0],[300,2]]] and not pane.wanted,"Scaled original OK returns exact physical domains and the active lifetime once")
		pane.set_context(model,false,text,art,[301,1]);pane.open();await frames();check(pane.buttons.recommendbutton.disabled,"Active rules disable the original Recommended control")
		await key_domain(KEY_ESCAPE);check(results[-1]==[false,[],[301,1]],"Domain Escape retires its own source lifetime")
		pane.set_context(model,true,text,art,[302,1]);pane.open();await frames()
		var spare:=painter.create_button({"resource":"ctl_cg_btn_right","rect":pane.plan.row.bounds,"offset":Vector2.ZERO,"caption":{}},pane,pane.models);spare.hide();var spare_id:=spare.get_instance_id()
		pane.row_nodes[0].tree_exiting.connect(func():spare.free(),CONNECT_ONE_SHOT)
		for turn in 12:
			pane.state.select_available(0);var began:=Time.get_ticks_usec();pane.capture("domain:0:add");pane.invoke("domain:0:add");pane.capture("domain:0:remove");pane.invoke("domain:0:remove");samples.append((Time.get_ticks_usec()-began)/1000.0)
		check(samples.max()<50.0,"Actual unchanged-resource add/remove handler pair avoids an obnoxious stall: "+str(samples))
		check(not painter.button_geometry.has(spare_id) and pane.buttons.keys().all(func(tag):return painter.button_geometry.has(pane.buttons[tag].get_instance_id())) and painter.relocating_buttons.is_empty(),"Row and nested arrow painter leases survive relocation while an unrelated exiting control retires normally")
		var damaged: Dictionary=pane.models.duplicate();damaged.erase("ctl_cg_btn_dom");check(not str(preload("res://systems/native_data/creation_domains_layout.gd").parse(pane.source,damaged).error).is_empty(),"Missing original domain row helper fails explicitly")
	pane.close();check(art.bindings.values().all(func(name):return not str(name).begins_with("id_fixture_")),"Close retires every active domain icon binding");pane.free();check(painter.button_geometry.is_empty() and painter.decorated.is_empty(),"Final deletion retires the reused controls and their nested painter metadata");painter.free();surface.queue_free();await frames(6)
	var file:=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"handlerPairMs":samples,"scope":"Actual installed Domain controls with active custom help/icons, physical add/remove/recommend/OK/Escape, row reuse, reticket/scaling and synchronous handler samples. Controlled art/fonts; no original pixels, creator/draft/server/upload or full original table-loader acceptance.","gpu":false,"serverConnections":0},"\t"));file.close();quit(0 if failures.is_empty() else 1)
