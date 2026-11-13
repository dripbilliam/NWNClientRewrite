extends Control
# Pregame owns its installed/user-enabled catalog independently of a server.
# No gameplay state, server login, decoded presentation or texture comes from JS.
signal multiplayer_requested
signal client_settings_requested
signal exit_requested
signal source_ready(painter,text,catalog,cache_path: String)
const Loader=preload("res://systems/native_data/session_catalog.gd")
const Assets=preload("res://systems/native_data/asset_service.gd")
const Plan=preload("res://systems/native_data/entry_menu_layout.gd")
const Page=preload("res://systems/native_entry_menu_frame.gd")
var loader
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
var catalog_stats: Dictionary={}
var started_at:=0
var layout_ready_ms:=-1.0
func configure(source: Dictionary,cache: String,layout: String,settings) -> void:
	sources=source.duplicate(true); cache_path=cache; layout_path=layout; window_settings=settings
	started_at=Time.get_ticks_usec()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); mouse_filter=Control.MOUSE_FILTER_IGNORE; hide()
	status=Label.new(); add_child(status); status.text="Preparing menu resources…"; status.position=Vector2(24,24); status.mouse_filter=Control.MOUSE_FILTER_IGNORE
	loader=Loader.new(); add_child(loader); loader.completed.connect(catalog_ready); loader.start(sources)
	get_viewport().size_changed.connect(place)
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
	keys=preload("res://systems/native_key_settings.gd").new(); add_child(keys); keys.configure(painter,text,catalog,cache_path,bindings,layout_path); keys.prepared.connect(refresh); keys.finished.connect(return_options)
	if is_instance_valid(window_settings):
		video=preload("res://systems/native_video_options.gd").new(); add_child(video); video.configure(painter,text,catalog,cache_path,window_settings,layout_path); video.prepared.connect(refresh); video.finished.connect(return_options)
	refresh()
func table_ready(_id: int,result: Dictionary) -> void:
	if closed: return
	if not str(result.get("error","")).is_empty(): failure="Keymap: "+str(result.error); refresh(); return
	text.tables.keymap=result.value; bindings.install(result.value); refresh()
func scope() -> Array: return ["pregame",revision]
func open() -> void:
	if closed: return
	revision+=1; wanted=true; page="main"; external_child=false; show(); refresh(); move_to_front()
func dismiss() -> void:
	wanted=false; external_child=false; revision+=1
	for view in [main,options]:
		if is_instance_valid(view): view.dismiss()
	if is_instance_valid(keys): keys.retire_scope()
	if is_instance_valid(video): video.retire_scope()
	hide()
func refresh() -> void:
	if closed: return
	if not failure.is_empty(): status.text="Menu resources unavailable: "+failure
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
		main.visible=wanted and page=="main" and main.art_ready()
	if is_instance_valid(options):
		options.set_context(scope(),{"gamebutton":true,"videooptsbutton":is_instance_valid(video) and video.layout_ready and video.failure.is_empty(),"controlbutton":is_instance_valid(keys) and keys.layout_ready and keys.failure.is_empty() and bindings.bindings_ready,"nwsyncbutton":false,"closebutton":true,"xbutton":true})
		if options.buttons.has("nwsyncbutton"): options.buttons.nwsyncbutton.tooltip_text="Storage management is not available in this client build."
		options.visible=wanted and page=="options" and options.art_ready()
	status.visible=wanted and (not failure.is_empty() or not is_instance_valid(main) or not main.art_ready() or page=="options" and not options.art_ready())
	if layout_ready_ms<0 and is_instance_valid(main) and main.layout_ready and is_instance_valid(options) and options.layout_ready: layout_ready_ms=(Time.get_ticks_usec()-started_at)/1000.0
	place()
func place() -> void:
	for view in [main,options]:
		if is_instance_valid(view) and view.layout_ready: view.position=((get_viewport_rect().size-view.size)*0.5).max(Vector2.ZERO)
func main_action(tag: String) -> void:
	if closed or not wanted or page!="main": return
	match tag:
		"optionsbutton": revision+=1; page="options"; main.dismiss(); refresh()
		"multibutton": dismiss(); multiplayer_requested.emit()
		"exitbutton": dismiss(); exit_requested.emit()
func options_action(tag: String) -> void:
	if closed or not wanted or page!="options": return
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
	elif page=="options": options_action("closebutton")
	elif page=="client-settings": return false
	else: dismiss()
	return true
func snapshot() -> Dictionary:
	var workers:=1 if is_instance_valid(loader) and loader.task>=0 else 0
	for owner in find_children("*","Node",true,false):
		if owner.get_script()==Assets: workers+=owner.running.size()
	return {"native_only":true,"wanted":wanted,"page":page,"failure":failure,"closed":closed,"workers_running":workers,"catalog":catalog_stats,"layout_ready_ms":layout_ready_ms,"main":main.snapshot() if is_instance_valid(main) else {},"options":options.snapshot() if is_instance_valid(options) else {},"keys":keys.snapshot() if is_instance_valid(keys) else {},"video":video.snapshot() if is_instance_valid(video) else {},"full_entry_menu_parity":false,"unported_actions":["New/Load campaign","Movies","repository/news","NWSync Storage","complete modern configuration"]}
func close() -> void:
	if closed: return
	dismiss(); closed=true
	for owner in [main,options,keys,video,bindings,assets,painter,loader]:
		if is_instance_valid(owner): owner.close()
	if catalog!=null and catalog.has_method("release_ui_assets"): catalog.release_ui_assets()
	text.close(); catalog=null
func _exit_tree() -> void: close()
