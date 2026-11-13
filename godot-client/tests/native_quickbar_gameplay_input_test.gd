extends "res://tests/native_portrait_chooser_test.gd"
const Desktop=preload("res://systems/native_game_desktop.gd")
const Gameplay=preload("res://systems/native_gameplay_ui.gd")
const Context=preload("res://systems/native_quickbar_context.gd")
class DialogArt extends HeadlessArt:
	func close() -> void:pass
class TestInventory extends RefCounted:
	var frame_skin
	var closed:=false
	func close() -> void:closed=true;frame_skin.close()
var sent: Array=[]
var chat_sent: Array=[]
var timeline: Array=[]
func key(code: int) -> void:
	for pressed in [true,false]:
		var event:=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=pressed;surface.push_input(event,true);await frames()
func type_command(value: String) -> void:
	for character in value:
		var unicode:=character.unicode_at(0);var physical: int=unicode-32 if unicode>=97 and unicode<=122 else unicode
		for pressed in [true,false]:
			var event:=InputEventKey.new();event.keycode=physical;event.physical_keycode=physical;event.unicode=unicode if pressed else 0;event.pressed=pressed;surface.push_input(event,true);await process_frame
func macro_snapshot(owner,ui) -> Dictionary:
	var focus=surface.gui_get_focus_owner()
	var result: Dictionary={"stage":owner.stage,"scopeValid":not owner.scope.is_empty() and ui.desktop.shortcut_scope_valid(owner.scope),"wanted":owner.edit.wanted,"visible":owner.edit.is_visible_in_tree(),"focused":owner.edit.edit.has_focus(),"chatFocused":ui.chat.entry.has_focus(),"focusClass":focus.get_class() if is_instance_valid(focus) else "","focusPath":str(focus.get_path()) if is_instance_valid(focus) else "","identity":owner.identity(),"editorScope":owner.edit.scope.duplicate(),"text":owner.edit.edit.text,"caption":owner.edit.message.text,"requests":sent.size()}
	if owner.edit.edit.has_method("is_editing"):result.internalEditing=owner.edit.edit.call("is_editing")
	for property in owner.edit.edit.get_property_list():
		if str(property.name)=="keep_editing_on_text_submit":result.keepEditingOnSubmit=owner.edit.edit.get(property.name)
	return result
func run() -> void:
	create_timer(60).timeout.connect(func():quit(3))
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has_all(["report","install"]) or FileAccess.file_exists(args.report):quit(2);return
	var catalog:=Catalog.new();check(catalog.mount_install(args.install),"Installed source macro resources mount read-only")
	surface=SubViewport.new();surface.size=Vector2i(1100,800);surface.disable_3d=true;surface.render_target_update_mode=SubViewport.UPDATE_DISABLED;surface.handle_input_locally=true;root.add_child(surface);surface.notify_mouse_entered()
	var painter:=Painter.new();var art:=DialogArt.new();var fonts:=HeadlessFonts.new();painter.art=art;painter.fonts=fonts;painter.add_child(art);painter.add_child(fonts);art.loaded.connect(painter.art_loaded);surface.add_child(painter)
	var ui:=Gameplay.new();surface.add_child(ui);ui.set_process(false);ui.creator=null;ui.key_bindings=null;ui.inventory=TestInventory.new();ui.inventory.frame_skin=painter
	check(ui.text.base.open_file(args.install.path_join("lang/en/data/dialog.tlk")),"Original source dialog captions open")
	ui.chat=preload("res://systems/server_chat.gd").new();surface.add_child(ui.chat);ui.chat.setup();ui.chat.position=Vector2(0,530);ui.chat.entry.text="UNSUBMITTED_CHAT";ui.chat.request.connect(func(value):chat_sent.append(value.duplicate(true)))
	var desktop:=Desktop.new();ui.add_child(desktop);desktop.set_process(false);ui.desktop=desktop;desktop.owner_ui=ui;desktop.art=art;desktop.rules.text=ui.text;desktop.shortcut_rules.rules=desktop.rules
	desktop.actor_id=99;desktop.area_id=7;desktop.generation=1;desktop.objects={99:{"id":99,"objectType":5}}
	for index in 36:desktop.quick_bindings.append({"type":0})
	desktop.request.connect(func(value):sent.append(value.duplicate(true)))
	var owner:=Context.new();desktop.add_child(owner);desktop.shortcut_dialogs=owner;owner.configure(desktop,catalog,"")
	owner.edit_macro({"generation":1,"area":7,"actor":99,"index":35,"binding":{"type":0}})
	var deadline:=Time.get_ticks_msec()+15000
	while not owner.edit.layout_ready and owner.edit.failure.is_empty() and Time.get_ticks_msec()<deadline:await process_frame
	check(owner.edit.layout_ready and owner.edit.failure.is_empty(),"Actual original macro editor prepares without rendering")
	if owner.edit.layout_ready:
		await frames();check(owner.edit.edit.has_focus() and not ui.chat.entry.has_focus(),"Real Gameplay owner initially leaves focus with Enter Label")
		owner.edit.finished.connect(func(accepted,value,ticket):timeline.append({"event":"finished-after-owner","accepted":accepted,"value":value,"ticket":ticket,"state":macro_snapshot(owner,ui)}))
		owner.edit.edit.text="Native macro";timeline.append({"event":"before-label-enter","state":macro_snapshot(owner,ui)});await key(KEY_ENTER);timeline.append({"event":"after-label-enter","state":macro_snapshot(owner,ui)})
		check(owner.stage=="line" and owner.edit.message.text=="Input Command","Real Gameplay input preserves the original second macro stage")
		check(owner.edit.edit.has_focus() and not ui.chat.entry.has_focus(),"Real Gameplay Enter cannot steal the newly reopened command editor focus")
		check(bool(owner.edit.edit.call("is_editing")),"The reopened command stage retains real LineEdit editing, not only focus")
		owner.edit.edit.text="/tk NATIVE_QUICKBAR_MACRO_ACK";timeline.append({"event":"before-command-enter","state":macro_snapshot(owner,ui)});await key(KEY_ENTER);timeline.append({"event":"after-command-enter","state":macro_snapshot(owner,ui)})
		check(sent.size()==1 and sent[0].kind=="native-quickbar-assign" and sent[0].index==35 and sent[0].button=={"type":18,"commandLabel":"Native macro","commandLine":"/tk NATIVE_QUICKBAR_MACRO_ACK"},"Two real Gameplay Enter events emit the correct scoped macro assignment")
		check(owner.scope.is_empty() and not owner.edit.wanted and owner.edit.held.is_empty() and not ui.chat.entry.has_focus(),"Final macro Enter retires its source scope/held input and does not open chat")
		check(chat_sent.is_empty() and ui.chat.entry.text=="UNSUBMITTED_CHAT","Macro creation cannot submit or clear unrelated chat input")
		owner.edit_macro({"generation":1,"area":7,"actor":99,"index":35,"binding":{"type":0}});owner.edit.edit.text="Typed macro";await key(KEY_ENTER)
		timeline.append({"event":"before-physical-command-typing","state":macro_snapshot(owner,ui)})
		await type_command("typed command");timeline.append({"event":"after-physical-command-typing","state":macro_snapshot(owner,ui)})
		check(owner.edit.edit.text=="typed command","The first and later physical command characters survive the stage transition")
		var before:=sent.size();await key(KEY_ENTER);timeline.append({"event":"after-typed-command-enter","state":macro_snapshot(owner,ui)})
		check(sent.size()==before+1 and sent[-1].button=={"type":18,"commandLabel":"Typed macro","commandLine":"typed command"},"Physically typed second-stage text submits through the real Gameplay owner")
		check(owner.scope.is_empty() and not owner.edit.wanted and chat_sent.is_empty() and ui.chat.entry.text=="UNSUBMITTED_CHAT" and not ui.chat.entry.has_focus(),"Typed-command final Enter closes only its source dialog and preserves unrelated chat")
	ui.close();check(ui.inventory.closed and painter.closed and owner.closed,"Actual Gameplay close retires desktop dialogs, dummy inventory ownership and source painter normally")
	ui.free();painter.free();surface.queue_free();await frames(6)
	var file:=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"timeline":timeline,"sent":sent,"chatSent":chat_sent,"sourceArtworkDouble":true,"graphical":false,"scope":"Actual NativeGameplayUi unhandled-key owner, server chat LineEdit, original UTIL_EDITPOPUP and real two-stage macro controller; controlled raster/fonts, no server/GPU/pixel acceptance."},"\t"));file.close();quit(0 if failures.is_empty() else 1)
