extends "res://tests/native_modal_owner_input_test.gd"
const Race=preload("res://systems/native_race_chooser.gd")
const Order=preload("res://systems/native_data/modal_order.gd")
const Surfaces=preload("res://systems/native_modal_surfaces.gd")
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has_all(["report","install"]) or FileAccess.file_exists(args.report):quit(2);return
	var catalog:=Catalog.new();check(catalog.mount_install(args.install),"Actual installed Race/Subrace resources mount read-only")
	var surface:=SubViewport.new();surface.size=Vector2i(1100,800);surface.disable_3d=true;surface.gui_disable_input=false;surface.handle_input_locally=true;surface.render_target_update_mode=SubViewport.UPDATE_DISABLED;root.add_child(surface);surface.notify_mouse_entered()
	var painter:=Painter.new();painter.art=SourceFixture.ControlledArt.new();painter.fonts=ReadyFonts.new();painter.add_child(painter.art);painter.add_child(painter.fonts);surface.add_child(painter)
	var text=preload("res://systems/native_data/talk_text.gd").new();check(text.base.open_file(str(args.install).path_join("lang/en/data/dialog.tlk")),"Actual installed TLK supplies source captions")
	var order:=Order.new();var surfaces:=Surfaces.new();surface.add_child(surfaces);surfaces.configure(order)
	var canvas:=CanvasLayer.new();canvas.layer=40;surface.add_child(canvas)
	var pane:=Race.new();canvas.add_child(pane);pane.position=Vector2(80,80);pane.configure(painter,text,catalog,str(args.report)+".cache");pane.start()
	var loaded:=check(await ready(pane) and await ready(pane.subrace),"Actual CG_RACE and UTIL_EDITPOPUP source Controls prepare")
	var trace: Dictionary={};var finishes: Array=[];var reopen_child: Array=[false];var reopen_parent: Array=[false]
	var values: Array=[{"id":6,"name":"Authored race","title":483,"description":487,"icon":""}]
	pane.finished.connect(func(accepted,id,value,scope):
		finishes.append([accepted,id,value,scope.duplicate()])
		if reopen_parent[0]:
			reopen_parent[0]=false;pane.set_context(values,6,"Next context",true,text,painter.art,[803,5]);pane.open())
	pane.subrace.finished.connect(func(accepted,_value,_scope):
		if not accepted and reopen_child[0]:
			reopen_child[0]=false;pane.capture("subracebutton");pane.invoke("subracebutton"))
	if loaded:
		pane.set_context(values,6,"Authored subrace",true,text,painter.art,[801,3]);pane.open();await frames()
		await click(surface,pane.buttons.subracebutton)
		check(pane.subrace.wanted and pane.modal.visible and pane.subrace.edit.has_focus(),"Unbound baseline physically opens the actual Subrace editor")
		await click(surface,pane.subrace.buttons.cancelbutton)
		check(not pane.subrace.wanted and not pane.modal.visible and pane.available() and finishes.is_empty(),"Baseline physical Subrace Cancel returns without committing Race")
		# Fixture-only bindings exercise the approved chooser correction before
		# adding verified parent/leaf mappings to the production creator factory.
		pane.set_modal_owner(order,"other");pane.subrace.set_modal_owner(order,"other");surfaces.bind_layer(pane,canvas);surfaces.bind_layer(pane.subrace,canvas)
		await click(surface,pane.buttons.subracebutton);await frames()
		trace={"parentWanted":pane.wanted,"parentAvailable":pane.available(),"childWanted":pane.subrace.wanted,"childVisible":pane.subrace.is_visible_in_tree(),"containerVisible":pane.modal.visible,"requestScope":pane.subrace_scope.duplicate(),"childScope":pane.subrace.scope.duplicate(),"parentTicket":pane.modal_owner_ticket.duplicate(true),"childTicket":pane.subrace.modal_owner_ticket.duplicate(true),"records":order.snapshot().records}
		check(pane.subrace.wanted and pane.modal.visible and pane.subrace.available() and pane.subrace.edit.has_focus(),"Actual bound Subrace activation must preserve the new child while retiring lower parent input")
		var hidden_top: bool=not pane.subrace.is_visible_in_tree() and order.admits(pane.subrace.modal_owner_ticket)
		check(not hidden_top,"No hidden Subrace may remain the current logical top")
		if pane.subrace.wanted:
			await click(surface,pane.subrace.buttons.cancelbutton);check(pane.available() and pane.subrace_scope.is_empty() and finishes.is_empty(),"Physical bound child Cancel restores its live Race owner")
			var same: Dictionary=pane.modal_owner_ticket.duplicate(true);pane.set_context(values,6,"Authored subrace",true,text,painter.art,[801,3]);pane.open();await frames()
			check(pane.modal_owner_ticket==same,"Same-scope Race context refresh/open preserves parent lifetime")
			await pointer(surface,pane.buttons.okbutton,true);pane.capture("subracebutton");pane.invoke("subracebutton");await frames();await pointer(surface,pane.buttons.okbutton,false)
			check(pane.subrace.wanted and pane.held.is_empty() and finishes.is_empty(),"Parent admission loss still retires actual held OK without cancelling the new child")
			var old_child: Dictionary=pane.subrace.modal_owner_ticket.duplicate(true);var old_scope: Array=pane.subrace.scope.duplicate();var old_parent: Dictionary=pane.modal_owner_ticket.duplicate(true)
			pane.set_context(values,6,"Replacement",true,text,painter.art,[802,4]);pane.subrace_result(true,"stale value",old_scope);await frames()
			check(not pane.subrace.wanted and not pane.modal.visible and pane.subrace_scope.is_empty() and pane.current_subrace=="Replacement" and finishes.is_empty(),"Actual context replacement cancels owned child and rejects its stale accepted result")
			check(pane.modal_owner_ticket!=old_parent and pane.modal_owner_ticket.scope==[802,4] and pane.available() and not order.retire(old_parent) and not order.retire(old_child),"Scope replacement registers exact new parent and retires both old tickets")
			await click(surface,pane.buttons.subracebutton);old_child=pane.subrace.modal_owner_ticket.duplicate(true);old_scope=pane.subrace.scope.duplicate();reopen_child[0]=true;await click(surface,pane.subrace.buttons.cancelbutton)
			check(pane.subrace.wanted and pane.modal.visible and pane.subrace.modal_owner_ticket!=old_child and pane.subrace_scope==pane.subrace.scope and pane.subrace.available(),"Synchronous Cancel callback may reopen a new exact child without hidden top")
			pane.subrace_result(false,"",old_scope);check(pane.subrace.wanted and pane.modal.visible and pane.subrace.available(),"Late old Cancel cannot hide a reentrant current child")
			await click(surface,pane.subrace.buttons.cancelbutton);check(pane.available() and pane.subrace_scope.is_empty() and finishes.is_empty(),"Current reentrant child Cancel restores only its parent")
			await click(surface,pane.buttons.subracebutton);old_parent=pane.modal_owner_ticket.duplicate(true);pane.subrace.edit.text="Chosen";reopen_parent[0]=true;await click(surface,pane.subrace.buttons.okbutton)
			check(finishes.size()==1 and finishes[0][0] and finishes[0][2]=="Chosen" and finishes[0][3]==[802,4] and pane.wanted and pane.scope==[803,5] and pane.available() and not pane.subrace.wanted and not order.retire(old_parent),"Accepted physical child result can synchronously replace parent scope without retiring the replacement")
			await click(surface,pane.buttons.subracebutton);old_child=pane.subrace.modal_owner_ticket.duplicate(true);old_parent=pane.modal_owner_ticket.duplicate(true);pane.dismiss();await frames()
			check(order.snapshot().records.is_empty() and pane.subrace_scope.is_empty() and not pane.subrace.wanted and not pane.modal.visible and not order.retire(old_parent) and not order.retire(old_child),"Actual owner dismissal cancels active child and exact parent/leaf tickets")
			pane.open();await frames();await click(surface,pane.buttons.subracebutton);pane.close();await frames()
			check(pane.closed and pane.subrace.closed and order.snapshot().records.is_empty(),"Actual close drains active parent/child leases without a hidden current top")
		pane.dismiss();check(order.snapshot().records.is_empty(),"Repeated owner teardown leaves no parent or leaf tickets")
	pane.close();pane.free();surfaces.close();surfaces.free();order.close();canvas.free()
	var factory=make_ui(surface,catalog,args.install,str(args.report)+".factory");factory.creator.configure_source(painter,text,catalog,str(args.report)+".factory-source")
	var frontend=factory.creator.source_frontend;var factory_pane=frontend.race;factory_pane.process_mode=Node.PROCESS_MODE_ALWAYS;frontend.surface.show()
	check(factory_pane.modal_owner_order==factory.modal_order and factory_pane.subrace.modal_owner_order==factory.modal_order and factory.modal_surfaces.owners.has(factory_pane.get_instance_id()) and factory.modal_surfaces.owners.has(factory_pane.subrace.get_instance_id()),"Actual Gameplay creator factory maps both real Race/Subrace Controls to their existing frontend render group")
	check(factory.modal_order.snapshot().records.is_empty(),"Actual creator configure/prewarm does not activate either Race owner")
	var factory_loaded:=check(await ready(factory_pane) and await ready(factory_pane.subrace),"Actual factory-created Race and Subrace Controls prepare through installed source workers")
	var commits: Array=[];var accepted: Array=[false];var factory_reopen: Array=[false]
	var commit: Callable=func(id: int,value: Variant,identity: Array) -> Dictionary:
		commits.append([id,value,identity.duplicate()]);return {"accepted":accepted[0],"race":id,"subrace":value,"code":0x800a}
	factory_pane.finished.connect(func(was_accepted,_id,_value,_scope):
		if was_accepted and factory_reopen[0]:
			factory_reopen[0]=false;frontend.begin([813,7],{"classBase":0},[]);frontend.bind_races([813,7],values,6,"Reentrant factory",true,text,painter.art,commit);frontend.open_child("racebutton"))
	if factory_loaded:
		frontend.begin([811,5],{"classBase":0},[]);frontend.bind_races([811,5],values,6,"Factory subrace",true,text,painter.art,commit);frontend.open_child("racebutton");await frames()
		var parent_ticket: Dictionary=factory_pane.modal_owner_ticket.duplicate(true)
		check(factory_pane.wanted and factory_pane.available() and factory.modal_order.admits(parent_ticket),"Real frontend logical Race open registers its actual parent exactly once")
		await click(surface,factory_pane.buttons.subracebutton);await click(surface,factory_pane.subrace.buttons.cancelbutton)
		check(factory_pane.available() and factory_pane.modal_owner_ticket==parent_ticket and not factory_pane.subrace.wanted and commits.is_empty(),"Physical factory-created Subrace Cancel restores exact parent without draft commit")
		await click(surface,factory_pane.buttons.subracebutton);var retired_scope: Array=factory_pane.subrace.scope.duplicate();var retired_leaf: Dictionary=factory_pane.subrace.modal_owner_ticket.duplicate(true)
		frontend.begin([812,6],{"classBase":0},[]);frontend.bind_races([812,6],values,6,"Replacement factory",true,text,painter.art,commit);frontend.open_child("racebutton");factory_pane.subrace_result(true,"Old child",retired_scope);await frames()
		check(factory_pane.available() and not factory_pane.subrace.wanted and not factory_pane.modal.visible and factory_pane.current_subrace=="Replacement factory" and commits.is_empty() and not factory.modal_order.retire(parent_ticket) and not factory.modal_order.retire(retired_leaf),"Real frontend replacement cancels old child and rejects its late result/exact tickets")
		await click(surface,factory_pane.buttons.subracebutton);factory_pane.subrace.edit.text="Rejected custom";await click(surface,factory_pane.subrace.buttons.okbutton)
		check(commits==[[6,"Rejected custom",[812,6]]] and factory_pane.wanted and factory_pane.available() and not factory_pane.subrace.wanted and not factory_pane.modal.visible,"Physical factory child OK reaches exact authored commit once and rejection restores usable parent")
		accepted[0]=true;factory_reopen[0]=true;await click(surface,factory_pane.buttons.subracebutton);factory_pane.subrace.edit.text="Accepted custom";await click(surface,factory_pane.subrace.buttons.okbutton)
		check(commits.size()==2 and commits[1]==[6,"Accepted custom",[812,6]] and frontend.scope==[813,7] and frontend.child=="racebutton" and factory_pane.available() and factory_pane.current_subrace=="Reentrant factory" and not factory_pane.subrace.wanted,"Physical accepted factory result permits synchronous new parent scope without old completion retiring it")
		await click(surface,factory_pane.buttons.subracebutton);frontend.dismiss();await frames()
		check(not factory_pane.wanted and not factory_pane.subrace.wanted and factory.modal_order.snapshot().records.is_empty() and not factory.modal_order.snapshot().membership_available,"Actual frontend teardown retires active Race and Subrace without claiming complete coverage")
	factory.close();factory.free();painter.close();painter.free();text.close();surface.queue_free();await frames(4)
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"trace":trace,"scope":"Approved Race input/scope correction, actual Gameplay/creator factory opt-ins, installed source Controls and physical/reentrant frontend lifecycle cases; authored choice/commit data, controlled art/fonts; no server/GPU/build/full draft or complete modal coverage acceptance"}
	var file:=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify(result,"  ")+"\n");file.close();print("MODAL_RACE_SUBRACE ",JSON.stringify(result));quit(0 if failures.is_empty() else 1)
