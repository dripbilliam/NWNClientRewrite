extends SceneTree
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Lobby=preload("res://systems/character_lobby.gd")
const Painter=preload("res://systems/native_gui_painter.gd")
const Talk=preload("res://systems/native_data/talk_text.gd")
const Preloader=preload("res://systems/native_data/ui_icon_texture_preloader.gd")
const Shared=preload("res://systems/native_data/shared_ui_rasters.gd")
var checks:=0
var failures: Array=[]
var surface: SubViewport
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label); print("FAIL ",label)
func wait_for(predicate: Callable) -> bool:
	var end:=Time.get_ticks_msec()+90000
	while not predicate.call() and Time.get_ticks_msec()<end: await process_frame
	return predicate.call()
func run() -> void:
	var report:=""; var install:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): report=arg.substr(9)
		if arg.begins_with("--install="): install=arg.substr(10)
	var project_cache:=ProjectSettings.globalize_path("res://.cache").simplify_path()
	var report_path:=ProjectSettings.globalize_path("res://").path_join(report).simplify_path()
	if report.is_empty() or install.is_empty() or not report_path.begins_with(project_cache+"/") or FileAccess.file_exists(report_path): quit(2); return
	root.size=Vector2i(1200,800); surface=SubViewport.new(); surface.size=root.size; surface.render_target_update_mode=SubViewport.UPDATE_ALWAYS; surface.gui_disable_input=false; surface.handle_input_locally=true; root.add_child(surface)
	var display:=TextureRect.new(); root.add_child(display); display.texture=surface.get_texture(); display.size=root.size; display.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var base:=Catalog.new(); check(base.mount_install(install),"Installed original chooser content mounts read-only")
	var cache:=ProjectSettings.globalize_path("user://native-prepared-v2")
	var warm:=Preloader.new(); root.add_child(warm); warm.configure(base,cache,["iashsw","is_acidfog"]); warm.texture_ready.connect(func(name,texture):Shared.retain(base,name,texture)); warm.start()
	check(await wait_for(func():return warm.finished) and warm.progress().retained==2 and warm.progress().failed==0,"Installed item and spell rasters prepare before server binding")
	var source: Dictionary=base.raster_location("is_acidfog"); var extension: String="dds" if int(source.get("type",-1))==2033 else "tga"
	var override_dir:=report_path.trim_suffix(".json")+"-overrides"; check(DirAccess.make_dir_recursive_absolute(override_dir)==OK,"Isolated test server override directory is available")
	var original: PackedByteArray=base.get_resource("is_acidfog",int(source.type)); check(not original.is_empty(),"Original spell raster bytes remain available for a selected-source override")
	var file:=FileAccess.open(override_dir.path_join("is_acidfog."+extension),FileAccess.WRITE); file.store_buffer(original); file.close()
	var server:=Catalog.new(); check(server.mount_install(install) and server.mount_directory(override_dir,50000000),"Fake server catalog overlays the selected spell raster on the original install")
	check(Shared.source_key(base,"is_acidfog")!=Shared.source_key(server,"is_acidfog") and Shared.lookup(server,"is_acidfog")==null and Shared.lookup(server,"iashsw")!=null,"Source identity reuses installed raster but isolates the server-selected override")
	var base_text:=Talk.new(); check(base_text.base.open_file(install.path_join("lang/en/data/dialog.tlk")),"Original chooser text opens")
	var base_painter:=Painter.new(); surface.add_child(base_painter); base_painter.configure_source(base,cache)
	var lobby:=Lobby.new(); surface.add_child(lobby); lobby.preferences.open_file(""); var requests: Array=[]; lobby.request.connect(func(message):requests.append(message.duplicate(true))); lobby.prepare_native_frontend(base_painter,base_text,base,cache)
	check(await wait_for(func():return is_instance_valid(lobby.native_chooser) and lobby.native_chooser.art_ready()),"Original chooser frame prepares from installed content")
	var selection:={"phase":"character-selection","connected":true,"canSelect":true,"selected":null,"choices":[{"key":"server:a","label":"Alpha","source":"server","classes":[{"id":0,"level":1}]}]}
	lobby.apply_state({"connection":1,"state":selection})
	check(await wait_for(func():return lobby.native_chooser.visible),"Installed chooser is admitted before the server catalog rebind")
	var server_text:=Talk.new(); server_text.base.open_file(install.path_join("lang/en/data/dialog.tlk"))
	var server_painter:=Painter.new(); surface.add_child(server_painter); server_painter.configure_source(server,cache)
	lobby.configure_native(server_painter,server_text,server,cache,false,["iashsw","is_acidfog","nwn84_missing_server_icon"])
	var icons=lobby.server_icon_preloader
	check(is_instance_valid(icons) and not icons.finished and not lobby.native_chooser.visible and lobby.native_wait.visible,"Active server catalog hides the chooser while override icons prepare")
	check(int(icons.progress().reused)==1 and int(icons.progress().missing)==1 and int(icons.progress().total)==3 and not lobby.native_sync_bar.indeterminate,"Progress distinguishes installed reuse, absent reference and one server override")
	check(await wait_for(func():return icons.finished and lobby.native_chooser.visible),"Chooser admits after all selected server icon outcomes finish")
	var progress: Dictionary=icons.progress()
	check(progress.completed==3 and progress.reused==1 and progress.retained==1 and progress.failed==0 and progress.missing==1,"Server override decodes once while an absent reference is counted explicitly")
	check(Shared.lookup(server,"is_acidfog")!=null and Shared.lookup(server,"is_acidfog")!=Shared.lookup(base,"is_acidfog") and Shared.lookup(server,"iashsw")==Shared.lookup(base,"iashsw"),"Server-selected source wins and unchanged installed texture identity is reused")
	check(lobby.native_chooser.icon_preload_notice.contains("no raster") and lobby.native_chooser.notice.text==lobby.native_chooser.icon_preload_notice,"Chooser surfaces an absent-reference warning after successful admission")
	var warning_notice: String=lobby.native_chooser.icon_preload_notice
	var busy_selection: Dictionary=selection.duplicate(true); busy_selection.busy=true; lobby.apply_state({"connection":1,"state":busy_selection})
	var fatal_dir:=override_dir+"-fatal"; check(DirAccess.make_dir_recursive_absolute(fatal_dir)==OK,"Isolated corrupt server-icon source is available")
	file=FileAccess.open(fatal_dir.path_join("is_light.tga"),FileAccess.WRITE); file.store_buffer(PackedByteArray([1,2,3])); file.close()
	var fatal_catalog:=Catalog.new(); check(fatal_catalog.mount_install(install) and fatal_catalog.mount_directory(fatal_dir,50000000),"Fake server catalog selects a present corrupt override")
	var fatal_painter:=Painter.new(); surface.add_child(fatal_painter); fatal_painter.configure_source(fatal_catalog,cache)
	lobby.configure_native(fatal_painter,server_text,fatal_catalog,cache,false,["is_light"])
	var fatal_icons=lobby.server_icon_preloader
	check(await wait_for(func():return fatal_icons.finished),"Corrupt selected server icon completes with an explicit result")
	check(fatal_icons.progress().failed==1 and not lobby.native_chooser.visible and lobby.native_wait.visible and lobby.native_wait_text.text.contains("unavailable") and not lobby.native_wait_cancel.disabled and not lobby.can_select(),"Present corrupt icon blocks chooser admission and leaves a visible cancel/failure state")
	lobby.native_wait_cancel.pressed.emit()
	check(requests.any(func(message):return message.kind=="lobby-disconnect" and int(message.connection)==1),"Fatal icon preparation permits a scoped disconnect even while the lobby is busy")
	var fatal_progress: Dictionary=fatal_icons.progress(); var fatal_notice: String=lobby.native_wait_text.text
	var old=fatal_icons; var old_generation: int=lobby.server_icon_generation
	lobby.apply_state({"connection":2,"state":{"phase":"connecting","connected":false,"canCancelJoin":true,"choices":[]}})
	check(old.closed and lobby.server_icon_preloader==null and lobby.server_icon_progress.is_empty() and lobby.server_icon_timer.is_stopped() and lobby.server_icon_generation>old_generation,"Reconnect retires server preload jobs, timer, generation and stale progress")
	var diagnostic:={"progress":progress,"warning_notice":warning_notice,"fatal_progress":fatal_progress,"fatal_notice":fatal_notice,"shared":Shared.snapshot(),"base_key":Shared.source_key(base,"is_acidfog"),"server_key":Shared.source_key(server,"is_acidfog")}
	lobby.close_native(); lobby.free(); base_painter.close(); base_painter.free(); server_painter.close(); server_painter.free(); fatal_painter.close(); fatal_painter.free(); base_text.close(); server_text.close(); warm.close(); warm.free(); await process_frame
	check(DirAccess.remove_absolute(override_dir.path_join("is_acidfog."+extension))==OK and DirAccess.remove_absolute(override_dir)==OK,"Selected server override fixture is removed")
	check(DirAccess.remove_absolute(fatal_dir.path_join("is_light.tga"))==OK and DirAccess.remove_absolute(fatal_dir)==OK,"Corrupt server override fixture is removed")
	file=FileAccess.open(report_path,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"diagnostic":diagnostic},"  ")+"\n"); file.close(); quit(0 if failures.is_empty() else 1)
