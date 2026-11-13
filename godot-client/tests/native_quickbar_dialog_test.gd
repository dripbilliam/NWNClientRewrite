extends "res://tests/native_portrait_chooser_test.gd"
const Desktop=preload("res://systems/native_game_desktop.gd")
const Context=preload("res://systems/native_quickbar_context.gd")
class DialogArt extends HeadlessArt:
	func close() -> void:pass
class Inventory extends RefCounted:
	var frame_skin
class Ui extends RefCounted:
	var text
	var inventory:=Inventory.new()
	var hud_ready:=false
	var key_bindings
var sent: Array=[]
func wait_ready(predicate: Callable,seconds: float=30) -> bool:
	var until:=Time.get_ticks_msec()+int(seconds*1000)
	while not predicate.call() and Time.get_ticks_msec()<until:await process_frame
	return predicate.call()
func key(code: int) -> void:
	for pressed in [true,false]:
		var event:=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=pressed;surface.push_input(event,true);await frames()
func identity(desktop,index: int) -> Dictionary:return {"generation":desktop.generation,"area":desktop.area_id,"actor":desktop.actor_id,"index":index,"binding":desktop.quick_bindings[index].duplicate(true)}
func run() -> void:
	create_timer(85).timeout.connect(func():quit(3))
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has_all(["report","install"]) or FileAccess.file_exists(args.report):quit(2);return
	var catalog:=Catalog.new();check(catalog.mount_install(args.install),"Installed source dialog catalog mounts read-only")
	check(preload("res://systems/native_data/prepared_cache.gd").digest(catalog.get_resource("util_editpopup",2047))=="bca0ac612d83a58193f708a9c26dff1db1c5ba628f88bc5dfafb5f4f28dc2a45","Macro editor uses pinned original UTIL_EDITPOPUP")
	surface=SubViewport.new();surface.size=Vector2i(1100,800);surface.disable_3d=true;surface.render_target_update_mode=SubViewport.UPDATE_DISABLED;surface.handle_input_locally=true;root.add_child(surface);surface.notify_mouse_entered()
	var painter:=Painter.new();var art:=DialogArt.new();var fonts:=HeadlessFonts.new();painter.art=art;painter.fonts=fonts;painter.add_child(art);painter.add_child(fonts);art.loaded.connect(painter.art_loaded);surface.add_child(painter)
	var text:=preload("res://systems/native_data/talk_text.gd").new();check(text.base.open_file(args.install.path_join("lang/en/data/dialog.tlk")),"Original captions and active information text are available")
	text.tables={"skills":{"orderedRows":[{"Name":549,"Description":550,"Icon":"server_skill"}]}}
	var desktop:=Desktop.new();surface.add_child(desktop);desktop.owner_ui=Ui.new();desktop.owner_ui.text=text;desktop.owner_ui.inventory.frame_skin=painter;desktop.rules.text=text;desktop.shortcut_rules.rules=desktop.rules;desktop.art=art
	desktop.actor_id=99;desktop.area_id=7;desktop.generation=1;desktop.objects={99:{"id":99,"objectType":5}}
	for index in 36:desktop.quick_bindings.append({"type":0})
	desktop.quick_bindings[1]={"type":3,"intParam":0};desktop.request.connect(func(value):sent.append(value.duplicate(true)))
	var owner:=Context.new();desktop.add_child(owner);desktop.shortcut_dialogs=owner;owner.configure(desktop,catalog,"")
	check(not owner.edit.started and not owner.information.started and owner.edit.jobs.is_empty() and owner.information.jobs.is_empty(),"Unrelated desktop entry schedules no information or macro preparation")
	var start:=Time.get_ticks_usec();owner.examine(identity(desktop,1),desktop.shortcut_rules.information(desktop.quick_bindings[1]))
	var prepared:=await wait_ready(func():return owner.information.layout_ready)
	var information_prepare_usec:=Time.get_ticks_usec()-start
	check(prepared and owner.information.failure.is_empty(),"Actual original information dialog prepares without GPU/raster publication: "+owner.information.failure)
	if prepared:
		await frames();check(owner.information.wanted and owner.information.title.text==text.raw({"strRef":549}) and owner.information.description.get_parsed_text()==text.raw({"strRef":550}),"Quickslot information displays active skill name and description in the original source controls")
		await click(owner.information.buttons.closebutton);check(owner.scope.is_empty() and not owner.information.wanted and sent.is_empty(),"Physical original Close retires the popup without a server gameplay action")
		owner.examine(identity(desktop,1),desktop.shortcut_rules.information(desktop.quick_bindings[1]));desktop.quick_bindings[1]={"type":0};await frames();check(not owner.information.wanted and owner.scope.is_empty(),"A replaced quickslot closes its information scope")
	start=Time.get_ticks_usec();owner.edit_macro(identity(desktop,4));prepared=await wait_ready(func():return owner.edit.layout_ready)
	var macro_prepare_usec:=Time.get_ticks_usec()-start
	check(prepared and owner.edit.failure.is_empty(),"Actual original macro editor prepares without GPU/raster publication: "+owner.edit.failure)
	if prepared:
		await frames();check(owner.edit.wanted and owner.edit.edit.has_focus() and owner.edit.message.text=="Enter Label" and text.raw({"strRef":6679})=="Enter Label","First lazy macro opening receives the original installed Enter Label caption and editable keyboard focus")
		owner.edit.edit.text="A greeting";await key(KEY_ENTER)
		check(owner.edit.wanted and owner.edit.message.text=="Input Command" and text.raw({"strRef":6628})=="Input Command" and owner.edit.edit.has_focus() and sent.is_empty(),"Physical Enter proceeds to the original Input Command stage without sending a partial macro")
		owner.edit.edit.text="/hello";await click(owner.edit.buttons.okbutton)
		check(sent.size()==1 and sent[-1].kind=="native-quickbar-assign" and sent[-1].index==4 and sent[-1].button=={"type":18,"commandLine":"/hello","commandLabel":"A greeting"},"Physical second-stage OK emits exact native text-macro fields to its originating shortcut")
		check(desktop.quick_bindings[4]=={"type":0} and not owner.edit.wanted and owner.scope.is_empty(),"Macro dialog retires and waits for the private protocol owner's client-layout reflection")
		owner.edit_macro(identity(desktop,4));owner.edit.edit.text="Do not save";await key(KEY_ESCAPE);check(sent.size()==1 and owner.scope.is_empty() and not owner.edit.wanted,"Physical Escape cancels macro creation without a hidden assignment")
		desktop.quick_bindings[4]={"type":18,"commandLine":"/old","commandLabel":"Old label"};owner.edit_macro(identity(desktop,4),"label");await frames()
		check(owner.edit.edit.text=="Old label" and owner.edit.message.text=="Enter Label","Existing macro label edit preserves the received command text and actual installed caption")
		owner.edit.edit.text="New label";await key(KEY_ENTER);check(sent.size()==2 and sent[-1].button=={"type":18,"commandLine":"/old","commandLabel":"New label"},"Label-only Enter changes only the authored label in the typed request")
		owner.edit_macro(identity(desktop,4),"line");owner.edit.edit.text="/new";var old_ticket:=owner.identity();desktop.quick_bindings[4]={"type":40};owner.edited(true,"/new",old_ticket)
		check(sent.size()==2 and owner.scope.is_empty(),"A held old editor result cannot overwrite a changed shortcut")
	owner.close();desktop.close();desktop.free();painter.free();surface.queue_free();await frames(6)
	var file:=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"information_prepare_usec":information_prepare_usec,"macro_prepare_usec":macro_prepare_usec,"sourceArtworkDouble":true,"graphical":false,"scope":"Actual installed CG_SPELLINFO/UTIL_EDITPOPUP and source input/focus/Close/OK/Escape/lifetime with controlled raster/font publication. No GPU waits, original pixels or authoritative server acknowledgements accepted."},"\t"));file.close();quit(0 if failures.is_empty() else 1)
