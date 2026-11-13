extends "res://tests/native_modal_owner_input_test.gd"
const Table=preload("res://systems/native_data/two_da.gd")
class TestSettings extends Node:
	signal changed
	var applied_scale:=1.0
	var maximum_scale:=2.0
	var error:=""
	var query_ready:=true
	var applies:=0
	var commits:=0
	func current() -> Dictionary:return {"minimum":0.5,"maximum":2.0,"windowed":true,"width":1100,"height":800,"scale":applied_scale}
	func modes() -> Array:return [{"label":"Authored read-only mode"}]
	func apply_choice(value: float) -> bool:
		applied_scale=value;applies+=1;changed.emit();return true
	func commit() -> void:commits+=1
class InputWitness extends Node:
	var movement:=0
	func _unhandled_key_input(event: InputEvent) -> void:
		if event is InputEventKey and event.pressed and event.keycode==KEY_W:movement+=1
func key(surface: SubViewport,code: int) -> void:
	for pressed in [true,false]:
		var event:=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=pressed;surface.push_input(event,true);await frames()
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has_all(["report","install"]) or FileAccess.file_exists(args.report):quit(2);return
	var catalog:=Catalog.new();check(catalog.mount_install(args.install),"Installed Video/Key source resources mount read-only")
	var surface:=SubViewport.new();surface.size=Vector2i(1100,800);surface.disable_3d=true;surface.gui_disable_input=false;surface.handle_input_locally=true;surface.render_target_update_mode=SubViewport.UPDATE_DISABLED;root.add_child(surface);surface.notify_mouse_entered()
	var ui=make_ui(surface,catalog,args.install,args.report)
	var painter:=Painter.new();painter.art=SourceFixture.ControlledArt.new();painter.fonts=ReadyFonts.new();painter.add_child(painter.art);painter.add_child(painter.fonts);surface.add_child(painter)
	check(ui.text.base.open_file(str(args.install).path_join("lang/en/data/dialog.tlk")),"Actual installed TLK captions open")
	ui.key_bindings.install(Table.new().parse(catalog.read_resource("keymap",2017).get_string_from_ascii()),ui.text.base.language)
	check(ui.key_bindings.bindings_ready,"Actual installed Keymap supplies the existing transaction owner")
	var settings:=TestSettings.new();surface.add_child(settings)
	var witness:=InputWitness.new();surface.add_child(witness)
	var menu:=MainMenu.new();surface.add_child(menu);menu.layout_path="";menu.window_settings=settings;menu.key_bindings=ui.key_bindings;menu.playing_query=func():return true;menu.connection_query=func():return true
	menu.set_modal_order(ui.modal_order,ui.modal_surfaces)
	menu.configure_native(painter,ui.text,catalog,str(args.report)+".source-cache",[1,1,55,42]);menu.observe_lobby({"connected":true,"busy":false,"phase":"playing"})
	var video=menu.video_owner;var editor=menu.key_owner
	check(ui.modal_order.snapshot().records.is_empty() and video.modal_lease.ticket.is_empty() and editor.modal_lease.ticket.is_empty(),"Configure/prewarm creates no Video/Key modal membership")
	var loaded:=check(await ready(menu.native_frame) and await ready(video) and await ready(editor),"Actual original menu, Video and Key geometry prepare through existing model workers")
	check(ui.modal_order.snapshot().records.is_empty(),"Asynchronous source completion still creates no modal lifetime")
	var popup_canvas:=CanvasLayer.new();popup_canvas.layer=101;surface.add_child(popup_canvas)
	var info:=SourcePopup.new();info.configure_mode(true);popup_canvas.add_child(info);info.position=Vector2(20,20);info.configure(painter,ui.text,catalog,str(args.report)+".info-cache");info.set_modal_order(ui.modal_order);ui.modal_surfaces.bind_layer(info,popup_canvas);info.start()
	var popup_loaded:=check(await ready(info),"Actual installed information popup prepares independently")
	var wheel:=Wheel.new();surface.add_child(wheel);wheel.set_modal_owner(ui.modal_order,func(id):
		if wheel.request_id!=id:return false
		wheel.reset();return true)
	ui.modal_surfaces.bind_layer(wheel,wheel);wheel.set_process_input(true)
	if loaded and popup_loaded:
		wheel_open(wheel);action_menu(wheel);menu.open(true);await frames()
		check(not wheel.active and wheel.is_processing_input() and menu.modal_lease.admits(),"Logical Options open retires prior radial with its real input processing enabled")
		await click(surface,menu.native_frame.buttons.videooptionsbutton)
		check(video.visible and not menu.panel.visible and video.modal_lease.admits() and video.modal_lease.ticket.owner==video.get_instance_id(),"Physical Video click replaces parent membership with actual Video Control")
		var first: Dictionary=video.modal_lease.ticket.duplicate(true);var rows: Array=ui.modal_order.snapshot().records
		menu.set_modal_order(ui.modal_order,ui.modal_surfaces);video.settings_changed();video.prepared.emit()
		check(video.modal_lease.ticket==first and ui.modal_order.snapshot().records==rows,"Setup/settings/duplicate prepared boundaries never promote or replace an open Video lifetime")
		var before: float=video.pending_scale;await click(surface,video.buttons.intupbutton)
		check(video.pending_scale>before and settings.applies==0,"Actual source scale arrow edits only pending state")
		video.arrow=1;video.held["applybutton"]=video.revision;video.dragging=true
		info.set_context({"ready":true,"name":"Modal fixture","description":"Received help"},ui.text,painter.art,[1]);info.open();await frames()
		check(not video.modal_lease.admits() and video.arrow==0 and video.held.is_empty() and not video.dragging and info.available(),"Higher actual popup synchronously retires only private Video held/repeat/drag input")
		await click(surface,video.buttons.applybutton)
		check(video.visible and info.wanted and settings.applies==0 and not menu.panel.visible,"Physical lower Video Apply cannot act through a live higher popup")
		var escape:=InputEventKey.new();escape.keycode=KEY_ESCAPE;escape.pressed=true;menu._input(escape);menu._unhandled_key_input(escape)
		check(video.visible and not menu.panel.visible and info.wanted,"Hidden parent Escape paths cannot dismiss or reopen a lower Video owner")
		await click(surface,info.buttons.closebutton)
		check(video.modal_lease.admits() and video.modal_lease.ticket==first,"Physical top Close restores the same lower Video lifetime")
		await click(surface,video.buttons.applybutton)
		check(settings.applies==1 and video.applied and video.visible,"Admitted physical Apply retains existing transaction semantics")
		await key(surface,KEY_ESCAPE)
		check(not video.visible and video.modal_lease.ticket.is_empty() and menu.panel.visible and menu.modal_lease.admits() and settings.commits==1,"Physical Escape retires Video, commits already-applied value and restores parent once")
		await click(surface,menu.native_frame.buttons.controlsbutton)
		check(editor.visible and editor.modal_lease.admits() and not menu.panel.visible and ui.key_bindings.valid_transaction(editor.ticket),"Physical Controls click registers actual Key owner and keeps original pending transaction")
		var key_ticket: Dictionary=editor.modal_lease.ticket.duplicate(true)
		await click(surface,editor.buttons.tab1)
		check(editor.page==1 and editor.row_buttons.has("hotbar:0"),"Actual key tab exposes the existing editable hotbar rows")
		var row: Button=editor.row_buttons["hotbar:0"];editor.scroller.scroll_vertical=maxi(0,int(row.position.y-editor.scroller.size.y*0.5));await frames();await click(surface,row)
		check(ui.key_bindings.capturing,"Physical source row enters the existing key capture owner")
		var pending: Dictionary=ui.key_bindings.pending.duplicate(true);var transaction: int=editor.ticket
		info.open();await frames()
		check(not editor.modal_lease.admits() and not ui.key_bindings.capturing and ui.key_bindings.valid_transaction(transaction) and ui.key_bindings.pending==pending,"Higher popup cancels private capture without discarding or committing the key transaction")
		var movement:=witness.movement;await key(surface,KEY_W)
		check(witness.movement==movement+1 and ui.key_bindings.pending==pending,"Off-menu movement still passes and lower Key capture cannot steal or assign it")
		menu._input(escape);menu._unhandled_key_input(escape)
		check(editor.visible and not menu.panel.visible and info.wanted,"Lower Key owner and hidden parent cannot consume higher popup Escape")
		await click(surface,info.buttons.closebutton)
		check(editor.modal_lease.admits() and editor.modal_lease.ticket==key_ticket,"Physical top Close restores the exact Key lifetime")
		await key(surface,KEY_ESCAPE)
		check(not editor.visible and editor.modal_lease.ticket.is_empty() and ui.key_bindings.pending.is_empty() and menu.panel.visible,"Admitted Key Escape preserves original discard and parent return semantics")
		await click(surface,menu.native_frame.buttons.controlsbutton);var stale: Dictionary=editor.modal_lease.ticket.duplicate(true);menu.set_native_scope([2,2,77,99]);await frames()
		check(not editor.visible and editor.modal_lease.ticket.is_empty() and not ui.modal_order.retire(stale) and ui.key_bindings.pending.is_empty(),"Scope retirement invalidates exact old Key lifetime and its pending transaction")
		menu.open(true);await click(surface,menu.native_frame.buttons.videooptionsbutton)
		check(video.modal_lease.ticket!=first and video.modal_lease.ticket.scope==[2,2,77,99],"Reopened Video obtains a fresh exact scope instead of reusing an old ticket")
		check(not ui.modal_order.snapshot().membership_available,"Additional verified owners do not silently claim complete53/2 membership")
	menu.dismiss();menu.detach_native();menu.free();wheel.reset();wheel.free();info.close();info.free();popup_canvas.free();settings.free();witness.free();painter.close();painter.free();ui.close();ui.free();surface.queue_free();await frames(4)
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Actual installed menu/Video/Key and popup geometry, physical pointer/key and existing transaction owners; lower radial input remains enabled; controlled rasters/fonts and authored display-mode provider; no original pixels, server, monitor changes or complete modal membership claim","gameServerConnections":0,"gpu":false,"nativeBuilds":0}
	var file:=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify(result,"  ")+"\n");file.close();print("NATIVE_MODAL_OPTIONS ",JSON.stringify(result));quit(0 if failures.is_empty() else 1)
