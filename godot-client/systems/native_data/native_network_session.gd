extends Node
# Godot-owned original-server session through first-world presentation and
# movement request encoding. Normal gameplay promotion waits for direct UI
# integration and the remaining game-message handlers.
const Settings=preload("res://systems/native_data/client_settings_store.gd")
const StartupPaths=preload("res://systems/native_data/native_startup_paths.gd")
const CryptoOwner=preload("res://systems/native_data/native_network_crypto.gd")
const Build=preload("res://systems/native_data/native_installed_network_build.gd")
const Identity=preload("res://systems/native_data/native_login_identity.gd")
const Peer=preload("res://systems/native_data/native_network_peer.gd")
const ConnectionFailure=preload("res://systems/native_data/native_network_connection_failure.gd")
const Store=preload("res://systems/native_data/nwsync_store.gd")
const Repository=preload("res://systems/native_data/native_nwsync_repository.gd")
const Requirements=preload("res://systems/native_data/native_resource_requirements.gd")
const ResourceProgress=preload("res://systems/native_data/resource_progress.gd")
const ServerStatus=preload("res://systems/native_data/native_network_server_status.gd")
const CharacterNeeded=preload("res://systems/native_data/native_network_character_needed.gd")
const LobbyPlayer=preload("res://systems/native_data/native_network_lobby_player.gd")
const LobbyPlayerRegistry=preload("res://systems/native_data/native_lobby_player_registry.gd")
const GuiAccess=preload("res://systems/native_data/native_network_gui_access.gd")
const ResourceSources=preload("res://systems/native_data/native_resource_sources.gd")
const SessionCatalog=preload("res://systems/native_data/session_catalog.gd")
const TwoDA=preload("res://systems/native_data/two_da.gd")
const Characters=preload("res://systems/native_data/native_server_characters.gd")
const DeviceProperties=preload("res://systems/native_data/native_device_properties.gd")
const RuntimeMessages=preload("res://systems/native_data/native_runtime_messages.gd")
const PlayerRequests=preload("res://systems/native_data/native_player_requests.gd")
const InventoryResponse=preload("res://systems/native_data/native_inventory_response.gd")
const EquipmentCache=preload("res://systems/native_data/native_network_equipment_cache.gd")
const InventoryWindowStatus=preload("res://systems/native_data/native_inventory_window_status.gd")
const ContainerStatus=preload("res://systems/native_data/native_container_status.gd")
const NetworkNui=preload("res://systems/native_data/native_network_nui.gd")
const NuiState=preload("res://systems/native_data/nui_state.gd")
const NetworkHud=preload("res://systems/native_data/native_network_hud.gd")
const AreaVisuals=preload("res://systems/native_data/native_network_area_visuals.gd")
const NetworkFeedback=preload("res://systems/native_data/native_network_feedback.gd")
const NativeTextEventScope=preload("res://systems/native_data/native_text_event_scope.gd")
const NativeVisibilityFrames=preload("res://systems/native_data/native_visibility_frames.gd")
const NativeAudioFrames=preload("res://systems/native_data/native_audio_frames.gd")
const NetworkStore=preload("res://systems/native_data/native_network_store.gd")
const NetworkParty=preload("res://systems/native_data/native_network_party.gd")
const SpellInput=preload("res://systems/native_data/native_network_spell_input.gd")
const FeatInput=preload("res://systems/native_data/native_network_feat_input.gd")
const EmoteInput=preload("res://systems/native_data/native_network_emote_input.gd")
const MapInput=preload("res://systems/native_data/native_network_map_input.gd")
const ItemInput=preload("res://systems/native_data/native_network_item_input.gd")
const JournalEvents=preload("res://systems/native_data/native_journal_events.gd")
const NetworkSystemNotices=preload("res://systems/native_data/native_network_system_notices.gd")
const RecordTarget=preload("res://systems/native_data/character_record_target.gd")
const ObjectAnimation=preload("res://systems/native_data/object_animation.gd")
const TransitionSurface=preload("res://systems/native_data/transition_surface.gd")
const NetworkExamine=preload("res://systems/native_data/native_network_examine.gd")
const NetworkBarter=preload("res://systems/native_data/native_network_barter.gd")
const NetworkSound=preload("res://systems/native_data/native_network_sound.gd")
const NetworkAmbient=preload("res://systems/native_data/native_network_ambient.gd")
const ObjectVisual=preload("res://systems/native_data/native_network_object_visual.gd")
const NetworkPortal=preload("res://systems/native_data/native_network_portal.gd")
const NetworkCamera=preload("res://systems/native_data/native_network_camera.gd")
const NetworkLevelUp=preload("res://systems/native_data/native_network_levelup.gd")
const LevelUpTransaction=preload("res://systems/native_data/native_levelup_transaction.gd")
const NetworkCreatureVoice=preload("res://systems/native_data/native_network_creature_voice.gd")
const NetworkCustomToken=preload("res://systems/native_data/native_network_custom_token.gd")
const NetworkItemCaption=preload("res://systems/native_data/native_network_item_caption.gd")
const NetworkTargeting=preload("res://systems/native_data/native_network_targeting.gd")
const NetworkProjectile=preload("res://systems/native_data/native_network_projectile.gd")
const NetworkDmPermission=preload("res://systems/native_data/native_network_dm_permission.gd")
const NetworkModulePause=preload("res://systems/native_data/native_network_module_pause.gd")
const NetworkRuntime=preload("res://systems/native_data/native_network_runtime_52_54.gd")
const NetworkCharacterExport=preload("res://systems/native_data/native_network_character_export.gd")
const CharacterExportVault=preload("res://systems/native_data/native_character_export_vault.gd")
const GffDocument=preload("res://systems/native_data/gff_document.gd")
const NetworkSpeech=preload("res://systems/native_data/native_network_speech.gd")
const NetworkDialog=preload("res://systems/native_data/native_network_dialog.gd")
const ModuleInfo=preload("res://systems/native_data/native_module_info.gd")
const ModuleTime=preload("res://systems/native_data/native_module_time.gd")
const AreaState=preload("res://systems/native_data/native_area_state.gd")
const PlayerRoster=preload("res://systems/native_data/native_player_roster.gd")
const ObjectUpdates=preload("res://systems/native_data/native_object_updates.gd")
const Quickbar=preload("res://systems/native_data/native_quickbar.gd")
const ObjectRules=preload("res://systems/native_data/native_object_rules.gd")
const WorldState=preload("res://systems/native_data/native_network_world.gd")
const FrameProfile=preload("res://systems/native_render/frame_profile.gd")
const RawWorldDeltas=preload("res://systems/native_data/raw_world_deltas.gd")
signal phase_changed(phase: String)
signal character_list_ready(characters: Array[Dictionary])
signal character_preview_ready(preview: Dictionary)
signal character_rejected_ready(message: Dictionary)
signal server_status_ready(status: Dictionary)
signal character_needed_ready(message: Dictionary)
signal lobby_players_ready(players: Array)
signal session_failed(reason: String)
signal diagnostic(code: String,reason: String)
signal diagnostic_event(event: Dictionary)
signal resource_progress(phase: String,completed: int,total: int)
signal resource_progress_detail(state: Dictionary)
signal resource_sources_ready(sources: Dictionary)
signal catalog_ready(catalog: RefCounted)
signal module_information_ready(module: Dictionary)
signal area_packet_received(packet: PackedByteArray)
signal area_state_ready(entry: Dictionary)
signal roster_message_ready(message: Dictionary)
signal object_updates_ready(message: Dictionary)
signal scene_changes_ready(events: Array)
signal visibility_frame_ready(frame: Dictionary)
signal script_sound_frame_ready(frame: Dictionary)
signal movement_ready(records: Array)
signal quickbar_ready(message: Dictionary)
signal world_presentation_ready(data: Dictionary)
signal inventory_response_ready(message: Dictionary)
signal ui_message_ready(message: Dictionary)
signal system_notice_ready(message: Dictionary)
signal targeting_ready(message: Dictionary)
signal sound_object_ready(message: Dictionary)
signal ambient_command_ready(message: Dictionary)
signal time_changed(changes: Dictionary)
signal object_visual_ready(message: Dictionary)
signal portal_handoff_ready(handoff: Dictionary)
signal portal_source_departure_done
signal camera_command_ready(message: Dictionary)
signal area_visual_ready(message: Dictionary)
signal creature_voice_ready(message: Dictionary)
signal projectile_ready(message: Dictionary)
signal module_pause_ready(receipt: Dictionary)
signal character_export_status_ready(status: Dictionary)
signal disconnection_finished
signal device_send_advanced
var phase: String="idle"
var peer: RefCounted
var peer_poll_pending:=false
var disconnecting_peer:=false
var disconnect_outcome: Dictionary={}
var build_owner: RefCounted
var peer_closed_event: Dictionary={}
var disconnect_reason: Dictionary={}
var peer_connection_failure: Dictionary={}
var client_failure: Dictionary={}
var last_import_failure: Dictionary={}
var processing_delivery:=false
var resource_progress_snapshot: Variant=null
var server_info_snapshot: Dictionary={}
var character_uploaded:=false
var area_ready_sent:=false
var tlk_override_messages:=0
var final_state_snapshot: Dictionary={}
var identity: RefCounted
var content_store: RefCounted
var repository: Node
var profile_root: String=""
var install_root: String=""
var installed_nwsync_directory: String=""
var mods_directory: String=""
var disabled_mods: Array=[]
var portal_workshop_selection: Dictionary={}
var language:=0
var deadline:=0
var characters: Array[Dictionary]=[]
var character_list_generation:=0
var server_character_list_pending:=false
var lobby_players: RefCounted=LobbyPlayerRegistry.new()
var gui_access: RefCounted=GuiAccess.State.new()
var area_generation:=0
var text_event_connection:=-1
var text_events: RefCounted=NativeTextEventScope.new()
var visibility_frames: RefCounted=NativeVisibilityFrames.new()
var audio_frames: RefCounted=NativeAudioFrames.new()
var gui_panel_attempt_scope: Array=[]
var gui_panel_attempt_last:=0
var pending_preview: Dictionary={}
var character_submission_pending:=false
var lobby_subscription_serial:=0
var error: String=""
var device_metrics: Dictionary={}
var device_property_packets:=0
var device_send_turn:=0
var device_send_completed:=0
var login_waypoint: String=""
var device_echo_replies:=0
var server_status: String=""
var login_waypoint_requests:=0
var player_name: String=""
var portal_identity: RefCounted
var portal_character: Dictionary={}
var portal_pending: Dictionary={}
var portal_prepare: Callable
var portal_endpoint_allowed: Callable
var prepared_portal_context: Dictionary={}
var movement_sequences: Dictionary={}
var sent_device_metrics: Dictionary={}
var remote_build: Dictionary={}
var resource_sources: Dictionary={}
var catalog_loader: Node
var catalog: RefCounted
var catalog_serial:=-1
var catalog_archive_repair_attempted:=false
var character_confirmed:=false
var local_vault_allowed:=false
var local_vault_policy_known:=false
var module_information: Dictionary={}
var module_ready_sent:=false
var object_rules: RefCounted
var pending_object_packets: Array[Dictionary]=[]
var pending_object_bytes:=0
var pending_quickbar_packets: Array[Dictionary]=[]
var pending_quickbar_bytes:=0
var pending_visual_packets: Array[Dictionary]=[]
var pending_visual_bytes:=0
var world_state: RefCounted=WorldState.new()
var session_script_targeting: Variant=null
var level_up: RefCounted=LevelUpTransaction.new()
var pending_level_up_presentation: Dictionary={}
var pending_creature_voice: Array[Dictionary]=[]
var movement_serial:=0
var character_vault: RefCounted
var character_vault_error: String=""
var saved_character_id: String=""
var pending_character_export:=false
var character_export_uncertain:=false
var character_export_deadline:=0
var character_export_timeout_ms:=15000
var current_dialog: Dictionary={}
var journal_events: RefCounted=JournalEvents.new()
var nui_state: RefCounted=NuiState.new()
var pending_nui: Array[Dictionary]=[]
var pending_area_visual: Array[Dictionary]=[]
var local_build: Dictionary={}
var world_revision:=0
var published_revision:=-1
var last_presentation_ms:=0
var _direct_world_publisher: Callable
var _direct_world_borrows_static_nested:=false
var _world_delivery_serial:=0
var _immediate_world_projection: Dictionary={}

func state()->Dictionary:
	if phase in ["closed","failed"] and not final_state_snapshot.is_empty():return final_state_snapshot.duplicate(true)
	var controls: Array=[]
	for player_id in world_state.controls:
		controls.append({"playerId":player_id,"objectId":world_state.controls[player_id]})
	var world_snapshot: Dictionary=world_state.summary()
	var snapshot: Dictionary={"phase":phase,"closed":phase in ["closed","failed"],"resourceProgress":resource_progress_snapshot.duplicate(true) if resource_progress_snapshot is Dictionary else null,"resourcesReady":catalog!=null and object_rules!=null,"characterUploaded":character_uploaded,"characterSubmitted":character_submission_pending or character_uploaded,"characterConfirmed":character_confirmed,"localVaultAllowed":local_vault_allowed,"serverInfo":server_info_snapshot.duplicate(true) if not server_info_snapshot.is_empty() else null,"areaGeneration":area_generation,"areaReady":area_ready_sent,"deviceEchoReplies":device_echo_replies,"devicePropertyPackets":device_property_packets,"loginWaypointRequests":login_waypoint_requests,"tlkOverrideMessages":tlk_override_messages,"world":world_snapshot}
	if not disconnect_reason.is_empty():snapshot.disconnectReason=disconnect_reason.duplicate(true)
	if not client_failure.is_empty():snapshot.clientFailure=client_failure.duplicate(true)
	return snapshot

func set_object_tables(tables: Dictionary,existing_state: Callable=Callable())->bool:
	if object_rules!=null or phase in ["closed","failed"]:return false
	var candidate:=ObjectRules.new()
	var state_query: Callable=existing_state if existing_state.is_valid() else func(id: int)->Variant:return world_state.registry.get(id,{}).get("replicated",{})
	if not candidate.configure(tables,state_query):return false
	object_rules=candidate
	for pending in pending_object_packets:
		if not decode_object_packet(pending.packet,pending.decoded):return false
	pending_object_packets.clear();pending_object_bytes=0
	for pending in pending_quickbar_packets:
		if not decode_quickbar_packet(pending.packet,pending.decoded):return false
	pending_quickbar_packets.clear();pending_quickbar_bytes=0
	for pending in pending_visual_packets:
		if int(pending.areaId)==world_state.area_id and not decode_visual_packet(pending.packet,pending.decoded):return false
	pending_visual_packets.clear();pending_visual_bytes=0
	return true

func decode_visual_packet(packet: PackedByteArray,predecoded: Dictionary={})->bool:
	if object_rules==null:
		if pending_visual_packets.size()>=128 or pending_visual_bytes+packet.size()>4*1024*1024:return fail("Native object visual backlog exceeds bound")
		pending_visual_packets.append({"areaId":world_state.area_id,"packet":packet.duplicate(),"decoded":predecoded.duplicate(true)});pending_visual_bytes+=packet.size()
		return true
	var message: Dictionary=predecoded if not predecoded.is_empty() else ObjectVisual.decode_packet(packet,remote_build,object_rules.providers())
	if message.has("error"):invalid_game_message(packet,str(message.error));return true
	message.nativeAreaId=world_state.area_id
	var target: Dictionary=world_state.registry.get(int(message.targetId),{})
	if not target.is_empty() and (bool(target.get("replicationRemoved",false)) or int(target.get("areaId",-1))!=world_state.area_id):return true
	message.nativeTargetIdentity=target.get("nativeLifetime",target.get("clientKnownLifetime")) if not target.is_empty() else null
	var source: Dictionary=world_state.registry.get(int(message.get("sourceId",0x7f000000)),{})
	message.nativeSourceIdentity=source.get("nativeLifetime",source.get("clientKnownLifetime")) if not source.is_empty() and not bool(source.get("replicationRemoved",false)) and int(source.get("areaId",-1))==world_state.area_id else null
	object_visual_ready.emit(message)
	return true

func decode_quickbar_packet(packet: PackedByteArray,predecoded: Dictionary={})->bool:
	if object_rules==null:
		if pending_quickbar_packets.size()>=128 or pending_quickbar_bytes+packet.size()>8*1024*1024:return fail("Native quickbar backlog exceeds bound")
		pending_quickbar_packets.append({"packet":packet.duplicate(),"decoded":predecoded.duplicate(true)});pending_quickbar_bytes+=packet.size()
		return true
	var message: Dictionary=predecoded if not predecoded.is_empty() else Quickbar.decode_packet(packet,remote_build,object_rules.providers())
	if message.has("error"):invalid_game_message(packet,str(message.error));return true
	if not world_state.apply_quickbar(message):return fail("Native quickbar state rejected: "+str(world_state.error))
	world_revision+=1
	quickbar_ready.emit(message)
	return true

func accept_catalog(serial: int,prepared: RefCounted,reason: String,stats: Dictionary)->void:
	if phase in ["closed","failed"] or serial!=catalog_serial:return
	if not reason.is_empty() or prepared==null:
		var binding: Dictionary=stats.get("repair",{}) if stats.get("repair",{}) is Dictionary else {}
		if not reason.is_empty() and not catalog_archive_repair_attempted and binding.has("store") and binding.has("entry") and repository!=null and is_instance_valid(repository):
			catalog_archive_repair_attempted=true
			var archive_repository: Node=repository
			var repaired: Dictionary=await archive_repository.repair_failed_blob(binding.store,binding.entry)
			if phase in ["closed","failed"] or serial!=catalog_serial or repository!=archive_repository:return
			if repaired.has("error"):fail("Native server archive repair failed: "+str(repaired.error));return
			if catalog_loader==null or not is_instance_valid(catalog_loader):fail("Native server catalog loader is unavailable after repair");return
			catalog_serial=catalog_loader.start(resource_sources)
			return
		fail("Native server catalog preparation failed: "+reason)
		return
	if repository==null or not is_instance_valid(repository):fail("Native server content repair owner is unavailable");return
	var repair_repository: Node=repository
	prepared.bind_nwsync_repair(Callable(repair_repository,"repair_failed_blob"))
	var tables: Dictionary={}
	for name in ["baseitems","classes","visualeffects","skills","spells","feat"]:
		var bytes: PackedByteArray=prepared.get_resource(name,2017)
		if bytes.is_empty():
			var binding: Dictionary=prepared.nwsync_repair_binding(name,2017)
			if not binding.is_empty():
				var repaired: Dictionary=await repair_repository.repair_failed_blob(binding.store,binding.entry)
				if phase in ["closed","failed"] or serial!=catalog_serial or repository!=repair_repository:return
				if repaired.has("error"):fail("Server catalog object rule table repair failed: "+name);return
				bytes=prepared.get_resource(name,2017)
		if bytes.is_empty():fail("Server catalog omitted object rule table "+name);return
		tables[name]=TwoDA.new().parse(bytes.get_string_from_utf8())
	catalog=prepared
	if not set_object_tables(tables):
		if phase!="failed":fail("Server catalog object rule tables are invalid")
		return
	catalog_ready.emit(catalog)
	if phase=="portal-character-pending":
		if not await submit_portal_character():fail("Portal destination character could not be submitted")
		return
	if phase!="loading-content":return
	change_phase("characters")
	deadline=Time.get_ticks_msec()+15000
	server_character_list_pending=true
	if not await peer.send_game_message(PackedByteArray([112,17,1])):fail("Server character-list request failed")

func configure_portal(next_identity: RefCounted,character: Dictionary,waypoint: String,workshop_selection: Dictionary={})->bool:
	if phase!="idle" or portal_identity!=null or next_identity==null or next_identity.get_script()!=Identity or next_identity.disposed or RuntimeMessages.login_waypoint_response(waypoint).has("error"):return false
	if not workshop_selection.is_empty() and (not workshop_selection.get("modsDirectory") is String or not workshop_selection.get("disabledMods") is Array):return false
	if character.has("data"):
		if not character.data is PackedByteArray or character.data.size()<56 or character.data.size()>Characters.MAX_CHARACTER_BYTES:return false
		var document:=GffDocument.new()
		if document.parse(character.data,"BIC ").is_empty():return false
		portal_character={"data":character.data.duplicate()}
	else:
		var reference: Dictionary=Characters.play_request(int(character.get("source",-1)),str(character.get("resref","")))
		if reference.has("error"):return false
		portal_character={"source":int(character.source),"resref":str(character.resref)}
	portal_identity=next_identity
	portal_workshop_selection=workshop_selection.duplicate(true)
	login_waypoint=waypoint
	return true

func submit_portal_character()->bool:
	if phase!="portal-character-pending" or catalog==null or peer==null or portal_character.is_empty():return false
	var packet: Dictionary={}
	if portal_character.has("data"):
		packet=Characters.upload_request(portal_character.data,1)
		character_uploaded=true
		portal_character.data.fill(0)
	else:packet=Characters.play_request(int(portal_character.source),str(portal_character.resref))
	portal_character.clear()
	if packet.has("error") or not await peer.send_game_message(packet.bytes):return false
	character_confirmed=false;module_information.clear();module_ready_sent=false
	change_phase("character-loading")
	deadline=Time.get_ticks_msec()+30000
	return true

func begin_portal(message: Dictionary)->bool:
	if not phase in ["playing","area-loading"] or not character_confirmed or not portal_pending.is_empty() or identity==null or peer==null or not portal_prepare.is_valid():
		diagnostic_event.emit({"code":"network.portal-unavailable","reason":"Server transfer is unavailable in this connection state"})
		return true
	# The saved host checked the destination policy before copying login identity
	# or starting the destination's resource and server-info work.
	if portal_endpoint_allowed.is_valid() and not bool(portal_endpoint_allowed.call(str(message.host),int(message.port))):
		message.password=""
		return fail("This server is not enabled for this session. No connection was sent.")
	var next_identity: RefCounted=identity.for_portal(str(message.password))
	message.password=""
	if next_identity==null:return fail("Portal destination identity could not be prepared")
	portal_pending={"host":str(message.host),"port":int(message.port),"waypoint":str(message.waypoint) if not str(message.waypoint).is_empty() else "*PAUL_WAS_HERE*" if bool(message.seamless) else "","identity":next_identity,"playerName":player_name,"workshopSelection":{"modsDirectory":mods_directory,"disabledMods":disabled_mods.duplicate(true)}}
	change_phase("transferring")
	diagnostic_event.emit({"code":"network.portal-started","reason":"Server requested a portal handoff","host":message.host,"port":message.port,"seamless":message.seamless})
	var prepared: Dictionary=await portal_prepare.call(message)
	if phase in ["closed","failed"] or portal_pending.get("identity")!=next_identity:
		if prepared.get("session") is Node:
			prepared.session.close()
			prepared.session.queue_free()
		return false
	if prepared.has("error") or not prepared.get("session") is Node:
		return portal_fail("The destination connection could not be prepared")
	portal_pending.prepared=prepared
	portal_pending.waiting=true
	deadline=Time.get_ticks_msec()+15000
	if not await peer.send_game_message(NetworkPortal.character_request()):return portal_fail("The old server character could not be requested")
	return true

func finish_portal(message: Dictionary)->bool:
	if phase!="transferring" or not portal_pending.get("waiting",false) or portal_pending.has("character"):
		diagnostic_event.emit({"code":"network.portal-character-stale","reason":"Unrequested portal character was ignored"})
		if message.has("data"):message.data.fill(0)
		return true
	if message.has("data"):
		portal_pending.character={"data":message.data.duplicate()}
		message.data.fill(0)
	else:portal_pending.character={"source":int(message.source),"resref":str(message.resref)}
	if peer==null:return portal_fail("The old server connection could not be released")
	# Begin source disconnect at the character message, as the original host
	# does. The already decoded poll payloads still drain before adoption.
	var departing_peer: RefCounted=peer
	portal_pending.departingPeer=departing_peer
	close_portal_source(departing_peer)
	return true

func close_portal_source(departing_peer: RefCounted)->void:
	var departure: Dictionary=await departing_peer.close()
	if portal_pending.get("departingPeer")==departing_peer:
		portal_pending.departure=departure
		portal_pending.departureDone=true
	portal_source_departure_done.emit()

func portal_fail(reason: String)->bool:
	if portal_pending.is_empty():return false
	diagnostic_event.emit({"code":"network.portal-failed","reason":reason})
	return fail(reason)

func release_portal()->bool:
	if phase!="transferring" or portal_pending.is_empty() or not portal_pending.has("character") or peer==null:return false
	var departing_peer: RefCounted=portal_pending.get("departingPeer",peer)
	var departure: Dictionary={}
	if portal_pending.has("departingPeer"):
		while phase=="transferring" and portal_pending.get("departingPeer")==departing_peer and not bool(portal_pending.get("departureDone",false)):
			await portal_source_departure_done
		departure=portal_pending.get("departure",{})
	else:departure=await departing_peer.close()
	if phase!="transferring" or peer!=departing_peer or portal_pending.is_empty():return false
	if departure.has("error") or bool(peer_closed_event.get("failed",false)):return false
	var handoff: Dictionary=portal_pending
	portal_pending={}
	var prepared: Dictionary=handoff.get("prepared",{})
	handoff.erase("prepared")
	handoff.merge(prepared,true)
	change_phase("portal-ready")
	diagnostic_event.emit({"code":"network.portal-ready","reason":"Old server released the character; destination login is ready","host":handoff.host,"port":handoff.port})
	portal_handoff_ready.emit(handoff)
	return true

func select_portal_workshop(default_mods: String,settings_directory: String)->bool:
	if not portal_workshop_selection.is_empty():
		mods_directory=str(portal_workshop_selection.modsDirectory)
		disabled_mods=portal_workshop_selection.disabledMods.duplicate(true)
		portal_workshop_selection.clear()
		return true
	# An externally configured portal has no source-session selection. Read
	# non-secret settings only; this path never imports or unlocks credentials.
	var portal_settings:=Settings.new()
	if not portal_settings.open(settings_directory,default_mods):return false
	mods_directory=str(portal_settings.state.get("modsDirectory",default_mods))
	disabled_mods=portal_settings.state.get("disabledMods",[]).duplicate(true)
	portal_settings.close()
	return true

func bind_repository(owner: Node)->void:
	repository=owner
	repository.progress_detail.connect(func(state: Dictionary):
		if not is_same(repository,owner) or phase in ["closed","failed"]:return
		resource_progress_snapshot=ResourceProgress.finite_resource_progress(state)
		resource_progress_detail.emit(resource_progress_snapshot.duplicate(true) if resource_progress_snapshot is Dictionary else {}))
	repository.progress.connect(func(current: String,completed: int,total: int):resource_progress.emit(current,completed,total))
	repository.diagnostic_detail.connect(func(event: Dictionary):diagnostic_event.emit(event.duplicate(true)))
	repository.diagnostic.connect(func(code: String,reason: String):diagnostic.emit(code,reason))

func _decode_object_update(packet: PackedByteArray,build: Dictionary,providers: Dictionary)->Dictionary:
	var began:=FrameProfile.begin()
	var update:=ObjectUpdates.decode_packet(packet,build,providers)
	FrameProfile.finish("network_object_decode_ms",began)
	return update

func decode_object_packet(packet: PackedByteArray,predecoded: Dictionary={})->bool:
	if object_rules==null:
		if pending_object_packets.size()>=256 or pending_object_bytes+packet.size()>16*1024*1024:return fail("Native object-update backlog exceeds bound")
		pending_object_packets.append({"packet":packet.duplicate(),"decoded":predecoded.duplicate(true)});pending_object_bytes+=packet.size()
		return true
	var update: Dictionary=predecoded if not predecoded.is_empty() else _decode_object_update(packet,remote_build,object_rules.providers())
	if update.has("error"):invalid_game_message(packet,str(update.error));return true
	if not update.get("complete",false):
		var event: Dictionary={"code":"network.object-record-unhandled"}
		if update.get("unhandled") is Dictionary:event.merge(update.unhandled,true)
		diagnostic_event.emit(event)
	if FrameProfile.enabled:
		FrameProfile.count("count_network_import_records",update.get("records",[]).size())
		FrameProfile.count("count_network_import_registry_rows",world_state.registry.size())
	var import_began:=FrameProfile.begin()
	var accepted: bool=world_state.apply_updates(update)
	FrameProfile.finish("network_world_import_ms",import_began)
	FrameProfile.count("count_network_object_packets",1)
	if not accepted:
		last_import_failure={"code":"network.object-import-failed","reason":client_failure_text(world_state.error)}
		var import_event: Dictionary={"code":"network.object-import-failed","reason":str(world_state.error)}
		diagnostic_event.emit(import_event)
		diagnostic.emit(str(import_event.code),str(import_event.reason))
		return fail(str(world_state.error))
	if world_state.script_targeting==null:session_script_targeting=null
	for event in world_state.world_diagnostics:diagnostic_event.emit(event.duplicate(true))
	world_revision+=1
	var visibility_began:=FrameProfile.begin()
	var frames: Array=visibility_frames.tile_frames(world_state,update,area_generation,text_event_connection)
	FrameProfile.finish("network_visibility_events_ms",visibility_began)
	for frame in frames:visibility_frame_ready.emit(frame)
	object_updates_ready.emit(update)
	if phase=="playing":
		var scene_began:=FrameProfile.begin()
		var changes:=scene_changes_with_combat_scope()
		FrameProfile.finish("network_scene_events_ms",scene_began)
		scene_changes_ready.emit(changes)
	var level_reply: Dictionary=level_up.observe(world_state.registry.get(world_state.local_object_id,{}),world_state.area_id,remote_build)
	if not level_reply.is_empty():present_level_up_reply(level_reply)
	if phase=="playing":drain_creature_voice()
	return true

func scene_changes_with_combat_scope()->Array:
	# Saved raw-combat-events captures from the accepted World, before a later
	# coalesced snapshot can change cast inputs or a proxy's native lifetime.
	var output: Array=[]
	for event in world_state.presentation_changes:
		var row: Dictionary=event.duplicate(true)
		var actor: Variant=world_state.registry.get(row.get("id"))
		var current: bool=actor is Dictionary and not bool(actor.get("replicationRemoved",false)) and actor.get("areaId")==world_state.area_id
		if row.get("action") in ["cast-animation","attack-animation"] and not current:continue
		output.append(row)
		if not current:continue
		if row.get("action")=="movement" and row.get("changes") is Dictionary and row.changes.has("animation") and actor.get("objectType")==5:
			var replicated: Variant=actor.get("replicated")
			var cast: Variant=replicated.get("cast") if replicated is Dictionary else null
			var structured: bool=cast is Dictionary or cast is Array
			if structured or not (cast is float and is_nan(cast)) and cast:
				output.append({"action":"cast-state","id":row.id,"lifetime":actor.get("nativeLifetime"),"animation":row.changes.animation,"cast":cast.duplicate(true) if structured else cast,"ageMs":0})
		elif row.get("action") in ["cast-animation","attack-animation"]:
			row.lifetime=actor.get("nativeLifetime")
			row.ageMs=0
	return output

func movement_from_presentation(events: Array)->Array[Dictionary]:
	# Presentation events are constructed by the accepted World transaction.
	var rows: Array[Dictionary]=[]
	for event in events:
		if not event is Dictionary or str(event.get("action",""))!="movement":continue
		var id:=int(event.get("id",-1))
		var actor: Dictionary=world_state.registry.get(id,{})
		if int(actor.get("objectType",0))!=5 or bool(actor.get("replicationRemoved",false)) or int(actor.get("areaId",-1))!=world_state.area_id:continue
		movement_serial+=1
		rows.append({"id":id,"revision":movement_serial,"created":bool(event.get("created",false)),"object":actor,"changes":event.get("changes",{}).duplicate(true),"initial":actor.get("replicated",{}).duplicate(true)})
	return rows

func drain_creature_voice()->void:
	if phase!="playing" or pending_creature_voice.is_empty():return
	var waiting: Array[Dictionary]=pending_creature_voice;pending_creature_voice=[]
	for entry in waiting:
		if int(entry.areaId)!=world_state.area_id:continue
		var actor: Dictionary=world_state.registry.get(int(entry.message.objectId),{})
		if actor.is_empty() or int(actor.get("nativeLifetime",-1))!=int(entry.lifetime) or int(actor.get("objectType",0))!=5 or bool(actor.get("replicationRemoved",false)):continue
		creature_voice_ready.emit(entry.message)

func present_level_up_reply(reply: Dictionary)->void:
	if bool(reply.get("accepted",false)) and str(reply.get("operation",""))=="begin" and published_revision!=world_revision:
		pending_level_up_presentation=reply.duplicate(true)
	else:ui_message_ready.emit(reply)

func received_text_message(message: Dictionary)->Dictionary:
	# Capture after the canonical World mutation and before any coalesced view.
	var captured: Dictionary=text_events.capture(world_state,message,area_generation,text_event_connection)
	if not captured.get("ready",false):return message
	var output: Dictionary=message.duplicate(true)
	output.nativeTextEvent=captured.value
	return output

func level_up_input(request: Dictionary)->Dictionary:
	if phase!="playing" or peer==null:return {"error":"Native level-up session is unavailable"}
	var actor: Dictionary=world_state.registry.get(world_state.local_object_id,{})
	var old_world: RefCounted=world_state
	var old_peer: RefCounted=peer
	var old_generation:=area_generation
	var old_scope: Array=LevelUpTransaction.actor_scope(actor,world_state.area_id)
	var outcome: Dictionary=level_up.request(request,actor,world_state.area_id,object_rules,remote_build,Time.get_ticks_msec())
	if outcome.has("error"):return outcome
	for packet in outcome.packets:
		if not await old_peer.send_game_message(packet):
			if str(request.get("operation",""))!="cancel":
				var rejection: Dictionary=level_up.send_failed()
				if not rejection.is_empty():ui_message_ready.emit(rejection)
			return {"error":"Native level-up request could not be sent"}
	if str(request.get("operation",""))=="cancel":
		var current: Dictionary=world_state.registry.get(world_state.local_object_id,{})
		if phase!="playing" or world_state!=old_world or peer!=old_peer or area_generation!=old_generation or LevelUpTransaction.actor_scope(current,world_state.area_id)!=old_scope:return {"error":"Level-up cancellation scope retired"}
		level_up.complete_cancel(int(outcome.get("cancelDraftToken",-1)),outcome.get("cancelScope",[]))
		return {"cancelled":true,"sent":true,"serverAcknowledged":false}
	return {"sent":true}

func bind_direct_world_publisher(receiver: Callable,borrow_static_nested: bool=false)->void:
	_direct_world_publisher=receiver
	_direct_world_borrows_static_nested=borrow_static_nested

func _world_projection_scope(delivery: int)->Array[int]:
	return [delivery,Engine.get_process_frames(),world_state.get_instance_id(),world_revision,
		area_generation,world_state.area_id,world_state.local_object_id]

func begin_immediate_world_projection()->Array[int]:
	if not processing_delivery or _world_delivery_serial<1 or phase!="playing":return []
	var scope:=_world_projection_scope(_world_delivery_serial)
	_immediate_world_projection={"scope":scope}
	FrameProfile.count("count_network_immediate_world_projections",1)
	return scope

func world_projection_metadata()->Array:
	# Disclosure and GUI context may advance on presentation/query paths.
	# The clock's connection bind is independent from its transaction revision.
	var disclosure: RefCounted=world_state.disclosures
	var clock: RefCounted=world_state.clock_lifecycle
	return [disclosure.get_instance_id(),disclosure.serial,disclosure.identities.size(),
		gui_access.get_instance_id(),gui_access.sequence,gui_access.control_lifetime,
		clock.get_instance_id(),clock.epoch,clock.connection,clock._revision]

func acknowledge_immediate_world_projection(scope: Array[int],metadata: Array,current: Callable,repeat: Callable)->void:
	if scope.is_empty() or not processing_delivery or scope!=_world_projection_scope(_world_delivery_serial):return
	if _immediate_world_projection.get("scope")!=scope:return
	FrameProfile.count("count_network_immediate_world_acks",1)
	if metadata!=world_projection_metadata():return
	_immediate_world_projection={"scope":scope,"metadata":metadata,"current":current,"repeat":repeat}

func _periodic_projection_reuse(delivery: int)->Callable:
	if delivery<1 or delivery!=_world_delivery_serial or _immediate_world_projection.is_empty():return Callable()
	var prior: Array=_immediate_world_projection.scope
	if prior!=_world_projection_scope(delivery):return Callable()
	FrameProfile.count("count_network_periodic_same_revision",1)
	if not _direct_world_publisher.is_valid() or world_presentation_ready.has_connections():return Callable()
	if not _immediate_world_projection.has("repeat") or _immediate_world_projection.metadata!=world_projection_metadata():return Callable()
	FrameProfile.count("count_network_periodic_matching_metadata",1)
	return _immediate_world_projection.repeat if _immediate_world_projection.current.call() else Callable()

func publish_world_if_ready()->void:
	_publish_world_for_delivery(0)

func _publish_world_for_delivery(delivery: int)->void:
	if phase!="playing" or catalog==null or published_revision==world_revision or Time.get_ticks_msec()-last_presentation_ms<200:return
	var repeat:=_periodic_projection_reuse(delivery)
	var direct_receiver:=_direct_world_publisher
	var static_rows: RawWorldDeltas.StaticRows
	var data: Dictionary={}
	if not repeat.is_valid():
		var began:=FrameProfile.begin()
		# Only the private synchronous renderer sink can consume the proof.
		if direct_receiver.is_valid() and not world_presentation_ready.has_connections():
			static_rows=RawWorldDeltas.StaticRows.new(_direct_world_borrows_static_nested)
		data=presentation() if static_rows==null else _direct_presentation(false,static_rows)
		FrameProfile.finish("network_periodic_projection_ms",began)
		FrameProfile.count("count_network_periodic_projections",1)
		if data.has("error"):return
	last_presentation_ms=Time.get_ticks_msec()
	published_revision=world_revision
	if repeat.is_valid():
		FrameProfile.count("count_network_periodic_reused_projection",1)
		repeat.call()
	else:
		if direct_receiver.is_valid():direct_receiver.call(data,static_rows)
		if world_presentation_ready.has_connections():
			# The direct receiver can synchronously attach a public listener.
			# Give that listener the detached projection it normally receives.
			if static_rows!=null and static_rows.borrows_static_nested:
				data=data.duplicate()
				data.objects=data.objects.duplicate(true)
			world_presentation_ready.emit(data)
	if not pending_level_up_presentation.is_empty():
		var reply: Dictionary=pending_level_up_presentation
		pending_level_up_presentation={}
		var current: Dictionary=preload("res://systems/native_data/level_up_received_context.gd").snapshot(world_state.registry.get(world_state.local_object_id,{}))
		if level_up.draft.is_empty() or not current.get("ready",false) or level_up.draft.get("snapshot")!=current.get("value"):
			level_up.reset()
			reply.accepted=false;reply.result={};reply.text="Character changed; reopen Level Up"
		ui_message_ready.emit(reply)

func gui_access_context()->Dictionary:
	return {"actor":world_state.registry.get(world_state.local_object_id,{}),"actorId":world_state.local_object_id,"areaId":world_state.area_id,"areaGeneration":area_generation}

func gui_panel_input(request: Dictionary)->Dictionary:
	# network_game_session.mjs::hudPanel context-attempt/blocked-attempt.
	if phase!="playing" or peer==null:return {"error":"Native GUI panel session is unavailable"}
	var actor_id:=int(world_state.local_object_id)
	var actor: Dictionary=world_state.registry.get(actor_id,{})
	var area_id:=int(world_state.area_id)
	if not bool(request.get("open",false)) or int(request.get("actorId",-1))!=actor_id or int(request.get("areaId",-1))!=area_id or int(request.get("areaGeneration",request.get("generation",-1)))!=area_generation or int(actor.get("objectType",0))!=5 or int(actor.get("areaId",-1))!=area_id or bool(actor.get("replicationRemoved",false)) or bool(actor.get("destroyed",false)):
		return {"error":"Native GUI panel actor or area has retired"}
	var old_peer: RefCounted=peer
	var old_world: RefCounted=world_state
	var old_generation: int=area_generation
	var panel:=str(request.get("panel",""))
	var panel_id:=int(request.get("guiPanelId",-1))
	var target_id:=int(request.get("targetId",-1))
	var revision: Variant=request.get("accessRevision")
	var serial: Variant=request.get("attemptSerial")
	if not GuiAccess.State.integer(revision) or int(revision)!=gui_access.sequence or not GuiAccess.State.integer(serial) or int(serial)<=0:
		return {"error":"Native GUI panel attempt is stale"}
	var scope: Array=[peer.get_instance_id(),world_state.get_instance_id(),area_generation,actor_id,int(actor.get("nativeLifetime",0)),int(actor.get("clientKnownLifetime",0))]
	if scope!=gui_panel_attempt_scope:
		gui_panel_attempt_scope=scope;gui_panel_attempt_last=0
	if int(serial)<=gui_panel_attempt_last:return {"error":"Native GUI panel attempt has retired"}
	var packet: Dictionary={}
	var blocked:=false
	var selected_target_type: int=-1
	var selected_target_lifetime: int=-1
	var include_position: bool=AreaState.at_least(remote_build if not remote_build.is_empty() else local_build,35)
	if panel=="context-attempt":
		var source_kind:=str(request.get("sourceKind",""))
		if not GuiAccess.CONTEXT_SOURCES.has(source_kind) or panel_id!=int(GuiAccess.CONTEXT_SOURCES[source_kind][0]):return {"error":"Native world-context source is unavailable"}
		var position: Variant=request.get("position")
		if not position is Array or position.size()!=3:return {"error":"Native world-context position is unavailable"}
		if source_kind=="ground":
			if target_id!=GuiAccess.INVALID:return {"error":"Native ground-context target is unavailable"}
		else:
			var target: Dictionary=world_state.registry.get(target_id,{})
			if int(target.get("id",-1))!=target_id or int(target.get("objectType",0))!=int(GuiAccess.CONTEXT_SOURCES[source_kind][1]) or int(target.get("areaId",-1))!=area_id or bool(target.get("replicationRemoved",false)) or bool(target.get("destroyed",false)):
				return {"error":"Native world-context target is unavailable"}
			selected_target_type=int(target.get("objectType",-1))
			selected_target_lifetime=int(target.get("nativeLifetime",target.get("clientKnownLifetime",-1)))
		blocked=gui_access.matches(panel_id,target_id)
		packet=GuiAccess.attempt_request(panel_id,target_id,include_position) if blocked else GuiAccess.context_request(source_kind,target_id,position,include_position)
	elif panel=="blocked-attempt":
		if panel_id not in [5,6,7,8] or not gui_access.matches(panel_id,target_id):return {"error":"Native blocked-panel attempt is unavailable"}
		if panel_id!=8 and target_id!=GuiAccess.INVALID:return {"error":"Native blocked-panel target is unavailable"}
		if panel_id==8:
			var target: Dictionary=world_state.registry.get(target_id,{})
			if int(target.get("objectType",0))!=5 or int(target.get("areaId",-1))!=area_id or bool(target.get("replicationRemoved",false)) or bool(target.get("destroyed",false)):
				return {"error":"Native character-record target has retired"}
			if target_id!=actor_id or request.has("recordActorLifetime") or request.has("recordTargetLifetime"):
				if int(request.get("recordActorLifetime",-1))!=int(actor.get("clientKnownLifetime",0)) or int(request.get("recordTargetLifetime",-1))!=int(target.get("clientKnownLifetime",0)):
					return {"error":"Native character-record disclosure scope has retired"}
		blocked=true
		packet=GuiAccess.attempt_request(panel_id,target_id,include_position)
	else:return {"error":"Unsupported native GUI panel attempt"}
	if packet.has("error"):return packet
	gui_panel_attempt_last=int(serial)
	if not await old_peer.send_game_message(packet.bytes):return {"error":"Native GUI panel request failed"}
	var current_actor: Dictionary=input_actor(request)
	if peer!=old_peer or world_state!=old_world or area_generation!=old_generation or current_actor.is_empty() or int(current_actor.get("nativeLifetime",0))!=int(actor.get("nativeLifetime",0)) or int(current_actor.get("clientKnownLifetime",0))!=int(actor.get("clientKnownLifetime",0)) or bool(current_actor.get("destroyed",false)):
		return {"error":"Native GUI panel owner has retired"}
	if panel=="context-attempt" and selected_target_type>=0:
		var current_target: Dictionary=world_state.registry.get(target_id,{})
		if current_target.is_empty() or int(current_target.get("id",-1))!=target_id or int(current_target.get("objectType",-1))!=selected_target_type or selected_target_lifetime>=0 and int(current_target.get("nativeLifetime",current_target.get("clientKnownLifetime",-1)))!=selected_target_lifetime or int(current_target.get("areaId",-1))!=area_id or bool(current_target.get("replicationRemoved",false)) or bool(current_target.get("destroyed",false)):
			return {"error":"Native world-context owner has retired"}
	if panel=="blocked-attempt" and panel_id==8 and hud_record_target(request,current_actor).has("error"):return {"error":"Native character-record target has retired"}
	return {"sent":true,"blocked":blocked,"serverAcknowledged":false}

func script_target_input(request: Dictionary)->Dictionary:
	if phase!="playing" or peer==null:return {"error":"Native script targeting is unavailable"}
	var actor_id:=int(world_state.local_object_id)
	var area_id:=int(world_state.area_id)
	var actor: Dictionary=world_state.registry.get(actor_id,{})
	var mode: Variant=session_script_targeting
	if not mode is Dictionary or int(request.get("actorId",-1))!=actor_id or int(request.get("areaId",-1))!=area_id or int(actor.get("objectType",0))!=5 or int(actor.get("areaId",-1))!=area_id or bool(actor.get("replicationRemoved",false)) or int(mode.get("version",-1))!=int(request.get("version",-2)) or int(mode.get("areaId",-1))!=area_id or int(mode.get("actorId",-1))!=actor_id:
		return {"error":"Server target selection is stale"}
	var target_id:=int(request.get("targetId",NetworkTargeting.INVALID))
	if not NetworkTargeting.valid_uint(target_id):return {"error":"Invalid native script target ID"}
	var target: Dictionary=world_state.registry.get(target_id,{}) if target_id!=NetworkTargeting.INVALID else {}
	if target_id!=NetworkTargeting.INVALID:
		var location: Variant=target.get("inventoryLocation")
		var owned_item:=int(target.get("objectType",0))==6 and (int(target.get("equipmentOwnerId",-1))==actor_id or location is Dictionary and int(location.get("ownerId",-1))==actor_id)
		if target.is_empty() or bool(target.get("replicationRemoved",false)) or int(target.get("areaId",-1))!=area_id and not owned_item:return {"error":"Server target is unavailable"}
	if not NetworkTargeting.allowed(mode,int(target.get("objectType",2))):return {"error":"Server target type is not allowed"}
	var packet: Dictionary=NetworkTargeting.selection_request(target_id,request.get("position"))
	if packet.has("error"):return packet
	# The old session world retires the mode before sending. The frontend's
	# separate presentation world keeps it until a successful send below.
	session_script_targeting=null
	if not await peer.send_game_message(packet.bytes):return {"error":"Native script target selection could not be sent"}
	# network_frontend.js clears the selected mode only after a successful send,
	# and only if a newer server instruction has not replaced it meanwhile.
	var current_mode: Variant=world_state.script_targeting
	if current_mode is Dictionary and int(current_mode.get("version",-1))==int(request.get("version",-2)) and int(current_mode.get("areaId",-1))==area_id and int(current_mode.get("actorId",-1))==actor_id and int(world_state.area_id)==area_id and int(world_state.local_object_id)==actor_id:
		world_state.script_targeting=null;world_revision+=1
	return {"sent":true}

func presentation(prepare_area: bool=false)->Dictionary:
	var data: Dictionary=world_state.presentation(prepare_area)
	return _presentation_ui(data)

func _direct_presentation(prepare_area: bool,static_rows: RawWorldDeltas.StaticRows)->Dictionary:
	return _presentation_ui(world_state._project_presentation(prepare_area,static_rows))

func _presentation_ui(data: Dictionary)->Dictionary:
	if not data.has("error"):
		data.ui.guiPanelAccess=gui_access.snapshot(gui_access_context())
	return data

func set_device_metrics(metrics: Dictionary)->bool:
	if phase in ["closed","failed"]:return false
	var selected: Dictionary={}
	for key in DeviceProperties.KEYS:
		if not metrics.has(key):return false
		var value: Variant=metrics[key]
		if not value is int or DeviceProperties.request(key,int(value)).has("error"):return false
		selected[key]=int(value)
	device_metrics=selected
	if peer!=null and peer.admitted:return await flush_device_metrics()
	return true

func set_login_waypoint(value: String)->bool:
	if phase not in ["idle","connecting"] or RuntimeMessages.login_waypoint_response(value).has("error"):return false
	login_waypoint=value
	return true

func saved_character_list()->Dictionary:
	if character_vault==null:return {"error":"The Godot character vault is unavailable."}
	return character_vault.list()

func saved_character_bytes(id: String)->Dictionary:
	if character_vault==null:return {"error":"The Godot character vault is unavailable."}
	return character_vault.export_character(id)

func request_character_export()->Dictionary:
	if not phase in ["playing","area-loading"] or not character_confirmed or character_vault==null or peer==null:
		return {"error":"Native character export is unavailable"}
	if pending_character_export:return {"accepted":true,"alreadyPending":true}
	if character_export_uncertain:return {"error":"The previous character export is still awaiting its server reply"}
	pending_character_export=true
	character_export_deadline=Time.get_ticks_msec()+character_export_timeout_ms
	character_export_status_ready.emit({"state":"pending","text":"Saving character…"})
	if not await peer.send_game_message(PackedByteArray([112,6,31])):
		pending_character_export=false
		character_export_deadline=0
		return {"error":"The character export request could not be sent."}
	return {"accepted":true,"alreadyPending":false}

func receive_character_export(message: Dictionary)->void:
	var bytes: PackedByteArray=message.get("data",PackedByteArray())
	var saved: Dictionary={"error":"The Godot character vault is unavailable."} if character_vault==null or not character_confirmed else character_vault.store(message,saved_character_id)
	bytes.fill(0)
	message.data=PackedByteArray()
	pending_character_export=false
	character_export_deadline=0
	character_export_uncertain=false
	if not saved.get("ready",false):
		character_export_status_ready.emit({"state":"failed","text":str(saved.get("error","The server character export could not be saved."))})
		return
	var entry: Dictionary=saved.entry.duplicate(true)
	saved_character_id=str(entry.id)
	character_export_status_ready.emit({"state":"saved","text":"Saved "+str(entry.name),"entry":entry})
	if phase not in ["closed","failed"]:ui_message_ready.emit({"kind":"character-saved","entry":entry})

func walk_to(position: Array,run: bool=true)->Dictionary:
	if phase!="playing" or peer==null:return {"error":"Native player is not in an admitted area"}
	var actor_id: int=int(world_state.local_object_id)
	var actor: Dictionary=world_state.registry.get(actor_id,{})
	if int(actor.get("objectType",0))!=5 or int(actor.get("areaId",0))!=world_state.area_id or bool(actor.get("replicationRemoved",false)):return {"error":"Native controlled creature is not ready for input"}
	var sequence: int=(int(movement_sequences.get(actor_id,0))+1)&255
	var packet: Dictionary=PlayerRequests.waypoint(world_state.area_id,position,sequence,run)
	if packet.has("error"):return packet
	movement_sequences[actor_id]=sequence
	if not await peer.send_game_message(packet.bytes):return {"error":"Native waypoint send failed"}
	return {"sequence":sequence}

func inventory_window(opened: bool,owner_id: int=-1,role: String="primary",window_serial: int=-1,receipt_serial: int=-1)->Dictionary:
	if phase!="playing" or peer==null:return {"error":"Native inventory is not in an admitted area"}
	var request_world: RefCounted=world_state
	var request_peer: RefCounted=peer
	var request_generation: int=area_generation
	var actor_id: int=int(world_state.local_object_id)
	var actor: Dictionary=world_state.registry.get(actor_id,{})
	if int(actor.get("objectType",0))!=5 or int(actor.get("areaId",0))!=world_state.area_id or bool(actor.get("replicationRemoved",false)):return {"error":"Native inventory owner is unavailable"}
	if owner_id<0:owner_id=actor_id
	match role:
		"primary":
			if owner_id!=actor_id:return {"error":"Native inventory owner is unavailable"}
		"alternate":
			if not world_state.require_alternate_window(owner_id,window_serial,receipt_serial):return {"error":"Native alternate inventory window is retired"}
		"rejected":
			var rejected: Variant=world_state.rejected_inventory_window
			if opened or not rejected is Dictionary or int(rejected.get("ownerId",-1))!=owner_id or int(rejected.get("receiptSerial",-1))!=receipt_serial or int(rejected.get("actorId",-1))!=actor_id or int(rejected.get("areaId",-1))!=world_state.area_id:return {"error":"Native inventory rejection reply is retired"}
		_:return {"error":"Native inventory role is unavailable"}
	var packet: Dictionary=PlayerRequests.inventory_window(owner_id,opened)
	if packet.has("error") or not await peer.send_game_message(packet.bytes):return {"error":"Native inventory window request failed"}
	if world_state!=request_world or peer!=request_peer or input_actor({"actorId":actor_id,"areaId":request_world.area_id,"areaGeneration":request_generation}).is_empty():return {"error":"Native inventory controlled actor changed"}
	if role=="alternate" and not world_state.require_alternate_window(owner_id,window_serial,receipt_serial):return {"error":"Native alternate inventory window is retired"}
	if role=="rejected":
		var current_rejection: Variant=world_state.rejected_inventory_window
		if not current_rejection is Dictionary or int(current_rejection.get("ownerId",-1))!=owner_id or int(current_rejection.get("receiptSerial",-1))!=receipt_serial or int(current_rejection.get("actorId",-1))!=actor_id or int(current_rejection.get("areaId",-1))!=request_world.area_id:return {"error":"Native inventory rejection reply changed"}
	if role=="alternate" and not opened:world_state.close_alternate_window();world_revision+=1
	if role=="rejected":world_state.rejected_inventory_window=null
	return {"sent":true}

func inventory_panel(panel: int,owner_id: int=-1,role: String="primary",window_serial: int=-1,receipt_serial: int=-1)->Dictionary:
	if phase!="playing" or peer==null:return {"error":"Native inventory is not in an admitted area"}
	var request_world: RefCounted=world_state
	var request_peer: RefCounted=peer
	var request_generation: int=area_generation
	var actor_id: int=int(world_state.local_object_id)
	var actor: Dictionary=world_state.registry.get(actor_id,{})
	if int(actor.get("objectType",0))!=5 or int(actor.get("areaId",0))!=world_state.area_id or bool(actor.get("replicationRemoved",false)):return {"error":"Native inventory owner is unavailable"}
	if owner_id<0:owner_id=actor_id
	if role=="alternate":
		if not world_state.require_alternate_window(owner_id,window_serial,receipt_serial):return {"error":"Native alternate inventory window is retired"}
	elif role!="primary" or owner_id!=actor_id:return {"error":"Native inventory panel owner is unavailable"}
	var packet: Dictionary=PlayerRequests.inventory_panel(panel,role=="primary")
	if packet.has("error"):return {"error":"Native inventory panel request failed"}
	world_state.clear_repository_view(role=="primary");world_revision+=1
	if not await peer.send_game_message(packet.bytes):return {"error":"Native inventory panel request failed"}
	if world_state!=request_world or peer!=request_peer or input_actor({"actorId":actor_id,"areaId":request_world.area_id,"areaGeneration":request_generation}).is_empty():return {"error":"Native inventory controlled actor changed"}
	if role=="alternate" and not world_state.require_alternate_window(owner_id,window_serial,receipt_serial):return {"error":"Native alternate inventory window is retired"}
	return {"sent":true}

func container_input(operation: String,target_id: int,actor_id: int)->Dictionary:
	if phase!="playing" or peer==null:return {"error":"Native container is not in an admitted area"}
	var controlled:=int(world_state.local_object_id)
	var actor: Dictionary=world_state.registry.get(controlled,{})
	if actor_id!=controlled or int(actor.get("objectType",0))!=5 or int(actor.get("areaId",0))!=world_state.area_id or bool(actor.get("replicationRemoved",false)) or target_id==ContainerStatus.INVALID or target_id!=int(world_state.containers.get("C",ContainerStatus.INVALID)):return {"error":"Native container request is stale"}
	var packet: Dictionary=ContainerStatus.request(operation,target_id)
	if packet.has("error"):return packet
	if operation!="close":world_state.clear_container_view();world_revision+=1
	if not await peer.send_game_message(packet.bytes):return {"error":"Native container request failed"}
	if operation=="close":world_state.apply_container_status({"targetId":ContainerStatus.INVALID,"primary":true});world_revision+=1
	return {"sent":true}

func store_input(request: Dictionary)->Dictionary:
	if phase!="playing" or peer==null:return {"error":"Native store is not in an admitted area"}
	var actor_id:=int(world_state.local_object_id)
	var actor: Dictionary=world_state.registry.get(actor_id,{})
	if int(request.get("actorId",actor_id))!=actor_id or int(actor.get("objectType",0))!=5 or int(actor.get("areaId",0))!=world_state.area_id or bool(actor.get("replicationRemoved",false)):return {"error":"Native store actor is unavailable"}
	var store_state: Variant=world_state.store
	if not store_state is Dictionary or not bool(store_state.get("open",false)) or int(store_state.get("generation",-1))!=int(request.get("storeGeneration",-1)):return {"error":"Native store request is stale"}
	var operation:=str(request.get("operation",""));var item_id:=int(request.get("itemId",-1))
	if operation in ["buy","sell","identify"]:
		var item: Dictionary=world_state.registry.get(item_id,{})
		var location: Variant=item.get("inventoryLocation")
		var channel:=str(location.get("channel","")) if location is Dictionary else ""
		var owned:=channel in ["R","I"] and location is Dictionary and int(location.get("ownerId",-1))==actor_id
		var stock:=false
		if channel=="M" and world_state.inventories.get("M") is Dictionary:
			for entry in world_state.inventories.M.get("entries",[]):
				if int(entry.get("id",-1))==item_id:stock=true;break
		if int(item.get("objectType",0))!=6 or bool(item.get("replicationRemoved",false)) or not (stock if operation=="buy" else owned):return {"error":"Native store item is unavailable"}
	elif operation=="panel":
		if int(request.get("panel",-1))<0 or int(request.get("panel",-1))>=5:return {"error":"Invalid native store panel"}
	elif operation=="page":
		var count:=int(world_state.inventories.get("M",{}).get("pageCount",1))
		if int(request.get("page",-1))<0 or int(request.get("page",-1))>=count:return {"error":"Invalid native store page"}
	elif operation!="close":return {"error":"Invalid native store operation"}
	var packet: Dictionary=NetworkStore.request(operation,item_id,int(request.get("x",255)),int(request.get("y",255)),NetworkStore.INVALID,int(request.get("panel",-1)),int(request.get("page",-1)))
	if packet.has("error"):return packet
	if not await peer.send_game_message(packet.bytes):return {"error":"Native store request failed"}
	if operation=="identify":
		var examine: Dictionary=await target_action(item_id,"examine")
		if examine.has("error"):return examine
	elif operation=="close":
		world_state.apply_store({"kind":"store-close"});world_revision+=1
		ui_message_ready.emit({"kind":"store-close"})
	elif operation in ["panel","page"]:
		if world_state.inventories.get("M") is Dictionary:world_state.inventories.M.entries=[]
		if operation=="panel":store_state.panel=int(request.panel);store_state.page=0
		else:store_state.page=int(request.page)
		world_revision+=1
	return {"sent":true}

func barter_input(request: Dictionary)->Dictionary:
	if phase!="playing" or peer==null:return {"error":"Native barter is not in an admitted area"}
	var actor_id:=int(world_state.local_object_id)
	var actor: Dictionary=world_state.registry.get(actor_id,{})
	if int(request.get("actorId",actor_id))!=actor_id or int(actor.get("objectType",0))!=5 or int(actor.get("areaId",0))!=world_state.area_id or bool(actor.get("replicationRemoved",false)):return {"error":"Native barter actor is unavailable"}
	var operation:=str(request.get("operation",""));var target_id:=int(request.get("targetId",NetworkBarter.INVALID));var item_id:=int(request.get("itemId",NetworkBarter.INVALID))
	var state: Variant=world_state.barter
	if operation=="start":
		var target: Dictionary=world_state.registry.get(target_id,{})
		if int(target.get("objectType",0))!=5 or int(target.get("areaId",0))!=world_state.area_id or bool(target.get("replicationRemoved",false)):return {"error":"Native barter target is unavailable"}
		if item_id!=NetworkBarter.INVALID:
			var item: Dictionary=world_state.registry.get(item_id,{})
			var location: Variant=item.get("inventoryLocation")
			if int(item.get("objectType",0))!=6 or bool(item.get("replicationRemoved",false)) or not location is Dictionary or str(location.get("channel",""))!="R" or int(location.get("ownerId",-1))!=actor_id:return {"error":"Native barter item is unavailable"}
	else:
		if not state is Dictionary or int(state.get("serial",-1))!=int(request.get("serial",-1)) or int(state.get("actorId",-1))!=actor_id or int(state.get("areaId",-1))!=world_state.area_id or not bool(state.get("open",false)) and not (operation=="window" and not bool(request.get("value",false))) or target_id!=NetworkBarter.INVALID and target_id!=int(state.get("partnerId",-1)):return {"error":"Native barter view is stale"}
		if operation in ["add","remove","move"]:
			var item: Dictionary=world_state.registry.get(item_id,{})
			var location: Variant=item.get("inventoryLocation")
			var channel: String="R" if operation=="add" else "B"
			var present:=false
			for entry in world_state.inventories.get(channel,{}).get("entries",[]):
				if int(entry.get("id",-1))==item_id:present=true;break
			if bool(state.get("ownLocked",false)) or int(item.get("objectType",0))!=6 or bool(item.get("replicationRemoved",false)) or not location is Dictionary or int(location.get("ownerId",-1))!=actor_id or str(location.get("channel",""))!=channel or not present:return {"error":"Native barter item selection is stale or locked"}
		elif operation=="accept" and (not bool(state.get("ownLocked",false)) or not bool(state.get("otherLocked",false))):return {"error":"Both native barter offers must be locked"}
	var packet: Dictionary=NetworkBarter.request(operation,target_id,item_id,bool(request.get("value",false)),int(request.get("x",255)),int(request.get("y",255)))
	if packet.has("error"):return packet
	if not await peer.send_game_message(packet.bytes):return {"error":"Native barter send failed"}
	return {"sent":true}

func nui_input(request: Dictionary)->Dictionary:
	if phase!="playing" or peer==null:return {"error":"Native NUI input is not in an admitted area"}
	var token:=int(request.get("token",0));var serial:=int(request.get("serial",-1))
	if not nui_state.windows.has(token) or int(nui_state.windows[token].serial)!=serial:return {"error":"Native NUI input belongs to a closed or replaced window"}
	var raw_events: Variant=request.get("events",[]);var raw_binds: Variant=request.get("binds",[])
	if not raw_events is Array or not raw_binds is Array:return {"error":"Invalid native NUI input"}
	var events: Array=[];var binds: Array=[]
	for value in raw_events:
		if not value is Dictionary:return {"error":"Invalid native NUI event"}
		var entry: Dictionary=value.duplicate(true);entry.token=token;events.append(entry)
	for value in raw_binds:
		if not value is Dictionary:return {"error":"Invalid native NUI bind"}
		var entry: Dictionary=value.duplicate(true);entry.token=token;binds.append(entry)
	var build: Dictionary=remote_build if not remote_build.is_empty() else local_build
	if not build.has("number") or not build.has("revision") or not build.has("postfix"):return {"error":"Native NUI server build is unavailable"}
	var indexed: bool=int(build.number)>=8193 and (int(build.revision)>35 or int(build.revision)==35 and int(build.postfix)>=0)
	for entry in binds:
		var index:=int(entry.get("index",-1))
		if index<0 or bool(entry.get("wholeValue",false)): continue
		var current: Variant=nui_state.windows[token].bindings.get(str(entry.bind))
		if not current is Array or index>=current.size():return {"error":"NUI binding index is stale"}
	var packet: Dictionary=NetworkNui.input_packet(token,events,binds,indexed)
	if packet.has("error"):return packet
	for entry in binds:
		var value: Variant=entry.get("value")
		var index: int=-1 if bool(entry.get("wholeValue",false)) else int(entry.get("index",-1))
		nui_state.local_bind(token,str(entry.bind),value,index)
	if not binds.is_empty():world_revision+=1
	if not await peer.send_game_message(packet.bytes):return {"error":"Native NUI input send failed"}
	if not nui_state.windows.has(token) or int(nui_state.windows[token].serial)!=serial:return {"sent":true}
	for entry in events:
		if str(entry.get("type",""))=="close":nui_state.receive({"kind":"nui-destroy","token":token});break
	return {"sent":true}

func item_action(request: Dictionary)->Dictionary:
	if phase!="playing" or peer==null:return {"error":"Native inventory is not in an admitted area"}
	var actor_id:=int(world_state.local_object_id)
	var actor: Dictionary=world_state.registry.get(actor_id,{})
	if int(actor.get("objectType",0))!=5 or int(actor.get("areaId",0))!=world_state.area_id or bool(actor.get("replicationRemoved",false)):return {"error":"Native controlled creature is unavailable"}
	var item_id:=int(request.get("itemId",-1))
	var item: Dictionary=world_state.registry.get(item_id,{})
	if int(item.get("objectType",0))!=6 or bool(item.get("replicationRemoved",false)):return {"error":"Native item is unavailable"}
	var location: Variant=item.get("inventoryLocation",{})
	var channel:=str(location.get("channel","")) if location is Dictionary else ""
	var owned:=location is Dictionary and int(location.get("ownerId",-1))==actor_id and channel in ["R","I"]
	var equipped:=int(item.get("equipmentOwnerId",-1))==actor_id
	var operation:=str(request.get("operation",""))
	var destination_id:=int(request.get("destinationId",actor_id))
	var container:=int(world_state.containers.get("C",PlayerRequests.INVALID))
	var from_container:=container!=PlayerRequests.INVALID and channel=="C" and location is Dictionary and int(location.get("ownerId",-1))==container
	if destination_id!=actor_id and (destination_id!=container or container==PlayerRequests.INVALID):return {"error":"Native destination container is not open"}
	var packet: Dictionary={}
	if operation=="pickup":
		if owned or item.get("equipmentOwnerId")!=null or not from_container and int(item.get("areaId",0))!=world_state.area_id:return {"error":"Native pickup item is unavailable"}
		packet=PlayerRequests.item_repository(item_id,operation,actor_id,int(request.get("x",255)),int(request.get("y",255)))
	else:
		var container_object: Dictionary=world_state.registry.get(container,{}) if container!=PlayerRequests.INVALID else {}
		var container_location: Variant=container_object.get("inventoryLocation")
		var owned_container:=from_container and container_location is Dictionary and int(container_location.get("ownerId",-1))==actor_id
		if not owned and not equipped and not (from_container and operation=="move") and not (owned_container and operation=="split"):return {"error":"Native inventory item is unavailable"}
		match operation:
			"learn":packet=PlayerRequests.item_learn(item_id)
			"split":
				var stack: Dictionary=item.get("item",{})
				var amount:=int(request.get("amount",0))
				if amount<1 or amount>mini(65535,int(stack.get("stackSize",stack.get("field454",0)))):return {"error":"Native item split amount is unavailable"}
				packet=PlayerRequests.item_split(item_id,amount)
			"toggle":packet=PlayerRequests.item_toggle(item_id)
			"equip":
				var slot:=int(request.get("slot",0))
				if slot<=0 or slot>0x20000 or (slot & (slot-1))!=0:return {"error":"Native equipment slot is unavailable"}
				packet=PlayerRequests.item_equip(item_id,actor_id,slot)
			"unequip":
				if not equipped:return {"error":"Native equipped item is unavailable"}
				packet=PlayerRequests.item_repository(item_id,operation,actor_id,int(request.get("x",255)),int(request.get("y",255)))
			"move":
				if channel!="R" and not from_container:return {"error":"Native repository item is unavailable"}
				packet=PlayerRequests.item_repository(item_id,operation,destination_id,int(request.get("x",255)),int(request.get("y",255)))
			"drop":packet=PlayerRequests.item_drop(item_id,request.get("position",actor.get("replicated",{}).get("position",[])))
			_:return {"error":"Native item action is unavailable"}
	if packet.has("error"):return packet
	if not await peer.send_game_message(packet.bytes):return {"error":"Native item action send failed"}
	return {"sent":true}

func quickbar_activate(request: Dictionary)->Dictionary:
	if phase!="playing" or peer==null:return {"error":"Native quickbar is not in an admitted area"}
	var actor_id:=int(world_state.local_object_id)
	var actor: Dictionary=world_state.registry.get(actor_id,{})
	if int(request.get("actorId",actor_id))!=actor_id or int(actor.get("objectType",0))!=5 or int(actor.get("areaId",0))!=world_state.area_id or bool(actor.get("replicationRemoved",false)):return {"error":"Native quickbar belongs to a retired controlled creature"}
	var index:=int(request.get("index",-1))
	if index<0 or index>=36:return {"error":"Invalid native quickbar index"}
	var button: Dictionary=world_state.quickbar[index]
	var packet: Dictionary={}
	match int(button.get("type",0)):
		43:packet=PlayerRequests.cancel_polymorph(actor_id)
		38:packet=PlayerRequests.possess_familiar()
		42:packet=PlayerRequests.quick_chat(int(button.get("intParam",0))&65535)
		1:
			var item_id:=int(button.get("itemId",-1))
			var item: Dictionary=world_state.registry.get(item_id,{})
			if int(item.get("objectType",0))!=6 or bool(item.get("replicationRemoved",false)):return {"error":"Native shortcut item is unavailable"}
			var base_item:=int(item.get("item",{}).get("baseItem",-1))
			var item_info: Dictionary=object_rules.quickbar_item_info(base_item) if object_rules!=null else {}
			if item_info.is_empty():return {"error":"Native shortcut item rules are unavailable"}
			if int(item_info.container)!=0:
				var location: Variant=item.get("inventoryLocation",{})
				if not location is Dictionary or int(location.get("ownerId",-1))!=actor_id:return {"error":"Native shortcut container is unavailable"}
				packet=PlayerRequests.use_object(item_id,false)
			elif int(item_info.equipableSlots)!=0 and (int(button.get("intParam",0))&65535)==255:
				var second_id:=int(button.get("secondaryItemId",PlayerRequests.INVALID))
				if second_id!=PlayerRequests.INVALID:
					var second: Dictionary=world_state.registry.get(second_id,{})
					if int(second.get("objectType",0))!=6 or bool(second.get("replicationRemoved",false)):return {"error":"Native secondary shortcut item is unavailable"}
				packet=PlayerRequests.item_toggle(item_id,second_id)
			else:return {"error":"This shortcut action is not connected yet"}
		39:
			var target_id:=PlayerRequests.INVALID
			match int(button.get("associateType",0)):
				1:target_id=int(button.get("associateId",PlayerRequests.INVALID))
				2:target_id=int(actor.get("companionId",PlayerRequests.INVALID))
				3:target_id=int(actor.get("familiarId",PlayerRequests.INVALID))
				_:return {"sent":false}
			var command:=int(button.get("intParam",0))&65535
			if command>=32768:command-=65536
			packet=PlayerRequests.associate_command(target_id,command)
		_:return {"error":"This shortcut action is not connected yet"}
	if packet.has("error"):return packet
	if not await peer.send_game_message(packet.bytes):return {"error":"Native quickbar send failed"}
	return {"sent":true}

func quickbar_assign(request: Dictionary)->Dictionary:
	if phase!="playing" or peer==null:return {"error":"Native quickbar is not in an admitted area"}
	var actor_id:=int(world_state.local_object_id)
	var actor: Dictionary=world_state.registry.get(actor_id,{})
	if int(request.get("actorId",actor_id))!=actor_id or int(actor.get("objectType",0))!=5 or int(actor.get("areaId",0))!=world_state.area_id or bool(actor.get("replicationRemoved",false)):return {"error":"Native quickbar belongs to a retired controlled creature"}
	if not request.get("button") is Dictionary:return {"error":"Invalid native quickbar button"}
	var index:=int(request.get("index",-1))
	if index<0 or index>=world_state.quickbar.size():return {"error":"Invalid native quickbar index"}
	var requested_button: Dictionary=request.button
	var configured: Dictionary={}
	if int(requested_button.get("type",0))==1 and bool(request.get("configure",true)):
		var item_quickbar=preload("res://systems/native_data/native_item_quickbar.gd").new()
		item_quickbar.configure(world_state,object_rules.tables if object_rules!=null else {})
		configured=item_quickbar.configure_shortcut(world_state.quickbar[index],requested_button,0)
		if not bool(configured.get("ok",false)):
			var reason:=str(configured.get("error",""))
			return {"error":reason if not reason.is_empty() else "Native item shortcut is unavailable","feedback":int(configured.get("feedback",-1))}
		requested_button=configured.button
	var button: Dictionary=preload("res://systems/native_data/native_quickbar_button.gd").normalize_assignment(requested_button)
	if int(button.get("type",0))==1:
		for item_id in [int(button.get("itemId",-1)),int(button.get("secondaryItemId",PlayerRequests.INVALID))]:
			if item_id==PlayerRequests.INVALID:continue
			var item: Dictionary=world_state.registry.get(item_id,{})
			var location: Variant=item.get("inventoryLocation",{})
			var owned:=location is Dictionary and int(location.get("ownerId",-1))==actor_id and str(location.get("channel","")) in ["R","I"]
			var existing:=false
			for shortcut in world_state.quickbar:
				if int(shortcut.get("type",0))==1 and item_id in [int(shortcut.get("itemId",-1)),int(shortcut.get("secondaryItemId",-1))]:existing=true;break
			if int(item.get("objectType",0))!=6 or bool(item.get("replicationRemoved",false)) or not owned and not existing:return {"error":"Native quickbar item is unavailable"}
		button.secondaryItemId=int(button.get("secondaryItemId",PlayerRequests.INVALID))
	var packet: Dictionary=PlayerRequests.quickbar_assignment(index,button)
	if packet.has("error"):return packet
	if not await peer.send_game_message(packet.bytes):return {"error":"Native quickbar assignment send failed"}
	var update: Dictionary={"full":false,"entries":[{"index":index,"button":button,"items":[]}]}
	if not world_state.apply_quickbar(update):return {"error":"Native quickbar layout could not apply"}
	world_revision+=1
	quickbar_ready.emit(update)
	publish_world_if_ready()
	return {"sent":true,"button":button,"presentation":configured.get("presentation",{}),"feedback":int(configured.get("feedback",-1))}

func simple_native_action(request: Dictionary)->Dictionary:
	if phase!="playing" or peer==null:return {"error":"Native action is not in an admitted area"}
	var actor_id:=int(world_state.local_object_id)
	var actor: Dictionary=world_state.registry.get(actor_id,{})
	if int(request.get("actorId",actor_id))!=actor_id or int(actor.get("objectType",0))!=5 or int(actor.get("areaId",0))!=world_state.area_id or bool(actor.get("replicationRemoved",false)):return {"error":"Native action belongs to a retired controlled creature"}
	var packet: Dictionary={}
	match str(request.get("kind","")):
		"native-quickchat":packet=PlayerRequests.quick_chat(int(request.get("quickChat",-1)))
		"native-possess":packet=PlayerRequests.possess_familiar()
		"native-cancel-polymorph":packet=PlayerRequests.cancel_polymorph(actor_id)
		"native-associate":
			var target_id:=int(request.get("targetId",-1))
			var target: Dictionary=world_state.registry.get(target_id,{})
			if int(target.get("objectType",0))!=5 or bool(target.get("replicationRemoved",false)):return {"error":"Native associate target is unavailable"}
			packet=PlayerRequests.associate_command(target_id,int(request.get("command",0)))
		_:return {"error":"Native action is unavailable"}
	if packet.has("error"):return packet
	if not await peer.send_game_message(packet.bytes):return {"error":"Native action send failed"}
	return {"sent":true,"serverAcknowledged":false} if str(request.get("kind",""))=="native-cancel-polymorph" else {"sent":true}

func cancel_action(request: Dictionary)->Dictionary:
	if phase!="playing" or peer==null:return {"error":"Native action cancellation is unavailable"}
	var actor_id:=int(world_state.local_object_id)
	var actor: Dictionary=world_state.registry.get(actor_id,{})
	if int(request.get("actorId",actor_id))!=actor_id or int(actor.get("objectType",0))!=5 or int(actor.get("areaId",0))!=world_state.area_id or bool(actor.get("replicationRemoved",false)):return {"error":"Action cancellation belongs to an old controlled creature"}
	var action_id:=int(request.get("actionId",-1));var group_id:=int(request.get("groupId",-1))
	var packet: Dictionary=PlayerRequests.cancel_action(action_id,group_id)
	if packet.has("error"):return packet
	var current:=false
	for queued in actor.get("playerState",{}).get("actionQueue",[]):
		if int(queued.get("type",-1))==action_id and int(queued.get("group",-1))==group_id:current=true;break
	if not current:return {"sent":false,"stale":true}
	if not await peer.send_game_message(packet.bytes):return {"error":"Native action cancellation could not be sent"}
	return {"sent":true}

func disengage(request: Dictionary)->Dictionary:
	if phase!="playing" or peer==null:return {"error":"Disengage is unavailable"}
	var actor_id:=int(world_state.local_object_id)
	var actor: Dictionary=world_state.registry.get(actor_id,{})
	if int(request.get("actorId",actor_id))!=actor_id or int(actor.get("objectType",0))!=5 or int(actor.get("areaId",0))!=world_state.area_id or bool(actor.get("replicationRemoved",false)):return {"error":"Disengage belongs to an old controlled creature"}
	var packet: Dictionary=PlayerRequests.target(PlayerRequests.INVALID,"attack")
	if packet.has("error") or not await peer.send_game_message(packet.bytes):return {"error":"Native disengage could not be sent"}
	return {"sent":true,"serverAcknowledged":false}

func transfer_gold(request: Dictionary)->Dictionary:
	if phase!="playing" or peer==null:return {"error":"Native gold transfer is unavailable"}
	var actor_id:=int(world_state.local_object_id)
	var actor: Dictionary=world_state.registry.get(actor_id,{})
	if int(request.get("actorId",actor_id))!=actor_id or int(actor.get("objectType",0))!=5 or int(actor.get("areaId",0))!=world_state.area_id or bool(actor.get("replicationRemoved",false)):return {"error":"Native gold selection is stale"}
	var balance: Variant=actor.get("playerState",{}).get("combat",{}).get("field898")
	var amount: Variant=request.get("amount")
	if not balance is int or not amount is int or int(amount)<=0 or int(amount)>int(balance):return {"error":"Native gold selection is stale"}
	var target_id:=int(request.get("targetId",PlayerRequests.INVALID))
	var placement:=bool(request.get("placement",false))
	if target_id!=PlayerRequests.INVALID:
		var target: Dictionary=world_state.registry.get(target_id,{})
		var kind:=int(target.get("objectType",0))
		var container:=int(world_state.containers.get("C",PlayerRequests.INVALID))
		var location: Variant=target.get("inventoryLocation")
		var owned_container:=kind==6 and (target_id==container and container!=PlayerRequests.INVALID or location is Dictionary and (int(location.get("ownerId",-1))==actor_id and str(location.get("channel","")) in ["R","I"] or container!=PlayerRequests.INVALID and str(location.get("channel",""))=="C" and int(location.get("ownerId",-1))==container))
		if target.is_empty() or bool(target.get("replicationRemoved",false)) or not owned_container and int(target.get("areaId",-1))!=world_state.area_id or kind not in [5,6,9]:return {"error":"Native gold destination is unavailable"}
		if kind==6:
			var item_info: Dictionary=object_rules.quickbar_item_info(int(target.get("item",{}).get("baseItem",-1))) if object_rules!=null else {}
			if item_info.is_empty() or int(item_info.get("container",0))==0:return {"error":"Native gold destination is unavailable"}
		if placement:
			var barter: Variant=world_state.barter
			if not barter is Dictionary or not bool(barter.get("open",false)) or int(barter.get("serial",-1))!=int(request.get("barterSerial",-2)) or int(barter.get("partnerId",-1))!=target_id or bool(barter.get("ownLocked",false)):return {"error":"Native gold barter placement is stale or locked"}
	elif placement:return {"error":"Native gold ground placement is unavailable"}
	var packet: Dictionary=PlayerRequests.gold_transfer(int(amount),target_id,request.get("position",[]),placement,int(request.get("x",0)),int(request.get("y",0)))
	if packet.has("error") or not await peer.send_game_message(packet.bytes):return {"error":"Native gold transfer could not be sent"}
	return {"sent":true}

func input_actor(request: Dictionary)->Dictionary:
	if phase!="playing" or peer==null:return {}
	var id:=int(world_state.local_object_id)
	var actor: Dictionary=world_state.registry.get(id,{})
	if int(request.get("actorId",id))!=id or int(request.get("areaId",-1))!=world_state.area_id or int(request.get("generation",request.get("areaGeneration",-1)))!=area_generation or int(actor.get("objectType",0))!=5 or int(actor.get("areaId",-1))!=world_state.area_id or bool(actor.get("replicationRemoved",false)):return {}
	return actor

func rest(request: Dictionary)->Dictionary:
	if input_actor(request).is_empty():return {"error":"Rest belongs to an old controlled creature"}
	if not await peer.send_game_message(NetworkHud.rest_request()):return {"error":"Native rest request could not be sent"}
	return {"sent":true}

func player_attitude(request: Dictionary)->Dictionary:
	var actor:=input_actor(request)
	var player_id:=int(request.get("playerId",-1))
	var player: Dictionary=world_state.players.get(player_id,{})
	var character: Dictionary=player.get("character",{}) if player.get("character",{}) is Dictionary else {}
	if actor.is_empty() or player.is_empty() or bool(player.get("isDM",player.get("dm",false))) or int(player.get("objectId",-1))==int(actor.get("id",-1)) or int(character.get("id",-1))==int(actor.get("id",-1)):return {"error":"Native player attitude target is stale"}
	var target_id:=int(character.get("id",PlayerRequests.INVALID))
	if target_id==PlayerRequests.INVALID or target_id<0:return {"error":"That player character is not yet available"}
	var packet: Dictionary=NetworkHud.player_attitude_request(target_id,bool(request.get("likes",false)))
	if packet.has("error"):return packet
	if not await peer.send_game_message(packet.bytes):return {"error":"Native player attitude send failed"}
	return {"sent":true,"serverAcknowledged":false}

func player_list_input(request: Dictionary)->Dictionary:
	var actor:=input_actor(request)
	var player_id:=int(request.get("playerId",-1))
	var player: Dictionary=world_state.players.get(player_id,{})
	var character: Dictionary=player.get("character",{}) if player.get("character",{}) is Dictionary else {}
	var operation:=str(request.get("operation",""))
	if actor.is_empty() or player.is_empty() or bool(player.get("isDM",player.get("dm",false))) or int(player.get("objectId",-1))==int(actor.get("id",-1)) or int(character.get("id",-1))==int(actor.get("id",-1)) or operation not in ["select","tell"]:return {"error":"Native player-list selection is stale"}
	var expected:=int(player.get("objectId",PlayerRequests.INVALID)) if operation=="tell" else int(character.get("id",PlayerRequests.INVALID))
	if expected==PlayerRequests.INVALID or expected<0 or int(request.get("targetId",-1))!=expected:return {"error":"Native player-list target changed"}
	var packet: Dictionary=NetworkParty.player_list_gui_request(operation,expected,AreaState.at_least(remote_build if not remote_build.is_empty() else local_build,35))
	if packet.has("error"):return packet
	if not await peer.send_game_message(packet.bytes):return {"error":"Native player-list send failed"}
	return {"sent":true,"serverAcknowledged":false}

func party_chat_input(request: Dictionary)->Dictionary:
	var actor:=input_actor(request)
	if actor.is_empty():return {"error":"Native chat party owner is stale"}
	var operation:=str(request.get("operation",""))
	var target_id:=int(request.get("targetId",PlayerRequests.INVALID))
	if operation=="accept":
		if target_id!=PlayerRequests.INVALID or request.has("playerId") or request.has("playerAccount"):return {"error":"Invalid native chat acceptance"}
	elif operation=="invite":
		var player: Dictionary=world_state.players.get(int(request.get("playerId",-1)),{})
		var character: Dictionary=player.get("character",{}) if player.get("character",{}) is Dictionary else {}
		if player.is_empty() or not request.get("playerAccount") is String or str(player.get("name",""))!=str(request.playerAccount) or target_id!=int(character.get("id",PlayerRequests.INVALID)):return {"error":"Native chat invitation target changed"}
	else:return {"error":"Unsupported native chat party operation"}
	var packet: Dictionary=NetworkParty.party_request(operation,target_id)
	if packet.has("error"):return packet
	if not await peer.send_game_message(packet.bytes):return {"error":"Native chat party send failed"}
	return {"sent":true,"serverAcknowledged":false}

func party_input(request: Dictionary)->Dictionary:
	var actor:=input_actor(request)
	if actor.is_empty():return {"error":"Native party owner is stale"}
	var operation:=str(request.get("operation",""))
	var actor_id:=int(actor.get("id",-1))
	var flags: Dictionary=actor.get("replicated",{}).get("party",{})
	var target_id: Variant=null
	if operation=="list":
		if request.has("playerId") or request.has("targetId"):return {"error":"Party-list refresh has no target"}
	elif operation in ["accept","reject","ignore"]:
		target_id=flags.get("field7D8")
		if not bool(flags.get("field7DC",false)) or not target_id is int or target_id==PlayerRequests.INVALID or request.get("targetId")!=target_id:return {"error":"That party invitation is no longer current"}
	elif operation=="leave":
		if not request.has("playerId") and not request.has("targetId"):target_id=actor_id
		else:
			var player: Dictionary=world_state.players.get(int(request.get("playerId",-1)),{})
			var character: Dictionary=player.get("character",{}) if player.get("character",{}) is Dictionary else {}
			target_id=character.get("id")
			if player.is_empty() or bool(player.get("isDM",player.get("dm",false))) or not target_id is int or target_id==PlayerRequests.INVALID or request.get("targetId")!=target_id:return {"error":"Native party target is stale"}
	elif operation in ["invite","kick","transfer"]:
		var player: Dictionary=world_state.players.get(int(request.get("playerId",-1)),{})
		var character: Dictionary=player.get("character",{}) if player.get("character",{}) is Dictionary else {}
		target_id=character.get("id")
		if player.is_empty() or bool(player.get("isDM",player.get("dm",false))) or not target_id is int or target_id==PlayerRequests.INVALID or target_id==actor_id or request.get("targetId")!=target_id:return {"error":"Native party target is stale"}
		var member:=false
		for row in world_state.party:
			if int(row.get("id",-1))==target_id:member=true;break
		if operation=="invite" and member:return {"error":"That player is already in your group"}
		if operation!="invite" and (not member or not bool(flags.get("leader",false))):return {"error":"Only the current group leader can perform that action"}
	else:return {"error":"Unsupported native party operation"}
	var packet: Dictionary=NetworkParty.party_request(operation,target_id)
	if packet.has("error"):return packet
	if not await peer.send_game_message(packet.bytes):return {"error":"Native party send failed"}
	return {"sent":true,"serverAcknowledged":false}

func prepare_spell(request: Dictionary)->Dictionary:
	if input_actor(request).is_empty() or not request.get("clear",false) is bool:return {"error":"Native preparation belongs to an old controlled creature"}
	var packet: Dictionary=SpellInput.spell_preparation_clear_request(request) if bool(request.get("clear",false)) else SpellInput.spell_preparation_request(request)
	if packet.has("error"):return packet
	if not await peer.send_game_message(packet.bytes):return {"error":"Native spell preparation send failed"}
	return {"sent":true}

func validate_cast_target(actor: Dictionary,target_id: int)->bool:
	if target_id==PlayerRequests.INVALID:return true
	var target: Dictionary=world_state.registry.get(target_id,{})
	var owned_item:=false
	if int(target.get("objectType",0))==6:
		var location: Variant=target.get("inventoryLocation")
		owned_item=location is Dictionary and int(location.get("ownerId",-1))==int(actor.get("id",-1))
		if not owned_item:
			for shortcut in world_state.quickbar:
				if int(shortcut.get("type",0))==1 and target_id in [int(shortcut.get("itemId",-1)),int(shortcut.get("secondaryItemId",-1))]:owned_item=true;break
	return not target.is_empty() and not bool(target.get("replicationRemoved",false)) and (int(target.get("areaId",-1))==world_state.area_id or owned_item)

func cast_spell(request: Dictionary)->Dictionary:
	var actor:=input_actor(request)
	if actor.is_empty():return {"error":"Native controlled creature is not ready for input"}
	var spell: Dictionary=object_rules.spell_input_info(int(request.get("spellId",-1))) if object_rules!=null else {}
	if spell.is_empty():return {"error":"Native spell input metadata is unavailable"}
	var target_id:=int(request.get("targetId",PlayerRequests.INVALID))
	if not validate_cast_target(actor,target_id):return {"error":"Native spell target is unavailable"}
	var entry:=request.duplicate();entry.targetType=spell.targetType
	var packet: Dictionary=SpellInput.spell_cast_request(entry)
	if packet.has("error"):return packet
	if not await peer.send_game_message(packet.bytes):return {"error":"Native spell cast send failed"}
	return {"sent":true}

func cast_spell_like(request: Dictionary)->Dictionary:
	var actor:=input_actor(request)
	if actor.is_empty():return {"error":"Native controlled creature is not ready for input"}
	if object_rules==null or object_rules.spell_input_info(int(request.get("spellId",-1))).is_empty():return {"error":"Native innate spell metadata is unavailable"}
	if not validate_cast_target(actor,int(request.get("targetId",PlayerRequests.INVALID))):return {"error":"Native spell target is unavailable"}
	var packet: Dictionary=SpellInput.spell_like_cast_request(request)
	if packet.has("error"):return packet
	if not await peer.send_game_message(packet.bytes):return {"error":"Native innate cast send failed"}
	return {"sent":true}

func use_item(request: Dictionary)->Dictionary:
	var actor:=input_actor(request)
	if actor.is_empty():return {"error":"Native controlled creature is not ready for input"}
	var item_id:=int(request.get("itemId",-1))
	var item: Dictionary=world_state.registry.get(item_id,{})
	var location: Variant=item.get("inventoryLocation")
	var shortcut:=false
	for button in world_state.quickbar:
		if int(button.get("type",0))==1 and int(button.get("itemId",-1))==item_id:shortcut=true;break
	var owned:=location is Dictionary and int(location.get("ownerId",-1))==int(actor.get("id",-1)) and str(location.get("channel","")) in ["R","I"]
	if int(item.get("objectType",0))!=6 or bool(item.get("replicationRemoved",false)) or not shortcut and not owned:return {"error":"Native item-use source is unavailable"}
	if not validate_cast_target(actor,int(request.get("targetId",PlayerRequests.INVALID))):return {"error":"Native spell target is unavailable"}
	var packet: Dictionary=ItemInput.item_use_request(request)
	if packet.has("error"):return packet
	if not await peer.send_game_message(packet.bytes):return {"error":"Native item-use send failed"}
	return {"sent":true}

func use_feat(request: Dictionary)->Dictionary:
	var actor:=input_actor(request)
	if actor.is_empty():return {"error":"Native controlled creature is not ready for input"}
	if object_rules==null or object_rules.feat_input_info(int(request.get("featId",-1))).is_empty():return {"error":"Native feat input metadata is unavailable"}
	if not validate_cast_target(actor,int(request.get("targetId",PlayerRequests.INVALID))):return {"error":"Native spell target is unavailable"}
	var packet: Dictionary=FeatInput.feat_use_request(request)
	if packet.has("error"):return packet
	if not await peer.send_game_message(packet.bytes):return {"error":"Native feat send failed"}
	return {"sent":true}

func change_mode(request: Dictionary)->Dictionary:
	var actor:=input_actor(request)
	if actor.is_empty():return {"error":"Native controlled creature is not ready for input"}
	if int(request.get("modeId",-1))==5 and not validate_cast_target(actor,int(request.get("targetId",PlayerRequests.INVALID))):return {"error":"Native spell target is unavailable"}
	var packet: Dictionary=FeatInput.mode_change_request(request)
	if packet.has("error"):return packet
	if not await peer.send_game_message(packet.bytes):return {"error":"Native mode send failed"}
	return {"sent":true}

func activity_input(request: Dictionary)->Dictionary:
	var actor:=input_actor(request)
	if actor.is_empty():return {"error":"Activity input belongs to a retired actor"}
	var activity_id: Variant=request.get("activityId")
	var target_id: Variant=request.get("targetId",PlayerRequests.INVALID)
	if activity_id is int or activity_id is float:
		if is_finite(float(activity_id)) and float(activity_id)==5.0:
			if not request.has("targetId") or target_id==PlayerRequests.INVALID:
				var flags: Variant=actor.get("playerState",{}).get("playerFlags")
				if not PlayerRequests.input_integer(flags,0,0xffffffff) or (int(flags)&512)==0:return {"error":"Counterspell cancellation requires current server mode4"}
			else:
				if not PlayerRequests.input_integer(target_id,0,0xffffffff):return {"error":"Counterspell target is not a current creature"}
				var target: Dictionary=world_state.registry.get(int(target_id),{})
				if target.is_empty() or int(target.get("id",-1))==int(actor.get("id",-1)) or int(target.get("objectType",0))!=5 or bool(target.get("replicationRemoved",false)) or int(target.get("areaId",-1))!=world_state.area_id:return {"error":"Counterspell target is not a current creature"}
	var packet: Dictionary=PlayerRequests.activity(activity_id,target_id)
	if packet.has("error"):return packet
	if not await peer.send_game_message(packet.bytes):return {"error":"Native activity send failed"}
	return {"sent":true}

func skill_input(request: Dictionary)->Dictionary:
	var actor:=input_actor(request)
	var target_id: Variant=request.get("targetId")
	if actor.is_empty() or target_id==PlayerRequests.INVALID:return {"error":"Skill input belongs to a retired actor or invalid target"}
	if not PlayerRequests.input_integer(target_id,0,0xffffffff) or not validate_cast_target(actor,int(target_id)):return {"error":"Native spell target is unavailable"}
	# The old submitNativeSkill wrapper forwards only packedSkill and targetId;
	# skillUseRequest supplies the original fixed zero XYZ by default.
	var packet: Dictionary=PlayerRequests.skill(request.get("packedSkill"),target_id)
	if packet.has("error"):return packet
	if not await peer.send_game_message(packet.bytes):return {"error":"Native skill send failed"}
	return {"sent":true}

func play_emote(request: Dictionary)->Dictionary:
	var actor:=input_actor(request)
	var voice: Variant=request.get("voice",65535)
	if actor.is_empty() or not voice is int or voice<0 or voice>65535:return {"error":"Native emote belongs to an old controlled creature"}
	var entry:=request.duplicate();entry.actorId=int(actor.get("id",-1))
	var packet: Dictionary=EmoteInput.emote_animation_request(entry)
	if packet.has("error"):return packet
	if not await peer.send_game_message(packet.bytes):return {"error":"Native emote send failed"}
	if int(voice)!=65535:
		var voice_packet: Dictionary=PlayerRequests.quick_chat(int(voice))
		if voice_packet.has("error"):return voice_packet
		if not await peer.send_game_message(voice_packet.bytes):return {"error":"Native emote voice send failed"}
	return {"sent":true}

func map_position_visible(point: Variant,actor: Dictionary,area: Dictionary)->bool:
	if not point is Array or point.size()!=3:return false
	for value in point:
		if not (value is int or value is float) or not is_finite(float(value)):return false
	var width:=int(area.get("width",0));var height:=int(area.get("height",0))
	var x:=int(floor(float(point[0])/10.0));var y:=int(floor(float(point[1])/10.0))
	if x<0 or x>=width or y<0 or y>=height:return false
	var exploration: Variant=actor.get("playerState",{}).get("mapExploration",{})
	var cells: Variant=exploration.get(world_state.area_id,[]) if exploration is Dictionary else []
	return cells is Array and y*width+x<cells.size() and cells[y*width+x]==1

func map_f32(value: Variant)->float:
	var bytes:=PackedByteArray([0,0,0,0]);bytes.encode_float(0,float(value));return bytes.decode_float(0)

func map_input(request: Dictionary)->Dictionary:
	var actor:=input_actor(request)
	var area: Dictionary=world_state.registry.get(world_state.area_id,{}).get("state",{})
	if actor.is_empty() or area.is_empty():return {"error":"Native map owner is stale"}
	var operation:=str(request.get("operation",""))
	var reference:=int(request.get("reference",-1))
	var packet: Dictionary={}
	if operation=="click":
		var pin: Dictionary=world_state.map_pins.get(reference,{})
		if pin.is_empty() or not bool(pin.get("enabled",false)) or not map_position_visible(pin.get("position"),actor,area):return {"error":"Native server map pin is unavailable"}
		packet=MapInput.map_pin_click_request({"reference":reference,"includePosition":AreaState.at_least(remote_build if not remote_build.is_empty() else local_build,35)})
	else:
		var position: Variant=request.get("position")
		if operation=="add":
			if not map_position_visible(position,actor,area):return {"error":"Map notes require an explored map position"}
		else:
			var pin: Dictionary={}
			for row in area.get("playerMapPins",[]):
				if int(row.get("index",-1))==reference:pin=row;break
			if pin.is_empty() or not map_position_visible(pin.get("position"),actor,area):return {"error":"Native personal map note is stale"}
			if operation=="change":
				var previous: Variant=pin.get("position")
				if not position is Array or position.size()!=3 or not previous is Array or previous.size()!=3:return {"error":"Native map-note editor cannot move this note"}
				for index in 3:
					if map_f32(position[index])!=map_f32(previous[index]):return {"error":"Native map-note editor cannot move this note"}
		packet=MapInput.map_note_request(request)
	if packet.has("error"):return packet
	if not await peer.send_game_message(packet.bytes):return {"error":"Native map request could not be sent"}
	return {"sent":true,"serverAcknowledged":false}

func hud_record_target(request: Dictionary,actor: Dictionary)->Dictionary:
	var actor_id:=int(actor.get("id",-1))
	var target_value: Variant=request.get("targetId",actor_id)
	if not RecordTarget.client_id(target_value):return {"error":"Native character-record target is unavailable"}
	var target_id:=int(target_value)
	var tagged:=request.has("recordActorLifetime") or request.has("recordTargetLifetime")
	if target_id==actor_id and not tagged:return {"target":actor,"foreign":false,"scoped":false}
	var target: Dictionary=world_state.registry.get(target_id,{})
	var actor_lifetime: Variant=request.get("recordActorLifetime")
	var target_lifetime: Variant=request.get("recordTargetLifetime")
	if not RecordTarget.valid_lifetime(actor_lifetime) or not RecordTarget.valid_lifetime(target_lifetime):return {"error":"Native character-record disclosure scope is unavailable"}
	if RecordTarget.lifetime(world_state.registry,actor_id,world_state.area_id)!=actor_lifetime or RecordTarget.lifetime(world_state.registry,target_id,world_state.area_id)!=target_lifetime or actor.get("destroyed")==true:return {"error":"Native character-record disclosure owner has retired"}
	if target_id!=actor_id and not RecordTarget.admission(actor_id,target_id,world_state.registry,{"gameMasterPermission":world_state.game_master_permission}).get("available",false):return {"error":"Native character-record associate ownership is unavailable"}
	return {"target":target,"foreign":target_id!=actor_id,"scoped":true}

func hud_feat_present(target: Dictionary,feat_id: int)->bool:
	var stats: Dictionary=target.get("inventoryStats",{})
	var player: Dictionary=target.get("playerState",{})
	var primary:=false
	if stats.has("fields118"):primary=stats.fields118 is Array and feat_id in stats.fields118
	elif player.has("feats"):primary=player.feats is Array and feat_id in player.feats
	else:
		for entry in stats.get("feats",[]):
			if entry is Dictionary and int(entry.get("id",-1))==feat_id:primary=true;break
	var secondary: Variant=stats.get("fields128",player.get("bonusFeats",[]))
	return primary or secondary is Array and feat_id in secondary

func hud_panel(request: Dictionary)->Dictionary:
	var actor:=input_actor(request)
	if actor.is_empty() or not request.get("open") is bool:return {"error":"Native panel request is stale"}
	var opened: bool=request.open
	var panel:=str(request.get("panel",""))
	var include_position:=AreaState.at_least(remote_build if not remote_build.is_empty() else local_build,35)
	if panel=="journal" and request.has("journalLifetime"):
		var old_world: RefCounted=world_state;var old_peer: RefCounted=peer;var old_actor:=actor
		var scope: Dictionary={"world":old_world,"peer":old_peer,"actor":old_actor,"areaId":world_state.area_id,"areaGeneration":area_generation}
		var assert_current: Callable=func()->Variant:
			var current: Dictionary=input_actor(request)
			return phase not in ["closed","failed"] and world_state==old_world and peer==old_peer and int(current.get("id",-1))==int(old_actor.get("id",-2)) and int(current.get("clientKnownLifetime",-1))==int(old_actor.get("clientKnownLifetime",-2))
		var send_packet: Callable=func(bytes: PackedByteArray)->Variant:return await old_peer.send_game_message(bytes)
		return await journal_events.transition({"open":opened,"journalLifetime":request.journalLifetime,"includePosition":include_position},scope,assert_current,send_packet)
	var record: Dictionary={}
	var packet: Dictionary={}
	match panel:
		"character","skill","feat":
			record=hud_record_target(request,actor)
			if record.has("error"):return record
			var displayed: Dictionary=record.target
			var target_id:=int(displayed.get("id",-1))
			if panel=="character":
				var page:=int(request.get("page",0))
				if bool(record.foreign) and opened and (page<0 or page>2):return {"error":"Native character-record page is unavailable"}
				packet=NetworkHud.character_sheet_request(target_id,page if opened else -1)
			elif panel=="skill":
				var skill_id:=int(request.get("skillId",-1))
				var found:=false
				for row in displayed.get("inventoryStats",{}).get("skills",[]):
					if row is Dictionary and int(row.get("index",-1))==skill_id and bool(row.get("flag",false)):found=true;break
				if not opened or int(request.get("targetId",-1))!=target_id or not found:return {"error":"That native skill row is no longer present"}
				packet=NetworkHud.skill_description_request(skill_id,target_id,include_position)
			else:
				var feat_id:=int(request.get("featId",-1))
				if not opened or int(request.get("targetId",-1))!=target_id or not hud_feat_present(displayed,feat_id):return {"error":"That native feat row is no longer present"}
				packet=NetworkHud.feat_description_request(feat_id,target_id,include_position)
		"effect":
			var effect_id:=int(request.get("effectId",-1))
			var icons: Variant=actor.get("playerState",{}).get("effectIcons",{})
			if not opened or not icons is Dictionary or not icons.has(effect_id) and not icons.has(str(effect_id)):return {"error":"That native effect icon is no longer present"}
			packet=NetworkHud.effect_icon_request(effect_id,include_position)
		"chat-reply":
			var player: Dictionary=world_state.players.get(int(request.get("playerId",-1)),{})
			var target_id:=int(request.get("targetId",-1))
			if not opened or player.is_empty() or target_id!=int(player.get("objectId",PlayerRequests.INVALID)):return {"error":"That native chat reply player is no longer available"}
			packet=NetworkHud.chat_reply_request(target_id,include_position)
		"chat-focus":packet=NetworkHud.chat_focus_request(int(request.get("mode",-1)),opened,include_position)
		"journal":packet={"bytes":NetworkHud.journal_window_request(opened)}
		_:return {"error":"Unsupported native panel request"}
	if packet.has("error"):return packet
	var old_peer: RefCounted=peer
	var old_world: RefCounted=world_state
	if not await old_peer.send_game_message(packet.bytes):return {"error":"Native panel send failed"}
	if bool(record.get("scoped",false)):
		var current:=hud_record_target(request,input_actor(request))
		if current.has("error") or current.get("target",{}).get("id",-1)!=record.target.get("id",-2) or peer!=old_peer or world_state!=old_world:return {"error":"Native character-record target has retired"}
		if panel=="skill":
			var row_present:=false
			for row in current.target.get("inventoryStats",{}).get("skills",[]):
				if row is Dictionary and int(row.get("index",-1))==int(request.get("skillId",-1)) and bool(row.get("flag",false)):row_present=true;break
			if not row_present:return {"error":"That native skill row is no longer present"}
		if panel=="feat" and not hud_feat_present(current.target,int(request.get("featId",-1))):return {"error":"That native feat row is no longer present"}
	return {"sent":true}

func chat(request: Dictionary)->Dictionary:
	if phase!="playing" or peer==null:return {"error":"Native chat is not in an admitted area"}
	var actor_id:=int(world_state.local_object_id)
	var actor: Dictionary=world_state.registry.get(actor_id,{})
	if int(request.get("actorId",actor_id))!=actor_id or int(actor.get("objectType",0))!=5 or int(actor.get("areaId",0))!=world_state.area_id or bool(actor.get("replicationRemoved",false)):return {"error":"Native chat belongs to a retired controlled creature"}
	var raw_channel: Variant=request.get("channel",-1)
	if typeof(raw_channel) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(raw_channel)) or float(raw_channel)!=floorf(float(raw_channel)) or not request.get("text") is String:return {"error":"Invalid native chat request"}
	var channel:=int(raw_channel)
	var named_tell:=channel==4 and request.has("recipient")
	if named_tell and not request.recipient is String:return {"error":"Chat text cannot be encoded with the active native text codec"}
	var player_id: int=-1
	if request.has("playerId") and not named_tell and channel==4:
		var raw_player_id: Variant=request.playerId
		if typeof(raw_player_id) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(raw_player_id)) or float(raw_player_id)!=floorf(float(raw_player_id)) or float(raw_player_id)<0.0 or float(raw_player_id)>4294967295.0:return {"error":"Invalid native tell recipient"}
		player_id=int(raw_player_id)
	elif request.has("playerId") and typeof(request.playerId) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(request.playerId)):player_id=int(request.playerId)
	if request.has("playerAccount"):
		if channel!=4 or not request.playerAccount is String or not world_state.players.has(player_id) or str(world_state.players[player_id].get("name",""))!=request.playerAccount:return {"error":"Native Tell player has changed"}
	var packet: Dictionary=PlayerRequests.chat(channel,request.text,player_id,str(request.get("recipient","")),request.has("recipient"),request.has("playerId"))
	if packet.has("error"):return packet
	if not await peer.send_game_message(packet.bytes):return {"error":"Native chat send failed"}
	return {"sent":true}

func reply_dialog(request: Dictionary)->Dictionary:
	if input_actor(request).is_empty():return {"error":"Native controlled creature is not ready for input"}
	if current_dialog.is_empty() or not current_dialog.has("replies"):return {"error":"Native dialog reply is stale or unavailable"}
	var choices: Dictionary=current_dialog.replies
	var entry_id: Variant=request.get("entryId")
	var reply_id: Variant=request.get("replyId")
	var abort: Variant=request.get("abort",false)
	if entry_id!=choices.get("entryId") or not abort is bool:return {"error":"Native dialog reply is stale or unavailable"}
	var offered:=false
	for row in choices.get("replies",[]):
		if row.id==reply_id:offered=true;break
	if not abort and not offered and not (choices.replies.is_empty() and reply_id==0xffffffff):return {"error":"Native dialog reply is stale or unavailable"}
	if abort and int(choices.get("secondCount",0))==1:
		reply_id=int(choices.replies[0].id) if not choices.replies.is_empty() else 0xffffffff
		abort=false
	var packet: Dictionary=PlayerRequests.dialog_reply(int(current_dialog.ownerId),int(entry_id),0xffffffff if abort else int(reply_id),abort)
	if packet.has("error"):return packet
	if not await peer.send_game_message(packet.bytes):return {"error":"Native dialog reply send failed"}
	return {"sent":true}

func inventory_contains(channel: String,item_id: int)->bool:
	var view: Variant=world_state.inventories.get(channel)
	if not view is Dictionary:return false
	for entry in view.get("entries",[]):
		if int(entry.get("id",-1))==item_id:return true
	return false

func target_action(target_id: int,action: String,position: Array=[],run: bool=true)->Dictionary:
	if phase!="playing" or peer==null:return {"error":"Native player is not in an admitted area"}
	var actor_id: int=int(world_state.local_object_id)
	var actor: Dictionary=world_state.registry.get(actor_id,{})
	if int(actor.get("objectType",0))!=5 or int(actor.get("areaId",0))!=world_state.area_id or bool(actor.get("replicationRemoved",false)):return {"error":"Native controlled creature is not ready for input"}
	var target: Dictionary=world_state.registry.get(target_id,{})
	var kind:=int(target.get("objectType",0))
	var location: Variant=target.get("inventoryLocation",{})
	var owned_item:=action=="object.use" and kind==6 and location is Dictionary and int(location.get("ownerId",-1))==actor_id
	if action=="examine" and kind==6:
		var channel:=str(location.get("channel","")) if location is Dictionary else ""
		var container:=int(world_state.containers.get("C",PlayerRequests.INVALID))
		owned_item=location is Dictionary and (int(location.get("ownerId",-1))==actor_id or channel=="C" and container!=PlayerRequests.INVALID and int(location.get("ownerId",-1))==container or channel=="M" and world_state.store is Dictionary and bool(world_state.store.get("open",false)) and inventory_contains("M",target_id) or channel in ["A","B"] and world_state.barter is Dictionary and bool(world_state.barter.get("open",false)) and inventory_contains(channel,target_id)) or int(target.get("equipmentOwnerId",-1))==actor_id
	if target.is_empty() or bool(target.get("replicationRemoved",false)) or int(target.get("areaId",0))!=world_state.area_id and not owned_item:return {"error":"Native interaction target is unavailable"}
	var packet: Dictionary={}
	var sequence: int=-1
	match action:
		"examine":
			if kind not in [5,6,7,9,10]:return {"error":"Native examination target is unavailable"}
			packet=PlayerRequests.target(target_id,"examine")
		"conversation.start":packet=PlayerRequests.target(target_id,"talk")
		"combat.attack":packet=PlayerRequests.target(target_id,"attack")
		"door.open","door.close":
			if kind!=10:return {"error":"Native door target is unavailable"}
			packet=PlayerRequests.door(target_id,action=="door.open")
		"object.use":packet=PlayerRequests.use_object(target_id,kind==9)
		"door.transition":
			var state: Dictionary=target.get("replicated",{})
			if kind!=10 or ObjectAnimation.door_state(state) in [-1,0] or not bool(state.get("hasTransition",false)) or not state.get("position") is Array:return {"error":"Native door transition is unavailable"}
			packet=PlayerRequests.waypoint(world_state.area_id,state.position,0,run,false,0,target_id)
		"trigger.transition":
			var state: Dictionary=target.get("replicated",{})
			if kind!=7 or not bool(state.get("hasTransition",false)) or bool(state.get("isTrap",false)):return {"error":"Native transition trigger is unavailable"}
			if position.is_empty():
				var surface: Variant=TransitionSurface.network_trigger_surface(target)
				if surface is Dictionary:position=surface.get("destination",[])
			if position.size()!=3:return {"error":"Native transition trigger approach is unavailable"}
			for coordinate in position:
				if not (coordinate is int or coordinate is float) or not is_finite(float(coordinate)):return {"error":"Native transition trigger approach is unavailable"}
			sequence=(int(movement_sequences.get(actor_id,0))+1)&255
			packet=PlayerRequests.waypoint(world_state.area_id,position,sequence,run,false,0,target_id)
		_:return {"error":"Native interaction request is not implemented"}
	if packet.has("error"):return packet
	if sequence>=0:movement_sequences[actor_id]=sequence
	if not await peer.send_game_message(packet.bytes):return {"error":"Native interaction send failed"}
	return {"sent":true}

func keyboard_move(actor_id: int,operation: String,position: Array=[],heading: int=0,flags: int=0,transmit: bool=true)->Dictionary:
	if phase!="playing" or peer==null:return {"error":"Native player is not in an admitted area"}
	var controlled_id: int=int(world_state.local_object_id)
	var actor: Dictionary=world_state.registry.get(controlled_id,{})
	if actor_id!=controlled_id or int(actor.get("objectType",0))!=5 or int(actor.get("areaId",0))!=world_state.area_id or bool(actor.get("replicationRemoved",false)):return {"error":"Native keyboard input belongs to a retired controlled creature"}
	var packet: Dictionary={}
	var sequence: int=-1
	match operation:
		"drive":
			sequence=(int(movement_sequences.get(actor_id,0))+1)&255
			packet=PlayerRequests.drive(world_state.area_id,position,heading,sequence,flags)
		"stop":packet=PlayerRequests.abort_drive()
		"turn":packet=PlayerRequests.orientation(position)
		_:return {"error":"Invalid native keyboard operation"}
	if packet.has("error"):return packet
	if operation=="drive":movement_sequences[actor_id]=sequence
	var sent:=operation!="drive" or transmit
	if sent and not await peer.send_game_message(packet.bytes):return {"error":"Native keyboard send failed"}
	return {"sent":sent,"sequence":sequence} if operation=="drive" else {"sent":sent}

func flush_device_metrics()->bool:
	if peer==null or not peer.admitted:return true
	device_send_turn+=1
	var turn:=device_send_turn
	while device_send_completed<turn-1:await device_send_advanced
	if phase in ["closed","failed"] or peer==null:
		device_send_completed=turn;device_send_advanced.emit();return true
	var active_peer: RefCounted=peer
	for key in DeviceProperties.KEYS:
		if not device_metrics.has(key) or sent_device_metrics.get(key)==device_metrics[key]:continue
		var packet: Dictionary=DeviceProperties.request(key,int(device_metrics[key]))
		if packet.has("error") or not await active_peer.send_game_message(packet.bytes):
			device_send_completed=turn;device_send_advanced.emit();return false
		if phase in ["closed","failed"] or peer!=active_peer:
			device_send_completed=turn;device_send_advanced.emit();return true
		sent_device_metrics[key]=device_metrics[key]
		device_property_packets+=1
	device_send_completed=turn;device_send_advanced.emit()
	return true

func request_preview(source: int,resref: String,generation: int)->bool:
	if phase not in ["character-selection","character-rejected"] or character_submission_pending or peer==null or generation!=character_list_generation:return false
	var selected:=false
	for row in characters:
		if int(row.source)==source and str(row.resref)==resref and int(row.get("generation",-1))==character_list_generation:selected=true;break
	if not selected:return false
	var packet: Dictionary=Characters.preview_request(source,resref)
	if packet.has("error"):return false
	pending_preview={"source":source,"resref":resref,"type":5 if source==17 else 4 if source==14 else 1,"generation":character_list_generation}
	return await peer.send_game_message(packet.bytes)

func play_character(source: int,resref: String,generation: int)->bool:
	if phase not in ["character-selection","character-rejected"] or character_submission_pending or peer==null or generation!=character_list_generation:return false
	var selected:=false
	for row in characters:
		if int(row.source)==source and str(row.resref)==resref and int(row.get("generation",-1))==character_list_generation:selected=true;break
	if not selected:return false
	var packet: Dictionary=Characters.play_request(source,resref)
	if packet.has("error"):return false
	if lobby_players.subscribed and not (await lobby_player_subscription(false)).get("sent",false):return false
	if phase not in ["character-selection","character-rejected"] or generation!=character_list_generation:return false
	selected=false
	for row in characters:
		if int(row.source)==source and str(row.resref)==resref and int(row.get("generation",-1))==character_list_generation:selected=true;break
	if not selected:return false
	character_submission_pending=true
	pending_preview.clear()
	saved_character_id=""
	character_confirmed=false;module_information.clear();module_ready_sent=false
	change_phase("character-loading")
	deadline=Time.get_ticks_msec()+30000
	if not await peer.send_game_message(packet.bytes):return false
	return true

func play_local_character(bic: PackedByteArray,create_on_server: bool=false,vault_id: String="")->bool:
	if phase not in ["character-selection","character-rejected"] or character_submission_pending or peer==null or catalog==null or not local_vault_allowed and not create_on_server or bic.size()<4 or bic.slice(0,4).get_string_from_ascii()!="BIC ":return false
	var document:=GffDocument.new()
	if document.parse(bic,"BIC ").is_empty():return false
	if lobby_players.subscribed and not (await lobby_player_subscription(false)).get("sent",false):return false
	var owned: PackedByteArray=bic.duplicate()
	var packet: Dictionary=Characters.upload_request(owned,19 if create_on_server else 1)
	owned.fill(0)
	if packet.has("error"):return false
	character_submission_pending=true
	character_uploaded=true
	pending_preview.clear()
	saved_character_id=vault_id
	character_confirmed=false;module_information.clear();module_ready_sent=false
	change_phase("character-loading")
	deadline=Time.get_ticks_msec()+30000
	var transient_packet: PackedByteArray=packet.bytes
	var sent: bool=await peer.send_game_message(transient_packet)
	transient_packet.fill(0)
	packet.bytes=PackedByteArray()
	if not sent:return false
	return true

func set_server_vault_policy(server_info: Dictionary,host: String,port: int)->bool:
	# Only a fresh BNXR query for this endpoint may admit local BIC uploads.
	var allow_local: Variant=server_info.get("allowLocalVaultCharacters",null)
	if phase!="idle" or local_vault_policy_known or not (allow_local is int or allow_local is bool) or str(server_info.get("host","")).to_lower()!=host.to_lower() or int(server_info.get("port",0))!=port:return false
	local_vault_allowed=bool(allow_local)
	local_vault_policy_known=true
	server_info_snapshot=server_info.duplicate(true)
	return true

func lobby_player_subscription(open: bool)->Dictionary:
	if phase not in ["character-selection","character-rejected"] or peer==null:return {"error":"Lobby player list is unavailable outside character selection"}
	if lobby_players.subscribed==open:return {"sent":false,"subscribed":open}
	var previous: bool=lobby_players.subscribed
	lobby_subscription_serial+=1
	var serial:=lobby_subscription_serial
	lobby_players.set_subscribed(open)
	var packet:=PackedByteArray([112,49,1 if open else 2])
	if not await peer.send_game_message(packet):
		if serial==lobby_subscription_serial:lobby_players.set_subscribed(previous)
		return {"error":"Lobby player list request failed"}
	if phase not in ["character-selection","character-rejected"]:return {"error":"Lobby player list is unavailable outside character selection"}
	lobby_players_ready.emit(lobby_players.list())
	return {"sent":true,"subscribed":open}

func acknowledge_module_if_ready()->void:
	if not character_confirmed or module_information.is_empty() or module_ready_sent or peer==null:return
	if not await peer.send_game_message(PackedByteArray([112,3,2])):fail("Native module-ready acknowledgement failed");return
	if phase in ["closed","failed","disconnecting"]:return
	module_ready_sent=true
	change_phase("area-loading")
	deadline=Time.get_ticks_msec()+30000

func area_ready(render_world: Node)->bool:
	if phase!="area-presenting" or peer==null or catalog==null or not is_instance_valid(render_world):return false
	if int(render_world.get("area_id"))!=world_state.area_id or not render_world.has_method("ready_for_admission") or not render_world.ready_for_admission():return false
	area_ready_sent=true
	if not await peer.send_game_message(PackedByteArray([112,4,3])):
		area_ready_sent=false
		return fail("Native client-area acknowledgement failed")
	if phase!="area-presenting":return false
	change_phase("playing")
	for message in pending_nui:ui_message_ready.emit(message)
	pending_nui.clear()
	for message in pending_area_visual:area_visual_ready.emit(message)
	pending_area_visual.clear()
	drain_creature_voice()
	return true

func prepare_installed_start(profile: String,install: String,settings_directory_override: String)->Dictionary:
	if phase!="idle" or not profile.is_absolute_path() or not install.is_absolute_path():return {"error":"Invalid native network connection settings"}
	profile_root=profile.simplify_path();install_root=install.simplify_path()
	var build: Dictionary=await Build.read(install_root)
	if phase=="closed":return {"error":"Native network connection closed"}
	if build.has("error"):return build
	build_owner=build.identityOwner
	local_build=build.get("build",{}).duplicate(true)
	var talk_file:=FileAccess.open(install_root.path_join("lang/en/data/dialog.tlk"),FileAccess.READ)
	if talk_file==null:return {"error":"Original language table is unavailable"}
	var talk:=talk_file.get_buffer(12)
	talk_file.close()
	if talk.size()<12 or talk.slice(0,8).get_string_from_ascii()!="TLK V3.0":return {"error":"Original language table is unavailable"}
	language=int(talk.decode_u32(8))
	var startup: Dictionary=StartupPaths.resolve(install_root)
	if startup.has("error"):return startup
	character_vault=CharacterExportVault.new()
	var vault_parent:=settings_directory_override if not settings_directory_override.is_empty() else str(startup.settingsDirectory)
	if not character_vault.configure(vault_parent.path_join("godot-character-vault")):
		character_vault=null
		character_vault_error="Character vault directory is unavailable."
	return {"build":build,"startup":startup}

func prepare_storage_owners(reuse_installed_nwsync: bool)->bool:
	if content_store!=null or repository!=null or peer!=null:return false
	var cache:=profile_root.path_join("replacement-client/server-content")
	var content_helper:=ProjectSettings.globalize_path("res://../tooling/native/content-reader/nwn-content-reader.exe")
	content_store=Store.new()
	var native_directory:=profile_root.path_join("nwsync") if reuse_installed_nwsync else ""
	installed_nwsync_directory=native_directory
	if not content_store.configure(cache,native_directory,content_helper):return false
	var content_repository:=Repository.new();add_child(content_repository)
	bind_repository(content_repository)
	peer=Peer.new()
	return true

func prepare_portal_start(profile: String,install: String,settings_directory_override: String="",reuse_installed_nwsync: bool=true)->bool:
	if not prepared_portal_context.is_empty():return false
	var prepared: Dictionary=await prepare_installed_start(profile,install,settings_directory_override)
	if prepared.has("error"):return false
	if not prepare_storage_owners(reuse_installed_nwsync):return false
	prepared_portal_context=prepared
	return true

func start(host: String,port: int,profile: String,install: String,server_password: String="",temporary_cd_key: String="",player_name_override: String="",settings_directory_override: String="",reuse_installed_nwsync: bool=true,expected_server_key: PackedByteArray=PackedByteArray())->bool:
	if phase!="idle" or host.is_empty() or port<1 or port>65535 or not profile.is_absolute_path() or not install.is_absolute_path() or expected_server_key.size() not in [0,32]:return false
	var crypto_helper:=ProjectSettings.globalize_path("res://../tooling/native/nwn-network-crypto.exe")
	var prepared: Dictionary=prepared_portal_context
	prepared_portal_context={}
	if prepared.is_empty():prepared=await prepare_installed_start(profile,install,settings_directory_override)
	elif profile.simplify_path()!=profile_root or install.simplify_path()!=install_root:return fail("Prepared portal destination does not match this installation")
	if phase=="closed":return false
	if prepared.has("error"):return fail(str(prepared.error))
	if not character_vault_error.is_empty():
		var vault_event: Dictionary={"code":"character.vault-open-failed","reason":"Local character storage: "+character_vault_error}
		diagnostic_event.emit(vault_event)
		diagnostic.emit(str(vault_event.code),str(vault_event.reason))
	var build: Dictionary=prepared.build
	var startup: Dictionary=prepared.startup
	if portal_identity!=null:
		var portal_settings_directory:=settings_directory_override if not settings_directory_override.is_empty() else str(startup.settingsDirectory)
		if not select_portal_workshop(str(startup.defaultModsDirectory),portal_settings_directory):return fail("Saved client settings are unavailable")
		player_name=player_name_override.strip_edges()
		if not player_name.is_empty() and not Settings.new().valid_label(player_name):return fail("Player name is invalid")
		identity=portal_identity;portal_identity=null
	else:
		var settings_directory:=settings_directory_override if not settings_directory_override.is_empty() else str(startup.settingsDirectory)
		var settings:=Settings.new()
		if not settings.open(settings_directory,str(startup.defaultModsDirectory)):return fail("Saved client settings are unavailable")
		mods_directory=str(settings.state.get("modsDirectory",startup.defaultModsDirectory))
		disabled_mods=settings.state.get("disabledMods",[]).duplicate(true)
		var credential: Dictionary={}
		if temporary_cd_key.is_empty():
			credential=settings.cd_key()
		else:
			var candidate:=temporary_cd_key.strip_edges().to_upper()
			if not Settings.valid_cd_key_bytes(candidate.to_utf8_buffer()):settings.close();return fail("The temporary CD key format is invalid")
			credential={"cdKey":candidate}
		if credential.has("error"):
			var credential_error:=str(credential.error)
			settings.close();return fail(credential_error)
		var active: Dictionary=settings.active_row(settings.state)
		player_name=str(active.get("playerName","")) if player_name_override.is_empty() else player_name_override.strip_edges()
		if not player_name.is_empty() and not settings.valid_label(player_name):settings.close();return fail("Player name is invalid")
		settings.close()
		identity=Identity.new()
		if not identity.configure(str(credential.cdKey),server_password):
			credential.cdKey=""
			return fail("Saved CD key format is unavailable")
		credential.cdKey=""
	if peer==null and not prepare_storage_owners(reuse_installed_nwsync):return fail("NWSync content cache is unavailable")
	peer.diagnostic_event.connect(func(event: Dictionary):
		diagnostic_event.emit(event.duplicate(true))
		diagnostic.emit(str(event.get("code","")),str(event.get("reason",""))))
	peer.closed_event.connect(func(event: Dictionary):
		peer_closed_event=event.duplicate(true)
		if event.get("reason",{}) is Dictionary:disconnect_reason=event.get("reason",{}).duplicate(true)
		if bool(event.get("failed",false)) and phase not in ["closed","failed"] and disconnect_reason.is_empty() and portal_pending.is_empty() and client_failure.is_empty():
			client_failure={"code":"network.peer-failed","reason":"The game connection was lost.","cause":{"code":"network.peer-failed","reason":"Native network peer failed"},"phase":phase,"areaGeneration":area_generation})
	var metadata: Dictionary={"connectionType":16,"build":build.build,"language":language,"name":player_name,"legacyPublicKey":"","platformId":build.platformId,"platformIdentifier":Callable(build_owner,"platform_identifier")}
	if not world_state.begin_client_connection(int(metadata.connectionType)):return fail("Native client connection permission could not initialize")
	var connecting_peer: RefCounted=peer
	var connected: bool=await connecting_peer.connect_to_server(host,port,identity,metadata,crypto_helper,expected_server_key)
	if phase=="closed" or peer!=connecting_peer:return false
	if not connected:
		peer_connection_failure=connecting_peer.connection_failure.duplicate(true)
		if peer_connection_failure.is_empty():peer_connection_failure=ConnectionFailure.project({"name":"Error","message":str(connecting_peer.error)},"session-connect")
		if not connecting_peer.disconnecting:
			var failure_event: Dictionary={"code":"network.session-connect-failed","reason":"Native session connection failed","failure":peer_connection_failure.duplicate(true)}
			diagnostic_event.emit(failure_event)
			diagnostic.emit(str(failure_event.code),str(failure_event.reason))
		return fail(ConnectionFailure.failure_text(peer_connection_failure))
	change_phase("connecting")
	deadline=Time.get_ticks_msec()+15000
	return true

static func transport_failure_reason(result: Dictionary)->String:
	var reason:=str(result.get("error",""))
	if reason.is_empty() or not result.has("connectionError"):
		return reason
	return "%s (connection error %d)" % [reason,int(result.connectionError)]

static func client_failure_text(value: Variant)->String:
	if not value is String:return ""
	var key_pattern:=RegEx.create_from_string("(?i)\\b[A-Z0-9]{5}(?:-[A-Z0-9]{5}){6}\\b")
	var control_pattern:=RegEx.create_from_string("[\\x00-\\x1f\\x7f]")
	var cleaned: String=key_pattern.sub(value,"[protected key]",true)
	return control_pattern.sub(cleaned," ",true).substr(0,384)

func _process(_delta: float)->void:
	if phase in ["idle","closed","failed","portal-ready","disconnecting"] or peer==null:return
	if peer_poll_pending:return
	if pending_character_export and Time.get_ticks_msec()>character_export_deadline:
		pending_character_export=false
		character_export_deadline=0
		character_export_uncertain=true
		var timeout_event: Dictionary={"code":"network.character-export-timeout","reason":"The server character export did not arrive before the save deadline"}
		diagnostic_event.emit(timeout_event)
		diagnostic.emit(str(timeout_event.code),str(timeout_event.reason))
		character_export_status_ready.emit({"state":"failed","text":"Timed out waiting for the server character export; the connection remains open.","uncertain":true})
	var level_timeout: Dictionary=level_up.timeout(Time.get_ticks_msec())
	if not level_timeout.is_empty():ui_message_ready.emit(level_timeout)
	if Time.get_ticks_msec()>deadline and phase in ["connecting","resources","characters","character-loading","area-loading","area-presenting","transferring","portal-character-pending"]:
		if phase=="transferring":portal_fail("The old server did not complete its character handoff")
		else:fail("Original-server session timed out")
		return
	peer_poll_pending=true
	var active_peer: RefCounted=peer
	var result: Dictionary=await active_peer.poll()
	await handle_poll_result(result,active_peer)
	peer_poll_pending=false

func invalid_game_message(bytes: PackedByteArray,reason: String,object_update: Variant=null)->void:
	var event: Dictionary={"code":"network.game-message-invalid","reason":reason,"length":bytes.size(),"major":int(bytes[1]) if bytes.size()>1 else -1,"minor":int(bytes[2]) if bytes.size()>2 else -1}
	if object_update!=null:event.objectUpdate=object_update.duplicate(true) if object_update is Dictionary or object_update is Array else object_update
	diagnostic_event.emit(event)

func decode_server_game_message(bytes: PackedByteArray)->Dictionary:
	# The old decodeServerGameMessage boundary is independent of Session phase.
	# Inspect only the prefix here. Individual decoders own the payload.
	if bytes.size()<3 or bytes[0]!=80:return {"error":"Invalid native game-message envelope"}
	var major:=int(bytes[1]);var minor:=int(bytes[2])
	if major==1 and minor in [1,2] and bytes.size()!=3:return {"error":"Invalid native server availability message"}
	if major==2 and minor in [5,16] and bytes.size()!=3:return {"error":"Invalid native character admission response"}
	if major==2 and minor==12 and bytes.size()!=3:return {"error":"Invalid native login waypoint request"}
	if major==7 and minor==6 and bytes.size()!=3:return {"error":"Invalid native store close"}
	if major==20 and minor==5 and bytes.size()!=3:return {"error":"Invalid native dialog-close message"}
	if major==29 and minor in [1,2,3] and bytes.size()!=3:return {"error":"Invalid native level-up acknowledgement"}
	if major==5 and minor==1 and bytes.size()==3:return {"error":"Invalid empty native object-update message"}
	var incoming_build: Dictionary=remote_build if not remote_build.is_empty() else local_build
	var providers: Dictionary=object_rules.providers() if object_rules!=null else {}
	var message: Dictionary={}
	if NetworkModulePause.accepted(major,minor):message=NetworkModulePause.decode_packet(bytes)
	elif GuiAccess.accepted(major,minor):message=GuiAccess.decode_packet(bytes,incoming_build)
	elif NetworkItemCaption.accepted(major,minor):message=NetworkItemCaption.decode_packet(bytes)
	elif NetworkPortal.accepted(major,minor):message=NetworkPortal.decode_packet(bytes)
	elif NetworkTargeting.accepted(major,minor):message=NetworkTargeting.decode_packet(bytes)
	elif NetworkNui.accepted(major,minor):message=NetworkNui.decode_packet(bytes)
	elif NetworkLevelUp.accepted(major,minor):message=NetworkLevelUp.decode_packet(bytes)
	elif major==17 and minor==2:
		message=Characters.decode_packet(bytes)
		if not message.has("error"):message.kind="server-character-list"
	elif major==17 and minor==4:
		message=Characters.decode_preview_packet(bytes)
		if not message.has("error"):
			message.kind="server-character-preview"
			message.data=message.bytes
	elif LobbyPlayer.accepted(major,minor):message=LobbyPlayer.decode_packet(bytes)
	elif NetworkStore.accepted(major,minor):message=NetworkStore.decode_packet(bytes)
	elif NetworkFeedback.accepted(major,minor):message=NetworkFeedback.decode_packet(bytes,incoming_build)
	elif NetworkSound.accepted(major,minor):message=NetworkSound.decode_packet(bytes)
	elif NetworkAmbient.accepted(major,minor):message=NetworkAmbient.decode_packet(bytes)
	elif NetworkCharacterExport.accepted(major,minor):message=NetworkCharacterExport.decode_packet(bytes)
	elif ServerStatus.accepted(major,minor):message=ServerStatus.decode_packet(bytes)
	elif major==2 and minor==5:
		if bytes.size()!=3:return {"error":"Invalid native character admission response"}
		message={"kind":"character-confirmed"}
	elif CharacterNeeded.accepted(major,minor):message=CharacterNeeded.decode_packet(bytes)
	elif major==2 and minor==12:
		if bytes.size()!=3:return {"error":"Invalid native login waypoint request"}
		message={"kind":"login-waypoint-request"}
	elif NetworkRuntime.accepted(major,minor):message=NetworkRuntime.decode_packet(bytes)
	elif AreaVisuals.accepted(major,minor):message=AreaVisuals.decode_packet(bytes,incoming_build)
	elif NetworkDmPermission.accepted(major,minor):message=NetworkDmPermission.decode_packet(bytes)
	elif NetworkExamine.accepted(major,minor):message=NetworkExamine.decode_packet(bytes,incoming_build)
	elif major==13 and minor==1:message=InventoryWindowStatus.decode_packet(bytes)
	elif NetworkParty.accepted(major,minor):message=NetworkParty.decode_packet(bytes)
	elif NetworkBarter.accepted(major,minor):message=NetworkBarter.decode_packet(bytes)
	elif major==5 and minor==1:
		message=_decode_object_update(bytes,incoming_build,providers)
		if not message.has("error"):message.kind="object-updates"
	elif major==5 and minor==2 or major==10 and minor in [1,2,3]:message=PlayerRoster.decode_packet(bytes)
	elif major==14 and minor==14:
		var reader:=Requirements.Reader.new()
		if not reader.configure(bytes.slice(3)):return {"error":"Invalid native module-time bit streams"}
		message={"kind":"object-control","playerId":reader.dword(),"objectId":reader.object_id()}
		if not reader.finished():return {"error":"Invalid native object-control fields"}
	elif major==30 and minor in [1,2]:message=Quickbar.decode_packet(bytes,incoming_build,providers)
	elif NetworkProjectile.accepted(major,minor):message=NetworkProjectile.decode_packet(bytes)
	elif NetworkCamera.accepted(major,minor):message=NetworkCamera.decode_packet(bytes)
	elif major==12 and (minor in range(1,11) or minor==14):message=InventoryResponse.decode_packet(bytes)
	elif major==20 and minor in [1,2,4,5]:message=NetworkDialog.decode_packet(bytes)
	elif major==4 and minor==1:
		message=AreaState.decode_packet(bytes,incoming_build)
		if not message.has("error"):message.kind="client-area"
	elif major==3 and minor==1:
		var module: Dictionary=ModuleInfo.decode_packet(bytes,incoming_build)
		message=module if module.has("error") else {"kind":"module-info","module":module}
	elif major==2 and minor==18:
		var reader:=Requirements.Reader.new()
		if not reader.configure(bytes.slice(3)):return {"error":"Invalid native module-time bit streams"}
		message={"kind":"character-rejected","reason":reader.dword()}
		if not reader.finished():return {"error":"Invalid native character rejection fields"}
	elif major==1 and minor==3:
		var requirements: Dictionary=Requirements.decode_packet(bytes)
		message=requirements if requirements.has("error") else {"kind":"server-resources","requirements":requirements}
	elif major==3 and minor==3:
		message=ModuleTime.decode_packet(bytes)
		if not message.has("error"):message.kind="module-time"
	elif NetworkCustomToken.accepted(major,minor):message=NetworkCustomToken.decode_packet(bytes)
	elif NetworkCreatureVoice.accepted(major,minor):message=NetworkCreatureVoice.decode_packet(bytes)
	elif major==25 and minor==1:message=ContainerStatus.decode_packet(bytes)
	elif NetworkHud.accepted(major,minor):message=NetworkHud.decode_packet(bytes)
	elif ObjectVisual.accepted(major,minor):message=ObjectVisual.decode_packet(bytes,incoming_build,providers)
	elif major==9 and minor in NetworkSpeech.CHANNELS:message=NetworkSpeech.decode_packet(bytes)
	else:return {"kind":"unsupported","major":major,"minor":minor,"length":bytes.size()}
	if message.has("error"):
		var label:=game_message_stream_label(major,minor)
		if not label.is_empty():
			var reader:=Requirements.Reader.new()
			if not reader.configure(bytes.slice(3)):return {"error":label}
		var reason:=str(message.error)
		if reason.find(" fields")>=0 or reason.find("stream incomplete")>=0 or reason.ends_with(" envelope"):
			var fields_label:=game_message_fields_label(major,minor)
			if not fields_label.is_empty():
				var fields_error: Dictionary={"error":fields_label}
				if message.has("objectUpdate"):fields_error.objectUpdate=message.objectUpdate
				return fields_error
		return message
	message.major=major;message.minor=minor
	return message

func game_message_stream_label(major: int,minor: int)->String:
	if major==3 and minor==9:return "Invalid native module-pause streams"
	if major==53 and minor==2 or major==36 and minor==4:return "Invalid native GUI access streams"
	if major==24 and minor==5:return "Invalid native item-caption streams"
	if major==42 and minor==1 or major==43 and minor in [2,3]:return "Invalid native portal streams"
	if major==18 and minor==23 or major==57 and minor in [1,2]:return "Invalid native script targeting streams"
	if major==55 and minor in [1,2,4,5]:return "Invalid native NUI streams"
	if major==29 and minor==4:return "Invalid native level-up streams"
	if major==17 and minor in [2,4] or major==49 and minor==3:return "Invalid native character-selection streams"
	if major==7 and minor in [3,4]:return "Invalid native store streams"
	if major==18 and minor==14:return "Invalid native initiative streams"
	if major==23 and minor in [2,3,4,5,6,7]:return "Invalid native sound-object streams"
	if major==40 and minor in [1,2,3,4,5,6,7,8]:return "Invalid native ambient streams"
	if major==3 and minor==10:return "Invalid native character export streams"
	if major==4 and minor==4:return "Invalid native weather streams"
	if major==4 and minor==13:return "Invalid native wind streams"
	if major==31 and minor==22:return "Invalid native DM-permission streams"
	if major==27 and minor in [2,3,4,5,6]:return "Invalid native examination streams"
	if major==13 and minor==1:return "Invalid native inventory-window streams"
	if major==36 and minor==3:return "Invalid native party invitation streams"
	if major==35 and minor in [2,4,8,10,11]:return "Invalid native barter streams"
	if major in [1,2,3,4,5,9,10,12,14,16,18,20,22,25,26,28,30,32,34,41,48,50,52,54]:return "Invalid native module-time bit streams"
	return ""

func game_message_fields_label(major: int,minor: int)->String:
	if major==3 and minor==9:return "Invalid native module-pause fields"
	if major==53 and minor==2 or major==36 and minor==4:return "Invalid native GUI access fields"
	if major==24 and minor==5:return "Invalid native item-caption fields"
	if major==42 and minor==1 or major==43 and minor in [2,3]:return "Invalid native portal fields"
	if major==18 and minor==23 or major==57 and minor in [1,2]:return "Invalid native script targeting fields"
	if major==55 and minor in [1,2,4,5]:return "Invalid native NUI fields"
	if major==29 and minor==4:return "Invalid native level-up classes"
	if major==17 and minor in [2,4] or major==49 and minor==3:return "Invalid native character-selection fields"
	if major==7 and minor in [3,4]:return "Invalid native store fields"
	if major==18 and minor==14:return "Invalid native initiative fields"
	if major==23 and minor in [2,3,4,5,6,7]:return "Invalid native sound-object fields"
	if major==40 and minor in [1,2,3,4,5,6,7,8]:return "Invalid native ambient fields"
	if major==3 and minor==10:return "Invalid native character export fields"
	if major==4 and minor==4:return "Invalid native weather fields"
	if major==4 and minor==13:return "Invalid native wind fields"
	if major==31 and minor==22:return "Invalid native DM-permission fields"
	if major==27 and minor in [2,3,4,5,6]:return "Invalid native examination fields"
	if major==13 and minor==1:return "Invalid native inventory-window fields"
	if major==36 and minor==3:return "Invalid native party invitation fields"
	if major==35 and minor in [2,4,8,10,11]:return "Invalid native barter fields"
	if major==18 and minor in [3,5,6,8,11] or major==50 and minor==1:return "Invalid native feedback or token fields"
	if major==52 and minor in [2,3] or major==54 and minor==2:return "Invalid native runtime message fields"
	if major==9:return "Invalid native server speech"
	if major==25 and minor==1:return "Invalid native container status"
	if major in [28,32,41,48]:return "Invalid native HUD message fields"
	if major==16:return "Invalid native camera fields"
	if major==4 and minor==2:return "Invalid native area visual fields"
	if major==5 and minor==3:return "Invalid native object visual fields"
	if major==14 and minor in [1,3,4]:return "Invalid native party-list fields"
	if major==22:return "Invalid native quick-chat fields"
	if major==26:return "Invalid native creature voice fields"
	if major==30:return "Invalid native quickbar fields"
	if major==34:return "Invalid native projectile fields"
	if major==12:return "Invalid native inventory result"
	if major==20:return "Invalid native dialog fields"
	if major==5 and minor==1:return "Invalid native object-update fields"
	if major==10:return "Invalid native player-list fields"
	if major==4 and minor==1:return "Invalid native area-information fields"
	if major==5 and minor==2 or major==14 and minor==14:return "Invalid native object-control fields"
	if major==3 and minor==1:return "Invalid native module-information fields"
	if major==2 and minor==18:return "Invalid native character rejection fields"
	if major==1 and minor==3:return "Invalid native server-resource message fields"
	if major==3 and minor==3:return "Invalid native module-time message fields"
	return ""

func handle_poll_result(result: Dictionary,active_peer: RefCounted)->void:
	if active_peer!=peer or phase in ["closed","failed","disconnecting"]:return
	if not peer.connection_failure.is_empty():peer_connection_failure=peer.connection_failure.duplicate(true)
	var transport_error:=transport_failure_reason(result)
	# A BNDP may share this poll with earlier reliable records. Deliver those
	# records in wire order before retiring the connection in every phase.
	if not transport_error.is_empty() and result.get("payloads",[]).is_empty():
		if phase=="transferring" and portal_pending.has("character"):
			if not await release_portal():portal_fail("The old server connection could not be released")
		elif phase=="transferring":portal_fail("The old server closed without a portal character handoff")
		else:fail(transport_error)
		return
	if phase=="connecting" and result.get("admitted",false):
		remote_build=result.get("remote",{}).get("build",{}).duplicate(true)
		if not await flush_device_metrics():fail("Native device properties could not be sent");return
		if not await peer.send_game_message(PackedByteArray([112,1,0])):fail("Server status request failed");return
		change_phase("resources");deadline=Time.get_ticks_msec()+15000
	_world_delivery_serial+=1
	var delivery:=_world_delivery_serial
	_immediate_world_projection={}
	processing_delivery=true
	for bytes in result.get("payloads",[]):
		var decoded: Dictionary=decode_server_game_message(bytes)
		if decoded.has("error"):
			invalid_game_message(bytes,str(decoded.error),decoded.get("objectUpdate",null))
			continue
		if bytes[1]==17 and bytes[2]==2 and (phase!="characters" or not server_character_list_pending):
			diagnostic_event.emit({"code":"network.character-list-stale","reason":"Unrequested or stale server character list was ignored"})
			continue
		if bytes[1]==1 and bytes[2]==3 and catalog!=null:
			diagnostic_event.emit({"code":"network.resource-repeat-ignored","reason":"Repeated module resource initialization was ignored"})
			continue
		if bytes[1]==54 and bytes[2]==2:
			var response: Dictionary=RuntimeMessages.device_echo_response(decoded.data)
			if response.has("error") or not await peer.send_game_message(response.bytes):fail("Native device echo response failed");return
			device_echo_replies+=1
			continue
		if bytes[1]==2 and bytes[2]==12:
			login_waypoint_requests+=1
			var waypoint: Dictionary=RuntimeMessages.login_waypoint_response(login_waypoint)
			if waypoint.has("error"):fail(str(waypoint.error));return
			if not waypoint.bytes.is_empty() and not await peer.send_game_message(waypoint.bytes):fail("Native login waypoint response failed");return
			login_waypoint=""
			continue
		if NetworkPortal.accepted(int(bytes[1]),int(bytes[2])):
			var portal_message: Dictionary=decoded
			if portal_message.kind=="portal-activate":
				if not await begin_portal(portal_message):processing_delivery=false;return
			else:
				if not finish_portal(portal_message):processing_delivery=false;return
				if phase=="portal-ready":processing_delivery=false;return
			continue
		if NetworkCharacterExport.accepted(int(bytes[1]),int(bytes[2])):
			var export_message: Dictionary=decoded
			receive_character_export(export_message)
			continue
		if phase in ["resources","loading-content","characters","character-selection","character-loading","area-loading","area-presenting","playing"] and NetworkDmPermission.accepted(int(bytes[1]),int(bytes[2])):
			var permission: Dictionary=decoded
			if not world_state.apply_dm_permission(permission):fail("Invalid native game-master permission: "+str(world_state.error));return
			world_revision+=1
			for frame in visibility_frames.permission_frames(world_state,permission,area_generation,text_event_connection):visibility_frame_ready.emit(frame)
			continue
		if phase in ["character-loading","area-loading","area-presenting","playing"] and NetworkCustomToken.accepted(int(bytes[1]),int(bytes[2])):
			var token_message: Dictionary=decoded
			if not world_state.apply_custom_token(token_message):fail("Invalid native custom-token world state");return
			world_revision+=1
			ui_message_ready.emit(token_message)
			continue
		if phase in ["character-loading","area-loading","area-presenting","playing"] and bytes[1]==52 and int(bytes[2]) in [2,3]:
			var tlk_message: Dictionary=decoded
			tlk_override_messages+=1
			if not world_state.apply_tlk_overrides(tlk_message):fail("Invalid native TLK override: "+str(world_state.error));return
			if not tlk_message.entries.is_empty():
				world_revision+=1
				ui_message_ready.emit(tlk_message)
			continue
		if phase=="resources" and ServerStatus.accepted(int(bytes[1]),int(bytes[2])):
			var status: Dictionary=decoded
			server_status=str(status.kind)
			server_status_ready.emit(status)
			continue
		if phase=="resources" and bytes[1]==1 and bytes[2]==3:
			var requirements: Dictionary=decoded.requirements
			# Servers without NWSync still provide module/HAK/TLK requirements.
			# Resolve those from the installed resource stack before character admission.
			if requirements.get("advertisement") is Dictionary:
				if not repository.configure(str(requirements.advertisement.url),profile_root.path_join("replacement-client/server-content")):fail("Invalid NWSync repository URL");return
			change_phase("loading-content")
			load_content.call_deferred(requirements)
		elif phase=="characters" and bytes[1]==17 and bytes[2]==2:
			var list: Dictionary=decoded
			server_character_list_pending=false
			character_list_generation+=1
			pending_preview.clear()
			characters.clear()
			for row in list.characters:
				var choice: Dictionary=row.duplicate(true)
				choice.generation=character_list_generation
				characters.append(choice)
			change_phase("character-selection")
			character_list_ready.emit(characters.duplicate(true))
		elif phase in ["character-selection","character-rejected"] and bytes[1]==17 and bytes[2]==4:
			var preview: Dictionary=decoded
			if pending_preview.is_empty() or int(pending_preview.get("generation",-1))!=character_list_generation or str(preview.resref)!=str(pending_preview.resref) or int(preview.previewType)!=int(pending_preview.type):
				var stale_bytes: PackedByteArray=preview.get("bytes",PackedByteArray())
				stale_bytes.fill(0)
				preview.bytes=PackedByteArray()
				var stale_data: PackedByteArray=preview.get("data",PackedByteArray())
				stale_data.fill(0)
				preview.data=PackedByteArray()
				continue
			pending_preview.clear()
			character_preview_ready.emit(preview)
			var preview_bytes: PackedByteArray=preview.get("bytes",PackedByteArray())
			preview_bytes.fill(0)
			preview.bytes=PackedByteArray()
			var preview_data: PackedByteArray=preview.get("data",PackedByteArray())
			preview_data.fill(0)
			preview.data=PackedByteArray()
		elif phase in ["character-selection","character-rejected"] and LobbyPlayer.accepted(int(bytes[1]),int(bytes[2])):
			var player_message: Dictionary=decoded
			if not lobby_players.subscribed:continue
			if not lobby_players.apply(player_message):fail("Native lobby-player registry rejected the server record");return
			lobby_players_ready.emit(lobby_players.list())
		elif phase=="character-loading" and bytes[1]==2 and bytes[2]==5:
			character_confirmed=true
			await acknowledge_module_if_ready()
		elif phase=="character-loading" and CharacterNeeded.accepted(int(bytes[1]),int(bytes[2])):
			var needed: Dictionary=decoded
			character_confirmed=false;character_submission_pending=false;character_uploaded=false;module_information.clear();module_ready_sent=false;pending_preview.clear()
			var current_permission: Variant=world_state.game_master_permission
			world_state=WorldState.new()
			session_script_targeting=null
			if current_permission is Dictionary:world_state.game_master_permission=current_permission.duplicate(true)
			world_revision+=1;published_revision=-1
			change_phase("character-selection")
			deadline=Time.get_ticks_msec()+30000
			character_needed_ready.emit(needed)
		elif phase in ["character-loading","area-loading","area-presenting","playing"] and GuiAccess.accepted(int(bytes[1]),int(bytes[2])):
			var gui_message: Dictionary=decoded
			var admitted: Dictionary=gui_access.observe(gui_message)
			if not admitted.get("accepted",false):continue
			var gui_event: Dictionary=gui_access.bind_event(gui_message,gui_access_context())
			world_revision+=1
			if phase=="playing" and not gui_event.is_empty():ui_message_ready.emit({"kind":"gui-panel-access-event","event":gui_event})
		elif phase=="character-loading" and bytes[1]==3 and bytes[2]==1:
			var module: Dictionary=decoded.module
			module_information=module
			if not world_state.apply_module(module):fail("Native world state rejected module information");return
			world_revision+=1
			module_information_ready.emit(module.duplicate(true))
			await acknowledge_module_if_ready()
		elif phase in ["area-loading","playing"] and bytes[1]==4 and bytes[2]==1:
			var area: Dictionary=decoded
			if not world_state.apply_area(area):
				diagnostic_event.emit({"code":"network.area-import-failed","reason":str(world_state.error)})
				fail("Native world state rejected area: "+str(world_state.error));return
			session_script_targeting=null
			area_generation+=1
			area_ready_sent=false
			gui_panel_attempt_scope.clear();gui_panel_attempt_last=0
			level_up.reset()
			pending_level_up_presentation.clear()
			pending_creature_voice.clear()
			current_dialog.clear()
			pending_area_visual.clear()
			pending_visual_packets.clear();pending_visual_bytes=0
			world_revision+=1
			published_revision=-1
			change_phase("area-presenting")
			deadline=Time.get_ticks_msec()+60000
			area_packet_received.emit(bytes.duplicate())
			area_state_ready.emit(area)
		elif phase in ["area-loading","area-presenting","playing"] and bytes[1]==3 and bytes[2]==3:
			var clock: Dictionary=decoded
			world_state.apply_time(clock.changes)
			world_revision+=1
			time_changed.emit(clock.changes)
		elif phase in ["area-loading","area-presenting","playing"] and NetworkModulePause.accepted(int(bytes[1]),int(bytes[2])):
			var pause_message: Dictionary=decoded
			module_pause_ready.emit({"message":pause_message,"areaId":world_state.area_id,"generation":area_generation})
		elif phase in ["area-loading","area-presenting","playing"] and NetworkCamera.accepted(int(bytes[1]),int(bytes[2])):
			var camera_message: Dictionary=decoded
			camera_command_ready.emit(camera_message)
		elif phase in ["area-loading","area-presenting","playing"] and NetworkTargeting.accepted(int(bytes[1]),int(bytes[2])):
			var targeting: Dictionary=decoded
			if not world_state.apply_targeting(targeting):fail("Invalid native targeting instruction: "+str(world_state.error));return
			session_script_targeting=world_state.script_targeting.duplicate(true) if world_state.script_targeting is Dictionary else null
			world_revision+=1
			if phase=="playing":targeting_ready.emit(targeting)
		elif phase in ["area-loading","area-presenting","playing"] and NetworkProjectile.accepted(int(bytes[1]),int(bytes[2])):
			var projectile: Dictionary=decoded
			var current_area:=int(world_state.area_id)
			var source: Dictionary=world_state.registry.get(int(projectile.header.sourceId),{})
			var target: Dictionary=world_state.registry.get(int(projectile.header.targetId),{})
			if not target.is_empty() and (bool(target.get("replicationRemoved",false)) or int(target.get("areaId",-1))!=current_area):return
			projectile.nativeAreaId=current_area
			projectile.nativeAreaGeneration=area_generation
			# The original inbox captures raw registry objects before presentation
			# filtering. Their slot identity survives a delete -> create reuse.
			projectile.sourceRegistration=source.get("nativeProjectileRegistration") if not source.is_empty() else null
			projectile.targetRegistration=target.get("nativeProjectileRegistration") if not target.is_empty() else null
			projectile.sourceLifetime=int(source.get("nativeLifetime",0)) if int(source.get("areaId",-1))==current_area and not bool(source.get("replicationRemoved",false)) else 0
			projectile.targetLifetime=int(target.get("nativeLifetime",0)) if int(target.get("areaId",-1))==current_area and not bool(target.get("replicationRemoved",false)) else 0
			projectile.receivedAtMs=Time.get_ticks_msec()
			projectile_ready.emit(projectile)
		elif phase in ["area-loading","area-presenting","playing"] and NetworkLevelUp.accepted(int(bytes[1]),int(bytes[2])):
			var level_message: Dictionary=decoded
			var level_reply: Dictionary=level_up.receive(level_message,world_state.registry.get(world_state.local_object_id,{}),world_state.area_id,remote_build)
			if not level_reply.is_empty():present_level_up_reply(level_reply)
		elif phase in ["area-loading","area-presenting","playing"] and NetworkCreatureVoice.accepted(int(bytes[1]),int(bytes[2])):
			var voice_message: Dictionary=decoded
			if voice_message.get("kind")=="voice-play":
				var voice_frame: Dictionary=audio_frames.voice(world_state,voice_message,area_generation,text_event_connection)
				if voice_frame.is_empty():continue
				voice_message.nativeVoiceFrame=voice_frame
			var voice_actor: Dictionary=world_state.registry.get(int(voice_message.objectId),{})
			if voice_actor.is_empty() or int(voice_actor.get("objectType",0))!=5 or int(voice_actor.get("areaId",-1))!=world_state.area_id or bool(voice_actor.get("replicationRemoved",false)):continue
			if phase=="playing":creature_voice_ready.emit(voice_message)
			elif pending_creature_voice.size()<128:pending_creature_voice.append({"areaId":world_state.area_id,"lifetime":int(voice_actor.get("nativeLifetime",0)),"message":voice_message})
			else:fail("Native creature voice admission queue exceeded bound");return
		elif phase in ["area-loading","area-presenting","playing"] and (bytes[1]==10 and int(bytes[2]) in [1,2,3] or bytes[1]==5 and bytes[2]==2 or bytes[1]==14 and bytes[2]==14):
			var roster: Dictionary=decoded
			var roster_notices: Array[Dictionary]=NetworkSystemNotices.from_message(roster,world_state.players,phase=="playing")
			if not world_state.apply_roster(roster):fail("Native world state rejected roster: "+str(world_state.error));return
			world_revision+=1
			for notice in roster_notices:system_notice_ready.emit(notice)
			roster_message_ready.emit(roster)
		elif phase in ["area-loading","area-presenting","playing"] and bytes[1]==5 and bytes[2]==1:
			if not decode_object_packet(bytes,decoded):return
		elif phase in ["area-loading","area-presenting","playing"] and ObjectVisual.accepted(int(bytes[1]),int(bytes[2])):
			if not decode_visual_packet(bytes,decoded):return
		elif phase in ["area-loading","area-presenting","playing"] and bytes[1]==30 and int(bytes[2]) in [1,2]:
			if not decode_quickbar_packet(bytes,decoded):return
		elif phase in ["area-loading","area-presenting","playing"] and NetworkItemCaption.accepted(int(bytes[1]),int(bytes[2])):
			var caption: Dictionary=decoded
			if world_state.apply_item_caption(caption):world_revision+=1
		elif phase in ["area-loading","area-presenting","playing"] and bytes[1]==12 and (int(bytes[2]) in range(1,11) or bytes[2]==14):
			var response: Dictionary=decoded
			var equipment: Dictionary=EquipmentCache.apply_inventory_equipment_result(world_state.registry,world_state.inventories,world_state.local_object_id,response)
			if bool(equipment.get("applied",false)):
				for id in equipment.staged:
					var canonical: Dictionary=world_state.registry[id]
					canonical.merge(equipment.staged[id],true)
					world_state.registry[id]=canonical
				if equipment.view is Dictionary:world_state.inventories["I"]=equipment.view
				world_revision+=1
				publish_world_if_ready()
			inventory_response_ready.emit(response)
		elif phase in ["area-loading","area-presenting","playing"] and bytes[1]==13 and bytes[2]==1:
			var window: Dictionary=decoded
			if not world_state.observe_inventory_window(window):fail("Invalid native inventory-window status: "+str(world_state.error));return
			world_revision+=1
			ui_message_ready.emit({"kind":"inventory-window-status","windows":world_state.inventory_window_snapshot()})
		elif phase in ["area-loading","area-presenting","playing"] and bytes[1]==25 and bytes[2]==1:
			var container: Dictionary=decoded
			if not world_state.apply_container_status(container):fail("Invalid native container status: "+str(world_state.error));return
			world_revision+=1
		elif phase in ["area-loading","area-presenting","playing"] and NetworkStore.accepted(int(bytes[1]),int(bytes[2])):
			var store_message: Dictionary=decoded
			if not world_state.apply_store(store_message):fail("Invalid native store message: "+str(world_state.error));return
			world_revision+=1
			if store_message.kind in ["store-transaction","store-close"]:
				if phase=="playing":ui_message_ready.emit(store_message)
				else:
					if pending_nui.size()>=4096:fail("Native UI admission queue exceeded bound");return
					pending_nui.append(store_message)
		elif phase in ["area-loading","area-presenting","playing"] and NetworkParty.accepted(int(bytes[1]),int(bytes[2])):
			var party_message: Dictionary=decoded
			if not world_state.apply_party(party_message):fail("Invalid native party message: "+str(world_state.error));return
			world_revision+=1
		elif phase in ["area-loading","area-presenting","playing"] and NetworkExamine.accepted(int(bytes[1]),int(bytes[2])):
			var examine: Dictionary=decoded
			if world_state.apply_examine(examine):world_revision+=1
			if phase=="playing":ui_message_ready.emit(examine)
			else:
				if pending_nui.size()>=4096:fail("Native UI admission queue exceeded bound");return
				pending_nui.append(examine)
		elif phase in ["area-loading","area-presenting","playing"] and NetworkBarter.accepted(int(bytes[1]),int(bytes[2])):
			var barter_message: Dictionary=decoded
			if barter_message.kind!="barter-reject" and world_state.apply_barter(barter_message):world_revision+=1
			barter_message.nativeBarterSerial=int(world_state.barter.get("serial",0)) if world_state.barter is Dictionary else 0
			barter_message.nativeBarterRevision=int(world_state.barter.get("revision",0)) if world_state.barter is Dictionary else 0
			if phase=="playing":ui_message_ready.emit(barter_message)
			else:
				if pending_nui.size()>=4096:fail("Native UI admission queue exceeded bound");return
				pending_nui.append(barter_message)
		elif phase in ["area-loading","area-presenting","playing"] and NetworkSound.accepted(int(bytes[1]),int(bytes[2])):
			var sound_message: Dictionary=decoded
			if world_state.apply_sound_object(sound_message):
				world_revision+=1
				sound_object_ready.emit(sound_message)
			elif not world_state.sound_diagnostic.is_empty():diagnostic_event.emit(world_state.sound_diagnostic.duplicate(true))
			elif not world_state.error.is_empty():fail(str(world_state.error));return
		elif phase in ["area-loading","area-presenting","playing"] and NetworkAmbient.accepted(int(bytes[1]),int(bytes[2])):
			var ambient_message: Dictionary=decoded
			ambient_command_ready.emit(ambient_message)
		elif phase in ["area-loading","area-presenting","playing"] and NetworkNui.accepted(int(bytes[1]),int(bytes[2])):
			var nui: Dictionary=decoded
			if nui.kind=="nui-create" and int(nui.get("format",-1))==0:
				if catalog==null:continue
				var resref:=str(nui.get("resref",""))
				var layout_bytes: PackedByteArray=catalog.get_resource(resref,2083)
				var utf8_bytes: PackedByteArray=layout_bytes.slice(3) if layout_bytes.size()>=3 and layout_bytes[0]==0xef and layout_bytes[1]==0xbb and layout_bytes[2]==0xbf else layout_bytes
				var layout_text:=utf8_bytes.get_string_from_utf8()
				var parser:=JSON.new()
				if utf8_bytes.is_empty() or layout_text.to_utf8_buffer()!=utf8_bytes or parser.parse(layout_text)!=OK or not parser.data is Dictionary:
					diagnostic_event.emit({"code":"network.nui-resource-unavailable","reason":"Native NUI JSON resource could not be loaded","resref":resref})
					continue
				nui.layout=parser.data
			if not nui_state.receive(nui):fail("Invalid native NUI message: "+str(nui_state.failure));return
			if nui.kind=="nui-create":nui.nativeSerial=int(nui_state.windows[int(nui.token)].serial)
			if phase=="playing":ui_message_ready.emit(nui)
			else:
				if pending_nui.size()>=4096:fail("Native NUI admission queue exceeded bound");return
				pending_nui.append(nui)
		elif phase in ["area-loading","area-presenting","playing"] and NetworkHud.accepted(int(bytes[1]),int(bytes[2])):
			var hud: Dictionary=decoded
			var hud_notices: Array[Dictionary]=NetworkSystemNotices.from_message(hud,world_state.players,phase=="playing")
			if not world_state.apply_hud(hud):fail("Invalid native HUD message: "+str(world_state.error));return
			world_revision+=1
			for notice in hud_notices:system_notice_ready.emit(notice)
		elif phase in ["area-loading","area-presenting","playing"] and AreaVisuals.accepted(int(bytes[1]),int(bytes[2])):
			var area_visual: Dictionary=decoded
			if area_visual.kind=="area-visual":
				if not world_state.valid_current_area():continue
				if phase=="playing":area_visual_ready.emit(area_visual)
				else:
					if pending_area_visual.size()>=512:fail("Native area visual admission queue exceeded bound");return
					pending_area_visual.append(area_visual)
			elif world_state.apply_area_visual(area_visual):world_revision+=1
			elif not world_state.error.is_empty():fail(str(world_state.error));return
		elif phase in ["area-loading","area-presenting","playing"] and NetworkFeedback.accepted(int(bytes[1]),int(bytes[2])):
			var feedback: Dictionary=received_text_message(decoded)
			if phase=="playing":ui_message_ready.emit(feedback)
			else:
				if pending_nui.size()>=4096:fail("Native UI admission queue exceeded bound");return
				pending_nui.append(feedback)
		elif phase in ["area-loading","area-presenting","playing"] and bytes[1]==9 and int(bytes[2]) in NetworkSpeech.CHANNELS:
			var speech: Dictionary=received_text_message(decoded)
			if speech.get("kind")=="script-sound":
				var sound_frame: Dictionary=audio_frames.script_sound(world_state,speech,area_generation,text_event_connection)
				if not sound_frame.is_empty():script_sound_frame_ready.emit(sound_frame)
			else:ui_message_ready.emit(speech)
		elif phase in ["area-loading","area-presenting","playing"] and bytes[1]==20 and int(bytes[2]) in [1,2,4,5]:
			var dialog: Dictionary=decoded
			match str(dialog.kind):
				"dialog-entry":current_dialog=dialog.duplicate(true)
				"dialog-replies":
					if current_dialog.is_empty():continue
					current_dialog.replies=dialog.duplicate(true)
				"dialog-close":current_dialog.clear()
			ui_message_ready.emit(dialog)
		elif phase=="character-loading" and bytes[1]==2 and bytes[2]==18:
			var rejection: Dictionary=decoded
			character_confirmed=false;character_submission_pending=false;character_uploaded=false;module_information.clear();module_ready_sent=false;pending_preview.clear()
			change_phase("character-rejected")
			deadline=Time.get_ticks_msec()+30000
			character_rejected_ready.emit(rejection)
		else:diagnostic_event.emit({"code":"network.game-message-unhandled","reason":"Native game-message handler is unavailable","major":int(bytes[1]),"minor":int(bytes[2]),"length":bytes.size()})
	processing_delivery=false
	if phase=="transferring" and not portal_pending.is_empty():
		if portal_pending.has("character"):
			if not await release_portal():portal_fail("The old server connection could not be released")
			return
		if not transport_error.is_empty():portal_fail("The old server closed without a portal character handoff");return
	if not transport_error.is_empty():fail(transport_error);return
	_publish_world_for_delivery(delivery)
	if delivery==_world_delivery_serial:_immediate_world_projection={}

func load_content(requirements: Dictionary)->void:
	var roots: Array[String]=[profile_root,install_root]
	var content_repository: Node=repository
	var resolution: Dictionary=await content_repository.ensure_requirements(content_store,requirements,language,roots,mods_directory,disabled_mods)
	if phase!="loading-content" or repository!=content_repository:return
	if resolution.has("error") or not resolution.get("ready",false):
		fail("Required server content is unavailable: "+str(resolution.get("error","missing="+str(resolution.get("missing",[]).size()))))
		return
	var sources: Dictionary=ResourceSources.build(resolution,install_root,profile_root,profile_root.path_join("replacement-client/server-content"),installed_nwsync_directory,ProjectSettings.globalize_path("res://../tooling/native/content-reader/nwn-content-reader.exe"),mods_directory,disabled_mods)
	if sources.has("error"):fail("Admitted server content cannot be mounted: "+str(sources.error));return
	resource_sources=sources
	catalog_archive_repair_attempted=false
	resource_sources_ready.emit(sources.duplicate(true))
	if phase=="closed" or phase=="failed":return
	catalog_loader=SessionCatalog.new();add_child(catalog_loader)
	catalog_loader.completed.connect(accept_catalog)
	if not portal_character.is_empty():
		change_phase("portal-character-pending")
		deadline=Time.get_ticks_msec()+30000
	catalog_serial=catalog_loader.start(sources)

func change_phase(next: String)->void:
	phase=next
	phase_changed.emit(next)

func fail(reason: String)->bool:
	if phase=="disconnecting":return false
	var exposed_reason:=reason
	if processing_delivery and client_failure.is_empty():
		var safe_reason:=client_failure_text(reason)
		if safe_reason.is_empty():safe_reason="Native game-message processing failed"
		client_failure={"code":"network.game-session-failed","reason":"The client could not process a server update.","cause":{"code":str(last_import_failure.get("code","network.message-processing-failed")) if str(last_import_failure.get("reason",""))==safe_reason else "network.message-processing-failed","reason":safe_reason},"phase":phase,"areaGeneration":area_generation}
		exposed_reason=str(client_failure.reason)
		var failure_event: Dictionary={"code":"network.game-session-failed","reason":"Native game-message delivery failed","clientFailure":client_failure.duplicate(true)}
		diagnostic_event.emit(failure_event)
		diagnostic.emit(str(failure_event.code),str(failure_event.reason))
	error=exposed_reason
	close()
	phase="failed"
	session_failed.emit(exposed_reason)
	return false

func disconnect_session()->Dictionary:
	if disconnecting_peer:
		await disconnection_finished
		return disconnect_outcome.duplicate(true)
	if phase in ["closed","failed"]:return {}
	var departing_peer: RefCounted=peer
	disconnect_outcome={}
	disconnecting_peer=true
	close(false)
	while peer_poll_pending:await get_tree().process_frame
	if departing_peer!=null:disconnect_outcome=await departing_peer.close()
	disconnecting_peer=false
	disconnection_finished.emit()
	return disconnect_outcome.duplicate(true)

func close(finish_peer: bool=true)->void:
	if phase=="closed":return
	# Closing the repository settles pending HTTP waits synchronously. Retire the
	# session before that can resume load_content and report Cancel as a failure.
	final_state_snapshot=state()
	final_state_snapshot.phase="closed"
	final_state_snapshot.closed=true
	phase="closed"
	processing_delivery=false
	local_vault_allowed=false;local_vault_policy_known=false
	mods_directory="";disabled_mods.clear();portal_workshop_selection.clear()
	if portal_pending.get("identity") is RefCounted:portal_pending.identity.dispose()
	if portal_pending.get("character",{}).get("data") is PackedByteArray:portal_pending.character.data.fill(0)
	if portal_pending.get("prepared",{}).get("session") is Node:
		portal_pending.prepared.session.close()
		portal_pending.prepared.session.queue_free()
	portal_pending.clear()
	if portal_identity!=null:portal_identity.dispose();portal_identity=null
	if portal_character.get("data") is PackedByteArray:portal_character.data.fill(0)
	portal_character.clear();login_waypoint="";player_name=""
	if repository!=null:repository.close();repository.queue_free();repository=null
	if catalog_loader!=null:catalog_loader.close();catalog_loader.queue_free();catalog_loader=null
	catalog=null;catalog_serial=-1
	catalog_archive_repair_attempted=false
	if content_store!=null:content_store.close();content_store=null
	if peer!=null:
		if finish_peer:peer.finish()
		peer=null
	if build_owner!=null:build_owner.dispose();build_owner=null
	if identity!=null:identity.dispose();identity=null
	character_vault=null
	saved_character_id=""
	pending_character_export=false
	character_export_uncertain=false
	character_export_deadline=0
	level_up.reset()
	pending_level_up_presentation.clear()
	pending_creature_voice.clear()
	movement_serial=0
	characters.clear()
	server_character_list_pending=false
	lobby_players.reset()
	gui_access.reset();area_generation=0
	gui_panel_attempt_scope.clear();gui_panel_attempt_last=0
	server_status=""
	pending_preview.clear()
	character_submission_pending=false
	character_uploaded=false;area_ready_sent=false;tlk_override_messages=0
	resource_progress_snapshot=null;server_info_snapshot.clear()
	module_information.clear()
	remote_build.clear()
	movement_sequences.clear()
	current_dialog.clear()
	nui_state=NuiState.new();pending_nui.clear();pending_area_visual.clear();local_build.clear()
	resource_sources.clear()
	pending_object_packets.clear();pending_object_bytes=0;object_rules=null
	pending_quickbar_packets.clear();pending_quickbar_bytes=0;pending_visual_packets.clear();pending_visual_bytes=0
	world_state=WorldState.new();session_script_targeting=null;world_revision=0;published_revision=-1;last_presentation_ms=0
	_direct_world_publisher=Callable()
	_direct_world_borrows_static_nested=false
	_immediate_world_projection={}
	phase_changed.emit("closed")
