extends "res://tests/native_modal_owner_input_test.gd"
func class_model() -> Dictionary:
	return {"entries":[{"id":4,"name":"Authored class A","title":483,"description":487,"icon":"","enabled":true},{"id":6,"name":"Authored class B","title":483,"description":487,"icon":"","enabled":true},{"id":99,"name":"Unavailable class","title":483,"description":487,"icon":"","enabled":false}],"recommended":{"title":483,"description":487}}
func alignment_model() -> Dictionary:
	return {"data":{"AlignRestrict":0,"AlignRstrctType":0,"InvertRestrict":0},"classId":4,"goodEvil":50,"lawChaos":50}
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has_all(["report","install"]) or FileAccess.file_exists(args.report):quit(2);return
	var original: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://reports/native-modal-activation-callers-v2.json"))
	check(original.success and original.binarySha256=="3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a","Saved exact original activation index belongs to pinned client")
	for source in [["0x1408e1ae0","0x1408e1bfd"],["0x1408e0d20","0x1408e0ea8"]]:
		var witnesses: Array=original.procedures.filter(func(row):return row.start==source[0])
		check(witnesses.size()==1 and witnesses[0].calls.any(func(call):return call.target=="0x1401fbe40" and call.address==source[1]),"Exact creation open path explicitly calls modal Activate: "+str(source[0]))
	var catalog:=Catalog.new();check(catalog.mount_install(args.install),"Actual installed Class/Alignment resources mount read-only")
	var surface:=SubViewport.new();surface.size=Vector2i(1100,800);surface.disable_3d=true;surface.gui_disable_input=false;surface.handle_input_locally=true;surface.render_target_update_mode=SubViewport.UPDATE_DISABLED;root.add_child(surface);surface.notify_mouse_entered()
	var painter:=Painter.new();painter.art=SourceFixture.ControlledArt.new();painter.fonts=ReadyFonts.new();painter.add_child(painter.art);painter.add_child(painter.fonts);surface.add_child(painter)
	var text=preload("res://systems/native_data/talk_text.gd").new();check(text.base.open_file(str(args.install).path_join("lang/en/data/dialog.tlk")),"Installed TLK supplies actual source captions/help")
	var ui=make_ui(surface,catalog,args.install,args.report);ui.creator.configure_source(painter,text,catalog,str(args.report)+".source")
	var front=ui.creator.source_frontend;var classes=front.class_chooser;var alignment=front.alignment
	classes.process_mode=Node.PROCESS_MODE_ALWAYS;alignment.process_mode=Node.PROCESS_MODE_ALWAYS
	check(classes.modal_owner_order==ui.modal_order and alignment.modal_owner_order==ui.modal_order and ui.modal_surfaces.owners.has(classes.get_instance_id()) and ui.modal_surfaces.owners.has(alignment.get_instance_id()),"Actual creator factory opts in exact Class/Alignment Controls to existing render group")
	check(ui.modal_order.snapshot().records.is_empty(),"Factory prewarm creates no Class/Alignment modal membership")
	var loaded:=check(await ready(classes) and await ready(alignment),"Actual CG_CLASS/CG_ALIGNMENT installed geometry and source Controls prepare")
	var popup_canvas:=CanvasLayer.new();popup_canvas.layer=101;surface.add_child(popup_canvas)
	var info:=SourcePopup.new();info.configure_mode(true);popup_canvas.add_child(info);info.position=Vector2(20,20);info.configure(painter,text,catalog,str(args.report)+".info");info.set_modal_order(ui.modal_order);ui.modal_surfaces.bind_layer(info,popup_canvas);info.start()
	var popup_loaded:=check(await ready(info),"Higher actual source information dialog prepares")
	var class_calls: Array=[];var alignment_calls: Array=[];var accept: Array=[false];var handoff: Array=[false];var reopen: Array=[false]
	var class_commit: Callable=func(id: int,identity: Array) -> Dictionary:class_calls.append([id,identity.duplicate()]);return {"accepted":accept[0],"classId":id,"code":0x8004}
	var alignment_commit: Callable=func(id: int,identity: Array) -> Dictionary:alignment_calls.append([id,identity.duplicate()]);return {"accepted":accept[0],"code":0x8001}
	classes.finished.connect(func(accepted,_id,_ticket):
		if accepted and handoff[0]:handoff[0]=false;front.open_child("alignbutton"))
	alignment.finished.connect(func(accepted,_id,_ticket):
		if accepted and reopen[0]:
			reopen[0]=false;front.begin([903,3],{"classBase":4},[]);front.bind_alignment([903,3],alignment_model(),true,text,alignment_commit);front.open_child("alignbutton"))
	if loaded and popup_loaded:
		var identity: Array=[901,1];front.begin(identity,{"classBase":4},[]);front.bind_classes(identity,class_model(),true,text,painter.art,class_commit);front.bind_alignment(identity,alignment_model(),true,text,alignment_commit);front.open_child("classbutton");await frames()
		var class_ticket: Dictionary=classes.modal_owner_ticket.duplicate(true)
		check(classes.available() and ui.modal_order.admits(class_ticket),"Actual frontend logical Class open registers displayed parent")
		await click(surface,classes.row_buttons[1]);check(classes.state.selected_class()==6 and class_calls.is_empty(),"Physical class row previews without authored commit")
		await pointer(surface,classes.buttons.okbutton,true);info.set_context({"ready":true,"name":"Higher help","description":"Fixture text"},text,painter.art,[91]);info.open();await frames();await pointer(surface,classes.buttons.okbutton,false)
		check(info.available() and not classes.available() and classes.held.is_empty() and class_calls.is_empty(),"Higher modal retires held Class OK without committing")
		await click(surface,classes.row_buttons[0]);check(classes.state.selected_class()==6 and info.wanted,"Enabled lower Class owner cannot select through the higher popup")
		await click(surface,info.buttons.closebutton);check(classes.available() and classes.modal_owner_ticket==class_ticket,"Physical higher Close restores exact Class lifetime")
		classes.set_context(class_model(),true,text,painter.art,front.ticket);classes.open();check(classes.modal_owner_ticket==class_ticket,"Same-scope Class refresh preserves lifetime")
		await pointer(surface,classes.row_buttons[1],true);var old_scope: Array=front.ticket.duplicate();text.revision+=1;front.bind_classes(identity,class_model(),true,text,painter.art,class_commit);await pointer(surface,classes.row_buttons[1],false)
		check(classes.state.selected_class()==4 and classes.held.is_empty() and classes.modal_owner_ticket!=class_ticket and classes.modal_owner_ticket.scope==front.ticket and not ui.modal_order.retire(class_ticket),"Class text-scope replacement retires old held input and exact ticket")
		front.class_result(true,6,old_scope);check(class_calls.is_empty() and classes.wanted,"Stale frontend Class result cannot commit into replacement scope")
		await click(surface,classes.row_buttons[2]);await click(surface,classes.buttons.okbutton);check(classes.state.selected_class()==99 and classes.buttons.okbutton.disabled and class_calls.is_empty(),"Unavailable class remains inspectable while physical OK stays disabled")
		await click(surface,classes.buttons.cancelbutton);check(not classes.wanted and front.child.is_empty() and ui.modal_order.snapshot().records.is_empty(),"Physical Class Cancel retires only its actual modal lifetime")
		front.open_child("classbutton");await frames();await click(surface,classes.row_buttons[1]);await click(surface,classes.buttons.okbutton)
		check(class_calls==[[6,identity]] and classes.wanted and classes.available(),"Rejected actual frontend Class commit reopens usable source parent")
		accept[0]=true;handoff[0]=true;await click(surface,classes.buttons.okbutton)
		check(class_calls.size()==2 and not classes.wanted and alignment.wanted and alignment.available() and front.child=="alignbutton" and ui.modal_order.snapshot().records.size()==1,"Authored synchronous Class completion can activate exact Alignment owner without stale Class membership")
		var alignment_ticket: Dictionary=alignment.modal_owner_ticket.duplicate(true);await click(surface,alignment.buttons.lgbutton)
		check(alignment.state.selected==0 and alignment_calls.is_empty(),"Physical original Alignment radio previews without commit")
		await pointer(surface,alignment.buttons.okbutton,true);info.set_context({"ready":true,"name":"Alignment help","description":"Fixture text"},text,painter.art,[92]);info.open();await frames();await pointer(surface,alignment.buttons.okbutton,false)
		check(not alignment.available() and alignment.held.is_empty() and alignment_calls.is_empty(),"Higher modal retires held Alignment OK")
		await click(surface,info.buttons.closebutton);check(alignment.available() and alignment.modal_owner_ticket==alignment_ticket,"Alignment resumes its exact previous lifetime")
		alignment.set_context(alignment_model().data,4,50,50,true,text,front.ticket);alignment.open();check(alignment.modal_owner_ticket==alignment_ticket,"Same-scope Alignment context preserves modal lifetime")
		await pointer(surface,alignment.buttons.lnbutton,true);old_scope=front.ticket.duplicate();identity=[902,2];front.begin(identity,{"classBase":4},[]);front.bind_alignment(identity,alignment_model(),true,text,alignment_commit);front.open_child("alignbutton");await pointer(surface,alignment.buttons.lnbutton,false)
		check(alignment.state.selected==4 and alignment.held.is_empty() and alignment.modal_owner_ticket!=alignment_ticket and alignment.modal_owner_ticket.scope==front.ticket and not ui.modal_order.retire(alignment_ticket),"Alignment context replacement retires held radio and exact old owner")
		front.alignment_result(true,0,old_scope);check(alignment_calls.is_empty() and alignment.available(),"Old Alignment result cannot commit replacement context")
		front.bind_alignment(identity,alignment_model(),false,text,alignment_commit);var selected: int=alignment.state.selected;await click(surface,alignment.buttons.recommendbutton)
		check(alignment.buttons.recommendbutton.disabled and alignment.state.selected==selected,"Private Recommended disabled state survives modal binding")
		await click(surface,alignment.buttons.cancelbutton);check(not alignment.wanted and ui.modal_order.snapshot().records.is_empty(),"Physical Alignment Cancel retires its exact lifetime")
		accept[0]=false;front.open_child("alignbutton");await frames();await click(surface,alignment.buttons.lgbutton);await click(surface,alignment.buttons.okbutton)
		check(alignment_calls==[[0,identity]] and alignment.wanted and alignment.available(),"Rejected Alignment commit restores usable original Controls")
		accept[0]=true;reopen[0]=true;await click(surface,alignment.buttons.okbutton)
		check(alignment_calls.size()==2 and alignment.available() and front.scope==[903,3] and alignment.modal_owner_ticket.scope==front.ticket,"Reentrant accepted callback preserves replacement Alignment scope/ticket")
		front.dismiss();check(ui.modal_order.snapshot().records.is_empty() and not ui.modal_order.snapshot().membership_available,"Actual frontend retirement clears leases while complete coverage stays unavailable")
	info.close();info.free();popup_canvas.free();ui.close();ui.free();painter.close();painter.free();text.close();surface.queue_free();await frames(4)
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Actual Gameplay/creator Class/Alignment factories and installed source input with authored choices/commit/reentry, controlled art/fonts. No full draft rule, level-up, server/GPU/build/pixel or complete modal coverage acceptance."}
	var file:=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify(result,"  ")+"\n");file.close();print("MODAL_CLASS_ALIGNMENT ",JSON.stringify(result));quit(0 if failures.is_empty() else 1)
