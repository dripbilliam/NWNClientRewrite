extends "res://tests/native_portrait_chooser_test.gd"
const Front=preload("res://systems/native_creation_frontend.gd")
func wait_ready(test: Callable) -> bool:
	var deadline:=Time.get_ticks_msec()+20000
	while not bool(test.call()) and Time.get_ticks_msec()<deadline:await process_frame
	return bool(test.call())
func escape() -> void:
	var event:=InputEventKey.new();event.keycode=KEY_ESCAPE;event.pressed=true;surface.push_input(event,true);await frames()
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has_all(["report","install"]) or FileAccess.file_exists(args.report):quit(2);return
	var catalog:=Catalog.new();check(catalog.mount_install(args.install),"Installed source catalog mounts read-only")
	surface=SubViewport.new();surface.size=Vector2i(1100,800);surface.gui_disable_input=false;surface.handle_input_locally=true;surface.render_target_update_mode=SubViewport.UPDATE_DISABLED;root.add_child(surface);surface.notify_mouse_entered()
	var painter:=Painter.new();var art:=HeadlessArt.new();var fonts:=HeadlessFonts.new();painter.art=art;painter.fonts=fonts;painter.add_child(art);painter.add_child(fonts);art.loaded.connect(painter.art_loaded);surface.add_child(painter)
	var text:=preload("res://systems/native_data/talk_text.gd").new();check(text.base.open_file(str(args.install).path_join("lang/en/data/dialog.tlk")),"Original message and Main captions use installed TLK")
	var front:=Front.new();surface.add_child(front);front.configure(painter,text,catalog,"")
	var endings: Array=[];var commands: Array=[];var notices: Array=[]
	front.finished.connect(func(cancelled,identity):endings.append([cancelled,identity.duplicate()]))
	front.command_requested.connect(func(operation,identity):commands.append([operation,identity.duplicate()]))
	front.status_dismissed.connect(func(message,identity):notices.append([message,identity.duplicate()]))
	front.begin(["creation",7],{},[])
	check(await wait_ready(func():return front.main.layout_ready),"Actual original CG_MAIN prepares: "+front.main.failure)
	if front.main.layout_ready:
		for tag in front.flow.enabled:front.flow.enabled[tag]=true
		front.flow.completed.class=true;front.refresh();await frames()
		var retained: Dictionary={"enabled":front.flow.enabled.duplicate(),"completed":front.flow.completed.duplicate(),"scope":front.scope.duplicate()}
		await mouse(front.main.buttons.playbutton,true);front.set_phase("preparing","Preparing your character…");await mouse(front.main.buttons.playbutton,false)
		check(commands.is_empty(),"A Play release held across preparation cannot start another submit")
		check(await wait_ready(func():return front.status_view.layout_ready),"Original OK-scroll status resources prepare: "+front.status_view.failure)
		if front.status_view.layout_ready:
			var notice=front.status_view
			check(front.main.visible and notice.visible and notice.message=="Preparing your character…" and notice.description.get_parsed_text()==notice.message,"Preparation is visible beside the preserved Main controls")
			check(notice.resource=="okscrollpanel" and notice.plan.entries.okbutton.callback=="0x140201f30" and notice.plan.content.size.x>0,"Status reuses original message art, scroll attachments and OK callback")
			check(notice.progress and not notice.buttons.okbutton.visible and notice.mouse_behavior_recursive==Control.MOUSE_BEHAVIOR_DISABLED,"Readonly progress has no dismiss button and cannot intercept parent input")
			check(front.main.buttons.values().filter(func(button):return not button.disabled)==[front.main.buttons.cancelbutton] and front.main.summary_view.tabs.all(func(button):return button.disabled),"Preparing disables Main actions and summary tabs while preserving only Cancel")
			check(not notice.get_global_rect().intersects(front.main.buttons.cancelbutton.get_global_rect()),"Source notice stays clear of the original Cancel hit rectangle")
			await click(front.main.buttons.genderbutton);front.main_action("resetbutton",front.scope);front.main_action("playbutton",front.scope)
			check(front.child.is_empty() and commands.is_empty() and front.flow.completed==retained.completed,"Physical disabled controls and direct Main actions cannot mutate or submit during preparation")
			await mouse(front.main.buttons.cancelbutton,true);front.set_phase("waiting","Waiting for the server to admit your character…");await mouse(front.main.buttons.cancelbutton,false)
			await click(front.main.buttons.cancelbutton);await escape();front.main_action("cancelbutton",front.scope)
			check(endings.is_empty() and front.wanted and front.main.buttons.values().all(func(button):return button.disabled),"Waiting rejects physical, keyboard, direct and stale preparation Cancel without implying admission")
			check(front.main.visible and notice.visible and notice.message.begins_with("Waiting"),"Waiting remains visible on Main until authoritative admission or rejection")
			front.set_phase("editing","Custom server rejected the selected feat.\nReview your choices.");await frames()
			check(front.main.visible and front.flow.enabled==retained.enabled and front.flow.completed==retained.completed and front.scope==retained.scope,"Rejection restores the original availability and preserves choices/completion/scope")
			check(notice.visible and not notice.progress and notice.buttons.okbutton.visible and not notice.buttons.okbutton.disabled and notice.description.get_parsed_text()==front.phase_status,"The exact rejection reason is readable with original OK/scroll controls")
			var current: Array=notice.scope.duplicate();var revision: int=notice.revision
			front.set_phase("editing",front.phase_status);front.refresh();check(notice.scope==current and notice.revision==revision,"Repeated render does not reticket a notice or retire a held acknowledgement")
			await click(notice.buttons.okbutton)
			check(notices==[["Custom server rejected the selected feat.\nReview your choices.",["creation",7]]] and front.phase_status.is_empty() and not notice.visible and front.main.visible,"Physical OK dismisses only this scoped reason while keeping Main and choices")
			front.set_phase("editing","First reason");await mouse(notice.buttons.okbutton,true);var stale: Array=notice.scope.duplicate();front.set_phase("editing","Newer reason");await mouse(notice.buttons.okbutton,false)
			front.dismiss_status(stale);check(notices.size()==1 and notice.visible and front.phase_status=="Newer reason","A held or stale acknowledgement cannot erase a newer server reason")
			await escape();check(notices.size()==2 and notices[-1]==["Newer reason",["creation",7]] and not notice.visible,"Escape acknowledges only an editing notice")
			front.set_phase("editing","Retained until edited");await click(front.main.buttons.genderbutton)
			check(front.child=="genderbutton" and not notice.visible,"Opening a source child retires the embedded Main notice without covering its controls")
			front.accept_child(front.ticket.duplicate(),2);check(notice.visible and front.phase_status=="Retained until edited","Cancelling a child preserves the unresolved reason")
			front.set_phase("editing","");check(not notice.visible and not front.main.buttons.playbutton.disabled,"An explicit successful edit clear removes the notice and restores original buttons")
			front.set_phase("preparing","Preparing again");await click(front.main.buttons.cancelbutton)
			check(endings==[[true,["creation",7]]] and not front.wanted and not notice.visible,"Physical preparing Cancel retires the exact draft and progress view")
			front.begin(["creation",8],{},[]);front.set_phase("preparing","Preparing replacement");await escape()
			check(endings[-1]==[true,["creation",8]] and endings.size()==2,"Preparing Escape follows the same owned cancellation path")
			front.begin(["creation",9],{},[]);front.set_phase("editing","Old draft reason");var old_scope: Array=notice.scope.duplicate();front.begin(["creation",10],{},[]);front.dismiss_status(old_scope)
			check(front.phase_status.is_empty() and not notice.visible and front.scope==["creation",10],"Draft replacement retires previous status identity and stale acknowledgements")
			check(notice.modal_owner_ticket.is_empty(),"Embedded notice does not invent or trap a separate modal owner")
	front.close();check(front.main.assets.running.is_empty() and front.status_view.assets.running.is_empty(),"Close drains source Main/status workers")
	front.queue_free();painter.close();painter.queue_free();await frames(5);surface.queue_free();await frames()
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"graphical":false,"serverConnections":0,"scope":"Actual installed CG_MAIN and OK-scroll controls, physical headless pointer/keyboard input, phase/held-input guards and preserved original flow availability. Non-rendering art/font doubles; no raster, complete class flow, BIC save or server admission acceptance."}
	var file:=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify(result,"\t"));file.close();quit(0 if result.success else 1)
