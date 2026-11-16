extends "res://native_session_world.gd"
# Godot-owned original-server route through the existing renderer/UI. This is
# an explicit development entry until the remaining gameplay stream, browser,
# saved-key migration and acceptance matrix replace the transitional host.
const DirectSession=preload("res://systems/native_data/native_network_session.gd")
const Characters=preload("res://systems/native_data/native_server_characters.gd")
const GffDocument=preload("res://systems/native_data/gff_document.gd")
const CharacterPreview=preload("res://systems/native_data/character_preview.gd")
const ServerDirectory=preload("res://systems/native_data/native_server_directory.gd")
const LoginProfileController=preload("res://systems/native_data/godot_login_profile_controller.gd")
const ClientSettingsStore=preload("res://systems/native_data/client_settings_store.gd")
const BrowserStore=preload("res://systems/native_data/godot_server_browser_store.gd")
const ServerQuery=preload("res://systems/native_data/native_server_query.gd")
const PlacedSounds=preload("res://systems/native_data/native_placed_sounds.gd")
const AmbientAudio=preload("res://systems/native_data/native_ambient_audio_owner.gd")
const CharacterExportVault=preload("res://systems/native_data/native_character_export_vault.gd")
const NWSyncStore=preload("res://systems/native_data/nwsync_store.gd")
var direct_session: Node
var direct_placed_sounds
var direct_ambient_audio
var direct_ambient_queue: Array[Dictionary]=[]
var direct_visual_queue: Array[Dictionary]=[]
var direct_voice_queue: Array[Dictionary]=[]
var direct_login_profiles
var direct_upgrade_notice: String=""
var direct_browser_store
var direct_server_query: Node
var direct_inspect_endpoint: Dictionary={}
var direct_inspect_tab: String=""
var direct_inspect_result: Dictionary={}
var direct_observed_rows: Dictionary={}
var direct_browser_join_row: Dictionary={}
var direct_browser_join_name: String=""
var direct_server_port:=0
var selected_character: Dictionary={}
var direct_generation:=0
var direct_area_presented:=false
var direct_catalog_adopted:=false
var direct_quickbar_received:=false
var direct_check_deadline:=0
var local_character_pending:=false
var direct_lobby_choices: Dictionary={}
var direct_lobby_state: Dictionary={}
var direct_choice_request_id:=-1
var direct_manual_test_chosen:=false
var direct_manual_test_played:=false
var direct_started_from_browser:=false
var direct_browser_view_id:=0
var direct_browser_tab:="Direct"
var direct_browser_page:=0
var direct_browser_selected:=-1
var direct_browser_filter:=""
var direct_browser_sort:="Players"
var direct_browser_filters:={"local":true,"server":true,"password":true}
var direct_browser_busy:=false
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
var direct_travel_stage:=0
var direct_travel_deadline:=0
var direct_travel_origin:=-1
var direct_nwsync_cancel_pending:=false
var direct_portal_stage:=0
var direct_portal_origin_area:=-1
var direct_portal_origin_connection:=-1
var direct_camera_state
var direct_camera_queue: Array[Dictionary]=[]
var direct_camera_target_id:=-1
var direct_nwsync_visual_descriptor: Dictionary={}
var direct_nwsync_visual_progress: Array[Dictionary]=[]
var direct_nwsync_visual_settings_hash:=""
var direct_nwsync_visual_settings_path:=""
var direct_nwsync_visual_stage:=0
var direct_levelup_probe_started:=false
var direct_levelup_origin_level:=-1
var direct_levelup_events: Array[Dictionary]=[]
var direct_levelup_outbound: Array[Dictionary]=[]
var direct_levelup_probe_finished: Dictionary={}
var direct_disconnect_after_export:=false
var direct_character_export_stage:=0

func run()->void:
	super.run()
	if closing or not direct_mode or host==null:return
	interactive=true;report.interactive=true;report.direct_session=true
	direct_directory=ServerDirectory.new();host.add_child(direct_directory)
	direct_directory.completed.connect(direct_directory_ready)
	direct_server_query=ServerQuery.new();host.add_child(direct_server_query)
	direct_server_query.completed.connect(direct_server_query_ready)
	var install:=str(args.get("direct-install",ProjectSettings.globalize_path("res://../../FullDecomp/NwnRootInstall")))
	var startup: Dictionary=StartupPaths.resolve(install)
	if startup.has("error"):fail(str(startup.error));return
	var visual_path:=str(args.get("direct-nwsync-visual-fixture",""))
	if not visual_path.is_empty():
		if not visual_path.is_absolute_path() or not FileAccess.file_exists(visual_path):fail("Private NWSync visual descriptor is unavailable");return
		var visual_value: Variant=JSON.parse_string(FileAccess.get_file_as_string(visual_path))
		if not visual_value is Dictionary or str(visual_value.get("format",""))!="nwn79-private-nwsync-visual-v1" or not visual_value.get("entries") is Array or visual_value.entries.size()!=13:fail("Invalid private NWSync visual descriptor");return
		direct_nwsync_visual_descriptor=visual_value
		direct_nwsync_visual_settings_path=str(args.get("direct-settings",startup.settingsDirectory)).path_join("client-settings.json")
		if not FileAccess.file_exists(direct_nwsync_visual_settings_path):fail("Private NWSync visual check requires an existing isolated settings file");return
		direct_nwsync_visual_settings_hash=FileAccess.get_sha256(direct_nwsync_visual_settings_path)
	direct_login_profiles=LoginProfileController.new()
	if not direct_login_profiles.open(str(args.get("direct-settings",startup.settingsDirectory)),str(startup.defaultModsDirectory),session_connection,func(message: Dictionary):receive(message),func()->bool:return direct_session!=null, direct_profile_changed):
		fail("Godot login profiles could not open: "+direct_login_profiles.error);return
	if direct_login_profiles.legacy_upgrade.has("error"):
		direct_upgrade_notice=str(direct_login_profiles.legacy_upgrade.error)+". Enter a temporary CD key or save a new login profile to recover."
	elif bool(direct_login_profiles.legacy_upgrade.get("credentialReentryRequired",false)):
		direct_upgrade_notice="Previous saved CD keys must be entered again. Save a new key in Login Profiles or use a temporary key to connect."
	if bool(direct_login_profiles.legacy_upgrade.get("imported",false)):
		report.legacy_settings_import={"imported":true,"backup_created":true,"discarded_credentials":int(direct_login_profiles.legacy_upgrade.get("discardedCredentials",0))}
	direct_browser_store=BrowserStore.new()
	if not direct_browser_store.open(str(args.get("direct-settings",startup.settingsDirectory)).path_join("native-server-browser.json")):
		fail("Godot server browser could not open: "+direct_browser_store.error);return
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

func direct_connect(server_host: String,server_port: int,server_password: String="",temporary_cd_key: String="",player_name: String="",portal_handoff: Dictionary={})->void:
	var install:=str(args.get("direct-install",ProjectSettings.globalize_path("res://../../FullDecomp/NwnRootInstall")))
	var startup: Dictionary=StartupPaths.resolve(install)
	if startup.has("error"):
		if portal_handoff.get("identity") is RefCounted:portal_handoff.identity.dispose()
		fail(str(startup.error));return
	var profile:=str(args.get("direct-profile",startup.userDirectory))
	direct_server_port=server_port
	direct_camera_state=null;direct_camera_queue.clear();direct_camera_target_id=-1
	server_label=server_host;root.title="NWN · Godot direct · "+server_host
	direct_session=DirectSession.new();host.add_child(direct_session)
	direct_lobby_state={"phase":"connecting","endpoint":{"host":server_host,"port":server_port},"busy":true,"canCancelJoin":true,"connected":false}
	direct_show_character_state()
	character_lobby.show_sync_wait()
	if not is_instance_valid(direct_placed_sounds):
		direct_placed_sounds=PlacedSounds.new();host.add_child(direct_placed_sounds)
	direct_placed_sounds.configure(null,func()->Dictionary:return direct_session.world_state.time if direct_session!=null else {})
	direct_ambient_audio=AmbientAudio.new();host.add_child(direct_ambient_audio)
	direct_ambient_queue.clear()
	direct_voice_queue.clear()
	direct_session.catalog_ready.connect(direct_catalog_ready)
	direct_session.phase_changed.connect(direct_phase_changed)
	direct_session.resource_progress.connect(direct_resource_progress)
	direct_session.character_list_ready.connect(direct_character_list)
	direct_session.lobby_players_ready.connect(direct_lobby_players)
	direct_session.character_preview_ready.connect(direct_character_preview)
	direct_session.module_information_ready.connect(direct_module_ready)
	direct_session.area_state_ready.connect(direct_area_ready)
	direct_session.roster_message_ready.connect(func(_message: Dictionary):direct_present_area())
	direct_session.object_updates_ready.connect(func(message: Dictionary):
		if args.get("direct-headless-local-smoke-check","")=="true":
			for row in message.get("records",[]):
				if int(row.get("id",0))==int(direct_session.world_state.local_object_id) and row.get("state",{}).has("position"):direct_local_smoke_update_serial+=1
		direct_present_area())
	direct_session.movement_ready.connect(direct_movement)
	direct_session.world_presentation_ready.connect(direct_world_ready)
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
	direct_session.area_visual_ready.connect(func(message: Dictionary):
		if not closing and direct_session!=null and direct_session.phase=="playing" and is_instance_valid(world) and is_instance_valid(world.effects):world.effects.create_area_visual(message))
	direct_session.sound_object_ready.connect(func(message: Dictionary):
		if closing or direct_session==null or not is_instance_valid(direct_placed_sounds) or int(direct_placed_sounds.area.get("id",-1))!=direct_session.world_state.area_id:return
		var record: Dictionary=direct_session.world_state.registry.get(int(message.objectId),{})
		direct_placed_sounds.command(message,record))
	direct_session.ambient_command_ready.connect(direct_ambient_command)
	direct_session.time_changed.connect(direct_ambient_time)
	direct_session.object_visual_ready.connect(direct_object_visual)
	direct_session.camera_command_ready.connect(direct_camera_command)
	direct_session.creature_voice_ready.connect(direct_creature_voice)
	direct_session.character_export_status_ready.connect(direct_character_export_status)
	direct_session.portal_handoff_ready.connect(func(handoff: Dictionary):direct_portal_handoff.call_deferred(handoff))
	direct_session.quickbar_ready.connect(func(_message: Dictionary):direct_quickbar_received=true)
	direct_session.session_failed.connect(func(reason: String):
		if direct_started_from_browser:direct_connection_failed(reason)
		else:fail("Godot original-server session failed: "+reason))
	if not portal_handoff.is_empty() and not direct_session.configure_portal(portal_handoff.identity,portal_handoff.character,str(portal_handoff.waypoint)):
		if portal_handoff.get("identity") is RefCounted:portal_handoff.identity.dispose()
		fail("Portal destination character could not be prepared");return
	if not direct_session.start(server_host,server_port,profile,install,server_password,temporary_cd_key,player_name,str(args.get("direct-settings",""))):
		if not closing and not direct_started_from_browser:fail("Godot original-server session could not start: "+str(direct_session.error))
		return
	var saved: Dictionary=direct_session.saved_character_list()
	if saved.get("ready",false):direct_lobby_state.savedCharacters=saved.entries
	label.text="Connecting to "+server_host+" with Godot networking…"
	if args.get("direct-headless-check","")=="true":direct_check_deadline=Time.get_ticks_msec()+75000
	if args.get("direct-headless-levelup-check","")=="true":direct_check_deadline=Time.get_ticks_msec()+180000
	if args.get("direct-headless-local-smoke-check","")=="true":direct_check_deadline=Time.get_ticks_msec()+90000
	if args.get("direct-headless-character-export-check","")=="true":direct_check_deadline=Time.get_ticks_msec()+90000
	if args.get("direct-headless-portal-check","")=="true":direct_check_deadline=Time.get_ticks_msec()+120000
	if not direct_nwsync_visual_descriptor.is_empty():direct_check_deadline=Time.get_ticks_msec()+120000
	if args.get("direct-headless-nwsync-cancel-check","")=="true":direct_check_deadline=Time.get_ticks_msec()+30000

func direct_phase_changed(phase: String)->void:
	report.direct_status={"phase":phase,"catalog_adopted":direct_catalog_adopted,"area_presented":direct_area_presented,"generation":direct_generation,"snapshots":received}
	if closing or not is_instance_valid(character_lobby):return
	if phase in ["connecting","resources","loading-content"]:
		direct_lobby_state.phase="resources" if phase=="loading-content" else phase
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

func direct_resource_progress(stage: String,completed: int,total: int)->void:
	if closing or direct_session==null or direct_session.phase!="loading-content":return
	direct_lobby_state.phase="resources"
	direct_lobby_state.busy=true
	direct_lobby_state.canCancelJoin=true
	direct_lobby_state.resourceProgress={"phase":stage,"completed":completed,"total":total,"downloadedBytes":0}
	direct_show_character_state()
	character_lobby.show_sync_wait()
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
	report.direct_last_error=reason
	direct_visual_queue.clear();direct_ambient_queue.clear();direct_voice_queue.clear()
	if is_instance_valid(direct_placed_sounds):direct_placed_sounds.detach()
	if is_instance_valid(direct_ambient_audio):direct_ambient_audio.close();direct_ambient_audio.queue_free();direct_ambient_audio=null
	direct_browser_join_row.clear();direct_browser_join_name=""
	direct_lobby_choices.clear();direct_lobby_state.clear();selected_character.clear()
	direct_catalog_adopted=false;direct_area_presented=false;direct_quickbar_received=false
	if direct_session!=null:
		direct_session.close();direct_session.queue_free();direct_session=null
	character_lobby.apply_state({"connection":session_connection,"state":{"phase":"menu","canJoin":true}})
	character_lobby.panel.hide()
	server_browser.receive({"kind":"browser-notice","connection":session_connection,"text":reason})
	direct_browser_view(reason)

func direct_visible_rows()->Array[Dictionary]:
	var rows: Array[Dictionary]=[]
	var source: Array[Dictionary]=direct_directory_rows if direct_browser_tab=="Internet" else direct_browser_store.rows(direct_browser_tab) if direct_browser_store!=null else []
	for source_row in source:
		var row: Dictionary=source_row.duplicate(true)
		var key:=str(row.host)+":"+str(row.port)
		if direct_observed_rows.has(key):row.merge(direct_observed_rows[key],true)
		if not bool(direct_browser_filters.get("local",true)) and bool(row.get("allowLocalVaultCharacters",false)):continue
		if not bool(direct_browser_filters.get("server",true)) and not bool(row.get("allowLocalVaultCharacters",false)):continue
		if not bool(direct_browser_filters.get("password",true)) and bool(row.get("passwordRequired",false)):continue
		var needle:=direct_browser_filter.to_lower()
		if not needle.is_empty() and not (str(row.get("serverName","")).to_lower().contains(needle) or str(row.get("moduleName","")).to_lower().contains(needle) or str(row.get("host","")).to_lower().contains(needle)):continue
		rows.append(row)
	match direct_browser_sort:
		"Name":rows.sort_custom(func(a,b):return str(a.serverName).nocasecmp_to(str(b.serverName))<0)
		"Module":rows.sort_custom(func(a,b):return str(a.moduleName).nocasecmp_to(str(b.moduleName))<0)
		"Latency":rows.sort_custom(func(a,b):return int(a.get("latency",999999))<int(b.get("latency",999999)))
		_:rows.sort_custom(func(a,b):return int(a.get("playerCount",0))>int(b.get("playerCount",0)))
	return rows

func direct_browser_view(notice: String="",selection_ack: Dictionary={})->void:
	if not is_instance_valid(server_browser):return
	if notice.is_empty() and not direct_upgrade_notice.is_empty():notice=direct_upgrade_notice
	direct_browser_view_id+=1
	var profile: Dictionary=ticket.get("directProfile",{})
	var active_name:=str(profile.get("name",""))
	var active_login: Variant=null
	if direct_login_profiles!=null:
		var profile_status: Dictionary=direct_login_profiles.status()
		for row in profile_status.get("loginProfiles",[]):
			if row.id==profile_status.activeProfileId:active_login={"id":row.id,"label":row.label,"playerName":row.playerName};break
	var manual_name:=str(direct_browser_store.state.get("profileDefault","")) if direct_browser_store!=null else ""
	var browser_name:=active_name if not active_name.is_empty() else manual_name if not manual_name.is_empty() else str(direct_browser_store.state.get("last",{}).get("name","")) if direct_browser_store!=null else ""
	var last: Dictionary=direct_browser_store.state.get("last",{}) if direct_browser_store!=null else {}
	var all_rows: Array[Dictionary]=[]
	if direct_browser_tab in ["Internet","History","Favorites"]:all_rows=direct_visible_rows()
	var total:=all_rows.size();var pages:=maxi(1,ceili(float(total)/128.0))
	direct_browser_page=clampi(direct_browser_page,0,pages-1)
	var page_rows: Array[Dictionary]=[]
	for row in all_rows.slice(direct_browser_page*128,mini(total,(direct_browser_page+1)*128)):
		var visible: Dictionary=row.duplicate(true);visible.selected=int(row.entryId)==direct_browser_selected
		visible.favorite=false
		if direct_browser_store!=null:
			for favorite in direct_browser_store.state.favorites:
				if str(favorite.host)==str(row.host) and int(favorite.port)==int(row.port):visible.favorite=true;break
		page_rows.append(visible)
	var selected_row: Dictionary={}
	var source: Array[Dictionary]=direct_directory_rows if direct_browser_tab=="Internet" else direct_browser_store.rows(direct_browser_tab) if direct_browser_store!=null else []
	for row in source:
		if int(row.entryId)==direct_browser_selected:
			selected_row=row.duplicate(true)
			var key:=str(row.host)+":"+str(row.port)
			if direct_observed_rows.has(key):selected_row.merge(direct_observed_rows[key],true)
			break
	if direct_browser_tab=="Direct" and not direct_inspect_result.is_empty():selected_row=direct_inspect_result
	var view: Dictionary={"kind":"browser-view","connection":session_connection,"viewId":direct_browser_view_id,"reopen":true,"tab":direct_browser_tab,"busy":direct_browser_busy,"inspecting":not direct_inspect_endpoint.is_empty(),"canJoin":true,"canDiscover":true,"localOnly":false,"sourcePage":direct_browser_tab!="Direct","hasSavedCdKey":bool(profile.get("hasSavedCdKey",false)),"hasSessionProfile":not active_name.is_empty() or not manual_name.is_empty(),"activeLoginProfile":active_login,"direct":{"host":str(last.get("host","127.0.0.1")),"port":int(last.get("port",5121)),"name":browser_name},"rows":page_rows,"page":direct_browser_page,"pages":pages,"total":total,"filter":direct_browser_filter,"sort":direct_browser_sort,"filters":direct_browser_filters.duplicate(true),"status":notice,"details":selected_row if not selected_row.is_empty() else null}
	if not selection_ack.is_empty():view.selectionAck=selection_ack
	server_browser.receive(view)

func direct_server_query_ready(row: Dictionary,error: String)->void:
	var endpoint:=direct_inspect_endpoint.duplicate(true);var tab:=direct_inspect_tab
	direct_inspect_endpoint.clear();direct_inspect_tab="";direct_browser_busy=false
	if endpoint.is_empty() or tab!=direct_browser_tab or not is_instance_valid(server_browser) or not server_browser.wanted:return
	if error.is_empty():
		var key:=str(endpoint.host)+":"+str(endpoint.port)
		direct_observed_rows[key]=row.duplicate(true)
		direct_inspect_result=row.duplicate(true)
	direct_browser_view("Server information received" if error.is_empty() else error+" · You can still try Connect.")

func direct_profile_changed(status: Dictionary)->void:
	if direct_login_profiles.legacy_upgrade.has("error"):
		direct_upgrade_notice=str(direct_login_profiles.legacy_upgrade.error)+". Enter a temporary CD key or save a new login profile to recover."
	elif bool(direct_login_profiles.legacy_upgrade.get("credentialReentryRequired",false)):
		direct_upgrade_notice="Previous saved CD keys must be entered again. Save a new key in Login Profiles or use a temporary key to connect."
	else:direct_upgrade_notice=""
	var active_name: String=direct_login_profiles.active_player_name()
	ticket.directProfile={"name":active_name,"hasSavedCdKey":bool(status.get("hasSavedCdKey",false))}
	if ticket.get("preworkSources") is Dictionary:
		ticket.preworkSources.modsDirectory=str(status.get("modsDirectory",""))
		ticket.preworkSources.disabledMods=status.get("disabledMods",[]).duplicate()
	if is_instance_valid(server_browser) and server_browser.wanted:direct_browser_view("Active login profile updated.")

func direct_directory_ready(rows: Array[Dictionary],error: String)->void:
	direct_browser_busy=false
	if error.is_empty():direct_directory_rows=rows;direct_directory_loaded=true
	if is_instance_valid(server_browser) and server_browser.wanted and direct_browser_tab=="Internet":direct_browser_view(error if not error.is_empty() else str(rows.size())+" Internet servers found")

func direct_refresh_directory()->void:
	if direct_directory==null or direct_browser_busy:return
	direct_browser_busy=true
	direct_browser_view("Reading Internet server list…")
	direct_directory.refresh()

func browser_request(message: Dictionary)->void:
	if not direct_mode:super.browser_request(message);return
	if closing or not is_instance_valid(server_browser):return
	if str(message.get("operation","")) not in ["open","close"] and int(message.get("viewId",-1))!=server_browser.view_id:return
	match str(message.get("operation","")):
		"open":
			if direct_server_query!=null:direct_server_query.close()
			direct_inspect_endpoint.clear();direct_inspect_result.clear();direct_browser_busy=false
			var requested:=str(message.get("listTab",""))
			direct_browser_tab=requested if requested in ["Internet","History","Favorites"] else "Direct"
			direct_browser_view()
			if direct_browser_tab=="Internet" and not direct_directory_loaded:direct_refresh_directory()
		"close":
			if direct_server_query!=null:direct_server_query.close()
			direct_inspect_endpoint.clear();direct_inspect_result.clear();direct_browser_busy=false
		"tab":
			if direct_server_query!=null:direct_server_query.close()
			direct_inspect_endpoint.clear();direct_inspect_result.clear();direct_browser_busy=false
			var selected_tab:=str(message.get("tab",""))
			if selected_tab not in ["Direct","Internet","History","Favorites"]:return
			direct_browser_tab=selected_tab;direct_browser_page=0;direct_browser_selected=-1
			direct_browser_view()
			if selected_tab=="Internet" and not direct_directory_loaded:direct_refresh_directory()
		"refresh":
			if direct_browser_tab=="Internet":direct_refresh_directory()
		"filter":
			direct_browser_filter=str(message.get("filter","")).left(128)
			direct_browser_sort=str(message.get("sort","Players"))
			if direct_browser_sort not in ["Name","Module","Players","Latency"]:direct_browser_sort="Players"
			if message.get("filters") is Dictionary:direct_browser_filters=message.filters.duplicate(true)
			direct_browser_page=0;direct_browser_view()
		"page":direct_browser_page=maxi(0,int(message.get("page",0)));direct_browser_view()
		"select":
			var entry_id:=int(message.get("entryId",-1))
			var selected_row: Dictionary={}
			for row in direct_visible_rows():
				if int(row.entryId)==entry_id:selected_row=row;break
			if selected_row.is_empty():direct_browser_view("That server selection is no longer available.");return
			direct_browser_selected=entry_id
			direct_browser_view("",{"requestViewId":int(message.viewId),"host":selected_row.host,"port":selected_row.port})
		"profile":
			var values: Dictionary=message.get("values",{})
			var name:=str(values.get("name",""))
			var accepted: bool=direct_browser_store.valid_profile_name(name)
			if accepted and bool(values.get("saveDefault",false)):accepted=direct_browser_store.profile(name)
			if accepted:
				if not bool(values.get("saveDefault",false)):direct_browser_store.state.profileDefault=name
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
			direct_inspect_endpoint={"host":str(endpoint.get("host","")),"port":int(endpoint.get("port",0))}
			direct_inspect_tab=direct_browser_tab;direct_browser_busy=true
			direct_browser_view("Contacting server…")
			if not direct_server_query.query(str(direct_inspect_endpoint.host),int(direct_inspect_endpoint.port)) and not direct_inspect_endpoint.is_empty():
				direct_inspect_endpoint.clear();direct_browser_busy=false;direct_browser_view("Server information request failed")
		"join":
			if direct_session!=null:return
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
			if address.is_empty() or port<1 or port>65535:direct_browser_view("Enter a valid server address and UDP port.");return
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
			direct_connect(address,port,str(values.get("password","")),temporary_key,submitted_name)
			values.password=""
			temporary_key=""
		_:
			direct_browser_view("That server-list action has not yet been migrated to the Godot direct entry.")

func _profile_tick()->void:
	super._profile_tick()
	direct_camera_bind()
	if closing or direct_check_deadline<=0:return
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
			var outcome: Dictionary=direct_session.target_action(npc_id,"conversation.start")
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
	report.direct_headless_check={"area":world.area_id,"controlled":world.controlled_id,"snapshots":received,"objects":world.desired.size(),"quickbar":direct_session.world_state.quickbar.size(),"catalog_shared":is_same(catalog,direct_session.catalog),"ui_generation":gameplay_ui.generation if is_instance_valid(gameplay_ui) else -1}
	if args.get("direct-headless-manual-check","")=="true":
		report.direct_headless_check.manual_selected=direct_manual_test_chosen
		report.direct_headless_check.manual_played=direct_manual_test_played
		if not direct_manual_test_chosen or not direct_manual_test_played:fail("Godot chooser did not submit a selected local character");return
	if not bool(report.direct_headless_check.catalog_shared) or int(report.direct_headless_check.ui_generation)!=epoch:fail("Godot direct world and UI did not share the admitted session");return
	direct_check_deadline=0
	if args.get("direct-headless-reconnect-check","")=="true" and direct_reconnect_stage==0:
		report.direct_reconnect={"first_world":report.direct_headless_check.duplicate(true)}
		direct_reconnect_stage=1
		direct_disconnect()
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

func direct_portal_handoff(handoff: Dictionary)->void:
	var next_identity: RefCounted=handoff.get("identity")
	if closing or direct_session==null or direct_session.phase!="portal-ready" or next_identity==null:
		if next_identity!=null:next_identity.dispose()
		return
	var host_name:=str(handoff.get("host",""))
	var port_number:=int(handoff.get("port",0))
	var player_name:=str(handoff.get("playerName",""))
	var character: Dictionary=handoff.get("character",{})
	var source_port:=direct_server_port
	direct_disconnect(false)
	if closing:
		next_identity.dispose()
		return
	var old_retired:=direct_session==null and not is_instance_valid(world)
	report.direct_portal_check={"source_port":source_port,"destination_port":port_number,"character_kind":"bic" if character.has("data") else "reference","old_retired":old_retired,"destination_auth_started":false,"world_admitted":false}
	if not old_retired:
		next_identity.dispose()
		fail("Portal handoff retained the old world or session")
		return
	report.direct_portal_transfers=int(report.get("direct_portal_transfers",0))+1
	direct_connect(host_name,port_number,"","",player_name,handoff)
	if direct_session!=null:report.direct_portal_check.destination_auth_started=true

func request_disconnect(_save_character: bool)->void:
	if not direct_mode:super.request_disconnect(_save_character);return
	if _save_character:direct_save_then_disconnect()
	else:direct_disconnect()

func direct_save_then_disconnect()->void:
	if direct_session==null:return
	direct_disconnect_after_export=true
	var result: Dictionary=direct_session.request_character_export()
	if result.has("error"):
		direct_disconnect_after_export=false
		direct_character_export_status({"state":"failed","text":str(result.error),"uncertain":direct_session.character_export_uncertain})

func direct_character_export_status(status: Dictionary)->void:
	if closing or direct_session==null:return
	direct_lobby_state.exportStatus=status.duplicate(true)
	if str(status.get("state",""))=="saved":
		var saved: Dictionary=direct_session.saved_character_list()
		if saved.get("ready",false):direct_lobby_state.savedCharacters=saved.entries
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

func direct_disconnect(return_to_menu: bool=true)->void:
	if closing:return
	direct_disconnect_after_export=false
	direct_character_export_stage=0
	direct_visual_queue.clear()
	direct_ambient_queue.clear()
	direct_voice_queue.clear()
	direct_camera_queue.clear();direct_camera_state=null;direct_camera_target_id=-1
	if is_instance_valid(direct_placed_sounds):direct_placed_sounds.detach()
	if is_instance_valid(direct_ambient_audio):direct_ambient_audio.close();direct_ambient_audio.queue_free();direct_ambient_audio=null
	if direct_session!=null:
		direct_session.close();direct_session.queue_free();direct_session=null
	direct_check_deadline=0
	direct_nwsync_cancel_pending=false
	reset_session()
	direct_lobby_choices.clear();direct_lobby_state.clear();selected_character.clear()
	direct_catalog_adopted=false;direct_area_presented=false;direct_quickbar_received=false;local_character_pending=false
	direct_inventory_stage=0;direct_inventory_deadline=0;direct_item_id=-1
	session_connection+=1
	if direct_login_profiles!=null:
		direct_login_profiles.connection=session_connection
		direct_login_profiles.visible=false;direct_login_profiles.view_id+=1
	server_browser.reset(session_connection)
	character_lobby.apply_state({"connection":session_connection,"state":{"phase":"menu","canJoin":true}})
	if return_to_menu:open_startup_menu.call_deferred()

func direct_catalog_ready(prepared: RefCounted)->void:
	if closing or direct_catalog_adopted:return
	if not install_mounted_catalog(prepared,str(direct_session.install_root),direct_session.resource_sources):fail("Godot catalog could not attach to the native gameplay UI");return
	direct_catalog_adopted=true
	if is_instance_valid(direct_ambient_audio):direct_ambient_audio.configure(prepared,ProjectSettings.globalize_path(str(args.get("prepared-cache","user://native-prepared-v2"))))
	current_prework_sources=direct_session.resource_sources.duplicate(true)
	label.text="Godot resource catalog ready"
	if local_character_pending:direct_select_local_character()
	direct_present_area()

func direct_character_list(rows: Array[Dictionary])->void:
	if closing:return
	if not direct_browser_join_row.is_empty() and direct_browser_store!=null:
		var remembered: bool=direct_browser_store.remember(direct_browser_join_row,direct_browser_join_name)
		report.direct_history_saved=remembered
		direct_browser_join_row.clear();direct_browser_join_name=""
	if args.get("direct-headless-manual-check","")=="true" or not args.has("direct-pregen-bic") and not args.has("direct-local-bic") and args.get("direct-headless-check","")!="true":
		direct_lobby_choices.clear()
		var choices: Array=[]
		for row in rows:
			var key: String="server:"+str(row.source)+":"+str(row.resref)
			if direct_lobby_choices.has(key):fail("Duplicate native server character identity");return
			direct_lobby_choices[key]=row.duplicate(true)
			var choice: Dictionary=row.duplicate(true)
			choice.key=key;choice.source="server";choice.nativeSource=int(row.source);choice.serverSource=int(row.source);choice.label=str(row.resref)
			choices.append(choice)
		if direct_session.local_vault_allowed:
			for row in direct_local_choices():
				direct_lobby_choices[row.key]=row.duplicate(true)
				choices.append(row)
		direct_lobby_state={"phase":"character-selection","endpoint":{"host":server_label,"port":int(args.get("direct-port",0))},"choices":choices,"selected":null,"preview":null,"canSelect":not choices.is_empty(),"canCreate":false,"connected":true,"localAllowed":direct_session.local_vault_allowed,"busy":false,"error":"" if not choices.is_empty() else "No usable local or server character was found"}
		var saved: Dictionary=direct_session.saved_character_list()
		if saved.get("ready",false):direct_lobby_state.savedCharacters=saved.entries
		direct_show_character_state()
		return
	if rows.is_empty():
		local_character_pending=true
		direct_select_local_character()
		return
	selected_character=rows[0].duplicate(true)
	if not direct_session.request_preview(int(selected_character.source),str(selected_character.resref)):fail("Godot direct character preview request failed")

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
	if not direct_session.play_local_character(bytes):fail("Godot local character upload was rejected");return
	local_character_pending=false
	label.text="Uploading selected local character to private server…"

func direct_character_preview(preview: Dictionary)->void:
	if closing or selected_character.is_empty():return
	var bytes: PackedByteArray=preview.get("bytes",PackedByteArray())
	if bytes.size()<4 or bytes.slice(0,4).get_string_from_ascii()!="BIC ":fail("Godot direct server-vault preview is invalid");return
	if not direct_lobby_state.is_empty():
		direct_lobby_state.preview=direct_project_bic(bytes)
		if direct_lobby_state.preview.has("error"):fail("Godot server character preview is invalid");return
		direct_lobby_state.selectionAck={"requestId":direct_choice_request_id,"key":direct_lobby_state.selected}
		direct_show_character_state()
		return
	if not direct_session.play_character(int(selected_character.source),str(selected_character.resref)):fail("Godot direct character Play request failed")

func direct_project_bic(bytes: PackedByteArray)->Dictionary:
	var parser:=GffDocument.new()
	var document: Dictionary=parser.parse(bytes,"BIC ")
	if not parser.failure.is_empty():return {"error":"Invalid BIC record"}
	var projected: Dictionary=CharacterPreview.project(document.root,int(direct_session.language))
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

func direct_local_bytes(row: Dictionary)->PackedByteArray:
	var ticket_file: Dictionary=row.get("nativeFile",{})
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

func direct_show_character_state()->void:
	if not is_instance_valid(character_lobby):return
	var state: Dictionary=direct_lobby_state.duplicate(true)
	if str(state.get("phase","")) in ["character-selection","character-rejected"] and direct_session!=null:state.lobbyPlayers=direct_session.lobby_players.list()
	character_lobby.apply_state({"connection":session_connection,"state":state,"localCharacterRoots":ticket.get("localCharacterRoots",[]),"nativeVault":direct_session.character_vault if direct_session!=null else null})
	if str(direct_lobby_state.get("phase",""))=="character-selection":character_lobby.panel.show()

func direct_lobby_players(_rows: Array)->void:
	if not closing and direct_session!=null and direct_session.phase=="character-selection":direct_show_character_state()

func lobby_request(message: Dictionary)->void:
	if not direct_mode:super.lobby_request(message);return
	var kind:=str(message.get("kind",""))
	if kind=="lobby-disconnect":
		if bool(message.get("saveCharacter",false)):direct_save_then_disconnect()
		else:direct_disconnect()
		return
	if kind=="lobby-cancel-join":direct_disconnect();return
	if kind=="lobby-join":server_browser.open(true,true);return
	if closing or direct_session==null:return
	if kind=="lobby-export":
		var requested: Dictionary=direct_session.request_character_export()
		if requested.has("error"):direct_character_export_status({"state":"failed","text":str(requested.error),"uncertain":direct_session.character_export_uncertain})
		return
	if kind=="lobby-page":
		if direct_session.phase!="character-selection":return
		var page:=int(message.get("page",-1))
		if page<0 or page>2:return
		var subscription: Dictionary=direct_session.lobby_player_subscription(page==2)
		if subscription.has("error"):
			direct_lobby_state.error=str(subscription.error)
			direct_show_character_state()
		return
	if kind=="lobby-choose":
		var key:=str(message.get("key",""))
		if direct_lobby_state.is_empty() or direct_session.phase!="character-selection" or not direct_lobby_choices.has(key):return
		selected_character=direct_lobby_choices[key].duplicate(true)
		direct_choice_request_id=int(message.get("requestId",-1))
		direct_lobby_state.selected=key;direct_lobby_state.preview=null
		if str(selected_character.get("source",""))=="server":
			if not direct_session.request_preview(int(selected_character.nativeSource),str(selected_character.resref)):fail("Godot direct character preview request failed");return
		else:
			var bytes:=direct_local_bytes(selected_character)
			if bytes.is_empty():fail("Godot local character changed before preview");return
			direct_lobby_state.preview=direct_project_bic(bytes)
			if direct_lobby_state.preview.has("error"):fail("Godot local character preview is invalid");return
			direct_lobby_state.selectionAck={"requestId":direct_choice_request_id,"key":key}
		direct_show_character_state()
	elif kind=="lobby-play":
		if direct_lobby_state.is_empty() or direct_session.phase!="character-selection" or direct_lobby_state.get("selected")!=message.get("key") or direct_lobby_state.get("preview")==null:return
		if str(selected_character.get("source",""))=="server":
			if not direct_session.play_character(int(selected_character.nativeSource),str(selected_character.resref)):fail("Godot direct character Play request failed");return
		else:
			var bytes:=direct_local_bytes(selected_character)
			if bytes.is_empty() or not direct_session.play_local_character(bytes,false,str(selected_character.get("nativeVaultId",""))):fail("Godot local character Play request failed");return
		direct_lobby_state.phase="area-loading";direct_lobby_state.canSelect=false
		direct_show_character_state()

func direct_module_ready(module: Dictionary)->void:
	module_name=str(module.get("name","Arelith"))
	root.title="NWN · Godot direct · "+module_name+" · "+server_label

func direct_area_ready(_entry: Dictionary)->void:
	direct_visual_queue.clear()
	direct_ambient_queue.clear()
	direct_voice_queue.clear()
	direct_camera_target_id=-1
	direct_camera_queue=direct_camera_queue.filter(func(command: Dictionary):return str(command.get("kind",""))!="camera-attach" or int(command.get("nativeAreaId",-1))==direct_session.world_state.area_id)
	if is_instance_valid(direct_placed_sounds):direct_placed_sounds.detach()
	if is_instance_valid(direct_ambient_audio):direct_ambient_audio.detach()
	direct_generation+=1
	direct_area_presented=false
	report.direct_area_packet={"area":direct_session.world_state.area_id,"objects":direct_session.world_state.registry.size(),"controlled":direct_session.world_state.local_object_id}
	direct_present_area()

func direct_present_area()->void:
	if closing or direct_area_presented or not direct_catalog_adopted or direct_session==null or direct_session.phase!="area-presenting":return
	var data: Dictionary=direct_session.presentation(true)
	if data.has("error") or not data.get("objects") is Array or data.objects.is_empty():
		report.direct_area_wait=str(data.get("error","Native area has no staged objects"))
		return
	receive({"kind":"snapshot","connection":session_connection,"generation":direct_generation,"data":data})
	if not is_instance_valid(world) or world.area_id!=int(data.area.id):fail("Godot renderer did not open the direct server area");return
	if is_instance_valid(direct_placed_sounds) and is_instance_valid(world.effects) and is_instance_valid(world.effects.world_audio):direct_placed_sounds.attach(direct_session.world_state.area,direct_session.world_state.registry,world.effects.world_audio)
	if is_instance_valid(direct_ambient_audio):
		direct_ambient_audio.attach(direct_session.world_state.area,int(direct_session.world_state.time.get("timeOfDay",0)))
		for command in direct_ambient_queue:
			if int(command.get("nativeAreaId",-1))==direct_session.world_state.area_id:direct_ambient_audio.receive(command)
		direct_ambient_queue.clear()
	direct_drain_visuals()
	direct_drain_voices()
	direct_area_presented=true
	label.text="Preparing Godot world…"

func direct_world_ready(data: Dictionary)->void:
	if closing or not direct_area_presented or direct_session==null or direct_session.phase!="playing":return
	if int(data.get("area",{}).get("id",-1))!=world.area_id:return
	receive({"kind":"snapshot","connection":session_connection,"generation":direct_generation,"data":data})
	direct_drain_visuals()
	direct_drain_voices()
	direct_camera_bind()

func direct_movement(rows: Array)->void:
	if closing or direct_session==null or direct_session.phase!="playing" or not is_instance_valid(world) or world.area_id!=direct_session.world_state.area_id:return
	if args.get("direct-headless-local-smoke-check","")=="true":
		if not report.has("direct_local_smoke_movement_fields"):report.direct_local_smoke_movement_fields=[]
		for row in rows:
			if int(row.get("id",-1))!=int(direct_session.world_state.local_object_id) or report.direct_local_smoke_movement_fields.size()>=32:continue
			var changes: Dictionary=row.get("changes",{})
			report.direct_local_smoke_movement_fields.append({"revision":int(row.get("revision",0)),"created":bool(row.get("created",false)),"fields":changes.keys(),"animation":changes.get("animation"),"pathLength":changes.get("path",[]).size()})
	world.observe_movement(rows)

func direct_creature_voice(message: Dictionary)->void:
	if closing or direct_session==null or direct_session.phase!="playing":return
	var id:=int(message.get("objectId",-1))
	var actor: Dictionary=direct_session.world_state.registry.get(id,{})
	if int(actor.get("objectType",0))!=5 or int(actor.get("areaId",-1))!=direct_session.world_state.area_id:return
	var lifetime:=int(actor.get("nativeLifetime",0))
	if lifetime<=0:return
	if direct_voice_queue.size()>=128:
		report.direct_voice_overflow=int(report.get("direct_voice_overflow",0))+1
		return
	direct_voice_queue.append({"message":message.duplicate(true),"connection":session_connection,"generation":direct_generation,"areaId":direct_session.world_state.area_id,"objectId":id,"lifetime":lifetime})
	direct_drain_voices()

func direct_drain_voices()->void:
	if closing or direct_session==null or not is_instance_valid(world) or not is_instance_valid(world.effects) or not is_instance_valid(gameplay_ui):return
	var waiting: Array[Dictionary]=[]
	for entry in direct_voice_queue:
		if int(entry.connection)!=session_connection or int(entry.generation)!=direct_generation or int(entry.areaId)!=world.area_id:continue
		var id:=int(entry.objectId)
		var actor: Dictionary=direct_session.world_state.registry.get(id,{})
		if int(actor.get("objectType",0))!=5 or int(actor.get("areaId",-1))!=world.area_id or int(actor.get("nativeLifetime",0))!=int(entry.lifetime):continue
		var render_actor: Variant=world.effects.object(id)
		if not render_actor is Dictionary or int(render_actor.get("nativeLifetime",0))!=int(entry.lifetime):
			waiting.append(entry)
			continue
		world.effects.creature_voices.receive_network(entry.message,Callable(gameplay_ui,"receive_voice_caption"),session_connection)
	direct_voice_queue=waiting

func native_camera_follow_target_id()->int:
	if not is_instance_valid(world):return -1
	if direct_camera_target_id>=0 and world.instances.has(direct_camera_target_id) and world.desired.has(direct_camera_target_id) and int(world.desired[direct_camera_target_id].object.get("objectType",0)) in [5,9]:return direct_camera_target_id
	return world.controlled_id

func direct_camera_command(message: Dictionary)->void:
	if closing or direct_session==null:return
	if direct_camera_queue.size()>=128:fail("Native camera command queue exceeded bound");return
	var queued:=message.duplicate(true)
	queued.nativeReceivedMs=Time.get_ticks_msec()
	queued.nativeAreaId=direct_session.world_state.area_id
	if queued.kind=="camera-attach":
		var object: Dictionary=direct_session.world_state.registry.get(int(queued.objectId),{})
		if not object.is_empty():queued.nativeLifetime=object.get("nativeLifetime",object.get("clientKnownLifetime"))
	direct_camera_queue.append(queued)
	direct_camera_bind()

func direct_camera_bind()->void:
	if closing or direct_session==null or not is_instance_valid(world) or not is_instance_valid(controller) or controller.follow_state==null:return
	if direct_camera_state==null:direct_camera_state=controller.follow_state
	elif controller.follow_state!=direct_camera_state:controller.enable_follow(int(direct_camera_state.state.mode),controller.target,float(controller.follow_height) if is_finite(float(controller.follow_height)) else 1.0,{},direct_camera_state)
	if direct_camera_target_id>=0 and (not world.desired.has(direct_camera_target_id) or not world.instances.has(direct_camera_target_id)):
		direct_camera_target_id=-1
		if world.instances.has(world.controlled_id):
			var home: Vector3=world.instances[world.controlled_id].global_position
			direct_camera_state.attach([home.x,-home.z,home.y],1.0,true,false)
	while not direct_camera_queue.is_empty():
		var command: Dictionary=direct_camera_queue[0]
		var accepted:=false
		if command.kind=="camera-attach":
			var target:=int(command.objectId)
			var object: Dictionary=direct_session.world_state.registry.get(target,{})
			if int(command.nativeAreaId)!=world.area_id or object.is_empty() or int(object.get("areaId",-1))!=world.area_id or int(object.get("objectType",0)) not in [5,9] or command.has("nativeLifetime") and object.get("nativeLifetime",object.get("clientKnownLifetime"))!=command.nativeLifetime:
				direct_camera_queue.pop_front()
				continue
			if not world.instances.has(target) or not is_instance_valid(world.instances[target]):
				if Time.get_ticks_msec()-int(command.nativeReceivedMs)<5000:return
				direct_camera_queue.pop_front()
				report.direct_camera_unresolved=int(report.get("direct_camera_unresolved",0))+1
				continue
			var position: Vector3=world.instances[target].global_position
			direct_camera_state.attach([position.x,-position.z,position.y],1.0,int(object.objectType)==5,bool(command.findClearView))
			direct_camera_target_id=-1 if target==world.controlled_id else target
			if bool(command.findClearView):
				report.direct_camera_clear_view_unavailable=int(report.get("direct_camera_clear_view_unavailable",0))+1
				direct_camera_state.state.findClearView=false
			accepted=true
		else:accepted=direct_camera_state.apply_command(command)
		direct_camera_queue.pop_front()
		if not accepted:report.direct_camera_rejected=int(report.get("direct_camera_rejected",0))+1

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
		if name=="gd_sync_icon":
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
	direct_resource_progress("server-content",1,99)
	var stale_ignored: bool=prior_state==JSON.stringify(character_lobby.state) and prior_visible==character_lobby.panel.visible
	var settings_unchanged:=FileAccess.get_sha256(direct_nwsync_visual_settings_path)==direct_nwsync_visual_settings_hash
	report.direct_nwsync_visual_check={"progress":progress,"resourcesVerified":verified,"iconDecoded":icon_image!=null,"iconPixel":icon_pixel,"lobbyControlsRetired":controls_retired,"staleProgressIgnored":stale_ignored,"settingsUnchanged":settings_unchanged,"worldReady":world.ready_for_control(),"visualCapture":null,"phase":phase}
	if not controls_retired or not stale_ignored or not settings_unchanged or not bool(report.direct_nwsync_visual_check.worldReady):fail("Private NWSync visual post-admission state check failed");return false
	if DisplayServer.get_name()=="headless":direct_nwsync_visual_stage=2;return true
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

func direct_ambient_command(message: Dictionary)->void:
	if closing or direct_session==null:return
	var area_id: int=direct_session.world_state.area_id
	if area_id<0x80000000:return
	if is_instance_valid(direct_ambient_audio) and int(direct_ambient_audio.area_id)==area_id:
		direct_ambient_audio.receive(message)
		return
	if direct_ambient_queue.size()>=128:
		report.direct_ambient_overflow=int(report.get("direct_ambient_overflow",0))+1
		return
	var queued:=message.duplicate(true)
	queued.nativeAreaId=area_id
	direct_ambient_queue.append(queued)

func direct_ambient_time(changes: Dictionary)->void:
	if closing or direct_session==null or not changes.has("timeOfDay"):return
	if is_instance_valid(direct_ambient_audio) and int(direct_ambient_audio.area_id)==direct_session.world_state.area_id:
		direct_ambient_audio.day_night(int(changes.timeOfDay))

func direct_object_visual(message: Dictionary)->void:
	if closing or direct_session==null or int(message.get("nativeAreaId",-1))!=direct_session.world_state.area_id:return
	if direct_visual_queue.size()>=512:report.direct_visual_overflow=int(report.get("direct_visual_overflow",0))+1;return
	direct_visual_queue.append(message.duplicate(true))
	direct_drain_visuals()

func direct_drain_visuals()->void:
	if direct_session==null or not is_instance_valid(world) or not is_instance_valid(world.effects):return
	var waiting: Array[Dictionary]=[]
	for message in direct_visual_queue:
		if int(message.nativeAreaId)!=world.area_id:continue
		var target:=int(message.targetId);var source:=int(message.get("sourceId",0x7f000000))
		var original_identity: Variant=message.get("nativeTargetIdentity")
		if original_identity!=null:
			var current: Dictionary=direct_session.world_state.registry.get(target,{})
			if current.get("nativeLifetime",current.get("clientKnownLifetime"))!=original_identity:continue
		var original_source: Variant=message.get("nativeSourceIdentity")
		if original_source!=null:
			var current_source: Dictionary=direct_session.world_state.registry.get(source,{})
			if current_source.get("nativeLifetime",current_source.get("clientKnownLifetime"))!=original_source:continue
		var target_row: Dictionary=world.desired.get(target,{})
		var source_row: Dictionary=world.desired.get(source,{})
		if target!=0x7f000000 and target_row.is_empty() and direct_session.world_state.registry.has(target):
			waiting.append(message)
			continue
		var lifetime:=int(target_row.get("object",{}).get("nativeLifetime",0))
		var source_lifetime:=int(source_row.get("object",{}).get("nativeLifetime",0))
		world.effects.receive_raw({"serial":int(world.effects.last_serial)+1,"events":[{"kind":"instant","id":target,"lifetime":lifetime,"sourceLifetime":source_lifetime,"message":message.duplicate(true)}]})
	direct_visual_queue=waiting

func gameplay_presentation_allowed()->bool:
	return not closing and direct_session!=null and direct_session.phase=="playing" and is_instance_valid(world) and (gameplay_ui.presentation_enabled or world.ready_for_control()) and not loading_screen.blocks_input()

func send(value: Dictionary)->void:
	if direct_login_profiles!=null and direct_login_profiles.handle(value):return
	if closing or direct_session==null:return
	var kind:=str(value.get("kind",""))
	if kind=="area-ready":
		if direct_session.phase=="area-presenting" and is_instance_valid(world):
			if not direct_session.area_ready(world):fail("Godot prepared-area acknowledgement failed")
		return
	if kind in ["observed","main-menu-observed","catalog-ready","finished","creation-native-phase"]:return
	if kind=="level-source-progress" and args.get("direct-headless-levelup-check","")=="true":
		report.direct_levelup_probe_progress={"phase":str(value.get("phase","")),"checks":int(value.get("checks",0)),"success":bool(value.get("success",false))}
		return
	if kind=="level-source-finished" and args.get("direct-headless-levelup-check","")=="true":
		direct_levelup_probe_finished={"success":bool(value.get("success",false)),"checks":int(value.get("checks",0)),"failures":value.get("failures",[])}
		return
	if direct_session.phase!="playing" or not is_instance_valid(world) or int(value.get("generation",epoch))!=epoch or int(value.get("areaId",world.area_id))!=world.area_id:return
	var outcome: Dictionary={}
	if kind in ["inventory-open","inventory-close","inventory-page"]:
		var owner_id:=int(value.get("ownerId",direct_session.world_state.local_object_id))
		var role:=str(value.get("inventoryRole","primary"))
		var window_serial:=int(value.get("windowSerial",-1))
		var receipt_serial:=int(value.get("inventoryReceipt",-1))
		match kind:
			"inventory-open":
				outcome=direct_session.inventory_window(true,owner_id,role,window_serial,receipt_serial)
				if not outcome.has("error"):outcome=direct_session.inventory_panel(int(value.get("page",0)),owner_id,role,window_serial,receipt_serial)
			"inventory-close":outcome=direct_session.inventory_window(false,owner_id,role,window_serial,receipt_serial)
			"inventory-page":outcome=direct_session.inventory_panel(int(value.get("page",0)),owner_id,role,window_serial,receipt_serial)
		direct_inventory_result(value,outcome)
		return
	match kind:
		"native-panel":
			if str(value.get("panel","")) in ["blocked-attempt","context-attempt"]:
				outcome=direct_session.gui_panel_input(value)
				if outcome.has("error"):receive({"kind":"ui-protocol","connection":session_connection,"generation":epoch,"message":{"kind":"native-action-result","action":"native-panel","accepted":false,"text":str(outcome.error)}})
			return
		"native-script-target":
			outcome=direct_session.script_target_input(value)
			if outcome.has("error"):receive({"kind":"ui-protocol","connection":session_connection,"generation":epoch,"message":{"kind":"native-action-result","action":"native-script-target","accepted":false,"text":str(outcome.error)}})
			return
		"inventory-container":
			if str(value.get("inventoryRole","primary"))!="primary":outcome={"error":"Alternate container navigation is unavailable"}
			else:outcome=direct_session.container_input(str(value.get("operation","")),int(value.get("targetId",-1)),int(value.get("actorId",direct_session.world_state.local_object_id)))
			direct_inventory_result(value,outcome)
			return
		"walk":
			outcome=direct_session.walk_to(value.get("position",[]),bool(value.get("run",true)))
			if args.get("direct-headless-local-smoke-check","")=="true" and direct_local_smoke_stage==0:direct_local_smoke_request={"requestAccepted":not outcome.has("error"),"requestTransmitted":outcome.has("sequence"),"sequence":int(outcome.get("sequence",-1)),"error":str(outcome.get("error",""))}
		"drive":outcome=direct_session.keyboard_move(int(value.get("actorId",-1)),str(value.get("operation","")),value.get("position",[]),int(value.get("heading",0)),int(value.get("flags",0)),bool(value.get("transmit",true)))
		"examine":outcome=direct_session.target_action(int(value.get("targetId",-1)),"examine")
		"interact":outcome=direct_session.target_action(int(value.get("targetId",-1)),str(value.get("action","")),value.get("position",[]),bool(value.get("run",true)))
		"item-action":
			outcome=direct_session.item_action(value)
			direct_inventory_result(value,outcome)
			return
		"item-use":outcome=direct_session.target_action(int(value.get("itemId",-1)),"object.use")
		"native-nui-input":
			outcome=direct_session.nui_input(value)
			if outcome.has("error") and is_instance_valid(gameplay_ui):gameplay_ui.chat.append_message({"system":true,"text":str(outcome.error)})
			return
		"native-store":
			outcome=direct_session.store_input(value)
			if outcome.has("error"):receive({"kind":"ui-protocol","connection":session_connection,"generation":epoch,"message":{"kind":"native-action-result","action":"native-store","accepted":false,"text":str(outcome.error)}})
			return
		"native-barter":
			outcome=direct_session.barter_input(value)
			if outcome.has("error"):receive({"kind":"ui-protocol","connection":session_connection,"generation":epoch,"message":{"kind":"native-action-result","action":"native-barter","accepted":false,"text":str(outcome.error)}})
			return
		"native-level-up":
			outcome=direct_session.level_up_input(value)
			if args.get("direct-headless-levelup-check","")=="true":direct_levelup_outbound.append({"operation":str(value.get("operation","")),"sent":not outcome.has("error")})
			if outcome.has("error"):
				receive({"kind":"ui-protocol","connection":session_connection,"generation":epoch,"message":{"kind":"native-action-result","action":"native-level-up","operation":str(value.get("operation","")),"levelRequest":value.get("levelRequest",{}).duplicate(true),"accepted":false,"text":str(outcome.error)}})
			return
		"native-quickbar-assign","native-quickbar-activate","native-quickchat","native-associate","native-possess","native-cancel-polymorph":
			outcome=direct_session.quickbar_assign(value) if kind=="native-quickbar-assign" else direct_session.quickbar_activate(value) if kind=="native-quickbar-activate" else direct_session.simple_native_action(value)
			receive({"kind":"ui-protocol","connection":session_connection,"generation":epoch,"message":{"kind":"native-action-result","action":kind,"accepted":not outcome.has("error"),"result":outcome if not outcome.has("error") else {},"text":str(outcome.get("error",""))}})
			return
		"chat":
			outcome=direct_session.chat(value)
			if outcome.has("error"):receive({"kind":"ui-protocol","connection":session_connection,"generation":epoch,"message":{"kind":"native-action-result","action":"native-chat","generation":epoch,"areaId":world.area_id,"actorId":direct_session.world_state.local_object_id,"accepted":false,"text":str(outcome.error)}})
			return
		"reply":
			outcome=direct_session.reply_dialog(value)
			if outcome.has("error"):receive({"kind":"ui-protocol","connection":session_connection,"generation":epoch,"message":{"kind":"dialog-error","entryId":int(value.get("entryId",-1)),"reason":str(outcome.error)}})
			return
		_:return
	if outcome.has("error") and is_instance_valid(gameplay_ui):gameplay_ui.chat.append_message({"system":true,"text":str(outcome.error)})

func direct_inventory_result(request: Dictionary,outcome: Dictionary)->void:
	var reply: Dictionary={"kind":"inventory-command-result","requestId":request.get("requestId"),"inventoryRole":str(request.get("inventoryRole","primary")),"ownerId":request.get("ownerId",direct_session.world_state.local_object_id),"windowSerial":request.get("windowSerial"),"accepted":not outcome.has("error")}
	if outcome.has("error"):reply.reason=str(outcome.error)
	if report.get("direct_inventory_commands") is Array:report.direct_inventory_commands.append({"kind":str(request.get("kind","")),"accepted":reply.accepted})
	receive({"kind":"ui-protocol","connection":session_connection,"generation":epoch,"message":reply})

func shutdown()->void:
	if closing:return
	if is_instance_valid(direct_ambient_audio):direct_ambient_audio.close();direct_ambient_audio.queue_free();direct_ambient_audio=null
	if direct_directory!=null:direct_directory.close()
	if direct_login_profiles!=null:direct_login_profiles.close();direct_login_profiles=null
	if direct_session!=null:direct_session.close()
	finish_acknowledged=true
	super.shutdown()
