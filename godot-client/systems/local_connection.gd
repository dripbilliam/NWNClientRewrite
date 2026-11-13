extends Node

const MAX_FRAME := 1048576
var owner_scene
var peer := StreamPeerTCP.new()
var pending := PackedByteArray()
var bridge_frames = preload("res://systems/bridge_frames.gd").new()
var token := ""
var authenticated := false
var connected_once := false
var area_id := -1
var generation := -1
var controlled_id := -1
var pivots: Dictionary = {}
var content_sequence := 0
var content_revisions: Dictionary = {}
var world_scope = preload("res://systems/world_scope.gd").new()
var retired_world_refs: Array = []
var retired_audio_refs: Array = []
var retired_world_owners := 0
var motion = preload("res://systems/network_motion.gd").new()
var ground = preload("res://systems/ground_height.gd").new()
var keyboard
var pending_paths: Dictionary = {}
var path_request := 0
var targets: Dictionary = {}
var initial_bounds: Dictionary = {}
var initial_transforms: Dictionary = {}
var overlay: CanvasLayer
var status: Label
var chat: RichTextLabel
var entry: LineEdit
var chat_box: PanelContainer
var chat_ui
var examine_panel
var floating
var last_controlled: Vector3
var following := false
var camera_heights: Dictionary = {}
var camera_memory: Dictionary = {}
var server_camera_mode := -1
var camera_session
var camera_target_id := -1
var camera_events: Array = []
var nwsync_probe
var sync_handoff_watch
var drive_time := 0.0
var walk_active := false
var dialog_panel
var queued_dialogs: Array = []
var smoke_origin: Variant = null
var smoke_screenshot := ""
var smoke_presented := false
var smoke_frame_complete := false
var source_eligibility: Dictionary = {}
var lobby
var connection := 0
var lifecycle_wait_save := false
var model_rigs
var combat = preload("res://systems/combat_animation.gd").new()
var rig_probe_before: Dictionary = {}
var rig_probe_controlled: Dictionary = {}
var rig_probe_motion: Dictionary = {}
var entity_colliders: Dictionary = {}
var removed_states: Dictionary = {}
var gameplay_probe
var radial
var spellbook
var quickbar
var targeting = preload("res://systems/server_targeting.gd").new()
var native_cursor = preload("res://systems/server_cursor.gd").new()
var particles
var effects
var client_dummies
var world_audio
var visual_probe
var inventory
var character_sheet
var level_up
var area_map
var journal
var nui
var buffs
var party
var players
var nui_input_packets = preload("res://systems/nui_packets.gd").new()
var level_state: Dictionary = {}
var options
var main_menu
var server_browser
var creation
var creation_probe
var debug_window
var inventory_probe
var feedback_ack: Dictionary = {}
var interface_probe
var portal_recovery_probe
var shutting_down := false

func configure(scene, ticket_path: String) -> void:
	owner_scene = scene
	get_tree().auto_accept_quit = false
	_make_ui()
	keyboard = preload("res://systems/keyboard_drive.gd").new()
	keyboard.client = self
	add_child(keyboard)
	lobby = preload("res://systems/character_lobby.gd").new()
	add_child(lobby)
	lobby.request.connect(send)
	server_browser = preload("res://systems/server_browser.gd").new(); add_child(server_browser); server_browser.request.connect(browser_request)
	server_browser.closed.connect(func(): if lobby.state.get("phase", "menu") == "menu": main_menu.open(false))
	creation = preload("res://systems/server_creation.gd").new(); add_child(creation); creation.request.connect(send)
	creation.voice_observed.connect(func(value): value["kind"] = "creation-audio-observed"; send(value))
	lobby.creation_requested.connect(creation.open)
	creation.closed.connect(func(): if lobby.state.get("phase", "") in ["character-selection", "character-rejected"]: lobby.panel.show())
	main_menu = preload("res://systems/native_main_menu.gd").new(); add_child(main_menu)
	main_menu.multiplayer_requested.connect(func():
		if lobby.state.get("connected", false) or lobby.state.get("busy", false): lobby.panel.show()
		else: lobby.panel.hide(); server_browser.open())
	main_menu.options_requested.connect(func(): lobby.panel.hide(); options.show(); options.move_to_front())
	main_menu.exit_requested.connect(func(): _notification(NOTIFICATION_WM_CLOSE_REQUEST))
	debug_window = preload("res://systems/native_debug_window.gd").new(); debug_window.visible = false; add_child(debug_window); debug_window.setup(self)
	debug_window.request.connect(send); debug_window.closed_by_user.connect(options.debug_closed)
	options.debug_preference.connect(func(value): debug_window.visible = value)
	options.fps_preference.connect(func(value): if is_instance_valid(owner_scene.native_hud): owner_scene.native_hud.metrics.visible = value)
	if options.debug_enabled: debug_window.show()
	var ticket: Variant = JSON.parse_string(FileAccess.get_file_as_string(ticket_path))
	if not ticket is Dictionary or not ticket.get("port") is float or int(ticket.port) < 1024 or int(ticket.port) > 65535 or str(ticket.get("token", "")).length() != 64:
		fatal("Invalid private local connection ticket")
		return
	token = ticket.token
	var error := peer.connect_to_host("127.0.0.1", int(ticket.port))
	if error != OK:
		fatal("Could not reach local networking backend")

func _make_ui() -> void:
	overlay = CanvasLayer.new()
	overlay.layer = 10
	add_child(overlay)
	status = Label.new()
	status.position = Vector2(16, 85)
	status.text = "Connecting Godot to local server backend…"
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status.add_theme_color_override("font_shadow_color", Color.BLACK)
	status.add_theme_constant_override("shadow_offset_x", 2)
	status.add_theme_constant_override("shadow_offset_y", 2)
	overlay.add_child(status)
	status.hide()
	chat_ui = preload("res://systems/server_chat.gd").new()
	chat_ui.setup()
	chat_box = chat_ui
	chat_box.hide()
	chat_box.position = Vector2(16, 650)
	overlay.add_child(chat_box)
	chat_ui.request.connect(command)
	chat = chat_ui.messages
	entry = chat_ui.entry
	get_viewport().size_changed.connect(_place_chat)
	_place_chat()
	floating = preload("res://systems/server_floating.gd").new()
	overlay.add_child(floating)
	dialog_panel = preload("res://systems/server_conversation.gd").new()
	dialog_panel.setup()
	overlay.add_child(dialog_panel)
	dialog_panel.request.connect(command)
	examine_panel = preload("res://systems/server_examine.gd").new()
	examine_panel.setup()
	overlay.add_child(examine_panel)
	radial = preload("res://systems/server_radial.gd").new()
	add_child(radial)
	radial.request.connect(command)
	targeting.request.connect(command)
	native_cursor.request.connect(command)
	spellbook = preload("res://systems/server_spellbook.gd").new()
	spellbook.setup()
	overlay.add_child(spellbook)
	spellbook.request.connect(command)
	quickbar = preload("res://systems/server_quickbar.gd").new()
	overlay.add_child(quickbar)
	quickbar.setup()
	quickbar.request.connect(command)
	quickbar.assignment_requested.connect(func(index, point):
		radial.open_at(point,null,Vector3.ZERO,false)
		command({"kind":"quickbar-menu","quickbarId":quickbar.quickbar_id,"index":index,"requestId":radial.request_id}))
	inventory = preload("res://systems/server_inventory.gd").new()
	inventory.setup()
	overlay.add_child(inventory)
	inventory.request.connect(command)
	quickbar.inventory_valid = inventory.can_shortcut
	quickbar.radial_valid = radial.can_shortcut
	character_sheet = preload("res://systems/server_character_sheet.gd").new()
	character_sheet.setup()
	overlay.add_child(character_sheet)
	character_sheet.request.connect(command)
	quickbar.record_valid = character_sheet.can_drag
	quickbar.character_requested.connect(toggle_character_sheet)
	level_up = preload("res://systems/server_level_up.gd").new(); level_up.setup(); overlay.add_child(level_up); level_up.request.connect(command)
	area_map = preload("res://systems/server_map.gd").new(); area_map.setup(); overlay.add_child(area_map); area_map.request.connect(command)
	journal = preload("res://systems/server_journal.gd").new(); journal.setup(); overlay.add_child(journal); journal.request.connect(command)
	quickbar.map_requested.connect(toggle_map)
	quickbar.journal_requested.connect(toggle_journal)
	nui = preload("res://systems/server_nui.gd").new(); add_child(nui); nui.setup(overlay); nui.request.connect(send)
	buffs = preload("res://systems/server_buffs.gd").new(); overlay.add_child(buffs); buffs.setup()
	party = preload("res://systems/server_party.gd").new(); overlay.add_child(party); party.setup(); party.request.connect(command); party.panel_requested.connect(_party_panel)
	party.portrait_selected.connect(func(index, _point):
		if targeting.active and not targeting.pending:
			targeting.pending = true
			command({"kind":"party-target","viewId":party.view_id,"entryId":index,"token":targeting.token}))
	party.portrait_menu.connect(func(index, point):
		if targeting.active: targeting.cancel(); return
		radial.open_at(point, null, Vector3.ZERO, false)
		command({"kind":"party-menu","viewId":party.view_id,"entryId":index,"requestId":radial.request_id}))
	players = preload("res://systems/server_players.gd").new(); overlay.add_child(players); players.setup(); players.request.connect(command)
	quickbar.level_requested.connect(func(): level_up.open())
	character_sheet.level_requested.connect(func(): level_up.open())
	inventory.menu_requested.connect(func(id, point):
		radial.open_at(point, null, Vector3.ZERO, false)
		command({"kind": "inventory-menu", "viewId": inventory.view_id, "entryId": id, "requestId": radial.request_id}))
	options = preload("res://systems/native_options.gd").new()
	options.setup()
	overlay.add_child(options)
	options.request.connect(send)
	options.feedback_preference.connect(func(_values): _send_feedback_preferences())
	options.camera_preference.connect(func(mode):
		server_camera_mode = -1
		if camera_session != null: camera_session.set_mode(mode)
		if is_instance_valid(owner_scene.camera_controller): owner_scene.camera_controller.set_follow_mode(mode))
	inventory.creature_slots = options.show_creature_slots
	options.inventory_preference.connect(func(value): inventory.creature_slots = value; inventory.render())
	quickbar.inventory_requested.connect(toggle_inventory)
	quickbar.options_requested.connect(func(): options.visible = not options.visible; options.move_to_front())
	quickbar.spellbook_requested.connect(func():
		if spellbook.visible:
			spellbook.wanted = false
			spellbook.hide()
			command({"kind": "spellbook-close"})
		else:
			spellbook.open())

func _place_chat() -> void:
	chat_box.position.y = maxf(80.0, get_viewport().get_visible_rect().size.y - 380.0)

func browser_request(value: Dictionary) -> void:
	if value.get("kind")=="browser-input" and value.get("operation")=="join": lobby.show_sync_wait()
	send(value)
func send(value: Dictionary) -> void:
	if peer.get_status() == StreamPeerTCP.STATUS_CONNECTED:
		if value.get("kind") != "hello" and not value.has("connection"):
			value["connection"] = connection
		if value.get("kind") == "nui-input" and value.get("operation") != "fragment":
			var packets: Array = nui_input_packets.encode(value)
			if packets.is_empty(): push_error(nui_input_packets.failure); return
			for packet in packets: peer.put_data((JSON.stringify(packet) + "\n").to_utf8_buffer())
			return
		peer.put_data((JSON.stringify(value) + "\n").to_utf8_buffer())

func _send_feedback_preferences() -> void:
	if authenticated and is_instance_valid(options):
		send({"kind":"client-feedback-options","values":options.feedback_values()})

func command(value: Dictionary) -> void:
	if generation < 0:
		return
	value["areaId"] = area_id
	value["generation"] = generation
	send(value)

func _process(delta: float) -> void:
	peer.poll()
	if peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
		if connected_once:
			if interface_probe != null: interface_probe.stop()
			if is_instance_valid(nui): nui.reset()
			if is_instance_valid(buffs): buffs.reset()
			if is_instance_valid(party): party.reset()
			if is_instance_valid(players): players.reset()
			if is_instance_valid(creation): creation.reset()
			if is_instance_valid(server_browser): server_browser.reset(connection)
			if is_instance_valid(options): options.installation.reset(); options.hide()
			world_scope.invalidate()
			_clear_native_world()
			connected_once = false
			dialog_panel.hide()
			status.text = "Disconnected from local server backend"
			if is_instance_valid(lobby):
				lobby.message.text = "Local networking backend ended. Close and relaunch the client to reconnect."
				lobby.panel.show()
		return
	connected_once = true
	if not authenticated:
		send({"kind": "hello", "token": token})
		token = ""
		authenticated = true
		_send_feedback_preferences()
	var count := peer.get_available_bytes()
	if count > 0:
		for frame in bridge_frames.feed(peer.get_data(mini(count, 262144))[1]):
			receive(frame)
		if not bridge_frames.failure.is_empty():
			fatal(bridge_frames.failure)
			return
	if shutting_down: return
	_update_transforms(delta)
	_keyboard(delta)

func receive(message: Dictionary) -> void:
	if shutting_down: return
	if message.get("kind") == "lobby":
		var next := int(message.connection)
		if next < connection:
			return
		if next != connection:
			connection = next
			nui_input_packets.reset()
			if interface_probe != null: interface_probe.stop()
			if is_instance_valid(nui): nui.reset()
			if is_instance_valid(buffs): buffs.reset()
			if is_instance_valid(party): party.reset()
			if is_instance_valid(players): players.reset()
			chat_ui.reset()
			creation.reset()
			server_browser.reset(connection)
			options.hide(); options.installation.reset(); debug_window.backend.clear()
			native_cursor.reset(true)
			world_scope.reset(connection)
			_clear_native_world()
			dialog_panel.hide()
			feedback_ack.clear()
			camera_memory.clear(); server_camera_mode = -1; options.show_camera_mode(options.camera_mode)
			camera_session = null; camera_target_id = -1; camera_events.clear()
			_send_feedback_preferences()
		lobby.apply_state(message)
		if str(message.state.phase) == "menu" and not message.get("auto", false): lobby.panel.hide(); main_menu.open(false)
		elif str(message.state.phase) != "menu": main_menu.panel.hide()
		if str(message.state.phase) in ["connecting","resources","resources-unavailable"]:
			if not server_browser.wanted or server_browser.join_handoff_pending: lobby.show_sync_wait()
		return
	if int(message.get("connection", -1)) != connection:
		return
	if message.get("kind") == "sync-handoff-watch":
		sync_handoff_watch = preload("res://tests/sync_handoff_watch.gd").new(); sync_handoff_watch.start(self,message); return
	if message.get("kind") == "vault-handoff-selection":
		lobby.preferred_auto_key = str(message.key); return
	if message.get("kind") == "portal-recovery-test":
		portal_recovery_probe = preload("res://tests/portal_recovery_probe.gd").new(); portal_recovery_probe.run(self,message); return
	if message.get("kind") == "nui-handoff-test":
		interface_probe = preload("res://tests/nui_handoff_probe.gd").new(); interface_probe.run(self,message); return
	if message.get("kind") == "portal-recovery-retry" and portal_recovery_probe != null:
		portal_recovery_probe.retry(); return
	if message.get("kind") == "feedback-options":
		feedback_ack = message.values.duplicate(true)
		return
	if str(message.get("kind","")).begins_with("camera-") and message.get("kind") not in ["camera-live-test","camera-command-live-test"]:
		_receive_camera(message)
		return
	if str(message.get("kind", "")).begins_with("browser-"):
		server_browser.receive(message)
		var phase:=str(lobby.state.get("phase",""))
		if phase in ["connecting","resources","resources-unavailable"] and lobby.state.get("canCancelJoin",false):
			server_browser.begin_join_handoff(); lobby.show_sync_wait()
		elif message.get("kind")=="browser-view" and not server_browser.join_handoff_pending: lobby.panel.hide()
		if server_browser.panel.visible: main_menu.panel.hide(); lobby.panel.hide()
		return
	if message.get("kind") == "creator-live-test":
		creation_probe = preload("res://systems/creation_probe.gd").new(); creation_probe.run(self, message); return
	if str(message.get("kind", "")).begins_with("settings-"):
		options.installation.receive(message)
		return
	if str(message.get("kind", "")).begins_with("creation-"):
		creation.receive(message); return
	if message.get("kind") == "client-debug": debug_window.receive(message); return
	if message.get("kind") == "menu-exit-test": main_menu.choose("exit"); return
	if message.get("kind") == "setup-live-test":
		interface_probe = preload("res://systems/settings_probe.gd").new(); interface_probe.run(self, message); return
	if message.get("kind") == "nwsync-test-begin":
		nwsync_probe = preload("res://tests/nwsync_probe.gd").new(); nwsync_probe.start(self,message); return
	if message.get("kind") == "nwsync-live-test" and nwsync_probe != null:
		nwsync_probe.finish(message); return
	if str(message.get("kind", "")).begins_with("buff-"):
		buffs.receive(message)
		return
	if str(message.get("kind", "")).begins_with("party-"):
		party.receive(message)
		return
	if str(message.get("kind", "")).begins_with("nui-"):
		nui.receive(message)
		return
	match message.get("kind", ""):
		"quit":
			_shutdown(message)
		"status":
			status.text = str(message.text)
		"loading":
			if message.has("transferId"):
				if not world_scope.begin(message):
					return
			else:
				world_scope.invalidate()
			_clear_native_world()
			dialog_panel.hide()
			status.show()
			status.text = str(message.text)
		"area":
			if not world_scope.matches(message):
				return
			generation = -1
			if str(message.get("metadataSha256", "")).length() != 64 or FileAccess.get_sha256(str(message.scene).get_basename() + ".json") != message.metadataSha256:
				fatal("Native area metadata hash mismatch")
				return
			owner_scene.load_room(str(message.scene))
			if generation != int(message.generation) or area_id != int(message.areaId):
				fatal("Native area does not match current local session")
				return
			world_scope.admit(message)
			send({"kind": "loaded", "areaId": area_id, "generation": generation, "transferId": world_scope.ticket, "entityIds": owner_scene.registry.entities.keys(), "sha256": owner_scene.report.scene_sha256, "meshes": owner_scene.report.mesh_instances, "rigs": model_rigs.stats if is_instance_valid(model_rigs) else {}, "nativeLoadMs": owner_scene.report.load_ms})
			print("LOCAL_NATIVE_LOADED %s %s" % [area_id, generation])
		"content":
			apply_content(message)
		"area-environment":
			if world_scope.admitted and world_scope.matches(message) and is_instance_valid(owner_scene.environment_owner):
				var applied: bool = owner_scene.environment_owner.receive(message)
				send({"kind":"environment-observed","areaId":area_id,"generation":generation,"transferId":world_scope.ticket,"applied":applied,"state":owner_scene.environment_owner.snapshot()})
		"area-sky":
			if world_scope.admitted and world_scope.matches(message) and is_instance_valid(owner_scene.environment_owner):
				var applied: bool = owner_scene.environment_owner.receive_sky(message)
				send({"kind":"sky-observed","areaId":area_id,"generation":generation,"transferId":world_scope.ticket,"applied":applied,"state":owner_scene.environment_owner.snapshot().sky})
		"weather-state":
			if world_scope.admitted and world_scope.matches(message) and is_instance_valid(owner_scene.environment_owner):
				var applied: bool = owner_scene.environment_owner.receive_weather(message)
				send({"kind":"weather-observed","areaId":area_id,"generation":generation,"transferId":world_scope.ticket,"revision":message.revision,"applied":applied,"state":owner_scene.environment_owner.weather.snapshot()})
		"weather-resource":
			if world_scope.admitted and world_scope.matches(message) and is_instance_valid(owner_scene.environment_owner):
				var environment = owner_scene.environment_owner
				if not is_instance_valid(environment.weather_world):
					environment.weather_world = preload("res://systems/weather_world.gd").new();environment.add_child(environment.weather_world)
					environment.weather_world.configure(self,environment,{"connection":connection,"areaId":area_id,"generation":generation,"transferId":world_scope.ticket})
				var applied: bool = environment.weather_world.receive_resource(message)
				send({"kind":"weather-resource-observed","areaId":area_id,"generation":generation,"transferId":world_scope.ticket,"resourceId":message.resourceId,"applied":applied,"state":environment.weather_world.snapshot()})
		"weather-particles":
			if world_scope.admitted and world_scope.matches(message) and is_instance_valid(owner_scene.environment_owner) and is_instance_valid(owner_scene.environment_owner.weather_world):
				owner_scene.environment_owner.weather_world.receive_particles(message)
		"particles-ready", "particle-stream", "particle-complete":
			if generation >= 0 and world_scope.admitted and world_scope.matches(message) and is_instance_valid(particles):
				particles.receive(message)
		"world-audio-cue":
			if world_scope.admitted and world_scope.matches(message) and is_instance_valid(world_audio):world_audio.receive_cue(message.cue)
		"world-audio-begin", "world-audio-chunk", "world-audio-commit", "world-audio-failed":
			if world_scope.admitted and world_scope.matches(message) and is_instance_valid(world_audio):world_audio.receive(message)
		"client-dummy":
			if generation >= 0 and world_scope.admitted and world_scope.matches(message) and is_instance_valid(client_dummies):
				client_dummies.receive(message)
		"visual-reserve", "visual-ready", "visual-remove", "visual-cancel", "visual-model-particles":
			if generation >= 0 and world_scope.admitted and world_scope.matches(message) and is_instance_valid(effects):
				effects.receive(message)
		"visual-live-test":
			if generation >= 0 and world_scope.admitted and world_scope.matches(message):
				visual_probe = preload("res://systems/visual_probe.gd").new()
				visual_probe.run(self, message)
		"movement":
			if not world_scope.admitted or not world_scope.matches(message):
				return
			for row in message.records:
				var id := int(row.id)
				var changes: Dictionary = row.changes
				var deferred: bool = changes.has("path") and not changes.path.is_empty()
				var prior: Dictionary = motion.objects.get(id, {})
				var stale: bool = not row.get("created", false) and prior.get("script", 0) != 0 and prior.has("driveSequence") and int(changes.get("actionFlag", 0)) != 0 and int(changes.actionFlag) != int(prior.driveSequence)
				motion.observe(id, changes, row.get("created", false), row.initial, deferred)
				if deferred and not stale and motion.objects.has(id) and motion.path_animation(int(motion.objects[id].animation)):
					pending_paths[id] = {"row": row, "waiting": false}
				elif changes.has("path") or changes.has("animation") and not motion.path_animation(int(changes.animation)):
					pending_paths.erase(id)
		"drive-ack", "drive-preview":
			if world_scope.matches(message) and is_instance_valid(keyboard):
				keyboard.result(message)
		"path-result":
			if world_scope.matches(message):
				_path_result(message)
		"action-menu", "action-close", "action-error", "action-icon":
			if generation >= 0 and _text_scope(message):
				radial.receive(message)
		"target-mode", "target-hover", "target-error":
			if generation < 0:
				if queued_dialogs.size() < 32:
					queued_dialogs.append(message)
			elif _text_scope(message):
				targeting.receive(message)
		"players-view", "players-closed":
			if generation >= 0 and _text_scope(message): players.receive(message)
		"cursor-image":
			if generation >= 0 and _text_scope(message):
				native_cursor.receive(message)
		"combat-actors", "combat-events":
			if generation >= 0 and _text_scope(message):
				combat.receive(message)
		"spellbook-view", "book-icon", "book-description", "book-notice":
			if generation >= 0 and _text_scope(message):
				spellbook.receive(message)
		"inventory-view", "inventory-icon", "inventory-notice", "inventory-closed":
			if generation >= 0 and _text_scope(message): inventory.receive(message)
		"sheet-view", "sheet-image", "sheet-notice", "sheet-closed":
			if generation >= 0 and _text_scope(message): character_sheet.receive(message)
		"map-view", "map-art", "map-state", "map-pose", "map-notice", "map-closed":
			if generation >= 0 and _text_scope(message): area_map.receive(message)
		"journal-view", "journal-closed":
			if generation >= 0 and _text_scope(message): journal.receive(message)
		"level-availability":
			if generation >= 0 and _text_scope(message):
				level_state = message.duplicate(true)
				quickbar.level_button.visible = message.available
				quickbar.level_button.disabled = false
				character_sheet.level_button.visible = message.available
				character_sheet.level_button.disabled = false
		"level-view", "level-notice", "level-closed", "level-complete":
			if generation >= 0 and _text_scope(message): level_up.receive(message)
		"sheet-live-test":
			if generation >= 0 and _text_scope(message):
				inventory_probe = preload("res://systems/character_sheet_probe.gd").new()
				inventory_probe.run(self, message)
		"level-live-test":
			if generation >= 0 and _text_scope(message):
				inventory_probe = preload("res://systems/level_up_probe.gd").new()
				inventory_probe.run(self, message)
		"interface-spell-ready", "interface-spell-observed":
			if interface_probe != null and generation >= 0 and _text_scope(message):
				if message.kind == "interface-spell-ready": interface_probe.spell_ready = message.duplicate(true)
				else: interface_probe.spell_observation = message.duplicate(true)
		"interface-live-test":
			if generation >= 0 and _text_scope(message):
				interface_probe = preload("res://systems/nui_probe.gd").new()
				interface_probe.run(self, message)
		"status-live-test":
			if generation >= 0 and _text_scope(message):
				interface_probe = preload("res://systems/buff_probe.gd").new()
				interface_probe.run(self, message)
		"roster-live-test":
			if generation >= 0 and _text_scope(message):
				interface_probe = preload("res://systems/party_probe.gd").new()
				interface_probe.run(self, message)
		"records-live-test":
			if generation >= 0 and _text_scope(message):
				inventory_probe = preload("res://systems/map_journal_probe.gd").new()
				inventory_probe.run(self, message)
		"inventory-live-test":
			if generation >= 0 and _text_scope(message):
				inventory_probe = preload("res://systems/inventory_probe.gd").new()
				inventory_probe.run(self, message)
		"shortcut-reconnect-test":
			if generation >= 0 and _text_scope(message):
				inventory_probe = preload("res://tests/shortcut_reconnect_probe.gd").new()
				inventory_probe.run(self, message)
		"feedback-live-test":
			if generation >= 0 and _text_scope(message):
				inventory_probe = preload("res://tests/feedback_options_probe.gd").new()
				inventory_probe.run(self, message)
		"camera-live-test":
			if generation >= 0 and _text_scope(message):
				interface_probe = preload("res://tests/camera_mode_probe.gd").new()
				interface_probe.run(self,message)
		"portal-region-live-test":
			if generation >= 0 and _text_scope(message):
				interface_probe = preload("res://tests/portal_region_probe.gd").new()
				interface_probe.run(self,message)
		"camera-command-live-test":
			if generation >= 0 and _text_scope(message):
				interface_probe = preload("res://tests/camera_command_probe.gd").new()
				interface_probe.run(self,message)
		"weather-live-test":
			if generation >= 0 and _text_scope(message):
				interface_probe = preload("res://tests/weather_probe.gd").new()
				interface_probe.run(self,message)
		"container-live-test":
			if generation >= 0 and _text_scope(message):
				inventory_probe = preload("res://systems/container_probe.gd").new()
				inventory_probe.run(self, message)
		"store-live-test":
			if generation >= 0 and _text_scope(message):
				inventory_probe = preload("res://systems/store_probe.gd").new()
				inventory_probe.run(self, message)
		"quickbar-view", "quickbar-icon":
			if generation >= 0 and _text_scope(message):
				quickbar.receive(message)
		"poses":
			if not world_scope.admitted or not world_scope.matches(message) or int(message.generation) != generation or int(message.areaId) != area_id:
				return
			for pose in message.poses:
				var id := int(pose.id)
				if pivots.has(id):
					if pose.has("cameraHeight"): camera_heights[id] = float(pose.cameraHeight)
					owner_scene.registry.entities[id]["cursor"] = int(pose.get("cursor", 1))
					owner_scene.registry.entities[id]["objectType"] = int(pose.get("objectType", 0))
					var removed: bool = pose.get("removed", false)
					pivots[id].visible = not removed
					owner_scene.registry.entities[id]["eligible"] = source_eligibility.get(id, false) and not removed
					if removed_states.get(id) != removed:
						removed_states[id] = removed
						for body in entity_colliders.get(id, []):
							body.collision_layer = 0 if removed else 1
					if removed:
						motion.objects.erase(id)
						pending_paths.erase(id)
					if not motion.objects.has(id):
						targets[id] = Transform3D(Basis(Vector3.UP, float(pose.rotation)), _vec(pose.position))
					if not motion.objects.has(id) and is_instance_valid(model_rigs) and pose.has("animation"):
						model_rigs.set_animation(id, int(pose.animation), float(pose.get("animationSpeed", 1.0)))
			var next_controlled := int(message.controlledId)
			if next_controlled != controlled_id:
				spellbook.reset()
				quickbar.reset()
				radial.reset()
				targeting.reset(true)
				native_cursor.reset()
				if is_instance_valid(keyboard):
					keyboard.clear(false)
				controlled_id = next_controlled
				following = pivots.has(controlled_id)
				if following:
					last_controlled = pivots[controlled_id].global_position
					_enable_player_camera()
		"chat":
			chat_ui.append_message(message)
		"error":
			chat_ui.append_message({"system": true, "color": "#ffb0a0", "text": str(message.text)})
		"character-saved":
			if creation_probe != null: creation_probe.saved_key = str(message.key)
			chat_ui.append_message({"system": true, "text": "Saved character: " + str(message.name)})
			if lifecycle_wait_save:
				lifecycle_wait_save = false
				send({"kind": "lobby-disconnect", "saveCharacter": true})
		"lifecycle-export":
			lifecycle_wait_save = true
			send({"kind": "lobby-export"})
		"lifecycle-rejoin":
			lobby.preferred_auto_key = str(message.key)
			lobby.last_auto_join = -1
			lobby._auto()
		"lifecycle-close":
			_notification(NOTIFICATION_WM_CLOSE_REQUEST)
		"dialog-entry", "dialog-replies", "dialog-close", "dialog-selected", "dialog-error", "examine", "examine-portrait", "floating":
			if generation < 0:
				if queued_dialogs.size() < 32 and (world_scope.expected.is_empty() or _text_scope(message)):
					queued_dialogs.append(message)
			elif _text_scope(message):
				_dialog(message)
		"smoke":
			if world_scope.admitted and world_scope.matches(message):
				smoke_origin = _vec(message.position)
				smoke_screenshot = str(message.screenshot)
				smoke_presented = false
				smoke_frame_complete = false
				_begin_rig_probe()
				command({"kind": "chat", "text": "Godot local bridge check"})
				if message.get("mode") == "keyboard":
					_movement_smoke()
					return
				var destination := _vec(message.position) + Vector3(float(message.get("offset", 1.5)), 0, 0)
				command({"kind": "walk", "position": [destination.x, destination.y, destination.z]})
		"gameplay-test-begin":
			if world_scope.admitted and world_scope.matches(message) and gameplay_probe == null:
				gameplay_probe = preload("res://tests/gameplay_live_probe.gd").new()
				gameplay_probe.run(self, message)
		"spell-observed":
			if _text_scope(message) and gameplay_probe != null:
				gameplay_probe.note(message)

func _movement_smoke() -> void:
	var scope: Dictionary = world_scope.expected.duplicate()
	keyboard.require_focus = false
	owner_scene.native_hud.panels.help.show()
	owner_scene.native_hud.panels.objects.show()
	var began := Time.get_ticks_usec()
	var phase := -1
	var samples: Array = []
	var text_stopped := false
	var menu_movement := false
	while Time.get_ticks_usec() - began < 6300000:
		await get_tree().process_frame
		if not world_scope.matches(scope) or not motion.objects.has(controlled_id):
			return
		var seconds := (Time.get_ticks_usec() - began) / 1000000.0
		var next_phase := 0 if seconds < 2 else (1 if seconds < 3 else (2 if seconds < 3.8 else (3 if seconds < 4.2 else (4 if seconds < 4.8 else (5 if seconds < 5.6 else 6)))))
		if next_phase != phase:
			keyboard.clear()
			entry.release_focus()
			if next_phase == 0:
				keyboard.handle_key(KEY_W, true)
			elif next_phase == 1:
				keyboard.handle_key(KEY_Q, true)
			elif next_phase == 2:
				keyboard.handle_key(KEY_W, true)
				keyboard.handle_key(KEY_D, true)
			elif next_phase == 4:
				entry.grab_focus()
				keyboard.handle_key(KEY_W, true)
				keyboard.update_input()
				text_stopped = not keyboard.moving and keyboard.keys.is_empty()
			elif next_phase == 5:
				keyboard.handle_key(KEY_SHIFT, true)
				keyboard.handle_key(KEY_W, true)
			phase = next_phase
		var state: Dictionary = motion.objects[controlled_id]
		if keyboard.moving and state.active and owner_scene.native_hud.panels.help.visible and owner_scene.native_hud.panels.objects.visible:
			menu_movement = true
		if samples.size() < 2000:
			samples.append({"ms": int(seconds * 1000), "phase": phase, "position": [state.render.x, state.render.y, state.render.z], "orientation": [state.orientation.x, state.orientation.y], "animation": state.animation, "active": state.active, "script": state.script})
	keyboard.clear()
	keyboard.require_focus = true
	command({"kind": "movement-tested", "result": {"completed": true, "menuMovement": menu_movement, "textFocusStopped": text_stopped, "previewStatistics": keyboard.statistics, "samples": samples}})

func _clear_native_world() -> void:
	if is_instance_valid(owner_scene.camera_controller):
		camera_memory = owner_scene.camera_controller.remembered_pose()
		if owner_scene.camera_controller.follow_state != null: camera_session = owner_scene.camera_controller.follow_state
	if camera_session != null: camera_session.state.focus = null; camera_session.state.position = null
	camera_target_id = -1
	camera_heights.clear()
	if inventory_probe != null: inventory_probe.stop()
	inventory_probe = null
	if is_instance_valid(inventory): inventory.reset()
	if is_instance_valid(character_sheet): character_sheet.reset()
	if is_instance_valid(level_up): level_up.reset()
	if is_instance_valid(area_map): area_map.reset()
	if is_instance_valid(journal): journal.reset()
	level_state.clear()
	if is_instance_valid(options): options.hide()
	if visual_probe != null: visual_probe.stop()
	visual_probe = null
	if is_instance_valid(owner_scene.environment_owner) and is_instance_valid(owner_scene.environment_owner.weather_world): owner_scene.environment_owner.weather_world.retire()
	if is_instance_valid(effects): effects.close()
	effects = null
	if is_instance_valid(world_audio):
		world_audio.close();retired_audio_refs.append_array(world_audio.retired_playback_refs)
	retired_audio_refs = retired_audio_refs.filter(func(reference):return reference.get_ref() != null)
	world_audio = null
	if is_instance_valid(client_dummies): client_dummies.close()
	client_dummies = null
	if is_instance_valid(particles):
		particles.retire()
	particles = null
	if is_instance_valid(keyboard):
		keyboard.clear(false)
	motion.objects.clear()
	ground.configure([])
	pending_paths.clear()
	retired_world_refs = retired_world_refs.filter(func(reference): return reference.get_ref() != null)
	for owned in [owner_scene.world_input, owner_scene.camera_controller, owner_scene.native_hud, owner_scene.registry, owner_scene.room_owner, owner_scene.environment_owner]:
		if is_instance_valid(owned):
			retired_world_refs.append(weakref(owned))
			retired_world_owners += 1
	generation = -1
	area_id = -1
	controlled_id = -1
	following = false
	smoke_origin = null
	smoke_frame_complete = false
	rig_probe_before.clear(); rig_probe_controlled.clear(); rig_probe_motion.clear()
	for collection in [pivots, targets, initial_bounds, initial_transforms, source_eligibility, entity_colliders, removed_states, content_revisions]:
		collection.clear()
	combat.reset()
	model_rigs = null
	if is_instance_valid(radial):
		radial.reset()
	if is_instance_valid(spellbook):
		spellbook.reset()
	if is_instance_valid(quickbar):
		quickbar.reset()
	if is_instance_valid(players): players.reset()
	targeting.reset(true)
	native_cursor.reset()
	if gameplay_probe != null:
		gameplay_probe.stop()
		gameplay_probe = null
	if is_instance_valid(dialog_panel):
		dialog_panel.reset()
	if is_instance_valid(examine_panel):
		examine_panel.reset()
	if is_instance_valid(floating):
		floating.reset()
	owner_scene.clear_room()
	queued_dialogs = queued_dialogs.filter(_text_scope)

func bind_world(metadata: Dictionary) -> void:
	var live: Dictionary = metadata.get("live", {})
	if int(live.get("connection", -1)) != connection:
		fatal("Imported area belongs to another connection")
		return
	if not world_scope.matches(live):
		fatal("Imported area belongs to a retired world transfer")
		return
	area_id = int(live.get("areaId", -1))
	generation = int(live.get("generation", -1))
	controlled_id = int(live.get("controlledId", -1))
	pivots.clear()
	targets.clear()
	initial_bounds.clear()
	initial_transforms.clear()
	source_eligibility.clear()
	entity_colliders.clear()
	removed_states.clear()
	content_sequence = 0
	content_revisions.clear()
	for row in metadata.get("content", []):
		content_revisions[int(row.id)] = int(row.revision)
	motion.configure(metadata.get("clientMotion", {}).get("objects", []))
	ground.configure(metadata.get("clientMotion", {}).get("ground", []))
	motion.height_query = ground.height
	rig_probe_before.clear(); rig_probe_controlled.clear(); rig_probe_motion.clear()
	following = false
	var registry = owner_scene.registry
	for row in metadata.get("entities", []):
		var id := int(row.id)
		if not row.has("pose"):
			continue
		var pivot := Node3D.new()
		registry.add_child(pivot)
		pivot.global_transform = Transform3D(Basis(Vector3.UP, float(row.pose.rotation)), _vec(row.pose.position))
		pivots[id] = pivot
		source_eligibility[id] = row.get("eligible", false)
		initial_transforms[id] = pivot.global_transform
		if registry.bounds.has(id):
			initial_bounds[id] = registry.bounds[id]
		for node in registry.entity_nodes.get(id, []):
			node.reparent(pivot, true)
	# The pick geometry follows the same entity transform as its visual parts.
	for body in registry.get_children():
		if body is StaticBody3D:
			var id := int(body.get_meta("entity_id", -1))
			if pivots.has(id):
				body.reparent(pivots[id], true)
	owner_scene.camera_controller.keyboard_pan = false
	model_rigs = preload("res://systems/model_rigs.gd").new()
	owner_scene.registry.add_child(model_rigs)
	model_rigs.configure(owner_scene.registry, pivots, metadata)
	combat.configure(model_rigs, pivots)
	particles = preload("res://systems/particle_world.gd").new()
	owner_scene.registry.add_child(particles)
	particles.configure(self, metadata, registry, model_rigs)
	world_audio = preload("res://systems/world_audio.gd").new()
	owner_scene.registry.add_child(world_audio)
	world_audio.configure(self)
	client_dummies = preload("res://systems/client_dummies.gd").new()
	owner_scene.registry.add_child(client_dummies)
	client_dummies.configure(self)
	effects = preload("res://systems/visual_world.gd").new()
	owner_scene.registry.add_child(effects)
	effects.configure(self)
	if not model_rigs.stats.failures.is_empty():
		fatal("Native model rig/skin preparation failed")
		return
	for id in registry.parts:
		entity_colliders[id] = []
		for mesh in registry.parts[id]:
			var body = mesh.get_meta("collision_body", null)
			if is_instance_valid(body):
				entity_colliders[id].append(body)
	owner_scene.world_input.action = _world_action
	owner_scene.world_input.context_action = _open_radial
	owner_scene.world_input.cursor_action = _world_cursor
	owner_scene.world_input.extra_pointer_block = func(point): return chat_box.get_global_rect().has_point(point) or (dialog_panel.visible and dialog_panel.get_global_rect().has_point(point)) or (examine_panel.visible and examine_panel.get_global_rect().has_point(point)) or (spellbook.visible and spellbook.get_global_rect().has_point(point)) or (character_sheet.visible and character_sheet.get_global_rect().has_point(point)) or (level_up.visible and level_up.get_global_rect().has_point(point)) or (area_map.visible and area_map.get_global_rect().has_point(point)) or (journal.visible and journal.get_global_rect().has_point(point)) or (players.visible and players.get_global_rect().has_point(point)) or (options.visible and options.get_global_rect().has_point(point)) or main_menu.blocks_pointer(point) or party.blocks_pointer(point) or nui.blocks_pointer(point) or buffs.blocks_pointer(point) or (quickbar.visible and quickbar.get_global_rect().has_point(point)) or inventory.blocks_pointer(point) or radial.blocks_pointer(point) or server_browser.blocks_pointer(point) or lobby.blocks_pointer(point)
	owner_scene.native_hud.enable_live_mode()
	owner_scene.native_hud.metrics.visible = options.show_fps
	status.hide()
	chat_box.show()
	owner_scene.native_hud.examine_requested.connect(func(id): command({"kind": "examine", "targetId": id}))
	for message in queued_dialogs:
		if _text_scope(message):
			_dialog(message)
	queued_dialogs.clear()
	if pivots.has(controlled_id):
		last_controlled = pivots[controlled_id].global_position
		following = true
		_enable_player_camera()

func _enable_player_camera() -> void:
	var mode: int = server_camera_mode if server_camera_mode >= 0 else options.camera_mode
	var current_pose: Dictionary = owner_scene.camera_controller.remembered_pose()
	if not current_pose.is_empty(): camera_memory = current_pose
	owner_scene.camera_controller.enable_follow(mode,last_controlled,float(camera_heights.get(controlled_id,1)),camera_memory,camera_session)
	camera_session = owner_scene.camera_controller.follow_state
	options.show_camera_mode(mode)

func _receive_camera(message: Dictionary) -> void:
	if camera_session == null and is_instance_valid(owner_scene.camera_controller): camera_session = owner_scene.camera_controller.follow_state
	if camera_session == null:
		camera_session = preload("res://systems/game_camera_state.gd").new(); camera_session.reset(options.camera_mode)
	var accepted: bool
	if message.kind == "camera-attach": accepted = _attach_camera(int(message.get("objectId",-1)),bool(message.get("findClearView",false)))
	else: accepted = camera_session.apply_command(message)
	if accepted:
		if message.kind in ["camera-mode","camera-restore"]:
			server_camera_mode = int(camera_session.state.mode); options.show_camera_mode(server_camera_mode)
		camera_events.append({"kind":message.kind,"command":message.duplicate(true),"mode":camera_session.state.mode,"target":camera_target_id})
		if camera_events.size() > 128: camera_events.pop_front()

func _attach_camera(id: int,find_clear: bool = false) -> bool:
	if owner_scene.registry == null or not owner_scene.registry.entities.has(id) or not pivots.has(id) or removed_states.get(id,false): return false
	var entity: Dictionary = owner_scene.registry.entities[id]
	if int(entity.get("objectType",0)) not in [5,9]: return false
	var p: Vector3 = pivots[id].global_position
	camera_session.attach([p.x,-p.z,p.y],float(camera_heights.get(id,1)),int(entity.objectType) == 5,find_clear)
	# Scene clear-view/collision queries are a separate migration step. Retain
	# the request in diagnostics, then release the one-shot gate as the JS owner
	# does when geometry is unavailable; never suppress subsequent commands.
	if find_clear:
		camera_events.append({"kind":"camera-clear-view-unavailable","target":id})
		camera_session.state.findClearView = false
	camera_target_id = -1 if id == controlled_id else id
	return true

func _update_camera(delta: float) -> void:
	if camera_session == null or not is_instance_valid(owner_scene.camera_controller): return
	if camera_target_id >= 0 and (not owner_scene.registry.entities.has(camera_target_id) or removed_states.get(camera_target_id,false)):
		_attach_camera(controlled_id)
	var target: int = controlled_id if camera_target_id < 0 else camera_target_id
	if not pivots.has(target) or not pivots.has(controlled_id): return
	var actor: Dictionary = motion.objects.get(controlled_id,{})
	var direction: Vector3 = actor.get("orientation",Vector3.FORWARD)
	camera_session.state.modeAppearanceHeight = float(camera_heights.get(controlled_id,1))
	owner_scene.camera_controller.follow_frame(pivots[target].global_position,rad_to_deg(atan2(-direction.x,direction.y)),int(actor.get("animation",0)),delta,float(camera_heights.get(target,1)))

func apply_content(message: Dictionary) -> void:
	var began := Time.get_ticks_usec()
	if world_scope.connection != 0 and (not world_scope.admitted or not world_scope.matches(message)):
		return
	if int(message.get("connection", -1)) != connection or int(message.get("areaId", -1)) != area_id or int(message.get("generation", -1)) != generation or int(message.get("sequence", -1)) <= content_sequence:
		return
	var upserts: Array = message.get("upserts", [])
	var removed: Array = message.get("remove", [])
	var ids: Array = upserts.map(func(row): return int(row.id))
	if ids.size() != _unique(ids).size() or not ids.filter(func(id): return removed.has(id)).is_empty():
		fatal("Duplicate native content identity")
		return
	var prepared
	if not upserts.is_empty():
		prepared = preload("res://systems/content_bundle.gd").new()
		owner_scene.add_child(prepared)
		var scope := {"connection": connection, "areaId": area_id, "generation": generation}
		if not prepared.prepare(str(message.get("scene", "")), str(message.get("metadataSha256", "")), scope, upserts):
			var reason: String = prepared.error
			prepared.free()
			fatal(reason)
			return
		if str(prepared.metadata.sha256) != str(message.get("sha256", "")):
			prepared.free()
			fatal("Native content envelope GLB mismatch")
			return
	# Existing content survives all validation/preparation failures above.
	var preserve: Dictionary = {}
	var preserve_targets: Dictionary = {}
	for id in ids:
		if pivots.has(id):
			preserve[id] = pivots[id].global_transform
		if targets.has(id):
			preserve_targets[id] = targets[id]
	for id in ids + removed:
		_retire_entity(int(id), not ids.has(id))
	var mesh_count := 0
	if prepared != null:
		var registry = owner_scene.registry
		registry.adopt_entities(prepared.registry, ids)
		model_rigs.adopt_entities(prepared.rigs, ids)
		for row in prepared.metadata.entities:
			var id := int(row.id)
			var pivot: Node3D = prepared.pivots[id]
			var source_pose := pivot.global_transform
			pivot.reparent(registry, true)
			pivots[id] = pivot
			initial_transforms[id] = source_pose
			if registry.bounds.has(id):
				initial_bounds[id] = registry.bounds[id]
			if preserve.has(id):
				pivot.global_transform = preserve[id]
			if preserve_targets.has(id):
				targets[id] = preserve_targets[id]
			if initial_bounds.has(id):
				registry.bounds[id] = (pivot.global_transform * source_pose.affine_inverse()) * initial_bounds[id]
			source_eligibility[id] = row.get("eligible", false)
			entity_colliders[id] = []
			for mesh in registry.parts[id]:
				var body = mesh.get_meta("collision_body", null)
				if is_instance_valid(body):
					entity_colliders[id].append(body)
				mesh_count += 1
		for row in upserts:
			content_revisions[int(row.id)] = int(row.revision)
		motion.adopt(prepared.metadata.get("clientMotion", {}).get("objects", []))
		if is_instance_valid(particles):
			particles.adopt(prepared.metadata, registry)
		prepared.free()
	content_sequence = int(message.sequence)
	if is_instance_valid(owner_scene.native_hud):
		owner_scene.native_hud.refresh_entities()
	var ack := {"kind": "content-applied", "connection": connection, "areaId": area_id, "generation": generation, "sequence": content_sequence, "entities": ids, "removed": removed, "meshes": mesh_count, "rigs": model_rigs.stats.duplicate(true), "importMs": (Time.get_ticks_usec() - began) / 1000.0}
	if message.has("screenshot"):
		_content_screenshot(ack, str(message.screenshot))
	else:
		send(ack)

func _content_screenshot(ack: Dictionary, filename: String) -> void:
	await RenderingServer.frame_post_draw
	if int(ack.connection) != connection or int(ack.generation) != generation or int(ack.areaId) != area_id:
		return
	var path := ProjectSettings.globalize_path("res://reports/" + filename)
	if filename.get_file() == filename and filename.ends_with(".png") and not FileAccess.file_exists(path):
		if get_viewport().get_texture().get_image().save_png(path) == OK:
			ack["screenshot"] = filename
	send(ack)

func _unique(ids: Array) -> Array:
	var result: Array = []
	for id in ids:
		if not result.has(id):
			result.append(id)
	return result

func _retire_entity(id: int, erase_motion: bool = true) -> void:
	if is_instance_valid(particles):
		particles.forget_entity(id)
	if erase_motion:
		motion.objects.erase(id)
		pending_paths.erase(id)
	for body in entity_colliders.get(id, []):
		if is_instance_valid(body):
			body.collision_layer = 0
	if pivots.has(id):
		var pivot: Node3D = pivots[id]
		pivot.hide()
		pivot.get_parent().remove_child(pivot)
		pivot.queue_free()
	if is_instance_valid(model_rigs):
		model_rigs.forget_entity(id)
	owner_scene.registry.forget_entity(id)
	for collection in [pivots, targets, initial_transforms, initial_bounds, source_eligibility, entity_colliders, removed_states, content_revisions]:
		collection.erase(id)

func _update_transforms(delta: float) -> void:
	if generation < 0 or owner_scene.registry == null:
		return
	motion.update(delta)
	for id in motion.objects:
		if not pivots.has(id) or removed_states.get(id, false):
			continue
		var pose: Dictionary = motion.pose(id)
		pivots[id].global_transform = Transform3D(Basis(Vector3.UP, float(pose.rotation)), pose.position)
		if initial_bounds.has(id):
			owner_scene.registry.bounds[id] = (pivots[id].global_transform * initial_transforms[id].affine_inverse()) * initial_bounds[id]
		var state: Dictionary = motion.objects[id]
		var animation := int(state.animation)
		if state.get("facingTurn") != null and not state.active:
			animation = int(state.facingTurn)
		if is_instance_valid(model_rigs):
			combat.base_frame(id, animation, motion.gait_speed(id, model_rigs.clip_length(id, animation)))
		motion.finish_frame(id)
		if not state.active and int(state.animation) != animation and state.get("facingTurn") == null:
			combat.base_frame(id, int(state.animation))
	for id in targets:
		if motion.objects.has(id):
			continue
		var pivot: Node3D = pivots[id]
		var destination: Transform3D = targets[id]
		var fraction := minf(1.0, delta * 18.0)
		if pivot.global_position.distance_to(destination.origin) > 5.0:
			fraction = 1.0
		pivot.global_transform = pivot.global_transform.interpolate_with(destination, fraction)
		if initial_bounds.has(id):
			owner_scene.registry.bounds[id] = (pivot.global_transform * initial_transforms[id].affine_inverse()) * initial_bounds[id]
	if following and pivots.has(controlled_id):
		var position: Vector3 = pivots[controlled_id].global_position
		_update_camera(delta)
		last_controlled = position
		if smoke_origin != null and not smoke_presented and not rig_probe_controlled.is_empty() and position.distance_to(smoke_origin) > 0.03 and is_instance_valid(model_rigs):
			var sample: Dictionary = model_rigs.compare_samples(rig_probe_controlled, model_rigs.diagnostic_sample([controlled_id]))
			if int(sample.changed_local_parts) > 0 and int(sample.advanced_model_clocks) > 0 and sample.active_clips.any(func(row): return row.clip in ["walk", "run"]): rig_probe_motion = sample
		if smoke_origin != null and not smoke_presented and position.distance_to(smoke_origin) > 0.3:
			smoke_presented = true
			_smoke_presentation(position.distance_to(smoke_origin))
	_request_paths()
	combat.update(delta)
	if is_instance_valid(floating):
		floating.advance(delta, owner_scene.camera, pivots)

func _smoke_presentation(distance: float) -> void:
	var scope: Dictionary = world_scope.expected.duplicate()
	var rigs = model_rigs
	await RenderingServer.frame_post_draw
	if not world_scope.admitted or not world_scope.matches(scope) or not is_instance_valid(rigs) or model_rigs != rigs:
		return
	var image_path := ProjectSettings.globalize_path("res://reports/" + smoke_screenshot)
	var saved := false
	if smoke_screenshot.get_file() == smoke_screenshot and smoke_screenshot.ends_with(".png") and not FileAccess.file_exists(image_path):
		saved = get_viewport().get_texture().get_image().save_png(image_path) == OK
	var camera_follow: bool = owner_scene.camera_controller.follow_valid(pivots[controlled_id].global_position)
	var animation: Dictionary = model_rigs.compare_samples(rig_probe_before, model_rigs.diagnostic_sample()) if is_instance_valid(model_rigs) and not rig_probe_before.is_empty() else {}
	var controlled_animation: Dictionary = model_rigs.compare_samples(rig_probe_controlled, model_rigs.diagnostic_sample([controlled_id])) if is_instance_valid(model_rigs) and not rig_probe_controlled.is_empty() else {}
	if not rig_probe_motion.is_empty(): controlled_animation = rig_probe_motion
	var alive := retired_world_refs.filter(func(reference): return reference.get_ref() != null).size()
	send({"kind": "presented", "areaId": area_id, "generation": generation, "distance": distance, "cameraFollow": camera_follow, "screenshot": smoke_screenshot if saved else "", "animation": animation, "controlledAnimation":controlled_animation,"controlledId":controlled_id,"cleanup": {"retired": retired_world_owners, "alive": alive}})
	smoke_frame_complete = saved

func _begin_rig_probe() -> void:
	rig_probe_motion.clear()
	var scope: Dictionary = world_scope.expected.duplicate()
	var rigs = model_rigs
	await RenderingServer.frame_post_draw
	if world_scope.matches(scope) and is_instance_valid(rigs) and model_rigs == rigs:
		rig_probe_before = model_rigs.diagnostic_sample()
		rig_probe_controlled = model_rigs.diagnostic_sample([controlled_id])

func _dialog(message: Dictionary) -> void:
	if gameplay_probe != null:
		gameplay_probe.note(message)
	if str(message.kind).begins_with("target-"):
		targeting.receive(message)
	elif message.kind == "examine":
		examine_panel.present(message)
	elif message.kind == "examine-portrait":
		examine_panel.set_portrait(message)
	elif message.kind == "floating":
		floating.add_event(message)
	else:
		dialog_panel.present(message)

func _text_scope(message: Dictionary) -> bool:
	var expected: Dictionary = world_scope.expected
	return not expected.is_empty() and int(message.get("connection", -1)) == connection and int(message.get("areaId", -1)) == int(expected.areaId) and int(message.get("generation", -1)) == int(expected.generation)

func _world_action(hit: Dictionary) -> void:
	if is_instance_valid(keyboard):
		keyboard.clear()
	if targeting.active:
		targeting.choose(hit)
		return
	if hit.get("entity", {}).get("eligible", false):
		command({"kind": "interact", "targetId": hit.id})
	elif hit.has("position"):
		var position: Vector3 = hit.position
		command({"kind": "walk", "position": [position.x, position.y, position.z]})

func _open_radial(hit: Dictionary, point: Vector2) -> void:
	if targeting.active:
		targeting.cancel()
		return
	var id: Variant = int(hit.id) if int(hit.get("id", -1)) >= 0 else null
	radial.open_at(point, id, hit.position)

func _world_cursor(hit: Dictionary, blocked: bool) -> void:
	if blocked:
		if native_cursor.desired != -1:
			native_cursor.reset()
		return
	var id := targeting.hover(hit) if targeting.active else int(hit.get("entity", {}).get("cursor", 3 if hit.has("position") else 1))
	native_cursor.select(id, Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT))

func _keyboard(delta: float) -> void:
	if is_instance_valid(keyboard):
		keyboard.update_input()

func _request_paths() -> void:
	for id in pending_paths.keys():
		var pending: Dictionary = pending_paths[id]
		if pending.waiting or not motion.objects.has(id):
			continue
		var state: Dictionary = motion.objects[id]
		var sequence := int(pending.row.changes.get("actionFlag", 0))
		if not motion.path_animation(int(state.animation)) or state.script != 0 and sequence != 0 and sequence != int(state.get("driveSequence", 0)):
			pending_paths.erase(id)
			continue
		path_request += 1
		pending.request = path_request
		pending.position = state.position
		pending.render = state.render
		pending.cursor = state.cursor
		pending.path = state.path.duplicate()
		pending.lifetime = state.lifetime
		pending.script = state.script
		pending.sequence = int(state.get("driveSequence", 0))
		pending.waiting = true
		command({"kind": "path", "actorId": id, "revision": pending.row.revision, "requestId": path_request, "state": {"render": [state.render.x, state.render.y, state.render.z], "path": state.path.map(func(point): return [point.x, point.y, point.z]), "cursor": int(state.cursor), "script": int(state.script), "lastSequence": int(state.get("driveSequence", 0))}})

func _path_result(message: Dictionary) -> void:
	var id := int(message.actorId)
	if not pending_paths.has(id) or not motion.objects.has(id):
		return
	var pending: Dictionary = pending_paths[id]
	if int(pending.get("request", -1)) != int(message.requestId) or int(pending.row.revision) != int(message.revision):
		return
	var state: Dictionary = motion.objects[id]
	pending.waiting = false
	var sequence := int(pending.row.changes.get("actionFlag", 0))
	if not motion.path_animation(int(state.animation)) or state.script != 0 and sequence != 0 and sequence != int(state.get("driveSequence", 0)):
		pending_paths.erase(id)
		return
	if state.position != pending.position or state.render != pending.render or state.cursor != pending.cursor or state.path != pending.path or state.lifetime != pending.lifetime or state.script != pending.script or int(state.get("driveSequence", 0)) != pending.sequence:
		return
	pending_paths.erase(id)
	if message.get("result") != null:
		motion.accept_path(id, message.result, pending.row.changes)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_I, KEY_C, KEY_M, KEY_J] and generation >= 0:
		var focus := get_viewport().gui_get_focus_owner()
		if not (focus is LineEdit or focus is TextEdit):
			if event.keycode == KEY_C: toggle_character_sheet()
			elif event.keycode == KEY_M: toggle_map()
			elif event.keycode == KEY_J: toggle_journal()
			else: toggle_inventory()
			get_viewport().set_input_as_handled()
			return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE and targeting.active:
		var focus := get_viewport().gui_get_focus_owner()
		if not (focus is LineEdit or focus is TextEdit):
			targeting.cancel()
			get_viewport().set_input_as_handled()
			return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ENTER:
		entry.grab_focus()
		get_viewport().set_input_as_handled()

func _party_panel(id: String) -> void:
	if generation < 0: return
	match id:
		"map": toggle_map()
		"inventory": toggle_inventory()
		"journal": toggle_journal()
		"character": toggle_character_sheet()
		"level-up": level_up.open()
		"options": options.visible = not options.visible; options.move_to_front()
		"pvp":
			if players.wanted: players.close_players()
			else: players.open()
		"spells":
			if spellbook.wanted: spellbook.wanted = false; spellbook.hide(); command({"kind":"spellbook-close"})
			else: spellbook.open()

func toggle_inventory() -> void:
	if inventory.wanted: inventory.close_inventory()
	else: inventory.open()

func toggle_character_sheet() -> void:
	if character_sheet.wanted: character_sheet.close_sheet()
	else: character_sheet.open()

func toggle_map() -> void:
	if area_map.wanted: area_map.close_map()
	else: area_map.open()

func toggle_journal() -> void:
	if journal.wanted: journal.close_journal()
	else: journal.open()

func _vec(value: Array) -> Vector3:
	return Vector3(float(value[0]), float(value[1]), float(value[2]))

func fatal(message: String) -> void:
	if is_instance_valid(status):
		status.text = message
	push_error(message)
	peer.disconnect_from_host()
	get_tree().quit(1)

func _exit_tree() -> void:
	combat.reset()
	if nwsync_probe != null and is_instance_valid(lobby) and lobby.resource_progress.is_connected(nwsync_probe.progress): lobby.resource_progress.disconnect(nwsync_probe.progress)
	nwsync_probe = null
	if sync_handoff_watch != null: sync_handoff_watch.stop()
	sync_handoff_watch = null
	# Input retains custom cursor textures beyond the scene unless explicitly reset.
	# Release both its reference and our cache while RenderingServer is still alive.
	if native_cursor != null:
		native_cursor.reset(true)

func _shutdown(message: Dictionary) -> void:
	if shutting_down: return
	shutting_down = true
	set_process(false)
	world_scope.invalidate()
	if interface_probe != null: interface_probe.stop()
	if sync_handoff_watch != null: sync_handoff_watch.stop()
	if is_instance_valid(nui): nui.reset()
	if is_instance_valid(buffs): buffs.reset()
	if is_instance_valid(party): party.reset()
	if is_instance_valid(players): players.reset()
	if is_instance_valid(creation): creation.reset()
	if is_instance_valid(creation) and is_instance_valid(creation.voice_audio):retired_audio_refs.append_array(creation.voice_audio.retired_playback_refs)
	if is_instance_valid(server_browser): server_browser.reset(connection)
	_clear_native_world()
	native_cursor.reset(true)
	# Retire active world/animation/effect/particle/UI owners while the renderer
	# and window still exist. Wait for actual queue-free completion and one draw
	# boundary instead of freeing a live world during SceneTree destruction.
	var frames := 0
	var survivors := retired_world_refs.filter(func(ref):return ref.get_ref() != null).size()
	var audio_survivors := retired_audio_refs.filter(func(ref):return ref.get_ref() != null).size()
	while frames < 60 and (frames < 2 or survivors > 0 or audio_survivors > 0):
		# Playback references are released by the actual mixer, independently of
		# queued Node destruction. Yield real time while polling weak ownership;
		# uncapped render frames alone can exhaust this bound before one mix.
		if audio_survivors > 0:await get_tree().create_timer(0.005).timeout
		await get_tree().process_frame
		frames += 1
		survivors = retired_world_refs.filter(func(ref):return ref.get_ref() != null).size()
		audio_survivors = retired_audio_refs.filter(func(ref):return ref.get_ref() != null).size()
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw
	var observed := {"kind":"shutdown-observed","frames":frames,"retiredWorldOwners":retired_world_owners,"worldSurvivors":survivors,"audioSurvivors":audio_survivors,"nui":nui.retired_state() if is_instance_valid(nui) else {},"partySurvivors":party.retired_alive() if is_instance_valid(party) else 0,"buffSurvivors":buffs.retired_alive() if is_instance_valid(buffs) else 0}
	send(observed)
	print("NATIVE_SHUTDOWN_RETIRED ",JSON.stringify(observed))
	if message.get("diagnoseOrphans", false):
		for id in Node.get_orphan_node_ids():
			var orphan = instance_from_id(id)
			if orphan is Label: print("ORPHAN_UI ", JSON.stringify({"id": id, "text": orphan.text, "name": orphan.name, "script": str(orphan.get_script()), "connections": str(orphan.get_incoming_connections())}))
	peer.disconnect_from_host()
	get_tree().quit(0 if survivors == 0 and audio_survivors == 0 else 1)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if shutting_down: return
		if authenticated and peer.get_status() == StreamPeerTCP.STATUS_CONNECTED and is_instance_valid(lobby):
			status.text = "Disconnecting from local server…"
			send({"kind": "lobby-quit", "saveCharacter": lobby.save_on_disconnect.button_pressed})
		else:
			get_tree().quit()
