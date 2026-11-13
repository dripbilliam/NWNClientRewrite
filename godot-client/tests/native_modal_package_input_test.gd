extends "res://tests/native_modal_owner_input_test.gd"
class CommitGate extends RefCounted:
	signal completed(result: Dictionary)
	var calls: Array=[]
	func commit(operation: String,id: int,scope: Array,ticket: Array) -> Dictionary:
		calls.append({"operation":operation,"id":id,"scope":scope.duplicate(),"ticket":ticket.duplicate()})
		var result: Dictionary=await completed
		return result
func model() -> Dictionary:
	return {"entries":[{"id":1,"name":"Authored package A","title":483,"description":487,"icon":""},{"id":2,"name":"Authored package B","title":483,"description":487,"icon":""}],"default":1,"classId":0}
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has_all(["report","install"]) or FileAccess.file_exists(args.report):quit(2);return
	var catalog:=Catalog.new();check(catalog.mount_install(args.install),"Actual installed Package resources mount read-only")
	var surface:=SubViewport.new();surface.size=Vector2i(1100,800);surface.disable_3d=true;surface.gui_disable_input=false;surface.handle_input_locally=true;surface.render_target_update_mode=SubViewport.UPDATE_DISABLED;root.add_child(surface);surface.notify_mouse_entered()
	var painter:=Painter.new();painter.art=SourceFixture.ControlledArt.new();painter.fonts=ReadyFonts.new();painter.add_child(painter.art);painter.add_child(painter.fonts);surface.add_child(painter)
	var text=preload("res://systems/native_data/talk_text.gd").new();check(text.base.open_file(str(args.install).path_join("lang/en/data/dialog.tlk")),"Actual installed TLK supplies source captions/help")
	var ui=make_ui(surface,catalog,args.install,args.report);ui.creator.configure_source(painter,text,catalog,str(args.report)+".source")
	var frontend=ui.creator.source_frontend;var pane=frontend.packages;pane.process_mode=Node.PROCESS_MODE_ALWAYS
	check(pane.modal_owner_order==ui.modal_order and pane.modal_owner_kind=="other" and ui.modal_surfaces.owners.has(pane.get_instance_id()),"Actual Gameplay to creator factory binds only explicit Package parent to its real render group")
	check(ui.modal_order.snapshot().records.is_empty(),"Actual factory prewarm creates no Package membership")
	var loaded:=check(await ready(pane),"Actual installed CG_PACKAGE and source controls prepare")
	var popup_canvas:=CanvasLayer.new();popup_canvas.layer=101;surface.add_child(popup_canvas)
	var info:=SourcePopup.new();info.configure_mode(true);popup_canvas.add_child(info);info.position=Vector2(20,20);info.configure(painter,text,catalog,str(args.report)+".info");info.set_modal_order(ui.modal_order);ui.modal_surfaces.bind_layer(info,popup_canvas);info.start()
	var popup_loaded:=check(await ready(info),"Actual higher information popup prepares independently")
	var gate:=CommitGate.new();var identity: Array=[601,1];var sent: Array=[];ui.request.connect(func(message):sent.append(message.duplicate(true)))
	if loaded and popup_loaded:
		frontend.begin(identity,{"classBase":0},[]);frontend.bind_packages(identity,model(),true,text,painter.art,func(_scope):return true,gate.commit);frontend.open_child("packagesbutton");await frames()
		var first: Dictionary=pane.modal_owner_ticket.duplicate(true)
		check(pane.wanted and pane.available() and ui.modal_order.admits(first) and pane.row_buttons.size()==2,"Actual frontend logical Package open registers the displayed source owner")
		await click(surface,pane.row_buttons[1]);check(pane.state.selected_package()==2 and gate.calls.is_empty(),"Physical source row selects private package without committing")
		info.set_context({"ready":true,"name":"Higher source help","description":"Received fixture text"},text,painter.art,[9]);info.open();await frames()
		check(not pane.available() and pane.held.is_empty() and info.available(),"Higher actual modal masks lower Package input and retires held state")
		await click(surface,pane.row_buttons[0]);check(pane.state.selected_package()==2 and info.wanted,"Physical lower row cannot change selection through higher popup")
		await click(surface,info.buttons.closebutton);check(pane.available() and pane.modal_owner_ticket==first,"Physical higher Close restores the exact same Package lifetime")
		await click(surface,pane.buttons.configurepckg)
		check(gate.calls.size()==1 and gate.calls[0].operation=="configure" and gate.calls[0].id==2 and frontend.packages_applying and pane.busy and pane.wanted and pane.modal_owner_ticket==first and pane.available(),"Physical Configure enters actual frontend await while keeping its busy modal parent registered")
		info.open();await frames();await click(surface,pane.buttons.configurepckg)
		check(gate.calls.size()==1 and pane.busy and pane.wanted and not pane.available(),"Pending Configure cannot duplicate through a higher modal")
		await click(surface,info.buttons.closebutton);gate.completed.emit({"accepted":false});await frames()
		var second: Dictionary=pane.modal_owner_ticket.duplicate(true)
		check(not frontend.packages_applying and pane.wanted and not pane.busy and pane.available() and second!=first and second.scope==frontend.ticket and not ui.modal_order.retire(first),"Rejected authored completion reopens only current actual Package ticket with original frontend retry behavior")
		var same: Dictionary=second.duplicate(true);frontend.open_packages();await frames()
		check(pane.modal_owner_ticket==same,"Same-scope Package refresh/open does not promote or replace lifetime")
		await click(surface,pane.buttons.configurepckg);check(gate.calls.size()==2 and frontend.packages_applying,"Second physical Configure starts one new actual pending completion")
		var retired_request: Array=frontend.ticket.duplicate();identity=[602,2];frontend.begin(identity,{"classBase":0},[]);frontend.bind_packages(identity,model(),true,text,painter.art,func(_scope):return true,gate.commit);frontend.open_child("packagesbutton");await frames()
		var current: Dictionary=pane.modal_owner_ticket.duplicate(true);var current_request: Array=frontend.ticket.duplicate()
		gate.completed.emit({"accepted":true,"configure":true});await frames()
		check(frontend.ticket==current_request and frontend.ticket!=retired_request and frontend.child=="packagesbutton" and pane.wanted and pane.modal_owner_ticket==current and pane.available() and not ui.modal_order.retire(second),"Old Configure completion cannot close or transfer a replacement scope into unbound Skills")
		await pointer(surface,pane.row_buttons[1],true);var stale: Dictionary=current.duplicate(true);identity=[603,3];frontend.begin(identity,{"classBase":0},[]);frontend.bind_packages(identity,model(),true,text,painter.art,func(_scope):return true,gate.commit);frontend.open_child("packagesbutton");await frames();await pointer(surface,pane.row_buttons[1],false)
		check(pane.state.selected_package()==1 and pane.held.is_empty() and not ui.modal_order.retire(stale),"Held source row cannot cross a new Package scope and exact lifetime")
		await click(surface,pane.buttons.cancelbutton);check(not pane.wanted and pane.modal_owner_ticket.is_empty() and not frontend.packages_applying and ui.modal_order.snapshot().records.is_empty(),"Physical source Cancel retires actual Package through existing frontend callback")
		check(not sent.any(func(message):return message.get("kind")=="native-creation-submit") and not ui.modal_order.snapshot().membership_available,"Authored fixture emits no character upload and does not claim complete modal coverage")
	info.close();info.free();popup_canvas.free();ui.close();ui.free();painter.close();painter.free();text.close();surface.queue_free();await frames(4)
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Actual Gameplay/creator factory/Package Controls and frontend Configure await, higher-popup physical input, retry/Cancel/stale scope. Authored package model and completion gate, controlled rasters/fonts; no full draft, Skills continuation, server/GPU/build acceptance"}
	var file:=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify(result,"  ")+"\n");file.close();print("MODAL_PACKAGE ",JSON.stringify(result));quit(0 if failures.is_empty() else 1)
