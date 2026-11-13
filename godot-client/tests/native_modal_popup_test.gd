extends "res://tests/native_modal_late_chat_test.gd"
const Order=preload("res://systems/native_data/modal_order.gd")
const SourcePopup=preload("res://systems/native_feat_popup.gd")
const SourceModal=preload("res://systems/native_source_modal.gd")
const Wheel=preload("res://systems/server_radial.gd")
func frames(count: int=2) -> void:
	for index in count: await process_frame
func click(surface: SubViewport,button: Button) -> void:
	var point:=button.get_global_rect().get_center()
	var motion:=InputEventMouseMotion.new();motion.position=point;motion.global_position=point;surface.push_input(motion,true);await frames()
	for pressed in [true,false]:
		var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed;event.position=point;event.global_position=point;event.button_mask=MOUSE_BUTTON_MASK_LEFT if pressed else 0;surface.push_input(event,true);await frames()
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has_all(["report","install"]) or FileAccess.file_exists(args.report):quit(2);return
	var catalog:=Catalog.new();check(catalog.mount_install(args.install),"Installed original popup models mount read-only")
	var surface:=SubViewport.new();surface.size=Vector2i(1100,800);surface.disable_3d=true;surface.gui_disable_input=false;surface.handle_input_locally=true;surface.render_target_update_mode=SubViewport.UPDATE_DISABLED;root.add_child(surface);surface.notify_mouse_entered()
	var painter:=Painter.new();painter.art=ControlledArt.new();painter.fonts=ControlledFonts.new();painter.add_child(painter.art);painter.add_child(painter.fonts);surface.add_child(painter)
	var ui=make_ui(surface,catalog,args.install,args.report)
	check(ui.desktop.shortcut_dialogs.information.modal_owner_order==ui.modal_order and ui.desktop.shortcut_dialogs.edit.modal_owner_order==null,"Actual Gameplay setup opts in only its real verified nested information owner")
	ui.creator.configure_source(painter,ui.text,catalog,str(args.report)+".creator-cache")
	var parent=ui.creator.source_frontend.feats
	check(parent.info_popup.modal_owner_order==ui.modal_order and parent.group_popup.modal_owner_order==ui.modal_order and parent.modal_owner_order==null,"Actual creation setup binds its two real nested popup owners without classifying CG_FEATS")
	var order:=Order.new()
	var popup_layer:=CanvasLayer.new();popup_layer.layer=101;surface.add_child(popup_layer)
	var wheel:=Wheel.new();surface.add_child(wheel);wheel.set_modal_owner(order,func(id):
		if wheel.request_id!=id:return false
		wheel.reset();return true)
	# Isolate the popup's real input. Global input gating for a lower registered
	# wheel is not enabled or claimed by this membership-only foundation.
	wheel.set_process_input(false)
	wheel_open(wheel);var wheel_ticket: Dictionary=wheel.modal_owner_ticket.duplicate(true)
	var group:=SourcePopup.new();group.configure_mode(false);popup_layer.add_child(group);group.position=Vector2(100,100);group.configure(painter,ui.text,catalog,str(args.report)+".group-cache");group.set_modal_order(order)
	var info:=SourcePopup.new();info.configure_mode(true);popup_layer.add_child(info);info.position=Vector2(200,150);info.configure(painter,ui.text,catalog,str(args.report)+".info-cache");info.set_modal_order(order)
	var scope: Array=[81,3,"popup"];var outcomes: Array=[]
	group.finished.connect(func(accepted,id,ticket):outcomes.append([accepted,id,ticket.duplicate()]))
	group.set_context({"ready":true,"entries":[{"id":72,"name":"Child B"},{"id":73,"name":"Child C"}]},ui.text,painter.art,scope)
	group.start();group.open();info.start()
	check(group.wanted and not group.layout_ready and group.modal_owner_ticket.is_empty() and order.snapshot().records.size()==1,"Wanted popup does not register before actual asynchronous preparation/show")
	var deadline:=Time.get_ticks_msec()+5000
	while (not group.layout_ready or not info.layout_ready) and group.failure.is_empty() and info.failure.is_empty() and Time.get_ticks_msec()<deadline:await process_frame
	var ready:=check(group.layout_ready and info.layout_ready and group.failure.is_empty() and info.failure.is_empty(),"Actual group/information source resources and controls finish within owned bound")
	if ready:
		check(group.resource=="cg_feats_popup" and info.resource=="cg_spellinfo" and group.plan.popup_buttons.has("okbutton") and info.buttons.has("closebutton"),"Two exact source owner modes retain their original distinct controls")
		check(order.snapshot().records.size()==2 and order.snapshot().records.back().kind=="other" and group.modal_owner_ticket.scope==scope,"Asynchronous wanted completion registers only the verified visible leaf")
		order.set_membership_coverage(true) # Complete authored wheel+two-popup graph only.
		check(not order.deactivate_for_panel(16).deactivationRequested and wheel.active,"Actual non-radial popup blocks lower radial close in authored complete graph")
		var original: Dictionary=group.modal_owner_ticket.duplicate(true)
		group.open();group.set_modal_order(order)
		check(group.modal_owner_ticket==original and order.snapshot().records.size()==2,"Repeated current open/setup preserves the exact current popup lifetime")
		await click(surface,group.row_buttons[1]);await click(surface,group.buttons.okbutton)
		check(outcomes==[[true,73,scope]] and not group.wanted and order.snapshot().records.size()==1 and order.snapshot().records[0].ticket==wheel_ticket,"Physical row/OK retires only the popup before delivering its exact scoped outcome")
		group.open();var reopened: Dictionary=group.modal_owner_ticket.duplicate(true)
		check(reopened!=original and not order.retire(original),"Reopened real popup has a new lifetime and rejects its retired ticket")
		info.set_context({"ready":true,"name":"Literal <name>","description":"Fresh active help","icon":""},ui.text,painter.art,[81,3,"info"]);info.open()
		var info_ticket: Dictionary=info.modal_owner_ticket.duplicate(true)
		check(order.snapshot().records.back().ticket==info_ticket and info.title.text=="Literal <name>","Distinct information owner appends as a separate actual modal leaf")
		group.open()
		check(group.modal_owner_ticket==reopened and order.snapshot().records.back().ticket==reopened and order.snapshot().records.size()==3,"Reactivating a lower real popup promotes its same lifetime")
		group.dismiss();await click(surface,info.buttons.closebutton)
		check(not info.wanted and info.modal_owner_ticket.is_empty() and order.snapshot().records.size()==1,"Physical information Close retires itself and leaves the lower wheel")
		group.open();var old_scope_ticket: Dictionary=group.modal_owner_ticket.duplicate(true)
		group.set_context({"ready":true,"entries":[{"id":91,"name":"Replacement"}]},ui.text,painter.art,[82,1,"replacement"]);group.open()
		check(group.modal_owner_ticket!=old_scope_ticket and group.modal_owner_ticket.scope==[82,1,"replacement"] and not order.retire(old_scope_ticket),"Scope replacement retires the old ticket before a new source popup can act")
		for pressed in [true,false]:
			var event:=InputEventKey.new();event.keycode=KEY_ESCAPE;event.physical_keycode=KEY_ESCAPE;event.pressed=pressed;surface.push_input(event,true);await frames()
		check(not group.wanted and outcomes.back()==[false,-1,[82,1,"replacement"]] and order.snapshot().records.size()==1,"Physical Escape retires the exact source popup and preserves its cancellation ticket")
		order.set_membership_coverage(false)
	var unclassified:=SourceModal.new();popup_layer.add_child(unclassified);unclassified.layout_ready=true;unclassified.open()
	check(unclassified.wanted and unclassified.modal_owner_order==null and unclassified.modal_owner_ticket.is_empty(),"Generic source-modal inheritance has no implicit original membership")
	unclassified.close();unclassified.free()
	var retiring:=SourcePopup.new();popup_layer.add_child(retiring);retiring.configure(painter,ui.text,catalog,str(args.report)+".retiring-cache");retiring.set_modal_order(order);retiring.start();retiring.open();retiring.close();await frames()
	check(retiring.closed and retiring.jobs.is_empty() and retiring.modal_owner_ticket.is_empty() and order.snapshot().records.size()==1,"Closing an actual pending popup prevents late worker/show registration")
	retiring.free();group.close();group.free();info.close();info.free();wheel.reset();wheel.free();order.close();ui.close();ui.free();painter.free();surface.queue_free();catalog=null;await frames(4)
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"gpu":false,"servers":0,"scope":"Explicit opt-in actual source Feats group/information modal ownership, original resource worker preparation and physical row/OK/Close/Escape; real Gameplay/nested creation setup. Controlled art/fonts and authored complete fixture graph only. Production coverage remains unavailable/no53/2 radial close; no pixels/server/full modal membership."}
	var file:=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify(result,"  ")+"\n");file.close();print("MODAL_POPUP_RESULT ",JSON.stringify(result));quit(0 if result.success else 1)
