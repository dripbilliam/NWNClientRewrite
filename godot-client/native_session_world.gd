extends "res://native_live_world.gd"
# User-directed browser/character controls around the direct native renderer.
# This entry never accepts GLB scenes, image URLs or prepared JS rig data.
const Browser=preload("res://systems/server_browser.gd")
const Lobby=preload("res://systems/character_lobby.gd")
const RenderSettings=preload("res://systems/native_render_settings.gd")
const MainMenu=preload("res://systems/native_main_menu.gd")
const ParticleVisibility=preload("res://systems/native_render/particle_visibility.gd")
const MaterialPrewarm=preload("res://systems/native_render/material_prewarm.gd")
var render_settings
var entity_inspector
var render_menu
var login_profiles
var login_profiles_layer
var window_settings
var ui_preload
var render_settings_layer: CanvasLayer
var particle_visibility
var material_prewarm
var asset_prework
var prework_discovery
var prework_choices: Array=[]
var prework_sources_configured:=false
var current_prework_sources: Dictionary={}
var settings_at:=0
var server_browser
var character_lobby
var lobby_pages_probe
var lobby_pages_probe_started:=false
var local_delete_probe
var local_delete_probe_started:=false
var test_lobby_participant: Dictionary={}
var character_preview_receipt:=""
var character_preview_probe
var chooser_ready_connection:=-1
var fixture_filter_connection:=-1
var session_connection:=0
var pending_creator:=false
var loading_announced:=false
var raw_world: Dictionary={}
var raw_serial:=-1
var accepted_raw_serial:=-1
var cancelled_connection:=-1
var return_to_browser:=false
var return_to_main_menu:=false
var catalog_retirement
var replay_view: Dictionary={}
var test_barter_peer: Dictionary={}
var export_receipt_serial:=0
func send(value: Dictionary) -> void:
	var scoped:=value.duplicate()
	if not scoped.has("connection"): scoped.connection=session_connection
	if str(scoped.get("kind",""))=="observed":
		scoped.nativeProcessId=OS.get_process_id()
		if is_instance_valid(particle_visibility): scoped.particle_visibility=particle_visibility.snapshot()
	if str(scoped.get("kind","")) in ["observed","catalog-ready"] and args.get("recording","")=="true":
		scoped.nativeView={"connection":session_connection,"position":[0,0,0],"quaternion":[0,0,0,1],"size":[root.size.x,root.size.y],"particles":render_settings.particles_enabled,"particle_collision":render_settings.particle_collision_enabled,"gore":render_settings.gore}
		if is_instance_valid(camera): scoped.nativeView.merge({"position":[camera.position.x,camera.position.y,camera.position.z],"quaternion":[camera.quaternion.x,camera.quaternion.y,camera.quaternion.z,camera.quaternion.w],"camera_state":controller.remembered_pose(),"fov":camera.fov,"near":camera.near,"far":camera.far})
	super.send(scoped)
func accept_connection(message: Dictionary) -> bool:
	var value: Variant=message.get("connection")
	if not (value is int or value is float) or not is_finite(float(value)) or float(value)!=floor(float(value)) or value<0:
		fail("Native protocol message has no valid connection scope"); return false
	var incoming:=int(value)
	if incoming<session_connection:
		report.stale_session_messages=int(report.get("stale_session_messages",0))+1
		return false
	if incoming>session_connection:
		if str(message.get("kind","")) not in ["lobby","session-reset"]:
			fail("Native protocol connection advanced without a lobby/reset boundary"); return false
		reset_session(); session_connection=incoming; cancelled_connection=-1
		if is_instance_valid(server_browser): server_browser.connection=incoming
	if incoming==cancelled_connection and str(message.get("kind","")) not in ["lobby","session-reset","notice","browser-open","browser-view","browser-closed","browser-notice","browser-profile-result","login-profiles-view","login-profiles-notice","finish","finish-ack"]:
		report.cancelled_session_messages=int(report.get("cancelled_session_messages",0))+1
		return false
	return true
func run() -> void:
	print("NATIVE_SESSION_START")
	super.run()
	print("NATIVE_SESSION_PROTOCOL_OPEN ",host!=null)
	if closing or host==null: return
	catalog_retirement=WorldRetirement.new(); host.add_child(catalog_retirement)
	root.title="NWN · Native Godot"
	if args.get("recording","")=="true":
		var banner_layer:=CanvasLayer.new(); banner_layer.layer=120; host.add_child(banner_layer)
		var banner:=Label.new(); banner.text="RECORDING AREA LOADS · Quit through Main Menu when finished"; banner.position=Vector2(12,40); banner.add_theme_color_override("font_color",Color.YELLOW); banner.add_theme_color_override("font_outline_color",Color.BLACK); banner.add_theme_constant_override("outline_size",5); banner.mouse_filter=Control.MOUSE_FILTER_IGNORE; banner_layer.add_child(banner)
	particle_visibility=ParticleVisibility.new(); host.add_child(particle_visibility)
	render_settings_layer=CanvasLayer.new(); render_settings_layer.layer=31; host.add_child(render_settings_layer)
	login_profiles_layer=CanvasLayer.new(); login_profiles_layer.layer=60; host.add_child(login_profiles_layer)
	login_profiles=preload("res://systems/native_login_profiles.gd").new(); login_profiles_layer.add_child(login_profiles); login_profiles.setup(str(args.get("menu-layout","user://native-menu-layout.cfg"))); login_profiles.request.connect(send)
	render_settings=RenderSettings.new(); render_settings_layer.add_child(render_settings)
	render_settings.setup(str(args.get("render-preferences","user://native-options.cfg")),str(args.get("menu-layout","user://native-menu-layout.cfg")),args.get("profile","")=="true",str(args.get("static-parts","")),str(args.get("profile","")))
	window_settings=preload("res://systems/native_window_settings.gd").new(); host.add_child(window_settings); window_settings.configure(root,str(args.get("render-preferences","user://native-options.cfg")))
	asset_prework=preload("res://systems/native_prework_process.gd").new(); host.add_child(asset_prework); asset_prework.changed.connect(render_settings.update_prework)
	ui_preload=preload("res://systems/native_ui_preload.gd").new(); host.add_child(ui_preload); ui_preload.changed.connect(render_settings.update_ui_preload)
	render_settings.ui_preload_requested.connect(start_ui_preload)
	render_settings.ui_preload_cancel_requested.connect(ui_preload.cancel)
	asset_prework.set_workers(render_settings.prework_worker_setting)
	render_settings.prework_workers_changed.connect(asset_prework.set_workers)
	render_settings.prework_folder_requested.connect(func():
		var path:=ProjectSettings.globalize_path(str(args.get("prepared-cache","user://native-prepared-v2")))
		asset_prework.view_saved_files(path))
	render_settings.prework_requested.connect(start_asset_prework)
	render_settings.prework_cancel_requested.connect(asset_prework.cancel)
	render_settings.prework_clear_requested.connect(func():
		if ui_preload.state.active: return
		var path:=ProjectSettings.globalize_path(str(args.get("prepared-cache","user://native-prepared-v2")))
		asset_prework.clear_saved(path))
	prework_discovery=preload("res://systems/native_data/prework_sources.gd").new(); host.add_child(prework_discovery)
	prework_discovery.completed.connect(func(choices: Array,error: String):
		prework_choices=choices; refresh_prework_sources()
		if not error.is_empty() and not asset_prework.state.active: render_settings.prework_status.text=error)
	prework_sources_configured=ticket.has("preworkSources")
	prework_discovery.start(ticket.get("preworkSources",{}))
	render_settings.particles_changed.connect(particle_visibility.set_enabled)
	render_settings.particle_collision_changed.connect(particle_visibility.set_collision_enabled)
	host.set_meta("native_gore",render_settings.gore)
	render_settings.gore_changed.connect(func(value):host.set_meta("native_gore",value))
	render_settings.creature_slots_changed.connect(func(on):
		if is_instance_valid(gameplay_ui): gameplay_ui.inventory.ui.creature_slots=on; gameplay_ui.inventory.signature="")
	particle_visibility.set_enabled(render_settings.particles_enabled)
	particle_visibility.set_collision_enabled(render_settings.particle_collision_enabled)
	render_settings.profiling_changed.connect(set_profiling)
	entity_inspector=preload("res://systems/native_entity_inspector.gd").new(); render_settings_layer.add_child(entity_inspector)
	entity_inspector.setup(func():return {"world":world,"generation":epoch},object_name,str(args.report).trim_suffix(".json"),str(args.get("menu-layout","user://native-menu-layout.cfg")))
	render_settings.entity_inspector_requested.connect(open_entity_inspector)
	set_profiling(render_settings.profiling_enabled)
	material_prewarm=MaterialPrewarm.new(); host.add_child(material_prewarm)
	material_prewarm.start(str(args.get("material-prewarm","true"))=="true" and DisplayServer.get_name()!="headless")
	report.material_prewarm=material_prewarm.stats
	render_menu=MainMenu.new(); host.add_child(render_menu); render_menu.layout_path=str(args.get("menu-layout","user://native-menu-layout.cfg"))
	render_menu.client_theme_changed.connect(func(value):
		if is_instance_valid(server_browser): server_browser.panel.theme=value)
	render_menu.window_settings=window_settings
	if ticket.get("preworkSources") is Dictionary:
		render_menu.configure_pregame(ticket.preworkSources,ProjectSettings.globalize_path(str(args.get("prepared-cache","user://native-prepared-v2"))))
	render_menu.playing_query=func(): return is_instance_valid(world)
	render_menu.connection_query=func(): return character_lobby.state.get("connected",false) or character_lobby.state.get("canCancelJoin",false)
	render_menu.escape_override=func():
		if is_instance_valid(login_profiles) and login_profiles.visible: login_profiles.close_panel(); return true
		if is_instance_valid(entity_inspector) and entity_inspector.visible: entity_inspector.hide(); return true
		if render_settings.visible: render_settings.hide(); return true
		if is_instance_valid(server_browser) and server_browser.wanted: return server_browser.escape()
		if is_instance_valid(character_lobby) and (character_lobby.state.get("canCancelJoin",false) or loading_announced): cancel_loading(); return true
		return false
	render_menu.options_requested.connect(open_render_settings)
	render_settings.visibility_changed.connect(func():
		if not render_settings.visible: render_menu.child_closed())
	render_menu.exit_requested.connect(shutdown)
	render_menu.disconnect_requested.connect(func(): return_to_main_menu=true; request_disconnect(false))
	render_menu.export_requested.connect(func(): lobby_request({"kind":"lobby-export"}))
	server_browser=Browser.new(); host.add_child(server_browser)
	server_browser.login_profiles_requested.connect(open_login_profiles)
	render_settings.login_profiles_requested.connect(open_login_profiles)
	if is_instance_valid(render_menu.pregame): render_menu.pregame.source_ready.connect(server_browser.configure_native)
	character_lobby=Lobby.new(); host.add_child(character_lobby)
	character_lobby.local_catalog.configure(ticket.get("localCharacterRoots",[]))
	character_lobby.preferences.open_file(str(args.get("lobby-preferences","user://native-character-lobby.cfg")))
	# Normal launches use the original source-defined character chooser.
	# The former redesign is retained only for explicit diagnostic comparisons.
	if args.get("modern-picker","")=="true":
		character_lobby.enable_picker()
		if is_instance_valid(render_menu.pregame): render_menu.pregame.source_ready.connect(character_lobby.picker.configure_base)
	elif is_instance_valid(render_menu.pregame) and args.get("local-ui-check","")!="true":
		character_lobby.native_frontend=true
		render_menu.pregame.source_ready.connect(character_lobby.prepare_native_frontend)
	character_lobby.configure_preview(str(args.get("preview-directory","")))
	server_browser.request.connect(send)
	character_lobby.request.connect(lobby_request)
	render_menu.multiplayer_requested.connect(func():
		if character_lobby.state.get("connected",false) or character_lobby.state.get("busy",false): character_lobby.panel.show()
		else: server_browser.open(true,true))
	character_lobby.creation_requested.connect(func(): pending_creator=true; character_lobby.message.text="Preparing character resources…")
	server_browser.closed.connect(server_browser_closed)
	label.text="Native renderer · choose a server"
func open_login_profiles() -> void:
	var player: String=server_browser.name_edit.text if is_instance_valid(server_browser) else ""
	login_profiles.open(player,session_connection)
func server_browser_closed() -> void:
	# A retired connection has no character-selection surface to return to.
	if server_browser.return_to_main or not character_lobby.state.get("connected",false) and not character_lobby.state.get("canCancelJoin",false):
		character_lobby.panel.hide(); label.text=""; render_menu.open(false)
	else: character_lobby.panel.show()
func open_startup_menu() -> void:
	if is_instance_valid(world): return
	if server_browser.wanted: server_browser.close()
	character_lobby.panel.hide(); render_menu.open(false); label.text=""
	var ui=render_menu.pregame; var deadline:=Time.get_ticks_msec()+10000
	while not closing and Time.get_ticks_msec()<deadline and is_instance_valid(ui) and ui.failure.is_empty() and (not is_instance_valid(ui.main) or not ui.main.layout_ready or DisplayServer.get_name()!="headless" and not ui.main.art_ready()): await process_frame
	if closing: return
	if is_instance_valid(ui): ui.refresh()
	var ready: bool=is_instance_valid(ui) and ui.failure.is_empty() and is_instance_valid(ui.main) and ui.main.layout_ready and (DisplayServer.get_name()=="headless" or ui.main.art_ready())
	report.startup_menu={"ready":ready,"mainVisible":ready and ui.main.is_visible_in_tree(),"browserHidden":not server_browser.wanted,"lobbyHidden":not character_lobby.panel.visible}
	send({"kind":"main-menu-observed","ready":ready,"mainVisible":report.startup_menu.mainVisible,"browserHidden":report.startup_menu.browserHidden,"lobbyHidden":report.startup_menu.lobbyHidden})
	if ready: print("NATIVE_STARTUP_MAIN_MENU_READY")
func open_render_settings() -> void:
	refresh_prework_sources()
	render_settings.show(); render_settings.move_to_front()
func open_game_options() -> void:
	if render_settings.visible: render_settings.hide()
	render_menu.open(is_instance_valid(world))
func refresh_prework_sources() -> void:
	render_settings.set_prework_sources(prework_choices.map(func(choice):return str(choice.label)),initialized and not closing)
func start_asset_prework() -> void:
	if closing or ui_preload.state.active: return
	refresh_prework_sources()
	var selected: int=render_settings.prework_content.selected
	var cache_path:=ProjectSettings.globalize_path(str(args.get("prepared-cache","user://native-prepared-v2")))
	var all_models: bool=render_settings.prework_scope.selected==1
	asset_prework.model_limit=int(args.get("prework-check-limit",0))
	asset_prework.extra_variants=preload("res://systems/native_data/prework_store.gd").known_requests(catalog) if initialized else []
	if initialized and selected==0:
		if not current_prework_sources.is_empty(): asset_prework.start_sources(current_prework_sources,cache_path,all_models)
		return
	var index: int=selected-(1 if initialized else 0)
	if index>=0 and index<prework_choices.size(): asset_prework.start_sources(prework_choices[index].sources,cache_path,all_models)
func start_ui_preload() -> void:
	if closing or asset_prework.state.active: return
	refresh_prework_sources()
	var selected: int=render_settings.ui_preload_content.selected
	var cache_path:=ProjectSettings.globalize_path(str(args.get("prepared-cache","user://native-prepared-v2")))
	ui_preload.capture_opened=initialized and selected==0
	if initialized and selected==0:
		if not current_prework_sources.is_empty(): ui_preload.start_sources(current_prework_sources,cache_path)
		return
	var index:=selected-(1 if initialized else 0)
	if index>=0 and index<prework_choices.size(): ui_preload.start_sources(prework_choices[index].sources,cache_path)
func open_entity_inspector() -> void:
	render_settings.hide(); render_menu.panel.hide()
	entity_inspector.theme=render_settings.theme; entity_inspector.open()
func set_profiling(value: bool) -> void:
	if value and not is_instance_valid(frame_profile):
		frame_profile=FrameProfile.new(); host.add_child(frame_profile); frame_profile.configure(root); frame_profile.control_file=str(args.get("profile-control","")); frame_profile.control.connect(profile_control)
		report.frame_profile_summary=frame_profile.summary_stats
	if is_instance_valid(frame_profile): frame_profile.set_enabled(value)
func _profile_tick() -> void:
	super._profile_tick()
	# Connection/chooser/loading owners already present their own statuses.
	# Keep the diagnostic overlay opt-in and out of pregame screens.
	if is_instance_valid(label): label.visible=is_instance_valid(world) and FrameProfile.enabled
	if initialized and is_instance_valid(gameplay_ui) and not closing and is_instance_valid(character_lobby):
		if not character_lobby.native_frontend: character_lobby.configure_confirmation(gameplay_ui.inventory.frame_skin,gameplay_ui.text,catalog,ProjectSettings.globalize_path(str(args.get("prepared-cache","user://native-prepared-v2"))))
		if is_instance_valid(character_lobby.picker): character_lobby.picker.configure_source(gameplay_ui.text,catalog,ProjectSettings.globalize_path(str(args.get("prepared-cache","user://native-prepared-v2"))))
		if not is_instance_valid(character_lobby.picker) or character_lobby.picker.details_page>=0:
			character_lobby.configure_native(gameplay_ui.inventory.frame_skin,gameplay_ui.text,catalog,ProjectSettings.globalize_path(str(args.get("prepared-cache","user://native-prepared-v2"))))
	elif not closing and not initialized and is_instance_valid(character_lobby) and character_lobby.native_frontend and is_instance_valid(render_menu.pregame) and render_menu.pregame.catalog!=null and is_instance_valid(render_menu.pregame.painter):
		character_lobby.prepare_native_frontend(render_menu.pregame.painter,render_menu.pregame.text,render_menu.pregame.catalog,ProjectSettings.globalize_path(str(args.get("prepared-cache","user://native-prepared-v2"))))
	if not closing and args.get("local-ui-check","")=="true" and is_instance_valid(character_lobby) and is_instance_valid(character_lobby.native_chooser):
		var chooser=character_lobby.native_chooser
		if chooser.layout_ready and chooser.is_visible_in_tree() and character_lobby.can_select() and character_lobby.needs_local_metadata() and chooser.row_keys.is_empty() and not chooser.pregen.disabled and not chooser.show_pregenerated and fixture_filter_connection!=character_lobby.connection:
			fixture_filter_connection=character_lobby.connection; expose_local_fixture(chooser,fixture_filter_connection)
		if chooser.layout_ready and chooser.is_visible_in_tree() and character_lobby.connection!=chooser_ready_connection and character_lobby.can_select() and chooser.automatic_selection.is_empty() and character_lobby.native_selection.is_empty() and not chooser.row_keys.is_empty() and character_lobby.state.get("selected")==chooser.row_keys[0]:
			chooser_ready_connection=character_lobby.connection
			report.native_chooser_ready={"connection":chooser_ready_connection,"key":character_lobby.state.selected,"firstKey":chooser.row_keys[0],"unadmitted":not is_instance_valid(world)}
			send({"kind":"native-chooser-ready"}.merged(report.native_chooser_ready))
	if not closing and args.get("actions-check","")=="true" and (args.get("lobby-pages-check","")!="true" or report.get("lobby_pages",{}).get("success",false)) and is_instance_valid(character_lobby) and is_instance_valid(gameplay_ui) and is_instance_valid(character_lobby.native_chooser) and character_lobby.native_chooser.layout_ready and character_lobby.native_chooser.record.is_visible_in_tree() and character_lobby.state.get("canSelect",false) and character_lobby.state.get("selected")==args.get("preview-check-key",""):
		var preview: Dictionary=character_lobby.record_preview() if character_lobby.record_preview() is Dictionary else {}
		var source: Dictionary=character_lobby.state.get("preview",{}) if character_lobby.state.get("preview") is Dictionary else {}
		var receipt:=str([session_connection,character_lobby.state.get("selected"),source.get("sha256",""),character_lobby.native_chooser.get_instance_id()])
		if preview.get("native_only",false) and not source.get("sha256","").is_empty() and receipt!=character_preview_receipt:
			var identity: Array=[session_connection,character_lobby.state.get("selected"),str(source.sha256)]
			if is_instance_valid(character_preview_probe) and not character_preview_probe.running and (character_preview_probe.identity!=identity or character_preview_probe.owner_id!=character_lobby.native_chooser.get_instance_id()): character_preview_probe=null
			if not is_instance_valid(character_preview_probe):
				character_preview_probe=preload("res://systems/lobby_record_probe.gd").new(); character_preview_probe.run(self)
				return
			if character_preview_probe.running: return
			character_preview_receipt=receipt
			var title: String=gameplay_ui.text.name({"firstName":preview.get("firstName",{}),"lastName":preview.get("lastName",{})},-1)
			var record_caption: String=gameplay_ui.text.raw({"strRef":0xf182})+", "+title
			send({"kind":"native-character-preview-proof","key":character_lobby.state.get("selected"),"sha256":source.sha256,"native_only":true,"title_matches":not title.is_empty() and character_lobby.native_chooser.record_labels.title.text==record_caption,"abilities":preview.get("abilities",{}),"classes":preview.get("classes",[]),"skill_count":preview.get("skills",[]).size(),"feat_count":preview.get("feats",[]).size(),"spell_count":preview.get("spells",[]).size(),"record_input":character_preview_probe.result})
	if not closing and args.get("lobby-pages-check","")=="true" and args.get("actions-check","")=="true" and not lobby_pages_probe_started and is_instance_valid(character_lobby) and is_instance_valid(character_lobby.native_chooser) and character_lobby.native_chooser.layout_ready and character_lobby.state.get("canSelect",false):
		lobby_pages_probe_started=true; lobby_pages_probe=preload("res://systems/lobby_pages_probe.gd").new(); lobby_pages_probe.run(self)
	if not closing and args.get("local-delete-check","")=="true" and not local_delete_probe_started and chooser_ready_connection==session_connection and is_instance_valid(character_lobby.native_chooser):
		local_delete_probe_started=true; local_delete_probe=preload("res://systems/local_character_delete_probe.gd").new(); local_delete_probe.run(self)
	if args.get("offline-replay","")=="true":
		for input_owner in [keyboard,world_input]:
			if is_instance_valid(input_owner): input_owner.process_mode=Node.PROCESS_MODE_DISABLED
	if pending_creator and is_instance_valid(gameplay_ui) and not closing:
		pending_creator=false; gameplay_ui.creator.open(session_connection)
	if is_instance_valid(render_settings) and render_settings.visible and Time.get_ticks_msec()-settings_at>=500:
		settings_at=Time.get_ticks_msec(); var began:=FrameProfile.begin()
		refresh_prework_sources()
		render_settings.update_performance(frame_profile.snapshot() if is_instance_valid(frame_profile) else {})
		FrameProfile.finish("settings_update",began)
func expose_local_fixture(chooser,connection: int) -> void:
	# Owned-local automation only: original installed fixtures are pregenerated.
	# Use the real checkbox rather than bypassing the default-off source filter.
	var point: Vector2=chooser.pregen.get_global_rect().get_center(); var motion:=InputEventMouseMotion.new(); motion.position=point; motion.global_position=point; root.push_input(motion,true); await process_frame
	for pressed in [true,false]:
		if closing or not is_instance_valid(character_lobby) or character_lobby.connection!=connection or character_lobby.native_chooser!=chooser or not is_instance_valid(chooser) or not chooser.is_visible_in_tree(): return
		var event:=InputEventMouseButton.new(); event.position=point; event.global_position=point; event.button_index=MOUSE_BUTTON_LEFT; event.pressed=pressed; event.button_mask=MOUSE_BUTTON_MASK_LEFT if pressed else 0; root.push_input(event,true); await process_frame
	report.local_fixture_filter={"connection":connection,"checked":chooser.show_pregenerated,"native_input":true,"unadmitted":not is_instance_valid(world),"catalog":character_lobby.local_catalog.snapshot(),"keys":chooser.row_keys.duplicate()}
func gameplay_presentation_allowed() -> bool:
	return super.gameplay_presentation_allowed() and (args.get("offline-replay","")=="true" or str(character_lobby.state.get("phase",""))=="playing")
func receive(message: Dictionary) -> void:
	if not FrameProfile.enabled:
		receive_profiled(message); return
	# Finite labels keep untrusted message names out of profiler key cardinality.
	# These spans cover synchronous handler work; awaited continuations remain
	# separately owned. They are children of protocol_apply, not additive CPU.
	var kind:=str(message.get("kind",""))
	if kind not in ["raw-world-begin","raw-world-chunk","raw-world-end","ui-protocol","raw-visual-events","raw-combat-events","raw-voice-events","raw-script-sounds","lobby","session-reset","setup"]: kind="other"
	var began:=FrameProfile.begin()
	receive_profiled(message)
	FrameProfile.finish("protocol_message_"+kind+"_ms",began)
	FrameProfile.count("count_protocol_message_"+kind,1)
func receive_profiled(message: Dictionary) -> void:
	if closing and message.get("kind")!="finish-ack": return
	if not accept_connection(message): return
	if message.get("kind")=="setup" and message.get("resourceSources") is Dictionary: current_prework_sources=message.resourceSources.duplicate(true)
	match str(message.get("kind","")):
		"test-lobby-participant-status":
			if args.get("lobby-pages-check","")=="true" and args.get("actions-check","")=="true": test_lobby_participant=message.get("value",{}).duplicate(true)
		"test-barter-peer-status":
			if args.get("actions-check","")=="true" and args.get("actions-barter-check","")=="true": test_barter_peer=message.get("value",{}).duplicate(true)
		"begin-performance-window":
			if args.get("offline-replay","")!="true": return
			if not is_instance_valid(world) or int(message.get("generation",-1))!=epoch or int(message.get("areaId",-1))!=world.area_id or not world.ready_for_control() or not world.snapshot(false).get("object_visuals_complete",false):
				send({"kind":"performance-window-ready","success":false}); return
			samples.clear(); previous=0
			report.performance_window={"steady":true,"started_at_ms":Time.get_ticks_msec(),"generation":epoch,"areaId":world.area_id,"entities":world.instances.size(),"scope":"Offline post-completion measurement; numeric frame interval window reset only, scene and server inputs unchanged"}
			send({"kind":"performance-window-ready","success":true,"generation":epoch,"areaId":world.area_id})
		"replay-view":
			if args.get("offline-replay","")!="true": return
			var view: Dictionary=message.get("value",{})
			var size_value: Array=view.get("size",[])
			if size_value.size()==2 and int(size_value[0])>0 and int(size_value[0])<=16384 and int(size_value[1])>0 and int(size_value[1])<=16384: root.size=Vector2i(int(size_value[0]),int(size_value[1]))
			if view.get("particles") is bool: particle_visibility.set_enabled(view.particles)
			if view.get("particle_collision") is bool: particle_visibility.set_collision_enabled(view.particle_collision)
			if view.get("gore") is int or view.get("gore") is float: host.set_meta("native_gore",clampi(int(view.gore),0,2))
			if is_instance_valid(controller) and controller.follow_state!=null:
				var pose: Dictionary=view.get("camera_state",{})
				for field in ["yaw","pitch","distance"]:
					if pose.has(field) and is_finite(float(pose[field])): controller.follow_state.state[field]=float(pose[field])
			if is_instance_valid(camera) and view.has("fov"): camera.fov=clampf(float(view.fov),1,179)
		"probe-native-creation":
			if args.get("settings-check","")!="true": return
			var probe=preload("res://tests/native_creation_live_probe.gd").new(); host.add_child(probe); probe.run(self)
		"native-creation-result":
			if is_instance_valid(gameplay_ui): gameplay_ui.creator.result(message)
		"probe-live-actions":
			if args.get("actions-check","")!="true": return
			var probe=preload("res://tests/native_live_actions_probe.gd").new(); host.add_child(probe); probe.run(self)
		"probe-native-desktop":
			if args.get("settings-check","")!="true": return
			probe_native_desktop()
		"probe-render-settings":
			if args.get("settings-check","")!="true": return
			probe_render_settings()
		"raw-world-begin":
			var serial:=int(message.get("serial",-1)); var count:=int(message.get("count",-1))
			if serial<=raw_serial or count<0 or count>65536 or not message.get("data") is Dictionary: fail("Invalid native raw-world header"); return
			var mode:=str(message.data.get("bridgeMode","full"))
			if mode not in ["full","delta"] or mode=="delta" and (int(message.data.get("bridgeBaseSerial",-2))!=accepted_raw_serial or int(message.generation)!=epoch): fail("Native raw-world delta has no accepted base"); return
			raw_serial=serial; raw_world={"serial":serial,"generation":int(message.generation),"count":count,"data":message.data}; raw_world.data.objects=[]
		"raw-world-chunk":
			if raw_world.is_empty() or int(message.get("serial",-1))!=raw_serial or int(message.get("generation",-1))!=int(raw_world.generation) or not message.get("objects") is Array or message.objects.size()>64 or raw_world.data.objects.size()+message.objects.size()>int(raw_world.count): fail("Invalid native raw-world chunk"); return
			raw_world.data.objects.append_array(message.objects)
		"raw-world-end":
			if raw_world.is_empty() or int(message.get("serial",-1))!=raw_serial or int(message.get("generation",-1))!=int(raw_world.generation) or raw_world.data.objects.size()!=int(raw_world.count): fail("Incomplete native raw-world snapshot"); return
			var snapshot:=raw_world; raw_world={}
			# Apply the persisted render policy only at the next area boundary.
			# Existing placements and in-flight batches keep their original layout.
			if int(snapshot.generation)!=epoch: render_pool.compact_static_parts=render_settings.compact_scenery_enabled
			super.receive({"kind":"snapshot","generation":snapshot.generation,"data":snapshot.data})
			if closing: return
			accepted_raw_serial=raw_serial
			if args.get("offline-replay","")=="true" and is_instance_valid(character_lobby): character_lobby.panel.hide()
			if is_instance_valid(gameplay_ui) and not gameplay_ui.options_requested.is_connected(open_game_options):
				render_menu.key_bindings=gameplay_ui.key_bindings
				render_menu.configure_native(gameplay_ui.inventory.frame_skin,gameplay_ui.text,catalog,ProjectSettings.globalize_path(str(args.get("prepared-cache","user://native-prepared-v2"))),[session_connection,gameplay_ui.generation,gameplay_ui.area_id,gameplay_ui.controlled_id])
				gameplay_ui.options_requested.connect(open_game_options)
				gameplay_ui.inventory.ui.creature_slots=render_settings.creature_slots
			if is_instance_valid(gameplay_ui): render_menu.set_native_scope([session_connection,gameplay_ui.generation,gameplay_ui.area_id,gameplay_ui.controlled_id])
			if is_instance_valid(world_input): world_input.extra_pointer_block=native_pointer_blocked
			send({"kind":"raw-world-accepted","serial":raw_serial,"generation":snapshot.generation})
		"browser-open":
			character_lobby.panel.hide(); server_browser.open()
		"main-menu-open":
			open_startup_menu()
		"login-profiles-view","login-profiles-notice":
			if is_instance_valid(login_profiles): login_profiles.receive(message)
		"probe-native-admission":
			if args.get("actions-check","")!="true" or message.get("host","")!="127.0.0.1" or int(message.get("port",0))!=5125: fail("Admission probe requires the owned original local action server"); return
			probe_native_admission.call_deferred()
		"browser-view","browser-closed","browser-notice","browser-profile-result":
			server_browser.receive(message)
			if message.kind=="browser-view":
				send({"kind":"browser-observed","viewId":int(message.viewId),"native_rendering":true})
		"lobby":
			session_connection=int(message.connection); character_lobby.apply_state(message)
			render_menu.observe_lobby(message.state)
			var phase:=str(message.state.get("phase",""))
			if phase in ["closed","disconnecting"]:
				cancelled_connection=session_connection; reset_session()
			if phase=="closed": return_to_browser=true
			if phase in ["menu","closed"] and return_to_main_menu and not message.state.get("busy",false):
				return_to_main_menu=false; return_to_browser=false
				if server_browser.wanted: server_browser.close()
				character_lobby.panel.hide(); label.text=""; render_menu.open(false)
			elif phase in ["menu","closed"] and return_to_browser and not message.state.get("busy",false):
				return_to_browser=false; character_lobby.panel.hide(); label.text=""
				server_browser.open_list()
			elif server_browser.wanted: character_lobby.panel.hide()
			if str(message.state.get("phase",""))=="area-loading" and not loading_announced:
				loading_announced=true; loading_screen.begin(-2,"area")
			elif str(message.state.get("phase",""))=="playing": loading_announced=false
			if is_instance_valid(gameplay_ui): gameplay_ui.creator.observe(message.state)
		"character-saved":
			export_receipt_serial+=1
			label.text="Character exported: "+str(message.get("name",""))
			if is_instance_valid(gameplay_ui): gameplay_ui.chat.append_message({"system":true,"text":label.text})
		"notice": label.text=str(message.text)
		"session-reset": reset_session()
		"probe-session-disconnect":
			if not is_instance_valid(world) or not world.ready_for_control() or character_lobby.disconnect_button.disabled: fail("Native local disconnect probe is unavailable"); return
			if not report.has("session_disconnect_probes"): report.session_disconnect_probes=[]
			var unfinished:=0
			for task in world.worker_tasks():
				if not WorkerThreadPool.is_task_completed(int(task)): unfinished+=1
			report.session_disconnect_probes.append({"connection":session_connection,"generation":epoch,"area_id":world.area_id,"entities":world.instances.size(),"desired":world.desired.size(),"pending_batches":world.batches.size(),"unfinished_workers":unfinished,"cache":render_pool.snapshot()})
			character_lobby.save_on_disconnect.button_pressed=false
			character_lobby.disconnect_button.pressed.emit()
		"probe-session-cancel":
			if args.get("settings-check","")!="true" or not character_lobby.state.get("canCancelJoin",false): fail("Pending connection cancellation probe unavailable"); return
			report.session_cancel_probes=int(report.get("session_cancel_probes",0))+1
			character_lobby.cancel_button.pressed.emit()
		"probe-stale-world-input":
			var retired_connection:=int(message.oldConnection)
			if retired_connection>=session_connection or not is_instance_valid(world) or not world.ready_for_control(): fail("Stale input probe has no retired connection"); return
			var position: Array=message.position
			send({"kind":"walk","connection":retired_connection,"generation":epoch,"areaId":world.area_id,"position":[position[0]+5.0,position[1],position[2]]})
			send({"kind":"catalog-ready","connection":retired_connection})
			send({"kind":"raw-world-accepted","connection":retired_connection,"generation":epoch,"serial":0})
			send({"kind":"observed","connection":retired_connection,"state":{"ready":false}})
			report.stale_input_probes=int(report.get("stale_input_probes",0))+1
		"finish-menu-check":
			record_menu_check_stage("entry_begin")
			var pregame_ready:=await probe_pregame_entry()
			record_menu_check_stage("entry_ready")
			var prework_ready:=true
			if prework_sources_configured:
				var deadline:=Time.get_ticks_msec()+10000
				while prework_discovery.task>=0 and Time.get_ticks_msec()<deadline: await process_frame
				open_render_settings(); render_settings.tabs.current_tab=render_settings.prework_prepare.get_parent().get_index()
				record_menu_check_stage("content_ready")
				prework_ready=not initialized and not render_settings.prework_prepare.disabled and not prework_choices.is_empty()
				if prework_ready:
					render_settings.prework_prepare.pressed.emit()
					record_menu_check_stage("model_start")
					while asset_prework.state.active and asset_prework.child_pid<0 and Time.get_ticks_msec()<deadline: await process_frame
					prework_ready=asset_prework.state.active and asset_prework.child_pid>0
					var corpus_limit:=int(args.get("prework-check-limit",0))
					if corpus_limit>0:
						deadline=Time.get_ticks_msec()+220000
						var trace:=FileAccess.open(str(args.report)+".prework-progress.jsonl",FileAccess.WRITE); var traced_at:=0
						while asset_prework.state.active and Time.get_ticks_msec()<deadline:
							if Time.get_ticks_msec()-traced_at>=1000: trace.store_line(JSON.stringify(asset_prework.state)); trace.flush(); traced_at=Time.get_ticks_msec()
							await process_frame
						trace.close()
						prework_ready=prework_ready and not asset_prework.state.active and int(asset_prework.state.completed)==int(asset_prework.state.total) and int(asset_prework.state.total)>0
					else:
						render_settings.prework_cancel.pressed.emit()
						record_menu_check_stage("model_cancel_requested")
						while asset_prework.state.active and Time.get_ticks_msec()<deadline: await process_frame
						prework_ready=prework_ready and not asset_prework.state.active and not render_settings.prework_prepare.disabled
				report.offline_prework={"ready":prework_ready,"connected":initialized,"choices":prework_choices.map(func(choice):return str(choice.label)),"state":asset_prework.state.duplicate(true)}
				record_menu_check_stage("model_cancel_finished")
				if DisplayServer.get_name()!="headless":
					await RenderingServer.frame_post_draw; root.get_texture().get_image().save_png(str(args.report)+".prework.png")
				var ui_ready: bool=not render_settings.ui_preload_prepare.disabled and render_settings.ui_preload_content.item_count>0
				if ui_ready:
					render_settings.tabs.current_tab=render_settings.ui_preload_prepare.get_parent().get_index()
					render_settings.ui_preload_prepare.pressed.emit()
					record_menu_check_stage("ui_start")
					ui_ready=ui_preload.state.active and not render_settings.ui_preload_cancel.disabled and render_settings.prework_prepare.disabled
					render_settings.ui_preload_cancel.pressed.emit()
					record_menu_check_stage("ui_cancel_requested")
					deadline=Time.get_ticks_msec()+15000
					while ui_preload.state.active and Time.get_ticks_msec()<deadline: await process_frame
					ui_ready=ui_ready and not ui_preload.state.active and ui_preload.state.get("cancelled",false) and not render_settings.ui_preload_prepare.disabled
				report.offline_ui_preload={"ready":ui_ready,"connected":initialized,"state":ui_preload.state.duplicate(true)}
				record_menu_check_stage("ui_cancel_finished")
				prework_ready=prework_ready and ui_ready
			report.merge({"success":true,"native_rendering":true,"network_connections":0,"browser_ready":server_browser.view_id>=0,"full_migration":false,"scope":"Browser startup only; not world/rendering acceptance"},true)
			report.success=prework_ready and report.browser_ready and pregame_ready
			if is_instance_valid(server_browser): server_browser.close_native()
			if is_instance_valid(render_menu): render_menu.close_pregame(); report.pregame_cleanup=render_menu.pregame_cleanup
			if DisplayServer.get_name()!="headless": report.final_window={"screen":root.current_screen,"primary":DisplayServer.get_primary_screen(),"screens":DisplayServer.get_screen_count(),"unfocusable":root.unfocusable,"focused":root.has_focus(),"mouse_mode":Input.mouse_mode}
			var file:=FileAccess.open(args.report,FileAccess.WRITE); file.store_string(JSON.stringify(report,"  ")+"\n"); file.close()
			send({"kind":"finished","success":report.success}); peer.disconnect_from_host(); host.free(); quit(0 if report.success else 1)
		_: super.receive(message)
func record_menu_check_stage(stage: String) -> void:
	var now:=Time.get_ticks_msec()
	if not report.has("menu_check_stages"): report.menu_check_stages=[]; report.menu_check_started_ms=now
	var row: Dictionary={"stage":stage,"elapsed_ms":now-int(report.menu_check_started_ms),"model_active":asset_prework.state.active,"ui_active":ui_preload.state.active}
	report.menu_check_stages.append(row)
	var path:=str(args.report)+".menu-stages.jsonl"; var file:=FileAccess.open(path,FileAccess.READ_WRITE if FileAccess.file_exists(path) else FileAccess.WRITE)
	if file!=null: file.seek_end(); file.store_line(JSON.stringify(row)); file.close()
func probe_pregame_entry() -> bool:
	if initialized or not is_instance_valid(render_menu.pregame): report.pregame_entry={"success":false,"reason":"Pregame owner requires an unconnected entry"}; return false
	if server_browser.wanted: server_browser.close()
	character_lobby.panel.hide(); render_menu.open(false)
	var ui=render_menu.pregame; var deadline:=Time.get_ticks_msec()+10000; var require_art:=DisplayServer.get_name()!="headless"
	while Time.get_ticks_msec()<deadline and ui.failure.is_empty() and (not is_instance_valid(ui.main) or not ui.main.layout_ready or not is_instance_valid(ui.options) or not ui.options.layout_ready or require_art and (not ui.main.art_ready() or not ui.options.art_ready())): await process_frame
	var checks: Dictionary={"ready":ui.failure.is_empty() and is_instance_valid(ui.main) and ui.main.layout_ready and is_instance_valid(ui.options) and ui.options.layout_ready and (not require_art or ui.main.art_ready() and ui.options.art_ready())}
	if checks.ready:
		checks.main=ui.main.is_visible_in_tree() and not render_menu.panel.visible
		ui.main.buttons.optionsbutton.pressed.emit(); checks.options=ui.options.is_visible_in_tree() and ui.page=="options"
		ui.options.buttons.closebutton.pressed.emit(); checks.return_main=ui.main.is_visible_in_tree() and ui.page=="main"
		var previous: int=server_browser.view_id
		ui.main.buttons.multibutton.pressed.emit()
		while server_browser.view_id<=previous and Time.get_ticks_msec()<deadline: await process_frame
		while Time.get_ticks_msec()<deadline and (not is_instance_valid(server_browser.profile_dialog) or not server_browser.profile_dialog.layout_ready): await process_frame
		checks.profile=is_instance_valid(server_browser.profile_dialog) and server_browser.profile_dialog.visible and server_browser.profile_first and not server_browser.panel.visible
		if checks.profile:
			server_browser.profile_dialog.edits.pnameeditbox.text="GodotMenuProbe"; server_browser.profile_dialog.invoke("okbutton")
			while Time.get_ticks_msec()<deadline and (server_browser.profile_dialog.pending or server_browser.state.get("busy",false) or not is_instance_valid(server_browser.entry_menu) or not server_browser.entry_menu.layout_ready): await process_frame
			checks.profile_commit=server_browser.name_edit.text=="GodotMenuProbe" and not server_browser.profile_first and not server_browser.profile_dialog.visible
		checks.multiplayer=is_instance_valid(server_browser.entry_menu) and server_browser.entry_menu.visible and server_browser.entry_menu.buttons.size()==6
		if checks.multiplayer:
			server_browser.entry_menu.buttons.dirconnectbutton.pressed.emit(); checks.direct_modal=server_browser.direct_dialog.visible and server_browser.entry_menu.visible and not server_browser.panel.visible
			server_browser.direct_dialog.buttons.cancelbutton.pressed.emit(); checks.direct_return=server_browser.entry_menu.visible and not server_browser.direct_dialog.visible and not server_browser.panel.visible
			server_browser.entry_menu.buttons.intjoinbutton.pressed.emit()
			while Time.get_ticks_msec()<deadline and (server_browser.state.get("busy",false) or server_browser.state.get("tab","")!="Internet"): await process_frame
		while Time.get_ticks_msec()<deadline and not server_browser.native_browser.layout_ready and server_browser.native_browser.failure.is_empty(): await process_frame
		checks.browser=server_browser.wanted and server_browser.native_browser.visible and server_browser.native_browser.layout_ready and server_browser.native_browser.failure.is_empty() and server_browser.view_id>previous and not ui.visible and not ui.wanted
		if checks.browser:
			while Time.get_ticks_msec()<deadline and not server_browser.filter_dialog.layout_ready and server_browser.filter_dialog.failure.is_empty(): await process_frame
			server_browser.open_filters(); checks.filters=server_browser.filter_dialog.visible and not server_browser.panel.visible and server_browser.modal_shield.visible
			if checks.filters:
				server_browser.filter_dialog.buttons.cancelbutton.pressed.emit(); checks.filters_return=server_browser.browser_visible() and not server_browser.filter_dialog.visible and not server_browser.modal_shield.visible
	report.pregame_entry={"success":checks.values().all(func(value):return value),"checks":checks,"state":ui.snapshot(),"browser":server_browser.native_browser.snapshot(),"connected":initialized,"public_connections":0,"art_ready_required":require_art,"headless_routes_only":not require_art,"visual_accepted":false}
	return report.pregame_entry.success
func probe_native_admission() -> void:
	var deadline:=Time.get_ticks_msec()+15000; var ui=server_browser
	while Time.get_ticks_msec()<deadline and (not is_instance_valid(ui.profile_dialog) or not ui.profile_dialog.layout_ready or not ui.direct_dialog.layout_ready or not ui.entry_menu.layout_ready): await process_frame
	var checks: Dictionary={"prepared":is_instance_valid(ui.profile_dialog) and ui.profile_dialog.layout_ready and ui.profile_dialog.failure.is_empty() and ui.direct_dialog.layout_ready and ui.direct_dialog.failure.is_empty() and ui.entry_menu.layout_ready and ui.entry_menu.failure.is_empty()}
	if checks.prepared:
		ui.entry_context=true; ui.entry_stage="entry"
		ui.open_profile(); checks.profile_open=ui.profile_dialog.visible and not ui.panel.visible
		ui.profile_dialog.edits.pnameeditbox.text="GodotNativeLocalTest"; ui.profile_dialog.buttons.passwordcheck.set_pressed_no_signal(false); ui.profile_dialog.invoke("okbutton")
		checks.profile_pending=ui.profile_dialog.pending
		while Time.get_ticks_msec()<deadline and (ui.profile_dialog.pending or ui.state.get("busy",false)): await process_frame
		checks.profile_committed=ui.name_edit.text=="GodotNativeLocalTest" and not ui.profile_dialog.visible and ui.entry_menu.visible and not ui.state.get("busy",false)
		if checks.profile_committed:
			ui.host_edit.text="127.0.0.1"; ui.port_edit.value=5125; ui.entry_menu.buttons.dirconnectbutton.pressed.emit()
			checks.direct_open=ui.direct_dialog.visible and ui.entry_menu.visible and not ui.panel.visible
			checks.endpoint=ui.direct_dialog.edits.ipeditbox.text=="127.0.0.1:5125"
			checks.saved_key=ui.key_edit.text.is_empty() and ui.state.get("hasSavedCdKey",false)
	var success: bool=checks.values().all(func(value):return value) and checks.size()==7
	report.native_admission={"success":success,"checks":checks,"server":"127.0.0.1:5125","public_connections":0,"via":"native profile, Multiplayer and Direct Connect controls"}
	send({"kind":"native-admission-proof","success":success,"checks":checks})
	if success: ui.direct_dialog.invoke("okbutton")
func probe_native_desktop() -> void:
	var deadline:=Time.get_ticks_msec()+15000
	while is_instance_valid(gameplay_ui) and not gameplay_ui.tables_ready and Time.get_ticks_msec()<deadline: await process_frame
	if not is_instance_valid(gameplay_ui) or not gameplay_ui.tables_ready: send({"kind":"native-desktop-proof","success":false,"reason":"Native UI tables did not become ready"}); return
	var ui=gameplay_ui; var desktop=ui.desktop
	for panel in ["character","spells","inventory","map","journal","pvp"]: desktop.panel(panel)
	deadline=Time.get_ticks_msec()+15000
	while Time.get_ticks_msec()<deadline and (desktop.sheet.state.is_empty() or not desktop.actor().get("inventoryStats",{}).has("fields70") or desktop.map_set_job>=0 or not desktop.map_queue.is_empty() or not desktop.map_jobs.is_empty()): await process_frame
	var current: Dictionary=desktop.actor(); var inv: Dictionary=current.get("inventoryStats",{})
	var windows: bool=desktop.sheet.visible and desktop.book.visible and ui.inventory.ui.visible and desktop.area_map.visible and desktop.journal.visible and desktop.players.visible
	var stats_ready: bool=inv.has("fields70") and desktop.sheet.state.get("model",{}).get("abilities",[]).size()==6
	desktop.open_radial({"id":desktop.actor_id,"position":Vector3.ZERO},Vector2(600,350)); await process_frame
	var radial_ready: bool=desktop.radial.active and desktop.radial.layer>ui.layer.layer
	desktop.radial.reset()
	var drive_before: int=keyboard.stats.drive; var old_focus: bool=keyboard.require_focus; keyboard.require_focus=false
	var accepted: bool=keyboard.key(KEY_W,true)
	await create_timer(0.03).timeout
	keyboard.key(KEY_W,false); keyboard.require_focus=old_focus
	var movement: bool=accepted and int(keyboard.stats.drive)>drive_before
	desktop.begin_target({"type":3,"intParam":22})
	deadline=Time.get_ticks_msec()+6000
	while Time.get_ticks_msec()<deadline and (not ui.conversation.opened or ui.conversation.entry_id<0): await process_frame
	var dialog: bool=ui.conversation.opened and ui.conversation.reply_ids.size()>0
	if dialog: ui.conversation.choose(4294967295,true)
	var proof:={"kind":"native-desktop-proof","success":windows and stats_ready and radial_ready and movement and dialog and desktop.area_map.board.art.size()>0,"windows":windows,"received_stats":stats_ready,"party_members":desktop.party.rows.size(),"portrait_resource":desktop.party.rows[0].portraitKey if not desktop.party.rows.is_empty() else "","party_portrait_loaded":desktop.party.cards[0].get_node("Box/Portrait/Image").texture!=null if desktop.party.cards.has(0) else false,"quickbar_slots":desktop.quickbar.rows.size(),"map_art":desktop.area_map.board.art.size(),"map_exploration":desktop.area_map.board.explored.size(),"radial":radial_ready,"wasd_with_windows":movement,"server_skill_dialog":dialog,"ui_errors":ui.stats.errors.duplicate(true),"missing_art":desktop.art.failed.keys()}
	for view in [desktop.sheet,desktop.book,desktop.area_map,desktop.journal,desktop.players]: view.hide(); view.wanted=false
	ui.inventory.ui.close_inventory()
	send(proof)
func probe_render_settings() -> void:
	var before: bool=particle_visibility.enabled; var objects: int=world.instances.size()
	render_menu.choose("options")
	var opened: bool=render_settings.visible
	render_settings.particles_toggle.button_pressed=true
	for frame in 3: await process_frame
	render_settings.particles_toggle.button_pressed=false
	var counts: Dictionary={}
	for id in particle_visibility.emitters:
		var emitter: Object=particle_visibility.emitters[id].get_ref()
		if is_instance_valid(emitter): counts[id]=int(emitter.frames)
	for frame in 3: await process_frame
	var paused: bool=not particle_visibility.enabled
	for id in counts:
		var emitter: Object=particle_visibility.emitters[id].get_ref() if particle_visibility.emitters.has(id) else null
		if is_instance_valid(emitter): paused=paused and int(emitter.frames)==int(counts[id]) and not emitter.is_processing() and not emitter.is_visible_in_tree()
	render_settings.particles_toggle.button_pressed=before; render_settings.hide()
	send({"kind":"render-settings-proof","opened":opened,"paused":paused,"restored":particle_visibility.enabled==before,"emitters":counts.size(),"objects_before":objects,"objects_after":world.instances.size()})
func save_last_seen_appearance() -> void:
	if is_instance_valid(character_lobby) and not character_lobby.appearance_identity.is_empty() and is_instance_valid(gameplay_ui):
		var saved: bool=character_lobby.save_last_seen(gameplay_ui.text.objects.get(gameplay_ui.controlled_id,{}))
		report.last_seen_appearance={"saved":saved,"error":character_lobby.appearance_cache.error}
func reset_session() -> void:
	if is_instance_valid(login_profiles): login_profiles.reset()
	save_last_seen_appearance()
	if is_instance_valid(character_lobby): character_lobby.close_native()
	if is_instance_valid(asset_prework): asset_prework.close()
	preload("res://systems/native_data/prework_store.gd").forget(catalog)
	current_prework_sources={}
	pending_combat.clear(); pending_visual.clear(); pending_voice.clear(); pending_script_sounds.clear()
	pending_creator=false
	loading_announced=false
	if is_instance_valid(loading_screen): loading_screen.reset()
	if is_instance_valid(render_menu): render_menu.dismiss()
	if is_instance_valid(render_settings): render_settings.hide()
	if is_instance_valid(entity_inspector): entity_inspector.reset()
	if is_instance_valid(render_menu): render_menu.dismiss(); render_menu.detach_native()
	if is_instance_valid(catalog_loader):
		if is_instance_valid(catalog_retirement): catalog_retirement.retire(catalog_loader)
		else: catalog_loader.close(); catalog_loader.queue_free()
	if is_instance_valid(keyboard): keyboard.stop(false)
	if is_instance_valid(world_input): world_input.process_mode=Node.PROCESS_MODE_DISABLED
	if is_instance_valid(gameplay_ui): gameplay_ui.close()
	if is_instance_valid(world): world_retirement.retire(world)
	for owner in [environment,keyboard,world_input,hud,registry,gameplay_ui]:
		if is_instance_valid(owner): owner.queue_free()
	world=null; environment=null; keyboard=null; world_input=null; hud=null; registry=null; transition_targets=null; gameplay_ui=null; catalog_loader=null
	catalog=Catalog.new(); initialized=false; catalog_loading=false; epoch=-1; acknowledged=-1; previous=0
	initial_controlled=null; maximum_distance=0.0; observed_at=0; presentation_stats={}; stats_at=0; walkmesh_registered=false
func shutdown() -> void:
	if is_instance_valid(login_profiles): login_profiles.reset()
	if is_instance_valid(character_lobby) and is_instance_valid(character_lobby.native_preview): character_lobby.native_preview.close(); report.character_preview=character_lobby.native_preview.snapshot()
	if closing: return
	save_last_seen_appearance()
	if is_instance_valid(lobby_pages_probe): lobby_pages_probe.stop()
	if is_instance_valid(local_delete_probe): local_delete_probe.stop()
	if is_instance_valid(character_preview_probe): character_preview_probe.stop()
	if is_instance_valid(character_lobby):
		character_lobby.close_native(); report.lobby_preferences=character_lobby.preferences.snapshot(); character_lobby.local_catalog.close(); report.local_character_catalog=character_lobby.local_catalog.snapshot()
	if is_instance_valid(server_browser): server_browser.close_native()
	if is_instance_valid(render_menu): render_menu.dismiss()
	if is_instance_valid(render_menu) and is_instance_valid(render_menu.pregame):
		report.pregame_ui=render_menu.pregame.snapshot(); render_menu.close_pregame(); report.pregame_cleanup=render_menu.pregame_cleanup
	if is_instance_valid(window_settings): report.window_settings=window_settings.snapshot(); window_settings.close()
	if is_instance_valid(prework_discovery): prework_discovery.close()
	if is_instance_valid(ui_preload): ui_preload.close(); report.ui_preload=ui_preload.state.duplicate(true)
	if is_instance_valid(asset_prework): asset_prework.close(); report.asset_prework=asset_prework.state.duplicate(true)
	super.shutdown()
func native_pointer_blocked(point: Vector2) -> bool:
	if closing or not is_instance_valid(world): return true
	return (is_instance_valid(login_profiles) and login_profiles.visible and login_profiles.get_global_rect().has_point(point)) or (is_instance_valid(server_browser) and server_browser.blocks_pointer(point)) or (is_instance_valid(character_lobby) and character_lobby.blocks_pointer(point)) or (is_instance_valid(gameplay_ui) and gameplay_ui.blocks_pointer(point)) or (is_instance_valid(render_menu) and render_menu.blocks_pointer(point)) or (is_instance_valid(render_settings) and render_settings.visible and render_settings.get_global_rect().has_point(point)) or (is_instance_valid(entity_inspector) and entity_inspector.blocks_pointer(point))
	raw_world={}
	accepted_raw_serial=-1
	label.text="Native renderer · choose a server or character"
func cancel_loading() -> void:
	request_disconnect(false)
func lobby_request(message: Dictionary) -> void:
	if str(message.get("kind","")) in ["lobby-disconnect","lobby-cancel-join"]:
		request_disconnect(bool(message.get("saveCharacter",false)))
	else: send(message)
func request_disconnect(save_character: bool) -> void:
	if cancelled_connection==session_connection: return
	var cancel: bool=character_lobby.state.get("canCancelJoin",false)
	if not cancel and not character_lobby.state.get("connected",false): return
	cancelled_connection=session_connection; return_to_browser=true
	reset_session()
	character_lobby.panel.hide(); label.text="Disconnecting…"
	send({"kind":"lobby-cancel-join" if cancel else "lobby-disconnect","saveCharacter":save_character})
