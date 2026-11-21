extends "res://native_session_world.gd"
# Godot-owned original-server route through the existing renderer/UI. This is
# an explicit development entry until the remaining gameplay stream, browser,
# saved-key migration and acceptance matrix replace the transitional host.
const DirectSession=preload("res://systems/native_data/native_network_session.gd")
const Characters=preload("res://systems/native_data/native_server_characters.gd")
const CameraAppearanceHeight=preload("res://systems/native_data/native_camera_appearance_height.gd")
const CameraSceneQuery=preload("res://systems/native_render/camera_scene_query.gd")
const GameCameraState=preload("res://systems/game_camera_state.gd")
const GffDocument=preload("res://systems/native_data/gff_document.gd")
const CharacterPreview=preload("res://systems/native_data/character_preview.gd")
const MIN_CHARACTER_PREVIEW_BYTES:=56
const ServerDirectory=preload("res://systems/native_data/native_server_directory.gd")
const LoginProfileController=preload("res://systems/native_data/godot_login_profile_controller.gd")
const ClientSettingsStore=preload("res://systems/native_data/client_settings_store.gd")
const BrowserStore=preload("res://systems/native_data/godot_server_browser_store.gd")
const ServerQuery=preload("res://systems/native_data/native_server_query.gd")
const PlacedSounds=preload("res://systems/native_data/native_placed_sounds.gd")
const AmbientAudio=preload("res://systems/native_data/native_ambient_audio_owner.gd")
const CharacterExportVault=preload("res://systems/native_data/native_character_export_vault.gd")
const NWSyncStore=preload("res://systems/native_data/nwsync_store.gd")
const SceneDelivery=preload("res://systems/native_data/network_scene_delivery.gd")
const VisualPresentation=preload("res://systems/native_data/network_visual_presentation.gd")
const CombatEventOrder=preload("res://systems/native_data/network_combat_event_order.gd")
const RuntimeDiagnostics=preload("res://systems/native_data/runtime_diagnostics.gd")
const SessionFailureJournal=preload("res://systems/native_data/native_session_failure_journal.gd")
const RuntimeDiagnosticReporting=preload("res://systems/native_data/runtime_diagnostic_reporting.gd")
const ResourceProgress=preload("res://systems/native_data/resource_progress.gd")
const LevelReplyScope=preload("res://systems/native_data/level_up_reply_scope.gd")
const NativeTextEventScope=preload("res://systems/native_data/native_text_event_scope.gd")
const NativeVisibilityFrames=preload("res://systems/native_data/native_visibility_frames.gd")
const NativeAudioFrames=preload("res://systems/native_data/native_audio_frames.gd")
const RawWorldDeltas=preload("res://systems/native_data/raw_world_deltas.gd")
signal direct_scene_sync_completed(result: Variant)
var direct_session: Node
var direct_raw_deltas=RawWorldDeltas.new()
var direct_raw_refresh_pending:=false
var direct_raw_next_serial:=0
var _direct_static_rows: RawWorldDeltas.StaticRows
var direct_text_events: RefCounted=NativeTextEventScope.new()
var direct_visibility_frames: RefCounted=NativeVisibilityFrames.new()
var direct_audio_frames: RefCounted=NativeAudioFrames.new()
var direct_scene_delivery: RefCounted
var direct_visual_presentation: RefCounted
var direct_scene_sync_requested:=false
var direct_scene_sync_running:=false
var direct_placed_sounds
var direct_ambient_audio
var direct_visual_queue: Array[Dictionary]=[]
var direct_projectile_queue: Array[Dictionary]=[]
var direct_module_pause_queue: Array[Dictionary]=[]
var direct_voice_queue: Array[Dictionary]=[]
var direct_login_profiles
var direct_browser_store
var direct_server_query: Node
var direct_join_policy_query: Node
var direct_join_policy_serial:=0
var direct_inspect_endpoint: Dictionary={}
var direct_inspect_tab: String=""
var direct_inspect_result: Dictionary={}
var direct_observed_rows: Dictionary={}
var direct_browser_join_row: Dictionary={}
var direct_browser_join_name: String=""
var direct_server_port:=0
var selected_character: Dictionary={}
var direct_generation:=0
var direct_graphics_failed_generation:=-1
var direct_area_presented:=false
var direct_catalog_adopted:=false
var direct_quickbar_received:=false
var direct_check_deadline:=0
var local_character_pending:=false
var direct_lobby_choices: Dictionary={}
var direct_lobby_state: Dictionary={}
var direct_lobby_last_public_signature: String=""
var direct_lobby_page:=0
var direct_lobby_page_version:=0
var direct_lobby_info_query: Node
var direct_lobby_cancelling:=false
var direct_local_file_bytes: PackedByteArray=PackedByteArray()
var direct_local_file_key: String=""
var direct_local_file_token:=-1
var direct_local_file_last_token:=-1
var direct_local_file_choice: Dictionary={}
var direct_local_file_preview: Dictionary={}
var direct_preview_pending: Dictionary={}
var direct_choice_request_id:=-1
var direct_vault_server_play_stage:=0
var direct_vault_server_key: String=""
var direct_manual_test_chosen:=false
var direct_manual_test_played:=false
var direct_started_from_browser:=false
var direct_browser_view_id:=0
var direct_browser_first_view_id:=-1
var direct_browser_refresh_ready_at:=0
var direct_browser_inspect_view_id:=-1
var direct_browser_local_only:=false
var direct_browser_local_port:=5121
var direct_browser_tab:="Direct"
var direct_browser_page:=0
var direct_browser_selected:=-1
var direct_browser_selected_key:=""
var direct_browser_filter:=""
var direct_browser_sort:="Players"
var direct_browser_session_name:=""
var direct_browser_filters:={"local":true,"server":true,"password":true}
var direct_browser_advanced:={"hideEmpty":false,"hideFull":false,"module":""}
var direct_browser_game_type: Variant=null
var direct_browser_source_page:=false
var direct_browser_source_sorts: Dictionary={}
var direct_browser_busy:=false
var direct_browser_work:=""
var direct_directory: Node
var direct_directory_rows: Array[Dictionary]=[]
var direct_directory_loaded:=false
var direct_reconnect_stage:=0
var direct_inventory_stage:=0
var direct_inventory_deadline:=0
var direct_window_receipts_before:=0
var direct_item_id:=-1
var direct_dialog_stage:=0
var direct_dialog_deadline:=0
var direct_speech_echo:=false
var direct_dialog_events: Array[String]=[]
var direct_local_smoke_stage:=0
var direct_local_smoke_origin: Array=[]
var direct_local_smoke_area:=-1
var direct_local_smoke_generation:=-1
var direct_local_smoke_update_serial:=0
var direct_local_smoke_origin_serial:=0
var direct_local_smoke_pose_frames:=0
var direct_local_smoke_sample: Dictionary={}
var direct_local_smoke_animation_witness: Dictionary={}
var direct_local_smoke_animation_frame:=-1
var direct_local_smoke_animation_server_updates:=-1
var direct_local_smoke_speech_echo:=false
var direct_local_smoke_request: Dictionary={}
var direct_keyboard_generation:=0
var direct_command_queue: Array[Dictionary]=[]
var direct_command_running:=false
var direct_travel_stage:=0
var direct_travel_deadline:=0
var direct_travel_origin:=-1
var direct_nwsync_cancel_pending:=false
var direct_portal_stage:=0
var direct_portal_origin_area:=-1
var direct_portal_origin_connection:=-1
var direct_portal_adopting:=false
var direct_portal_adopting_destination: Node
var direct_camera_state
var direct_camera_appearance_table: Dictionary={}
var direct_camera_appearance_job:=-1
var direct_camera_height_cache: Dictionary={}
var direct_camera_queue: Array[Dictionary]=[]
var direct_camera_target_id:=-1
var direct_camera_pending_entry_attach:=false
var direct_nwsync_visual_descriptor: Dictionary={}
var direct_nwsync_visual_progress: Array[Dictionary]=[]
var direct_nwsync_visual_settings_hash:=""
var direct_nwsync_visual_settings_path:=""
var direct_nwsync_visual_stage:=0
var direct_nwsync_world_stage:=0
var direct_nwsync_world_material: Dictionary={}
var direct_nwsync_world_error:=""
var direct_levelup_probe_started:=false
var direct_levelup_origin_level:=-1
var direct_levelup_events: Array[Dictionary]=[]
var direct_levelup_outbound: Array[Dictionary]=[]
var direct_levelup_probe_finished: Dictionary={}
var direct_disconnect_after_export:=false
var direct_shutdown_after_export:=false
var direct_shutdown_export_complete:=false
var direct_character_export_stage:=0
var direct_creation_probe_started:=false
var direct_diagnostics: RefCounted
var direct_session_failure_journal: RefCounted
var direct_diagnostic_context_mode: String=""
var direct_diagnostic_reporting: RefCounted
var direct_diagnostic_catalog: RefCounted
var direct_diagnostic_catalog_seen: Dictionary={}

func native_model_diagnostic(row: Dictionary) -> void:
	if direct_diagnostics!=null:
		direct_diagnostics.record(str(row.get("code","model.warning")),str(row.get("message","")),row.get("detail",{}),str(row.get("severity","warning")))

func native_area_graphics_failed(reason: String) -> void:
	if direct_diagnostics!=null:
		direct_diagnostics.record("network.area-graphics-failed",reason,{"areaId":world.area_id if is_instance_valid(world) else -1},"error")
	direct_retire_failed_area(reason)

func direct_area_setup_failed(reason: String) -> void:
	# This is the onArea setup catch, before graphics work starts. The old
	# frontend retains its connection, retires this presentation, and exposes
	# the error. There is no area-graphics diagnostic for this branch.
	direct_retire_failed_area(reason)

func direct_retire_failed_area(reason: String) -> void:
	if closing:return
	# Keep the live connection and report the failed presentation in the
	# existing loading overlay. Its Back action owns the later disconnect.
	direct_graphics_failed_generation=direct_generation
	direct_area_presented=false
	direct_finish_queued_visual_receipts("stale")
	if direct_scene_delivery!=null:direct_scene_delivery.dispose();direct_scene_delivery=null
	if direct_visual_presentation!=null:direct_visual_presentation.dispose();direct_visual_presentation=null
	direct_visual_queue.clear();direct_projectile_queue.clear();direct_voice_queue.clear()
	direct_camera_queue.clear();direct_camera_state=null;direct_camera_target_id=-1;direct_camera_pending_entry_attach=false
	if is_instance_valid(direct_placed_sounds):direct_placed_sounds.detach()
	if is_instance_valid(direct_ambient_audio):direct_ambient_audio.detach()
	if is_instance_valid(keyboard):keyboard.stop(false);keyboard.queue_free()
	if is_instance_valid(world_input):world_input.process_mode=Node.PROCESS_MODE_DISABLED;world_input.queue_free()
	for owned in [hud,registry,environment]:
		if is_instance_valid(owned):owned.process_mode=Node.PROCESS_MODE_DISABLED;owned.queue_free()
	# A retained failed world can exit after the next area has installed its
	# keyhole. Close its shader owner now so that later exit cannot reset the
	# next area's global keyhole state.
	if is_instance_valid(keyhole):keyhole.close()
	if is_instance_valid(world):world_retirement.retire(world)
	# The old failed presentation disposes its prepared area assets even when
	# renderer retirement keeps the outgoing world alive for worker cleanup.
	area_graphics.retire()
	finish_renderer_retirement()
	world=null;world_input=null;keyboard=null;hud=null;registry=null;environment=null;keyhole=null
	if is_instance_valid(gameplay_ui):
		gameplay_ui.reset_quickbar_for_graphics_failure()
		gameplay_ui.set_gameplay_visible(false)
	if is_instance_valid(loading_screen):loading_screen.show_error(epoch,reason)
	direct_lobby_state.error=reason
	label.text=reason

func direct_install_choice_locked() -> bool:
	return closing or direct_session!=null or is_instance_valid(world) or is_instance_valid(character_lobby) and (bool(character_lobby.state.get("connected",false)) or bool(character_lobby.state.get("canCancelJoin",false)) or bool(character_lobby.state.get("busy",false)))

func direct_install_selected(path: String) -> void:
	if direct_install_choice_locked():return
	# The old disconnected chooser replaced its installation and discarded its
	# UI resolver. Rebuild the Godot pregame owner from the newly selected path;
	# the next connection resolves its catalog from args.direct-install.
	args["direct-install"]=path
	var selected: Dictionary=StartupPaths.direct_ticket(path,str(args.get("direct-profile","")),str(args.get("direct-settings","")))
	if selected.has("error"):
		if is_instance_valid(client_setup):client_setup.notice.text=str(selected.error)
		return
	ticket=selected
	if is_instance_valid(render_menu):
		render_menu.configure_pregame(ticket.preworkSources,ProjectSettings.globalize_path(str(args.get("prepared-cache","user://native-prepared-v2"))))
		if is_instance_valid(render_menu.pregame):
			if is_instance_valid(server_browser):render_menu.pregame.source_ready.connect(server_browser.configure_native)
			if is_instance_valid(character_lobby) and character_lobby.native_frontend:render_menu.pregame.source_ready.connect(character_lobby.prepare_native_frontend)
	if is_instance_valid(character_lobby):character_lobby.local_catalog.configure(ticket.get("localCharacterRoots",[]))

func direct_chat_focus_allowed()->bool:
	return not closing and direct_session!=null and direct_session.phase=="playing" and (not is_instance_valid(render_menu) or not render_menu.visible) and (not is_instance_valid(render_settings) or not render_settings.visible)

func run()->void:
	super.run()
	if closing or not direct_mode or host==null:return
	if is_instance_valid(gameplay_ui):gameplay_ui.chat_focus_phase_query=Callable(self,"direct_chat_focus_allowed")
	interactive=true;report.interactive=true;report.direct_session=true
	direct_directory=ServerDirectory.new();host.add_child(direct_directory)
	direct_directory.completed.connect(direct_directory_ready)
	direct_server_query=ServerQuery.new();host.add_child(direct_server_query)
	direct_server_query.completed.connect(direct_server_query_ready)
	var startup: Dictionary=StartupPaths.resolve(str(args.get("direct-install","")))
	if startup.has("error"):fail(str(startup.error));return
	direct_diagnostics=RuntimeDiagnostics.new("",func()->Dictionary:
		var scope: Dictionary={"server":server_label,"connection":session_connection,"areaId":direct_session.world_state.area_id if direct_session!=null else -1}
		if not direct_diagnostic_context_mode.is_empty():scope.mode=direct_diagnostic_context_mode
		return scope)
	renderer_resource_retirement.report=func(code: String,message: String)->void:
		if direct_diagnostics!=null:direct_diagnostics.record(code,message)
	direct_diagnostic_reporting=RuntimeDiagnosticReporting.new()
	direct_diagnostic_reporting.configure(direct_diagnostics,str(args.get("direct-settings",startup.settingsDirectory)))
	if is_instance_valid(render_settings) and is_instance_valid(render_settings.tabs):render_settings.tabs.add_child(direct_diagnostic_reporting.create_panel())
	direct_diagnostics.record("session.started","Runtime diagnostic recording started",{},"info")
	var visual_path:=str(args.get("direct-nwsync-visual-fixture",""))
	if not visual_path.is_empty():
		if not visual_path.is_absolute_path() or not FileAccess.file_exists(visual_path):fail("Private NWSync visual descriptor is unavailable");return
		var visual_value: Variant=JSON.parse_string(FileAccess.get_file_as_string(visual_path))
		if not visual_value is Dictionary or str(visual_value.get("format",""))!="nwn79-private-nwsync-visual-v1" or not visual_value.get("entries") is Array or visual_value.entries.size()!=13:fail("Invalid private NWSync visual descriptor");return
		direct_nwsync_visual_descriptor=visual_value
	direct_login_profiles=LoginProfileController.new()
	if not direct_login_profiles.open(str(args.get("direct-settings",startup.settingsDirectory)),str(startup.defaultModsDirectory),session_connection,func(message: Dictionary):receive(message),func()->bool:return direct_session!=null, direct_profile_changed):
		fail("Godot login profiles could not open: "+direct_login_profiles.error);return
	if not visual_path.is_empty():
		direct_nwsync_visual_settings_path=direct_login_profiles.store.file
		if not FileAccess.file_exists(direct_nwsync_visual_settings_path):fail("Private NWSync visual check requires an existing isolated settings file");return
		direct_nwsync_visual_settings_hash=FileAccess.get_sha256(direct_nwsync_visual_settings_path)
	# The disconnected settings page shares this already-open store. Opening a
	# second settings writer would leave the profile controller's CAS bytes stale.
	protected_settings_bridge=preload("res://systems/native_data/godot_settings_bridge.gd").new()
	protected_settings_bridge.attach(direct_login_profiles.store,send)
	var selected_install:=str(args.get("direct-install-to-save",""))
	if not selected_install.is_empty() and not direct_login_profiles.store.update({"installDirectory":selected_install}):
		fail("Selected NWN installation could not be saved: "+direct_login_profiles.store.error);return
	direct_browser_store=BrowserStore.new()
	var browser_file: String=direct_login_profiles.store.file.get_base_dir().path_join("native-server-browser.json")
	if not direct_browser_store.open(browser_file):
		fail("Godot server browser could not open: "+direct_browser_store.error);return
	direct_browser_local_only=str(args.get("direct-local-only",""))=="true"
	var selected_endpoint: Dictionary=direct_browser_store.normalized_endpoint({"host":str(args.get("direct-host","")),"port":int(args.get("direct-port",0))})
	if direct_browser_local_only and str(selected_endpoint.get("host",""))=="127.0.0.1":direct_browser_local_port=int(selected_endpoint.port)
	report.scope="Explicit Godot-only original-server development entry; reuses native renderer and gameplay UI without Electron, Node.js or loopback. Incomplete gameplay/browser/reconnect coverage is not normal-client acceptance."
	var server_host:=str(args.get("direct-host",""))
	var server_port:=int(args.get("direct-port",0))
	if server_host.is_empty() and server_port==0:
		if args.get("direct-graphical-menu-exit-check","")=="true":direct_graphical_menu_exit_test_start.call_deferred()
		elif args.get("direct-graphical-menu-check","")=="true":direct_graphical_menu_test_start.call_deferred()
		elif args.get("direct-headless-inspect-check","")=="true":direct_inspect_test_start.call_deferred()
		elif args.get("direct-headless-history-check","")=="true":direct_history_test_start.call_deferred()
		elif args.get("direct-headless-fresh-user-check","")=="true":direct_fresh_user_test_start.call_deferred()
		elif args.get("direct-headless-directory-check","")=="true":direct_directory_test_start.call_deferred()
		elif args.get("direct-headless-browser-check","")=="true":direct_browser_test_start.call_deferred()
		else:open_startup_menu.call_deferred()
		return
	if server_host.is_empty() or server_port<1 or server_port>65535:fail("Godot direct session requires a valid host and UDP port");return
	direct_connect(server_host,server_port)

func native_clock_direct_scope()->Dictionary:
	if closing or direct_session==null or not direct_area_presented or direct_session.phase not in ["area-presenting","playing"] or not is_instance_valid(world):return {}
	var area_id:=int(direct_session.world_state.area_id)
	if area_id==0x7f000000 or int(direct_session.area_generation)!=direct_generation or world.area_id!=area_id:return {}
	return {"connection":session_connection,"generation":direct_generation,"areaId":area_id}

func direct_publish_clock_controlled()->void:
	if native_clock_runtime==null or not native_clock_runtime.ready or direct_session==null:return
	var scope: Dictionary=native_clock_direct_scope()
	if scope.is_empty():return
	var actor_id:=int(direct_session.world_state.local_object_id)
	var actor: Dictionary=direct_session.world_state.registry.get(actor_id,{})
	if int(actor.get("objectType",0))!=5 or int(actor.get("areaId",-1))!=int(scope.areaId) or bool(actor.get("replicationRemoved",false)):return
	var published: Dictionary=native_clock_runtime.publish_direct_controlled_id(actor_id,int(scope.connection),int(scope.generation),int(scope.areaId))
	if not published.get("ready",false):report.direct_clock_controlled_unavailable=str(published.get("reason","Controlled actor clock fact is unavailable."))

func publish_device_properties()->void:
	if not direct_mode:
		super.publish_device_properties()
		return
	if closing or direct_session==null or not is_instance_valid(window_settings):return
	var metrics: Dictionary=window_settings.current()
	metrics.fixed=window_settings.fixed_scale
	var packet: Dictionary=device_properties_packet(metrics,session_connection,device_metrics_revision+1)
	if packet.is_empty():return
	var signature: Array=device_properties_signature(packet)
	if signature==last_device_metrics:return
	var metrics_session: Node=direct_session
	if not await metrics_session.set_device_metrics({"gui_scale":int(packet.guiScalePercent),"gui_width":int(packet.guiWidth),"gui_height":int(packet.guiHeight)}):
		report.direct_device_properties_error="Current window metrics could not be queued for the original server."
		return
	if closing or direct_session!=metrics_session:return
	device_metrics_revision+=1
	last_device_metrics=signature

func native_clock_prefix()->void:
	super.native_clock_prefix()
	direct_drain_module_pause()

func direct_module_pause(receipt: Dictionary)->void:
	if closing or direct_session==null or not receipt.get("message") is Dictionary:return
	if direct_module_pause_queue.size()>=128:fail("Native module-pause admission queue exceeded bound");return
	direct_module_pause_queue.append({"connection":session_connection,"generation":int(receipt.get("generation",-1)),"areaId":int(receipt.get("areaId",-1)),"message":receipt.message.duplicate(true)})
	report.direct_module_pause_pending=direct_module_pause_queue.size()

func direct_drain_module_pause()->void:
	if direct_module_pause_queue.is_empty() or native_clock_runtime==null or not bool(native_clock_runtime.ready) or not bool(native_clock_runtime.diagnostics.get("directOwnersReady",false)):return
	var scope: Dictionary=native_clock_direct_scope()
	if scope.is_empty():return
	while not direct_module_pause_queue.is_empty():
		var entry: Dictionary=direct_module_pause_queue[0]
		direct_module_pause_queue.pop_front()
		if int(entry.connection)!=int(scope.connection) or int(entry.generation)!=int(scope.generation) or int(entry.areaId)!=int(scope.areaId):
			report.direct_module_pause_retired=int(report.get("direct_module_pause_retired",0))+1
			continue
		var applied: Dictionary=native_clock_runtime.receive_direct_pause(entry.message,int(scope.connection),int(scope.generation),int(scope.areaId))
		if not applied.get("ready",false):fail("Native module-pause transition unavailable: "+str(applied.get("reason","clock owner rejected receipt")));return
		report.direct_module_pause_applied=int(report.get("direct_module_pause_applied",0))+1
		report.direct_module_pause_last={"mask":int(entry.message.mask),"value":int(entry.message.value),"deliveryOrder":int(applied.get("deliveryOrder",0)),"duplicatePacket":bool(applied.get("duplicatePacket",false))}
	report.direct_module_pause_pending=direct_module_pause_queue.size()

func direct_browser_endpoint_error(value: Dictionary)->String:
	if direct_browser_store==null:return "Server browser policy is unavailable"
	var reason: String=direct_browser_store.endpoint_error(value)
	if not reason.is_empty():return reason
	if not direct_browser_store.permits_endpoint(value,direct_browser_local_only,direct_browser_local_port):return "This server is not enabled for this session. No connection was sent."
	return ""

func direct_browser_key(value: Dictionary)->String:
	var endpoint: Dictionary=direct_browser_store.normalized_endpoint(value)
	return str(endpoint.get("host",""))+":"+str(endpoint.get("port",0)) if not endpoint.is_empty() else ""

func direct_portal_endpoint_allowed(server_host: String,server_port: int)->bool:
	return direct_browser_endpoint_error({"host":server_host,"port":server_port}).is_empty()

func direct_connect(server_host: String,server_port: int,server_password: String="",temporary_cd_key: String="",player_name: String="",portal_handoff: Dictionary={},server_public_key: Variant=null)->void:
	var endpoint_reason:=direct_browser_endpoint_error({"host":server_host,"port":server_port})
	if not endpoint_reason.is_empty():
		if not portal_handoff.is_empty():direct_dispose_portal_handoff(portal_handoff)
		if direct_started_from_browser:direct_browser_view(endpoint_reason)
		else:fail(endpoint_reason)
		return
	var expected_server_key:=PackedByteArray()
	if server_public_key!=null and server_public_key!="":
		if not server_public_key is String or RegEx.create_from_string("^[A-Za-z0-9+/]{43}=$").search(server_public_key)==null:
			if not portal_handoff.is_empty():direct_dispose_portal_handoff(portal_handoff)
			if direct_started_from_browser:direct_browser_view("Invalid server public identity")
			else:fail("Invalid server public identity")
			return
		expected_server_key=Marshalls.base64_to_raw(server_public_key)
		if expected_server_key.size()!=32:
			if not portal_handoff.is_empty():direct_dispose_portal_handoff(portal_handoff)
			if direct_started_from_browser:direct_browser_view("Invalid server public identity")
			else:fail("Invalid server public identity")
			return
	if portal_handoff.get("session") is Node:
		var prepared_session: Node=portal_handoff.session
		if closing or not is_instance_valid(prepared_session):
			direct_dispose_portal_handoff(portal_handoff)
			return
		await direct_begin_connect(server_host,server_port,server_password,temporary_cd_key,player_name,portal_handoff,str(portal_handoff.install),portal_handoff.startup,portal_handoff.get("serverInfo",{}),bool(portal_handoff.get("serverInfoUnavailable",false)),expected_server_key)
		return
	var install:=str(args.get("direct-install",ProjectSettings.globalize_path("res://../../FullDecomp/NwnRootInstall")))
	var startup: Dictionary=StartupPaths.resolve(install)
	if startup.has("error"):
		if portal_handoff.get("identity") is RefCounted:portal_handoff.identity.dispose()
		fail(str(startup.error));return
	direct_cancel_join_policy_query()
	direct_lobby_page_reset()
	direct_lobby_state={"phase":"connecting","endpoint":{"host":server_host,"port":server_port},"busy":true,"canCancelJoin":true,"connected":false}
	direct_show_character_state()
	character_lobby.show_sync_wait()
	label.text="Checking server character policy…"
	var policy_serial:=direct_join_policy_serial
	direct_join_policy_query=ServerQuery.new();host.add_child(direct_join_policy_query)
	var query: Node=direct_join_policy_query
	var server_info: Dictionary={}
	var server_info_unavailable:=false
	if query.query(server_host,server_port):
		var answer: Array=await query.completed
		if answer.size()==2 and str(answer[1]).is_empty() and answer[0] is Dictionary:server_info=answer[0]
		else:server_info_unavailable=true
	else:server_info_unavailable=true
	if closing or policy_serial!=direct_join_policy_serial:
		if portal_handoff.get("identity") is RefCounted:portal_handoff.identity.dispose()
		return
	if is_instance_valid(query):query.close();query.queue_free()
	direct_join_policy_query=null
	await direct_begin_connect(server_host,server_port,server_password,temporary_cd_key,player_name,portal_handoff,install,startup,server_info,server_info_unavailable,expected_server_key)

func direct_cancel_join_policy_query()->void:
	direct_join_policy_serial+=1
	if not is_instance_valid(direct_join_policy_query):direct_join_policy_query=null;return
	var query: Node=direct_join_policy_query
	direct_join_policy_query=null
	query.close()
	query.completed.emit({},"Join cancelled")
	query.queue_free()

func direct_begin_connect(server_host: String,server_port: int,server_password: String,temporary_cd_key: String,player_name: String,portal_handoff: Dictionary,install: String,startup: Dictionary,server_info: Dictionary,server_info_unavailable: bool,expected_server_key: PackedByteArray)->void:
	if direct_session_failure_journal==null:direct_session_failure_journal=SessionFailureJournal.new(report,str(args.get("report","")))
	direct_raw_deltas.reset();direct_raw_refresh_pending=false
	direct_diagnostic_context_mode="multiplayer"
	direct_retire_local_file();direct_local_file_last_token=-1
	var profile:=str(args.get("direct-profile",startup.userDirectory))
	direct_retire_pending_preview()
	direct_vault_server_play_stage=0;direct_vault_server_key=""
	direct_server_port=server_port
	direct_camera_state=null;direct_camera_queue.clear();direct_camera_target_id=-1;direct_camera_pending_entry_attach=false;direct_camera_appearance_job=-1;direct_camera_appearance_table={};direct_camera_height_cache.clear()
	server_label=server_host;root.title="NWN · Godot direct · "+server_host
	direct_keyboard_reset()
	direct_session=portal_handoff.get("session") if portal_handoff.get("session") is Node else DirectSession.new()
	direct_session.text_events=direct_text_events
	direct_session.text_event_connection=session_connection
	direct_session.visibility_frames=direct_visibility_frames
	direct_session.audio_frames=direct_audio_frames
	direct_session.portal_endpoint_allowed=Callable(self,"direct_portal_endpoint_allowed")
	if direct_session.get_parent()==null:host.add_child(direct_session)
	var policy_known: bool=direct_session.local_vault_policy_known or direct_session.set_server_vault_policy(server_info,server_host,server_port)
	publish_device_properties()
	report.direct_vault_policy={"known":policy_known,"localAllowed":direct_session.local_vault_allowed,"source":"fresh-BNXR" if policy_known else "unavailable"}
	report.direct_character_list={"acceptedPackets":0,"receivedServerRows":0,"projectedServerRows":0,"projectedLocalRows":0,"projectedSavedRows":0,"phase":"connecting"}
	direct_lobby_state={"phase":"connecting","endpoint":{"host":server_host,"port":server_port},"busy":true,"canCancelJoin":true,"connected":false}
	direct_show_character_state()
	character_lobby.show_sync_wait()
	if not is_instance_valid(direct_placed_sounds):
		direct_placed_sounds=PlacedSounds.new();host.add_child(direct_placed_sounds)
	# src/main.js updates the listener/output before ambient, then placed
	# sounds on each network frame. Effect world (45) updates listener owners
	# before world audio (110); these two presentation owners follow in order.
	direct_placed_sounds.process_priority=130
	direct_placed_sounds.configure(null,func()->Dictionary:return direct_session.world_state.time if direct_session!=null else {},func()->Dictionary:return direct_session.world_state.registry if direct_session!=null else {},func()->int:return direct_session.world_state.area_id if direct_session!=null else -1)
	var placed_diagnostic_session: Node=direct_session
	var placed_diagnostic_connection:=session_connection
	direct_placed_sounds.diagnostic=func(code: String,reason: String,context: Dictionary)->void:
		if closing or not is_same(direct_session,placed_diagnostic_session) or session_connection!=placed_diagnostic_connection:return
		var event: Dictionary={"code":code,"reason":reason}
		event.merge(context.duplicate(true))
		direct_session.diagnostic_event.emit(event)
	direct_ambient_audio=AmbientAudio.new();host.add_child(direct_ambient_audio)
	direct_ambient_audio.process_priority=120
	var ambient_diagnostic_session: Node=direct_session
	var ambient_diagnostic_connection:=session_connection
	direct_ambient_audio.diagnostic=func(code: String,reason: String,context: Dictionary)->void:
		if closing or not is_same(direct_session,ambient_diagnostic_session) or session_connection!=ambient_diagnostic_connection:return
		var event: Dictionary={"code":code,"reason":reason}
		event.merge(context.duplicate(true))
		direct_session.diagnostic_event.emit(event)
	direct_voice_queue.clear()
	direct_session.catalog_ready.connect(direct_catalog_ready)
	direct_session.phase_changed.connect(direct_phase_changed)
	var visibility_session: Node=direct_session
	var visibility_connection:=session_connection
	direct_session.visibility_frame_ready.connect(func(frame: Dictionary):
		if not closing and is_same(direct_session,visibility_session) and session_connection==visibility_connection:receive(frame))
	direct_session.script_sound_frame_ready.connect(func(frame: Dictionary):
		if not closing and is_same(direct_session,visibility_session) and session_connection==visibility_connection:receive(frame))
	var lobby_status_session: Node=direct_session
	var lobby_status_connection:=session_connection
	direct_session.server_status_ready.connect(func(status: Dictionary):
		if closing or not is_same(direct_session,lobby_status_session) or session_connection!=lobby_status_connection:return
		var code: Variant={"server-loading":1,"server-unavailable":0,"server-resources":2}.get(str(status.get("kind","")))
		if code is int:
			direct_lobby_state.serverStatus=code
			direct_show_character_state())
	var progress_session: Node=direct_session
	var progress_connection:=session_connection
	direct_session.resource_progress_detail.connect(func(state: Dictionary):
		if not closing and is_same(direct_session,progress_session) and session_connection==progress_connection:direct_resource_progress(state))
	var diagnostic_pair: Dictionary={"code":""}
	var diagnostic_session: Node=direct_session
	var diagnostic_connection:=session_connection
	direct_session.diagnostic.connect(func(code: String,_reason: String):
		var rows: Array=report.get("direct_resource_diagnostics",[])
		if str(diagnostic_pair.code)==code:diagnostic_pair.code=""
		else:
			if rows.size()<16:rows.append({"code":code});report.direct_resource_diagnostics=rows
			if direct_diagnostics!=null and is_same(direct_session,diagnostic_session) and session_connection==diagnostic_connection:direct_diagnostics.record(code,_reason)
		if code=="network.nwsync-native-cache-failed":push_warning("Installed content cache unavailable; fetching required content"))
	direct_session.diagnostic_event.connect(func(event: Dictionary):
		direct_session_failure_journal.record(event,diagnostic_connection)
		var detail: Dictionary=event.duplicate(true)
		diagnostic_pair.code=str(detail.get("code",""))
		if direct_diagnostics!=null and is_same(direct_session,diagnostic_session) and session_connection==diagnostic_connection:direct_diagnostics.record(str(detail.get("code","runtime.failure")),str(detail.get("reason",detail.get("message",""))),detail,"error" if str(detail.get("code","")).ends_with("-failed") else "warning")
		var rows: Array=report.get("direct_resource_diagnostics",[])
		if rows.size()<16:rows.append(detail)
		report.direct_resource_diagnostics=rows
		if is_same(direct_session,diagnostic_session) and session_connection==diagnostic_connection and str(detail.get("code","")).begins_with("network.character-"):
			direct_lobby_state.error=str(detail.get("reason",""))
			if detail.has("strRef"):direct_lobby_state.characterRejection=detail.duplicate(true)
			else:direct_lobby_state.erase("characterRejection")
			direct_show_character_state())
	if server_info_unavailable:
		var unavailable: Dictionary={"code":"network.server-info-unavailable","reason":"Public server vault policy could not be queried"}
		direct_session.diagnostic_event.emit(unavailable)
		direct_session.diagnostic.emit(str(unavailable.code),str(unavailable.reason))
	var starting_session: Node=direct_session
	if native_clock_runtime!=null:
		report.native_clock_attach=native_clock_runtime.attach_direct_session(starting_session,session_connection)
	direct_session.character_list_ready.connect(direct_character_list)
	direct_session.lobby_players_ready.connect(direct_lobby_players)
	direct_session.character_preview_ready.connect(func(preview: Dictionary):
		if direct_preview_connection_current(diagnostic_session,diagnostic_connection):direct_character_preview(preview))
	direct_session.character_rejected_ready.connect(func(message: Dictionary):
		if direct_preview_connection_current(diagnostic_session,diagnostic_connection):direct_character_rejected(message))
	direct_session.module_information_ready.connect(direct_module_ready)
	var snapshot_session: Node=direct_session
	var snapshot_connection:=session_connection
	direct_session.area_state_ready.connect(func(entry: Dictionary):
		if not closing and is_same(direct_session,snapshot_session) and session_connection==snapshot_connection:direct_area_ready(entry))
	direct_session.roster_message_ready.connect(func(_message: Dictionary):direct_present_area())
	direct_session.object_updates_ready.connect(func(message: Dictionary):
		if args.get("direct-headless-local-smoke-check","")=="true":
			for row in message.get("records",[]):
				if int(row.get("id",0))==int(direct_session.world_state.local_object_id) and row.get("state",{}).has("position"):direct_local_smoke_update_serial+=1
		direct_present_area())
	direct_session.movement_ready.connect(direct_movement)
	direct_session.scene_changes_ready.connect(direct_scene_changes)
	direct_session.bind_direct_world_publisher(func(data: Dictionary,static_rows: RawWorldDeltas.StaticRows):
		if not closing and is_same(direct_session,snapshot_session) and session_connection==snapshot_connection:
			_direct_accept_projection(data,static_rows,direct_world_ready),true)
	direct_session.inventory_response_ready.connect(func(message: Dictionary):
		if args.get("direct-headless-item-action-check","")=="true" and int(message.get("itemId",-1))==direct_item_id:report.direct_item_response=message.duplicate(true)
		if not closing and direct_session!=null and direct_session.phase=="playing":receive({"kind":"ui-protocol","connection":session_connection,"generation":epoch,"message":message}))
	direct_session.ui_message_ready.connect(func(message: Dictionary):
		if str(message.get("kind",""))=="character-saved":return
		if str(message.get("kind","")) in ["custom-token","tlk-overrides"]:
			if not closing and direct_session!=null and is_instance_valid(gameplay_ui):gameplay_ui.receive(message,epoch,session_connection)
			return
		if args.get("direct-headless-levelup-check","")=="true" and str(message.get("action",""))=="native-level-up":
			direct_levelup_events.append({"operation":str(message.get("operation","")),"accepted":bool(message.get("accepted",false)),"serverAccepted":bool(message.get("result",{}).get("accepted",false)),"availableCount":message.get("result",{}).get("available",[]).size()})
		if args.get("direct-headless-chat-dialog-check","")=="true":
			if message.get("kind")=="server-speech" and str(message.get("text",{}).get("text",""))=="Godot original server check":direct_speech_echo=true
			if str(message.get("kind","")).begins_with("dialog-"):direct_dialog_events.append(str(message.kind))
		if args.get("direct-headless-local-smoke-check","")=="true" and message.get("kind")=="server-speech" and str(message.get("text",{}).get("text",""))=="Godot direct local smoke":direct_local_smoke_speech_echo=true
		if not closing and direct_session!=null and direct_session.phase=="playing":receive({"kind":"ui-protocol","connection":session_connection,"generation":epoch,"message":message}))
	direct_session.system_notice_ready.connect(func(notice: Dictionary):
		if not closing and direct_session!=null and direct_session.phase=="playing":receive({"kind":"ui-protocol","connection":session_connection,"generation":epoch,"message":{"kind":"system-notice"}.merged(notice,true)}))
	direct_session.targeting_ready.connect(func(_message: Dictionary):
		if closing or direct_session==null or direct_session.phase!="playing" or not is_instance_valid(gameplay_ui) or direct_generation!=direct_session.area_generation:return
		var state=direct_session.world_state
		gameplay_ui.receive_immediate_targeting(direct_generation,int(state.area_id),int(state.local_object_id),{"scriptTargeting":state.script_targeting,"scriptTargetingData":state.script_targeting_data,"spellTargetingOverrides":state.spell_targeting_overrides}))
	direct_session.area_visual_ready.connect(direct_scene_area_visual_received)
	direct_session.sound_object_ready.connect(func(message: Dictionary):
		if closing or direct_session==null or not is_instance_valid(direct_placed_sounds) or int(direct_placed_sounds.area.get("id",-1))!=direct_session.world_state.area_id:return
		var record: Dictionary=direct_session.world_state.registry.get(int(message.objectId),{})
		direct_placed_sounds.command(message,record))
	direct_session.ambient_command_ready.connect(direct_ambient_command)
	direct_session.time_changed.connect(direct_ambient_time)
	direct_session.object_visual_ready.connect(direct_scene_object_visual_received)
	direct_session.camera_command_ready.connect(direct_camera_command)
	direct_session.creature_voice_ready.connect(direct_creature_voice)
	direct_session.projectile_ready.connect(direct_scene_projectile_received)
	direct_session.character_export_status_ready.connect(direct_character_export_status)
	var portal_origin: Node=direct_session
	var portal_origin_connection:=session_connection
	direct_session.portal_handoff_ready.connect(func(handoff: Dictionary):direct_portal_handoff.call_deferred(handoff,portal_origin,portal_origin_connection))
	direct_session.portal_prepare=Callable(self,"direct_prepare_portal_destination")
	direct_session.quickbar_ready.connect(func(_message: Dictionary):direct_quickbar_received=true)
	direct_session.session_failed.connect(func(reason: String):
		if direct_session!=null and not direct_session.client_failure.is_empty():report.direct_client_failure=direct_session.client_failure.duplicate(true)
		if direct_started_from_browser:direct_connection_failed(reason)
		else:fail("Godot original-server session failed: "+reason))
	if not portal_handoff.is_empty():
		if not direct_session.configure_portal(portal_handoff.identity,portal_handoff.character,str(portal_handoff.waypoint),portal_handoff.get("workshopSelection",{})):
			direct_dispose_portal_handoff(portal_handoff)
			fail("Portal destination character could not be prepared");return
		if portal_handoff.get("character",{}).get("data") is PackedByteArray:portal_handoff.character.data.fill(0)
	var started: bool=await starting_session.start(server_host,server_port,profile,install,server_password,temporary_cd_key,player_name,str(args.get("direct-settings","")),true,expected_server_key)
	if closing or direct_session!=starting_session:return
	if not started:
		if not direct_started_from_browser:fail("Godot original-server session could not start: "+str(starting_session.error))
		return
	if not portal_handoff.is_empty() and report.has("direct_portal_check"):report.direct_portal_check.destination_auth_started=true
	var saved: Dictionary=direct_session.saved_character_list()
	if direct_session.local_vault_allowed and saved.get("ready",false):direct_lobby_state.savedCharacters=saved.entries
	label.text="Connecting to "+server_host+" with Godot networking…"
	if args.get("direct-headless-check","")=="true":direct_check_deadline=Time.get_ticks_msec()+75000
	if str(args.get("direct-headless-vault-policy-check","")) in ["server-only","local-allowed","server-only-play"]:direct_check_deadline=Time.get_ticks_msec()+(120000 if args.get("direct-headless-vault-policy-check","")=="server-only-play" else 75000)
	if args.get("direct-headless-levelup-check","")=="true":direct_check_deadline=Time.get_ticks_msec()+180000
	if args.get("direct-headless-local-smoke-check","")=="true":direct_check_deadline=Time.get_ticks_msec()+90000
	if args.get("direct-headless-character-export-check","")=="true":direct_check_deadline=Time.get_ticks_msec()+90000
	if args.get("direct-headless-portal-check","")=="true":direct_check_deadline=Time.get_ticks_msec()+120000
	if not direct_nwsync_visual_descriptor.is_empty():direct_check_deadline=Time.get_ticks_msec()+120000
	if args.get("direct-headless-nwsync-cancel-check","")=="true":direct_check_deadline=Time.get_ticks_msec()+30000
	if args.get("direct-server-vault-create-check","")=="true":direct_check_deadline=Time.get_ticks_msec()+300000
	if args.get("direct-server-vault-reconnect-check","")=="true":direct_check_deadline=Time.get_ticks_msec()+120000

func direct_phase_changed(phase: String)->void:
	report.direct_status={"phase":phase,"catalog_adopted":direct_catalog_adopted,"area_presented":direct_area_presented,"generation":direct_generation,"snapshots":received,"characterListPackets":int(report.get("direct_character_list",{}).get("acceptedPackets",0)),"serverCharacterRows":int(report.get("direct_character_list",{}).get("receivedServerRows",0))}
	if phase not in ["character-selection","character-rejected"] and direct_lobby_page!=0:direct_lobby_page_reset()
	if phase in ["area-loading","playing"]:direct_lobby_state.creating=false
	if closing or not is_instance_valid(character_lobby):return
	if is_instance_valid(gameplay_ui) and phase in ["area-loading","playing"]:gameplay_ui.creator.observe({"phase":phase})
	if phase in ["connecting","resources","loading-content"]:
		direct_lobby_state.phase="resources" if phase=="loading-content" else phase
		if phase=="loading-content":direct_lobby_state.serverStatus=2
		direct_lobby_state.busy=true
		direct_lobby_state.canCancelJoin=true
		direct_show_character_state()
		character_lobby.show_sync_wait()
	elif phase=="playing":
		direct_lobby_state.phase="playing"
		direct_lobby_state.busy=false
		direct_lobby_state.canCancelJoin=false
		direct_lobby_state.connected=true
		direct_lobby_state.erase("resourceProgress")
		direct_show_character_state()
		if direct_raw_refresh_pending and direct_raw_deltas.pending.is_empty():direct_refresh_world_after_ack.call_deferred(session_connection,direct_generation)
	elif phase=="character-rejected":
		direct_lobby_state.phase="character-rejected"
		direct_lobby_state.busy=false
		direct_lobby_state.connected=true
		direct_lobby_state.canSelect=not direct_lobby_state.get("choices",[]).is_empty()
		direct_show_character_state()
	elif phase in ["characters","character-selection","character-loading","area-loading","area-presenting","transferring","portal-ready","portal-character-pending"]:
		direct_lobby_state.phase="transferring" if phase=="portal-ready" else phase
		if phase=="transferring":direct_lobby_state.busy=true
		direct_show_character_state()

func direct_resource_progress(detail: Dictionary)->void:
	if closing or direct_session==null or direct_session.phase!="loading-content":return
	direct_lobby_state.phase="resources"
	direct_lobby_state.busy=true
	var projected: Variant=ResourceProgress.finite_resource_progress(detail)
	if projected is Dictionary:direct_lobby_state.resourceProgress=projected
	else:direct_lobby_state.erase("resourceProgress")
	direct_show_character_state()
	character_lobby.show_sync_wait()
	if not projected is Dictionary:return
	var stage:=str(projected.phase)
	var completed:=int(projected.completed)
	var total:=int(projected.total)
	if not direct_nwsync_visual_descriptor.is_empty() and direct_nwsync_visual_progress.size()<128:
		var native_cancel=character_lobby.native_wait_cancel
		direct_nwsync_visual_progress.append({"phase":stage,"completed":completed,"total":total,"lobbyPhase":str(character_lobby.state.get("phase","")),"cancelVisible":is_instance_valid(native_cancel) and native_cancel.is_visible_in_tree() and not native_cancel.disabled,"playGated":character_lobby.play_button.disabled,"playVisible":character_lobby.play_button.is_visible_in_tree(),"cancelOwner":"native-wait-cancel"})
	if args.get("direct-headless-nwsync-cancel-check","")=="true" and not direct_nwsync_cancel_pending and stage=="server-manifest":
		direct_nwsync_cancel_pending=true
		direct_nwsync_cancel_test.call_deferred()

func direct_nwsync_cancel_test()->void:
	await process_frame
	if closing or direct_session==null or direct_session.phase!="loading-content":fail("NWSync Cancel fixture did not reach active content loading");return
	var ready_path:=str(args.get("direct-nwsync-fixture-ready",""))
	var listener_started:=false
	if not ready_path.is_empty():
		var deadline_ms:=Time.get_ticks_msec()+2500
		while Time.get_ticks_msec()<deadline_ms:
			if FileAccess.file_exists(ready_path):
				var starts:=FileAccess.get_file_as_string(ready_path)
				if starts.contains("/manifests/") and starts.contains(" started"):
					listener_started=true
					break
			await create_timer(0.05).timeout
		if not listener_started:fail("NWSync Cancel fixture did not observe the delayed manifest request start");return
	else:
		await create_timer(0.5).timeout
	if closing or direct_session==null or direct_session.phase!="loading-content":fail("NWSync Cancel fixture lost the active content request");return
	var repository: Node=direct_session.repository
	var pending_requests:=0
	if is_instance_valid(repository):
		for child in repository.get_children():
			if child is HTTPRequest:pending_requests+=1
	var visible_cancel=character_lobby.native_wait_cancel
	if pending_requests<1 or not bool(character_lobby.state.get("canCancelJoin",false)) or not is_instance_valid(visible_cancel) or not visible_cancel.is_visible_in_tree() or visible_cancel.disabled:
		fail("NWSync Cancel fixture did not find an active request and enabled Cancel control")
		return
	report.direct_nwsync_cancel={"phase_before":direct_session.phase,"pending_requests_before":pending_requests,"listener_started":listener_started,"via":"visible-native-wait-cancel-button"}
	visible_cancel.pressed.emit()
	report.direct_nwsync_cancel.session_released=direct_session==null
	report.direct_nwsync_cancel.repository_closed=repository.closed if is_instance_valid(repository) else true
	report.direct_nwsync_cancel.world_retired=not is_instance_valid(world)
	report.direct_nwsync_cancel.lobby_phase=str(character_lobby.state.get("phase",""))
	if not report.direct_nwsync_cancel.session_released or not report.direct_nwsync_cancel.repository_closed or not report.direct_nwsync_cancel.world_retired or report.direct_nwsync_cancel.lobby_phase!="menu":
		fail("NWSync Cancel did not retire the active Godot session and return to menu")
		return
	direct_check_deadline=0
	shutdown.call_deferred()

func direct_graphical_menu_test_start()->void:
	if DisplayServer.get_name()=="headless":fail("Godot graphical menu check requires a visible display");return
	await open_startup_menu()
	if closing or not bool(report.get("startup_menu",{}).get("ready",false)) or not bool(report.startup_menu.get("mainVisible",false)):fail("Godot graphical main menu did not become visible");return
	server_browser.open(false,true)
	var deadline:=Time.get_ticks_msec()+15000
	while not closing and Time.get_ticks_msec()<deadline and (server_browser.view_id<1 or not is_instance_valid(server_browser.entry_menu) or not server_browser.entry_menu.visible):await process_frame
	if closing:return
	var chooser_ready: bool=server_browser.wanted and server_browser.view_id>0 and is_instance_valid(server_browser.entry_menu) and server_browser.entry_menu.visible and server_browser.entry_menu.art_ready()
	report.direct_graphical_menu_check={"main_menu_ready":true,"main_menu_visible_before_chooser":true,"chooser_ready":chooser_ready,"chooser_visible":is_instance_valid(server_browser.entry_menu) and server_browser.entry_menu.visible,"connected":direct_session!=null,"display":DisplayServer.get_name(),"screen":root.current_screen,"primary_screen":DisplayServer.get_primary_screen(),"screen_count":DisplayServer.get_screen_count(),"window_visible":root.visible,"window_size":[root.size.x,root.size.y]}
	if not chooser_ready or direct_session!=null or not root.visible:fail("Godot graphical server chooser did not become visible");return
	print("NWN79_GODOT_GRAPHICAL_MENU_PASS screen=",root.current_screen," size=",root.size)
	shutdown.call_deferred()

func direct_graphical_menu_exit_test_start()->void:
	if DisplayServer.get_name()=="headless":fail("Godot graphical Exit check requires a visible display");return
	await open_startup_menu()
	if closing:return
	var page=render_menu.pregame if is_instance_valid(render_menu) else null
	var button=page.main.buttons.get("exitbutton") if is_instance_valid(page) and is_instance_valid(page.main) else null
	var ready: bool=bool(report.get("startup_menu",{}).get("ready",false)) and bool(report.startup_menu.get("mainVisible",false)) and direct_session==null and not is_instance_valid(world) and is_instance_valid(button) and button.is_visible_in_tree() and not button.disabled
	report.direct_menu_exit_check={"success":ready,"resource":"pre_main","control":"exitbutton","world_present":is_instance_valid(world),"connected":direct_session!=null,"display":DisplayServer.get_name(),"screen":root.current_screen,"window_visible":root.visible,"via":"pressed-signal"}
	if not ready:fail("Godot direct main-menu Exit control is unavailable");return
	button.pressed.emit()

func direct_browser_test_start()->void:
	await open_startup_menu()
	if closing or not bool(report.get("startup_menu",{}).get("ready",false)):fail("Godot direct main menu did not prepare installed resources");return
	server_browser.open(true,true)
	await process_frame
	if closing or not server_browser.wanted or str(server_browser.state.get("tab",""))!="Direct" or server_browser.view_id<1:fail("Godot direct browser did not open");return
	report.direct_browser_check={"menu_layout_ready":true,"browser_visible":server_browser.wanted,"saved_profile":not str(ticket.get("directProfile",{}).get("name","")).is_empty(),"direct_tab":true,"graphical_preload_accepted":false}
	var active_name:=str(ticket.get("directProfile",{}).get("name",""))
	server_browser.name_edit.text="Invalid Test Profile"
	server_browser.confirm_direct("127.0.0.1:5121","",[server_browser.connection,server_browser.view_id])
	await process_frame
	if closing or direct_session!=null or not str(server_browser.state.get("status","")).contains("active login profile"):fail("Godot direct browser did not reject a mismatched profile");return
	report.direct_browser_check.mismatched_profile_rejected=true
	server_browser.name_edit.text=active_name
	server_browser.key_edit.text="BAD"
	server_browser.confirm_direct("127.0.0.1:5121","",[server_browser.connection,server_browser.view_id])
	# Invalid temporary credentials can finish after the browser's next frame.
	# Wait only for this exact rejection; a successful join or lost browser is a
	# wrong terminal state, and the bounded deadline still fails the fixture.
	var invalid_key_deadline:=Time.get_ticks_msec()+3000
	while not closing and Time.get_ticks_msec()<invalid_key_deadline:
		if direct_session==null and str(server_browser.state.get("status","")).contains("temporary CD key format"):break
		if not server_browser.wanted or (direct_session!=null and direct_session.phase in ["characters","character-selection","area-loading","area-presenting","playing"]):break
		await process_frame
	if closing or direct_session!=null or not str(server_browser.state.get("status","")).contains("temporary CD key format"):fail("Godot direct browser did not recover from invalid temporary credentials");return
	report.direct_browser_check.invalid_temporary_key_rejected=true
	server_browser.name_edit.text=active_name
	server_browser.confirm_direct("127.0.0.1:5121","",[server_browser.connection,server_browser.view_id])

func direct_fresh_user_test_start()->void:
	await open_startup_menu()
	if closing or not bool(report.get("startup_menu",{}).get("ready",false)):fail("Godot clean setup did not reach the main menu");return
	if direct_login_profiles.status().hasSavedCdKey or not direct_login_profiles.status().loginProfiles.is_empty():fail("Godot clean setup is not using an empty settings profile");return
	server_browser.open(true,true)
	await process_frame
	if closing or not server_browser.wanted or server_browser.view_id<1:fail("Godot clean setup did not open the Direct browser");return
	server_browser.name_edit.text="NWN79 Tester"
	server_browser.key_edit.text="BAD"
	server_browser.confirm_direct("127.0.0.1:5121","",[server_browser.connection,server_browser.view_id])
	await process_frame
	if closing or direct_session!=null or not str(server_browser.state.get("status","")).contains("temporary CD key format"):fail("Godot clean setup did not reject an invalid temporary key");return
	var install:=str(args.get("direct-install",ProjectSettings.globalize_path("res://../../FullDecomp/NwnRootInstall")))
	var source: Dictionary=StartupPaths.resolve(install)
	if source.has("error"):fail("Godot recovery source is unavailable");return
	var saved:=ClientSettingsStore.new()
	if not saved.open(str(source.settingsDirectory),str(source.defaultModsDirectory)):fail("Existing protected recovery source is unavailable");return
	var credential: Dictionary=saved.cd_key()
	saved.close()
	if credential.has("error"):fail("Existing protected recovery key could not be unlocked");return
	server_browser.name_edit.text="NWN79 Tester"
	server_browser.key_edit.text=str(credential.cdKey)
	report.direct_fresh_user={"empty_settings":true,"manual_player_name":true,"invalid_key_rejected":true,"temporary_key":true}
	server_browser.confirm_direct("127.0.0.1:5121","",[server_browser.connection,server_browser.view_id])
	server_browser.key_edit.clear()
	credential.cdKey=""

func direct_directory_test_start()->void:
	await open_startup_menu()
	if closing or not bool(report.get("startup_menu",{}).get("ready",false)):fail("Godot Internet browser did not prepare installed resources");return
	direct_directory_rows=[{"entryId":0,"host":"127.0.0.1","port":5121,"serverName":"Owned Prelude","moduleName":"Prelude","allowLocalVaultCharacters":true,"passwordRequired":false,"playerCount":1,"maximumPlayers":2,"allowed":true}]
	direct_directory_loaded=true
	server_browser.open(true,true,"Internet")
	await process_frame
	if closing or str(server_browser.state.get("tab",""))!="Internet" or server_browser.entries.size()!=1 or server_browser.view_id<1:fail("Godot Internet browser did not show the admitted fixture server");return
	server_browser._send("select",{"entryId":0})
	await process_frame
	if closing or server_browser.selected!=0 or int(server_browser.state.get("selectionAck",{}).get("port",0))!=5121:fail("Godot Internet browser did not acknowledge server selection");return
	report.direct_directory_check={"listed":true,"selected":true,"electron_free":true}
	server_browser.submit_selected_join("")

func direct_history_test_start()->void:
	await open_startup_menu()
	if closing or not bool(report.get("startup_menu",{}).get("ready",false)):fail("Godot History check did not reach the main menu");return
	server_browser.open(true,true,"History")
	await process_frame
	if closing or str(server_browser.state.get("tab",""))!="History" or server_browser.entries.is_empty():fail("Godot History check did not show the saved server");return
	server_browser._send("select",{"entryId":0})
	await process_frame
	if closing or server_browser.selected!=0:fail("Godot History selection was not acknowledged");return
	server_browser._send("favorite",{"direct":false,"entryId":0,"on":true})
	await process_frame
	if closing or direct_browser_store.rows("Favorites").is_empty():fail("Godot History favorite was not persisted");return
	server_browser._send("tab",{"tab":"Favorites","sourcePage":true})
	await process_frame
	if closing or str(server_browser.state.get("tab",""))!="Favorites" or server_browser.entries.is_empty():fail("Godot Favorites tab did not show the saved server");return
	server_browser._send("select",{"entryId":0})
	await process_frame
	if closing or server_browser.selected!=0:fail("Godot Favorites selection was not acknowledged");return
	report.direct_history_check={"history_listed":true,"favorite_persisted":true,"favorites_listed":true,"selected":true}
	server_browser.submit_selected_join("")

func direct_inspect_test_start()->void:
	await open_startup_menu()
	if closing or not bool(report.get("startup_menu",{}).get("ready",false)):fail("Godot Server info check did not reach the main menu");return
	server_browser.open(true,true)
	await process_frame
	if closing or not server_browser.wanted or server_browser.view_id<1:fail("Godot Server info check did not open the Direct browser");return
	server_browser._send("inspect",{"direct":true,"values":{"host":"127.0.0.1","port":5121}})
	await direct_server_query.completed
	if closing or direct_browser_busy or str(server_browser.state.get("details",{}).get("moduleName",""))!="Prelude" or not bool(server_browser.state.get("details",{}).get("extendedReceived",false)):fail("Godot Server info did not reach the browser details view");return
	report.direct_inspect_check={"native_udp":true,"module":"Prelude","extended":true,"browser_details":true}
	server_browser.confirm_direct("127.0.0.1:5121","",[server_browser.connection,server_browser.view_id])

func direct_connection_failed(reason: String)->void:
	if closing:return
	direct_raw_deltas.reset();direct_raw_refresh_pending=false
	direct_cancel_join_policy_query()
	direct_lobby_page_reset()
	report.direct_last_error=reason
	var client_failure_detail: Dictionary=direct_session.client_failure.duplicate(true) if direct_session!=null else {}
	if not client_failure_detail.is_empty():report.direct_client_failure=client_failure_detail.duplicate(true)
	direct_finish_queued_visual_receipts("closed")
	if direct_scene_delivery!=null:direct_scene_delivery.dispose();direct_scene_delivery=null
	if direct_visual_presentation!=null:direct_visual_presentation.dispose();direct_visual_presentation=null
	direct_visual_queue.clear();direct_voice_queue.clear();direct_projectile_queue.clear();direct_module_pause_queue.clear()
	if is_instance_valid(direct_placed_sounds):direct_placed_sounds.detach()
	if is_instance_valid(direct_ambient_audio):direct_ambient_audio.close();direct_ambient_audio.queue_free();direct_ambient_audio=null
	direct_browser_join_row.clear();direct_browser_join_name=""
	direct_lobby_choices.clear();direct_lobby_state.clear();selected_character.clear()
	direct_retire_local_file();direct_local_file_last_token=-1
	direct_retire_pending_preview()
	direct_catalog_adopted=false;direct_area_presented=false;direct_quickbar_received=false
	if direct_session!=null:
		direct_keyboard_reset()
		direct_session.close();direct_session.queue_free();direct_session=null
	var menu_state: Dictionary={"phase":"menu","canJoin":true}
	if not client_failure_detail.is_empty():menu_state.clientFailure=client_failure_detail
	character_lobby.apply_state({"connection":session_connection,"state":menu_state})
	character_lobby.panel.hide()
	server_browser.receive({"kind":"browser-notice","connection":session_connection,"text":reason})
	direct_browser_view(reason)

func direct_source_sort(tab: String)->Dictionary:
	return {"order":[2,0,1,3,4,5] if tab=="Internet" else [0,1,2,3,4,5],"ascending":[true,true,false,true,true,true] if tab=="Internet" else [true,true,true,true,true,true],"header":2}

func direct_ascii_lower(value: Variant)->String:
	var text: String=str(value) if value!=null else ""
	const LOWER="abcdefghijklmnopqrstuvwxyz"
	var result: String=""
	for index in text.length():
		var code:=text.unicode_at(index)
		result+=LOWER.substr(code-65,1) if code>=65 and code<=90 else text.substr(index,1)
	return result

func direct_source_values(row: Dictionary)->Array:
	return [direct_ascii_lower(row.get("serverName")),direct_ascii_lower(row.get("moduleName")),int(row.get("playerCount",0))*256+int(row.get("maximumPlayers",0)),int(row.get("minimumLevel",0))*100+int(row.get("maximumLevel",0)),direct_ascii_lower(row.get("pvpSetting")),"ok" if row.get("syncAvailable")==true else "need" if row.get("syncAvailable")==false else ""]

func direct_source_before(a: Dictionary,b: Dictionary,sort_state: Dictionary)->bool:
	var av:=direct_source_values(a);var bv:=direct_source_values(b)
	for column in sort_state.order:
		var index: int=int(column)
		if av[index]==bv[index]:continue
		return (av[index]<bv[index]) if sort_state.ascending[index] else (av[index]>bv[index])
	return int(a._browser_sort_position)<int(b._browser_sort_position)

func direct_visible_rows()->Array[Dictionary]:
	var rows: Array[Dictionary]=[]
	var source: Array[Dictionary]=direct_directory_rows if direct_browser_tab=="Internet" else direct_browser_store.rows(direct_browser_tab) if direct_browser_store!=null else []
	var text_server:=TextServerManager.get_primary_interface()
	var language:=OS.get_locale_language()
	var needle:=text_server.string_to_lower(direct_browser_filter,language)
	for source_row in source:
		var row: Dictionary=source_row.duplicate(true)
		var key:=str(row.host)+":"+str(row.port)
		if direct_observed_rows.has(key):row.merge(direct_observed_rows[key],true)
		if direct_browser_tab=="Internet" and direct_browser_game_type!=null and row.get("gameType")!=direct_browser_game_type:continue
		if not bool(direct_browser_filters.get("local",true)) and row.get("allowLocalVaultCharacters")==true:continue
		if not bool(direct_browser_filters.get("server",true)) and row.get("allowLocalVaultCharacters")==false:continue
		if not bool(direct_browser_filters.get("password",true)) and bool(row.get("passwordRequired",false)):continue
		if bool(direct_browser_advanced.get("hideEmpty",false)) and row.get("playerCount")==0:continue
		if bool(direct_browser_advanced.get("hideFull",false)) and row.has("playerCount") and row.has("maximumPlayers") and row.playerCount==row.maximumPlayers:continue
		if not str(direct_browser_advanced.get("module","")).is_empty() and not str(row.get("moduleName","")).contains(str(direct_browser_advanced.module)):continue
		if not needle.is_empty() and not text_server.string_to_lower(str(row.get("serverName",""))+" "+str(row.get("moduleName",""))+" "+str(row.get("host","")),language).contains(needle):continue
		row._browser_sort_position=rows.size()
		rows.append(row)
	if direct_browser_source_page and direct_browser_source_sorts.has(direct_browser_tab):
		var sort_state: Dictionary=direct_browser_source_sorts[direct_browser_tab]
		rows.sort_custom(func(a,b):return direct_source_before(a,b,sort_state))
	else:
		match direct_browser_sort:
			"Name":rows.sort_custom(func(a,b):return str(a.serverName).nocasecmp_to(str(b.serverName))<0)
			"Module":rows.sort_custom(func(a,b):return str(a.moduleName).nocasecmp_to(str(b.moduleName))<0)
			"Latency":rows.sort_custom(func(a,b):return int(a.get("latency",999999))<int(b.get("latency",999999)))
			_:rows.sort_custom(func(a,b):return int(a.get("playerCount",0))>int(b.get("playerCount",0)))
	for row in rows:row.erase("_browser_sort_position")
	return rows

func direct_browser_view(notice: String="",selection_ack: Dictionary={})->void:
	if not is_instance_valid(server_browser):return
	direct_browser_view_id+=1
	if direct_browser_first_view_id<0:direct_browser_first_view_id=direct_browser_view_id
	var profile: Dictionary=ticket.get("directProfile",{})
	var active_name:=str(profile.get("name",""))
	var active_login: Variant=null
	if direct_login_profiles!=null:
		var profile_status: Dictionary=direct_login_profiles.status()
		for row in profile_status.get("loginProfiles",[]):
			if row.id==profile_status.activeProfileId:active_login={"id":row.id,"label":row.label,"playerName":row.playerName};break
	var manual_name:=direct_browser_session_name if not direct_browser_session_name.is_empty() else str(direct_browser_store.state.get("profileDefault","")) if direct_browser_store!=null else ""
	var browser_name:=active_name if not active_name.is_empty() else manual_name if not manual_name.is_empty() else str(direct_browser_store.state.get("last",{}).get("name","")) if direct_browser_store!=null else ""
	var last: Dictionary=direct_browser_store.state.get("last",{}) if direct_browser_store!=null else {}
	var all_rows: Array[Dictionary]=[]
	if direct_browser_tab in ["Internet","History","Favorites"]:all_rows=direct_visible_rows()
	if not direct_browser_selected_key.is_empty():
		direct_browser_selected=-1
		for row in all_rows:
			if direct_browser_key(row)==direct_browser_selected_key:direct_browser_selected=int(row.entryId);break
	var total:=all_rows.size();var pages:=maxi(1,ceili(float(total)/128.0))
	direct_browser_page=clampi(direct_browser_page,0,pages-1)
	var page_rows: Array[Dictionary]=[]
	for row in all_rows.slice(direct_browser_page*128,mini(total,(direct_browser_page+1)*128)):
		var visible: Dictionary=row.duplicate(true);visible.selected=int(row.entryId)==direct_browser_selected
		visible.allowed=direct_browser_store.permits_endpoint(visible,direct_browser_local_only,direct_browser_local_port)
		visible.favorite=false
		if direct_browser_store!=null:
			for favorite in direct_browser_store.state.favorites:
				if str(favorite.host)==str(row.host) and int(favorite.port)==int(row.port):visible.favorite=true;break
		page_rows.append(visible)
	var selected_row: Dictionary={}
	var source: Array[Dictionary]=direct_directory_rows if direct_browser_tab=="Internet" else direct_browser_store.rows(direct_browser_tab) if direct_browser_store!=null else []
	for row in source:
		if not direct_browser_selected_key.is_empty() and direct_browser_key(row)==direct_browser_selected_key:
			selected_row=row.duplicate(true)
			var key:=str(row.host)+":"+str(row.port)
			if direct_observed_rows.has(key):selected_row.merge(direct_observed_rows[key],true)
			break
	if direct_browser_tab=="Direct" and not direct_inspect_result.is_empty():selected_row=direct_inspect_result
	var position:=-1
	for index in all_rows.size():
		if int(all_rows[index].entryId)==direct_browser_selected:position=index;break
	if not selected_row.is_empty():selected_row.allowed=direct_browser_store.permits_endpoint(selected_row,direct_browser_local_only,direct_browser_local_port)
	var view: Dictionary={"kind":"browser-view","connection":session_connection,"viewId":direct_browser_view_id,"reopen":true,"tab":direct_browser_tab,"busy":direct_browser_busy,"inspecting":not direct_inspect_endpoint.is_empty(),"canJoin":direct_session==null and not bool(direct_lobby_state.get("canCancelJoin",false)),"canDiscover":not direct_browser_local_only,"localOnly":direct_browser_local_only,"localAllowedPort":direct_browser_local_port,"sourcePage":direct_browser_source_page,"sourceSort":direct_browser_source_sorts.get(direct_browser_tab,direct_source_sort(direct_browser_tab)),"gameType":direct_browser_game_type,"advancedFilters":direct_browser_advanced.duplicate(true),"hasSavedCdKey":bool(profile.get("hasSavedCdKey",false)),"hasSessionProfile":not active_name.is_empty() or not manual_name.is_empty(),"activeLoginProfile":active_login,"direct":{"host":str(last.get("host","127.0.0.1")),"port":int(last.get("port",5121)),"name":browser_name},"rows":page_rows,"page":direct_browser_page,"pages":pages,"total":total,"filter":direct_browser_filter,"sort":direct_browser_sort,"filters":direct_browser_filters.duplicate(true),"status":notice,"details":selected_row if not selected_row.is_empty() else null,"detailsPosition":{"index":position,"total":total,"canPrevious":position>0,"canNext":position>=0 and position+1<total},"refreshCooldownMs":maxi(0,direct_browser_refresh_ready_at-Time.get_ticks_msec())}
	if not selection_ack.is_empty():view.selectionAck=selection_ack
	server_browser.receive(view)

func direct_server_query_ready(row: Dictionary,error: String)->void:
	var endpoint:=direct_inspect_endpoint.duplicate(true);var tab:=direct_inspect_tab
	direct_inspect_endpoint.clear();direct_inspect_tab="";direct_browser_inspect_view_id=-1
	if direct_browser_work=="inspect":direct_browser_busy=false;direct_browser_work=""
	if endpoint.is_empty() or tab!=direct_browser_tab or not is_instance_valid(server_browser) or not server_browser.wanted:return
	if error.is_empty():
		var combined: Dictionary=endpoint.duplicate(true)
		var source: Array[Dictionary]=direct_directory_rows if tab=="Internet" else direct_browser_store.rows(tab)
		for candidate in source:
			if str(candidate.host)==str(endpoint.host) and int(candidate.port)==int(endpoint.port):combined.merge(candidate,true);break
		combined.merge(row,true);combined.host=endpoint.host;combined.port=endpoint.port
		var normalized: Dictionary=direct_browser_store.normalized_row(combined)
		if normalized.is_empty():error="Invalid server information"
		else:
			var key:=str(endpoint.host)+":"+str(endpoint.port)
			direct_observed_rows[key]=normalized
			direct_inspect_result=normalized
	direct_browser_view("Server information received" if error.is_empty() else error+" · You can still try Connect.")

func direct_profile_changed(status: Dictionary)->void:
	var active_name: String=direct_login_profiles.active_player_name()
	ticket.directProfile={"name":active_name,"hasSavedCdKey":bool(status.get("hasSavedCdKey",false))}
	if ticket.get("preworkSources") is Dictionary:
		ticket.preworkSources.modsDirectory=str(status.get("modsDirectory",""))
		ticket.preworkSources.disabledMods=status.get("disabledMods",[]).duplicate()
	if is_instance_valid(server_browser) and server_browser.wanted:direct_browser_view("Active login profile updated.")

func direct_directory_ready(rows: Array[Dictionary],error: String)->void:
	if direct_browser_work=="directory":direct_browser_busy=false;direct_browser_work=""
	if error.is_empty():
		var accepted: Array[Dictionary]=[];var seen: Dictionary={}
		for source_row in rows:
			var row: Dictionary=direct_browser_store.normalized_row(source_row)
			if row.is_empty():continue
			var key:=str(row.host)+":"+str(row.port)
			if seen.has(key):continue
			seen[key]=true;row.entryId=accepted.size();row.allowed=true;accepted.append(row)
		direct_directory_rows=accepted;direct_directory_loaded=true
	if is_instance_valid(server_browser) and server_browser.wanted and direct_browser_tab=="Internet":direct_browser_view(error if not error.is_empty() else str(direct_directory_rows.size())+" Internet servers found")

func direct_refresh_directory()->void:
	if direct_browser_tab!="Internet":direct_browser_view("Select Internet to refresh the server list");return
	if direct_browser_local_only:direct_browser_view("Internet discovery is not enabled for this session");return
	if Time.get_ticks_msec()<direct_browser_refresh_ready_at:direct_browser_view("Wait two seconds between server refreshes");return
	if direct_directory==null or direct_browser_busy:direct_browser_view("Wait for the current connection operation");return
	direct_browser_refresh_ready_at=Time.get_ticks_msec()+2000
	direct_browser_busy=true;direct_browser_work="directory"
	direct_browser_view("Reading Internet server list…")
	direct_directory.refresh()

func direct_begin_browser_inspect(row: Dictionary,request_view_id: int)->void:
	var endpoint: Dictionary=direct_browser_store.normalized_endpoint(row)
	if endpoint.is_empty():direct_browser_view(direct_browser_store.endpoint_error(row));return
	var denial:=direct_browser_endpoint_error(endpoint)
	if not denial.is_empty():direct_browser_view(denial);return
	if direct_server_query!=null:direct_server_query.close()
	direct_inspect_endpoint=endpoint;direct_inspect_tab=direct_browser_tab;direct_browser_inspect_view_id=request_view_id
	direct_browser_busy=true;direct_browser_work="inspect"
	direct_browser_selected=int(row.get("entryId",direct_browser_selected))
	if direct_browser_tab!="Direct":direct_browser_selected_key=direct_browser_key(row)
	direct_inspect_result=row.duplicate(true)
	direct_browser_view("Contacting server…")
	if not direct_server_query.query(str(endpoint.host),int(endpoint.port),3500,true) and not direct_inspect_endpoint.is_empty():
		direct_inspect_endpoint.clear();direct_inspect_tab="";direct_browser_inspect_view_id=-1;direct_browser_busy=false;direct_browser_work=""
		direct_browser_view("Server information request failed")

func direct_reset_browser_presentation()->void:
	if direct_server_query!=null:direct_server_query.close()
	if direct_directory!=null and direct_browser_work=="directory":direct_directory.close()
	direct_inspect_endpoint.clear();direct_inspect_result.clear();direct_inspect_tab="";direct_browser_inspect_view_id=-1
	direct_browser_busy=false;direct_browser_work="";direct_browser_first_view_id=-1
	direct_observed_rows.clear();direct_browser_tab="Direct";direct_browser_page=0;direct_browser_selected=-1;direct_browser_selected_key=""
	direct_browser_filter="";direct_browser_sort="Players";direct_browser_filters={"local":true,"server":true,"password":true}
	direct_browser_source_page=false;direct_browser_game_type=null
	direct_browser_source_sorts={"Internet":direct_source_sort("Internet"),"History":direct_source_sort("History"),"Favorites":direct_source_sort("Favorites")}
	direct_browser_advanced=direct_browser_store.state.get("browserFilters",{"hideEmpty":false,"hideFull":false,"module":""}).duplicate(true)

func direct_browser_return_menu(connection: int)->void:
	var joining:=direct_started_from_browser and bool(direct_lobby_state.get("canCancelJoin",false))
	direct_reset_browser_presentation()
	if joining:
		await direct_disconnect(false)
		if closing or direct_session!=null or session_connection<=connection:return
		server_browser.open(true,true)
		return
	if closing or connection!=session_connection or not is_instance_valid(server_browser) or not server_browser.wanted:return
	direct_browser_view()

func browser_request(message: Dictionary)->void:
	if not direct_mode:super.browser_request(message);return
	if closing or not is_instance_valid(server_browser):return
	if int(message.get("connection",-1))!=session_connection:return
	var operation:=str(message.get("operation",""))
	var view_id:=int(message.get("viewId",-1))
	if operation in ["return-menu","cancel-inspect"]:
		var minimum:=direct_browser_first_view_id if operation=="return-menu" else direct_browser_inspect_view_id
		if minimum<0 or view_id<minimum or view_id>direct_browser_view_id:return
	elif operation not in ["open","close"] and view_id!=server_browser.view_id:return
	if direct_browser_busy and operation not in ["open","close","return-menu","cancel-inspect"]:
		direct_browser_view("Wait for the current connection operation");return
	match operation:
		"open":
			if direct_browser_busy or direct_session!=null:direct_browser_view("Wait for the current connection operation");return
			direct_reset_browser_presentation()
			var requested:=str(message.get("listTab",""))
			direct_browser_tab=requested if requested in ["Internet","History","Favorites"] else "Direct"
			direct_browser_source_page=requested in ["Internet","History","Favorites"]
			direct_browser_view()
			if direct_browser_tab=="Internet" and not direct_directory_loaded and not direct_browser_local_only and Time.get_ticks_msec()>=direct_browser_refresh_ready_at:direct_refresh_directory()
		"close":
			if bool(message.get("leaveMultiplayer",false)) and str(direct_browser_store.state.get("profileDefault","")).is_empty():direct_browser_session_name=""
			direct_reset_browser_presentation()
		"return-menu":direct_browser_return_menu(session_connection)
		"cancel-inspect":
			if direct_browser_work=="inspect":
				direct_server_query.close();direct_inspect_endpoint.clear();direct_inspect_tab="";direct_browser_inspect_view_id=-1
				direct_browser_busy=false;direct_browser_work="";direct_browser_view()
			elif not direct_browser_busy:direct_browser_view()
		"tab":
			if direct_server_query!=null:direct_server_query.close()
			direct_inspect_endpoint.clear();direct_inspect_result.clear();direct_inspect_tab="";direct_browser_inspect_view_id=-1;direct_browser_busy=false;direct_browser_work=""
			var selected_tab:=str(message.get("tab",""))
			if selected_tab not in ["Direct","Internet","History","Favorites"]:return
			direct_browser_tab=selected_tab;direct_browser_page=0;direct_browser_selected=-1;direct_browser_selected_key=""
			if message.get("sourcePage") is bool:direct_browser_source_page=message.sourcePage
			direct_browser_view()
			if selected_tab=="Internet" and not direct_directory_loaded and not direct_browser_local_only and Time.get_ticks_msec()>=direct_browser_refresh_ready_at:direct_refresh_directory()
		"sort-column":
			var column: Variant=message.get("column")
			if not direct_browser_source_page or direct_browser_tab=="History" or not direct_browser_source_sorts.has(direct_browser_tab) or not column is int or int(column)<0 or int(column)>5:direct_browser_view("Invalid original browser sort");return
			var sort_state: Dictionary=direct_browser_source_sorts[direct_browser_tab].duplicate(true)
			sort_state.header=column
			if sort_state.order[0]==column:sort_state.ascending[column]=not sort_state.ascending[column]
			else:
				var priority: Array=[column]
				for value in sort_state.order:
					if value!=column:priority.append(value)
				sort_state.order=priority
			direct_browser_source_sorts[direct_browser_tab]=sort_state
			direct_browser_view()
		"game-type":
			var game_type: Variant=message.get("gameType")
			if direct_browser_tab!="Internet" or game_type!=null and (not game_type is int or int(game_type)<0 or int(game_type)>32767):direct_browser_view("Invalid server game type");return
			direct_browser_game_type=game_type;direct_browser_page=0;direct_browser_selected=-1;direct_browser_selected_key="";direct_inspect_result.clear();direct_browser_view()
		"advanced-filter":
			if not direct_browser_store.filters(message.get("values")):direct_browser_view(direct_browser_store.error);return
			direct_browser_advanced=direct_browser_store.state.browserFilters.duplicate(true)
			direct_browser_page=0;direct_browser_selected=-1;direct_browser_selected_key="";direct_browser_view()
		"refresh":
			if direct_browser_tab=="Internet":direct_refresh_directory()
		"filter":
			direct_browser_filter=str(message.get("filter","")).left(128)
			direct_browser_sort=str(message.get("sort","Players"))
			if direct_browser_sort not in ["Name","Module","Players","Latency"]:direct_browser_sort="Players"
			if message.get("filters") is Dictionary:
				var filters: Dictionary=message.filters
				if filters.get("local") is bool and filters.get("server") is bool and filters.get("password") is bool:direct_browser_filters={"local":filters.local,"server":filters.server,"password":filters.password}
			direct_browser_page=0;direct_browser_selected=-1;direct_browser_selected_key="";direct_browser_view()
		"page":direct_browser_page=maxi(0,int(message.get("page",0)));direct_browser_view()
		"select":
			var entry_id:=int(message.get("entryId",-1))
			var selected_row: Dictionary={}
			for row in direct_visible_rows():
				if int(row.entryId)==entry_id:selected_row=row;break
			if selected_row.is_empty():direct_browser_view("That server selection is no longer available.");return
			direct_browser_selected=entry_id
			direct_browser_selected_key=direct_browser_key(selected_row)
			direct_browser_view("",{"requestViewId":int(message.viewId),"host":selected_row.host,"port":selected_row.port})
		"selection-step":
			var direction: Variant=message.get("direction")
			if not direct_browser_source_page or direct_browser_tab not in ["Internet","History","Favorites"] or not direction is int or int(direction) not in [-1,1]:direct_browser_view("Invalid server selection direction");return
			var visible_rows:=direct_visible_rows();var selected_index:=-1
			for index in visible_rows.size():
				if int(visible_rows[index].entryId)==direct_browser_selected:selected_index=index;break
			var next_index:=selected_index+int(direction)
			if next_index>=0 and next_index<visible_rows.size():
				var next_row: Dictionary=visible_rows[next_index]
				direct_browser_selected=int(next_row.entryId)
				direct_browser_selected_key=direct_browser_key(next_row)
				direct_browser_page=floori(float(next_index)/128.0)
				direct_browser_view("",{"requestViewId":int(message.viewId),"host":next_row.host,"port":next_row.port})
			else:direct_browser_view()
		"profile":
			var values: Dictionary=message.get("values",{})
			var name:=str(values.get("name",""))
			var accepted: bool=direct_browser_store.valid_profile_name(name)
			if accepted and bool(values.get("saveDefault",false)):accepted=direct_browser_store.profile(name)
			if accepted:
				direct_browser_session_name=name
				receive({"kind":"browser-profile-result","connection":session_connection,"requestViewId":int(message.viewId),"accepted":true,"name":name,"savedDefault":bool(values.get("saveDefault",false))})
			else:receive({"kind":"browser-profile-result","connection":session_connection,"requestViewId":int(message.viewId),"accepted":false,"text":direct_browser_store.error})
			direct_browser_view("" if accepted else direct_browser_store.error)
		"favorite":
			var row: Dictionary={}
			if bool(message.get("direct",false)):
				row=message.get("values",{})
			else:
				for candidate in direct_visible_rows():
					if int(candidate.entryId)==int(message.get("entryId",-1)):row=candidate;break
			if row.is_empty():direct_browser_view("Select a server to change its favorite status.");return
			var currently_favorite:=false
			for favorite in direct_browser_store.state.favorites:
				if str(favorite.host).to_lower()==str(row.get("host","")).to_lower() and int(favorite.port)==int(row.get("port",0)):currently_favorite=true;break
			var on:=bool(message.get("on",not currently_favorite))
			if not direct_browser_store.favorite(row,on):direct_browser_view(direct_browser_store.error);return
			direct_browser_view()
		"inspect":
			var endpoint: Dictionary={}
			if bool(message.get("direct",false)):endpoint=message.get("values",{})
			else:
				for row in direct_visible_rows():
					if int(row.entryId)==int(message.get("entryId",-1)):endpoint=row;break
			if endpoint.is_empty():direct_browser_view("Select a server to inspect.");return
			direct_begin_browser_inspect(endpoint,view_id)
		"details-step":
			var direction: Variant=message.get("direction")
			if not direction is int or int(direction) not in [-1,1]:direct_browser_view("Invalid server details direction");return
			var visible_rows:=direct_visible_rows();var selected_index:=-1
			for index in visible_rows.size():
				if int(visible_rows[index].entryId)==direct_browser_selected:selected_index=index;break
			var next_index:=selected_index+int(direction)
			if selected_index<0 or next_index<0 or next_index>=visible_rows.size():direct_browser_view("No adjacent server");return
			var next_row: Dictionary=visible_rows[next_index]
			direct_browser_selected=int(next_row.entryId);direct_browser_selected_key=direct_browser_key(next_row);direct_browser_page=floori(float(next_index)/128.0)
			var denial:=direct_browser_endpoint_error(next_row)
			if not denial.is_empty():direct_inspect_result=next_row.duplicate(true);direct_browser_view(denial);return
			direct_begin_browser_inspect(next_row,view_id)
		"join":
			if direct_session!=null or bool(direct_lobby_state.get("canCancelJoin",false)):
				direct_browser_view("Disconnect the current game before joining another server");return
			var values: Dictionary=message.get("values",{})
			var address:=str(values.get("host",""))
			var port:=int(values.get("port",0))
			var join_row: Dictionary={"host":address,"port":port}
			if not bool(message.get("direct",true)):
				var listed: Dictionary={}
				var source: Array[Dictionary]=direct_directory_rows if direct_browser_tab=="Internet" else direct_browser_store.rows(direct_browser_tab)
				for row in source:
					if int(row.entryId)==direct_browser_selected and int(row.entryId)==int(message.get("entryId",-1)):listed=row;break
				if listed.is_empty():direct_browser_view("Select an available server before connecting.");return
				address=str(listed.host);port=int(listed.port)
				join_row=listed.duplicate(true)
			var profile: Dictionary=ticket.get("directProfile",{})
			var endpoint_reason:=direct_browser_endpoint_error({"host":address,"port":port})
			if not endpoint_reason.is_empty():direct_browser_view(endpoint_reason);return
			var submitted_name:=str(values.get("name","")).strip_edges()
			if not str(profile.get("name","")).is_empty() and str(profile.name)!=submitted_name:direct_browser_view("Select the active login profile and its matching player name before connecting.");return
			if submitted_name.is_empty() or submitted_name.length()>32:direct_browser_view("Enter a player name of up to 32 characters.");return
			if not bool(profile.get("hasSavedCdKey",false)) and str(values.get("cdKey","")).is_empty():direct_browser_view("Enter a temporary CD key or save one in the active login profile.");return
			var temporary_key:=str(values.get("cdKey",""))
			values.cdKey=""
			direct_browser_join_row=join_row
			direct_browser_join_name=submitted_name
			direct_started_from_browser=true
			character_lobby.show_sync_wait()
			direct_connect(address,port,str(values.get("password","")),temporary_key,submitted_name,{},values.get("serverPublicKey",join_row.get("serverPublicKey")))
			values.password=""
			temporary_key=""
		_:
			direct_browser_view("That server-list action has not yet been migrated to the Godot direct entry.")

func _profile_tick()->void:
	super._profile_tick()
	direct_camera_bind()
	if closing or direct_check_deadline<=0:return
	var vault_mode:=str(args.get("direct-headless-vault-policy-check",""))
	if vault_mode in ["server-only","local-allowed","server-only-play"] and direct_session!=null and direct_session.phase=="character-selection" and str(direct_lobby_state.get("phase",""))=="character-selection":
		var expected_local:=vault_mode=="local-allowed"
		if expected_local and not character_lobby.local_catalog.ready():return
		var local_keys: Array=[]
		var server_count:=0
		for key in direct_lobby_choices:
			if str(direct_lobby_choices[key].get("source",""))!="server":local_keys.append(key)
			else:server_count+=1
		var ui_local_keys: Array=[]
		for key in character_lobby.keys:
			if str(key).begins_with("installed:") or str(key).begins_with("local:") or str(key).begins_with("vault:") or str(key).begins_with("godot-vault:"):ui_local_keys.append(key)
		report.direct_vault_policy_check={"policyKnown":direct_session.local_vault_policy_known,"localAllowed":direct_session.local_vault_allowed,"phase":direct_lobby_state.phase,"connected":bool(direct_lobby_state.get("connected",false)),"localChoices":local_keys.size(),"uiLocalChoices":ui_local_keys.size(),"savedRows":direct_lobby_state.get("savedCharacters",[]).size(),"serverChoices":server_count,"serverPreviewRequested":direct_vault_server_play_stage>=1,"serverPreviewReady":direct_vault_server_play_stage>=2,"serverPlaySent":direct_vault_server_play_stage>=3,"worldAdmitted":false}
		if not bool(report.direct_vault_policy_check.policyKnown) or bool(report.direct_vault_policy_check.localAllowed)!=expected_local or not bool(report.direct_vault_policy_check.connected) or (expected_local and (local_keys.is_empty() or ui_local_keys.is_empty())) or (not expected_local and (not local_keys.is_empty() or not ui_local_keys.is_empty() or int(report.direct_vault_policy_check.savedRows)!=0)):fail("Server character-vault policy disagreed with the chooser");return
		if vault_mode=="server-only-play":
			if server_count!=1:fail("Private server-vault fixture did not present one server character");return
			if direct_vault_server_play_stage==0:
				for key in direct_lobby_choices:
					if str(direct_lobby_choices[key].get("source",""))=="server":direct_vault_server_key=str(key);break
				if direct_vault_server_key.is_empty():fail("Private server-vault choice was unavailable");return
				lobby_request({"kind":"lobby-choose","connection":session_connection,"key":direct_vault_server_key,"requestId":1})
				if direct_session.pending_preview.is_empty():fail("Private server-vault preview request was not sent");return
				direct_vault_server_play_stage=1
			elif direct_vault_server_play_stage==1 and direct_lobby_state.get("preview") is Dictionary:
				if direct_lobby_state.preview.has("error"):fail("Private server-vault preview was invalid");return
				direct_vault_server_play_stage=2
				lobby_request({"kind":"lobby-play","key":direct_vault_server_key})
				if direct_session.phase!="character-loading":fail("Private server-vault Play was not sent");return
				direct_vault_server_play_stage=3
			return
		direct_check_deadline=0
		shutdown()
		return
	if args.get("direct-headless-manual-check","")=="true" and is_instance_valid(character_lobby):
		var chooser=character_lobby.native_chooser
		report.direct_manual_state={"session_phase":direct_session.phase if direct_session!=null else "none","lobby_phase":direct_lobby_state.get("phase"),"selected":direct_lobby_state.get("selected"),"preview_ready":direct_lobby_state.get("preview") is Dictionary,"preview_error":str(direct_lobby_state.get("preview",{}).get("error","")) if direct_lobby_state.get("preview") is Dictionary else "","selection_pending":character_lobby.native_selection.duplicate(true),"panel_visible":character_lobby.panel.visible,"key_present":character_lobby.keys.has("installed:fighter.bic"),"row_visible":is_instance_valid(chooser) and chooser.row_keys.has("installed:fighter.bic"),"show_pregenerated":chooser.show_pregenerated if is_instance_valid(chooser) else false,"choice_request_id":direct_choice_request_id,"chosen":direct_manual_test_chosen,"played":direct_manual_test_played}
	if Time.get_ticks_msec()>direct_check_deadline:fail("Godot direct renderer/UI check timed out at "+str(direct_session.phase if direct_session!=null else "not-started")+" snapshots="+str(received));return
	if args.get("direct-headless-manual-check","")=="true" and not direct_lobby_state.is_empty() and direct_session.phase=="character-selection":
		if is_instance_valid(character_lobby.native_chooser) and character_lobby.can_select():
			if not character_lobby.native_chooser.show_pregenerated:
				character_lobby.native_chooser.show_pregenerated=true
				character_lobby.native_chooser.row_signature=""
				character_lobby.native_chooser.sync()
			report.direct_manual_progress={"choices":direct_lobby_choices.size(),"ui_choices":character_lobby.keys.size(),"fighter_visible":character_lobby.native_chooser.row_keys.has("installed:fighter.bic"),"metadata_ready":character_lobby.local_catalog.ready(),"can_select":character_lobby.can_select(),"native_base_only":character_lobby.native_base_only,"native_chooser":true,"chosen":direct_manual_test_chosen,"played":direct_manual_test_played}
			if not direct_manual_test_chosen and bool(report.direct_manual_progress.fighter_visible) and character_lobby.panel.visible:
				character_lobby.choose_native("installed:fighter.bic")
				direct_manual_test_chosen=direct_lobby_state.get("selected")=="installed:fighter.bic"
			elif direct_manual_test_chosen and not direct_manual_test_played and direct_lobby_state.get("preview") is Dictionary and character_lobby.native_selection.is_empty() and bool(report.direct_manual_progress.fighter_visible):
				character_lobby._play()
				direct_manual_test_played=direct_session.phase=="character-loading"
	if direct_session==null or direct_session.phase!="playing" or not direct_quickbar_received or not is_instance_valid(world) or not world.ready_for_control() or received<2:return
	var controlled: int=int(direct_session.world_state.local_object_id)
	var actor: Dictionary=direct_session.world_state.registry.get(controlled,{})
	if controlled==0x7f000000 or world.controlled_id!=controlled or int(actor.get("objectType",0))!=5 or int(actor.get("areaId",-1))!=world.area_id or not world.desired.has(controlled):
		report.direct_control_wait={"generation":direct_generation,"session_phase":direct_session.phase,"session_controlled":controlled,"world_controlled":world.controlled_id,"actor_type":int(actor.get("objectType",0)),"actor_area":int(actor.get("areaId",-1)),"world_area":world.area_id,"desired":world.desired.has(controlled),"snapshots":received}
		return
	report.erase("direct_control_wait")
	if args.get("direct-headless-local-smoke-check","")=="true" and direct_local_smoke_stage<3:
		if not direct_local_smoke_tick(controlled,actor):return
	if args.get("direct-headless-character-export-check","")=="true" and direct_character_export_stage<2:
		if direct_character_export_stage==0:
			direct_character_export_stage=1
			lobby_request({"kind":"lobby-export"})
			if direct_session==null or not direct_session.pending_character_export:fail("Godot character export request was not accepted");return
		return
	if args.get("direct-headless-levelup-check","")=="true":
		var total_level:=0
		for cls in actor.get("replicated",{}).get("stats",{}).get("classes",[]):total_level+=int(cls.get("level",0))
		if not direct_levelup_probe_started:
			if not bool(actor.get("playerState",{}).get("combat",{}).get("canLevelUp",false)):
				report.direct_levelup_wait={"level":total_level,"canLevelUp":false,"playerState":actor.has("playerState")}
				return
			direct_levelup_origin_level=total_level
			var probe_source:=load("res://tests/native_live_level_up_source_probe.gd") as Script
			if probe_source==null:fail("Private level-up source probe is unavailable");return
			var probe=probe_source.new();host.add_child(probe)
			direct_levelup_probe_started=true
			probe.run(self)
			return
		if not direct_levelup_probe_finished.is_empty() and not bool(direct_levelup_probe_finished.get("success",false)) and not direct_levelup_events.any(func(event):return event.operation=="submit" and event.serverAccepted):
			fail("Private level-up source controls failed before a server result: "+str(direct_levelup_probe_finished.get("failures",[])));return
		if total_level<=direct_levelup_origin_level or not direct_levelup_events.any(func(event):return event.operation=="begin" and event.accepted) or not direct_levelup_events.any(func(event):return event.operation=="submit" and event.serverAccepted):return
		report.direct_levelup_check={"originLevel":direct_levelup_origin_level,"finalLevel":total_level,"events":direct_levelup_events.duplicate(true),"outbound":direct_levelup_outbound.duplicate(true),"serverBitmap":true,"serverResult":true,"authoritativeUpdate":true,"sourceControls":true}
	if args.get("direct-headless-inventory-check","")=="true" and direct_inventory_stage<3:
		if direct_inventory_stage==0:
			report.direct_inventory_commands=[]
			direct_window_receipts_before=int(direct_session.world_state.inventory_receipt_serial)
			gameplay_ui.request.emit({"kind":"inventory-open","page":0,"requestId":101,"ownerId":controlled})
			direct_inventory_deadline=Time.get_ticks_msec()+5000
			direct_inventory_stage=1
			return
		if direct_inventory_stage==1:
			if (direct_session.world_state.inventories.is_empty() or int(direct_session.world_state.inventory_receipt_serial)<=direct_window_receipts_before) and Time.get_ticks_msec()<direct_inventory_deadline:return
			if args.get("direct-headless-item-action-check","")=="true":
				var entries: Array=direct_session.world_state.inventories.get("R",{}).get("entries",[])
				if entries.is_empty():fail("Private server did not provide a repository item for action check");return
				var row: Dictionary=entries[0]
				direct_item_id=int(row.id)
				gameplay_ui.request.emit({"kind":"item-action","itemId":direct_item_id,"operation":"move","x":int(row.get("x",255)),"y":int(row.get("y",255)),"requestId":104})
				direct_inventory_deadline=Time.get_ticks_msec()+5000
				direct_inventory_stage=2
				return
		if direct_inventory_stage==2:
			if not report.has("direct_item_response") and Time.get_ticks_msec()<direct_inventory_deadline:return
			if not report.has("direct_item_response") or not bool(report.direct_item_response.get("success",false)):fail("Private server did not accept the Godot item move");return
		gameplay_ui.request.emit({"kind":"inventory-page","page":1,"requestId":102,"ownerId":controlled})
		gameplay_ui.request.emit({"kind":"inventory-close","requestId":103,"ownerId":controlled})
		direct_inventory_stage=3
		report.direct_inventory_check={"requests":report.direct_inventory_commands.duplicate(true),"received_inventory_channels":direct_session.world_state.inventories.size(),"server_13_1_observed":int(direct_session.world_state.inventory_receipt_serial)>direct_window_receipts_before,"window_receipt_before":direct_window_receipts_before,"window_receipt_after":int(direct_session.world_state.inventory_receipt_serial)}
		var expected_count:=4 if args.get("direct-headless-item-action-check","")=="true" else 3
		if report.direct_inventory_commands.size()!=expected_count or report.direct_inventory_commands.any(func(row):return not row.accepted) or direct_session.world_state.inventories.is_empty():fail("Godot inventory roundtrip did not reach received inventory state");return
	if args.get("direct-headless-chat-dialog-check","")=="true" and direct_dialog_stage<4:
		if direct_dialog_stage==0:
			gameplay_ui.request.emit({"kind":"chat","actorId":controlled,"channel":1,"text":"Godot original server check"})
			direct_dialog_deadline=Time.get_ticks_msec()+8000
			direct_dialog_stage=1
			return
		if direct_dialog_stage==1:
			if not direct_speech_echo and Time.get_ticks_msec()<direct_dialog_deadline:return
			if not direct_speech_echo:fail("Private server did not echo the Godot chat request");return
			var npc_id:=-1
			for id in direct_session.world_state.registry:
				var candidate: Dictionary=direct_session.world_state.registry[id]
				if int(id)!=controlled and int(candidate.get("objectType",0))==5 and int(candidate.get("areaId",0))==world.area_id and not bool(candidate.get("replicationRemoved",false)):npc_id=int(id);break
			if npc_id<0:fail("Private server did not provide a conversation creature");return
			var outcome: Dictionary=await direct_session.target_action(npc_id,"conversation.start")
			if outcome.has("error"):fail("Godot conversation request failed: "+str(outcome.error));return
			direct_dialog_deadline=Time.get_ticks_msec()+12000
			direct_dialog_stage=2
			return
		if direct_dialog_stage==2:
			var choices: Dictionary=direct_session.current_dialog.get("replies",{})
			if choices.is_empty() and Time.get_ticks_msec()<direct_dialog_deadline:return
			if choices.is_empty():fail("Private server did not offer conversation replies");return
			var replies: Array=choices.get("replies",[])
			var reply_id:=int(replies[0].id) if not replies.is_empty() else 0xffffffff
			gameplay_ui.request.emit({"kind":"reply","entryId":int(choices.entryId),"replyId":reply_id,"abort":false})
			direct_dialog_deadline=Time.get_ticks_msec()+8000
			direct_dialog_stage=3
			return
		if direct_dialog_stage==3:
			if direct_dialog_events.size()<3 and Time.get_ticks_msec()<direct_dialog_deadline:return
			if direct_dialog_events.size()<3:fail("Private server did not advance after the Godot dialog reply");return
			report.direct_chat_dialog_check={"speech_echo":direct_speech_echo,"events":direct_dialog_events.duplicate(),"reply_advanced":true}
			direct_dialog_stage=4
	if args.get("direct-headless-travel-check","")=="true" and direct_travel_stage<4:
		if direct_travel_stage==0:
			direct_travel_origin=world.area_id
			gameplay_ui.request.emit({"kind":"chat","actorId":controlled,"channel":1,"text":"-native-b"})
			direct_travel_deadline=Time.get_ticks_msec()+30000
			direct_travel_stage=1
			return
		if direct_travel_stage==1:
			if (world.area_id==direct_travel_origin or direct_generation<2) and Time.get_ticks_msec()<direct_travel_deadline:return
			if world.area_id==direct_travel_origin or direct_generation<2:fail("Private server did not admit the destination area");return
			report.direct_travel_check={"first_area":direct_travel_origin,"second_area":world.area_id,"second_generation":direct_generation}
			gameplay_ui.request.emit({"kind":"chat","actorId":controlled,"channel":1,"text":"-native-a"})
			direct_travel_deadline=Time.get_ticks_msec()+30000
			direct_travel_stage=2
			return
		if direct_travel_stage==2:
			if (world.area_id!=direct_travel_origin or direct_generation<3) and Time.get_ticks_msec()<direct_travel_deadline:return
			if world.area_id!=direct_travel_origin or direct_generation<3:fail("Private server did not re-admit the original area");return
			report.direct_travel_check.returned=true
			report.direct_travel_check.third_generation=direct_generation
			direct_travel_stage=4
	if args.get("direct-headless-portal-check","")=="true" and direct_portal_stage<2:
		if direct_portal_stage==0:
			direct_portal_origin_area=world.area_id
			direct_portal_origin_connection=session_connection
			gameplay_ui.request.emit({"kind":"chat","actorId":controlled,"channel":1,"text":"-native-portal"})
			direct_portal_stage=1
			return
		if int(report.get("direct_portal_transfers",0))<1 or direct_server_port!=5122 or session_connection<=direct_portal_origin_connection or world.area_id==direct_portal_origin_area:return
		report.direct_portal_check.destination_area=world.area_id
		report.direct_portal_check.destination_connection=session_connection
		report.direct_portal_check.world_admitted=true
		direct_portal_stage=2
	if not direct_nwsync_visual_descriptor.is_empty() and direct_nwsync_visual_stage<2:
		if direct_nwsync_visual_stage==0 and not direct_nwsync_visual_validate():return
		if direct_nwsync_visual_stage<2:return
	if args.get("direct-nwsync-world-material-check","")=="true" and direct_nwsync_world_stage<2:
		if direct_nwsync_world_stage==0 and not direct_nwsync_world_validate():return
		if direct_nwsync_world_stage<2:return
	report.direct_headless_check={"area":world.area_id,"controlled":world.controlled_id,"snapshots":received,"objects":world.desired.size(),"quickbar":direct_session.world_state.quickbar.size(),"catalog_shared":is_same(catalog,direct_session.catalog),"ui_generation":gameplay_ui.generation if is_instance_valid(gameplay_ui) else -1}
	if args.get("direct-headless-manual-check","")=="true":
		report.direct_headless_check.manual_selected=direct_manual_test_chosen
		report.direct_headless_check.manual_played=direct_manual_test_played
		if not direct_manual_test_chosen or not direct_manual_test_played:fail("Godot chooser did not submit a selected local character");return
	if not bool(report.direct_headless_check.catalog_shared) or int(report.direct_headless_check.ui_generation)!=epoch:fail("Godot direct world and UI did not share the admitted session");return
	if vault_mode=="server-only-play":
		if direct_vault_server_play_stage!=3:fail("Private server-vault Play did not complete");return
		report.direct_vault_policy_check.serverPreviewRequested=true
		report.direct_vault_policy_check.serverPreviewReady=true
		report.direct_vault_policy_check.serverPlaySent=true
		report.direct_vault_policy_check.worldAdmitted=true
	if args.get("direct-server-vault-create-check","")=="true":
		var creation: Dictionary=report.get("direct_server_vault_create_check",{})
		var proof: Dictionary=report.get("creationProof",{})
		var expected: Dictionary=proof.get("expected",{}) if proof.get("expected",{}) is Dictionary else {}
		if not bool(proof.get("success",false)) or not bool(creation.get("creatorOpened",false)) or not bool(creation.get("creatorSubmitted",false)) or not bool(creation.get("source19Sent",false)) or str(expected.get("firstName","")).is_empty() or str(creation.get("characterFingerprint","")).is_empty():fail("Private source character creation did not complete before world admission");return
		report.direct_server_vault_create_check.worldAdmitted=true
		await direct_disconnect()
		report.direct_server_vault_create_check.disconnectClean=direct_session==null and str(character_lobby.state.get("phase",""))=="menu"
		if not report.direct_server_vault_create_check.disconnectClean:fail("Private created-character disconnect did not return to menu");return
		shutdown.call_deferred()
		return
	if args.get("direct-server-vault-reconnect-check","")=="true":
		var reconnect: Dictionary=report.get("direct_server_vault_reconnect_check",{})
		var proof: Dictionary=report.get("creationProof",{})
		if not bool(proof.get("success",false)) or not bool(reconnect.get("rosterAccepted",false)) or not bool(reconnect.get("serverRowMatched",false)) or not bool(reconnect.get("previewRequested",false)) or not bool(reconnect.get("previewReady",false)) or not bool(reconnect.get("playSent",false)) or str(reconnect.get("characterFingerprint","")).is_empty():fail("Private persisted server character was not selected and played through native controls");return
		report.direct_server_vault_reconnect_check.worldAdmitted=true
		await direct_disconnect()
		report.direct_server_vault_reconnect_check.disconnectClean=direct_session==null and str(character_lobby.state.get("phase",""))=="menu"
		if not report.direct_server_vault_reconnect_check.disconnectClean:fail("Private persisted-character disconnect did not return to menu");return
		shutdown.call_deferred()
		return
	direct_check_deadline=0
	if args.get("direct-headless-reconnect-check","")=="true" and direct_reconnect_stage==0:
		report.direct_reconnect={"first_world":report.direct_headless_check.duplicate(true)}
		direct_reconnect_stage=1
		await direct_disconnect()
		direct_reconnect_test_start.call_deferred()
		return
	if args.get("direct-headless-reconnect-check","")=="true":
		report.direct_reconnect.second_world=report.direct_headless_check.duplicate(true)
	print("NWN79 Godot direct playable world PASS: ",JSON.stringify(report.direct_headless_check))
	shutdown.call_deferred()

func direct_local_smoke_tick(controlled: int,actor: Dictionary)->bool:
	if direct_local_smoke_stage==2:return false
	var position: Variant=actor.get("replicated",{}).get("position",[])
	if not position is Array or position.size()!=3 or not world.instances.has(controlled):return false
	var instance=world.instances[controlled]
	if not is_instance_valid(instance) or not is_instance_valid(instance.rigs):return false
	var pose_frames:=int(instance.rigs.stats.get("pose_frames",0))
	if direct_local_smoke_stage==0:
		direct_local_smoke_origin=position.duplicate()
		direct_local_smoke_area=world.area_id
		direct_local_smoke_generation=direct_generation
		direct_local_smoke_origin_serial=direct_local_smoke_update_serial
		direct_local_smoke_pose_frames=pose_frames
		direct_local_smoke_sample=instance.rigs.diagnostic_sample([controlled])
		direct_local_smoke_animation_witness={}
		direct_local_smoke_animation_frame=-1
		direct_local_smoke_animation_server_updates=-1
		var target: Array=[float(position[0])+1.5,float(position[1]),float(position[2])]
		gameplay_ui.request.emit({"kind":"walk","position":target,"run":true})
		if not bool(direct_local_smoke_request.get("requestAccepted",false)):
			fail("Godot local smoke waypoint was not accepted: "+str(direct_local_smoke_request.get("error","unknown")));return false
		gameplay_ui.request.emit({"kind":"chat","actorId":controlled,"channel":1,"text":"Godot direct local smoke"})
		direct_local_smoke_stage=1
		return false
	var origin:=Vector3(float(direct_local_smoke_origin[0]),float(direct_local_smoke_origin[1]),float(direct_local_smoke_origin[2]))
	var current:=Vector3(float(position[0]),float(position[1]),float(position[2]))
	var displacement:=origin.distance_to(current)
	var server_moved:=direct_local_smoke_update_serial>direct_local_smoke_origin_serial and displacement>0.25
	var frames:=pose_frames-direct_local_smoke_pose_frames
	var camera_valid: bool=native_camera_follow_target_id()==controlled and controller.follow_valid(instance.position)
	if direct_local_smoke_animation_witness.is_empty() and frames>=2 and world.area_id==direct_local_smoke_area and direct_generation==direct_local_smoke_generation:
		var animation: Dictionary=instance.rigs.compare_samples(direct_local_smoke_sample,instance.rigs.diagnostic_sample([controlled]))
		var active_walk:=false
		for clip in animation.get("active_clips",[]):
			if str(clip.get("model","")).begins_with(str(controlled)+":") and str(clip.get("clip","")) in ["walk","run"]:active_walk=true;break
		var changed_parts:=int(animation.get("changed_local_parts",0))>0
		var changed_skin:=float(animation.get("maximum_local_skin_vertex_delta",0.0))>0.0001
		var rigid_only: bool=int(instance.rigs.stats.get("skin_meshes",0))==0 and int(instance.rigs.stats.get("rigid_meshes",0))>0 and instance.rigs.stats.get("failures",[]).is_empty()
		var animation_valid: bool=changed_parts and (changed_skin or rigid_only and active_walk and int(animation.get("advanced_model_clocks",0))>0 and int(animation.get("skin_meshes_sampled",-1))==0)
		animation.activeWalkClip=active_walk
		animation.rigidOnly=rigid_only
		if animation_valid:
			direct_local_smoke_animation_witness=animation.duplicate(true)
			direct_local_smoke_animation_frame=frames
			direct_local_smoke_animation_server_updates=direct_local_smoke_update_serial-direct_local_smoke_origin_serial
	report.direct_local_smoke_progress={"origin":direct_local_smoke_origin.duplicate(),"current":position.duplicate(),"serverUpdates":direct_local_smoke_update_serial-direct_local_smoke_origin_serial,"serverDisplacement":displacement,"speechEcho":direct_local_smoke_speech_echo,"cameraFollowValid":camera_valid,"presentationFrames":frames,"animationWitness":direct_local_smoke_animation_witness.duplicate(true),"animationSampleFrame":direct_local_smoke_animation_frame,"animationSampleServerUpdates":direct_local_smoke_animation_server_updates,"request":direct_local_smoke_request.duplicate(true)}
	if not server_moved or not direct_local_smoke_speech_echo or not camera_valid or frames<2 or direct_local_smoke_animation_witness.is_empty() or world.area_id!=direct_local_smoke_area or direct_generation!=direct_local_smoke_generation:return false
	report.direct_local_smoke_check={"requestKind":"walk","requestAccepted":bool(direct_local_smoke_request.get("requestAccepted",false)),"requestTransmitted":bool(direct_local_smoke_request.get("requestTransmitted",false)),"originArea":direct_local_smoke_area,"destinationArea":world.area_id,"originGeneration":direct_local_smoke_generation,"destinationGeneration":direct_generation,"serverDisplacement":displacement,"serverMovementObserved":server_moved,"speechEcho":direct_local_smoke_speech_echo,"cameraFollowValid":camera_valid,"presentationAnimationAdvanced":true,"animationWitness":direct_local_smoke_animation_witness.duplicate(true),"animationSampleFrame":direct_local_smoke_animation_frame,"animationSampleServerUpdates":direct_local_smoke_animation_server_updates,"presentationFrames":frames,"serverUpdates":direct_local_smoke_update_serial-direct_local_smoke_origin_serial}
	if args.get("direct-local-smoke-capture","")=="true":
		if DisplayServer.get_name()=="headless":fail("Graphical local smoke requested a headless display");return false
		direct_local_smoke_stage=2
		direct_local_smoke_capture.call_deferred()
		return false
	direct_local_smoke_stage=3
	return true

func direct_local_smoke_capture()->void:
	await process_frame
	await process_frame
	if closing or direct_local_smoke_stage!=2 or not is_instance_valid(world):return
	var capture_path:=str(args.get("report","")).trim_suffix(".json")+".png"
	if capture_path.is_empty() or root.get_texture().get_image().save_png(capture_path)!=OK:fail("Graphical local smoke world frame could not be captured");return
	report.direct_local_smoke_check.visualCapture=capture_path
	report.direct_local_smoke_check.visualArea=world.area_id
	report.direct_local_smoke_check.visualGeneration=direct_generation
	report.direct_local_smoke_check.visualControlled=world.controlled_id
	direct_local_smoke_stage=3

func direct_reconnect_test_start()->void:
	await process_frame
	if closing or direct_session!=null or is_instance_valid(world):fail("Godot direct disconnect retained the previous world");return
	server_browser.open(true,true)
	await process_frame
	if closing or not server_browser.wanted or str(server_browser.state.get("tab",""))!="Direct":fail("Godot direct browser did not reopen after disconnect");return
	report.direct_reconnect.browser_reopened=true
	server_browser.confirm_direct("127.0.0.1:5121","",[server_browser.connection,server_browser.view_id])

func direct_portal_handoff(handoff: Dictionary,origin: Node,origin_connection: int)->void:
	var next_identity: RefCounted=handoff.get("identity")
	var destination: Node=handoff.get("session") if handoff.get("session") is Node else null
	if direct_portal_adopting and destination!=null and is_same(destination,direct_portal_adopting_destination):return
	if closing or direct_portal_adopting or not is_instance_valid(origin) or not is_same(direct_session,origin) or session_connection!=origin_connection or origin.phase!="portal-ready" or next_identity==null:
		if not is_same(destination,direct_session):direct_dispose_portal_handoff(handoff)
		return
	direct_portal_adopting=true
	direct_portal_adopting_destination=destination
	var host_name:=str(handoff.get("host",""))
	var port_number:=int(handoff.get("port",0))
	var player_name:=str(handoff.get("playerName",""))
	var character: Dictionary=handoff.get("character",{})
	var source_port:=direct_server_port
	await direct_disconnect(false)
	if closing:
		direct_dispose_portal_handoff(handoff)
		direct_portal_adopting=false
		direct_portal_adopting_destination=null
		return
	var old_retired:=direct_session==null and not is_instance_valid(world)
	report.direct_portal_check={"source_port":source_port,"destination_port":port_number,"character_kind":"bic" if character.has("data") else "reference","old_retired":old_retired,"destination_auth_started":false,"world_admitted":false}
	if not old_retired:
		direct_dispose_portal_handoff(handoff)
		fail("Portal handoff retained the old world or session")
		direct_portal_adopting=false
		direct_portal_adopting_destination=null
		return
	report.direct_portal_transfers=int(report.get("direct_portal_transfers",0))+1
	await direct_connect(host_name,port_number,"","",player_name,handoff)
	direct_portal_adopting=false
	direct_portal_adopting_destination=null

func direct_dispose_portal_handoff(handoff: Dictionary)->void:
	if handoff.get("character",{}).get("data") is PackedByteArray:handoff.character.data.fill(0)
	if handoff.get("identity") is RefCounted:handoff.identity.dispose()
	if handoff.get("session") is Node and is_instance_valid(handoff.session):
		handoff.session.call("close")
		handoff.session.queue_free()

func direct_prepare_portal_destination(message: Dictionary)->Dictionary:
	if closing or direct_session==null or direct_session.phase!="transferring":return {"error":"The source session is unavailable"}
	var source_session: Node=direct_session
	var source_connection:=session_connection
	var install:=str(args.get("direct-install",ProjectSettings.globalize_path("res://../../FullDecomp/NwnRootInstall")))
	var startup: Dictionary=StartupPaths.resolve(install)
	if startup.has("error"):return {"error":startup.error}
	var profile:=str(args.get("direct-profile",startup.userDirectory))
	var destination: Node=DirectSession.new();host.add_child(destination)
	if not await destination.prepare_portal_start(profile,install,str(args.get("direct-settings",""))):
		destination.call("close");destination.queue_free()
		return {"error":"The destination session could not be prepared"}
	if closing or direct_session!=source_session or session_connection!=source_connection or source_session.phase!="transferring":
		destination.call("close");destination.queue_free()
		return {"error":"The source session closed during portal preparation"}
	var query: Node=ServerQuery.new();host.add_child(query)
	var server_info: Dictionary={}
	var server_info_unavailable:=false
	if query.query(str(message.host),int(message.port)):
		var answer: Array=await query.completed
		if answer.size()==2 and str(answer[1]).is_empty() and answer[0] is Dictionary:server_info=answer[0]
		else:server_info_unavailable=true
	else:server_info_unavailable=true
	if is_instance_valid(query):query.close();query.queue_free()
	if closing or direct_session!=source_session or session_connection!=source_connection or source_session.phase!="transferring":
		destination.call("close");destination.queue_free()
		return {"error":"The source session closed during portal preparation"}
	destination.set_server_vault_policy(server_info,str(message.host),int(message.port))
	return {"session":destination,"install":install,"startup":startup,"serverInfo":server_info,"serverInfoUnavailable":server_info_unavailable}

func request_disconnect(_save_character: bool)->void:
	if not direct_mode:super.request_disconnect(_save_character);return
	if _save_character:direct_save_then_disconnect()
	else:await direct_disconnect(true,true)

func direct_save_then_disconnect()->void:
	if direct_session==null:return
	direct_disconnect_after_export=true
	var result: Dictionary=await direct_session.request_character_export()
	if result.has("error"):
		direct_disconnect_after_export=false
		direct_character_export_status({"state":"failed","text":str(result.error),"uncertain":direct_session.character_export_uncertain})

func direct_character_export_status(status: Dictionary)->void:
	if closing or direct_session==null:return
	direct_lobby_state.exportStatus=status.duplicate(true)
	if str(status.get("state",""))=="saved":
		var saved: Dictionary=direct_session.saved_character_list()
		if direct_session.local_vault_allowed and saved.get("ready",false):direct_lobby_state.savedCharacters=saved.entries
		var entry: Dictionary=status.get("entry",{})
		if args.get("direct-headless-character-export-check","")=="true" and direct_character_export_stage==1:
			var readback: Dictionary=direct_session.saved_character_bytes(str(entry.get("id","")))
			var reopened=CharacterExportVault.new()
			var reopened_ready: bool=reopened.configure(str(direct_session.character_vault.directory))
			var persisted: Dictionary=reopened.export_character(str(entry.get("id",""))) if reopened_ready else {"error":"vault reopen failed"}
			var listed: bool=saved.get("ready",false) and saved.entries.any(func(row: Dictionary):return str(row.get("id",""))==str(entry.get("id","")))
			var durable: bool=readback.get("ready",false) and persisted.get("ready",false) and readback.data==persisted.data
			report.direct_character_export_check={"requestSent":true,"serverReply":true,"saved":listed,"durableReadback":durable,"revision":int(entry.get("revision",0)),"bytes":int(entry.get("bytes",0)),"sha256":str(entry.get("sha256","")),"sessionAlive":direct_session.phase=="playing"}
			if not listed or not durable:fail("Godot character export failed durable vault verification");return
			direct_character_export_stage=2
		receive({"kind":"character-saved","connection":session_connection,"name":str(entry.get("name","")),"entry":entry})
	elif str(status.get("state",""))=="failed" and args.get("direct-headless-character-export-check","")=="true" and direct_character_export_stage==1:
		fail("Private server character export failed: "+str(status.get("text","")));return
	direct_show_character_state()
	if direct_disconnect_after_export:
		if str(status.get("state",""))=="saved":direct_disconnect.call_deferred()
		elif str(status.get("state",""))=="failed":direct_disconnect_after_export=false
	if direct_shutdown_after_export:
		if str(status.get("state",""))=="saved":
			direct_shutdown_after_export=false
			direct_shutdown_export_complete=true
			shutdown.call_deferred()
		elif str(status.get("state",""))=="failed":direct_close_save_failed(str(status.get("text","Character save failed")))

func direct_close_save_failed(detail: String)->void:
	direct_shutdown_after_export=false
	var event: Dictionary={"code":"network.character-close-save-failed","reason":"Character save failed; the window remains open. Retry Export Character or disconnect without saving.","detail":detail}
	if direct_session!=null:
		direct_session.diagnostic_event.emit(event)
		direct_session.diagnostic.emit(str(event.code),str(event.reason))
	if is_instance_valid(gameplay_ui):gameplay_ui.chat.append_message({"system":true,"text":str(event.reason)})

func direct_disconnect(return_to_menu: bool=true,report_hud_action: bool=false)->Dictionary:
	if closing:return {}
	direct_raw_deltas.reset();direct_raw_refresh_pending=false
	direct_shutdown_after_export=false
	direct_lobby_page_reset()
	direct_finish_queued_visual_receipts("closed")
	if direct_scene_delivery!=null:direct_scene_delivery.dispose();direct_scene_delivery=null
	if direct_visual_presentation!=null:direct_visual_presentation.dispose();direct_visual_presentation=null
	if is_instance_valid(gameplay_ui) and gameplay_ui.creator.phase!="closed":gameplay_ui.creator.finish_view()
	direct_cancel_join_policy_query()
	direct_disconnect_after_export=false
	direct_character_export_stage=0
	direct_visual_queue.clear()
	direct_projectile_queue.clear()
	direct_module_pause_queue.clear()
	direct_voice_queue.clear()
	direct_camera_queue.clear();direct_camera_state=null;direct_camera_target_id=-1;direct_camera_pending_entry_attach=false;direct_camera_appearance_job=-1;direct_camera_appearance_table={};direct_camera_height_cache.clear()
	if is_instance_valid(direct_placed_sounds):direct_placed_sounds.detach()
	if is_instance_valid(direct_ambient_audio):direct_ambient_audio.close();direct_ambient_audio.queue_free();direct_ambient_audio=null
	var disconnect_outcome: Dictionary={}
	var disconnect_feedback: String=""
	if direct_session!=null:
		direct_keyboard_reset()
		disconnect_outcome=await direct_session.call("disconnect_session")
		if report_hud_action and disconnect_outcome.has("error"):
			var detail:=str(disconnect_outcome.error)
			disconnect_feedback=detail
			var event: Dictionary={"code":"network.hud-action-failed","reason":detail}
			direct_session.diagnostic_event.emit(event)
			direct_session.diagnostic.emit(str(event.code),detail)
		direct_session.queue_free();direct_session=null
	direct_check_deadline=0
	direct_nwsync_cancel_pending=false
	reset_session()
	direct_lobby_choices.clear();direct_lobby_state.clear();selected_character.clear()
	direct_retire_local_file();direct_local_file_last_token=-1
	direct_retire_pending_preview()
	direct_catalog_adopted=false;direct_area_presented=false;direct_quickbar_received=false;local_character_pending=false
	direct_inventory_stage=0;direct_inventory_deadline=0;direct_item_id=-1
	session_connection+=1
	if direct_login_profiles!=null:
		direct_login_profiles.connection=session_connection
		direct_login_profiles.visible=false;direct_login_profiles.view_id+=1
	server_browser.reset(session_connection)
	character_lobby.apply_state({"connection":session_connection,"state":{"phase":"menu","canJoin":true}})
	if is_instance_valid(render_menu):render_menu.observe_lobby({"phase":"menu","connected":false,"busy":false})
	if return_to_menu:
		if disconnect_feedback.is_empty():open_startup_menu.call_deferred()
		else:direct_disconnect_failure_menu_status.call_deferred(session_connection,disconnect_feedback)
	return disconnect_outcome

func direct_disconnect_failure_menu_status(connection: int,detail: String)->void:
	if closing or connection!=session_connection or direct_session!=null:return
	await open_startup_menu()
	if closing or connection!=session_connection or direct_session!=null or not is_instance_valid(render_menu) or not is_instance_valid(render_menu.pregame):return
	var pregame=render_menu.pregame
	if not pregame.wanted or pregame.closed:return
	pregame.placeholder_message=detail
	pregame.refresh()

func direct_catalog_ready(prepared: RefCounted)->void:
	if closing or direct_catalog_adopted or not is_instance_valid(direct_session) or not is_same(direct_session.catalog,prepared):return
	if not install_mounted_catalog(prepared,str(direct_session.install_root),direct_session.resource_sources):fail("Godot catalog could not attach to the native gameplay UI");return
	var talk_session: Node=direct_session
	var talk_connection:=session_connection
	if is_instance_valid(gameplay_ui):
		gameplay_ui.text.network_diagnostic=func(event: Dictionary)->void:
			if closing or direct_session!=talk_session or session_connection!=talk_connection:return
			talk_session.diagnostic_event.emit(event.duplicate(true))
			talk_session.diagnostic.emit(str(event.get("code","network.talk-table-warning")),str(event.get("reason","Native talk-table lookup warning")))
	if direct_diagnostics!=null and prepared.get("diagnostic_journal") is RefCounted:
		var journal: RefCounted=prepared.get("diagnostic_journal")
		if direct_diagnostic_catalog!=journal:
			if direct_diagnostic_catalog!=null and direct_diagnostic_catalog.is_connected("recorded",Callable(self,"direct_catalog_diagnostic")):direct_diagnostic_catalog.disconnect("recorded",Callable(self,"direct_catalog_diagnostic"))
			direct_diagnostic_catalog=journal
			for row in prepared.call("diagnostic_records"):direct_catalog_diagnostic(row)
			journal.connect("recorded",Callable(self,"direct_catalog_diagnostic"))
	direct_catalog_adopted=true
	if not direct_preview_pending.is_empty():
		var pending: Dictionary=direct_preview_pending
		direct_preview_pending={}
		var bytes: PackedByteArray=pending.bytes
		pending.erase("bytes")
		if int(pending.connection)==session_connection and int(pending.sessionId)==direct_session.get_instance_id() and pending.key==direct_lobby_state.get("selected") and int(pending.requestId)==direct_choice_request_id and direct_server_preview_current(pending,direct_session,session_connection):
			direct_publish_server_preview(bytes)
		bytes.fill(0)
		if not direct_preview_connection_current(talk_session,talk_connection):return
	# NWSync can take a full helper timeout to return this optional camera
	# table. Keep its read, decode and repair off the character-list handoff.
	var camera_assets: Node=gameplay_ui.assets
	direct_camera_appearance_job=camera_assets.request("appearance",2017,"2da")
	if direct_camera_appearance_job>=0:
		camera_assets.completed.connect(direct_camera_appearance_prepared.bind(camera_assets))
	else:report.direct_camera_appearance_table_unavailable=camera_assets.failure
	if is_instance_valid(direct_ambient_audio):direct_ambient_audio.configure(prepared,ProjectSettings.globalize_path(str(args.get("prepared-cache","user://native-prepared-v2"))))
	label.text="Godot resource catalog ready"
	if local_character_pending:direct_select_local_character()
	if not direct_lobby_state.is_empty():direct_show_character_state()
	direct_present_area()

func direct_camera_appearance_prepared(id: int,result: Dictionary,source: Node)->void:
	if id!=direct_camera_appearance_job or not is_instance_valid(gameplay_ui) or gameplay_ui.assets!=source:return
	source.completed.disconnect(direct_camera_appearance_prepared.bind(source))
	direct_camera_appearance_job=-1
	if closing or direct_session==null:return
	var reason:=str(result.get("error",""))
	if not reason.is_empty():
		report.direct_camera_appearance_table_unavailable=reason
		return
	direct_camera_appearance_table=result.value
	direct_camera_height_cache.clear()

func direct_catalog_diagnostic(row: Dictionary)->void:
	if direct_diagnostics==null:return
	var key:=str(row.get("session",""))+":"+str(row.get("sequence",0))
	if direct_diagnostic_catalog_seen.has(key):return
	direct_diagnostic_catalog_seen[key]=true
	direct_diagnostics.record(str(row.get("code","resource.failure")),str(row.get("message","")),row.get("context",{}),str(row.get("severity","warning")))

func direct_character_list(rows: Array[Dictionary])->void:
	if closing:return
	direct_retire_pending_preview()
	if args.get("direct-server-vault-reconnect-check","")=="true":report.direct_server_vault_reconnect_check={"rosterAccepted":not rows.is_empty(),"serverRowMatched":false,"previewRequested":false,"previewReady":false,"playSent":false,"worldAdmitted":false}
	var accepted_packets:=int(report.get("direct_character_list",{}).get("acceptedPackets",0))+1
	report.direct_character_list={"acceptedPackets":accepted_packets,"receivedServerRows":rows.size(),"projectedServerRows":0,"projectedLocalRows":0,"projectedSavedRows":0,"phase":"character-selection"}
	if report.get("direct_status") is Dictionary:
		report.direct_status.characterListPackets=accepted_packets
		report.direct_status.serverCharacterRows=rows.size()
	if not direct_browser_join_row.is_empty():
		if direct_browser_store!=null:
			report.direct_history_saved=direct_browser_store.remember(direct_browser_join_row,direct_browser_join_name)
		direct_browser_join_row.clear();direct_browser_join_name=""
		if is_instance_valid(server_browser):
			direct_reset_browser_presentation()
			server_browser.receive({"kind":"browser-closed","connection":session_connection})
	if args.get("direct-headless-manual-check","")=="true" or str(args.get("direct-headless-vault-policy-check","")) in ["server-only","local-allowed","server-only-play"] or args.get("direct-server-vault-create-check","")=="true" or args.get("direct-server-vault-reconnect-check","")=="true" or not args.has("direct-pregen-bic") and not args.has("direct-local-bic") and args.get("direct-headless-check","")!="true":
		direct_lobby_choices.clear()
		var choices: Array=[]
		var server_choices: Array=[]
		for row in rows:
			var key: String="server:"+str(row.source)+":"+str(row.resref)
			if direct_lobby_choices.has(key):fail("Duplicate native server character identity");return
			var choice: Dictionary=row.duplicate(true)
			choice.key=key;choice.source="server";choice.nativeSource=int(row.source);choice.serverSource=int(row.source);choice.label=str(row.resref)
			direct_lobby_choices[key]=choice.duplicate(true)
			server_choices.append(choice)
		if direct_session.local_vault_allowed:
			for row in direct_local_choices():
				direct_lobby_choices[row.key]=row.duplicate(true)
				choices.append(row)
			if not direct_local_file_key.is_empty() and not direct_local_file_bytes.is_empty():
				direct_lobby_choices[direct_local_file_key]=direct_local_file_choice.duplicate(true)
				choices.append(direct_local_file_choice.duplicate(true))
		else:direct_retire_local_file()
		choices.append_array(server_choices)
		var empty_notice: String="No server characters were returned for this login profile. Create a character or check the player name and CD key." if not direct_session.local_vault_allowed else "No usable local or server character was found; create a character to continue"
		var admitted_endpoint: Dictionary=direct_lobby_state.get("endpoint",{"host":server_label,"port":direct_server_port}).duplicate(true)
		direct_lobby_state={"phase":"character-selection","endpoint":admitted_endpoint,"choices":choices,"selected":null,"preview":null,"canSelect":not choices.is_empty(),"canCreate":true,"connected":true,"localAllowed":direct_session.local_vault_allowed,"busy":false,"error":"" if not choices.is_empty() else empty_notice}
		if direct_lobby_choices.has(direct_local_file_key):
			direct_lobby_state.selected=direct_local_file_key;direct_lobby_state.preview=direct_local_file_preview.duplicate(true);direct_lobby_state.selectionAck={"requestId":direct_local_file_token,"key":direct_local_file_key};selected_character=direct_local_file_choice.duplicate(true)
		var saved: Dictionary=direct_session.saved_character_list()
		if direct_session.local_vault_allowed and saved.get("ready",false):direct_lobby_state.savedCharacters=saved.entries
		report.direct_character_list.projectedServerRows=rows.size()
		report.direct_character_list.projectedLocalRows=choices.size()-rows.size()
		report.direct_character_list.projectedSavedRows=direct_lobby_state.get("savedCharacters",[]).size()
		direct_show_character_state()
		if (args.get("direct-server-vault-create-check","")=="true" or args.get("direct-server-vault-reconnect-check","")=="true") and not direct_creation_probe_started:
			if not direct_session.local_vault_policy_known or direct_session.local_vault_allowed:fail("Private creation fixture requires authoritative server-vault policy");return
			if args.get("direct-server-vault-create-check","")=="true" and not rows.is_empty():fail("Private creation fixture server vault was not empty");return
			direct_creation_probe_started=true
			var source: Script=load("res://tests/native_creation_source_live_probe.gd")
			if source==null:fail("Private native creator driver is unavailable");return
			var probe: Node=source.new();host.add_child(probe);probe.run.call_deferred(self)
		return
	if rows.is_empty():
		local_character_pending=true
		direct_select_local_character()
		return
	selected_character=rows[0].duplicate(true)
	if not await direct_session.request_preview(int(selected_character.source),str(selected_character.resref),int(selected_character.get("generation",-1))):fail("Godot direct character preview request failed")

func direct_select_local_character()->void:
	if closing or not local_character_pending or direct_session==null or direct_session.phase!="character-selection" or direct_session.catalog==null:return
	var pregenerated:=args.has("direct-pregen-bic")
	var name:=str(args.get("direct-pregen-bic","") if pregenerated else args.get("direct-local-bic",""))
	if name.is_empty() or name.length()>128 or name.get_file()!=name or name.find("\\")>=0 or name.find(":")>=0 or not name.to_lower().ends_with(".bic"):
		fail("Private server has no server-vault characters; select a local or installed pregenerated BIC");return
	var path:=str(direct_session.install_root).path_join("data/lcv").path_join(name) if pregenerated else str(direct_session.profile_root).path_join("localvault").path_join(name)
	var file:=FileAccess.open(path,FileAccess.READ)
	if file==null or file.get_length()<4 or file.get_length()>Characters.MAX_CHARACTER_BYTES:
		fail("Selected local character BIC is unavailable");return
	var bytes: PackedByteArray=file.get_buffer(file.get_length());file.close()
	if not await direct_session.play_local_character(bytes):fail("Godot local character upload was rejected");return
	local_character_pending=false
	label.text="Uploading selected local character to private server…"

func direct_preview_connection_current(owner: Node,connection: int)->bool:
	return not closing and is_instance_valid(owner) and is_same(direct_session,owner) and session_connection==connection

func direct_server_preview_current(preview: Dictionary,owner: Node,connection: int)->bool:
	if not direct_preview_connection_current(owner,connection) or owner.phase not in ["character-selection","character-rejected"] or owner.character_submission_pending:return false
	var source: Variant=selected_character.get("nativeSource",selected_character.get("source"))
	if not source is int or int(selected_character.get("generation",-1))!=int(owner.character_list_generation):return false
	var expected_type:=5 if source==17 else 4 if source==14 else 1
	return preview.get("resref")==selected_character.get("resref") and int(preview.get("previewType",-1))==expected_type

func direct_retire_pending_preview()->void:
	if direct_preview_pending.is_empty():return
	var bytes: PackedByteArray=direct_preview_pending.bytes
	direct_preview_pending={}
	bytes.fill(0)

func direct_character_preview(preview: Dictionary)->void:
	var owner: Node=direct_session
	var connection:=session_connection
	if not direct_server_preview_current(preview,owner,connection):return
	direct_retire_pending_preview()
	var bytes: PackedByteArray=preview.get("bytes",PackedByteArray())
	if bytes.is_empty():
		if not direct_lobby_state.is_empty():
			direct_lobby_state.preview=null
			direct_show_character_state()
		return
	if bytes.size()<MIN_CHARACTER_PREVIEW_BYTES or bytes.size()>Characters.MAX_CHARACTER_BYTES or bytes.slice(0,4).get_string_from_ascii()!="BIC ":
		direct_server_preview_invalid();return
	if not direct_lobby_state.is_empty():
		if not direct_catalog_adopted:
			# The packet owner wipes its copy after the signal returns. Keep an
			# independent buffer across the existing catalog handoff.
			direct_preview_pending={"connection":connection,"sessionId":owner.get_instance_id(),"key":direct_lobby_state.get("selected"),"requestId":direct_choice_request_id,"resref":preview.resref,"previewType":preview.previewType,"bytes":bytes.duplicate()}
			direct_lobby_state.preview=null
			direct_show_character_state()
			return
		direct_publish_server_preview(bytes)
		return
	var sent: bool=await owner.play_character(int(selected_character.source),str(selected_character.resref),int(selected_character.get("generation",-1)))
	if not sent and direct_preview_connection_current(owner,connection):fail("Godot direct character Play request failed")

func direct_publish_server_preview(bytes: PackedByteArray)->void:
	var projected:=direct_project_bic(bytes)
	if projected.has("error"):
		direct_server_preview_invalid()
		return
	direct_lobby_state.preview=projected
	if args.get("direct-server-vault-reconnect-check","")=="true":report.direct_server_vault_reconnect_check.previewReady=true
	direct_show_character_state()

func direct_server_preview_invalid()->void:
	if closing or not is_instance_valid(direct_session):return
	if not direct_lobby_state.is_empty():direct_lobby_state.preview=null
	var owner: Node=direct_session
	var connection:=session_connection
	var event: Dictionary={"code":"network.character-preview-invalid","reason":"The server character preview could not be read"}
	owner.diagnostic_event.emit(event)
	if direct_preview_connection_current(owner,connection):owner.diagnostic.emit(str(event.code),str(event.reason))

func direct_character_rejected(message: Dictionary)->void:
	if closing or not is_instance_valid(direct_session):return
	direct_retire_pending_preview()
	if is_instance_valid(gameplay_ui):gameplay_ui.creator.observe({"phase":"character-rejected"})
	selected_character.clear()
	direct_lobby_state.phase="character-rejected"
	direct_lobby_state.busy=false
	direct_lobby_state.connected=true
	direct_lobby_state.canCreate=true
	direct_lobby_state.selected=null
	direct_lobby_state.preview=null
	direct_lobby_state.erase("selectionAck")
	direct_lobby_state.canSelect=not direct_lobby_state.get("choices",[]).is_empty()
	if str(direct_lobby_state.get("error","")).is_empty():direct_lobby_state.error="The server rejected that character. Select another character or reconnect to refresh the list."
	report.direct_character_rejections=int(report.get("direct_character_rejections",0))+1
	report.direct_last_character_rejection_reason=int(message.get("reason",0))
	direct_show_character_state()

func direct_project_bic(bytes: PackedByteArray)->Dictionary:
	if bytes.size()<MIN_CHARACTER_PREVIEW_BYTES or bytes.size()>Characters.MAX_CHARACTER_BYTES:return {"error":"Invalid BIC record"}
	var parser:=GffDocument.new()
	var document: Dictionary=parser.parse(bytes,"BIC ")
	if not parser.failure.is_empty():return {"error":"Invalid BIC record"}
	# The saved native preview worker used the chooser's talk-table language
	# and displayed the BIC's authored fields for both local and server records.
	var language:=0
	if direct_catalog_adopted and is_instance_valid(gameplay_ui):language=int(gameplay_ui.text.base.language)
	elif is_instance_valid(character_lobby) and is_instance_valid(character_lobby.native_preview):language=int(character_lobby.native_preview.language)
	var projected: Dictionary=CharacterPreview.project(document.root,language)
	if projected.has("error"):return projected
	projected.visualSource=preload("res://systems/native_data/bic_visual.gd").source(document)
	projected.skillSource=preload("res://systems/native_data/pregame_skills.gd").source(document)
	projected.spellSource=preload("res://systems/native_data/pregame_spells.gd").source(document,projected.skillSource)
	projected.recordSource=preload("res://systems/native_data/pregame_record.gd").source(document,projected.skillSource)
	return projected

func direct_local_choices()->Array:
	var choices: Array=[]
	var roots: Array=ticket.get("localCharacterRoots",[])
	for index in roots.size():
		var directory:=DirAccess.open(str(roots[index]))
		if directory==null:continue
		var names:=Array(directory.get_files());names.sort()
		for name in names:
			if choices.size()>=1024:break
			if not str(name).to_lower().ends_with(".bic") or directory.is_link(str(name)):continue
			var path:=str(roots[index]).path_join(str(name))
			var file:=FileAccess.open(path,FileAccess.READ)
			if file==null:continue
			var size:=file.get_length();file.close()
			if size<56 or size>Characters.MAX_CHARACTER_BYTES:continue
			var digest:=FileAccess.get_sha256(path)
			if digest.length()!=64:continue
			var key: String=("installed" if index==0 else "local" if index==1 else "vault")+":"+str(name)
			choices.append({"key":key,"source":"installed" if index==0 else "vault","catalogStem":str(name).get_basename(),"label":str(name).get_basename(),"nativeFile":{"format":"native-local-bic-v1","path":path,"sha256":digest,"bytes":size}})
	if direct_session!=null:
		var listing: Dictionary=direct_session.saved_character_list()
		if listing.get("ready",false):
			for entry in listing.entries:
				if choices.size()>=1024:break
				choices.append({"key":"godot-vault:"+str(entry.id),"source":"vault","catalogStem":"","label":str(entry.name),"nativeVaultId":str(entry.id),"nativeFile":{"format":"godot-vault-bic-v1","id":str(entry.id),"sha256":str(entry.sha256),"bytes":int(entry.bytes)}})
	return choices

func direct_retire_local_file()->void:
	if not direct_local_file_bytes.is_empty():direct_local_file_bytes.fill(0);direct_local_file_bytes=PackedByteArray()
	if not direct_local_file_key.is_empty():
		direct_lobby_choices.erase(direct_local_file_key)
		var choices: Array=[]
		for row in direct_lobby_state.get("choices",[]):
			if str(row.get("key",""))!=direct_local_file_key:choices.append(row)
		if direct_lobby_state.has("choices"):direct_lobby_state.choices=choices
		if str(direct_lobby_state.get("selected",""))==direct_local_file_key:
			direct_lobby_state.selected=null;direct_lobby_state.preview=null;direct_lobby_state.erase("selectionAck");selected_character.clear()
	direct_local_file_key="";direct_local_file_token=-1;direct_local_file_choice.clear();direct_local_file_preview.clear()
func direct_local_bytes(row: Dictionary)->PackedByteArray:
	if direct_session==null or not direct_session.local_vault_allowed:return PackedByteArray()
	var ticket_file: Dictionary=row.get("nativeFile",{})
	if str(ticket_file.get("format",""))=="direct-local-bic-v1":
		return direct_local_file_bytes.duplicate() if str(row.get("key",""))==direct_local_file_key and int(ticket_file.get("token",-1))==direct_local_file_token and int(ticket_file.get("bytes",-1))==direct_local_file_bytes.size() else PackedByteArray()
	if str(ticket_file.get("format",""))=="godot-vault-bic-v1":
		if direct_session==null or str(row.get("nativeVaultId",""))!=str(ticket_file.get("id","")):return PackedByteArray()
		var saved: Dictionary=direct_session.saved_character_bytes(str(ticket_file.id))
		if not saved.get("ready",false) or int(saved.entry.bytes)!=int(ticket_file.get("bytes",-1)) or str(saved.entry.sha256)!=str(ticket_file.get("sha256","")):return PackedByteArray()
		return saved.data
	var path:=str(ticket_file.get("path",""))
	if not ticket.get("localCharacterRoots",[]).has(path.get_base_dir()) or str(ticket_file.get("format",""))!="native-local-bic-v1":return PackedByteArray()
	var file:=FileAccess.open(path,FileAccess.READ)
	if file==null:return PackedByteArray()
	if file.get_length()!=int(ticket_file.get("bytes",-1)):file.close();return PackedByteArray()
	var bytes:=file.get_buffer(file.get_length());file.close()
	if preload("res://systems/native_data/prepared_cache.gd").digest(bytes)!=str(ticket_file.get("sha256","")):return PackedByteArray()
	return bytes

func direct_lobby_choice(row: Dictionary)->Dictionary:
	var result: Dictionary={"key":row.get("key"),"label":row.get("label"),"source":row.get("source")}
	if row.has("classes"):result.classes=row.classes
	for field in ["portrait","portraitRef","serverSource","pregenerated","firstName","lastName"]:
		if row.has(field):result[field]=row[field]
	if str(row.get("source",""))!="server":
		for field in ["nativeFile","catalogStem","localFile"]:
			if row.has(field):result[field]=row[field]
	return result

func direct_lobby_server_info(raw: Dictionary)->Dictionary:
	var result: Dictionary={}
	for field in ["serverName","moduleName","moduleDescription","gameDetails","serverVersion","address"]:
		if raw.get(field) is String:result[field]=raw[field]
	for field in ["minimumLevel","maximumLevel","playerCount","maximumPlayers","pvpSetting","serverStatus"]:
		if raw.get(field) is int:result[field]=raw[field]
	if raw.get("extendedReceived") is bool:result.extendedReceived=raw.extendedReceived
	return result

func direct_lobby_page_reset()->void:
	direct_lobby_page_version+=1
	direct_lobby_page=0
	if is_instance_valid(direct_lobby_info_query):
		var query: Node=direct_lobby_info_query
		direct_lobby_info_query=null
		query.close()
		query.completed.emit({},"Character lobby page changed")
		query.queue_free()
	if not direct_lobby_state.is_empty():
		direct_lobby_state.lobbyPage=0
		direct_lobby_state.pageError=""
		direct_lobby_state.serverInfoPending=false
		direct_lobby_state.erase("serverDetails")

func direct_lobby_page_current(owner: Node,connection: int,version: int)->bool:
	return not closing and is_instance_valid(owner) and is_same(direct_session,owner) and session_connection==connection and direct_lobby_page_version==version

func direct_lobby_page_info(owner: Node,connection: int,version: int,endpoint: Dictionary)->void:
	if not direct_lobby_page_current(owner,connection,version) or direct_lobby_page!=1:return
	var query: Node=ServerQuery.new()
	direct_lobby_info_query=query
	host.add_child(query)
	var started: bool=query.query(str(endpoint.get("host","")),int(endpoint.get("port",0)),3500,true)
	var answer: Array=[]
	if started:answer=await query.completed
	else:answer=[{},"Server information request could not start"]
	if is_same(direct_lobby_info_query,query):direct_lobby_info_query=null
	if is_instance_valid(query):query.close();query.queue_free()
	if not direct_lobby_page_current(owner,connection,version) or direct_lobby_page!=1:return
	if answer.size()==2 and str(answer[1]).is_empty() and answer[0] is Dictionary:
		direct_lobby_state.serverDetails=direct_lobby_server_info(answer[0])
	else:direct_lobby_state.pageError=str(answer[1]) if answer.size()>1 else "Server information request failed"
	direct_lobby_state.serverInfoPending=false
	direct_show_character_state()

func direct_lobby_can_cancel()->bool:
	if closing or direct_lobby_cancelling:return false
	if direct_session==null:return bool(direct_lobby_state.get("canCancelJoin",false))
	if direct_session.phase=="idle" and str(direct_lobby_state.get("phase",""))=="connecting":return true
	return ResourceProgress.can_cancel_resources(str(direct_session.phase),bool(direct_session.character_submission_pending),bool(direct_session.character_uploaded)) or direct_session.phase=="transferring" and not direct_session.portal_pending.is_empty()

func direct_lobby_selectable()->bool:
	return not closing and direct_session!=null and direct_session.phase in ["character-selection","character-rejected"] and not direct_session.character_submission_pending and not direct_session.character_uploaded and not direct_session.server_character_list_pending and not bool(direct_lobby_state.get("busy",false)) and not bool(direct_lobby_state.get("creating",false))

func direct_show_character_state()->void:
	if not is_instance_valid(character_lobby):return
	var state: Dictionary=direct_lobby_state.duplicate(true)
	var public_choices: Array=[]
	for row in state.get("choices",[]):
		if row is Dictionary:public_choices.append(direct_lobby_choice(row))
	state.choices=public_choices
	if direct_session!=null:
		state.gameSession=direct_session.state()
		var info:=direct_lobby_server_info(direct_session.server_info_snapshot)
		info.merge(direct_lobby_state.get("serverDetails",{}),true)
		if direct_lobby_state.get("serverStatus") is int and direct_session.phase not in ["closed","failed"]:info.serverStatus=direct_lobby_state.serverStatus
		state.serverInfo=info
	state.canCancelJoin=direct_lobby_can_cancel()
	state.canSelect=direct_lobby_selectable()
	state.canCreate=direct_session!=null and direct_lobby_selectable() and direct_session.catalog!=null and direct_session.object_rules!=null
	state.canLobbyPages=direct_lobby_selectable()
	state.lobbyPage=direct_lobby_page
	if str(state.get("phase","")) in ["character-selection","character-rejected"] and direct_session!=null:state.lobbyPlayers=direct_session.lobby_players.list()
	var local_roots: Array=ticket.get("localCharacterRoots",[]) if direct_session!=null and direct_session.local_vault_allowed else []
	var local_vault: Variant=direct_session.character_vault if direct_session!=null and direct_session.local_vault_allowed else null
	var public_state: Dictionary=state.duplicate(true)
	# The world snapshot is not a lobby field; the old host suppressed identical public snapshots.
	public_state.erase("gameSession")
	var signature: String=JSON.stringify({"connection":session_connection,"session":direct_session.get_instance_id() if direct_session!=null else 0,"state":public_state,"localCharacterRoots":local_roots,"nativeVault":local_vault.get_instance_id() if local_vault is Object else 0})
	if signature!=direct_lobby_last_public_signature:
		direct_lobby_last_public_signature=signature
		character_lobby.apply_state({"connection":session_connection,"state":state,"localCharacterRoots":local_roots,"nativeVault":local_vault})
		if is_instance_valid(render_menu):render_menu.observe_lobby(state)
	if str(direct_lobby_state.get("phase","")) in ["character-selection","character-rejected"] and (not is_instance_valid(gameplay_ui) or gameplay_ui.creator.phase=="closed"):character_lobby.panel.show()

func direct_reject_local_choice(key: String,reason: String)->void:
	# A stale or disallowed local BIC is a chooser error, not a session failure.
	direct_lobby_choices.erase(key)
	var remaining: Array=[]
	for row in direct_lobby_state.get("choices",[]):
		if str(row.get("key",""))!=key:remaining.append(row)
	direct_lobby_state.choices=remaining
	direct_lobby_state.selected=null
	direct_lobby_state.preview=null
	direct_lobby_state.canSelect=not remaining.is_empty()
	direct_lobby_state.error=reason
	selected_character.clear()
	direct_show_character_state()

func direct_lobby_players(_rows: Array)->void:
	if not closing and direct_session!=null and direct_session.phase=="character-selection":direct_show_character_state()

func lobby_request(message: Dictionary)->void:
	if not direct_mode:super.lobby_request(message);return
	var kind:=str(message.get("kind",""))
	if int(message.get("connection",session_connection))!=session_connection:return
	if kind=="lobby-disconnect":
		if bool(message.get("saveCharacter",false)):direct_save_then_disconnect()
		else:await direct_disconnect()
		return
	if kind=="lobby-cancel-join":
		if not direct_lobby_can_cancel():return
		direct_lobby_cancelling=true
		await direct_disconnect()
		direct_lobby_cancelling=false
		return
	if kind=="lobby-join":server_browser.open(true,true);return
	if closing or direct_session==null:return
	if kind=="lobby-export":
		var requested: Dictionary=await direct_session.request_character_export()
		if requested.has("error"):direct_character_export_status({"state":"failed","text":str(requested.error),"uncertain":direct_session.character_export_uncertain})
		return
	if kind=="lobby-page":
		if int(message.get("connection",-1))!=session_connection or direct_session.phase not in ["character-selection","character-rejected"]:return
		if not message.get("page") is int:return
		var page: int=message.page
		if page<0 or page>2 or page!=0 and not direct_lobby_selectable():return
		direct_lobby_page_version+=1
		var version:=direct_lobby_page_version
		if is_instance_valid(direct_lobby_info_query):
			var old_query: Node=direct_lobby_info_query
			direct_lobby_info_query=null
			old_query.close();old_query.completed.emit({},"Character lobby page changed");old_query.queue_free()
		direct_lobby_page=page
		direct_lobby_state.lobbyPage=page
		direct_lobby_state.pageError=""
		direct_lobby_state.serverInfoPending=false
		if page!=2:direct_lobby_state.erase("players")
		direct_show_character_state()
		var page_owner: Node=direct_session
		var page_connection:=session_connection
		var endpoint: Dictionary=direct_lobby_state.get("endpoint",{}).duplicate(true)
		var subscription: Dictionary=await page_owner.lobby_player_subscription(page==2)
		if not direct_lobby_page_current(page_owner,page_connection,version):return
		if subscription.has("error"):
			direct_lobby_state.pageError=str(subscription.error)
			direct_show_character_state()
			return
		if page==1 and not bool(direct_lobby_state.get("serverDetails",{}).get("extendedReceived",false)):
			direct_lobby_state.serverInfoPending=true
			direct_show_character_state()
			direct_lobby_page_info(page_owner,page_connection,version,endpoint)
		return
	if kind=="lobby-local-file-preview":
		if int(message.get("connection",-1))!=session_connection or direct_session.phase not in ["character-selection","character-rejected"] or bool(direct_lobby_state.get("busy",false)) or not direct_session.local_vault_allowed or not bool(direct_lobby_state.get("localAllowed",false)):return
		var token:=int(message.get("token",-1))
		var name:=str(message.get("name",""))
		var incoming: Variant=message.get("bytes")
		if token<0 or token<=direct_local_file_last_token or name.is_empty() or name.get_file()!=name or not name.to_lower().ends_with(".bic") or not incoming is PackedByteArray or incoming.size()<4 or incoming.size()>Characters.MAX_CHARACTER_BYTES:return
		direct_local_file_last_token=token
		direct_retire_pending_preview()
		direct_retire_local_file()
		var owned: PackedByteArray=incoming.duplicate()
		var preview: Dictionary=direct_project_bic(owned)
		if preview.has("error"):
			owned.fill(0)
			direct_lobby_state.error=str(preview.error)
			direct_show_character_state()
			return
		direct_local_file_bytes=owned
		direct_local_file_token=token
		direct_local_file_key="local-file:"+str(token)
		direct_local_file_preview=preview.duplicate(true)
		direct_local_file_choice={"key":direct_local_file_key,"source":"local","localFile":true,"label":name,"firstName":preview.get("firstName",{"text":name}),"lastName":preview.get("lastName",{"text":""}),"nativeFile":{"format":"direct-local-bic-v1","token":token,"bytes":owned.size()}}
		direct_lobby_choices[direct_local_file_key]=direct_local_file_choice.duplicate(true)
		var choices: Array=direct_lobby_state.get("choices",[])
		choices.append(direct_local_file_choice.duplicate(true));direct_lobby_state.choices=choices
		selected_character=direct_local_file_choice.duplicate(true)
		direct_choice_request_id=token
		direct_lobby_state.selected=direct_local_file_key;direct_lobby_state.preview=preview;direct_lobby_state.selectionAck={"requestId":token,"key":direct_local_file_key};direct_lobby_state.error="";direct_lobby_state.canSelect=true
		direct_show_character_state()
		return
	if kind=="lobby-choose":
		if direct_lobby_page!=0:
			await lobby_request({"kind":"lobby-page","connection":session_connection,"page":0})
		var key:=str(message.get("key",""))
		if not direct_lobby_selectable() or not direct_lobby_choices.has(key):return
		if message.has("requestId") and (not message.requestId is int or int(message.requestId)<1 or int(message.requestId)>9007199254740991):return
		if key!=direct_local_file_key:direct_retire_local_file()
		direct_retire_pending_preview()
		selected_character=direct_lobby_choices[key].duplicate(true)
		direct_choice_request_id=int(message.get("requestId",-1))
		direct_lobby_state.selected=key;direct_lobby_state.preview=null
		direct_lobby_state.erase("selectionAck")
		direct_lobby_state.erase("characterRejection")
		direct_lobby_state.error=""
		if str(selected_character.get("source",""))=="server":
			var owner: Node=direct_session
			var connection:=session_connection
			var choice: Dictionary=selected_character
			if direct_choice_request_id>0:direct_lobby_state.selectionAck={"connection":connection,"requestId":direct_choice_request_id,"key":key}
			# The saved host sent the acknowledgement over IPC. Defer its local
			# delivery so a queued Play cannot reenter before preview dispatch.
			var publish_selection:=func():
				if direct_preview_connection_current(owner,connection) and not choice.is_empty() and is_same(selected_character,choice) and owner.phase in ["character-selection","character-rejected"]:direct_show_character_state()
			publish_selection.call_deferred()
			var sent: bool=await owner.request_preview(int(choice.nativeSource),str(choice.resref),int(choice.get("generation",-1)))
			if not direct_preview_connection_current(owner,connection) or choice.is_empty() or not is_same(selected_character,choice) or owner.phase not in ["character-selection","character-rejected"]:return
			if not sent:fail("Godot direct character preview request failed");return
			if args.get("direct-server-vault-reconnect-check","")=="true":report.direct_server_vault_reconnect_check.previewRequested=true
			return
		else:
			if not direct_session.local_vault_allowed:direct_reject_local_choice(key,"This server does not allow local characters. Choose a server character.");return
			var bytes:=direct_local_bytes(selected_character)
			if bytes.is_empty():direct_reject_local_choice(key,"Local character data changed. Select another character or reconnect to refresh the list.");return
			direct_lobby_state.preview=direct_project_bic(bytes)
			bytes.fill(0)
			if direct_lobby_state.preview.has("error"):direct_reject_local_choice(key,"Local character data is invalid. Select another character.");return
			if direct_choice_request_id>0:direct_lobby_state.selectionAck={"connection":session_connection,"requestId":direct_choice_request_id,"key":key}
		direct_show_character_state()
	elif kind=="lobby-play":
		if direct_lobby_page!=0:
			await lobby_request({"kind":"lobby-page","connection":session_connection,"page":0})
		var key:=str(message.get("key",""))
		if not direct_lobby_selectable() or direct_lobby_state.get("selected")!=key or not direct_lobby_choices.has(key):return
		var owner: Node=direct_session
		var connection:=session_connection
		var choice: Dictionary=selected_character
		if str(choice.get("source",""))=="server":
			direct_retire_pending_preview()
			direct_lobby_state.busy=true
			var sent: bool=await owner.play_character(int(choice.nativeSource),str(choice.resref),int(choice.get("generation",-1)))
			if not direct_preview_connection_current(owner,connection) or choice.is_empty() or not is_same(selected_character,choice):return
			direct_lobby_state.busy=false
			if not sent:fail("Godot direct character Play request failed");return
			if args.get("direct-server-vault-reconnect-check","")=="true":report.direct_server_vault_reconnect_check.playSent=true
		else:
			if direct_lobby_state.get("preview")==null:return
			if not direct_session.local_vault_allowed:direct_reject_local_choice(key,"This server does not allow local characters. Choose a server character.");return
			var bytes:=direct_local_bytes(selected_character)
			if bytes.is_empty():direct_reject_local_choice(key,"Local character data changed. Select another character or reconnect to refresh the list.");return
			var transient_file:=str(selected_character.get("nativeFile",{}).get("format",""))=="direct-local-bic-v1"
			direct_lobby_state.busy=true
			var accepted_local: bool=await owner.play_local_character(bytes,false,str(choice.get("nativeVaultId","")))
			bytes.fill(0)
			if not direct_preview_connection_current(owner,connection) or choice.is_empty() or not is_same(selected_character,choice):return
			direct_lobby_state.busy=false
			if transient_file:direct_retire_local_file()
			if not accepted_local:
				direct_lobby_state.error="Local character could not be submitted. Check this server's character policy and try again."
				direct_show_character_state()
				return
		direct_lobby_state.phase="area-loading";direct_lobby_state.canSelect=false
		direct_show_character_state()

func direct_module_ready(module: Dictionary)->void:
	module_name=str(module.get("name","Arelith"))
	root.title="NWN · Godot direct · "+module_name+" · "+server_label

func _direct_world_projection(prepare_area: bool=false,static_rows: RawWorldDeltas.StaticRows=null)->Dictionary:
	var began:=FrameProfile.begin()
	var data: Dictionary=direct_session.presentation(prepare_area) if static_rows==null else direct_session._direct_presentation(prepare_area,static_rows)
	FrameProfile.finish("direct_world_projection_ms",began)
	FrameProfile.count("count_direct_world_projections",1)
	return data

func _direct_accept_projection(data: Dictionary,static_rows: RawWorldDeltas.StaticRows,receiver: Callable)->Dictionary:
	var previous:=_direct_static_rows
	_direct_static_rows=static_rows
	var result: Dictionary=receiver.call(data)
	_direct_static_rows=previous
	return result

func direct_commit_presentation(data: Dictionary)->Dictionary:
	var static_rows:=_direct_static_rows
	_direct_static_rows=null
	if closing or direct_session==null or not data.get("area") is Dictionary or int(data.area.get("id",-1))!=int(direct_session.world_state.area_id):return {"error":"Native scene snapshot belongs to a retired area"}
	if not direct_raw_deltas.pending.is_empty() or snapshot_commit_running or not pending_prepared_snapshot.is_empty() or not entry_snapshot_commit.is_empty():
		direct_raw_refresh_pending=true
		return {"deferred":true}
	direct_raw_refresh_pending=false
	# The saved host consumes a serial for an unchanged poll too.
	direct_raw_next_serial=maxi(direct_raw_next_serial,raw_serial)+1
	var serial: int=direct_raw_next_serial
	var plan_began:=FrameProfile.begin()
	var changed: Variant=direct_raw_deltas.plan(session_connection,direct_generation,serial,data,static_rows)
	FrameProfile.finish("direct_world_delta_plan_ms",plan_began)
	if direct_raw_deltas.last_static_encodes_reused>0:
		FrameProfile.count("count_direct_static_row_encodes_reused",direct_raw_deltas.last_static_encodes_reused)
	if changed==null:return {"unchanged":true,"serial":raw_serial}
	if not changed is Dictionary:return {"error":"Invalid native raw-world delta"}
	if changed.has("error"):return {"error":str(changed.error)}
	# The old wire receiver assembled this same typed snapshot before commit.
	# Direct ownership skips only the obsolete byte/chunk transport.
	raw_serial=serial
	commit_raw_snapshot({"serial":serial,"connection":session_connection,"generation":direct_generation,"count":changed.objects.size(),"data":changed,"trusted_entry_wire":false})
	if closing:return {"error":"Native scene snapshot was not accepted"}
	return {"changed":true,"serial":serial}

func direct_refresh_world_after_ack(connection: int,generation: int)->void:
	if closing or connection!=session_connection or generation!=direct_generation or direct_session==null or not direct_area_presented or direct_session.phase not in ["area-presenting","playing"]:return
	if not direct_raw_deltas.pending.is_empty():return
	direct_raw_refresh_pending=false
	var static_rows:=RawWorldDeltas.StaticRows.new(true)
	var data: Dictionary=_direct_world_projection(direct_session.phase=="area-presenting",static_rows)
	if data.has("error"):
		direct_raw_refresh_pending=true
		return
	_direct_accept_projection(data,static_rows,direct_world_ready)

func direct_area_ready(_entry: Dictionary)->void:
	direct_finish_queued_visual_receipts("stale")
	if direct_scene_delivery!=null:direct_scene_delivery.dispose();direct_scene_delivery=null
	if direct_visual_presentation!=null:direct_visual_presentation.dispose();direct_visual_presentation=null
	direct_visual_queue.clear()
	direct_projectile_queue.clear()
	direct_module_pause_queue.clear()
	direct_voice_queue.clear()
	direct_camera_target_id=-1
	direct_camera_pending_entry_attach=true
	direct_camera_queue=direct_camera_queue.filter(func(command: Dictionary):return str(command.get("kind",""))!="camera-attach" or int(command.get("nativeAreaId",-1))==direct_session.world_state.area_id)
	if is_instance_valid(direct_placed_sounds):direct_placed_sounds.detach()
	if is_instance_valid(direct_ambient_audio):direct_ambient_audio.detach()
	direct_generation+=1
	direct_raw_deltas.reset();direct_raw_refresh_pending=false
	direct_area_presented=false
	report.direct_area_packet={"area":direct_session.world_state.area_id,"objects":direct_session.world_state.registry.size(),"controlled":direct_session.world_state.local_object_id}
	direct_present_area()

func direct_present_area()->void:
	if closing or direct_area_presented or direct_graphics_failed_generation==direct_generation or not direct_catalog_adopted or direct_session==null or direct_session.phase!="area-presenting":return
	var static_rows:=RawWorldDeltas.StaticRows.new(true)
	var data: Dictionary=_direct_world_projection(true,static_rows)
	if data.has("error") or not data.get("objects") is Array or data.objects.is_empty():
		report.direct_area_wait=str(data.get("error","Native area has no staged objects"))
		return
	var admitted:=_direct_accept_projection(data,static_rows,direct_commit_presentation)
	if admitted.has("error"):direct_area_setup_failed(str(admitted.error));return
	if admitted.get("deferred",false):return
	if not is_instance_valid(world) or world.area_id!=int(data.area.id):direct_area_setup_failed("Godot renderer did not open the direct server area");return
	var sound_session: Node=direct_session
	var sound_world=world
	var sound_area:=int(data.area.id)
	var sound_generation:=direct_generation
	var raw_object_lookup: Callable=func(id: int)->Variant:
		if closing or not is_same(direct_session,sound_session) or not is_same(world,sound_world) or direct_generation!=sound_generation or int(sound_session.world_state.area_id)!=sound_area:return null
		return sound_session.world_state.registry.get(id)
	world.raw_object_lookup=raw_object_lookup
	world.raw_object_enumerate=func()->Array:
		if closing or not is_same(direct_session,sound_session) or not is_same(world,sound_world) or direct_generation!=sound_generation or int(sound_session.world_state.area_id)!=sound_area:return []
		return sound_session.world_state.registry.values()
	if is_instance_valid(world.effects) and is_instance_valid(world.effects.script_sounds):world.effects.script_sounds.raw_object_lookup=raw_object_lookup
	direct_scene_delivery=SceneDelivery.new(self,{"areaId":Callable(self,"direct_scene_area_id"),"canonical":Callable(self,"direct_scene_canonical"),"row":Callable(self,"direct_scene_row"),"sceneClosed":Callable(self,"direct_scene_closed"),"requestSync":Callable(self,"direct_scene_sync"),"receiveMovementChanges":Callable(self,"direct_scene_movement"),"receiveAnimationChanges":Callable(self,"direct_scene_animation"),"receiveVisualChanges":Callable(self,"direct_scene_visual"),"receiveObjectVisual":Callable(self,"direct_scene_object_visual"),"receiveProjectile":Callable(self,"direct_scene_projectile"),"receiveAreaVisual":Callable(self,"direct_scene_area_visual"),"report":Callable(self,"direct_scene_report")})
	if not direct_scene_delivery.error.is_empty():direct_area_setup_failed(direct_scene_delivery.error);return
	direct_visual_presentation=VisualPresentation.new()
	direct_visual_presentation.configure({"areaId":Callable(self,"direct_scene_area_id"),"canonical":Callable(self,"direct_scene_canonical"),"view":Callable(self,"direct_visual_view"),"loopAdd":Callable(self,"direct_visual_loop_add"),"loopRemove":Callable(self,"direct_visual_loop_remove"),"instant":Callable(self,"direct_visual_instant"),"report":Callable(self,"direct_visual_report")})
	if args.get("direct-nwsync-world-material-check","")=="true" and is_instance_valid(world.terrain):
		world.terrain.tile_published.connect(direct_nwsync_world_tile_published)
	direct_drain_visuals()
	direct_drain_voices()
	direct_drain_projectiles()
	direct_area_presented=true
	direct_bind_gameplay_menu()
	direct_publish_clock_controlled()
	label.text="Preparing Godot world…"

func direct_world_ready(data: Dictionary)->Dictionary:
	if closing or not direct_area_presented or direct_session==null or direct_session.phase not in ["area-presenting","playing"]:return {"stale":true}
	if not is_instance_valid(world) or int(data.get("area",{}).get("id",-1))!=world.area_id:return {"stale":true}
	var admitted: Dictionary=direct_commit_presentation(data)
	if admitted.has("error"):
		direct_area_setup_failed(str(admitted.error))
		return admitted
	if admitted.get("deferred",false):return admitted
	_direct_world_publish_tail()
	return admitted

func _direct_world_publish_tail()->void:
	var tail_began:=FrameProfile.begin()
	direct_bind_gameplay_menu()
	direct_drain_visuals()
	direct_drain_voices()
	direct_drain_projectiles()
	direct_camera_bind()
	direct_publish_clock_controlled()
	FrameProfile.finish("direct_world_publish_tail_ms",tail_began)

func _direct_immediate_ack_current(owner: Node,scene: Node,connection: int,generation: int,scene_generation: int,serial: int)->bool:
	return not direct_scene_closed() and direct_area_presented and direct_session==owner and world==scene and session_connection==connection and direct_generation==generation and int(scene.generation)==scene_generation and not scene.closed and not scene.retiring \
		and raw_serial==serial and accepted_raw_serial==serial and int(direct_raw_deltas.base.get("serial",-1))==serial and direct_raw_deltas.pending.is_empty() and not direct_raw_refresh_pending \
		and not snapshot_commit_running and pending_prepared_snapshot.is_empty() and entry_snapshot_commit.is_empty()

func _direct_repeat_accepted_projection()->void:
	# Match a successful unchanged poll without projecting or planning it.
	direct_raw_refresh_pending=false
	direct_raw_next_serial=maxi(direct_raw_next_serial,raw_serial)+1
	_direct_world_publish_tail()

func direct_bind_gameplay_menu()->void:
	if closing or not direct_area_presented or direct_session==null or not initialized or not is_instance_valid(world) or not is_instance_valid(gameplay_ui):return
	var connection:=session_connection
	var generation:=direct_generation
	var area:=int(direct_session.world_state.area_id)
	ensure_native_gameplay_menu(func()->bool:
		return not closing and direct_area_presented and direct_session!=null and session_connection==connection and direct_generation==generation and int(direct_session.world_state.area_id)==area and is_instance_valid(world) and int(world.area_id)==area and is_instance_valid(gameplay_ui) and int(gameplay_ui.generation)==generation and int(gameplay_ui.area_id)==area)

func direct_movement(rows: Array)->Array:
	if closing or direct_session==null or direct_session.phase!="playing" or not is_instance_valid(world) or world.area_id!=direct_session.world_state.area_id:return []
	if args.get("direct-headless-local-smoke-check","")=="true":
		if not report.has("direct_local_smoke_movement_fields"):report.direct_local_smoke_movement_fields=[]
		for row in rows:
			if int(row.get("id",-1))!=int(direct_session.world_state.local_object_id) or report.direct_local_smoke_movement_fields.size()>=32:continue
			var changes: Dictionary=row.get("changes",{})
			report.direct_local_smoke_movement_fields.append({"revision":int(row.get("revision",0)),"created":bool(row.get("created",false)),"fields":changes.keys(),"animation":changes.get("animation"),"pathLength":changes.get("path",[]).size()})
	return world.observe_movement(rows)

func direct_scene_area_id()->int:
	return int(direct_session.world_state.area_id) if direct_session!=null else -1

func direct_scene_canonical(id: Variant)->Variant:
	return direct_session.world_state.disclosure_handles.get(int(id)) if direct_session!=null and id!=null else null

func direct_scene_row(id: Variant)->Variant:
	return direct_session.world_state.registry.get(int(id)) if direct_session!=null and id!=null else null

func direct_scene_closed()->bool:
	return closing or direct_session==null or direct_session.phase!="playing" or not is_instance_valid(world) or int(world.area_id)!=direct_scene_area_id()

func direct_scene_report(code: String,reason: String)->void:
	if direct_session!=null:direct_session.diagnostic_event.emit({"code":code,"reason":reason})

func direct_scene_sync()->Variant:
	if direct_scene_closed():return true
	direct_scene_sync_requested=true
	if direct_scene_sync_running:return await direct_scene_sync_completed
	direct_scene_sync_running=true
	var result: Variant=true
	while direct_scene_sync_requested and not direct_scene_closed():
		direct_scene_sync_requested=false
		result=await direct_scene_sync_once()
		if result is Dictionary and result.has("error"):break
	direct_scene_sync_running=false
	direct_scene_sync_completed.emit(result)
	if direct_scene_sync_requested and not direct_scene_closed():call_deferred("direct_scene_sync")
	return result

func _direct_scene_expected_ids(area_id: int)->Variant:
	var state: RefCounted=direct_session.world_state
	if state.area.is_empty() or state.module.is_empty() or state.local_object_id==DirectSession.WorldState.INVALID or not state.registry.has(state.local_object_id):
		return {"error":"Native world is not ready for presentation"}
	# A presentation updates disclosure tokens and the GUI control context
	# even when only its IDs are needed. Keep those owners in the same order.
	state.sync_disclosure_handles()
	var expected_ids: Array=[]
	for object_id in state.registry:
		var object: Dictionary=state.registry[object_id]
		state.disclosures.token(state.disclosure_handles[object_id],object)
		if int(object.get("areaId",-1))==area_id and not bool(object.get("replicationRemoved",false)):
			expected_ids.append(int(object.get("id",-1)))
	direct_session.gui_access.snapshot(direct_session.gui_access_context())
	return expected_ids

func direct_scene_sync_once()->Variant:
	if direct_scene_closed():return {"error":"Native scene is unavailable"}
	var owner:=direct_session
	var delivery_scope: Array[int]=owner.begin_immediate_world_projection()
	var connection:=session_connection
	var direct_epoch:=direct_generation
	var static_rows:=RawWorldDeltas.StaticRows.new(true)
	var data: Dictionary=_direct_world_projection(false,static_rows)
	if data.has("error"):return {"error":str(data.error)}
	var metadata: Array=owner.world_projection_metadata() if not delivery_scope.is_empty() else []
	var scene=world
	var area_id:=int(data.get("area",{}).get("id",-1))
	var expected_ids: Array=[]
	for object in data.get("objects",[]):
		if object is Dictionary and int(object.get("areaId",-1))==area_id and not bool(object.get("replicationRemoved",false)):expected_ids.append(int(object.get("id",-1)))
	var admission:=_direct_accept_projection(data,static_rows,direct_world_ready)
	data={}
	static_rows=null
	if admission.has("error"):return admission
	if admission.get("stale",false) or raw_serial<1:return {"error":"Native scene snapshot was not accepted for preparation"}
	var requested_serial:=raw_serial
	var generation:=int(scene.generation)
	if not delivery_scope.is_empty() and admission.get("changed",false) and int(admission.get("serial",-1))==requested_serial:
		var current:=_direct_immediate_ack_current.bind(owner,scene,connection,direct_epoch,generation,requested_serial)
		if current.call():
			owner.acknowledge_immediate_world_projection(delivery_scope,metadata,current,_direct_repeat_accepted_projection)
	var scoped_batches: Array=[]
	var committed:=false
	while is_instance_valid(scene) and is_same(world,scene) and int(scene.generation)==generation and not direct_scene_closed():
		if raw_serial>requested_serial:
			requested_serial=raw_serial
			committed=false
			scoped_batches.clear()
			var ids_began:=FrameProfile.begin()
			var refreshed_ids: Variant=_direct_scene_expected_ids(area_id)
			FrameProfile.finish("direct_scene_expected_ids_ms",ids_began)
			FrameProfile.count("count_direct_scene_expected_id_refreshes",1)
			if refreshed_ids is Dictionary:return refreshed_ids
			expected_ids=refreshed_ids
		if accepted_raw_serial>=requested_serial and direct_raw_deltas.pending.is_empty() and not direct_raw_refresh_pending and not snapshot_commit_running and pending_prepared_snapshot.is_empty() and entry_snapshot_commit.is_empty() and not scene.received_snapshot_active():
			var readiness_began:=FrameProfile.begin()
			if not committed:
				committed=true
				scoped_batches=scene.batches.duplicate()
			var pending_visual:=false
			for id in expected_ids:
				if not scene.desired.has(id):continue
				# The old sync reports a failed object and continues the current pass.
				if scene.failed_objects.has(id) or scene.base_scenery_omitted.has(id):continue
				if not scene.hidden.has(id):
					if not scene.instances.has(id) or str(scene.installed.get(id,""))!=str(scene.desired[id].key):
						pending_visual=true
						break
					if is_instance_valid(scene.references) and not scene.references.ready_for(scene.instances[id]):
						pending_visual=true
						break
			if not pending_visual:
				for batch in scoped_batches:
					if scene.batches.any(func(current):return is_same(current,batch)):
						pending_visual=true
						break
			FrameProfile.finish("direct_scene_readiness_ms",readiness_began)
			if not pending_visual:return true
		await process_frame
	return {"error":"Native scene changed during synchronization"}

func direct_scene_movement(events: Array)->Variant:
	if direct_scene_closed():return null
	var rows: Array[Dictionary]=direct_session.movement_from_presentation(events)
	if not rows.is_empty():
		var scene=world
		var pending: Array=direct_movement(rows)
		# NetworkScene.receiveMovementChanges returns the actor's running task.
		# A newer same-actor path shares it until the current admission settles.
		while not pending.is_empty() and is_instance_valid(scene) and is_same(world,scene) and not scene.closed and not scene.retiring:
			for index in range(pending.size()-1,-1,-1):
				var task: Dictionary=pending[index]
				if task.ticket.done:pending.remove_at(index)
			if not pending.is_empty():await process_frame
	return true

func direct_scene_animation(events: Array)->Variant:
	if direct_scene_closed() or not is_instance_valid(world):return null
	var delivered: Array=[]
	for event in events:
		if str(event.get("action","")) not in ["attack-animation","cast-animation"]:continue
		var actor: Variant=direct_scene_row(event.get("id"))
		if not actor is Dictionary:continue
		var row: Dictionary=event.duplicate(true)
		row.lifetime=int(actor.get("nativeLifetime",0))
		delivered.append(row)
	if not delivered.is_empty():world.receive_combat({"generation":world.generation,"areaId":world.area_id,"serial":int(world.combat.last_serial)+1,"events":CombatEventOrder.ordered(delivered)})
	return true

func direct_scene_visual(events: Array)->Variant:
	if direct_scene_closed() or direct_visual_presentation==null:return null
	var ticket=direct_visual_presentation.receive(events)
	return await ticket.wait_done()

func direct_scene_object_visual(message: Dictionary)->Variant:
	if direct_scene_closed() or direct_visual_presentation==null:return null
	var ticket=direct_visual_presentation.receive_instant(message)
	return await ticket.wait_done()

func direct_visual_view(id: int)->Variant:
	var actor: Variant=direct_scene_row(id)
	return actor if actor is Dictionary and not bool(actor.get("replicationRemoved",false)) and int(actor.get("areaId",-1))==direct_scene_area_id() else null

func direct_visual_report(code: String,reason: String,detail: Dictionary)->void:
	if direct_session!=null:direct_session.diagnostic_event.emit({"code":code,"reason":reason,"detail":detail.duplicate(true)})

func direct_visual_loop_add(actor: Variant,record: Dictionary)->int:
	if direct_scene_closed() or not actor is Dictionary or not is_instance_valid(world.effects):return 0
	var id:=int(actor.get("id",-1))
	if not is_instance_valid(world.effects.host(id)) and not (world.effects.last_render_position(id) is Vector3):
		direct_visual_report("network.visual-target-unavailable","Native visual target render binding is unavailable",{"objectId":id,"visualId":record.get("visualId")})
		return 0
	if not VisualPresentation.network_visual_identity(record.get("networkTransform")):
		direct_visual_report("network.visual-delivery-failed","Native network visual controller-map presentation is not connected",{"objectId":id,"visualId":record.get("visualId")})
		return 0
	var effect_id: int=world.effects.reserve(id,int(actor.get("nativeLifetime",0)),record,false,0,true)
	if effect_id<=0:return 0
	await world.effects.wait_effect_outcome(effect_id)
	return 1

func direct_visual_loop_remove(actor: Variant,visual_id: int)->int:
	if direct_scene_closed() or not actor is Dictionary or not is_instance_valid(world.effects):return 0
	var before:=int(world.effects.stats.get("removed",0))
	world.effects.route({"kind":"loop","id":int(actor.get("id",-1)),"lifetime":int(actor.get("nativeLifetime",0)),"changes":[{"action":"D","visualId":visual_id}]})
	return 1 if int(world.effects.stats.get("removed",0))>before else 0

func direct_visual_instant(message: Dictionary)->int:
	if direct_scene_closed() or int(message.get("nativeAreaId",-1))!=direct_scene_area_id() or not is_instance_valid(world.effects):return 0
	var effect_owner=world.effects
	var receipt_id: int=effect_owner.create_instant_receipt()
	var queued: Dictionary=message.duplicate(true)
	queued.nativeVisualReceiptId=receipt_id
	direct_object_visual(queued)
	var outcome: Dictionary=await effect_owner.wait_instant_receipt(receipt_id)
	if str(outcome.get("outcome",""))=="unavailable":direct_visual_report("network.visual-target-unavailable","Native visual target could not be resolved",{"visualId":message.get("visualId"),"objectId":message.get("targetId")})
	return 1 if str(outcome.get("outcome",""))=="routed" else 0

func direct_scene_projectile(message: Dictionary)->Variant:
	direct_projectile(message)
	return true

func direct_scene_area_visual(message: Dictionary)->Variant:
	if not direct_scene_closed() and is_instance_valid(world.effects):world.effects.create_area_visual(message)
	return true

func direct_scene_changes(events: Array)->void:
	if direct_scene_delivery==null or direct_scene_closed():return
	var delivery: RefCounted=direct_scene_delivery
	var scene=world
	var connection:=session_connection
	var generation:=direct_generation
	await delivery.updates(events)
	# Old main.js:2736 releases the transition only when this presentation
	# still owns the connection after its movement and ordered visual work.
	if not closing and is_same(direct_scene_delivery,delivery) and is_same(world,scene) and session_connection==connection and direct_generation==generation and renderer_transition_pending():finish_renderer_retirement()

func direct_scene_object_visual_received(message: Dictionary)->void:
	if direct_scene_delivery!=null and not direct_scene_closed():direct_scene_delivery.object_visual(message)
	else:direct_object_visual(message)

func direct_scene_projectile_received(message: Dictionary)->void:
	if direct_scene_delivery!=null and not direct_scene_closed():direct_scene_delivery.projectile(message)
	else:direct_projectile(message)

func direct_scene_area_visual_received(message: Dictionary)->void:
	if direct_scene_delivery!=null and not direct_scene_closed():direct_scene_delivery.area_visual(message)
	elif not closing and direct_session!=null and direct_session.phase=="playing" and is_instance_valid(world) and is_instance_valid(world.effects):world.effects.create_area_visual(message)

func direct_creature_voice(message: Dictionary)->void:
	if closing or direct_session==null or direct_graphics_failed_generation==direct_generation or direct_session.phase!="playing":return
	var id:=int(message.get("objectId",-1))
	var actor: Dictionary=direct_session.world_state.registry.get(id,{})
	if int(actor.get("objectType",0))!=5 or int(actor.get("areaId",-1))!=direct_session.world_state.area_id:return
	var lifetime:=int(actor.get("nativeLifetime",0))
	if lifetime<=0:return
	var voice_frame: Variant=message.get("nativeVoiceFrame")
	if voice_frame is Dictionary:
		if voice_frame.get("connection")!=session_connection or voice_frame.get("generation")!=direct_generation or voice_frame.get("areaId")!=direct_session.world_state.area_id or not voice_frame.get("events") is Array or voice_frame.events.size()!=1:return
		var captured: Variant=voice_frame.events[0]
		var appearance: Variant=actor.get("appearance")
		var soundset: int=int(appearance.get("field8A0",65535))&65535 if appearance is Dictionary else 65535
		if not captured is Dictionary or int(captured.get("lifetime",-1))!=lifetime or int(captured.get("soundsetId",-1))!=soundset:return
	if direct_voice_queue.size()>=128:
		report.direct_voice_overflow=int(report.get("direct_voice_overflow",0))+1
		return
	direct_voice_queue.append({"message":message.duplicate(true),"connection":session_connection,"generation":direct_generation,"areaId":direct_session.world_state.area_id,"objectId":id,"lifetime":lifetime})
	direct_drain_voices()

func direct_projectile(message: Dictionary)->void:
	if closing or direct_session==null or direct_graphics_failed_generation==direct_generation or int(message.get("nativeAreaId",-1))!=direct_session.world_state.area_id or int(message.get("nativeAreaGeneration",-1))!=direct_generation:return
	if direct_projectile_queue.size()>=128:
		report.direct_projectile_overflow=int(report.get("direct_projectile_overflow",0))+1
		return
	direct_projectile_queue.append({"connection":session_connection,"generation":direct_generation,"areaId":direct_session.world_state.area_id,"message":message.duplicate(true)})
	direct_drain_projectiles()

func direct_drain_projectiles()->void:
	if closing or direct_session==null or not is_instance_valid(world) or not is_instance_valid(world.effects) or not is_instance_valid(world.effects.projectiles):return
	if world.area_id!=direct_session.world_state.area_id:return
	for entry in direct_projectile_queue:
		if int(entry.connection)!=session_connection or int(entry.generation)!=direct_generation or int(entry.areaId)!=world.area_id:continue
		var message: Dictionary=entry.message
		var header: Dictionary=message.header
		var target_id:=int(header.targetId)
		var source_lifetime:=int(message.get("sourceLifetime",0))
		var target_lifetime:=int(message.get("targetLifetime",0))
		# The projectile adapter reports a present canonical replacement itself.
		# A removed source/target remains absent, as in ClientObjectArray.sync.
		var projectile_event:={"message":message,"id":target_id,"lifetime":target_lifetime,"sourceLifetime":source_lifetime,"receivedAtMs":int(message.get("receivedAtMs",Time.get_ticks_msec()))}
		if message.has("sourceRegistration"):projectile_event.sourceRegistration=message.sourceRegistration
		if message.has("targetRegistration"):projectile_event.targetRegistration=message.targetRegistration
		world.effects.projectiles.receive(projectile_event)
	direct_projectile_queue.clear()

func direct_drain_voices()->void:
	if closing or direct_session==null or not is_instance_valid(world) or not is_instance_valid(world.effects) or not is_instance_valid(gameplay_ui):return
	for entry in direct_voice_queue:
		if int(entry.connection)!=session_connection or int(entry.generation)!=direct_generation or int(entry.areaId)!=world.area_id:continue
		var id:=int(entry.objectId)
		var actor: Dictionary=direct_session.world_state.registry.get(id,{})
		if int(actor.get("objectType",0))!=5 or int(actor.get("areaId",-1))!=world.area_id or int(actor.get("nativeLifetime",0))!=int(entry.lifetime):continue
		var voice_frame: Variant=entry.message.get("nativeVoiceFrame")
		if voice_frame is Dictionary:
			var captured: Variant=voice_frame.events[0] if voice_frame.get("events") is Array and voice_frame.events.size()==1 else null
			var appearance: Variant=actor.get("appearance")
			var soundset: int=int(appearance.get("field8A0",65535))&65535 if appearance is Dictionary else 65535
			if not captured is Dictionary or int(captured.get("soundsetId",-1))!=soundset:continue
		world.effects.creature_voices.receive_network(entry.message,Callable(gameplay_ui,"receive_voice_caption"),session_connection)
	direct_voice_queue.clear()

func native_camera_follow_target_id()->int:
	if not is_instance_valid(world):return -1
	if direct_camera_target_id>=0 and world.instances.has(direct_camera_target_id) and world.desired.has(direct_camera_target_id) and int(world.desired[direct_camera_target_id].object.get("objectType",0)) in [5,9] and not bool(world.desired[direct_camera_target_id].object.get("replicationRemoved",false)):return direct_camera_target_id
	return world.controlled_id

func native_camera_follow_height(target_id: int)->float:
	if direct_session==null:return 1.0
	var object: Dictionary=direct_session.world_state.registry.get(target_id,{})
	var appearance: Variant=object.get("appearance")
	var index: Variant=appearance.get("appearance") if appearance is Dictionary else null
	if not index is int:return 1.0
	if not direct_camera_height_cache.has(index):direct_camera_height_cache[index]=CameraAppearanceHeight.from_table(object,direct_camera_appearance_table)
	return float(direct_camera_height_cache[index])

func native_camera_clear_view_facing(target_id: int)->float:
	if not is_instance_valid(world) or direct_session==null:return NAN
	var movement: Dictionary=world.motion.objects.get(target_id,{})
	var orientation: Variant=movement.get("orientation")
	var object: Dictionary=direct_session.world_state.registry.get(target_id,{})
	if orientation==null:
		var replicated: Variant=object.get("replicated",{})
		if replicated is Dictionary:orientation=replicated.get("orientation")
	if orientation==null:
		var static_state: Variant=object.get("staticState",{})
		if static_state is Dictionary:orientation=static_state.get("orientation")
	if orientation==null:
		var light_state: Variant=object.get("lightState",{})
		if light_state is Dictionary:orientation=light_state.get("orientation")
	if orientation is Dictionary:orientation=orientation.get("vector")
	if orientation is Vector3:
		return GameCameraState.mul(GameCameraState.f(atan2(-orientation.x,orientation.y)),GameCameraState.f(57.295776))
	if orientation is Array and orientation.size()>=2:
		return GameCameraState.mul(GameCameraState.f(atan2(-float(orientation[0]),float(orientation[1]))),GameCameraState.f(57.295776))
	if world.instances.has(target_id) and is_instance_valid(world.instances[target_id]):
		return rad_to_deg(world.instances[target_id].rotation.y)
	return NAN

func direct_camera_query_blocked(start: Array,finish: Array)->bool:
	return CameraSceneQuery.blocked(world,start,finish) if is_instance_valid(world) else false

func direct_camera_query_nearest(start: Array,finish: Array)->Variant:
	return CameraSceneQuery.nearest(world,start,finish) if is_instance_valid(world) else null

func native_camera_collision_context()->Dictionary:
	if not is_instance_valid(world) or not is_instance_valid(camera) or not world.instances.has(world.controlled_id):return {}
	var actor_instance: Node3D=world.instances[world.controlled_id]
	if not is_instance_valid(actor_instance):return {}
	var actor_position: Vector3=actor_instance.position
	var camera_position: Vector3=camera.position
	var eligible: bool=world.installed.has(world.controlled_id) and not world.hidden.has(world.controlled_id)
	return {"query":Callable(self,"direct_camera_query_nearest"),"position":[actor_position.x,-actor_position.z,actor_position.y],"cameraPosition":[camera_position.x,-camera_position.z,camera_position.y],"keyholeActive":is_instance_valid(keyhole) and keyhole.ready_for_camera() and eligible,"eligible":eligible}

func native_camera_clear_view_query()->Callable:
	return Callable(self,"direct_camera_query_blocked")

func direct_camera_command(message: Dictionary)->void:
	if closing or direct_session==null or direct_graphics_failed_generation==direct_generation:return
	if direct_camera_queue.size()>=128:fail("Native camera command queue exceeded bound");return
	var queued:=message.duplicate(true)
	queued.nativeReceivedMs=Time.get_ticks_msec()
	queued.nativeAreaId=direct_session.world_state.area_id
	if queued.kind=="camera-attach":
		var object: Dictionary=direct_session.world_state.registry.get(int(queued.objectId),{})
		if not object.is_empty():queued.nativeLifetime=object.get("nativeLifetime",object.get("clientKnownLifetime"))
	direct_camera_queue.append(queued)
	direct_camera_bind()

func direct_camera_attachment_unavailable(target_id: int)->void:
	if direct_session==null:return
	var event: Dictionary={"code":"network.camera-attachment-unavailable","reason":"Camera attachment target has no current supported render object","objectId":target_id}
	direct_session.diagnostic_event.emit(event)
	direct_session.diagnostic.emit(str(event.code),str(event.reason))

func direct_camera_bind()->void:
	if closing or direct_session==null or not is_instance_valid(world) or not is_instance_valid(controller) or controller.follow_state==null:return
	if direct_camera_state==null:
		direct_camera_state=controller.follow_state
		if is_instance_valid(render_settings):direct_camera_state.set_mode(render_settings.camera_mode)
	elif controller.follow_state!=direct_camera_state:controller.enable_follow(int(direct_camera_state.state.mode),controller.target,float(controller.follow_height) if is_finite(float(controller.follow_height)) else 1.0,{},direct_camera_state)
	direct_camera_state.state.modeAppearanceHeight=native_camera_follow_height(world.controlled_id)
	if direct_camera_target_id>=0 and (not world.desired.has(direct_camera_target_id) or not world.instances.has(direct_camera_target_id) or bool(world.desired.get(direct_camera_target_id,{}).get("object",{}).get("replicationRemoved",false))):
		direct_camera_target_id=-1
		if world.instances.has(world.controlled_id):
			var home: Vector3=world.instances[world.controlled_id].global_position
			direct_camera_state.attach([home.x,-home.z,home.y],native_camera_follow_height(world.controlled_id),true,false)
	while not direct_camera_queue.is_empty():
		var command: Dictionary=direct_camera_queue[0]
		var accepted:=false
		if command.kind=="camera-attach":
			var target:=int(command.objectId)
			var object: Dictionary=direct_session.world_state.registry.get(target,{})
			if int(command.nativeAreaId)!=world.area_id or object.is_empty() or bool(object.get("replicationRemoved",false)) or int(object.get("areaId",-1))!=world.area_id or int(object.get("objectType",0)) not in [5,9] or command.has("nativeLifetime") and object.get("nativeLifetime",object.get("clientKnownLifetime"))!=command.nativeLifetime:
				direct_camera_attachment_unavailable(target)
				direct_camera_queue.pop_front()
				continue
			if not world.instances.has(target) or not is_instance_valid(world.instances[target]):
				direct_camera_attachment_unavailable(target)
				direct_camera_queue.pop_front()
				report.direct_camera_unresolved=int(report.get("direct_camera_unresolved",0))+1
				continue
			var position: Vector3=world.instances[target].global_position
			direct_camera_state.attach([position.x,-position.z,position.y],native_camera_follow_height(target),int(object.objectType)==5,bool(command.findClearView))
			direct_camera_target_id=-1 if target==world.controlled_id else target
			direct_camera_pending_entry_attach=false
			accepted=true
		else:
			if command.kind=="camera-flags" and (int(command.get("flags",0)) & ~115)!=0:
				var flags:=int(command.flags)
				var diagnostic_event: Dictionary={"code":"network.camera-flags-partial","reason":"Camera flag storage is applied; translation/effect and other behavior bits are not yet connected","flags":flags,"unsupportedBits":(flags & ~115) & 0xffffffff}
				direct_session.diagnostic_event.emit(diagnostic_event)
				direct_session.diagnostic.emit(str(diagnostic_event.code),str(diagnostic_event.reason))
			accepted=direct_camera_state.apply_command(command)
		direct_camera_queue.pop_front()
		if not accepted:report.direct_camera_rejected=int(report.get("direct_camera_rejected",0))+1
	# The provisional area anchor can precede publication of the PC render
	# object. The original pending entry attach waits for that binding, then
	# performs one clear-view self-attach; it is separate from received 16/10.
	if direct_camera_pending_entry_attach and entry_camera.anchored and world.instances.has(world.controlled_id) and is_instance_valid(world.instances[world.controlled_id]):
		var controlled: Dictionary=direct_session.world_state.registry.get(world.controlled_id,{})
		if int(controlled.get("objectType",0))==5 and int(controlled.get("areaId",-1))==world.area_id and not bool(controlled.get("replicationRemoved",false)):
			var position: Vector3=world.instances[world.controlled_id].global_position
			direct_camera_state.attach([position.x,-position.z,position.y],native_camera_follow_height(world.controlled_id),true,true)
			direct_camera_target_id=-1
			direct_camera_pending_entry_attach=false

func direct_nwsync_visual_validate()->bool:
	var descriptor:=direct_nwsync_visual_descriptor
	var manifest: Dictionary=direct_session.content_store.manifest(str(descriptor.manifestHash))
	if manifest.has("error") or manifest.get("entries",{}).size()!=13:fail("Private NWSync visual manifest was not mounted after admission");return false
	var verified:=0
	var icon_image: Image
	var icon_pixel:=false
	for authored in descriptor.entries:
		var name:=str(authored.get("name",""));var type:=int(authored.get("type",-1));var key:=name+":"+str(type)
		if not manifest.entries.has(key):fail("Private NWSync visual resource is absent from admitted manifest: "+key);return false
		var entry: Dictionary=manifest.entries[key]
		if str(entry.get("hash",""))!=str(authored.hash) or int(entry.get("size",-1))!=int(authored.size):fail("Private NWSync visual identity differs from admitted manifest: "+key);return false
		var binding: Dictionary=catalog.location(name,type)
		if binding.is_empty() or str(binding.get("layer",{}).get("kind",""))!="nwsync":fail("Private NWSync visual resource was not bound to mounted catalog: "+key);return false
		var bytes: PackedByteArray=catalog.read_resource(name,type)
		if bytes.size()!=int(authored.size) or NWSyncStore.sha1(bytes)!=str(authored.hash):fail("Private NWSync visual mounted bytes or digest differ: "+key);return false
		verified+=1
		if name==str(descriptor.get("visualTextureName","gd_sync_icon")):
			icon_image=Image.new()
			if icon_image.load_tga_from_buffer(bytes)!=OK or icon_image.get_size()!=Vector2i(16,16):fail("Private NWSync visual TGA did not decode from mounted bytes");return false
			var pixel:=icon_image.get_pixel(0,0)
			icon_pixel=absf(pixel.r-240.0/255.0)<0.001 and absf(pixel.g-170.0/255.0)<0.001 and absf(pixel.b-20.0/255.0)<0.001 and absf(pixel.a-1.0)<0.001
	if verified!=13 or not icon_pixel:fail("Private NWSync visual cohort was incomplete after admission");return false
	var progress:=direct_nwsync_visual_progress.duplicate(true)
	var content:=progress.filter(func(row: Dictionary):return row.phase=="server-content")
	var phase:=str(args.get("direct-nwsync-visual-phase","cold"))
	if phase=="cold":
		var intermediate:=content.any(func(row: Dictionary):return int(row.total)==13 and int(row.completed)>0 and int(row.completed)<13)
		var complete:=content.any(func(row: Dictionary):return int(row.total)==13 and int(row.completed)==13)
		var play_gated:=not content.any(func(row: Dictionary):return int(row.total)==13 and (not bool(row.playGated) or bool(row.playVisible)))
		var cancel_visible:=not content.any(func(row: Dictionary):return int(row.total)==13 and not bool(row.cancelVisible))
		report.direct_nwsync_visual_progress=progress
		report.direct_nwsync_visual_predicates={"intermediate":intermediate,"complete":complete,"playGated":play_gated,"cancelVisible":cancel_visible,"cancelOwner":"native-wait-cancel"}
		if not intermediate or not complete or not play_gated or not cancel_visible:fail("Private NWSync visual lobby progress did not gate Play and expose Cancel through 13 resources");return false
	var native_wait_visible: bool=is_instance_valid(character_lobby.native_wait) and character_lobby.native_wait.is_visible_in_tree()
	var native_cancel_visible: bool=is_instance_valid(character_lobby.native_wait_cancel) and character_lobby.native_wait_cancel.is_visible_in_tree()
	var controls_retired: bool=not native_wait_visible and not native_cancel_visible and not character_lobby.panel.is_visible_in_tree()
	report.direct_nwsync_visual_lobby_after={"phase":str(character_lobby.state.get("phase","")),"panelVisible":character_lobby.panel.is_visible_in_tree(),"nativeWaitVisible":native_wait_visible,"nativeCancelVisible":native_cancel_visible}
	var prior_state:=JSON.stringify(character_lobby.state)
	var prior_visible: bool=character_lobby.panel.visible
	direct_resource_progress({"phase":"server-content","completed":1,"total":99,"downloadedBytes":0})
	var stale_ignored: bool=prior_state==JSON.stringify(character_lobby.state) and prior_visible==character_lobby.panel.visible
	var settings_unchanged:=FileAccess.get_sha256(direct_nwsync_visual_settings_path)==direct_nwsync_visual_settings_hash
	report.direct_nwsync_visual_check={"progress":progress,"resourcesVerified":verified,"iconDecoded":icon_image!=null,"iconPixel":icon_pixel,"lobbyControlsRetired":controls_retired,"staleProgressIgnored":stale_ignored,"settingsUnchanged":settings_unchanged,"worldReady":world.ready_for_control(),"visualCapture":null,"phase":phase}
	if not controls_retired or not stale_ignored or not settings_unchanged or not bool(report.direct_nwsync_visual_check.worldReady):fail("Private NWSync visual post-admission state check failed");return false
	if DisplayServer.get_name()=="headless":direct_nwsync_visual_stage=2;return true
	if args.get("direct-nwsync-world-material-check","")=="true":direct_nwsync_visual_stage=2;return true
	var layer:=CanvasLayer.new();layer.layer=120;host.add_child(layer)
	var image_view:=TextureRect.new();image_view.position=Vector2(20,20);image_view.size=Vector2(128,128);image_view.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;image_view.texture=ImageTexture.create_from_image(icon_image);layer.add_child(image_view)
	direct_nwsync_visual_stage=1
	direct_nwsync_visual_capture.call_deferred()
	return true

func direct_nwsync_visual_capture()->void:
	await process_frame
	await process_frame
	if closing or direct_nwsync_visual_stage!=1:return
	var capture_path:=str(args.get("report","")).trim_suffix(".json")+".png"
	if capture_path.is_empty() or root.get_texture().get_image().save_png(capture_path)!=OK:fail("Private NWSync visual overlay frame could not be captured");return
	report.direct_nwsync_visual_check.visualCapture=capture_path
	direct_nwsync_visual_stage=2

func direct_nwsync_world_tile_published(index: int,model: Node3D)->void:
	if not direct_nwsync_world_material.is_empty() or not direct_nwsync_world_error.is_empty() or not is_instance_valid(world) or not is_instance_valid(world.terrain):return
	var terrain: Node=world.terrain
	if index<0 or index>=terrain.definition.get("tiles",[]).size():return
	var model_name:=str(terrain.definition.tiles[index].get("model","")).to_lower()
	if model_name!="ttr01_g01_01":return
	var texture_name:=str(args.get("direct-nwsync-world-material-name","")).to_lower()
	if texture_name.is_empty():direct_nwsync_world_error="Private world texture name was not supplied";return
	var bundle: Dictionary=terrain.bundles.get(str(terrain.definition.tiles[index].model),{})
	var raster: Dictionary=bundle.get("textures",{}).get(texture_name,{})
	var digest:=str(raster.get("sha256",""))
	var dependency_digest:=""
	for dependency in bundle.get("dependencies",[]):
		if str(dependency.get("name","")).to_lower()==texture_name and dependency.has("sha256"):dependency_digest=str(dependency.sha256);break
	if digest.is_empty() or digest!=dependency_digest:direct_nwsync_world_error="Prepared tile texture dependency identity is unavailable";return
	var selected: Dictionary=catalog.raster_location(texture_name)
	var binding: Dictionary=catalog.location(texture_name,int(selected.get("type",-1))) if not selected.is_empty() else {}
	if binding.is_empty():direct_nwsync_world_error="Published tile texture has no catalog binding";return
	for mesh in model.get("meshes"):
		if not mesh is MeshInstance3D or not is_instance_valid(mesh):continue
		var source: Dictionary=mesh.get_meta("native_mesh_source",{})
		if str(source.get("texture_name","")).to_lower()!=texture_name or not bool(source.get("parsed_render",false)):continue
		var material: Material=mesh.material_override
		var bound: Variant=null
		if material is ShaderMaterial:bound=material.get_shader_parameter("native_texture")
		elif material is StandardMaterial3D:bound=material.albedo_texture
		var verified: bool=bound is Texture2D and render_pool.textures.has(digest) and is_same(bound,render_pool.textures[digest])
		direct_nwsync_world_material={"model":model_name,"textureName":texture_name,"textureType":int(selected.type),"sourceKind":str(binding.layer.get("kind","")),"textureSha256":digest,"boundMaterial":verified,"tileIndex":index,"meshPart":str(source.get("part_name","")),"area":world.area_id,"generation":direct_generation}
		if not verified:direct_nwsync_world_error="Published tile material did not bind its prepared texture"
		return
	direct_nwsync_world_error="Published target tile has no render mesh using its expected texture"

func direct_nwsync_world_validate()->bool:
	if not direct_nwsync_world_error.is_empty():fail("Private NWSync world material check: "+direct_nwsync_world_error);return false
	if direct_nwsync_world_material.is_empty():
		if is_instance_valid(world) and is_instance_valid(world.terrain) and world.terrain.done:fail("Private NWSync world target tile was not published")
		return false
	var expected:=str(args.get("direct-nwsync-world-material-name","")).to_lower()
	if direct_nwsync_world_material.textureName!=expected or not bool(direct_nwsync_world_material.boundMaterial):fail("Private NWSync world material identity differs from the published mesh");return false
	if not direct_nwsync_visual_descriptor.is_empty():
		if str(direct_nwsync_visual_descriptor.get("worldTextureName","")).to_lower()!=expected or direct_nwsync_world_material.sourceKind!="nwsync" or int(direct_nwsync_world_material.textureType)!=3:fail("Private NWSync world material did not select the advertised raster");return false
	var pose: Transform3D=camera.global_transform
	var q: Quaternion=pose.basis.get_rotation_quaternion()
	var receipt: Dictionary=direct_nwsync_world_material.duplicate(true)
	receipt.camera={"position":[snappedf(pose.origin.x,0.001),snappedf(pose.origin.y,0.001),snappedf(pose.origin.z,0.001)],"quaternion":[snappedf(q.x,0.001),snappedf(q.y,0.001),snappedf(q.z,0.001),snappedf(q.w,0.001)]}
	receipt.visualCapture=null
	report.direct_nwsync_world_check=receipt
	if DisplayServer.get_name()=="headless":direct_nwsync_world_stage=2;return true
	direct_nwsync_world_stage=1
	direct_nwsync_world_capture.call_deferred()
	return true

func direct_nwsync_world_capture()->void:
	await process_frame
	await process_frame
	if closing or direct_nwsync_world_stage!=1 or not is_instance_valid(world):return
	var capture_path:=str(args.get("report","")).trim_suffix(".json")+".png"
	if capture_path.is_empty() or root.get_texture().get_image().save_png(capture_path)!=OK:fail("Private NWSync world frame could not be captured");return
	report.direct_nwsync_world_check.visualCapture=capture_path
	if not direct_nwsync_visual_descriptor.is_empty():report.direct_nwsync_visual_check.visualCapture=capture_path
	direct_nwsync_world_stage=2

func direct_ambient_command(message: Dictionary)->void:
	if closing or direct_session==null or direct_graphics_failed_generation==direct_generation:return
	var area_id: int=direct_session.world_state.area_id
	if area_id<0x80000000:return
	if is_instance_valid(direct_ambient_audio) and int(direct_ambient_audio.area_id)==area_id:
		direct_ambient_audio.receive(message)
		return
	direct_session.diagnostic_event.emit({"code":"network.ambient-owner-unavailable","reason":"Area audio command has no active presentation owner","areaId":null,"operation":message.get("operation")})

func direct_ambient_time(changes: Dictionary)->void:
	if closing or direct_session==null or not changes.has("timeOfDay"):return
	if is_instance_valid(direct_ambient_audio) and int(direct_ambient_audio.area_id)==direct_session.world_state.area_id:
		direct_ambient_audio.day_night(int(changes.timeOfDay))

func direct_object_visual(message: Dictionary)->void:
	if closing or direct_session==null or direct_graphics_failed_generation==direct_generation or int(message.get("nativeAreaId",-1))!=direct_session.world_state.area_id:
		direct_finish_visual_receipt(message,"stale")
		return
	if direct_visual_queue.size()>=512:
		direct_finish_visual_receipt(message,"overflow")
		report.direct_visual_overflow=int(report.get("direct_visual_overflow",0))+1
		return
	direct_visual_queue.append(message.duplicate(true))
	direct_drain_visuals()

func direct_finish_visual_receipt(message: Dictionary,outcome: String)->void:
	var receipt_id:=int(message.get("nativeVisualReceiptId",0))
	if receipt_id>0 and is_instance_valid(world) and is_instance_valid(world.effects):world.effects.finish_instant_receipt(receipt_id,outcome)

func direct_finish_queued_visual_receipts(outcome: String)->void:
	for message in direct_visual_queue:direct_finish_visual_receipt(message,outcome)

func direct_drain_visuals()->void:
	if direct_session==null or not is_instance_valid(world) or not is_instance_valid(world.effects):return
	var waiting: Array[Dictionary]=[]
	for message in direct_visual_queue:
		if int(message.nativeAreaId)!=world.area_id:direct_finish_visual_receipt(message,"stale");continue
		var target:=int(message.targetId);var source:=int(message.get("sourceId",0x7f000000))
		var original_identity: Variant=message.get("nativeTargetIdentity")
		if original_identity!=null:
			var current: Dictionary=direct_session.world_state.registry.get(target,{})
			if current.get("nativeLifetime",current.get("clientKnownLifetime"))!=original_identity:direct_finish_visual_receipt(message,"stale");continue
		var original_source: Variant=message.get("nativeSourceIdentity")
		if original_source!=null:
			var current_source: Dictionary=direct_session.world_state.registry.get(source,{})
			if current_source.get("nativeLifetime",current_source.get("clientKnownLifetime"))!=original_source:direct_finish_visual_receipt(message,"stale");continue
		var target_row: Dictionary=world.desired.get(target,{})
		var source_row: Dictionary=world.desired.get(source,{})
		if target!=0x7f000000 and target_row.is_empty() and direct_session.world_state.registry.has(target):
			if int(message.get("nativeVisualReceiptId",0))>0:direct_finish_visual_receipt(message,"unavailable");continue
			waiting.append(message)
			continue
		var lifetime:=int(target_row.get("object",{}).get("nativeLifetime",0))
		var source_lifetime:=int(source_row.get("object",{}).get("nativeLifetime",0))
		world.effects.receive_raw({"serial":int(world.effects.last_serial)+1,"events":[{"kind":"instant","id":target,"lifetime":lifetime,"sourceLifetime":source_lifetime,"receiptId":int(message.get("nativeVisualReceiptId",0)),"message":message.duplicate(true)}]})
	direct_visual_queue=waiting

func gameplay_presentation_allowed()->bool:
	return not closing and direct_session!=null and direct_session.phase=="playing" and is_instance_valid(world) and (gameplay_ui.presentation_enabled or world.ready_for_control()) and not loading_screen.blocks_input()

func direct_creation_request(value: Dictionary)->void:
	if not is_instance_valid(gameplay_ui) or direct_session==null:return
	var creator=gameplay_ui.creator
	var connection:=int(value.get("connection",-1))
	var draft:=int(value.get("draft",-1))
	if connection!=session_connection or connection!=creator.connection or draft!=creator.draft_scope:return
	var kind:=str(value.get("kind",""))
	if kind=="native-creation-cancel":
		if not direct_session.character_uploaded and not direct_session.character_submission_pending:direct_lobby_state.creating=false
		direct_show_character_state.call_deferred()
		return
	var permitted: bool=direct_session.phase in ["character-selection","character-rejected"] and bool(direct_lobby_state.get("canCreate",false)) and bool(direct_lobby_state.get("connected",false))
	if kind=="native-creation-begin":
		permitted=permitted and not bool(direct_lobby_state.get("creating",false)) and direct_lobby_selectable()
		if permitted:
			direct_lobby_state.creating=true
			direct_show_character_state()
		creator.result({"operation":kind,"connection":connection,"draft":draft,"accepted":permitted,"text":"Character creation is unavailable for this connection."})
		if permitted and args.get("direct-server-vault-create-check","")=="true":report.direct_server_vault_create_check={"creatorOpened":true,"creatorSubmitted":false,"source19Sent":false,"worldAdmitted":false,"disconnectClean":false}
		return
	if kind!="native-creation-submit" or creator.phase!="waiting":return
	permitted=permitted and bool(direct_lobby_state.get("creating",false))
	var bytes:=Marshalls.base64_to_raw(str(value.get("data","")))
	var parser:=GffDocument.new()
	if permitted and bytes.size()>=4 and bytes.size()<=Characters.MAX_CHARACTER_BYTES and bytes.slice(0,4).get_string_from_ascii()=="BIC ":parser.parse(bytes,"BIC ")
	else:parser.failure="Invalid character data"
	var accepted: bool=false
	var save_error:=""
	if parser.failure.is_empty():
		# The old createOnly frontend persisted its BIC before submitting it to
		# a server, including when that server disallowed local-vault play.
		var saved: Dictionary={"error":"The Godot character vault is unavailable."} if direct_session.character_vault==null else direct_session.character_vault.store({"data":bytes},"",true)
		if saved.get("ready",false):accepted=await direct_session.play_local_character(bytes,true)
		else:save_error=str(saved.get("error","The created character could not be saved."))
	bytes.fill(0)
	creator.result({"operation":kind,"connection":connection,"draft":draft,"accepted":accepted,"text":save_error if not save_error.is_empty() else "The new character could not be submitted. Review its details and try again."})
	if not accepted:return
	report.direct_creation={"source19Sent":true,"connection":connection,"draft":draft}
	if args.get("direct-server-vault-create-check","")=="true":
		report.direct_server_vault_create_check.creatorSubmitted=true
		report.direct_server_vault_create_check.source19Sent=true
	direct_lobby_state.busy=true;direct_lobby_state.canCreate=false
	direct_show_character_state()

func direct_keyboard_reset()->void:
	direct_keyboard_generation+=1
func direct_keyboard_current(entry: Dictionary)->bool:
	return not closing and direct_keyboard_generation==int(entry.queueGeneration) and direct_session==entry.session and session_connection==int(entry.connection) and epoch==int(entry.generation) and is_instance_valid(world) and world.area_id==int(entry.areaId) and str(keyboard_context().get("identity",""))==str(entry.identity)
func direct_keyboard_command(value: Dictionary)->void:
	var identity:=str(value.get("_directKeyboardIdentity",""))
	if identity.is_empty():return
	var entry: Dictionary={"connection":session_connection,"generation":epoch,"areaId":int(value.areaId),"identity":identity,"session":direct_session,"queueGeneration":direct_keyboard_generation}
	if not direct_keyboard_current(entry):return
	var outcome: Dictionary=await entry.session.keyboard_move(int(value.get("actorId",-1)),str(value.get("operation","")),value.get("position",[]),int(value.get("heading",0)),int(value.get("flags",0)),bool(value.get("transmit",true)))
	if not direct_keyboard_current(entry):return
	if outcome.has("error"):
		if is_instance_valid(keyboard):keyboard.request_failed(str(outcome.error))
		return
	if str(value.get("operation",""))=="drive" and outcome.has("sequence") and is_instance_valid(keyboard):
		keyboard.result({"actorId":value.get("actorId"),"lifetime":value.get("lifetime"),"requestId":value.get("requestId"),"sequence":outcome.sequence,"sent":outcome.get("sent",false)})
func send(value: Dictionary)->void:
	if str(value.get("kind",""))=="raw-world-accepted":
		if value.has("connection") and value.connection!=session_connection:return
		if direct_raw_deltas.acknowledge(session_connection,value.get("generation"),value.get("serial")) and direct_raw_refresh_pending:
			direct_refresh_world_after_ack.call_deferred(session_connection,direct_generation)
		return
	if direct_login_profiles!=null and direct_login_profiles.handle(value):return
	var kind:=str(value.get("kind",""))
	# The old NativeCommandPump lets handshake, browser and lobby controls
	# interrupt a pending game request. They have separate Godot UI owners.
	if kind in ["hello","browser-input","login-profile-input","browser-observed","finished"] or kind.begins_with("lobby-"):
		direct_game_command(value)
		return
	if closing or direct_session==null:return
	var queued: Dictionary=value.duplicate(true)
	if kind=="drive":queued._directKeyboardIdentity=str(keyboard_context().get("identity",""))
	direct_command_queue.append({"value":queued,"session":direct_session,"connection":session_connection})
	if not direct_command_running:direct_command_drain()

func direct_command_drain()->void:
	if direct_command_running:return
	direct_command_running=true
	while not direct_command_queue.is_empty():
		var entry: Dictionary=direct_command_queue.pop_front()
		if closing or direct_session!=entry.session or session_connection!=int(entry.connection):continue
		await direct_game_command(entry.value)
	direct_command_running=false

func direct_game_command(value: Dictionary)->void:
	if closing or direct_session==null:return
	var kind:=str(value.get("kind",""))
	if kind.begins_with("native-creation-"):await direct_creation_request(value);return
	if kind=="creation-proof" and (args.get("direct-server-vault-create-check","")=="true" or args.get("direct-server-vault-reconnect-check","")=="true"):
		report.creationProof=value.duplicate(true)
		if not bool(value.get("success",false)):fail("Private source character creation probe failed before admission");return
		var expected: Dictionary=value.get("expected",{}) if value.get("expected",{}) is Dictionary else {}
		var fingerprint: String=(str(expected.get("firstName",""))+"\u0000"+str(expected.get("lastName",""))).sha256_text()
		if args.get("direct-server-vault-create-check","")=="true":report.direct_server_vault_create_check.characterFingerprint=fingerprint
		else:
			report.direct_server_vault_reconnect_check.characterFingerprint=fingerprint
			report.direct_server_vault_reconnect_check.serverRowMatched=bool(value.get("reconnectSelection",{}).get("success",false))
		return
	if kind=="area-ready":
		if direct_session.phase=="area-presenting" and is_instance_valid(world) and int(value.get("generation",-1))==direct_generation and int(value.get("areaId",-1))==world.area_id and world.area_id==direct_session.world_state.area_id:
			var ready_session: Node=direct_session
			var ready_world: Node=world
			var ready_connection:=session_connection
			var ready_generation:=direct_generation
			# The old onArea graphics completion attaches area audio before its
			# areaReady request. Commands before this point have no active owner.
			if is_instance_valid(direct_ambient_audio):direct_ambient_audio.attach(ready_session.world_state.area,int(ready_session.world_state.time.get("timeOfDay",0)))
			if is_instance_valid(direct_placed_sounds) and is_instance_valid(ready_world.effects) and is_instance_valid(ready_world.effects.world_audio):direct_placed_sounds.attach(ready_session.world_state.area,ready_session.world_state.registry,ready_world.effects.world_audio)
			if not await ready_session.area_ready(ready_world):
				if closing or not is_same(direct_session,ready_session) or not is_same(world,ready_world) or session_connection!=ready_connection or direct_generation!=ready_generation:return
				# Old NetworkFrontend.receive only displayed a rejected areaReady
				# promise; it kept the connected session available for recovery.
				var reason:="Godot prepared-area acknowledgement failed"
				label.text=reason
				direct_lobby_state.error=reason
				direct_show_character_state()
				if direct_diagnostics!=null:direct_diagnostics.record("network.ui-failed",reason,{},"error")
		return
	if kind in ["observed","main-menu-observed","catalog-ready","finished","creation-native-phase"]:return
	if kind=="level-source-progress" and args.get("direct-headless-levelup-check","")=="true":
		report.direct_levelup_probe_progress={"phase":str(value.get("phase","")),"checks":int(value.get("checks",0)),"success":bool(value.get("success",false))}
		return
	if kind=="level-source-finished" and args.get("direct-headless-levelup-check","")=="true":
		direct_levelup_probe_finished={"success":bool(value.get("success",false)),"checks":int(value.get("checks",0)),"failures":value.get("failures",[])}
		return
	if direct_session.phase!="playing" or not is_instance_valid(world) or int(value.get("generation",epoch))!=epoch or int(value.get("areaId",world.area_id))!=world.area_id:return
	if kind=="drive":await direct_keyboard_command(value);return
	var outcome: Dictionary={}
	if kind in ["inventory-open","inventory-close","inventory-page"]:
		var owner_id:=int(value.get("ownerId",direct_session.world_state.local_object_id))
		var role:=str(value.get("inventoryRole","primary"))
		var window_serial:=int(value.get("windowSerial",-1))
		var receipt_serial:=int(value.get("inventoryReceipt",-1))
		match kind:
			"inventory-open":
				outcome=await direct_session.inventory_window(true,owner_id,role,window_serial,receipt_serial)
				if not outcome.has("error"):outcome=await direct_session.inventory_panel(int(value.get("page",0)),owner_id,role,window_serial,receipt_serial)
			"inventory-close":outcome=await direct_session.inventory_window(false,owner_id,role,window_serial,receipt_serial)
			"inventory-page":outcome=await direct_session.inventory_panel(int(value.get("page",0)),owner_id,role,window_serial,receipt_serial)
		direct_inventory_result(value,outcome)
		return
	match kind:
		"native-cancel-action":
			outcome=await direct_session.cancel_action(value)
			receive({"kind":"ui-protocol","connection":session_connection,"generation":epoch,"message":{"kind":"native-action-result","action":kind,"accepted":not outcome.has("error"),"result":outcome if not outcome.has("error") else {},"text":str(outcome.get("error",""))}})
			return
		"native-disengage":
			outcome=await direct_session.disengage(value)
			if outcome.has("error") and is_instance_valid(gameplay_ui):gameplay_ui.chat.append_message({"system":true,"text":str(outcome.error)})
			return
		"inventory-gold":
			outcome=await direct_session.transfer_gold(value)
			direct_inventory_result(value,outcome)
			return
		"native-rest":
			outcome=await direct_session.rest(value)
			if outcome.has("error") and is_instance_valid(gameplay_ui):gameplay_ui.chat.append_message({"system":true,"text":str(outcome.error)})
			return
		"native-prepare","native-cast","native-spell-like","native-feat","native-mode":
			var cast_feedback_scope:=direct_action_feedback_scope() if value.get("targetFeedbackRequestId")!=null and kind!="native-prepare" else {}
			match kind:
				"native-prepare":outcome=await direct_session.prepare_spell(value)
				"native-cast":outcome=await direct_session.cast_spell(value)
				"native-spell-like":outcome=await direct_session.cast_spell_like(value)
				"native-feat":outcome=await direct_session.use_feat(value)
				"native-mode":outcome=await direct_session.change_mode(value)
			if not cast_feedback_scope.is_empty():direct_target_feedback_result(kind,value,outcome,cast_feedback_scope)
			elif outcome.has("error"):receive({"kind":"ui-protocol","connection":session_connection,"generation":epoch,"message":{"kind":"native-action-result","action":kind,"accepted":false,"text":str(outcome.error)}})
			return
		"native-activity","native-skill":
			var input_connection:=session_connection
			var input_epoch:=epoch
			var input_area:=int(world.area_id)
			var input_actor:=int(direct_session.world_state.local_object_id)
			var input_session: Node=direct_session
			if kind=="native-activity":outcome=await input_session.activity_input(value)
			else:outcome=await input_session.skill_input(value)
			receive({"kind":"ui-protocol","connection":input_connection,"generation":input_epoch,"message":{"kind":"native-action-result","action":kind,"generation":input_epoch,"areaId":input_area,"actorId":input_actor,"accepted":not outcome.has("error"),"result":outcome if not outcome.has("error") else {},"text":str(outcome.get("error",""))}})
			return
		"native-item-ability":
			var item_feedback_scope:=direct_action_feedback_scope() if value.get("targetFeedbackRequestId")!=null else {}
			outcome=await direct_session.use_item(value)
			if not item_feedback_scope.is_empty():direct_target_feedback_result(kind,value,outcome,item_feedback_scope)
			elif outcome.has("error") and is_instance_valid(gameplay_ui):gameplay_ui.chat.append_message({"system":true,"text":str(outcome.error)})
			return
		"native-emote":
			outcome=await direct_session.play_emote(value)
			if outcome.has("error") and is_instance_valid(gameplay_ui):gameplay_ui.chat.append_message({"system":true,"text":str(outcome.error)})
			return
		"native-map":
			outcome=await direct_session.map_input(value)
			receive({"kind":"ui-protocol","connection":session_connection,"generation":epoch,"message":{"kind":"native-action-result","action":kind,"requestId":value.get("requestId"),"accepted":not outcome.has("error"),"result":outcome if not outcome.has("error") else {},"text":str(outcome.get("error",""))}})
			return
		"native-player-attitude","native-players","native-party","native-party-chat":
			match kind:
				"native-player-attitude":outcome=await direct_session.player_attitude(value)
				"native-players":outcome=await direct_session.player_list_input(value)
				"native-party":outcome=await direct_session.party_input(value)
				"native-party-chat":outcome=await direct_session.party_chat_input(value)
			receive({"kind":"ui-protocol","connection":session_connection,"generation":epoch,"message":{"kind":"native-action-result","action":kind,"requestId":value.get("requestId"),"accepted":not outcome.has("error"),"result":outcome if not outcome.has("error") else {},"text":str(outcome.get("error",""))}})
			return
		"native-panel":
			var panel_connection:=session_connection
			var panel_epoch:=epoch
			var panel_generation:=direct_generation
			var panel_area:=int(world.area_id)
			var panel_actor:=int(direct_session.world_state.local_object_id)
			var panel_session: Node=direct_session
			var panel_world: Node=world
			if str(value.get("panel","")) in ["blocked-attempt","context-attempt"]:
				outcome=await direct_session.gui_panel_input(value)
			else:outcome=await direct_session.hud_panel(value)
			if closing or direct_session==null or not is_same(direct_session,panel_session) or not is_same(world,panel_world) or session_connection!=panel_connection or epoch!=panel_epoch or direct_generation!=panel_generation or not is_instance_valid(world) or int(world.area_id)!=panel_area or int(direct_session.world_state.local_object_id)!=panel_actor:return
			receive({"kind":"ui-protocol","connection":panel_connection,"generation":panel_epoch,"message":{"kind":"native-action-result","action":"native-panel","panel":str(value.get("panel","")),"open":value.get("open"),"requestId":value.get("requestId"),"generation":panel_epoch,"areaId":panel_area,"actorId":panel_actor,"accepted":not outcome.has("error"),"text":str(outcome.get("error",""))}})
			return
		"native-script-target":
			var script_feedback_scope:=direct_action_feedback_scope() if value.get("targetFeedbackRequestId")!=null else {}
			outcome=await direct_session.script_target_input(value)
			if not script_feedback_scope.is_empty():direct_target_feedback_result(kind,value,outcome,script_feedback_scope)
			elif outcome.has("error"):receive({"kind":"ui-protocol","connection":session_connection,"generation":epoch,"message":{"kind":"native-action-result","action":"native-script-target","accepted":false,"text":str(outcome.error)}})
			return
		"inventory-container":
			if str(value.get("inventoryRole","primary"))!="primary":outcome={"error":"Alternate container navigation is unavailable"}
			else:outcome=await direct_session.container_input(str(value.get("operation","")),int(value.get("targetId",-1)),int(value.get("actorId",direct_session.world_state.local_object_id)))
			direct_inventory_result(value,outcome)
			return
		"walk":
			var walk_feedback_scope:=direct_action_feedback_scope() if value.get("walkPointerRequestId")!=null else {}
			var walk_feedback_position: Variant=value.get("position",[]).duplicate(true) if not walk_feedback_scope.is_empty() else []
			var walk_feedback_run:=bool(value.get("run",true))
			outcome=await direct_session.walk_to(value.get("position",[]),bool(value.get("run",true)))
			if not walk_feedback_scope.is_empty() and direct_action_feedback_current(walk_feedback_scope):
				receive({"kind":"ui-protocol","connection":walk_feedback_scope.connection,"generation":int(walk_feedback_scope.epoch),"message":{"kind":"native-action-result","action":"walk","walkPointerRequestId":value.get("walkPointerRequestId"),"generation":int(walk_feedback_scope.epoch),"areaId":int(walk_feedback_scope.areaId),"actorId":int(walk_feedback_scope.actorId),"accepted":not outcome.has("error"),"sequence":outcome.get("sequence"),"position":walk_feedback_position,"run":walk_feedback_run,"text":str(outcome.get("error",""))}})
			if args.get("direct-headless-local-smoke-check","")=="true" and direct_local_smoke_stage==0:direct_local_smoke_request={"requestAccepted":not outcome.has("error"),"requestTransmitted":outcome.has("sequence"),"sequence":int(outcome.get("sequence",-1)),"error":str(outcome.get("error",""))}
			if not walk_feedback_scope.is_empty():return
		"examine":
			var examine_connection:=session_connection
			var examine_epoch:=epoch
			var examine_generation:=direct_generation
			var examine_session=direct_session
			var store_examine:=str(value.get("inventoryExamineOrigin",""))=="store"
			outcome=await direct_session.target_action(int(value.get("targetId",-1)),"examine")
			if store_examine:
				if closing or direct_session==null or not is_same(direct_session,examine_session) or session_connection!=examine_connection or epoch!=examine_epoch or direct_generation!=examine_generation:return
				receive({"kind":"ui-protocol","connection":examine_connection,"generation":examine_epoch,"message":{"kind":"native-action-result","action":"examine","requestId":value.get("requestId"),"inventoryExamineOrigin":"store","inventoryGeneration":value.get("inventoryGeneration"),"storeGeneration":value.get("storeGeneration"),"targetId":value.get("targetId"),"accepted":not outcome.has("error"),"text":str(outcome.get("error",""))}})
				return
		"interact":
			var action_name:=str(value.get("action",""))
			var target_id:=int(value.get("targetId",-1))
			outcome=await direct_session.target_action(target_id,action_name,value.get("position",[]),bool(value.get("run",true)))
			if action_name.begins_with("door."):
				report.last_door_command={"id":target_id,"action":action_name,"generation":int(value.get("generation",-1)),"sent":bool(outcome.get("sent",false)),"error":str(outcome.get("error",""))}
		"item-action":
			outcome=await direct_session.item_action(value)
			direct_inventory_result(value,outcome)
			return
		"item-use":outcome=await direct_session.target_action(int(value.get("itemId",-1)),"object.use")
		"native-nui-input":
			var nui_owner: Node=gameplay_ui.nui if is_instance_valid(gameplay_ui) and is_instance_valid(gameplay_ui.nui) else null
			var nui_session: Node=direct_session
			outcome=await nui_session.nui_input(value)
			if is_instance_valid(nui_owner):nui_owner.complete_input(int(value.get("nuiRequestId",-1)),outcome)
			if outcome.has("error") and is_instance_valid(gameplay_ui):gameplay_ui.chat.append_message({"system":true,"text":str(outcome.error)})
			return
		"native-store":
			var store_connection:=session_connection
			var store_epoch:=epoch
			outcome=await direct_session.store_input(value)
			receive({"kind":"ui-protocol","connection":store_connection,"generation":store_epoch,"message":{"kind":"native-action-result","action":"native-store","accepted":not outcome.has("error"),"text":str(outcome.get("error","")),"requestId":value.get("requestId"),"storeGeneration":value.get("storeGeneration"),"operation":value.get("operation")}})
			return
		"native-barter":
			outcome=await direct_session.barter_input(value)
			if outcome.has("error"):receive({"kind":"ui-protocol","connection":session_connection,"generation":epoch,"message":{"kind":"native-action-result","action":"native-barter","accepted":false,"text":str(outcome.error)}})
			return
		"native-level-up":
			var level_reply_scope: Dictionary=LevelReplyScope.capture(value)
			outcome=await direct_session.level_up_input(value)
			if args.get("direct-headless-levelup-check","")=="true":direct_levelup_outbound.append({"operation":str(value.get("operation","")),"sent":not outcome.has("error")})
			if outcome.has("error"):
				var level_reply: Dictionary={"kind":"native-action-result","action":"native-level-up","operation":str(value.get("operation","")),"accepted":false,"text":str(outcome.error)}
				if level_reply_scope.get("value") is Dictionary:level_reply.levelRequest=level_reply_scope.value.duplicate(true)
				receive({"kind":"ui-protocol","connection":session_connection,"generation":epoch,"message":level_reply})
			return
		"native-quickbar-assign","native-quickbar-activate","native-quickchat","native-associate","native-possess","native-cancel-polymorph":
			var action_connection:=session_connection
			var action_epoch:=epoch
			var action_generation:=direct_generation
			var action_area:=int(world.area_id)
			var action_actor:=int(direct_session.world_state.local_object_id)
			var action_session=direct_session
			if kind=="native-quickbar-assign":outcome=await direct_session.quickbar_assign(value)
			elif kind=="native-quickbar-activate":outcome=await direct_session.quickbar_activate(value)
			else:outcome=await direct_session.simple_native_action(value)
			if closing or direct_session==null or not is_same(direct_session,action_session) or session_connection!=action_connection or epoch!=action_epoch or direct_generation!=action_generation or not is_instance_valid(world) or int(world.area_id)!=action_area or int(direct_session.world_state.local_object_id)!=action_actor:return
			var action_result: Dictionary={"kind":"native-action-result","action":kind,"accepted":not outcome.has("error"),"result":outcome if not outcome.has("error") else {},"text":str(outcome.get("error",""))}
			if kind=="native-quickbar-assign":
				action_result.quickbarRequestId=value.get("quickbarRequestId")
				action_result.index=int(value.get("index",-1))
				action_result.generation=action_epoch
				action_result.areaId=action_area
				action_result.actorId=action_actor
			receive({"kind":"ui-protocol","connection":action_connection,"generation":action_epoch,"message":action_result})
			return
		"chat":
			var chat_connection:=session_connection
			var chat_generation:=epoch
			var chat_area:=int(world.area_id)
			var chat_actor:=int(direct_session.world_state.local_object_id)
			var chat_request: Variant=value.get("requestId")
			outcome=await direct_session.chat(value)
			receive({"kind":"ui-protocol","connection":chat_connection,"generation":chat_generation,"message":{"kind":"native-action-result","action":"native-chat","requestId":chat_request,"generation":chat_generation,"areaId":chat_area,"actorId":chat_actor,"accepted":not outcome.has("error"),"text":str(outcome.get("error",""))}})
			return
		"reply":
			var reply_session: Node=direct_session
			var reply_connection:=session_connection
			var reply_epoch:=epoch
			outcome=await reply_session.reply_dialog(value)
			if closing or direct_session!=reply_session or session_connection!=reply_connection:return
			if str(outcome.get("error",""))=="Native dialog reply is stale or unavailable":
				var current: Dictionary=reply_session.current_dialog.duplicate(true)
				if current.is_empty():receive({"kind":"ui-protocol","connection":reply_connection,"generation":reply_epoch,"message":{"kind":"dialog-close"}})
				else:
					var replies: Variant=current.get("replies")
					current.erase("replies")
					receive({"kind":"ui-protocol","connection":reply_connection,"generation":reply_epoch,"message":current})
					if replies is Dictionary:receive({"kind":"ui-protocol","connection":reply_connection,"generation":reply_epoch,"message":replies})
			elif outcome.has("error"):receive({"kind":"ui-protocol","connection":reply_connection,"generation":reply_epoch,"message":{"kind":"dialog-error","entryId":int(value.get("entryId",-1)),"dialogGeneration":int(value.get("dialogGeneration",-1)),"reason":str(outcome.error)}})
			return
		_:return
	if outcome.has("error") and is_instance_valid(gameplay_ui):gameplay_ui.chat.append_message({"system":true,"text":str(outcome.error)})

func direct_inventory_result(request: Dictionary,outcome: Dictionary)->void:
	if direct_session==null:return
	var reply: Dictionary={"kind":"inventory-command-result","requestId":request.get("requestId"),"inventoryRole":str(request.get("inventoryRole","primary")),"ownerId":request.get("ownerId",direct_session.world_state.local_object_id),"windowSerial":request.get("windowSerial"),"accepted":not outcome.has("error")}
	if outcome.has("error"):reply.reason=str(outcome.error)
	if report.get("direct_inventory_commands") is Array:report.direct_inventory_commands.append({"kind":str(request.get("kind","")),"accepted":reply.accepted})
	receive({"kind":"ui-protocol","connection":session_connection,"generation":epoch,"message":reply})

func direct_action_feedback_scope()->Dictionary:
	if closing or direct_session==null or not is_instance_valid(world):return {}
	return {"connection":session_connection,"epoch":epoch,"generation":direct_generation,"areaId":int(world.area_id),"actorId":int(direct_session.world_state.local_object_id),"session":direct_session,"world":world}

func direct_action_feedback_current(scope: Dictionary)->bool:
	return not closing and direct_session!=null and is_instance_valid(world) and session_connection==scope.connection and epoch==int(scope.epoch) and direct_generation==int(scope.generation) and is_same(direct_session,scope.session) and is_same(world,scope.world) and int(world.area_id)==int(scope.areaId) and int(direct_session.world_state.local_object_id)==int(scope.actorId)

func direct_target_feedback_result(kind: String,request: Dictionary,outcome: Dictionary,scope: Dictionary)->void:
	# Only the spell-targeting UI requests an awaited success receipt. Its
	# former Promise continuation wrote feedback after the native call settled.
	if not direct_action_feedback_current(scope):return
	receive({"kind":"ui-protocol","connection":scope.connection,"generation":int(scope.epoch),"message":{"kind":"native-action-result","action":kind,"targetFeedbackRequestId":request.get("targetFeedbackRequestId"),"generation":int(scope.epoch),"areaId":int(scope.areaId),"actorId":int(scope.actorId),"accepted":not outcome.has("error"),"text":str(outcome.get("error",""))}})

func shutdown()->void:
	if closing:return
	if direct_mode and direct_session!=null and not direct_shutdown_export_complete and not direct_shutdown_after_export and not report.has("failure") and direct_session.character_vault!=null and direct_session.phase in ["playing","area-loading"] and DisplayServer.get_name()!="headless":
		direct_shutdown_after_export=true
		var export_session: Node=direct_session
		var requested: Dictionary=await export_session.request_character_export()
		if closing or direct_session!=export_session:return
		if requested.has("error"):direct_close_save_failed(str(requested.error))
		return
	if direct_shutdown_after_export and not report.has("failure"):return
	if direct_diagnostics!=null:
		if not direct_diagnostics.flush(false):report.runtime_diagnostic_save_failed=direct_diagnostics.storage_error
		if direct_diagnostic_reporting!=null:report.runtime_diagnostics=direct_diagnostic_reporting.status.duplicate(true)
		if direct_diagnostic_reporting!=null:direct_diagnostic_reporting.close();direct_diagnostic_reporting=null
		if direct_diagnostic_catalog!=null and direct_diagnostic_catalog.is_connected("recorded",Callable(self,"direct_catalog_diagnostic")):direct_diagnostic_catalog.disconnect("recorded",Callable(self,"direct_catalog_diagnostic"))
		direct_diagnostic_catalog=null
	direct_keyboard_reset()
	direct_retire_local_file()
	direct_retire_pending_preview()
	if is_instance_valid(direct_ambient_audio):direct_ambient_audio.close();direct_ambient_audio.queue_free();direct_ambient_audio=null
	if direct_directory!=null:direct_directory.close()
	if direct_login_profiles!=null:direct_login_profiles.close();direct_login_profiles=null
	if direct_session!=null:await direct_session.call("disconnect_session")
	if direct_session_failure_journal!=null:direct_session_failure_journal.settled()
	finish_acknowledged=true
	super.shutdown()
	if direct_diagnostics!=null:
		if not direct_diagnostics.flush(false):report.runtime_diagnostic_save_failed=direct_diagnostics.storage_error
		direct_diagnostics=null
	renderer_resource_retirement.report=Callable()

func application_exit_policy()->bool:
	return str(args.get("direct-headless-vault-policy-check","")) in ["server-only","local-allowed"] or super.application_exit_policy()
