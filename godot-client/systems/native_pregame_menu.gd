extends Control
# Pregame owns its installed/user-enabled catalog independently of a server.
# No gameplay state, server login, decoded presentation or texture comes from JS.
signal multiplayer_requested
signal client_settings_requested
signal exit_requested
signal button_sound_requested
signal source_ready(painter,text,catalog,cache_path: String)
const Loader=preload("res://systems/native_data/session_catalog.gd")
const IconTextures=preload("res://systems/native_data/ui_icon_texture_preloader.gd")
const SharedRasters=preload("res://systems/native_data/shared_ui_rasters.gd")
const Assets=preload("res://systems/native_data/asset_service.gd")
const Plan=preload("res://systems/native_data/entry_menu_layout.gd")
const Page=preload("res://systems/native_entry_menu_frame.gd")
var loader
var icon_preloader
var catalog
var painter
var text=preload("res://systems/native_data/talk_text.gd").new()
var assets
var bindings
var keys
var video
var main
var options
var status: Label
var icon_loading_bar: ProgressBar
var sources: Dictionary={}
var cache_path:=""
var layout_path:=""
var window_settings
var wanted:=false
var page:="main"
var external_child:=false
var revision:=0
var failure:=""
var closed:=false
var button_audio_ready:=true
var button_audio_failure:=""
var catalog_stats: Dictionary={}
var started_at:=0
var layout_ready_ms:=-1.0
func configure(source: Dictionary,cache: String,layout: String,settings) -> void:
	sources=source.duplicate(true); cache_path=cache; layout_path=layout; window_settings=settings
	started_at=Time.get_ticks_usec()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); mouse_filter=Control.MOUSE_FILTER_IGNORE; hide()
	status=Label.new(); add_child(status); status.text="Preparing menu resources…"; status.position=Vector2(24,24); status.mouse_filter=Control.MOUSE_FILTER_IGNORE
	icon_loading_bar=ProgressBar.new(); add_child(icon_loading_bar); icon_loading_bar.position=Vector2(24,54); icon_loading_bar.custom_minimum_size=Vector2(320,18); icon_loading_bar.size=Vector2(320,18); icon_loading_bar.show_percentage=false; icon_loading_bar.mouse_filter=Control.MOUSE_FILTER_IGNORE; icon_loading_bar.hide()
	loader=Loader.new(); add_child(loader); loader.completed.connect(catalog_ready); loader.start(sources)
	get_viewport().size_changed.connect(place)
func _process(_delta: float) -> void:
	if closed or not wanted: return
	var progress: Dictionary={}
	if is_instance_valid(loader) and loader.task>=0: progress=loader.progress()
	elif is_instance_valid(icon_preloader) and not icon_preloader.finished: progress=icon_preloader.progress()
	if str(progress.get("phase",""))=="catalog":
		if is_instance_valid(icon_loading_bar): icon_loading_bar.max_value=1; icon_loading_bar.value=0; icon_loading_bar.show()
		if is_instance_valid(status): status.text="Preparing resource catalog…"
		return
	if str(progress.get("phase","")) not in ["item-icons","spellbook-icons","item-and-spell-icons"]:
		if not is_instance_valid(icon_preloader) or not icon_preloader.finished: return
		var ui_progress: Dictionary=menu_startup_status()
		if ui_progress.ready: return
		if is_instance_valid(icon_loading_bar): icon_loading_bar.max_value=maxi(1,int(ui_progress.total)); icon_loading_bar.value=int(ui_progress.completed); icon_loading_bar.show()
		if is_instance_valid(status): status.text="Preparing menu UI: %d / %d"%[int(ui_progress.completed),int(ui_progress.total)] if ui_progress.failures.is_empty() else "Menu resources unavailable: "+str(ui_progress.failures[0])
		return
	var completed:=int(progress.get("completed",0)); var total:=int(progress.get("total",0))
	if is_instance_valid(icon_loading_bar):
		icon_loading_bar.max_value=maxi(1,total); icon_loading_bar.value=completed; icon_loading_bar.show()
	if is_instance_valid(status):
		var message:="Preparing icon images: %d / %d"%[completed,total] if str(progress.get("phase",""))=="item-and-spell-icons" else "Loading icon sources: %d / %d"%[completed,total]
		if status.text!=message: status.text=message
func catalog_ready(_serial: int,value: RefCounted,error: String,stats: Dictionary) -> void:
	if closed: return
	if not error.is_empty(): failure=error; status.text="Menu resources unavailable: "+error; return
	catalog=value; catalog_stats=stats
	var install:=str(sources.get("install","")); var language:=str(sources.get("language","en"))
	if not text.base.open_file(install.path_join("lang/"+language+"/data/dialog.tlk")): failure=text.base.failure; status.text=failure; return
	painter=preload("res://systems/native_gui_painter.gd").new(); add_child(painter); painter.configure_source(catalog,cache_path); painter.fonts.bind(status,"fnt_galahad14")
	source_ready.emit(painter,text,catalog,cache_path)
	bindings=preload("res://systems/native_key_bindings.gd").new(); add_child(bindings); bindings.configure(layout_path)
	assets=Assets.new(); add_child(assets); assets.configure(catalog); assets.cache_directory=cache_path; assets.completed.connect(table_ready); assets.request("keymap",2017,"2da")
	main=Page.new(); add_child(main); main.configure(painter,text,catalog,cache_path,"pre_main"); main.action_requested.connect(main_action); main.prepared.connect(refresh); main.start()
	main.artwork_ready.connect(refresh)
	options=Page.new(); add_child(options); options.configure(painter,text,catalog,cache_path,"options_pregame"); options.action_requested.connect(options_action); options.prepared.connect(refresh); options.start()
	options.artwork_ready.connect(refresh)
	keys=preload("res://systems/native_key_settings.gd").new(); add_child(keys); keys.configure(painter,text,catalog,cache_path,bindings,layout_path); keys.prepared.connect(refresh); keys.artwork_ready.connect(refresh); keys.finished.connect(return_options)
	if is_instance_valid(window_settings):
		video=preload("res://systems/native_video_options.gd").new(); add_child(video); video.configure(painter,text,catalog,cache_path,window_settings,layout_path); video.prepared.connect(refresh); video.artwork_ready.connect(refresh); video.finished.connect(return_options)
	icon_preloader=IconTextures.new(); add_child(icon_preloader); icon_preloader.configure(catalog,cache_path)
	icon_preloader.texture_ready.connect(icon_texture_ready); icon_preloader.completed.connect(icon_preload_complete); icon_preloader.start()
	refresh()
func icon_texture_ready(name: String,texture: Texture2D) -> void:
	SharedRasters.retain(catalog,name,texture)
func icon_preload_complete(_stats: Dictionary) -> void:
	refresh()
func menu_startup_status() -> Dictionary:
	var total:=0; var completed:=0; var failures: Array=[]
	for owner in [main,options,keys,video]:
		if owner==null: continue
		total+=1
		if not is_instance_valid(owner): continue
		if owner.has_method("cohort_snapshot"):
			var cohort: Dictionary=owner.cohort_snapshot()
			if bool(cohort.get("ready",false)): completed+=1
			for reason in cohort.get("failures",[]): failures.append(str(reason))
		elif owner.art_ready(): completed+=1
	if is_instance_valid(bindings):
		total+=1
		if bindings.bindings_ready: completed+=1
	return {"ready":total>0 and completed==total and failures.is_empty(),"completed":completed,"total":total,"failures":failures}
func table_ready(_id: int,result: Dictionary) -> void:
	if closed: return
	if not str(result.get("error","")).is_empty(): failure="Keymap: "+str(result.error); refresh(); return
	text.tables.keymap=result.value; bindings.install(result.value); refresh()
func scope() -> Array: return ["pregame",revision]
func open() -> void:
	if closed: return
	revision+=1; wanted=true; page="main"; external_child=false; show(); refresh(); move_to_front()
func set_button_audio_status(ready: bool,reason: String="") -> void:
	if closed:return
	button_audio_ready=ready;button_audio_failure=reason;refresh()
func dismiss() -> void:
	wanted=false; external_child=false; revision+=1
	for view in [main,options]:
		if is_instance_valid(view): view.dismiss()
	if is_instance_valid(keys): keys.retire_scope()
	if is_instance_valid(video): video.retire_scope()
	hide()
func refresh() -> void:
	if closed: return
	var source_loading: bool=is_instance_valid(loader) and loader.task>=0
	var texture_loading: bool=is_instance_valid(icon_preloader) and not icon_preloader.finished
	var menu_status: Dictionary=menu_startup_status() if is_instance_valid(icon_preloader) and icon_preloader.finished else {}
	if is_instance_valid(icon_loading_bar): icon_loading_bar.visible=wanted and (source_loading or texture_loading or not menu_status.is_empty() and not menu_status.ready)
	if not button_audio_failure.is_empty():status.text="Menu sound unavailable: "+button_audio_failure
	elif not failure.is_empty(): status.text="Menu resources unavailable: "+failure
	elif not button_audio_ready:status.text="Preparing menu sound…"
	elif page in ["main","options"]:
		var active=main if page=="main" else options
		if is_instance_valid(active):
			var cohort: Dictionary=active.cohort_snapshot()
			if not cohort.failures.is_empty(): status.text="Menu resources unavailable ("+str(cohort.scope)+"): "+str(cohort.failures[0])
			else: status.text="Preparing menu resources…"
	if is_instance_valid(main):
		var state:=Plan.main_state(main.layout_ready,false,true)
		# Multiplayer-only client mode has no local New/Load workflow. Movies
		# and repository/news remain explicitly unported, rather than inert clicks.
		for tag in state.enabled:
			state.enabled[tag]=state.enabled[tag] and tag in ["multibutton","optionsbutton","exitbutton"]
			state.colors[tag]=Color.WHITE if state.enabled[tag] else Color(0.5,0.5,0.5,1)
		main.set_context(scope(),state.enabled,state.colors)
		for tag in main.buttons:
			if tag not in ["multibutton","optionsbutton","exitbutton"]: main.buttons[tag].tooltip_text="Unavailable in this client build."
		main.visible=wanted and page=="main" and is_instance_valid(icon_preloader) and icon_preloader.finished and bool(menu_status.get("ready",false)) and (button_audio_ready or not button_audio_failure.is_empty())
	if is_instance_valid(options):
		options.set_context(scope(),{"gamebutton":true,"videooptsbutton":is_instance_valid(video) and video.art_ready(),"controlbutton":is_instance_valid(keys) and keys.art_ready() and bindings.bindings_ready,"nwsyncbutton":false,"closebutton":true,"xbutton":true})
		if options.buttons.has("nwsyncbutton"): options.buttons.nwsyncbutton.tooltip_text="Storage management is not available in this client build."
		options.visible=wanted and page=="options" and options.art_ready() and (button_audio_ready or not button_audio_failure.is_empty())
	status.visible=wanted and (not failure.is_empty() or not button_audio_failure.is_empty() or not button_audio_ready or not is_instance_valid(icon_preloader) or not icon_preloader.finished or not bool(menu_status.get("ready",false)) or page=="options" and not options.art_ready())
	if layout_ready_ms<0 and is_instance_valid(main) and main.layout_ready and is_instance_valid(options) and options.layout_ready: layout_ready_ms=(Time.get_ticks_usec()-started_at)/1000.0
	place()
func place() -> void:
	for view in [main,options]:
		if is_instance_valid(view) and view.layout_ready: view.position=((get_viewport_rect().size-view.size)*0.5).max(Vector2.ZERO)
func main_action(tag: String) -> void:
	if closed or not wanted or page!="main" or not button_audio_ready and button_audio_failure.is_empty(): return
	if tag in ["optionsbutton","multibutton","exitbutton"]: button_sound_requested.emit()
	match tag:
		"optionsbutton": revision+=1; page="options"; main.dismiss(); refresh()
		"multibutton": dismiss(); multiplayer_requested.emit()
		"exitbutton": dismiss(); exit_requested.emit()
func options_action(tag: String,from_button: bool=true) -> void:
	if closed or not wanted or page!="options" or not button_audio_ready and button_audio_failure.is_empty(): return
	if tag=="videooptsbutton" and (not is_instance_valid(video) or not video.art_ready()): return
	if tag=="controlbutton" and (not is_instance_valid(keys) or not keys.art_ready()): return
	if from_button and tag in ["closebutton","xbutton","gamebutton","videooptsbutton","controlbutton"]: button_sound_requested.emit()
	match tag:
		"closebutton","xbutton": revision+=1; page="main"; options.dismiss(); refresh()
		"gamebutton": external_child=true; page="client-settings"; options.dismiss(); refresh(); client_settings_requested.emit()
		"videooptsbutton": page="video"; options.dismiss(); refresh(); video.show_page(scope())
		"controlbutton": bindings.install(text.tables.keymap); page="keys"; options.dismiss(); refresh(); keys.show_page(scope())
func return_options() -> void:
	if closed or not wanted or page not in ["keys","video","client-settings"]: return
	external_child=false; page="options"; refresh()
func child_closed() -> bool:
	if not wanted or not external_child: return false
	return_options(); return true
func escape() -> bool:
	if closed or not wanted: return false
	if page=="keys": keys.finish_page(false)
	elif page=="video": video.finish_page()
	elif page=="options": options_action("closebutton",false)
	elif page=="client-settings": return false
	else: dismiss()
	return true
func snapshot() -> Dictionary:
	var workers:=1 if is_instance_valid(loader) and loader.task>=0 else 0
	for owner in find_children("*","Node",true,false):
		if owner.get_script()==Assets: workers+=owner.running.size()
	return {"native_only":true,"wanted":wanted,"page":page,"failure":failure,"closed":closed,"workers_running":workers,"catalog":catalog_stats,"icon_textures":icon_preloader.progress() if is_instance_valid(icon_preloader) else {},"shared_rasters":SharedRasters.snapshot(),"menu_startup":menu_startup_status(),"layout_ready_ms":layout_ready_ms,"main":main.snapshot() if is_instance_valid(main) else {},"options":options.snapshot() if is_instance_valid(options) else {},"keys":keys.snapshot() if is_instance_valid(keys) else {},"video":video.snapshot() if is_instance_valid(video) else {},"full_entry_menu_parity":false,"unported_actions":["New/Load campaign","Movies","repository/news","NWSync Storage","complete modern configuration"]}
func close() -> void:
	if closed: return
	dismiss(); closed=true
	for owner in [main,options,keys,video,bindings,assets,icon_preloader,painter,loader]:
		if is_instance_valid(owner): owner.close()
	if catalog!=null and catalog.has_method("release_ui_assets"): catalog.release_ui_assets()
	text.close(); catalog=null
func _exit_tree() -> void: close()
