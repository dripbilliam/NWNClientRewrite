extends SceneTree
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Painter=preload("res://systems/native_gui_painter.gd")
const Menu=preload("res://systems/native_main_menu.gd")
const Settings=preload("res://systems/native_window_settings.gd")
const Text=preload("res://systems/native_data/talk_text.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var output:=""; var install:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
		elif arg.begins_with("--install="): install=arg.substr(10)
	if output.is_empty() or FileAccess.file_exists(output) or not install.is_absolute_path(): quit(2); return
	root.set_flag(Window.FLAG_NO_FOCUS,true)
	var primary:=DisplayServer.get_primary_screen()
	for screen in DisplayServer.get_screen_count():
		if screen!=primary:
			root.current_screen=screen
			root.position=DisplayServer.screen_get_position(screen)+Vector2i(80,80)
			break
	root.size=Vector2i(1000,760)
	var catalog:=Catalog.new(); var mounted: bool=catalog.mount_install(install)
	var painter:=Painter.new(); root.add_child(painter)
	if mounted: painter.configure_source(catalog,ProjectSettings.globalize_path("user://native-prepared-v2"))
	var settings:=Settings.new(); root.add_child(settings); settings.configure(root,output+".settings.cfg")
	var menu:=Menu.new(); root.add_child(menu); menu.window_settings=settings; menu.layout_path=""
	if mounted: menu.configure_native(painter,Text.new(),catalog,ProjectSettings.globalize_path("user://native-prepared-v2"),[1,1,1,1])
	menu.observe_lobby({"connected":true,"busy":false,"phase":"playing"}); menu.open(true)
	var video=menu.video_owner
	var early_disabled: bool=is_instance_valid(video) and not video.art_ready() and not menu.native_frame.enabled.get("videooptionsbutton",false)
	menu.native_action("videooptionsbutton")
	var early_rejected: bool=is_instance_valid(video) and not video.visible and menu.panel.visible
	var deadline:=Time.get_ticks_msec()+30000
	while mounted and Time.get_ticks_msec()<deadline and (not video.art_ready() or not menu.native_frame.enabled.get("videooptionsbutton",false)):
		await process_frame
	var cohort: Dictionary=video.cohort_snapshot() if is_instance_valid(video) else {}
	var ready: bool=is_instance_valid(video) and video.art_ready() and menu.native_frame.enabled.get("videooptionsbutton",false)
	var opened:=false; var restored:=false
	if ready:
		menu.native_action("videooptionsbutton")
		opened=video.visible and not menu.panel.visible
		video.finish_page(); restored=not video.visible and menu.panel.visible and menu.native_frame.enabled.get("videooptionsbutton",false)
	var failure_disabled:=false; var failure_rejected:=false; var recovered:=false
	if restored:
		for node in video.find_children("*","TextureRect",true,false):
			var key:=str(node.get_meta("native_gui_art_key",""))
			if key.is_empty(): continue
			var texture: Texture2D=node.texture
			node.texture=null; painter.art.failed[key]=true; menu.update_native()
			failure_disabled=not menu.native_frame.enabled.get("videooptionsbutton",false)
			menu.native_action("videooptionsbutton")
			failure_rejected=not video.visible and menu.panel.visible
			painter.art.failed.erase(key); node.texture=texture; menu.update_native()
			recovered=menu.native_frame.enabled.get("videooptionsbutton",false)
			break
	var result: Dictionary={"success":mounted and early_disabled and early_rejected and ready and opened and restored and failure_disabled and failure_rejected and recovered and root.get_flag(Window.FLAG_NO_FOCUS) and root.current_screen!=primary,"mounted":mounted,"early_disabled":early_disabled,"early_rejected":early_rejected,"ready":ready,"opened":opened,"restored":restored,"failure_disabled":failure_disabled,"failure_rejected":failure_rejected,"recovered":recovered,"cohort":cohort,"video_failure":video.failure if is_instance_valid(video) else "No video owner","no_focus":root.get_flag(Window.FLAG_NO_FOCUS),"secondary":root.current_screen!=primary}
	menu.detach_native(); menu.free(); painter.close(); painter.free(); settings.free()
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify(result,"  ")); file.close()
	quit(0 if result.success else 1)
