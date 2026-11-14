extends SceneTree
const Pregame=preload("res://systems/native_pregame_menu.gd")

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var output:=""
	var install:=""
	var graphical:=false
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
	var settings=preload("res://systems/native_window_settings.gd").new(); root.add_child(settings); settings.configure(root,"")
	var menu:=Pregame.new(); root.add_child(menu)
	menu.configure({"install":install,"modsDirectory":"","disabledMods":[]},ProjectSettings.globalize_path("user://native-prepared-v2"),"",settings)
	menu.open()
	var samples: Array=[]
	var last_state:=""
	var limit_ms:=180000 if graphical else 120000
	var deadline:=Time.get_ticks_msec()+limit_ms
	var result: Dictionary={}
	var saw_icon_bar:=false
	var saw_texture_bar:=false
	var early_menu:=false
	while Time.get_ticks_msec()<deadline:
		await process_frame
		if is_instance_valid(menu.icon_loading_bar) and menu.icon_loading_bar.visible and not is_instance_valid(menu.main): saw_icon_bar=true
		if is_instance_valid(menu.icon_preloader) and not menu.icon_preloader.finished:
			if is_instance_valid(menu.icon_loading_bar) and menu.icon_loading_bar.visible: saw_texture_bar=true
			if is_instance_valid(menu.main) and menu.main.visible: early_menu=true
		if not menu.failure.is_empty(): break
		if not is_instance_valid(menu.main): continue
		var snapshot: Dictionary=menu.main.cohort_snapshot()
		var state:=str(snapshot.get("sealed",false))+":"+str(snapshot.get("models_ready",0))+":"+str(snapshot.get("images_ready",0))+":"+str(snapshot.get("fonts_ready",0))+":"+str(snapshot.get("failures",[]))
		if state!=last_state and (samples.size()<5 or snapshot.ready or not snapshot.failures.is_empty()):
			last_state=state; samples.append({"elapsed_ms":limit_ms-(deadline-Time.get_ticks_msec()),"cohort":snapshot})
		if snapshot.ready and menu.main.visible or not snapshot.failures.is_empty(): break
	if is_instance_valid(menu.main) and menu.main.cohort_snapshot().ready:
		for extra_frame in 4: await process_frame
	var untagged: Array=[]
	if is_instance_valid(menu.main) and menu.main.layout_ready:
		for owner in [menu.main.stage,menu.main.confirmation]:
			for label in owner.find_children("*","Label",true,false):
				if not label.text.is_empty() and str(label.get_meta("native_font_resource","")).is_empty():
					untagged.append({"name":str(label.name),"text":label.text.substr(0,60),"parent":str(label.get_parent().name)})
	var ready: bool=is_instance_valid(menu.main) and bool(menu.main.cohort_snapshot().ready) and is_instance_valid(menu.icon_preloader) and menu.icon_preloader.finished
	var first_visible: bool=ready and bool(menu.main.visible)
	var reopened:=false
	if ready:
		menu.dismiss(); menu.open()
		for extra_frame in 3: await process_frame
		reopened=menu.main.cohort_snapshot().ready and menu.main.visible
	var startup: Dictionary=menu.menu_startup_status()
	result={"success":ready and startup.ready and untagged.is_empty() and first_visible and reopened and saw_icon_bar and saw_texture_bar and not early_menu and int(menu.catalog_stats.get("item_icon_sources",{}).get("completed",0))>5000 and (not graphical or root.get_flag(Window.FLAG_NO_FOCUS) and root.current_screen!=DisplayServer.get_primary_screen()),"menu_failure":menu.failure,"page_failure":menu.main.failure if is_instance_valid(menu.main) else "No page","cohort":menu.main.cohort_snapshot() if is_instance_valid(menu.main) else {},"menu_startup":startup,"untagged_nonempty_labels":untagged,"samples":samples,"elapsed_ms":limit_ms-(deadline-Time.get_ticks_msec()),"graphical":graphical,"no_focus":root.get_flag(Window.FLAG_NO_FOCUS) if graphical else true,"secondary":root.current_screen!=DisplayServer.get_primary_screen() if graphical else true,"page_visible":first_visible,"reopen_ready_visible":reopened,"wanted":menu.wanted,"art_announced":menu.main.art_announced if is_instance_valid(menu.main) else false,"icon_loading_bar_before_menu":saw_icon_bar,"texture_loading_bar_before_menu":saw_texture_bar,"early_menu":early_menu,"icon_sources":menu.catalog_stats.get("item_icon_sources",{}),"icon_textures":menu.icon_preloader.progress() if is_instance_valid(menu.icon_preloader) else {},"shared_rasters":menu.snapshot().get("shared_rasters",{})}
	menu.close()
	settings.close()
	var file:=FileAccess.open(output,FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"  "))
	file.close()
	quit(0 if result.success else 1)
