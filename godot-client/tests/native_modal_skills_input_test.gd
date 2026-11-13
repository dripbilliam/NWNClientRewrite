extends "res://tests/native_modal_package_input_test.gd"
class SkillEditor extends RefCounted:
	signal completed(result: Dictionary)
	var calls: Array=[]
	var closes: Array=[]
	var accept_close:=false
	var data:=source_model()
	static func source_model() -> Dictionary:
		return {"ready":true,"points":5,"entries":[{"id":0,"name":"Authored skill","title":483,"description":487,"icon":"","enabled":true}],"details":{0:{"rank":0,"modifier":1,"value":1,"cost":1}}}
	func edit(operation: String,id: int,scope: Array,ticket: Array) -> Dictionary:
		calls.append({"operation":operation,"id":id,"scope":scope.duplicate(),"ticket":ticket.duplicate()})
		if operation=="recommend":
			var result: Dictionary=await completed
			return result
		if operation=="up":data.details[0].rank+=1;data.details[0].value+=1;data.points-=1
		return data.duplicate(true)
	func commit(accepted: bool,scope: Array) -> Dictionary:
		closes.append([accepted,scope.duplicate()]);return {"accepted":accept_close,"next":"package-feats"}
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has_all(["report","install"]) or FileAccess.file_exists(args.report):quit(2);return
	var catalog:=Catalog.new();check(catalog.mount_install(args.install),"Actual installed Package and Skills resources mount read-only")
	var surface:=SubViewport.new();surface.size=Vector2i(1100,800);surface.disable_3d=true;surface.gui_disable_input=false;surface.handle_input_locally=true;surface.render_target_update_mode=SubViewport.UPDATE_DISABLED;root.add_child(surface);surface.notify_mouse_entered()
	var painter:=Painter.new();painter.art=SourceFixture.ControlledArt.new();painter.fonts=ReadyFonts.new();painter.add_child(painter.art);painter.add_child(painter.fonts);surface.add_child(painter)
	var text=preload("res://systems/native_data/talk_text.gd").new();check(text.base.open_file(str(args.install).path_join("lang/en/data/dialog.tlk")),"Actual installed TLK supplies source captions/help")
	var ui=make_ui(surface,catalog,args.install,args.report);ui.creator.configure_source(painter,text,catalog,str(args.report)+".source")
	var frontend=ui.creator.source_frontend;var packages=frontend.packages;var pane=frontend.skills;packages.process_mode=Node.PROCESS_MODE_ALWAYS;pane.process_mode=Node.PROCESS_MODE_ALWAYS
	check(pane.modal_owner_order==ui.modal_order and pane.modal_owner_kind=="other" and ui.modal_surfaces.owners.has(pane.get_instance_id()),"Actual creator factory binds the verified Skills owner and existing render group")
	check(ui.modal_order.snapshot().records.is_empty(),"Package and Skills prewarm create no modal members")
	var loaded:=check(await ready(packages) and await ready(pane),"Actual installed Package and CG_SKILLS controls prepare")
	var popup_canvas:=CanvasLayer.new();popup_canvas.layer=101;surface.add_child(popup_canvas)
	var info:=SourcePopup.new();info.configure_mode(true);popup_canvas.add_child(info);info.position=Vector2(20,20);info.configure(painter,text,catalog,str(args.report)+".info");info.set_modal_order(ui.modal_order);ui.modal_surfaces.bind_layer(info,popup_canvas);info.start()
	var popup_loaded:=check(await ready(info),"Actual higher information owner prepares")
	var gate:=CommitGate.new();var editor:=SkillEditor.new();var identity: Array=[701,1];var sent: Array=[];ui.request.connect(func(message):sent.append(message.duplicate(true)))
	if loaded and popup_loaded:
		frontend.begin(identity,{"classBase":0},[]);frontend.bind_packages(identity,model(),true,text,painter.art,func(_scope):return true,gate.commit);frontend.bind_skills(identity,editor.data,true,text,painter.art,editor.edit,editor.commit);frontend.open_child("packagesbutton");await frames()
		var package_ticket: Dictionary=packages.modal_owner_ticket.duplicate(true);await click(surface,packages.buttons.configurepckg)
		check(gate.calls.size()==1 and frontend.packages_applying and packages.wanted,"Physical Package Configure enters the actual pending frontend handoff")
		gate.completed.emit({"accepted":true,"configure":true});await frames()
		var first: Dictionary=pane.modal_owner_ticket.duplicate(true)
		check(frontend.child=="package-configuration" and not packages.wanted and packages.modal_owner_ticket.is_empty() and pane.wanted and pane.available() and first.scope==frontend.ticket and not ui.modal_order.retire(package_ticket),"Accepted actual Package callback transfers only to current registered Skills parent")
		await click(surface,pane.row_buttons[0]);check(pane.selected==0 and editor.calls.is_empty(),"Physical source skill row changes private help selection without editing")
		await pointer(surface,pane.buttons["up:0"],true);var edits:=editor.calls.size()
		check(edits>=1 and editor.calls[0].ticket==frontend.ticket and editor.calls[0].scope==identity and pane.model.details[0].rank>=1 and not pane.repeat_tag.is_empty(),"Physical source Up starts existing native edit/repeat with exact fourth frontend ticket")
		info.set_context({"ready":true,"name":"Higher skill help","description":"Received fixture text"},text,painter.art,[11]);info.open();await frames();pane.advance_repeat(1000000)
		check(not pane.available() and pane.repeat_tag.is_empty() and pane.repeat_identity.is_empty() and pane.held.is_empty() and editor.calls.size()==edits,"Higher modal synchronously retires skill repeat/capture without another edit")
		await pointer(surface,pane.buttons["up:0"],false);await click(surface,info.buttons.closebutton)
		check(pane.available() and pane.modal_owner_ticket==first and editor.calls.size()==edits,"Physical higher Close restores same Skills lifetime without replaying held Up")
		pane.set_context(editor.data,true,text,painter.art,pane.scope);pane.open();await frames();check(pane.modal_owner_ticket==first,"Same-scope Skills refresh/open preserves parent lifetime")
		await click(surface,pane.buttons.recommendbutton)
		check(frontend.skills_applying and pane.busy and pane.wanted and pane.modal_owner_ticket==first,"Actual frontend recommendation await keeps its busy Skills parent registered")
		editor.completed.emit({"ready":false});await frames();check(not frontend.skills_applying and not pane.busy and pane.available() and pane.modal_owner_ticket==first,"Rejected authored edit completion keeps current owner and existing model")
		await click(surface,pane.buttons.recommendbutton);var old_request: Array=frontend.ticket.duplicate();identity=[702,2];frontend.begin(identity,{"classBase":0},[]);frontend.bind_skills(identity,editor.data,true,text,painter.art,editor.edit,editor.commit);frontend.open_child("package-configuration");await frames()
		var current: Dictionary=pane.modal_owner_ticket.duplicate(true);var before_model: Dictionary=pane.model.duplicate(true);var changed:=SkillEditor.source_model();changed.details[0].rank=99;editor.completed.emit(changed);await frames()
		check(frontend.ticket!=old_request and current!=first and current.scope==frontend.ticket and not ui.modal_order.retire(first) and pane.model==before_model and pane.available(),"Late old-scope recommendation cannot replace current Skills model or ticket")
		await click(surface,pane.buttons.cancelbutton);var reopened: Dictionary=pane.modal_owner_ticket.duplicate(true)
		check(editor.closes.size()==1 and not editor.closes[0][0] and pane.wanted and pane.available() and reopened!=current and not ui.modal_order.retire(current),"Rejected actual Cancel callback reopens only current Skills logical lifetime")
		editor.accept_close=true;await click(surface,pane.buttons.cancelbutton)
		check(editor.closes.size()==2 and not pane.wanted and pane.modal_owner_ticket.is_empty() and ui.modal_order.snapshot().records.is_empty(),"Accepted actual Cancel retires transferred Skills through existing frontend callback")
		check(not sent.any(func(message):return message.get("kind")=="native-creation-submit") and not ui.modal_order.snapshot().membership_available,"Authored handoff performs no upload or complete-modal coverage claim")
	info.close();info.free();popup_canvas.free();ui.close();ui.free();painter.close();painter.free();text.close();surface.queue_free();await frames(4)
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Actual creator factory/installed Package to Skills Configure handoff, physical row/Up/repeat masking and frontend edit/Cancel/stale lifetimes. Authored model/edit/completion providers, controlled rasters/fonts; no draft rules, server/GPU/build or complete modal coverage acceptance"}
	var file:=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify(result,"  ")+"\n");file.close();print("MODAL_SKILLS ",JSON.stringify(result));quit(0 if failures.is_empty() else 1)
