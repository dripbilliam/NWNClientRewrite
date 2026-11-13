extends "res://tests/native_portrait_chooser_test.gd"
const Feats=preload("res://systems/native_feats_chooser.gd")
const FeatLayout=preload("res://systems/native_data/creation_feats_layout.gd")
func wait_ready(predicate: Callable,seconds: int=60) -> bool:
	var until:=Time.get_ticks_msec()+seconds*1000
	while Time.get_ticks_msec()<until:
		if predicate.call():return true
		await process_frame
	return false
func key(code: int) -> void:
	for pressed in [true,false]:
		var event:=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=pressed;surface.push_input(event,true);await frames()
func choices_model() -> Dictionary:
	return {"ready":true,"remaining":2,"canAccept":false,"available":[{"id":51,"name":"Server Feat A","description":"Server-authored description","icon":"if_powerattack"},{"id":2,"name":"Server Family...","description":"Server family help","icon":"if_powerattack","children":[{"id":72,"name":"Server Child B"},{"id":73,"name":"Server Child C"}]}],"known":[{"id":41,"name":"Server Granted Feat","description":"Granted help","icon":"if_powerattack","enabled":false},{"id":42,"name":"Server Chosen Feat","description":"Chosen help","icon":"if_powerattack","enabled":true}]}
func run() -> void:
	create_timer(100).timeout.connect(func():push_error("Feats view test exceeded its bounded lifetime");quit(3))
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has_all(["report","install"]) or FileAccess.file_exists(args.report):quit(2);return
	var catalog:=Catalog.new();check(catalog.mount_install(args.install),"Original source artwork catalog mounts read-only")
	check(preload("res://systems/native_data/prepared_cache.gd").digest(catalog.get_resource("cg_feats",2047))=="f4a92261e5c2a896b0b9e23ade710fe113cb157df27c16bc7bc5edcf2a2ea09a","Original Feats GUI hierarchy is pinned")
	check(preload("res://systems/native_data/prepared_cache.gd").digest(catalog.get_resource("cg_feats_popup",2047))=="ff319e5d9d69beff70242e6dcd8c705092cd13bd0d1ac2c480dc0b959ebc3385","Original family picker GUI hierarchy is pinned")
	check(preload("res://systems/native_data/prepared_cache.gd").digest(catalog.get_resource("cg_spellinfo",2047))=="b00b06eaf0f5e07f6fd91c709b3c2aa3c27a10686b334c4cae52504e23ddaecb","Original distinct information popup resource is pinned")
	surface=SubViewport.new();surface.size=Vector2i(1100,800);surface.render_target_update_mode=SubViewport.UPDATE_DISABLED;surface.disable_3d=true;root.add_child(surface);surface.notify_mouse_entered()
	var painter:=Painter.new();var art:=HeadlessArt.new();var fonts:=HeadlessFonts.new();painter.art=art;painter.fonts=fonts;painter.add_child(art);painter.add_child(fonts);art.loaded.connect(painter.art_loaded);surface.add_child(painter)
	var text:=preload("res://systems/native_data/talk_text.gd").new();check(text.base.open_file(args.install.path_join("lang/en/data/dialog.tlk")),"Source captions use the original pregame TLK")
	var pane:=Feats.new();surface.add_child(pane);pane.position=Vector2(80,80);pane.configure(painter,text,catalog,"");var actions: Array=[];var finishes: Array=[]
	pane.action_requested.connect(func(operation,id,ticket):actions.append({"operation":operation,"id":id,"ticket":ticket.duplicate()}));pane.finished.connect(func(accepted,ticket):finishes.append([accepted,ticket.duplicate()]))
	pane.start()
	var prepared:=await wait_ready(func():return pane.layout_ready and pane.info_popup.layout_ready and pane.group_popup.layout_ready)
	check(prepared,"Actual Feats, family and information resource layouts prepare: "+JSON.stringify({"main":pane.failure,"info":pane.info_popup.failure,"group":pane.group_popup.failure}))
	if prepared:
		var model:=choices_model();var scope: Array=[81,3];pane.set_context(model,true,text,art,scope);pane.open();await frames()
		check(pane.plan.size.is_equal_approx(Vector2(742,526)) and pane.rows.available.size()==2 and pane.rows.known.size()==2 and pane.remaining.text=="2","Original frame and two source lists present the supplied active model")
		check(pane.buttons.okbutton.disabled and pane.buttons["known:0:arrow"].disabled and not pane.buttons["known:1:arrow"].disabled,"Remaining choices and granted/selectable state control actual actions")
		check(pane.plan.entries.okbutton.callback=="0x1409c8a90" and pane.info_popup.resource=="cg_spellinfo" and pane.group_popup.resource=="cg_feats_popup","Original callback identities and separate popup ownership are retained")
		await click(pane.buttons["available:0"]);check(pane.selected.available==0 and actions.is_empty(),"Physical row selection alone does not add a feat")
		check(pane.buttons["available:0:info"].visible,"Hovering the source row exposes its attached information child")
		await click(pane.buttons["available:0:arrow"]);check(actions.size()==1 and actions[-1]=={"operation":"add","id":51,"ticket":scope},"Physical original add arrow emits its physical feat ID and current ownership scope")
		await click(pane.buttons["known:1:arrow"]);check(actions.size()==2 and actions[-1].operation=="remove" and actions[-1].id==42 and pane.selected.known==1,"Physical remove arrow selects its known row and emits its physical ID")
		await click(pane.buttons["known:0:arrow"]);check(actions.size()==2,"Granted rows cannot remove their feat through a disabled source arrow")
		await click(pane.buttons["available:0"]);await click(pane.buttons["available:0:info"])
		check(pane.modal_active and pane.info_popup.wanted and pane.info_popup.title.text=="Server Feat A" and pane.info_popup.description.get_parsed_text()=="Server-authored description" and pane.buttons.cancelbutton.disabled,"Actual information child displays active text and blocks underlying Feats input")
		await click(pane.info_popup.buttons.closebutton);check(not pane.modal_active and not pane.info_popup.wanted and actions.size()==2,"Information Close returns without changing feat choices")
		if pane.modal_active:print("POPUP_CLOSE_STATE ",JSON.stringify({"revision":pane.revision,"scope":pane.scope,"popupScope":pane.info_popup.scope,"disabled":pane.info_popup.buttons.closebutton.disabled,"held":pane.info_popup.held,"buttonRect":str(pane.info_popup.buttons.closebutton.get_global_rect())}))
		await click(pane.buttons["available:1:arrow"]);check(pane.modal_active and pane.group_popup.wanted and pane.group_popup.selected==-1 and pane.group_popup.buttons.okbutton.disabled,"A multi-child family requires an explicit original popup selection")
		if pane.group_popup.row_buttons.size()>1:await click(pane.group_popup.row_buttons[1])
		check(pane.group_popup.selected==1 and not pane.group_popup.buttons.okbutton.disabled,"Physical family row enables the original OK action")
		await click(pane.group_popup.buttons.okbutton);check(actions.size()==3 and actions[-1].operation=="add" and actions[-1].id==73 and not pane.modal_active,"Family OK returns the selected physical child to the active owner")
		await click(pane.buttons["available:1:arrow"]);await key(KEY_ESCAPE);check(not pane.modal_active and actions.size()==3 and finishes.is_empty(),"Popup Escape cancels only its own selection")
		model.available[1].children=[{"id":91,"name":"One server child"}];pane.update_model(model);await click(pane.buttons["available:1:arrow"]);check(pane.group_popup.selected==0 and not pane.group_popup.buttons.okbutton.disabled,"A one-child family starts with its sole original choice selected")
		await click(pane.group_popup.buttons.cancelbutton);check(actions.size()==3 and not pane.modal_active,"Family Cancel emits no add action")
		await click(pane.buttons.recommendbutton);await click(pane.buttons.resetbutton);check(actions.slice(-2).map(func(entry):return entry.operation)==["recommend","reset"],"Original Recommended and Reset delegate meaningful scoped operations to the owner")
		pane.set_context(model,false,text,art,scope);await click(pane.buttons.recommendbutton);check(actions.size()==5 and pane.buttons.recommendbutton.disabled,"The active recommended setting disables source input")
		pane.set_context(model,true,text,art,scope);await click(pane.buttons["available:1:arrow"]);var stale: Array=pane.group_popup.scope.duplicate();pane.update_model({"ready":false});pane.popup_result(true,91,stale,false);check(not pane.modal_active and pane.rows.available.is_empty() and pane.rows.known.is_empty() and pane.remaining.text.is_empty() and pane.buttons.cancelbutton.disabled and actions.size()==5,"Dependency loss retires the open popup, stale child result, lists, text and actions")
		pane.set_context(model,true,text,art,[81,4]);pane.capture("available:0:arrow");pane.set_context(model,true,text,art,[82,1]);pane.invoke("available:0:arrow");check(actions.size()==5,"Held input cannot cross replacement data/connection ownership")
		pane.set_busy(true);await click(pane.buttons.resetbutton);check(actions.size()==5 and pane.buttons.resetbutton.disabled,"Pending owner work prevents duplicate changes")
		pane.set_busy(false);model.canAccept=true;model.remaining=0;pane.update_model(model);await click(pane.buttons.okbutton);check(finishes==[[true,[82,1]]] and not pane.wanted,"Original OK emits an accepted scoped result when the owner allows it")
		pane.set_context(model,true,text,art,[83,1]);pane.open();pane.scale=Vector2(.65,.65);pane.position=Vector2(10,10);surface.size=Vector2i(640,400);await frames();await click(pane.buttons["available:0:arrow"]);check(actions.size()==6 and actions[-1].id==51 and actions[-1].ticket==[83,1],"Original source helper hit regions remain aligned under viewport scaling")
		await key(KEY_ESCAPE);check(finishes[-1]==[false,[83,1]] and not pane.wanted,"Main Feats Escape cancels through its own scoped result")
		var missing: Dictionary=pane.models.duplicate();missing.erase("ctl_cg_btn_help");check(not str(FeatLayout.parse(pane.source,missing).error).is_empty(),"Missing source helpers fail layout preparation instead of inventing replacement controls")
	pane.close();pane.free();painter.free();surface.queue_free();await frames(6)
	var file:=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"publicConnections":0,"graphical":false,"sourceArtworkDouble":true,"scope":"Original CG_FEATS/family/info resources and physical view input, popup lifecycle, disabled states, scaling and retirement with supplied active-model fixtures. No live draft binding, prerequisite/recommendation rule parity, source creator/server outcome or original pixels accepted."},"\t"));file.close();quit(0 if failures.is_empty() else 1)
