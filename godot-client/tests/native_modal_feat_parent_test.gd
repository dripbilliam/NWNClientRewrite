extends "res://tests/native_modal_owner_input_test.gd"
const Feats=preload("res://systems/native_feats_chooser.gd")
const Order=preload("res://systems/native_data/modal_order.gd")
const Surfaces=preload("res://systems/native_modal_surfaces.gd")
func model() -> Dictionary:
	return {"ready":true,"remaining":1,"canAccept":false,"available":[{"id":51,"name":"Authored feat","description":"Received help","icon":"if_powerattack"},{"id":2,"name":"Authored family","children":[{"id":72,"name":"First child"},{"id":73,"name":"Second child"}]}],"known":[]}
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has_all(["report","install"]) or FileAccess.file_exists(args.report):quit(2);return
	var catalog:=Catalog.new();check(catalog.mount_install(args.install),"Actual installed Feats and leaf resources mount read-only")
	var surface:=SubViewport.new();surface.size=Vector2i(1100,800);surface.disable_3d=true;surface.gui_disable_input=false;surface.handle_input_locally=true;surface.render_target_update_mode=SubViewport.UPDATE_DISABLED;root.add_child(surface);surface.notify_mouse_entered()
	var painter:=Painter.new();painter.art=SourceFixture.ControlledArt.new();painter.fonts=ReadyFonts.new();painter.add_child(painter.art);painter.add_child(painter.fonts);surface.add_child(painter)
	var text=preload("res://systems/native_data/talk_text.gd").new();check(text.base.open_file(str(args.install).path_join("lang/en/data/dialog.tlk")),"Actual installed TLK supplies source captions")
	var order:=Order.new();var surfaces:=Surfaces.new();surface.add_child(surfaces);surfaces.configure(order)
	var canvas:=CanvasLayer.new();canvas.layer=40;surface.add_child(canvas)
	var pane:=Feats.new();canvas.add_child(pane);pane.position=Vector2(80,80);pane.configure(painter,text,catalog,str(args.report)+".cache")
	for popup in [pane.info_popup,pane.group_popup]:popup.set_modal_order(order);surfaces.bind_layer(popup,canvas)
	var actions: Array=[];var reopen: Array=[false];pane.action_requested.connect(func(operation,id,ticket):
		actions.append({"operation":operation,"id":id,"scope":ticket.duplicate()})
		if reopen[0]:reopen[0]=false;pane.show_info(model().available[0]))
	pane.start();var loaded:=check(await ready(pane) and await ready(pane.info_popup) and await ready(pane.group_popup),"Actual parent, information and group original geometry prepare")
	var trace: Dictionary={}
	if loaded:
		pane.set_context(model(),true,text,painter.art,[81,3]);pane.open();await frames()
		await click(surface,pane.buttons["available:0"]);await click(surface,pane.buttons["available:0:info"])
		check(pane.modal_active and pane.info_popup.wanted,"Physical parent information action opens the existing leaf")
		await click(surface,pane.info_popup.buttons.closebutton)
		check(not pane.modal_active and not pane.info_popup.wanted,"Unbound-parent baseline accepts its current physical child Close")
		# Explicit fixture opt-in isolates the parent/child request correction;
		# creator factory integration receives its own subsequent assertion.
		pane.set_modal_owner(order,"other");surfaces.bind_layer(pane,canvas)
		var parent_ticket: Dictionary=pane.modal_owner_ticket.duplicate(true)
		check(not parent_ticket.is_empty() and order.admits(parent_ticket),"Explicit proposed parent opt-in registers only actual displayed CG_FEATS")
		await click(surface,pane.buttons["available:0"]);await click(surface,pane.buttons["available:0:info"])
		trace={"parentRevision":pane.revision,"parentScope":pane.scope.duplicate(),"popupScope":pane.info_popup.scope.duplicate(),"parentTicket":parent_ticket.duplicate(true),"popupTicket":pane.info_popup.modal_owner_ticket.duplicate(true)}
		check(pane.modal_active and pane.info_popup.wanted and pane.info_popup.available() and not pane.available(),"Admitted child masks the actual lower parent without suppressing retirement")
		await click(surface,pane.info_popup.buttons.closebutton)
		check(not pane.modal_active and not pane.info_popup.wanted and order.admits(parent_ticket),"Current physical information Close must return to its still-live parent request")
		# Explicit model boundary clears any rejected diagnostic child before the
		# independent group check; retain both failure context and all assertions.
		pane.update_model(model());await frames();pane.show_group(model().available[1].children);await frames()
		await click(surface,pane.group_popup.row_buttons[1]);await click(surface,pane.group_popup.buttons.okbutton)
		check(actions.size()==1 and actions[0]=={"operation":"add","id":73,"scope":[81,3]} and not pane.modal_active,"Current physical family OK must return the selected exact child through parent admission loss")
		var unchanged_parent: Dictionary=pane.modal_owner_ticket.duplicate(true);pane.set_context(model(),true,text,painter.art,[81,3]);pane.open();await frames()
		check(pane.modal_owner_ticket==unchanged_parent,"Same-scope data refresh and repeated open preserve parent lifetime")
		await pointer(surface,pane.buttons["available:0:arrow"],true);pane.show_info(model().available[0]);await click(surface,pane.info_popup.buttons.closebutton);await pointer(surface,pane.buttons["available:0:arrow"],false)
		check(actions.size()==1 and pane.held.is_empty(),"Legitimate admission-loss retirement still rejects a held parent action across its child")
		reopen[0]=true;pane.show_group(model().available[1].children);var retired_group: Array=pane.group_popup.scope.duplicate();await frames();await click(surface,pane.group_popup.row_buttons[1]);await click(surface,pane.group_popup.buttons.okbutton)
		check(actions.size()==2 and pane.modal_active and pane.info_popup.wanted and pane.popup_identity==pane.info_popup.scope and pane.popup_identity!=retired_group,"Synchronous result callback may open a new exact child without old completion clearing it")
		var current_info: Array=pane.info_popup.scope.duplicate();pane.popup_result(true,72,retired_group,false);pane.popup_result(true,72,current_info,false)
		check(actions.size()==2 and pane.info_popup.wanted and pane.modal_active,"Retired or wrong-kind child callback cannot mutate or close current information")
		await click(surface,pane.info_popup.buttons.closebutton)
		check(not pane.modal_active and pane.popup_identity.is_empty() and pane.available(),"Current physical information Close completes after reentrant replacement")
		pane.update_model(model());pane.show_info(model().available[0]);var stale: Array=pane.info_popup.scope.duplicate();var prior_actions: Array=actions.duplicate(true);pane.set_context(model(),true,text,painter.art,[99,4]);pane.popup_result(true,72,stale,false)
		check(actions==prior_actions and not pane.modal_active and not pane.info_popup.wanted,"Changed parent context still rejects a retired child result")
		check(pane.modal_owner_ticket!=parent_ticket and pane.modal_owner_ticket.scope==[99,4] and order.admits(pane.modal_owner_ticket) and not order.retire(parent_ticket),"Scope replacement retires old parent and registers only current actual owner")
		pane.popup_serial=9007199254740991;pane.show_info(model().available[0])
		check(not pane.modal_active and pane.popup_identity.is_empty() and pane.available(),"Exhausted private child serial cannot wrap or create a replacement request")
		pane.dismiss();check(order.snapshot().records.is_empty(),"Parent dismissal retires all exact parent and leaf tickets")
	pane.close();pane.free();surfaces.close();surfaces.free();order.close();canvas.free()
	var factory=make_ui(surface,catalog,args.install,str(args.report)+".factory");factory.creator.configure_source(painter,text,catalog,str(args.report)+".factory-source")
	var frontend=factory.creator.source_frontend;var factory_pane=frontend.feats
	check(factory_pane.modal_owner_order==factory.modal_order and factory_pane.modal_owner_kind=="other" and factory_pane.info_popup.modal_owner_order==factory.modal_order and factory_pane.group_popup.modal_owner_order==factory.modal_order and factory.modal_surfaces.owners.has(factory_pane.get_instance_id()),"Actual Gameplay to creator factory explicitly binds parent and both existing leaves to their real render group")
	check(factory.modal_order.snapshot().records.is_empty(),"Actual creator configure/prewarm still creates no displayed modal membership")
	factory_pane.process_mode=Node.PROCESS_MODE_ALWAYS;frontend.surface.show()
	var factory_loaded:=check(await ready(factory_pane) and await ready(factory_pane.info_popup) and await ready(factory_pane.group_popup),"Actual factory-created parent and nested leaf source workers complete")
	if factory_loaded:
		factory_pane.set_context(model(),true,text,painter.art,[501,2]);factory_pane.open();await frames()
		var factory_ticket: Dictionary=factory_pane.modal_owner_ticket.duplicate(true)
		check(not factory_ticket.is_empty() and factory.modal_order.admits(factory_ticket),"Actual factory-created parent registers only on its displayed logical open")
		await click(surface,factory_pane.buttons["available:0"]);await click(surface,factory_pane.buttons["available:0:info"]);await click(surface,factory_pane.info_popup.buttons.closebutton)
		check(not factory_pane.modal_active and not factory_pane.info_popup.wanted and factory.modal_order.admits(factory_ticket),"Physical information Close returns correctly through actual creator factory ownership")
		frontend.dismiss();check(factory.modal_order.snapshot().records.is_empty(),"Actual frontend retirement clears its parent and nested leaf leases")
	factory.close();factory.free();painter.close();painter.free();text.close();surface.queue_free();await frames(4)
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"trace":trace,"scope":"Explicit CG_FEATS parent/leaf lifetime cases plus actual Gameplay to creator factory and installed source Controls/pointer input; authored current/stale model, controlled rasters/fonts, no draft-controller, server/GPU/build acceptance"}
	var file:=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify(result,"  ")+"\n");file.close();print("MODAL_FEAT_PARENT ",JSON.stringify(result));quit(0 if failures.is_empty() else 1)
