extends SceneTree
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Painter=preload("res://systems/native_gui_painter.gd")
const Video=preload("res://systems/native_video_options.gd")
const Settings=preload("res://systems/native_window_settings.gd")
const Text=preload("res://systems/native_data/talk_text.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var output:=""; var install:=""; var graphical:=false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
		elif arg.begins_with("--install="): install=arg.substr(10)
		elif arg=="--graphical": graphical=true
	if output.is_empty() or FileAccess.file_exists(output) or not install.is_absolute_path(): quit(2); return
	if graphical:
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
	var video:=Video.new(); root.add_child(video)
	if mounted: video.configure(painter,Text.new(),catalog,ProjectSettings.globalize_path("user://native-prepared-v2"),settings,"")
	var deadline:=Time.get_ticks_msec()+30000; var first_ready_before_complete:=false
	while mounted and Time.get_ticks_msec()<deadline and not video.art_ready() and video.failure.is_empty():
		await process_frame
		var cohort: Dictionary=video.cohort_snapshot()
		if video.art_ready() and (cohort.images_ready!=cohort.images_expected or cohort.fonts_ready!=cohort.fonts_expected): first_ready_before_complete=true
	var cohort: Dictionary=video.cohort_snapshot(); var ready: bool=video.art_ready()
	var unrelated_ready:=false; var reopened:=false
	if ready:
		painter.art.waiting["unrelated-video-test"]=[1]; painter.fonts.pending["unrelated-video-test"]=true
		unrelated_ready=video.art_ready()
		painter.art.waiting.erase("unrelated-video-test"); painter.fonts.pending.erase("unrelated-video-test")
		video.show_page([1,1,1,1]); reopened=video.visible and video.art_ready(); video.finish_page()
	var unregistered: Array=[]
	for node in video.find_children("*","TextureRect",true,false):
		if str(node.get_meta("native_gui_art_key","")).is_empty(): unregistered.append({"path":str(node.get_path()),"static":node.get_meta("native_gui_static_image",false),"texture":node.texture!=null})
	var result: Dictionary={"success":mounted and ready and unrelated_ready and reopened and not first_ready_before_complete and cohort.models_ready==cohort.models_expected and cohort.images_ready==cohort.images_expected and cohort.fonts_ready==cohort.fonts_expected,"mounted":mounted,"cohort":cohort,"unrelated_queue_did_not_block":unrelated_ready,"reopened":reopened,"first_ready_before_complete":first_ready_before_complete,"video_failure":video.failure,"unregistered_images":unregistered}
	video.close(); video.free(); painter.close(); painter.free(); settings.free()
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify(result,"  ")); file.close()
	quit(0 if result.success else 1)
