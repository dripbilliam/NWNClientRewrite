extends "res://tests/native_modal_owner_input_test.gd"
func portrait_choices(count: int) -> Array:
	var out: Array=[]
	for index in count:out.append("p%03d_"%index)
	return out
func wheel_at(surface: SubViewport,control: Control) -> void:
	var point:=control.get_global_transform_with_canvas()*(control.size*0.5)
	var motion:=InputEventMouseMotion.new();motion.position=point;motion.global_position=point;surface.push_input(motion,true);await frames()
	for pressed in [true,false]:
		var event:=InputEventMouseButton.new();event.position=point;event.global_position=point;event.button_index=MOUSE_BUTTON_WHEEL_DOWN;event.pressed=pressed;surface.push_input(event,true);await frames()
func portrait_settled(pane) -> bool:
	var deadline:=Time.get_ticks_msec()+3000
	while pane.range_pending and Time.get_ticks_msec()<deadline:await process_frame
	return not pane.range_pending
func source_scroll_bounds(pane) -> bool:
	# This fixture supplies a controlled raster, but its footprint must still
	# come from the installed posed mesh/layer rather than an invented thumb.
	var posed: Dictionary=preload("res://systems/native_data/gui_pose.gd").nodes(pane.models.scrollbar_simple,pane.bar.plan.poses)
	if not str(posed.get("error","")).is_empty():return false
	for layer in ["gui_boxes_ingame","gui_scrollbar"]:
		var model: Dictionary=posed.model.duplicate(true)
		for node in model.nodes:
			var mesh: Dictionary=node.get("mesh",{})
			var textures: Array=mesh.get("textures",[])
			if not textures.any(func(value):return str(value).to_lower()==layer):mesh.render=false
		var geometry: Dictionary=preload("res://systems/native_data/gui_model_geometry.gd").model(model)
		if not str(geometry.get("error","")).is_empty() or not geometry.drawn:return false
		var rect: Rect2=geometry.bounds
		if rect.size.x<=0 or rect.size.y<=0:return false
		var key: String=pane.bar.rail_key if layer=="gui_boxes_ingame" else pane.bar.thumb_image_key
		pane.frame.art.bounds[key]={"min":[rect.position.x/100.0,-rect.end.y/100.0],"max":[rect.end.x/100.0,-rect.position.y/100.0]}
	pane.bar.refresh()
	return pane.bar.thumb.size.x>0 and pane.bar.thumb.size.y>0
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has_all(["report","install"]) or FileAccess.file_exists(args.report):quit(2);return
	var original: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://reports/native-modal-activation-callers-v2.json"))
	check(original.success and original.binarySha256=="3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a","Pinned original modal activation evidence")
	for source in [["0x1408e71d0","0x1408e72f0"],["0x1408e58c0","0x1408e59dc"]]:
		var witnesses: Array=original.procedures.filter(func(row):return row.start==source[0])
		check(witnesses.size()==1 and witnesses[0].calls.any(func(call):return call.target=="0x1401fbe40" and call.address==source[1]),"Exact creation Gender/Portrait caller explicitly activates modal: "+str(source[0]))
	var scroll_original: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://reports/native-portrait-pane-dossiers-v1.json"))
	check(scroll_original.binary_sha256==original.binarySha256 and scroll_original.functions.any(func(row):return row.key=="ui-portrait-grid-scroll" and row.procedure.address=="0x1409d1350"),"Pinned complete original row-refresh callback is independently retained")
	var catalog:=Catalog.new();check(catalog.mount_install(args.install),"Installed source catalog mounts read-only")
	var surface:=SubViewport.new();surface.size=Vector2i(1100,800);surface.disable_3d=true;surface.gui_disable_input=false;surface.handle_input_locally=true;surface.render_target_update_mode=SubViewport.UPDATE_DISABLED;root.add_child(surface);surface.notify_mouse_entered()
	var painter:=Painter.new();painter.art=SourceFixture.ControlledArt.new();painter.fonts=ReadyFonts.new();painter.add_child(painter.art);painter.add_child(painter.fonts);surface.add_child(painter)
	var text=preload("res://systems/native_data/talk_text.gd").new();check(text.base.open_file(str(args.install).path_join("lang/en/data/dialog.tlk")),"Actual source captions use installed TLK")
	var ui=make_ui(surface,catalog,args.install,args.report);ui.creator.configure_source(painter,text,catalog,str(args.report)+".source")
	var front=ui.creator.source_frontend;var gender=front.gender;var portrait=front.portrait
	gender.process_mode=Node.PROCESS_MODE_ALWAYS;portrait.process_mode=Node.PROCESS_MODE_ALWAYS
	check(gender.modal_lease.order==ui.modal_order and portrait.modal_lease.order==ui.modal_order and ui.modal_surfaces.owners.has(gender.get_instance_id()) and ui.modal_surfaces.owners.has(portrait.get_instance_id()),"Real creator factory binds exact Gender/Portrait Controls and existing frontend render group")
	check(ui.modal_order.snapshot().records.is_empty(),"Factory prewarm does not create either modal lifetime")
	var prepared_order: Array=[];gender.prepared.connect(func():prepared_order.append("gender"));portrait.prepared.connect(func():prepared_order.append("portrait"))
	front.surface.show();gender.set_context(0,[1000,0,"gender"]);portrait.set_context(portrait_choices(71),"p020_",[1000,0,"portrait"],painter.art,catalog);gender.open();portrait.open()
	check(gender.wanted and portrait.wanted and not gender.layout_ready and not portrait.layout_ready and ui.modal_order.snapshot().records.is_empty(),"Logical early opens wait for actual source Controls instead of registering invisible prewarm owners")
	var loaded:=check(await ready(gender) and await ready(portrait),"Actual CG_SEX/CG_PORTRAIT source geometry and native Controls prepare")
	if loaded:
		check(await portrait_settled(portrait) and prepared_order.size()==2 and ui.modal_order.snapshot().records.size()==2 and (gender.available() if prepared_order.back()=="gender" else portrait.available()),"Actual asynchronous preparation registers each wanted source owner once in completion order")
		check(source_scroll_bounds(portrait),"Controlled scrollbar raster uses actual installed posed rail/thumb layer geometry")
		gender.dismiss();portrait.dismiss();front.surface.hide();check(ui.modal_order.snapshot().records.is_empty(),"Exact early-open retirement leaves no hidden owner before normal frontend use")
	var popup_canvas:=CanvasLayer.new();popup_canvas.layer=101;surface.add_child(popup_canvas)
	var info:=SourcePopup.new();info.configure_mode(true);popup_canvas.add_child(info);info.configure(painter,text,catalog,str(args.report)+".info");info.set_modal_order(ui.modal_order);ui.modal_surfaces.bind_layer(info,popup_canvas);info.start()
	var popup_loaded:=check(await ready(info),"Higher actual source information leaf prepares")
	var gender_calls: Array=[];var portrait_calls: Array=[];var accepted: Array=[false];var reenter: Array=[false]
	var gender_commit: Callable=func(id: int,identity: Array) -> Dictionary:gender_calls.append([id,identity.duplicate()]);return {"accepted":accepted[0],"gender":id,"code":0x8017}
	var portrait_commit: Callable=func(base: String,identity: Array) -> bool:portrait_calls.append([base,identity.duplicate()]);return accepted[0]
	portrait.finished.connect(func(was_accepted,_base,_ticket):
		if was_accepted and reenter[0]:
			reenter[0]=false;front.begin([1003,3],{"classBase":4},[]);front.bind_portraits([1003,3],portrait_choices(71),"p020_",painter.art,catalog,portrait_commit);front.open_child("portraitbutton"))
	if loaded and popup_loaded:
		var identity: Array=[1001,1];front.begin(identity,{"classBase":4},[]);front.bind_gender(identity,0,gender_commit);front.bind_portraits(identity,portrait_choices(71),"p020_",painter.art,catalog,portrait_commit);front.open_child("genderbutton");await frames()
		var gender_ticket: Dictionary=gender.modal_lease.ticket.duplicate(true)
		check(gender.available() and ui.modal_order.admits(gender_ticket),"Frontend logical Gender open activates exact real owner")
		await click(surface,gender.buttons.femalebutton);check(gender.state.selected==1 and gender_calls.is_empty(),"Physical Gender radio changes only private selection")
		await pointer(surface,gender.buttons.okbutton,true);info.position=gender.position;info.set_context({"ready":true,"name":"Higher Gender help","description":"Controlled text"},text,painter.art,[101]);info.open();await frames();await pointer(surface,gender.buttons.okbutton,false)
		check(not gender.available() and gender.held.is_empty() and gender_calls.is_empty() and info.available(),"Higher registered leaf cancels held Gender OK without a commit")
		await click(surface,gender.buttons.malebutton);check(gender.state.selected==1 and gender_calls.is_empty(),"Lower input remains enabled yet cannot select through higher popup")
		await click(surface,info.buttons.closebutton);check(gender.available() and gender.modal_lease.ticket==gender_ticket,"Physical popup Close restores exact Gender lifetime")
		gender.set_context(0,front.ticket);gender.open();check(gender.modal_lease.ticket==gender_ticket,"Same-scope Gender refresh preserves lifetime")
		await pointer(surface,gender.buttons.femalebutton,true);var old_scope: Array=front.ticket.duplicate();front.bind_gender(identity,1,gender_commit);await pointer(surface,gender.buttons.femalebutton,false)
		check(gender.available() and gender.held.is_empty() and gender.modal_lease.ticket!=gender_ticket and gender.modal_lease.ticket.scope==front.ticket and not ui.modal_order.retire(gender_ticket),"Gender scope replacement retires exact held input and old ticket")
		front.gender_result(true,0,old_scope);check(gender_calls.is_empty() and gender.wanted,"Old Gender completion cannot commit into replacement scope")
		await click(surface,gender.buttons.okbutton);check(gender_calls==[[1,identity]] and gender.available(),"Rejected authored Gender commit reopens usable original Controls")
		await click(surface,gender.buttons.cancelbutton);check(not gender.wanted and front.child.is_empty() and ui.modal_order.snapshot().records.is_empty(),"Physical Gender Cancel retires only its exact logical lifetime")
		front.open_child("portraitbutton");await frames();check(await portrait_settled(portrait) and portrait.available() and portrait.cells.size()==24,"Actual Portrait opens bounded pooled cells and settles range completion")
		var portrait_ticket: Dictionary=portrait.modal_lease.ticket.duplicate(true)
		await wheel_at(surface,portrait.viewport);check(portrait.state.position>321,"Physical Portrait wheel scrolls its admitted original viewport")
		portrait.scroll.get_v_scroll_bar().value=0;await frames();var selected_before: String=portrait.state.selected;await pointer(surface,portrait.cells[0].button,true);await wheel_at(surface,portrait.viewport);await pointer(surface,portrait.cells[0].button,false)
		check(portrait.held.is_empty() and portrait.state.selected==selected_before,"Row rebinding still retires held choice identity before the same physical pooled cell represents another portrait")
		portrait.scroll.get_v_scroll_bar().value=0;await frames();await click(surface,portrait.cells[0].button);check(portrait.state.selected=="p000_" and portrait_calls.is_empty(),"Physical original Portrait cell previews without commit")
		await pointer(surface,portrait.buttons.okbutton,true);info.position=portrait.position;info.set_context({"ready":true,"name":"Higher portrait help","description":"Controlled text"},text,painter.art,[102]);info.open();await frames();await pointer(surface,portrait.buttons.okbutton,false)
		var before_position: int=portrait.state.position;await wheel_at(surface,portrait.viewport);await click(surface,portrait.cells[1].button)
		check(not portrait.available() and portrait.held.is_empty() and portrait.state.position==before_position and portrait.state.selected=="p000_" and portrait_calls.is_empty(),"Higher actual popup masks lower Portrait pointer and wheel while cancelling held OK")
		check(not portrait.bar.dragging and not portrait.bar.repeat_clock.active,"Admission loss synchronously stops private Portrait thumb/repeat ownership")
		await click(surface,info.buttons.closebutton);check(portrait.available() and portrait.modal_lease.ticket==portrait_ticket,"Physical popup Close restores exact Portrait lifetime")
		await pointer(surface,portrait.bar.down,true);check(portrait.bar.repeat_clock.active,"Physical original Portrait scrollbar arrow begins its private held repeat")
		var first_repeat_position: int=portrait.state.position;await frames(34);check(portrait.state.position>first_repeat_position,"Held native arrow continues repeating across pooled-row rebindings")
		info.set_context({"ready":true,"name":"Repeat interruption","description":"Controlled text"},text,painter.art,[103]);info.open();await frames();await pointer(surface,portrait.bar.down,false)
		check(not portrait.bar.dragging and not portrait.bar.repeat_clock.active and portrait.held.is_empty(),"New higher owner retires an actually held private scrollbar repeat synchronously")
		await click(surface,info.buttons.closebutton)
		await pointer(surface,portrait.bar.thumb,true);check(portrait.bar.dragging,"Physical original Portrait thumb takes only its private drag ownership")
		var drag_value: int=portrait.state.position;var drag_motion:=InputEventMouseMotion.new();drag_motion.position=portrait.bar.thumb.get_global_transform_with_canvas()*(portrait.bar.thumb.size*0.5)+Vector2(0,-60);drag_motion.global_position=drag_motion.position;drag_motion.button_mask=MOUSE_BUTTON_MASK_LEFT;surface.push_input(drag_motion,true);await frames()
		check(portrait.bar.dragging and portrait.state.position<drag_value,"Physical thumb drag remains active across a pooled-row rebind")
		info.set_context({"ready":true,"name":"Drag interruption","description":"Controlled text"},text,painter.art,[104]);info.open();await frames();await pointer(surface,portrait.bar.thumb,false)
		check(not portrait.bar.dragging and not portrait.bar.repeat_clock.active,"Higher owner cancels an actually held Portrait thumb drag")
		await click(surface,info.buttons.closebutton)
		portrait.set_context(portrait_choices(71),"p020_",front.ticket,painter.art,catalog);portrait.open();await frames();check(await portrait_settled(portrait) and portrait.modal_lease.ticket==portrait_ticket,"Same-scope Portrait refresh retains lifetime through range completion")
		await pointer(surface,portrait.cells[0].button,true);old_scope=front.ticket.duplicate();identity=[1002,2];front.begin(identity,{"classBase":4},[]);front.bind_portraits(identity,portrait_choices(71),"p020_",painter.art,catalog,portrait_commit);front.open_child("portraitbutton");await pointer(surface,portrait.cells[0].button,false);await frames()
		check(await portrait_settled(portrait) and portrait.available() and portrait.held.is_empty() and portrait.state.selected=="p020_" and portrait.modal_lease.ticket!=portrait_ticket and not ui.modal_order.retire(portrait_ticket),"Replacement Portrait scope rejects held cell and old exact ticket")
		front.portrait_result(true,"p000_",old_scope);check(portrait_calls.is_empty() and portrait.wanted,"Old Portrait result cannot commit replacement scope")
		await click(surface,portrait.buttons.okbutton);check(portrait_calls==[["p020_",identity]] and portrait.available(),"Rejected Portrait commit reopens current owner")
		await click(surface,portrait.buttons.cancelbutton);check(not portrait.wanted and ui.modal_order.snapshot().records.is_empty(),"Physical Portrait Cancel retires exact modal lifetime")
		front.open_child("portraitbutton");await frames();accepted[0]=true;reenter[0]=true;await click(surface,portrait.buttons.okbutton)
		check(portrait_calls.size()==2 and portrait.available() and front.scope==[1003,3] and portrait.modal_lease.ticket.scope==front.ticket and ui.modal_order.snapshot().records.size()==1,"Synchronous accepted completion preserves reentrant new Portrait lifetime")
		front.dismiss();check(not portrait.wanted and not gender.wanted and ui.modal_order.snapshot().records.is_empty() and not ui.modal_order.snapshot().membership_available,"Frontend teardown retires exact owners while full coverage remains unavailable")
	info.close();info.free();popup_canvas.free();ui.close();ui.free();painter.close();painter.free();text.close();surface.queue_free();await frames(4)
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Actual Gameplay creator Gender/Portrait factories, installed source geometry, native pointer/wheel and modal lifetime boundaries. Authored choice/commit values and controlled raster/fonts; no full creator rules, original pixels, level-up, server, GPU, build or complete modal coverage acceptance."}
	var file:=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify(result,"  ")+"\n");file.close();print("MODAL_GENDER_PORTRAIT ",JSON.stringify(result));quit(0 if failures.is_empty() else 1)
