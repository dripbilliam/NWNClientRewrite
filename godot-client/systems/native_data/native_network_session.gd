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
const Store=preload("res://systems/native_data/nwsync_store.gd")
const Repository=preload("res://systems/native_data/native_nwsync_repository.gd")
const Requirements=preload("res://systems/native_data/native_resource_requirements.gd")
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
const InventoryWindowStatus=preload("res://systems/native_data/native_inventory_window_status.gd")
const ContainerStatus=preload("res://systems/native_data/native_container_status.gd")
const NetworkNui=preload("res://systems/native_data/native_network_nui.gd")
const NuiState=preload("res://systems/native_data/nui_state.gd")
const NetworkHud=preload("res://systems/native_data/native_network_hud.gd")
const AreaVisuals=preload("res://systems/native_data/native_network_area_visuals.gd")
const NetworkFeedback=preload("res://systems/native_data/native_network_feedback.gd")
const NetworkStore=preload("res://systems/native_data/native_network_store.gd")
const NetworkParty=preload("res://systems/native_data/native_network_party.gd")
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
signal phase_changed(phase: String)
signal character_list_ready(characters: Array[Dictionary])
signal character_preview_ready(preview: Dictionary)
signal character_rejected_ready(message: Dictionary)
signal server_status_ready(status: Dictionary)
signal character_needed_ready(message: Dictionary)
signal lobby_players_ready(players: Array)
signal session_failed(reason: String)
signal diagnostic(code: String,reason: String)
signal resource_progress(phase: String,completed: int,total: int)
signal resource_sources_ready(sources: Dictionary)
signal catalog_ready(catalog: RefCounted)
signal module_information_ready(module: Dictionary)
signal area_packet_received(packet: PackedByteArray)
signal area_state_ready(entry: Dictionary)
signal roster_message_ready(message: Dictionary)
signal object_updates_ready(message: Dictionary)
signal movement_ready(records: Array)
signal quickbar_ready(message: Dictionary)
signal world_presentation_ready(data: Dictionary)
signal inventory_response_ready(message: Dictionary)
signal ui_message_ready(message: Dictionary)
signal sound_object_ready(message: Dictionary)
signal ambient_command_ready(message: Dictionary)
signal time_changed(changes: Dictionary)
signal object_visual_ready(message: Dictionary)
signal portal_handoff_ready(handoff: Dictionary)
signal camera_command_ready(message: Dictionary)
signal area_visual_ready(message: Dictionary)
signal creature_voice_ready(message: Dictionary)
signal projectile_ready(message: Dictionary)
signal module_pause_ready(receipt: Dictionary)
signal character_export_status_ready(status: Dictionary)
var phase: String="idle"
var peer: RefCounted
var identity: RefCounted
var content_store: RefCounted
var repository: Node
var profile_root: String=""
var install_root: String=""
var mods_directory: String=""
var disabled_mods: Array=[]
var portal_workshop_selection: Dictionary={}
var language:=0
var deadline:=0
var characters: Array[Dictionary]=[]
var lobby_players: RefCounted=LobbyPlayerRegistry.new()
var gui_access: RefCounted=GuiAccess.State.new()
var area_generation:=0
var gui_panel_attempt_scope: Array=[]
var gui_panel_attempt_last:=0
var pending_preview: Dictionary={}
var error: String=""
var device_metrics: Dictionary={}
var login_waypoint: String=""
var device_echo_replies:=0
var server_status: String=""
var login_waypoint_requests:=0
var player_name: String=""
var portal_identity: RefCounted
var portal_character: Dictionary={}
var portal_pending: Dictionary={}
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
var pending_object_packets: Array[PackedByteArray]=[]
var pending_object_bytes:=0
var pending_quickbar_packets: Array[PackedByteArray]=[]
var pending_quickbar_bytes:=0
var pending_visual_packets: Array[Dictionary]=[]
var pending_visual_bytes:=0
var world_state: RefCounted=WorldState.new()
var level_up: RefCounted=LevelUpTransaction.new()
var pending_level_up_presentation: Dictionary={}
var pending_creature_voice: Array[Dictionary]=[]
var movement_serial:=0
var character_vault: RefCounted
var saved_character_id: String=""
var pending_character_export:=false
var character_export_uncertain:=false
var character_export_deadline:=0
var character_export_timeout_ms:=15000
var current_dialog: Dictionary={}
var nui_state: RefCounted=NuiState.new()
var pending_nui: Array[Dictionary]=[]
var pending_area_visual: Array[Dictionary]=[]
var local_build: Dictionary={}
var world_revision:=0
var published_revision:=-1
var last_presentation_ms:=0

func set_object_tables(tables: Dictionary,existing_state: Callable=Callable())->bool:
	if object_rules!=null or phase in ["closed","failed"]:return false
	var candidate:=ObjectRules.new()
	var state_query: Callable=existing_state if existing_state.is_valid() else func(id: int)->Variant:return world_state.registry.get(id,{}).get("replicated",{})
	if not candidate.configure(tables,state_query):return false
	object_rules=candidate
	for packet in pending_object_packets:
		if not decode_object_packet(packet):return false
	pending_object_packets.clear();pending_object_bytes=0
	for packet in pending_quickbar_packets:
		if not decode_quickbar_packet(packet):return false
	pending_quickbar_packets.clear();pending_quickbar_bytes=0
	for pending in pending_visual_packets:
		if int(pending.areaId)==world_state.area_id and not decode_visual_packet(pending.packet):return false
	pending_visual_packets.clear();pending_visual_bytes=0
	return true

func decode_visual_packet(packet: PackedByteArray)->bool:
	if object_rules==null:
		if pending_visual_packets.size()>=128 or pending_visual_bytes+packet.size()>4*1024*1024:return fail("Native object visual backlog exceeds bound")
		pending_visual_packets.append({"areaId":world_state.area_id,"packet":packet.duplicate()});pending_visual_bytes+=packet.size()
		return true
	var message: Dictionary=ObjectVisual.decode_packet(packet,remote_build,object_rules.providers())
	if message.has("error"):return fail("Invalid native object visual: "+str(message.error))
	message.nativeAreaId=world_state.area_id
	var target: Dictionary=world_state.registry.get(int(message.targetId),{})
	message.nativeTargetIdentity=target.get("nativeLifetime",target.get("clientKnownLifetime")) if not target.is_empty() else null
	var source: Dictionary=world_state.registry.get(int(message.get("sourceId",0x7f000000)),{})
	message.nativeSourceIdentity=source.get("nativeLifetime",source.get("clientKnownLifetime")) if not source.is_empty() else null
	object_visual_ready.emit(message)
	return true

func decode_quickbar_packet(packet: PackedByteArray)->bool:
	if object_rules==null:
		if pending_quickbar_packets.size()>=128 or pending_quickbar_bytes+packet.size()>8*1024*1024:return fail("Native quickbar backlog exceeds bound")
		pending_quickbar_packets.append(packet.duplicate());pending_quickbar_bytes+=packet.size()
		return true
	var message: Dictionary=Quickbar.decode_packet(packet,remote_build,object_rules.providers())
	if message.has("error"):return fail("Invalid native quickbar: "+str(message.error))
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
	for name in ["baseitems","classes","visualeffects","skills"]:
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
	if phase=="portal-character-pending" and not submit_portal_character():fail("Portal destination character could not be submitted")

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
		portal_character.data.fill(0)
	else:packet=Characters.play_request(int(portal_character.source),str(portal_character.resref))
	portal_character.clear()
	if packet.has("error") or not peer.send_game_message(packet.bytes):return false
	character_confirmed=false;module_information.clear();module_ready_sent=false
	change_phase("character-loading")
	deadline=Time.get_ticks_msec()+30000
	return true

func begin_portal(message: Dictionary)->bool:
	if not phase in ["playing","area-loading"] or not character_confirmed or not portal_pending.is_empty() or identity==null or peer==null:return true
	var next_identity: RefCounted=identity.for_portal(str(message.password))
	message.password=""
	if next_identity==null:return fail("Portal destination identity could not be prepared")
	portal_pending={"host":str(message.host),"port":int(message.port),"waypoint":str(message.waypoint) if not str(message.waypoint).is_empty() else "*PAUL_WAS_HERE*" if bool(message.seamless) else "","identity":next_identity,"playerName":player_name,"workshopSelection":{"modsDirectory":mods_directory,"disabledMods":disabled_mods.duplicate(true)}}
	if not peer.send_game_message(NetworkPortal.character_request()):return fail("Portal character download request failed")
	change_phase("transferring")
	deadline=Time.get_ticks_msec()+15000
	return true

func finish_portal(message: Dictionary)->bool:
	if phase!="transferring" or portal_pending.is_empty():
		if message.has("data"):message.data.fill(0)
		return true
	var handoff: Dictionary=portal_pending
	portal_pending={}
	if message.has("data"):
		handoff.character={"data":message.data.duplicate()}
		message.data.fill(0)
	else:handoff.character={"source":int(message.source),"resref":str(message.resref)}
	change_phase("portal-ready")
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
	repository.progress.connect(func(current: String,completed: int,total: int):resource_progress.emit(current,completed,total))
	repository.diagnostic.connect(func(code: String,reason: String):diagnostic.emit(code,reason))

func decode_object_packet(packet: PackedByteArray)->bool:
	if object_rules==null:
		if pending_object_packets.size()>=256 or pending_object_bytes+packet.size()>16*1024*1024:return fail("Native object-update backlog exceeds bound")
		pending_object_packets.append(packet.duplicate());pending_object_bytes+=packet.size()
		return true
	var update: Dictionary=ObjectUpdates.decode_packet(packet,remote_build,object_rules.providers())
	if update.has("error"):return fail("Invalid native object update: "+str(update.error))
	if not update.get("complete",false):return fail("Native object update is not yet supported: "+str(update.get("unhandled",{}).get("reason","unknown record")))
	if not world_state.apply_updates(update):return fail("Native world state rejected object updates: "+str(world_state.error))
	world_revision+=1
	object_updates_ready.emit(update)
	var movement: Array[Dictionary]=movement_from_update(update)
	if phase=="playing" and not movement.is_empty():movement_ready.emit(movement)
	var level_reply: Dictionary=level_up.observe(world_state.registry.get(world_state.local_object_id,{}),world_state.area_id,remote_build)
	if not level_reply.is_empty():present_level_up_reply(level_reply)
	if phase=="playing":drain_creature_voice()
	return true

func movement_from_update(update: Dictionary)->Array[Dictionary]:
	# Mirror network_world.js: emit a movement event for each received creature
	# create/update carrying one of the original motion fields, in record order.
	const TRIGGERS=["position","orientation","facingTarget","animation","path","walkRate","runRate"]
	const FIELDS=["position","orientation","facingTarget","animation","path","walkRate","runRate","field8F4","field8EC","actionFlag"]
	var rows: Array[Dictionary]=[]
	for record in update.get("records",[]):
		if str(record.get("action","")) not in ["create","update"] or int(record.get("objectType",0))!=5:continue
		var state: Dictionary=record.get("state",{})
		if not TRIGGERS.any(func(key):return state.has(key)):continue
		var id:=int(record.get("id",-1))
		var actor: Dictionary=world_state.registry.get(id,{})
		if int(actor.get("objectType",0))!=5 or bool(actor.get("replicationRemoved",false)) or int(actor.get("areaId",-1))!=world_state.area_id:continue
		var changes: Dictionary={}
		for key in FIELDS:
			if state.has(key):changes[key]=state[key].duplicate(true) if state[key] is Array or state[key] is Dictionary else state[key]
		movement_serial+=1
		rows.append({"id":id,"revision":movement_serial,"created":str(record.action)=="create","changes":changes,"initial":actor.get("replicated",{}).duplicate(true)})
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

func level_up_input(request: Dictionary)->Dictionary:
	if phase!="playing" or peer==null:return {"error":"Native level-up session is unavailable"}
	var actor: Dictionary=world_state.registry.get(world_state.local_object_id,{})
	var outcome: Dictionary=level_up.request(request,actor,world_state.area_id,object_rules,remote_build,Time.get_ticks_msec())
	if outcome.has("error"):return outcome
	for packet in outcome.packets:
		if not peer.send_game_message(packet):
			var rejection: Dictionary=level_up.send_failed()
			if not rejection.is_empty():ui_message_ready.emit(rejection)
			return {"error":"Native level-up request could not be sent"}
	return {"sent":true}

func publish_world_if_ready()->void:
	if phase!="playing" or catalog==null or published_revision==world_revision or Time.get_ticks_msec()-last_presentation_ms<200:return
	var data: Dictionary=presentation()
	if data.has("error"):return
	last_presentation_ms=Time.get_ticks_msec()
	published_revision=world_revision
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
	if not bool(request.get("open",false)) or int(request.get("actorId",-1))!=actor_id or int(request.get("areaId",-1))!=area_id or int(actor.get("objectType",0))!=5 or int(actor.get("areaId",-1))!=area_id or bool(actor.get("replicationRemoved",false)) or bool(actor.get("destroyed",false)):
		return {"error":"Native GUI panel actor or area has retired"}
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
	if not peer.send_game_message(packet.bytes):return {"error":"Native GUI panel request failed"}
	return {"sent":true,"blocked":blocked,"serverAcknowledged":false}

func script_target_input(request: Dictionary)->Dictionary:
	if phase!="playing" or peer==null:return {"error":"Native script targeting is unavailable"}
	var actor_id:=int(world_state.local_object_id)
	var area_id:=int(world_state.area_id)
	var actor: Dictionary=world_state.registry.get(actor_id,{})
	var mode: Variant=world_state.script_targeting
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
	world_state.script_targeting=null;world_revision+=1
	if not peer.send_game_message(packet.bytes):return {"error":"Native script target selection could not be sent"}
	return {"sent":true}

func presentation(prepare_area: bool=false)->Dictionary:
	var data: Dictionary=world_state.presentation(prepare_area)
	if not data.has("error"):
		data.ui.guiPanelAccess=gui_access.snapshot(gui_access_context())
	return data

func set_device_metrics(metrics: Dictionary)->bool:
	if phase in ["closed","failed"]:return false
	for key in DeviceProperties.KEYS:
		if not metrics.has(key):continue
		var value: Variant=metrics[key]
		if not value is int or DeviceProperties.request(key,int(value)).has("error"):return false
	device_metrics=metrics.duplicate(true)
	return flush_device_metrics() if peer!=null and peer.admitted else true

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
	if not peer.send_game_message(PackedByteArray([112,6,31])):
		return {"error":"The character export request could not be sent."}
	pending_character_export=true
	character_export_deadline=Time.get_ticks_msec()+character_export_timeout_ms
	character_export_status_ready.emit({"state":"pending","text":"Saving character…"})
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
	if not peer.send_game_message(packet.bytes):return {"error":"Native waypoint send failed"}
	return {"sequence":sequence}

func inventory_window(opened: bool,owner_id: int=-1,role: String="primary",window_serial: int=-1,receipt_serial: int=-1)->Dictionary:
	if phase!="playing" or peer==null:return {"error":"Native inventory is not in an admitted area"}
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
	if packet.has("error") or not peer.send_game_message(packet.bytes):return {"error":"Native inventory window request failed"}
	if role=="alternate" and not opened:world_state.close_alternate_window();world_revision+=1
	if role=="rejected":world_state.rejected_inventory_window=null
	return {"sent":true}

func inventory_panel(panel: int,owner_id: int=-1,role: String="primary",window_serial: int=-1,receipt_serial: int=-1)->Dictionary:
	if phase!="playing" or peer==null:return {"error":"Native inventory is not in an admitted area"}
	var actor_id: int=int(world_state.local_object_id)
	var actor: Dictionary=world_state.registry.get(actor_id,{})
	if int(actor.get("objectType",0))!=5 or int(actor.get("areaId",0))!=world_state.area_id or bool(actor.get("replicationRemoved",false)):return {"error":"Native inventory owner is unavailable"}
	if owner_id<0:owner_id=actor_id
	if role=="alternate":
		if not world_state.require_alternate_window(owner_id,window_serial,receipt_serial):return {"error":"Native alternate inventory window is retired"}
	elif role!="primary" or owner_id!=actor_id:return {"error":"Native inventory panel owner is unavailable"}
	var packet: Dictionary=PlayerRequests.inventory_panel(panel,role=="primary")
	if packet.has("error") or not peer.send_game_message(packet.bytes):return {"error":"Native inventory panel request failed"}
	world_state.clear_repository_view(role=="primary");world_revision+=1
	return {"sent":true}

func container_input(operation: String,target_id: int,actor_id: int)->Dictionary:
	if phase!="playing" or peer==null:return {"error":"Native container is not in an admitted area"}
	var controlled:=int(world_state.local_object_id)
	var actor: Dictionary=world_state.registry.get(controlled,{})
	if actor_id!=controlled or int(actor.get("objectType",0))!=5 or int(actor.get("areaId",0))!=world_state.area_id or bool(actor.get("replicationRemoved",false)) or target_id==ContainerStatus.INVALID or target_id!=int(world_state.containers.get("C",ContainerStatus.INVALID)):return {"error":"Native container request is stale"}
	var packet: Dictionary=ContainerStatus.request(operation,target_id)
	if packet.has("error"):return packet
	if not peer.send_game_message(packet.bytes):return {"error":"Native container request failed"}
	if operation=="close":world_state.apply_container_status({"targetId":ContainerStatus.INVALID,"primary":true})
	else:world_state.clear_container_view()
	world_revision+=1
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
	if not peer.send_game_message(packet.bytes):return {"error":"Native store request failed"}
	if operation=="identify":
		var examine: Dictionary=target_action(item_id,"examine")
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
	if not peer.send_game_message(packet.bytes):return {"error":"Native barter send failed"}
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
	var packet: Dictionary=NetworkNui.input_packet(token,events,binds,indexed)
	if packet.has("error"):return packet
	if not peer.send_game_message(packet.bytes):return {"error":"Native NUI input send failed"}
	for entry in binds:nui_state.local_bind(token,str(entry.bind),entry.get("value"))
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
	# Container and associate ownership need their own admitted window state.
	if destination_id!=actor_id:return {"error":"Native destination container is not available"}
	var packet: Dictionary={}
	if operation=="pickup":
		if owned or equipped or int(item.get("areaId",0))!=world_state.area_id:return {"error":"Native pickup item is unavailable"}
		packet=PlayerRequests.item_repository(item_id,operation,actor_id,int(request.get("x",255)),int(request.get("y",255)))
	else:
		if not owned and not equipped:return {"error":"Native inventory item is unavailable"}
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
				if channel!="R":return {"error":"Native repository item is unavailable"}
				packet=PlayerRequests.item_repository(item_id,operation,actor_id,int(request.get("x",255)),int(request.get("y",255)))
			"drop":packet=PlayerRequests.item_drop(item_id,request.get("position",actor.get("replicated",{}).get("position",[])))
			_:return {"error":"Native item action is unavailable"}
	if packet.has("error"):return packet
	if not peer.send_game_message(packet.bytes):return {"error":"Native item action send failed"}
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
			if int(button.get("associateType",0))!=1:return {"error":"Native dynamic associate shortcut is unavailable"}
			var target_id:=int(button.get("associateId",-1))
			var target: Dictionary=world_state.registry.get(target_id,{})
			if int(target.get("objectType",0))!=5 or bool(target.get("replicationRemoved",false)) or int(target.get("replicated",{}).get("master",-1))!=actor_id:return {"error":"Native associate shortcut target is unavailable"}
			var command:=int(button.get("intParam",0))&65535
			if command>=32768:command-=65536
			packet=PlayerRequests.associate_command(target_id,command)
		_:return {"error":"This shortcut action is not connected yet"}
	if packet.has("error"):return packet
	if not peer.send_game_message(packet.bytes):return {"error":"Native quickbar send failed"}
	return {"sent":true}

func quickbar_assign(request: Dictionary)->Dictionary:
	if phase!="playing" or peer==null:return {"error":"Native quickbar is not in an admitted area"}
	var actor_id:=int(world_state.local_object_id)
	var actor: Dictionary=world_state.registry.get(actor_id,{})
	if int(request.get("actorId",actor_id))!=actor_id or int(actor.get("objectType",0))!=5 or int(actor.get("areaId",0))!=world_state.area_id or bool(actor.get("replicationRemoved",false)):return {"error":"Native quickbar belongs to a retired controlled creature"}
	if not request.get("button") is Dictionary:return {"error":"Invalid native quickbar button"}
	var index:=int(request.get("index",-1))
	var button: Dictionary=request.button.duplicate(true)
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
	if not peer.send_game_message(packet.bytes):return {"error":"Native quickbar assignment send failed"}
	var update: Dictionary={"full":false,"entries":[{"index":index,"button":button,"items":[]}]}
	if not world_state.apply_quickbar(update):return {"error":"Native quickbar layout could not apply"}
	world_revision+=1
	quickbar_ready.emit(update)
	publish_world_if_ready()
	return {"sent":true,"button":button}

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
	if not peer.send_game_message(packet.bytes):return {"error":"Native action send failed"}
	return {"sent":true}

func chat(request: Dictionary)->Dictionary:
	if phase!="playing" or peer==null:return {"error":"Native chat is not in an admitted area"}
	var actor_id:=int(world_state.local_object_id)
	var actor: Dictionary=world_state.registry.get(actor_id,{})
	if int(request.get("actorId",actor_id))!=actor_id or int(actor.get("objectType",0))!=5 or int(actor.get("areaId",0))!=world_state.area_id or bool(actor.get("replicationRemoved",false)):return {"error":"Native chat belongs to a retired controlled creature"}
	var channel:=int(request.get("channel",-1))
	var player_id:=int(request.get("playerId",-1))
	if request.has("playerAccount"):
		if channel!=4 or not world_state.players.has(player_id) or str(world_state.players[player_id].get("name",""))!=str(request.playerAccount):return {"error":"Native Tell player has changed"}
	var packet: Dictionary=PlayerRequests.chat(channel,str(request.get("text","")),player_id,str(request.get("recipient","")))
	if packet.has("error"):return packet
	if not peer.send_game_message(packet.bytes):return {"error":"Native chat send failed"}
	return {"sent":true}

func reply_dialog(request: Dictionary)->Dictionary:
	if phase!="playing" or peer==null or current_dialog.is_empty() or not current_dialog.has("replies"):return {"error":"Native dialog reply is unavailable"}
	var actor: Dictionary=world_state.registry.get(int(world_state.local_object_id),{})
	if int(actor.get("objectType",0))!=5 or int(actor.get("areaId",0))!=world_state.area_id or bool(actor.get("replicationRemoved",false)):return {"error":"Native controlled creature is unavailable"}
	var choices: Dictionary=current_dialog.replies
	var entry_id:=int(request.get("entryId",-1))
	var reply_id:=int(request.get("replyId",-1))
	var abort:=bool(request.get("abort",false))
	if entry_id!=int(choices.get("entryId",-2)):return {"error":"Native dialog reply is stale or unavailable"}
	var offered:=false
	for row in choices.get("replies",[]):
		if int(row.id)==reply_id:offered=true;break
	if not abort and not offered and not (choices.replies.is_empty() and reply_id==0xffffffff):return {"error":"Native dialog reply is stale or unavailable"}
	if abort and int(choices.get("secondCount",0))==1:
		reply_id=int(choices.replies[0].id) if not choices.replies.is_empty() else 0xffffffff
		abort=false
	var packet: Dictionary=PlayerRequests.dialog_reply(int(current_dialog.ownerId),entry_id,0xffffffff if abort else reply_id,abort)
	if packet.has("error"):return packet
	if not peer.send_game_message(packet.bytes):return {"error":"Native dialog reply send failed"}
	return {"sent":true}

func target_action(target_id: int,action: String,position: Array=[],run: bool=true)->Dictionary:
	if phase!="playing" or peer==null:return {"error":"Native player is not in an admitted area"}
	var actor_id: int=int(world_state.local_object_id)
	var actor: Dictionary=world_state.registry.get(actor_id,{})
	if int(actor.get("objectType",0))!=5 or int(actor.get("areaId",0))!=world_state.area_id or bool(actor.get("replicationRemoved",false)):return {"error":"Native controlled creature is not ready for input"}
	var target: Dictionary=world_state.registry.get(target_id,{})
	var kind:=int(target.get("objectType",0))
	var location: Variant=target.get("inventoryLocation",{})
	var owned_item:=kind==6 and (location is Dictionary and int(location.get("ownerId",-1))==actor_id or int(target.get("equipmentOwnerId",-1))==actor_id)
	if target.is_empty() or bool(target.get("replicationRemoved",false)) or int(target.get("areaId",0))!=world_state.area_id and not owned_item:return {"error":"Native interaction target is unavailable"}
	var packet: Dictionary={}
	var sequence: int=-1
	match action:
		"examine":
			if kind not in [5,6,7,9,10]:return {"error":"Native examination target is unavailable"}
			packet=PlayerRequests.target(target_id,"examine")
		"conversation.start":
			if kind!=5:return {"error":"Native conversation target is unavailable"}
			packet=PlayerRequests.target(target_id,"talk")
		"combat.attack":
			if kind!=5:return {"error":"Native attack target is unavailable"}
			packet=PlayerRequests.target(target_id,"attack")
		"door.open","door.close":
			if kind!=10:return {"error":"Native door target is unavailable"}
			packet=PlayerRequests.door(target_id,action=="door.open")
		"object.use":
			if kind not in [6,9]:return {"error":"Native use target is unavailable"}
			packet=PlayerRequests.use_object(target_id,kind==9)
		"door.transition":
			var state: Dictionary=target.get("replicated",{})
			if kind!=10 or not bool(state.get("hasTransition",false)) or not state.get("position") is Array:return {"error":"Native door transition is unavailable"}
			packet=PlayerRequests.waypoint(world_state.area_id,state.position,0,run,false,0,target_id)
		"trigger.transition":
			if kind!=7:return {"error":"Native trigger target is unavailable"}
			sequence=(int(movement_sequences.get(actor_id,0))+1)&255
			packet=PlayerRequests.waypoint(world_state.area_id,position,sequence,run,false,0,target_id)
		_:return {"error":"Native interaction request is not implemented"}
	if packet.has("error"):return packet
	if sequence>=0:movement_sequences[actor_id]=sequence
	if not peer.send_game_message(packet.bytes):return {"error":"Native interaction send failed"}
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
	if sent and not peer.send_game_message(packet.bytes):return {"error":"Native keyboard send failed"}
	return {"sent":sent,"sequence":sequence} if operation=="drive" else {"sent":sent}

func flush_device_metrics()->bool:
	if peer==null or not peer.admitted:return true
	for key in DeviceProperties.KEYS:
		if not device_metrics.has(key) or sent_device_metrics.get(key)==device_metrics[key]:continue
		var packet: Dictionary=DeviceProperties.request(key,int(device_metrics[key]))
		if packet.has("error") or not peer.send_game_message(packet.bytes):return false
		sent_device_metrics[key]=device_metrics[key]
	return true

func request_preview(source: int,resref: String)->bool:
	if phase not in ["character-selection","character-rejected"] or not pending_preview.is_empty() or peer==null:return false
	var selected:=false
	for row in characters:
		if int(row.source)==source and str(row.resref)==resref:selected=true;break
	if not selected:return false
	var packet: Dictionary=Characters.preview_request(source,resref)
	if packet.has("error") or not peer.send_game_message(packet.bytes):return false
	pending_preview={"source":source,"resref":resref,"type":5 if source==17 else 4 if source==14 else 1}
	return true

func play_character(source: int,resref: String)->bool:
	if phase not in ["character-selection","character-rejected"] or peer==null:return false
	var selected:=false
	for row in characters:
		if int(row.source)==source and str(row.resref)==resref:selected=true;break
	if not selected:return false
	var packet: Dictionary=Characters.play_request(source,resref)
	if packet.has("error"):return false
	if lobby_players.subscribed and not lobby_player_subscription(false).get("sent",false):return false
	if not peer.send_game_message(packet.bytes):return false
	pending_preview.clear()
	saved_character_id=""
	character_confirmed=false;module_information.clear();module_ready_sent=false
	change_phase("character-loading")
	deadline=Time.get_ticks_msec()+30000
	return true

func play_local_character(bic: PackedByteArray,create_on_server: bool=false,vault_id: String="")->bool:
	if phase not in ["character-selection","character-rejected"] or peer==null or catalog==null or not local_vault_allowed and not create_on_server or bic.size()<4 or bic.slice(0,4).get_string_from_ascii()!="BIC ":return false
	var packet: Dictionary=Characters.upload_request(bic,19 if create_on_server else 1)
	if packet.has("error"):return false
	if lobby_players.subscribed and not lobby_player_subscription(false).get("sent",false):return false
	if not peer.send_game_message(packet.bytes):return false
	pending_preview.clear()
	saved_character_id=vault_id
	character_confirmed=false;module_information.clear();module_ready_sent=false
	change_phase("character-loading")
	deadline=Time.get_ticks_msec()+30000
	return true

func set_server_vault_policy(server_info: Dictionary,host: String,port: int)->bool:
	# Only a fresh BNXR query for this endpoint may admit local BIC uploads.
	if phase!="idle" or local_vault_policy_known or not server_info.get("allowLocalVaultCharacters") is bool or str(server_info.get("host","")).to_lower()!=host.to_lower() or int(server_info.get("port",0))!=port:return false
	local_vault_allowed=bool(server_info.allowLocalVaultCharacters)
	local_vault_policy_known=true
	return true

func lobby_player_subscription(open: bool)->Dictionary:
	if phase not in ["character-selection","character-rejected"] or peer==null:return {"error":"Lobby player list is unavailable outside character selection"}
	var packet:=PackedByteArray([112,49,1 if open else 2])
	if not peer.send_game_message(packet):return {"error":"Lobby player list request failed"}
	lobby_players.set_subscribed(open)
	lobby_players_ready.emit(lobby_players.list())
	return {"sent":true,"subscribed":open}

func acknowledge_module_if_ready()->void:
	if not character_confirmed or module_information.is_empty() or module_ready_sent or peer==null:return
	if not peer.send_game_message(PackedByteArray([112,3,2])):fail("Native module-ready acknowledgement failed");return
	module_ready_sent=true
	change_phase("area-loading")
	deadline=Time.get_ticks_msec()+30000

func area_ready(render_world: Node)->bool:
	if phase!="area-presenting" or peer==null or catalog==null or not is_instance_valid(render_world):return false
	if int(render_world.get("area_id"))!=world_state.area_id or not render_world.has_method("ready_for_admission") or not render_world.ready_for_admission():return false
	if not peer.send_game_message(PackedByteArray([112,4,3])):return fail("Native client-area acknowledgement failed")
	change_phase("playing")
	for message in pending_nui:ui_message_ready.emit(message)
	pending_nui.clear()
	for message in pending_area_visual:area_visual_ready.emit(message)
	pending_area_visual.clear()
	drain_creature_voice()
	return true

func start(host: String,port: int,profile: String,install: String,server_password: String="",temporary_cd_key: String="",player_name_override: String="",settings_directory_override: String="")->bool:
	if phase!="idle" or host.is_empty() or port<1 or port>65535 or not profile.is_absolute_path() or not install.is_absolute_path():return false
	profile_root=profile.simplify_path();install_root=install.simplify_path()
	var crypto_helper:=ProjectSettings.globalize_path("res://../tooling/native/nwn-network-crypto.exe")
	var owner:=CryptoOwner.new()
	if not owner.open(crypto_helper):return fail("Native network crypto helper is unavailable")
	var build: Dictionary=Build.read(install_root,owner)
	owner.close()
	if build.has("error"):return fail(str(build.error))
	local_build=build.get("build",{}).duplicate(true)
	var talk:=FileAccess.get_file_as_bytes(install_root.path_join("lang/en/data/dialog.tlk"))
	if talk.size()<12 or talk.slice(0,8).get_string_from_ascii()!="TLK V3.0":return fail("Original language table is unavailable")
	language=int(talk.decode_u32(8))
	var startup: Dictionary=StartupPaths.resolve(install_root)
	if startup.has("error"):return fail(str(startup.error))
	character_vault=CharacterExportVault.new()
	var vault_parent:=settings_directory_override if not settings_directory_override.is_empty() else str(startup.settingsDirectory)
	if not character_vault.configure(vault_parent.path_join("godot-character-vault")):return fail("Godot character vault is unavailable")
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
			if int(settings.state.get("version",0))<Settings.CURRENT_VERSION:
				var upgrade: Dictionary=settings.upgrade_legacy()
				if upgrade.has("error"):settings.close();return fail(str(upgrade.error))
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
	var cache:=profile_root.path_join("replacement-client/server-content")
	var content_helper:=ProjectSettings.globalize_path("res://../tooling/native/content-reader/nwn-content-reader.exe")
	content_store=Store.new()
	if not content_store.configure(cache,profile_root.path_join("nwsync"),content_helper):return fail("Installed NWSync content reader is unavailable")
	var content_repository:=Repository.new();add_child(content_repository)
	bind_repository(content_repository)
	peer=Peer.new()
	var metadata: Dictionary={"connectionType":16,"build":build.build,"language":language,"name":player_name,"legacyPublicKey":"","platformId":build.platformId,"platformIdentifier":build.platformIdentifier}
	if not world_state.begin_client_connection(int(metadata.connectionType)):return fail("Native client connection permission could not initialize")
	if not peer.connect_to_server(host,port,identity,metadata,crypto_helper):return fail(peer.error)
	change_phase("connecting")
	deadline=Time.get_ticks_msec()+15000
	return true

static func transport_failure_reason(result: Dictionary)->String:
	var reason:=str(result.get("error",""))
	if reason.is_empty() or not result.has("connectionError"):
		return reason
	return "%s (connection error %d)" % [reason,int(result.connectionError)]

func _process(_delta: float)->void:
	if phase in ["idle","closed","failed","portal-ready"] or peer==null:return
	if pending_character_export and Time.get_ticks_msec()>character_export_deadline:
		pending_character_export=false
		character_export_deadline=0
		character_export_uncertain=true
		character_export_status_ready.emit({"state":"failed","text":"Timed out waiting for the server character export; the connection remains open.","uncertain":true})
	var level_timeout: Dictionary=level_up.timeout(Time.get_ticks_msec())
	if not level_timeout.is_empty():ui_message_ready.emit(level_timeout)
	if Time.get_ticks_msec()>deadline and phase in ["connecting","resources","characters","character-loading","area-loading","area-presenting","transferring","portal-character-pending"]:
		fail("Original-server session timed out");return
	var result: Dictionary=peer.poll()
	var transport_error:=transport_failure_reason(result)
	# A BNDP may share this poll with earlier reliable records. Deliver those
	# records in wire order before retiring the connection in every phase.
	if not transport_error.is_empty() and result.get("payloads",[]).is_empty():fail(transport_error);return
	if phase=="connecting" and result.get("admitted",false):
		remote_build=result.get("remote",{}).get("build",{}).duplicate(true)
		if not flush_device_metrics():fail("Native device properties could not be sent");return
		if not peer.send_game_message(PackedByteArray([112,1,0])):fail("Server status request failed");return
		change_phase("resources");deadline=Time.get_ticks_msec()+15000
	for bytes in result.get("payloads",[]):
		if bytes.size()<3 or bytes[0]!=80:continue
		if bytes[1]==54 and bytes[2]==2:
			var echo: Dictionary=RuntimeMessages.device_echo_request(bytes)
			if echo.has("error"):fail(str(echo.error));return
			var response: Dictionary=RuntimeMessages.device_echo_response(echo.data)
			if response.has("error") or not peer.send_game_message(response.bytes):fail("Native device echo response failed");return
			device_echo_replies+=1
			continue
		if bytes[1]==2 and bytes[2]==12:
			if bytes.size()!=3:fail("Invalid native login waypoint request");return
			login_waypoint_requests+=1
			var waypoint: Dictionary=RuntimeMessages.login_waypoint_response(login_waypoint)
			if waypoint.has("error"):fail(str(waypoint.error));return
			if not waypoint.bytes.is_empty() and not peer.send_game_message(waypoint.bytes):fail("Native login waypoint response failed");return
			login_waypoint=""
			continue
		if NetworkPortal.accepted(int(bytes[1]),int(bytes[2])):
			var portal_message: Dictionary=NetworkPortal.decode_packet(bytes)
			if portal_message.has("error"):fail("Invalid native portal message: "+str(portal_message.error));return
			if portal_message.kind=="portal-activate":
				if not begin_portal(portal_message):return
			else:
				if not finish_portal(portal_message):return
				if phase=="portal-ready":return
			continue
		if NetworkCharacterExport.accepted(int(bytes[1]),int(bytes[2])):
			var export_message: Dictionary=NetworkCharacterExport.decode_packet(bytes)
			if export_message.has("error"):fail("Invalid native character export: "+str(export_message.error));return
			receive_character_export(export_message)
			continue
		if phase in ["resources","loading-content","characters","character-selection","character-loading","area-loading","area-presenting","playing"] and NetworkDmPermission.accepted(int(bytes[1]),int(bytes[2])):
			var permission: Dictionary=NetworkDmPermission.decode_packet(bytes)
			if permission.has("error") or not world_state.apply_dm_permission(permission):fail("Invalid native game-master permission: "+str(permission.get("error",world_state.error)));return
			world_revision+=1
			continue
		if phase in ["character-loading","area-loading","area-presenting","playing"] and NetworkCustomToken.accepted(int(bytes[1]),int(bytes[2])):
			var token_message: Dictionary=NetworkCustomToken.decode_packet(bytes)
			if token_message.has("error"):fail("Invalid native custom token: "+str(token_message.error));return
			ui_message_ready.emit(token_message)
			continue
		if phase in ["character-loading","area-loading","area-presenting","playing"] and bytes[1]==52 and int(bytes[2]) in [2,3]:
			var tlk_message: Dictionary=NetworkRuntime.decode_packet(bytes)
			if tlk_message.has("error") or not world_state.apply_tlk_overrides(tlk_message):fail("Invalid native TLK override: "+str(tlk_message.get("error",world_state.error)));return
			if not tlk_message.entries.is_empty():
				world_revision+=1
				ui_message_ready.emit(tlk_message)
			continue
		if phase=="resources" and ServerStatus.accepted(int(bytes[1]),int(bytes[2])):
			var status: Dictionary=ServerStatus.decode_packet(bytes)
			if status.has("error"):fail("Invalid native server status: "+str(status.error));return
			server_status=str(status.kind)
			server_status_ready.emit(status)
			if status.kind=="server-unavailable":fail("Original server is unavailable; retry the connection later");return
			continue
		if phase=="resources" and bytes[1]==1 and bytes[2]==3:
			var requirements: Dictionary=Requirements.decode_packet(bytes)
			if requirements.has("error"):fail("Invalid server resource requirements");return
			# Servers without NWSync still provide module/HAK/TLK requirements.
			# Resolve those from the installed resource stack before character admission.
			if requirements.get("advertisement") is Dictionary:
				if not repository.configure(str(requirements.advertisement.url),profile_root.path_join("replacement-client/server-content")):fail("Invalid NWSync repository URL");return
			change_phase("loading-content")
			load_content.call_deferred(requirements)
		elif phase=="characters" and bytes[1]==17 and bytes[2]==2:
			var list: Dictionary=Characters.decode_packet(bytes)
			if list.has("error"):fail("Invalid server character list");return
			characters=list.characters
			change_phase("character-selection")
			character_list_ready.emit(characters.duplicate(true))
		elif phase in ["character-selection","character-rejected"] and bytes[1]==17 and bytes[2]==4:
			var preview: Dictionary=Characters.decode_preview_packet(bytes)
			if preview.has("error"):fail("Invalid server character preview");return
			if pending_preview.is_empty() or str(preview.resref)!=str(pending_preview.resref) or int(preview.previewType)!=int(pending_preview.type):continue
			pending_preview.clear()
			character_preview_ready.emit(preview)
		elif phase in ["character-selection","character-rejected"] and LobbyPlayer.accepted(int(bytes[1]),int(bytes[2])):
			var player_message: Dictionary=LobbyPlayer.decode_packet(bytes)
			if player_message.has("error"):fail("Invalid native lobby-player record: "+str(player_message.error));return
			if not lobby_players.subscribed:continue
			if not lobby_players.apply(player_message):fail("Native lobby-player registry rejected the server record");return
			lobby_players_ready.emit(lobby_players.list())
		elif phase=="character-loading" and bytes[1]==2 and bytes[2]==5:
			if bytes.size()!=3:fail("Invalid server character confirmation");return
			character_confirmed=true
			acknowledge_module_if_ready()
		elif phase=="character-loading" and CharacterNeeded.accepted(int(bytes[1]),int(bytes[2])):
			var needed: Dictionary=CharacterNeeded.decode_packet(bytes)
			if needed.has("error"):fail("Invalid native character-needed response: "+str(needed.error));return
			character_confirmed=false;module_information.clear();module_ready_sent=false;pending_preview.clear()
			var current_permission: Variant=world_state.game_master_permission
			world_state=WorldState.new()
			if current_permission is Dictionary:world_state.game_master_permission=current_permission.duplicate(true)
			world_revision+=1;published_revision=-1
			change_phase("character-selection")
			deadline=Time.get_ticks_msec()+30000
			character_needed_ready.emit(needed)
		elif phase in ["character-loading","area-loading","area-presenting","playing"] and GuiAccess.accepted(int(bytes[1]),int(bytes[2])):
			var gui_message: Dictionary=GuiAccess.decode_packet(bytes,remote_build)
			if gui_message.has("error"):fail("Invalid native GUI access packet: "+str(gui_message.error));return
			var admitted: Dictionary=gui_access.observe(gui_message)
			if not admitted.get("accepted",false):continue
			var gui_event: Dictionary=gui_access.bind_event(gui_message,gui_access_context())
			world_revision+=1
			if phase=="playing" and not gui_event.is_empty():ui_message_ready.emit({"kind":"gui-panel-access-event","event":gui_event})
		elif phase=="character-loading" and bytes[1]==3 and bytes[2]==1:
			var module: Dictionary=ModuleInfo.decode_packet(bytes,remote_build)
			if module.has("error"):fail("Invalid native module information: "+str(module.error));return
			module_information=module
			if not world_state.apply_module(module):fail("Native world state rejected module information");return
			world_revision+=1
			module_information_ready.emit(module.duplicate(true))
			acknowledge_module_if_ready()
		elif phase in ["area-loading","playing"] and bytes[1]==4 and bytes[2]==1:
			var area: Dictionary=AreaState.decode_packet(bytes,remote_build)
			if area.has("error"):fail("Invalid native client-area message: "+str(area.error));return
			if not world_state.apply_area(area):fail("Native world state rejected area: "+str(world_state.error));return
			area_generation+=1
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
			var clock: Dictionary=ModuleTime.decode_packet(bytes)
			if clock.has("error"):fail(str(clock.error));return
			world_state.apply_time(clock.changes)
			world_revision+=1
			time_changed.emit(clock.changes)
		elif phase in ["area-loading","area-presenting","playing"] and NetworkModulePause.accepted(int(bytes[1]),int(bytes[2])):
			var pause_message: Dictionary=NetworkModulePause.decode_packet(bytes)
			if pause_message.has("error"):fail("Invalid native module-pause packet: "+str(pause_message.error));return
			module_pause_ready.emit({"message":pause_message,"areaId":world_state.area_id,"generation":area_generation})
		elif phase in ["area-loading","area-presenting","playing"] and NetworkCamera.accepted(int(bytes[1]),int(bytes[2])):
			var camera_message: Dictionary=NetworkCamera.decode_packet(bytes)
			if camera_message.has("error"):fail("Invalid native camera command: "+str(camera_message.error));return
			camera_command_ready.emit(camera_message)
		elif phase in ["area-loading","area-presenting","playing"] and NetworkTargeting.accepted(int(bytes[1]),int(bytes[2])):
			var targeting: Dictionary=NetworkTargeting.decode_packet(bytes)
			if targeting.has("error") or not world_state.apply_targeting(targeting):fail("Invalid native targeting instruction: "+str(targeting.get("error",world_state.error)));return
			world_revision+=1
		elif phase in ["area-loading","area-presenting","playing"] and NetworkProjectile.accepted(int(bytes[1]),int(bytes[2])):
			var projectile: Dictionary=NetworkProjectile.decode_packet(bytes)
			if projectile.has("error"):fail("Invalid native projectile: "+str(projectile.error));return
			var current_area:=int(world_state.area_id)
			var source: Dictionary=world_state.registry.get(int(projectile.header.sourceId),{})
			var target: Dictionary=world_state.registry.get(int(projectile.header.targetId),{})
			projectile.nativeAreaId=current_area
			projectile.nativeAreaGeneration=area_generation
			projectile.sourceLifetime=int(source.get("nativeLifetime",0)) if int(source.get("areaId",-1))==current_area and not bool(source.get("replicationRemoved",false)) else 0
			projectile.targetLifetime=int(target.get("nativeLifetime",0)) if int(target.get("areaId",-1))==current_area and not bool(target.get("replicationRemoved",false)) else 0
			projectile.receivedAtMs=Time.get_ticks_msec()
			projectile_ready.emit(projectile)
		elif phase in ["area-loading","area-presenting","playing"] and NetworkLevelUp.accepted(int(bytes[1]),int(bytes[2])):
			var level_message: Dictionary=NetworkLevelUp.decode_packet(bytes)
			if level_message.has("error"):fail("Invalid native level-up reply: "+str(level_message.error));return
			var level_reply: Dictionary=level_up.receive(level_message,world_state.registry.get(world_state.local_object_id,{}),world_state.area_id,remote_build)
			if not level_reply.is_empty():present_level_up_reply(level_reply)
		elif phase in ["area-loading","area-presenting","playing"] and NetworkCreatureVoice.accepted(int(bytes[1]),int(bytes[2])):
			var voice_message: Dictionary=NetworkCreatureVoice.decode_packet(bytes)
			if voice_message.has("error"):fail("Invalid native creature voice: "+str(voice_message.error));return
			var voice_actor: Dictionary=world_state.registry.get(int(voice_message.objectId),{})
			if voice_actor.is_empty() or int(voice_actor.get("objectType",0))!=5 or int(voice_actor.get("areaId",-1))!=world_state.area_id or bool(voice_actor.get("replicationRemoved",false)):continue
			if phase=="playing":creature_voice_ready.emit(voice_message)
			elif pending_creature_voice.size()<128:pending_creature_voice.append({"areaId":world_state.area_id,"lifetime":int(voice_actor.get("nativeLifetime",0)),"message":voice_message})
			else:fail("Native creature voice admission queue exceeded bound");return
		elif phase in ["area-loading","area-presenting","playing"] and (bytes[1]==10 and int(bytes[2]) in [1,2,3] or bytes[1]==5 and bytes[2]==2):
			var roster: Dictionary=PlayerRoster.decode_packet(bytes)
			if roster.has("error"):fail("Invalid native player roster: "+str(roster.error));return
			if not world_state.apply_roster(roster):fail("Native world state rejected roster: "+str(world_state.error));return
			world_revision+=1
			roster_message_ready.emit(roster)
		elif phase in ["area-loading","area-presenting","playing"] and bytes[1]==5 and bytes[2]==1:
			if not decode_object_packet(bytes):return
		elif phase in ["area-loading","area-presenting","playing"] and ObjectVisual.accepted(int(bytes[1]),int(bytes[2])):
			if not decode_visual_packet(bytes):return
		elif phase in ["area-loading","area-presenting","playing"] and bytes[1]==30 and int(bytes[2]) in [1,2]:
			if not decode_quickbar_packet(bytes):return
		elif phase in ["area-loading","area-presenting","playing"] and NetworkItemCaption.accepted(int(bytes[1]),int(bytes[2])):
			var caption: Dictionary=NetworkItemCaption.decode_packet(bytes)
			if caption.has("error"):fail("Invalid native item caption: "+str(caption.error));return
			if world_state.apply_item_caption(caption):world_revision+=1
		elif phase in ["area-loading","area-presenting","playing"] and bytes[1]==12 and (int(bytes[2]) in range(1,11) or bytes[2]==14):
			var response: Dictionary=InventoryResponse.decode_packet(bytes)
			if response.has("error"):fail("Invalid native inventory response: "+str(response.error));return
			inventory_response_ready.emit(response)
		elif phase in ["area-loading","area-presenting","playing"] and bytes[1]==13 and bytes[2]==1:
			var window: Dictionary=InventoryWindowStatus.decode_packet(bytes)
			if window.has("error") or not world_state.observe_inventory_window(window):fail("Invalid native inventory-window status: "+str(window.get("error",world_state.error)));return
			world_revision+=1
			ui_message_ready.emit({"kind":"inventory-window-status","windows":world_state.inventory_window_snapshot()})
		elif phase in ["area-loading","area-presenting","playing"] and bytes[1]==25 and bytes[2]==1:
			var container: Dictionary=ContainerStatus.decode_packet(bytes)
			if container.has("error") or not world_state.apply_container_status(container):fail("Invalid native container status: "+str(container.get("error",world_state.error)));return
			world_revision+=1
		elif phase in ["area-loading","area-presenting","playing"] and NetworkStore.accepted(int(bytes[1]),int(bytes[2])):
			var store_message: Dictionary=NetworkStore.decode_packet(bytes)
			if store_message.has("error") or not world_state.apply_store(store_message):fail("Invalid native store message: "+str(store_message.get("error",world_state.error)));return
			world_revision+=1
			if store_message.kind in ["store-transaction","store-close"]:
				if phase=="playing":ui_message_ready.emit(store_message)
				else:
					if pending_nui.size()>=4096:fail("Native UI admission queue exceeded bound");return
					pending_nui.append(store_message)
		elif phase in ["area-loading","area-presenting","playing"] and NetworkParty.accepted(int(bytes[1]),int(bytes[2])):
			var party_message: Dictionary=NetworkParty.decode_packet(bytes)
			if party_message.has("error") or not world_state.apply_party(party_message):fail("Invalid native party message: "+str(party_message.get("error",world_state.error)));return
			world_revision+=1
		elif phase in ["area-loading","area-presenting","playing"] and NetworkExamine.accepted(int(bytes[1]),int(bytes[2])):
			var examine: Dictionary=NetworkExamine.decode_packet(bytes,remote_build)
			if examine.has("error"):fail("Invalid native examination: "+str(examine.error));return
			if world_state.apply_examine(examine):world_revision+=1
			if phase=="playing":ui_message_ready.emit(examine)
			else:
				if pending_nui.size()>=4096:fail("Native UI admission queue exceeded bound");return
				pending_nui.append(examine)
		elif phase in ["area-loading","area-presenting","playing"] and NetworkBarter.accepted(int(bytes[1]),int(bytes[2])):
			var barter_message: Dictionary=NetworkBarter.decode_packet(bytes)
			if barter_message.has("error"):fail("Invalid native barter message: "+str(barter_message.error));return
			if barter_message.kind!="barter-reject" and world_state.apply_barter(barter_message):world_revision+=1
			barter_message.nativeBarterSerial=int(world_state.barter.get("serial",0)) if world_state.barter is Dictionary else 0
			barter_message.nativeBarterRevision=int(world_state.barter.get("revision",0)) if world_state.barter is Dictionary else 0
			if phase=="playing":ui_message_ready.emit(barter_message)
			else:
				if pending_nui.size()>=4096:fail("Native UI admission queue exceeded bound");return
				pending_nui.append(barter_message)
		elif phase in ["area-loading","area-presenting","playing"] and NetworkSound.accepted(int(bytes[1]),int(bytes[2])):
			var sound_message: Dictionary=NetworkSound.decode_packet(bytes)
			if sound_message.has("error"):fail("Invalid native sound-object message: "+str(sound_message.error));return
			if world_state.apply_sound_object(sound_message):
				world_revision+=1
				sound_object_ready.emit(sound_message)
		elif phase in ["area-loading","area-presenting","playing"] and NetworkAmbient.accepted(int(bytes[1]),int(bytes[2])):
			var ambient_message: Dictionary=NetworkAmbient.decode_packet(bytes)
			if ambient_message.has("error"):fail("Invalid native ambient command: "+str(ambient_message.error));return
			ambient_command_ready.emit(ambient_message)
		elif phase in ["area-loading","area-presenting","playing"] and NetworkNui.accepted(int(bytes[1]),int(bytes[2])):
			var nui: Dictionary=NetworkNui.decode_packet(bytes)
			if nui.has("error") or not nui_state.receive(nui):fail("Invalid native NUI message: "+str(nui.get("error",nui_state.failure)));return
			if nui.kind=="nui-create":nui.nativeSerial=int(nui_state.windows[int(nui.token)].serial)
			if phase=="playing":ui_message_ready.emit(nui)
			else:
				if pending_nui.size()>=4096:fail("Native NUI admission queue exceeded bound");return
				pending_nui.append(nui)
		elif phase in ["area-loading","area-presenting","playing"] and NetworkHud.accepted(int(bytes[1]),int(bytes[2])):
			var hud: Dictionary=NetworkHud.decode_packet(bytes)
			if hud.has("error") or not world_state.apply_hud(hud):fail("Invalid native HUD message: "+str(hud.get("error",world_state.error)));return
			world_revision+=1
		elif phase in ["area-loading","area-presenting","playing"] and AreaVisuals.accepted(int(bytes[1]),int(bytes[2])):
			var area_visual: Dictionary=AreaVisuals.decode_packet(bytes,remote_build)
			if area_visual.has("error"):fail("Invalid native area visual: "+str(area_visual.error));return
			if area_visual.kind=="area-visual":
				if not world_state.valid_current_area():continue
				if phase=="playing":area_visual_ready.emit(area_visual)
				else:
					if pending_area_visual.size()>=512:fail("Native area visual admission queue exceeded bound");return
					pending_area_visual.append(area_visual)
			elif world_state.apply_area_visual(area_visual):world_revision+=1
		elif phase in ["area-loading","area-presenting","playing"] and NetworkFeedback.accepted(int(bytes[1]),int(bytes[2])):
			var feedback: Dictionary=NetworkFeedback.decode_packet(bytes,remote_build)
			if feedback.has("error"):fail("Invalid native combat feedback: "+str(feedback.error));return
			if phase=="playing":ui_message_ready.emit(feedback)
			else:
				if pending_nui.size()>=4096:fail("Native UI admission queue exceeded bound");return
				pending_nui.append(feedback)
		elif phase in ["area-loading","area-presenting","playing"] and bytes[1]==9 and int(bytes[2]) in NetworkSpeech.CHANNELS:
			var speech: Dictionary=NetworkSpeech.decode_packet(bytes)
			if speech.has("error"):fail("Invalid native speech: "+str(speech.error));return
			ui_message_ready.emit(speech)
		elif phase in ["area-loading","area-presenting","playing"] and bytes[1]==20 and int(bytes[2]) in [1,2,4,5]:
			var dialog: Dictionary=NetworkDialog.decode_packet(bytes)
			if dialog.has("error"):fail("Invalid native dialog: "+str(dialog.error));return
			match str(dialog.kind):
				"dialog-entry":current_dialog=dialog.duplicate(true)
				"dialog-replies":
					if current_dialog.is_empty():continue
					current_dialog.replies=dialog.duplicate(true)
				"dialog-close":current_dialog.clear()
			ui_message_ready.emit(dialog)
		elif phase=="character-loading" and bytes[1]==2 and bytes[2]==18:
			if bytes.size()!=7:fail("Invalid server character rejection");return
			var rejection: Dictionary={"kind":"character-rejected","reason":int(bytes.decode_u32(3))}
			character_confirmed=false;module_information.clear();module_ready_sent=false;pending_preview.clear()
			change_phase("character-rejected")
			deadline=Time.get_ticks_msec()+30000
			character_rejected_ready.emit(rejection)
	if not transport_error.is_empty():fail(transport_error);return
	publish_world_if_ready()

func load_content(requirements: Dictionary)->void:
	var roots: Array[String]=[profile_root,install_root]
	var content_repository: Node=repository
	var resolution: Dictionary=await content_repository.ensure_requirements(content_store,requirements,language,roots,mods_directory,disabled_mods)
	if phase!="loading-content" or repository!=content_repository:return
	if resolution.has("error") or not resolution.get("ready",false):
		fail("Required server content is unavailable: "+str(resolution.get("error","missing="+str(resolution.get("missing",[]).size()))))
		return
	var sources: Dictionary=ResourceSources.build(resolution,install_root,profile_root,profile_root.path_join("replacement-client/server-content"),profile_root.path_join("nwsync"),ProjectSettings.globalize_path("res://../tooling/native/content-reader/nwn-content-reader.exe"),mods_directory,disabled_mods)
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
	if phase=="portal-character-pending":return
	if not peer.send_game_message(PackedByteArray([112,17,1])):fail("Server character-list request failed");return
	change_phase("characters")
	deadline=Time.get_ticks_msec()+15000

func change_phase(next: String)->void:
	phase=next
	phase_changed.emit(next)

func fail(reason: String)->bool:
	error=reason
	close()
	phase="failed"
	session_failed.emit(reason)
	return false

func close()->void:
	if phase=="closed":return
	# Closing the repository settles pending HTTP waits synchronously. Retire the
	# session before that can resume load_content and report Cancel as a failure.
	phase="closed"
	local_vault_allowed=false;local_vault_policy_known=false
	mods_directory="";disabled_mods.clear();portal_workshop_selection.clear()
	if portal_pending.get("identity") is RefCounted:portal_pending.identity.dispose()
	portal_pending.clear()
	if portal_identity!=null:portal_identity.dispose();portal_identity=null
	if portal_character.get("data") is PackedByteArray:portal_character.data.fill(0)
	portal_character.clear();login_waypoint="";player_name=""
	if repository!=null:repository.close();repository.queue_free();repository=null
	if catalog_loader!=null:catalog_loader.close();catalog_loader.queue_free();catalog_loader=null
	catalog=null;catalog_serial=-1
	catalog_archive_repair_attempted=false
	if content_store!=null:content_store.close();content_store=null
	if peer!=null:peer.close();peer=null
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
	lobby_players.reset()
	gui_access.reset();area_generation=0
	gui_panel_attempt_scope.clear();gui_panel_attempt_last=0
	server_status=""
	pending_preview.clear()
	module_information.clear()
	remote_build.clear()
	movement_sequences.clear()
	current_dialog.clear()
	nui_state=NuiState.new();pending_nui.clear();pending_area_visual.clear();local_build.clear()
	resource_sources.clear()
	pending_object_packets.clear();pending_object_bytes=0;object_rules=null
	pending_quickbar_packets.clear();pending_quickbar_bytes=0;pending_visual_packets.clear();pending_visual_bytes=0
	world_state=WorldState.new();world_revision=0;published_revision=-1;last_presentation_ms=0
	phase_changed.emit("closed")
