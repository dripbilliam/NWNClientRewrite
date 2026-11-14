extends SceneTree
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Painter=preload("res://systems/native_gui_painter.gd")
const Chat=preload("res://systems/server_chat.gd")
const Hud=preload("res://systems/native_chat_hud.gd")
const TextOwner=preload("res://systems/native_data/talk_text.gd")
class InventoryStub:
	extends RefCounted
	var frame_skin
class UiStub:
	extends Node
	var chat
	var inventory
	var text=TextOwner.new()
	var desktop
	var presentation_enabled:=true
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var install:="";var graphical:=false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--install="):install=arg.trim_prefix("--install=")
		elif arg=="--graphical":graphical=true
	if install.is_empty():quit(2);return
	if graphical:
		root.set_flag(Window.FLAG_NO_FOCUS,true)
		var primary:=DisplayServer.get_primary_screen()
		for screen in DisplayServer.get_screen_count():
			if screen!=primary:root.current_screen=screen;root.position=DisplayServer.screen_get_position(screen)+Vector2i(80,80);break
		root.size=Vector2i(900,700)
	var catalog:=Catalog.new()
	if not catalog.mount_install(install):quit(3);return
	catalog.build_resource_index()
	var painter:=Painter.new();root.add_child(painter);painter.configure_source(catalog,"")
	var ui:=UiStub.new();root.add_child(ui)
	var inventory:=InventoryStub.new();inventory.frame_skin=painter;ui.inventory=inventory
	var host:=Control.new();root.add_child(host);host.size=root.size
	var chat:=Chat.new();host.add_child(chat);chat.setup();ui.chat=chat
	ui.text.base.open_file(install.path_join("lang/en/data/dialog.tlk"))
	var hud:=Hud.new();ui.add_child(hud);hud.configure(ui,catalog,"","")
	var premature:=false
	var deadline:=Time.get_ticks_msec()+60000
	while Time.get_ticks_msec()<deadline and (not hud.layout_ready or hud.art_pending) and hud.art_error.is_empty():
		if is_instance_valid(hud.stage) and hud.stage.visible and hud.art_pending:premature=true
		await process_frame
	var snapshot: Dictionary=hud.art_snapshot()
	var success: bool=graphical and hud.layout_ready and not hud.art_pending and hud.art_error.is_empty() and hud.stage.visible and snapshot.ready and not premature
	var prompt_ready: bool=hud.prompt_background.texture!=null and hud.popup_background.texture!=null and hud.mode_label.get_meta("native_font_applied","")==hud.Plan.FONT
	success=success and prompt_ready
	hud.toggle_modes()
	var popup_ready: bool=hud.popup.visible and hud.popup_background.texture!=null and hud.mode_options.all(func(option):return option.get_meta("native_font_applied","")==hud.Plan.FONT)
	success=success and popup_ready
	var input:="nwn84 input remains"
	chat.entry.text=input
	hud.toggle_modes()
	success=success and chat.entry.text==input
	hud.static_art_keys.append("gui:nwn84_missing")
	hud.frame.art.failed["gui:nwn84_missing"]="Original model is missing"
	hud.art_pending=true;hud.stage.hide();hud.admit_art()
	var missing_explicit: bool=not hud.stage.visible and not hud.art_pending and hud.art_notice.visible and hud.art_notice.text.contains("nwn84_missing")
	success=success and missing_explicit
	print(JSON.stringify({"success":success,"snapshot":snapshot,"prompt_ready":prompt_ready,"popup_ready":popup_ready,"input_preserved":chat.entry.text==input,"premature":premature,"missing_explicit":missing_explicit,"art_error":hud.art_error,"failure":hud.failure}))
	hud.close();hud.free();chat.free();host.free();ui.free();painter.close();painter.free()
	quit(0 if success else 1)
