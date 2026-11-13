extends "res://tests/native_modal_late_chat_test.gd"
const SourceFixture=preload("res://tests/native_skill_description_source_test.gd")
const SourcePopup=preload("res://systems/native_feat_popup.gd")
const Wheel=preload("res://systems/server_radial.gd")
const MainMenu=preload("res://systems/native_main_menu.gd")
const Loading=preload("res://systems/native_loading_screen.gd")
class ReadyFonts extends Node:
	signal loaded(name: String)
	var fonts: Dictionary={}
	var metrics: Dictionary={}
	var bindings: Dictionary={}
	func request(name: String) -> void:
		fonts[name]=ThemeDB.fallback_font;metrics[name]={"height":14.0}
	func bind(control: Control,name: String) -> void:
		request(name);bindings[control.get_instance_id()]=name;control.set_meta("native_font_resource",name);control.set_meta("native_font_applied",name)
		if control is RichTextLabel:control.add_theme_font_override("normal_font",ThemeDB.fallback_font)
		else:control.add_theme_font_override("font",ThemeDB.fallback_font)
	func unbind(control: Control) -> void:bindings.erase(control.get_instance_id())
	func close() -> void:bindings.clear();fonts.clear();metrics.clear()
func frames(count: int=2) -> void:
	for index in count:await process_frame
func pointer(surface: SubViewport,control: Control,pressed: bool) -> void:
	var point:=control.get_global_transform_with_canvas()*(control.size*0.5)
	var event:=InputEventMouseButton.new();event.position=point;event.global_position=point;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed;event.button_mask=MOUSE_BUTTON_MASK_LEFT if pressed else 0;surface.push_input(event,true);await frames()
func click(surface: SubViewport,control: Control) -> void:
	var point:=control.get_global_transform_with_canvas()*(control.size*0.5)
	var motion:=InputEventMouseMotion.new();motion.position=point;motion.global_position=point;surface.push_input(motion,true);await frames()
	await pointer(surface,control,true);await pointer(surface,control,false)
func ready(panel) -> bool:
	var deadline:=Time.get_ticks_msec()+6000
	while not panel.layout_ready and panel.failure.is_empty() and Time.get_ticks_msec()<deadline:await process_frame
	return panel.layout_ready and panel.failure.is_empty()
func action_menu(wheel) -> void:
	wheel.receive({"kind":"action-menu","requestId":wheel.request_id,"menuId":77,"depth":0,"title":"Own callback","entries":[{"slot":0,"label":"Information"}]})
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has_all(["report","install"]) or FileAccess.file_exists(args.report):quit(2);return
	var catalog:=Catalog.new();check(catalog.mount_install(args.install),"Installed source menu/popup models mount read-only")
	var surface:=SubViewport.new();surface.size=Vector2i(1100,800);surface.disable_3d=true;surface.gui_disable_input=false;surface.handle_input_locally=true;surface.render_target_update_mode=SubViewport.UPDATE_DISABLED;root.add_child(surface);surface.notify_mouse_entered()
	var ui=make_ui(surface,catalog,args.install,args.report)
	check(ui.chat_skin.context==null and not ui.modal_radials_bound and is_instance_valid(ui.inventory_windows),"Real Gameplay configure remains safe with late chat and current alternate inventory owner")
	var painter:=Painter.new();painter.art=SourceFixture.ControlledArt.new();painter.fonts=ReadyFonts.new();painter.add_child(painter.art);painter.add_child(painter.fonts);surface.add_child(painter)
	var popup_canvas:=CanvasLayer.new();popup_canvas.layer=101;surface.add_child(popup_canvas)
	var info:=SourcePopup.new();info.configure_mode(true);popup_canvas.add_child(info);info.position=Vector2(220,160);info.configure(painter,ui.text,catalog,str(args.report)+".info-cache");info.set_modal_order(ui.modal_order);ui.modal_surfaces.bind_layer(info,popup_canvas);info.start()
	var prepared:=check(await ready(info),"Actual CG_SPELLINFO geometry and Controls prepare through original model workers")
	var wheel:=Wheel.new();surface.add_child(wheel);wheel.set_modal_owner(ui.modal_order,func(id):
		if wheel.request_id!=id:return false
		wheel.reset();return true)
	ui.modal_surfaces.bind_layer(wheel,wheel);wheel.set_process_input(true)
	if prepared:
		wheel_open(wheel);action_menu(wheel);info.set_context({"ready":true,"name":"External source popup","description":"Received text"},ui.text,painter.art,[1]);info.open()
		check(not wheel.active and info.available(),"External modal activation retires only the exact prior active radial")
		await click(surface,info.buttons.closebutton)
		check(not info.wanted and wheel.is_processing_input(),"Physical installed Close works with lower wheel processing enabled")
		var callback_states: Array=[];var requests: Array=[]
		wheel.request.connect(func(message):
			requests.append(message.duplicate(true))
			if message.kind=="radial-select":
				info.set_context({"ready":true,"name":"Callback popup","description":"Same synchronous owner"},ui.text,painter.art,[2]);info.open();callback_states.append(wheel.active))
		wheel_open(wheel);action_menu(wheel);await click(surface,wheel.buttons[0])
		check(callback_states==[true] and wheel.active and info.available() and not wheel.modal_admitted(),"Actual wheel pointer callback preserves its own live wheel while the new popup owns admission")
		var request_count:=requests.size();await click(surface,info.buttons.closebutton)
		check(not info.wanted and wheel.active and requests.size()==request_count and wheel.modal_admitted(),"Enabled lower wheel does not steal popup mouse/Escape or emit cancellation; exact prior lease resumes")
		wheel.reset();info.set_context({"ready":true,"name":"Unmapped guard","description":"Literal"},ui.text,painter.art,[3]);info.open()
		var unmapped:=Node.new();surface.add_child(unmapped);var ticket: Dictionary=ui.modal_order.activate(unmapped,"other",1)
		check(not ui.modal_surfaces.snapshot().available and popup_canvas.layer==101,"Unmapped registered top suspends projection without boosting known lower popup")
		ui.modal_order.retire(ticket);unmapped.free();info.dismiss()
	var hit_evidence: Dictionary={}
	var menu:=MainMenu.new();surface.add_child(menu);menu.set_modal_order(ui.modal_order,ui.modal_surfaces);menu.configure_native(painter,ui.text,catalog,str(args.report)+".menu-cache",[1,2,3,42]);menu.observe_lobby({"connected":true,"busy":false,"phase":"playing"});menu.open(true)
	var menu_ready:=check(await ready(menu.native_frame),"Actual OPTIONS_MAIN and OKCANCEL installed geometry assembles without raster waits")
	if menu_ready:
		menu.update_native();await frames()
		check(menu.native_frame.visible and menu.modal_lease.admits(),"Actual prepared menu replaces its fallback without duplicating logical lifetime")
		var before: Dictionary=menu.modal_lease.ticket.duplicate(true);menu.update_native();check(menu.modal_lease.ticket==before,"Repeated artwork/text completion does not promote or replace main-menu lifetime")
		ui.examine.process_mode=Node.PROCESS_MODE_ALWAYS;ui.examine.present({"name":{"text":"Server examine"},"description":{"text":"Received details"}});ui.examine.position=Vector2(90,200);await frames()
		check(ui.examine.modal_lease.admits() and ui.examine.get_parent().get_parent().layer>menu.layer and not menu.modal_lease.admits(),"New examine is logically and visibly above the earlier MainMenu despite original baseline10/30")
		var resume: Button=menu.native_frame.buttons.resumegamebutton;var hit_point:=resume.get_global_transform_with_canvas()*(resume.size*0.5)
		var motion:=InputEventMouseMotion.new();motion.position=hit_point;motion.global_position=hit_point;surface.push_input(motion,true);await frames()
		var hovered: Control=surface.gui_get_hovered_control()
		hit_evidence={"point":str(hit_point),"hover":str(hovered.get_path()) if is_instance_valid(hovered) else null,"hoverClass":hovered.get_class() if is_instance_valid(hovered) else null,"examineRect":str(ui.examine.get_global_rect()),"resumeRect":str(resume.get_global_rect()),"mainAdmission":menu.modal_lease.admits(),"examineAdmission":ui.examine.modal_lease.admits()}
		check(is_instance_valid(hovered) and ui.examine.is_ancestor_of(hovered) and not hovered is Button,"Old Resume hit is explicitly inert top Examine content, not its valid Close control")
		await click(surface,menu.native_frame.buttons.resumegamebutton)
		check(menu.panel.visible and ui.examine.visible,"Lower registered menu cannot consume its old button hit behind examine")
		ui.examine.reset();await click(surface,menu.native_frame.buttons.exitbutton)
		check(menu.native_frame.confirmation.visible and menu.native_frame.confirmation_lease.admits() and not menu.modal_lease.admits(),"Physical original Exit opens a distinct confirmation lease sharing the explicit menu surface")
		await click(surface,menu.native_frame.confirm_buttons.cancelbutton)
		check(not menu.native_frame.confirmation.visible and menu.panel.visible and menu.modal_lease.ticket==before and menu.modal_lease.admits(),"Physical original Cancel retires confirmation before restoring the same parent menu")
		var loading:=Loading.new();surface.add_child(loading);loading.begin(7,"Fixture area")
		check(loading.modal_lease.ticket.is_empty(),"Loading can begin before its current Gameplay order exists")
		loading.configure(ui)
		check(loading.modal_lease.admits() and loading.layer>menu.layer,"Existing configure completion adopts displayed loading generation once and projects it above menu")
		loading.dismiss_early();check(loading.active and loading.dismissed and loading.modal_lease.ticket.is_empty() and menu.modal_lease.admits(),"Presentation-only early dismissal retires loading lease without changing world completion")
		loading.begin(8,"Next area");loading.advance(8,{"terrain":true,"player":true,"camera":true})
		check(not loading.active and loading.modal_lease.ticket.is_empty(),"Loading completion retires its exact generation without waiting for another header")
		loading.reset();loading.free()
	menu.dismiss();menu.detach_native();menu.free();info.close();info.free();wheel.reset();wheel.free();popup_canvas.free()
	ui.creator.configure_source(painter,ui.text,catalog,str(args.report)+".creator-cache")
	check(ui.modal_surfaces.owners.has(ui.creator.source_frontend.feats.info_popup.get_instance_id()) and ui.modal_surfaces.owners.has(ui.creator.source_frontend.feats.group_popup.get_instance_id()),"Actual creator factory maps exactly its existing two leaf owners while leaving parent membership unchanged")
	check(not ui.modal_order.snapshot().membership_available,"Current production still reports remaining coverage gaps instead of enabling global53/2")
	ui.close();ui.free();painter.close();painter.free();surface.queue_free();catalog=null;await frames(4)
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"hitEvidence":hit_evidence,"gpu":false,"servers":0,"scope":"Real current Gameplay configure/alternate setup, installed popup/menu/confirmation Controls with enabled lower-wheel pointer dispatch, actual callback guard, explicit cross-layer input/render order, loading late binding and exact creator factory surface mapping. Controlled8px art/fallback fonts, authored received examine and menu state; no original pixel/live-server/full-coverage claim."}
	var file:=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify(result,"  ")+"\n");file.close();print("MODAL_OWNER_INPUT_RESULT ",JSON.stringify(result));quit(0 if result.success else 1)
