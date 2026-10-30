extends SceneTree
# Live original campaign rendering. The loopback peer supplies decoded protocol
# state only; native catalogs select/read/prepare every presented game asset.
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const SessionCatalog=preload("res://systems/native_data/session_catalog.gd")
const World=preload("res://systems/native_render/live_world.gd")
const Frames=preload("res://systems/bridge_frames.gd")
const AreaEnvironment=preload("res://systems/area_environment.gd")
const CameraController=preload("res://systems/camera_controller.gd")
const Lights=preload("res://systems/native_render/model_light_budget.gd")
const Registry=preload("res://systems/entity_registry.gd")
const Hud=preload("res://systems/native_hud.gd")
const InputOwner=preload("res://systems/world_input.gd")
const GameplayUi=preload("res://systems/native_gameplay_ui.gd")
const Keyboard=preload("res://systems/native_keyboard.gd")
const FrameProfile=preload("res://systems/native_render/frame_profile.gd")
const WorldRetirement=preload("res://systems/native_render/world_retirement.gd")
const RenderPool=preload("res://systems/native_render/resource_pool.gd")
const Interaction=preload("res://systems/native_interaction_policy.gd")
var render_pool:=RenderPool.new()
var peer:=StreamPeerTCP.new()
var frames:=Frames.new()
var args: Dictionary={}
var ticket: Dictionary={}
var catalog=Catalog.new()
var catalog_loader
var catalog_loading:=false
var resource_recordings: Array=[]
var world
var environment
var camera: Camera3D
var controller
var registry
var transition_targets
var hud
var world_input
var gameplay_ui
var keyboard
var walkmesh_registered:=false
var interactive:=false
var module_name:="Prelude"
var server_label:="LOCAL"
var presentation_stats: Dictionary={}
var stats_at:=0
var preview_captured:=false
var frame_profile
var world_retirement
var data_retirement
var prepared_write_session_lease:=false
var loading_screen
var camera_memory: Dictionary={}
var host: Node3D
var label: Label
var authenticated:=false
var closing:=false
var finish_acknowledged:=false
var initialized:=false
var epoch:=-1
var acknowledged:=-1
var observed_at:=0
var initial_controlled: Variant=null
var entry_camera:=preload("res://systems/native_render/entry_camera.gd").new()
var maximum_distance:=0.0
var received:=0
var samples:=PackedFloat64Array()
var previous:=0
var report:={"success":false,"native_rendering":true,"full_migration":false,"performance_accepted":false,"scope":"Live original Prelude through protocol-only JS; native original resource selection/loading, terrain/objects/actors, animation and authoritative motion. Player UI/input/effects integration incomplete."}
var pending_combat: Array=[]
var pending_visual: Array=[]
var pending_voice: Array=[]
var pending_script_sounds: Array=[]
func _initialize() -> void:
	# Launchers select the secondary screen before the native window is created.
	# Recheck the current topology for direct entry and display hot-plug changes.
	if DisplayServer.get_name()!="headless":
		var primary:=DisplayServer.get_primary_screen()
		for screen in DisplayServer.get_screen_count():
			if screen!=primary:
				root.current_screen=screen
				break
	call_deferred("run")
func run() -> void:
	auto_accept_quit=false; root.close_requested.connect(shutdown)
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("ticket") or not args.has("report") or FileAccess.file_exists(args.report): quit(2); return
	# The engine creates its main window non-activating (project.godot).
	# Keep it non-activating until the user clicks the actual game window.
	# Automated checks never activate it, including synthetic GUI probes.
	if args.get("settings-check","")!="true" and args.get("actions-check","")!="true": root.window_input.connect(activate_window_from_click)
	ticket=JSON.parse_string(FileAccess.get_file_as_string(args.ticket))
	if ticket.get("host")!="127.0.0.1" or not ticket.get("port") is float or str(ticket.get("token","")).length()!=64: quit(2); return
	# Keep cache disposal off transient world/menu close paths. The application
	# releases this lease only after every asset owner has joined at shutdown.
	if GameplayUi.Assets.CacheWrites.configured_enabled(): GameplayUi.Assets.CacheWrites.acquire(); prepared_write_session_lease=true
	host=Node3D.new(); root.add_child(host); var canvas:=CanvasLayer.new(); host.add_child(canvas); label=Label.new(); canvas.add_child(label); label.position=Vector2(12,12); label.add_theme_color_override("font_shadow_color",Color.BLACK); label.add_theme_constant_override("shadow_offset_x",2); label.add_theme_constant_override("shadow_offset_y",2); label.text="Opening native Prelude renderer…"
	world_retirement=WorldRetirement.new(); host.add_child(world_retirement)
	data_retirement=preload("res://systems/native_data/data_retirement.gd").new(); host.add_child(data_retirement)
	loading_screen=preload("res://systems/native_loading_screen.gd").new(); host.add_child(loading_screen); loading_screen.back_requested.connect(cancel_loading)
	if args.get("profile","")=="true":
		frame_profile=FrameProfile.new(); host.add_child(frame_profile); frame_profile.configure(root); frame_profile.control_file=str(args.get("profile-control","")); frame_profile.control.connect(profile_control)
		report.frame_profile_summary=frame_profile.summary_stats
	root.size=Vector2i(1280,800)
	if DisplayServer.get_name()!="headless":
		var screen:=root.current_screen; var usable:=DisplayServer.screen_get_usable_rect(screen)
		root.position=usable.position+(usable.size-root.size)/2
		report.startup_window={"screen":screen,"primary":DisplayServer.get_primary_screen(),"screens":DisplayServer.get_screen_count(),"non_activating":root.unfocusable}
	if peer.connect_to_host("127.0.0.1",int(ticket.port))!=OK: fail("Local protocol peer is unavailable"); return
	process_frame.connect(tick)
func activate_window_from_click(event: InputEvent) -> void:
	if not closing and event is InputEventMouseButton and event.pressed:
		root.window_input.disconnect(activate_window_from_click)
		root.unfocusable=false
		root.grab_focus() # Explicit user click, never automatic startup/teardown.
		report.user_activated_window=true
func send(value: Dictionary) -> void:
	if peer.get_status()==StreamPeerTCP.STATUS_CONNECTED: _send_profiled(value)
func _send_profiled(value: Dictionary) -> void:
	var began:=FrameProfile.begin()
	var encoded:=(JSON.stringify(value)+"\n").to_utf8_buffer()
	FrameProfile.finish("protocol_encode",began); began=FrameProfile.begin()
	peer.put_data(encoded); FrameProfile.finish("protocol_write",began)
func receive(message: Dictionary) -> void:
	if closing and message.get("kind")!="finish-ack": return
	match str(message.get("kind","")):
		"finish-ack": finish_acknowledged=true
		"setup":
			print("NATIVE_SESSION_SETUP_RECEIVED ticks_ms=",Time.get_ticks_msec())
			if initialized or catalog_loading: fail("Duplicate native resource setup"); return
			var install:=str(message.install)
			interactive=bool(message.get("interactive",false)); report.interactive=interactive
			module_name=str(message.get("moduleName","Prelude")); server_label=str(message.get("serverLabel","LOCAL")); root.title="Native Godot · "+module_name+" · "+server_label
			catalog_loading=true; label.text="Indexing native game and server resources…"
			var sources: Dictionary=message.get("resourceSources",{"install":install,"archives":[{"path":str(message.get("moduleFile",install.path_join("data/nwm/Prelude.nwm"))),"priority":100000000}]})
			if args.has("prepared-cache"): sources=sources.duplicate(); sources.rawCacheDirectory=str(args["prepared-cache"]).path_join("original-bytes")
			catalog_loader=SessionCatalog.new(); host.add_child(catalog_loader)
			var mounted: Dictionary={}
			catalog_loader.completed.connect(func(_serial: int, prepared: RefCounted, error: String, stats: Dictionary): mounted.merge({"catalog":prepared,"error":error,"stats":stats}))
			catalog_loader.start(sources)
			var own_loader=catalog_loader
			while mounted.is_empty() and not closing and is_instance_valid(own_loader) and catalog_loader==own_loader: await process_frame
			if closing or not is_instance_valid(own_loader) or catalog_loader!=own_loader: return
			catalog_loading=false
			if not str(mounted.error).is_empty(): fail(mounted.error); return
			catalog=mounted.catalog; report.native_catalog=mounted.stats
			print("NATIVE_SESSION_CATALOG_READY mount_ms=",mounted.stats.get("mount_ms",-1)," ticks_ms=",Time.get_ticks_msec())
			if message.has("recordingDirectory"):
				var recorder:=preload("res://systems/native_data/resource_recording.gd").new()
				var talk_files:={"base":install.path_join("lang/en/data/dialog.tlk"),"female":install.path_join("lang/en/data/dialogf.tlk")}
				if sources.get("customTlk") is Dictionary and sources.customTlk.get("path") is String:
					talk_files.custom=sources.customTlk.path; talk_files.custom_female=str(sources.customTlk.path).trim_suffix(".tlk")+"f.tlk"
				if not recorder.start(str(message.recordingDirectory),catalog.layers,talk_files): fail("Native resource recording could not start"); return
				catalog.recording=recorder; resource_recordings.append(recorder)
			var ui_configure_began:=Time.get_ticks_msec()
			gameplay_ui=GameplayUi.new(); host.add_child(gameplay_ui); gameplay_ui.configure(catalog,install,ProjectSettings.globalize_path(str(args.get("prepared-cache","user://native-prepared-v2"))),str(args.get("menu-layout","user://native-menu-layout.cfg")),sources.customTlk if sources.get("customTlk") is Dictionary else {}); gameplay_ui.world_camera=camera; gameplay_ui.world_registry=registry
			print("NATIVE_GAMEPLAY_UI_CONFIGURED elapsed_ms=",Time.get_ticks_msec()-ui_configure_began," ticks_ms=",Time.get_ticks_msec())
			gameplay_ui.set_gameplay_visible(false)
			gameplay_ui.gui_sound_requested.connect(func(resource):
				if is_instance_valid(world) and is_instance_valid(world.effects) and is_instance_valid(world.effects.world_audio):
					# Original PlayGuiSound1f6110: nonpositional one-shot, priority9,
					# delay0 and default volume. Native catalog/decoder owns the WAV.
					world.effects.world_audio.one_shot(resource,null,0,9,0,0))
			gameplay_ui.request.connect(func(value):
				if str(value.get("kind","")).begins_with("native-creation-"):
					send(value)
				elif is_instance_valid(world) and world.ready_for_control():
					var command: Dictionary=value.duplicate(); command.generation=epoch; command.areaId=world.area_id; send(command))
			loading_screen.configure(gameplay_ui)
			initialized=true; send({"kind":"catalog-ready","layers":catalog.layers.size()})
		"ui-protocol":
			if is_instance_valid(gameplay_ui): gameplay_ui.receive(message.message,int(message.generation))
		"snapshot":
			if not initialized or int(message.generation)<epoch: return
			var data: Dictionary=message.data
			if is_instance_valid(world): world.minutes_per_hour=int(data.get("module",{}).get("minutesPerHour",5))
			if int(message.generation)!=epoch:
				gameplay_ui.set_gameplay_visible(false)
				var transition_began:=FrameProfile.begin()
				if is_instance_valid(world):
					report.retired_areas=report.get("retired_areas",[]); report.retired_areas.append(world.snapshot())
					camera_memory=controller.remembered_pose()
				FrameProfile.finish("transition_old_snapshot",transition_began); transition_began=FrameProfile.begin()
				if is_instance_valid(keyboard): keyboard.stop(false); keyboard.queue_free()
				for owned in [world_input,hud,registry]:
					if is_instance_valid(owned): owned.process_mode=Node.PROCESS_MODE_DISABLED; owned.queue_free()
				if is_instance_valid(world): world_retirement.retire(world)
				if is_instance_valid(environment): environment.queue_free()
				FrameProfile.finish("transition_retire_begin",transition_began); transition_began=FrameProfile.begin()
				epoch=int(message.generation); acknowledged=-1; initial_controlled=null; entry_camera=preload("res://systems/native_render/entry_camera.gd").new(); walkmesh_registered=false; presentation_stats={}; stats_at=0
				loading_screen.begin(epoch,str(data.area.get("resRef",module_name)),data.get("entry",{}))
				world=World.new(); world.entry_prefetch_enabled=args.get("entry-prefetch","")!="false"; world.minutes_per_hour=int(data.get("module",{}).get("minutesPerHour",5)); world.use_skeleton=args.get("skeleton","")=="true"; host.add_child(world); world.open(catalog,data.area,epoch,ProjectSettings.globalize_path(str(args.get("prepared-cache","user://native-prepared-v2"))),render_pool,data.get("entry",{}))
				FrameProfile.finish("transition_world_open",transition_began)
				if camera==null:
					camera=Camera3D.new(); host.add_child(camera); camera.near=0.1; camera.far=150; camera.current=true; camera.position=Vector3(0,15,15)
					controller=CameraController.new(); host.add_child(controller); controller.configure(camera,Vector3.ZERO)
				controller.keyboard_pan=false
				registry=Registry.new(); host.add_child(registry); gameplay_ui.world_camera=camera; gameplay_ui.world_registry=registry
				transition_targets=preload("res://systems/native_render/transition_targets.gd").new(); world.add_child(transition_targets); transition_targets.configure(registry,world.area_id)
				hud=Hud.new(); host.add_child(hud); hud.configure(registry,camera); hud.enable_live_mode(); hud.metrics.hide()
				hud.instructions.text="Middle drag: orbit · wheel: zoom\nW/S: forward/back · A/D: turn · Q/E: strafe\nShift: walk · left click: move, talk, use or pick up\nHold Tab: highlights · right click: examine\nFull gameplay menus and effects pending."
				hud.examine_requested.connect(func(id): send({"kind":"examine","generation":epoch,"areaId":world.area_id,"targetId":id}))
				world_input=InputOwner.new(); host.add_child(world_input); world_input.configure(registry,camera,hud); world_input.camera_controller=controller; world_input.action=world_action
				world_input.extra_pointer_block=gameplay_ui.blocks_pointer; world_input.context_action=gameplay_ui.desktop.open_radial
				world_input.cursor_action=gameplay_ui.mouse_cursor.world_pointer
				world.instance_ready.connect(instance_ready)
				world.instance_state_changed.connect(func(id,source): instance_ready(id,source,world.instances[id]))
				world.instance_removed.connect(func(id):
					if registry.forget_entity(id): hud.queue_refresh_entities())
				keyboard=Keyboard.new(); host.add_child(keyboard); keyboard.context_query=keyboard_context; keyboard.transmit=player_command; keyboard.predict=world.preview_drive; keyboard.end_prediction=world.end_drive
				keyboard.set_key_bindings(gameplay_ui.key_bindings); world_input.set_key_bindings(gameplay_ui.key_bindings); controller.set_key_bindings(gameplay_ui.key_bindings)
				var budget:=Lights.new(); world.add_child(budget); budget.camera=camera; budget.maximum=1
				environment=AreaEnvironment.new(); host.add_child(environment); environment.configure({},world); environment.camera=camera; environment.controller=controller
				var fields: Dictionary=data.area.fields.duplicate(true)
				for key in fields:
					if fields[key] is bool: fields[key]=1 if fields[key] else 0
				report.environment_accepted=environment.receive({"revision":1,"state":{"fields":fields,"time":{"timeOfDay":data.time.timeOfDay,"transition":data.time.get("transition",0)},"minutesPerHour":float(data.module.get("minutesPerHour",0)),"elapsed":float(data.time.get("transition",0))/1000.0}})
			var state_began:=FrameProfile.begin()
			if str(data.get("bridgeMode","full"))=="delta":
				var removed: Array=data.get("removedObjectIds",[])
				world.receive_delta(data.objects,removed,int(data.controlledId))
				var ui_began:=FrameProfile.begin(); gameplay_ui.update_world(epoch,world.area_id,int(data.controlledId),data.objects,removed,data.get("inventory",{}),data); FrameProfile.finish("snapshot_ui_apply",ui_began)
			else:
				var world_began:=FrameProfile.begin()
				world.receive(data.objects,int(data.controlledId))
				FrameProfile.finish("snapshot_world_apply",world_began)
				var ui_began:=FrameProfile.begin()
				gameplay_ui.set_world(epoch,world.area_id,int(data.controlledId),data.objects,data.get("inventory",{}),data)
				FrameProfile.finish("snapshot_ui_apply",ui_began)
			FrameProfile.finish("snapshot_world_and_ui_apply",state_began)
			if data.get("ui",{}).has("players"): world.effects.creature_voices.set_players(data.ui.players)
			if transition_targets.receive(data.objects,data.get("removedObjectIds",[]),str(data.get("bridgeMode","full"))=="delta"): hud.queue_refresh_entities()
			flush_combat()
			received+=1
		"raw-visual-events":
			if int(message.get("generation",-1))<epoch: return
			if pending_visual.size()>=128: report.visual_transport_overflow=int(report.get("visual_transport_overflow",0))+1; return
			pending_visual.append(message); flush_visuals()
		"raw-combat-events":
			if int(message.get("generation",-1))<epoch: return
			if pending_combat.size()>=128: report.combat_transport_overflow=int(report.get("combat_transport_overflow",0))+1; return
			pending_combat.append({"message":message,"received":Time.get_ticks_msec()}); flush_combat()
		"raw-voice-events":
			if int(message.get("generation",-1))<epoch: return
			if pending_voice.size()>=128: report.voice_transport_overflow=int(report.get("voice_transport_overflow",0))+1; return
			pending_voice.append(message); flush_voices()
		"raw-script-sounds":
			if int(message.get("generation",-1))<epoch: return
			if pending_script_sounds.size()>=128: report.script_sound_transport_overflow=int(report.get("script_sound_transport_overflow",0))+1; return
			pending_script_sounds.append(message); flush_script_sounds()
		"movement":
			if is_instance_valid(world) and int(message.get("generation",-1))==epoch and int(message.get("areaId",-1))==world.area_id: world.observe_movement(message.records)
		"drive-ack":
			if is_instance_valid(keyboard) and int(message.get("generation",-1))==epoch and is_instance_valid(world) and int(message.get("areaId",-1))==world.area_id: keyboard.result(message)
		"probe-walk": probe_walk(message)
		"probe-drive": probe_drive()
		"probe-inventory": probe_inventory(bool(message.get("reopen",false)))
		"probe-interact": probe_interact(int(message.targetId))
		"probe-door": probe_door(int(message.targetId))
		"finish": shutdown()
		"failure": fail(str(message.get("reason","Local protocol session failed")))
func flush_combat() -> void:
	flush_visuals()
	flush_voices()
	flush_script_sounds()
	if not is_instance_valid(world): return
	var waiting: Array=[]
	for entry in pending_combat:
		var message: Dictionary=entry.message; var generation:=int(message.generation)
		if generation>epoch: waiting.append(entry); continue
		if generation!=epoch or int(message.areaId)!=world.area_id: continue
		for row in message.events: row.ageMs=int(row.get("ageMs",0))+maxi(0,Time.get_ticks_msec()-int(entry.received))
		world.receive_combat(message)
	pending_combat=waiting
func flush_visuals() -> void:
	if not is_instance_valid(world) or not is_instance_valid(world.effects): return
	var waiting: Array=[]
	for message in pending_visual:
		var generation:=int(message.generation)
		if generation>epoch: waiting.append(message)
		elif generation==epoch and int(message.areaId)==world.area_id: world.effects.receive_raw(message)
	pending_visual=waiting
func flush_voices() -> void:
	if not is_instance_valid(world) or not is_instance_valid(world.effects): return
	var waiting: Array=[]
	for message in pending_voice:
		var generation:=int(message.generation)
		if generation>epoch: waiting.append(message)
		elif generation==epoch and int(message.areaId)==world.area_id: world.effects.creature_voices.receive_raw(message)
	pending_voice=waiting
func flush_script_sounds() -> void:
	if not is_instance_valid(world) or not is_instance_valid(world.effects): return
	var waiting: Array=[]
	for message in pending_script_sounds:
		var generation:=int(message.generation)
		if generation>epoch: waiting.append(message)
		elif generation==epoch and int(message.areaId)==world.area_id: world.effects.script_sounds.receive_raw(message)
	pending_script_sounds=waiting
func tick() -> void:
	if is_instance_valid(frame_profile): frame_profile.start_frame()
	var began:=FrameProfile.begin(); _profile_tick(); FrameProfile.finish("callback_root",began)
func _profile_tick() -> void:
	if closing: return
	var phase_began:=FrameProfile.begin()
	peer.poll()
	if peer.get_status()==StreamPeerTCP.STATUS_CONNECTED:
		if not authenticated: authenticated=true; send({"kind":"hello","token":ticket.token}); ticket.clear()
		var count:=peer.get_available_bytes()
		if count>0:
			var decode_began:=FrameProfile.begin()
			var messages:=frames.feed(peer.get_data(mini(count,1048576))[1])
			FrameProfile.finish("protocol_read_decode",decode_began)
			decode_began=FrameProfile.begin()
			for message in messages: receive(message)
			FrameProfile.finish("protocol_apply",decode_began)
			if not frames.failure.is_empty(): fail(frames.failure); return
	elif authenticated: fail("Local protocol session disconnected"); return
	FrameProfile.finish("root_protocol",phase_began)
	if closing or not is_instance_valid(world): return
	var now:=Time.get_ticks_usec()
	if previous>0:
		samples.append((now-previous)/1000.0)
		if interactive and samples.size()>4096: samples=samples.slice(2048)
	previous=now
	if presentation_stats.is_empty() or now-stats_at>100000:
		phase_began=FrameProfile.begin()
		presentation_stats=world.snapshot(false); stats_at=now
		FrameProfile.finish("root_stats",phase_began)
		label.text="%.1f FPS · Native Godot · %s · %s\n%d/%d entities · %d/%d tiles · %d pending batches\n%d meshes · %d textures	\nMiddle drag: orbit · wheel: zoom · Tab: highlights" % [Engine.get_frames_per_second(),module_name,server_label,presentation_stats.entities,presentation_stats.desired,presentation_stats.terrain.get("rendered_tiles",0),presentation_stats.terrain.get("tiles",0),presentation_stats.pending_batches,presentation_stats.pool.meshes_created,presentation_stats.pool.textures_created]
		if not presentation_stats.failed_objects.is_empty(): label.text+="\n%d object visuals failed · details retained in diagnostics"%presentation_stats.failed_objects.size()
	var state: Dictionary=presentation_stats
	if not walkmesh_registered and is_instance_valid(world.surface) and world.surface.ready(): registry.register_walkmesh(world.surface); walkmesh_registered=true
	phase_began=FrameProfile.begin()
	if initial_controlled==null and not entry_camera.anchored:
		var pending_pose: Dictionary=world.object_pose(world.desired[world.controlled_id].object) if world.desired.has(world.controlled_id) else {}
		if not pending_pose.is_empty() or world.has_priority_origin:
			var position: Vector3=pending_pose.position if not pending_pose.is_empty() else world.priority_origin
			if entry_camera.anchor(camera,controller,position,camera_memory): world.stats.camera_anchor_ms=(Time.get_ticks_usec()-world.opened_at)/1000.0
	if world.instances.has(world.controlled_id):
		var position: Vector3=world.instances[world.controlled_id].position
		if initial_controlled==null:
			initial_controlled=position; entry_camera.anchor(camera,controller,position,camera_memory)
			world.stats.controlled_camera_bound_ms=(Time.get_ticks_usec()-world.opened_at)/1000.0
		var movement: Dictionary=world.motion.objects.get(world.controlled_id,{})
		if not movement.is_empty(): controller.follow_frame(position,rad_to_deg(atan2(movement.orientation.y,movement.orientation.x)),int(movement.animation),root.get_process_delta_time())
		maximum_distance=maxf(maximum_distance,position.distance_to(initial_controlled))
	FrameProfile.finish("root_camera",phase_began)
	var load_errors: Array=[]
	for failure in state.errors: load_errors.append(str(failure))
	for failure in world.terrain.diagnostics.get("errors",[]): load_errors.append(str(failure))
	var anchored: bool=initial_controlled!=null and world.instances.has(world.controlled_id) and controller.follow_valid(world.instances[world.controlled_id].position)
	loading_screen.advance(epoch,{"terrain":world.ready_for_admission(),"player":world.ready_for_control(),"camera":anchored,"tiles":world.terrain.completed_tiles,"total_tiles":world.terrain.definition.get("tiles",[]).size(),"errors":load_errors})
	gameplay_ui.set_gameplay_visible(gameplay_presentation_allowed())
	if not load_errors.is_empty(): report.area_loading_error=load_errors
	if state.admission_ready and acknowledged!=epoch: acknowledged=epoch; send({"kind":"area-ready","generation":epoch,"areaId":world.area_id})
	if Time.get_ticks_msec()-observed_at>500:
		observed_at=Time.get_ticks_msec(); send({"kind":"observed","generation":epoch,"areaId":world.area_id,"state":state,"ui_startup":gameplay_ui.startup_snapshot() if is_instance_valid(gameplay_ui) else {},"controlledDistance":maximum_distance,"fps":Engine.get_frames_per_second(),"frame_profile":frame_profile.snapshot() if is_instance_valid(frame_profile) else {}})
		if interactive and str(args.get("capture-preview","false"))=="true" and DisplayServer.get_name()!="headless" and state.ready and state.pending_batches==0 and not preview_captured:
			preview_captured=true; capture_preview.call_deferred()
func gameplay_presentation_allowed() -> bool:
	# Readiness gates the first reveal. Later appearance/reference preparation
	# must not hide an admitted HUD or steal text focus. New epochs explicitly
	# hide the canvases before opening their world, so this latch cannot cross
	# an area boundary. Server phase/connection gates remain in the session owner.
	return not closing and is_instance_valid(world) and (gameplay_ui.presentation_enabled or world.ready_for_control()) and not loading_screen.blocks_input()
func capture_preview() -> void:
	await RenderingServer.frame_post_draw
	if closing: return
	# GPU readback and PNG encoding are diagnostic work, not asset loading.
	# Keep their wall cost explicit and allow benchmark drivers to omit them.
	var began:=Time.get_ticks_usec(); var image:=root.get_texture().get_image()
	var readback_ms:=(Time.get_ticks_usec()-began)/1000.0
	began=Time.get_ticks_usec(); var error:=image.save_png(str(args.report).trim_suffix(".json")+".ready.png")
	report.diagnostic_preview={"readback_ms":readback_ms,"png_ms":(Time.get_ticks_usec()-began)/1000.0,"error":error,"frame":Engine.get_process_frames()}
func profile_control(command: Dictionary) -> void:
	# Diagnostic ablations only. These modes intentionally alter the workload;
	# their FPS is never accepted as a graphics-preserving optimization.
	if not is_instance_valid(world): return
	var mode:=str(command.get("mode","baseline"))
	if mode=="close": shutdown(); return
	root.disable_3d=mode=="no-3d"
	root.scaling_3d_scale=0.5 if mode=="half-resolution" else 1.0
	root.debug_draw=Viewport.DEBUG_DRAW_UNSHADED if mode=="unshaded" else Viewport.DEBUG_DRAW_DISABLED
	for actor in world.instances.values():
		if actor.has_method("set_animation") and is_instance_valid(actor.rigs):
			actor.rigs.set_process(mode!="no-animation")
			for mesh in actor.meshes:
				var body=mesh.get_meta("collision_body") if mesh.has_meta("collision_body") else null
				if not is_instance_valid(body): continue
				if mode=="no-actor-picking" and body.get_parent()==mesh:
					body.set_meta("profile_local",body.transform); body.reparent(world,true); body.collision_layer=0
				elif mode!="no-actor-picking" and body.get_parent()!=mesh:
					body.reparent(mesh,false); body.transform=body.get_meta("profile_local",Transform3D.IDENTITY); body.collision_layer=Registry.TARGET_LAYER
	for child in world.get_children():
		if child.get_script()==Lights: child.maximum=0 if mode=="no-point-shadows" else 1
	if mode=="capture": capture_preview.call_deferred()
func fail(reason: String) -> void:
	report.failure=reason; shutdown()
func cancel_loading() -> void:
	shutdown()
func keyboard_context() -> Dictionary:
	if is_instance_valid(loading_screen) and loading_screen.blocks_input(): return {}
	if closing or not is_instance_valid(world) or not world.ready_for_control() or not world.motion.objects.has(world.controlled_id): return {}
	var state: Dictionary=world.motion.objects[world.controlled_id]
	var object: Dictionary=world.desired.get(world.controlled_id,{}).get("object",{})
	var position: Array=object.get("replicated",{}).get("position",[])
	if position.size()<3: return {}
	return {"identity":"%s/%s/%s"%[epoch,world.controlled_id,state.lifetime],"id":world.controlled_id,"state":state,"position":Vector3(position[0],position[1],position[2])}
func player_command(value: Dictionary) -> void:
	if is_instance_valid(loading_screen) and loading_screen.blocks_input(): return
	if not is_instance_valid(world) or not world.ready_for_control(): return
	value.generation=epoch; value.areaId=world.area_id; send(value)
func object_name(source: Dictionary) -> String:
	var name_data: Variant=source.get("item",{}).get("name",source.get("replicated",{}).get("name",source.get("appearance",{}).get("name",source.get("staticState",{}).get("name",{}))))
	if name_data is Dictionary:
		if not str(name_data.get("text","")).is_empty(): return str(name_data.text)
		var value:=(str(name_data.get("firstName",{}).get("text",""))+" "+str(name_data.get("lastName",{}).get("text",""))).strip_edges()
		if not value.is_empty(): return value
	return {5:"Creature",6:"Item",9:"Object",10:"Door"}.get(int(source.objectType),"Object")
func instance_ready(id: int,source: Dictionary,instance) -> void:
	var began:=FrameProfile.begin(); _profile_instance_ready(id,source,instance); FrameProfile.finish("selection_registration_ms",began)
func _profile_instance_ready(id: int,source: Dictionary,instance) -> void:
	var row:={"eligible":false}
	if Interaction.eligible(source,world.area_id): row={"id":id,"name":object_name(source),"type":int(source.objectType),"eligible":true,"color":"#66ff99" if int(source.objectType)==5 else "#55ddff"}
	if registry.register_native(id,row,instance): hud.queue_refresh_entities()
func world_action(hit: Dictionary) -> void:
	if is_instance_valid(loading_screen) and loading_screen.blocks_input(): return
	if is_instance_valid(gameplay_ui) and is_instance_valid(gameplay_ui.desktop) and gameplay_ui.desktop.world_click(hit): return
	if not is_instance_valid(world) or not world.ready_for_control(): return
	var id:=int(hit.get("id",-1)); var kind:=int(hit.get("entity",{}).get("type",0)); var base:={"generation":epoch,"areaId":world.area_id}
	var selected_object: Dictionary=world.desired.get(id,{}).get("object",{})
	if selected_object.is_empty() and is_instance_valid(transition_targets): selected_object=transition_targets.objects.get(id,{})
	if id>=0 and not Interaction.eligible(selected_object,world.area_id): return
	if id==world.controlled_id: return
	if id>=0 and kind in [5,9,10]:
		var action:="conversation.start" if kind==5 else "object.use"
		if kind==10:
			var state: Dictionary=world.desired.get(id,{}).get("object",{}).get("replicated",{})
			# Original SetOpenState140423230 / client creation796dd0.
			var opened:=int(state.get("doorOpenState",{22:0,50:1,51:2,72:3}.get(int(state.get("animation",-1)),-1)))
			if opened<0: return
			action="door.transition" if opened>0 and bool(state.get("hasTransition",false)) else ("door.open" if opened==0 else "door.close")
		base.merge({"kind":"interact","targetId":id,"action":action})
	elif id>=0 and kind==6: base.merge({"kind":"pickup","targetId":id})
	elif id>=0 and kind==7:
		var destination: Variant=hit.get("entity",{}).get("destination")
		if not destination is Array or destination.size()!=3: return
		base.merge({"kind":"interact","action":"trigger.transition","targetId":id,"position":destination})
	elif hit.has("position"):
		var position: Vector3=hit.position; base.merge({"kind":"walk","position":[position.x,-position.z,position.y]})
	else: return
	if is_instance_valid(keyboard): keyboard.stop()
	report.pointer_commands=int(report.get("pointer_commands",0))+1; send(base)
func probe_walk(message: Dictionary) -> void:
	if int(message.get("generation",-1))!=epoch or not is_instance_valid(world) or not world.ready_for_control(): fail("Native pointer probe scope is stale"); return
	var p: Array=message.position; var point:=Vector3(p[0],p[2],-p[1]); var previous_camera:=camera.global_transform
	camera.position=point+Vector3(0,12,0.01); camera.look_at(point)
	await physics_frame; await physics_frame
	var hit: Dictionary=registry.pick(camera,camera.unproject_position(point))
	report.pointer_probe={"terrain_hit":int(hit.get("id",-2))==-1,"hit_id":int(hit.get("id",-2)),"error":hit.position.distance_to(point) if hit.has("position") else INF,"runtime_geometry_reads":registry.stats.runtime_geometry_reads,"colliders":registry.stats.colliders,"source":"Native CPU-decoded original mesh shapes through physics ray and normal world-action callback"}
	if hit.is_empty() or int(hit.get("id",-2))!=-1 or float(report.pointer_probe.error)>0.25: camera.global_transform=previous_camera; fail("Native pointer probe did not hit the requested ground"); return
	world_action(hit); camera.global_transform=previous_camera
func probe_drive() -> void:
	if not is_instance_valid(keyboard) or not world.ready_for_control(): fail("Native keyboard probe has no admitted actor"); return
	gameplay_ui.inventory.ui.open()
	keyboard.require_focus=false
	keyboard.key(KEY_W,true)
	await create_timer(0.8).timeout
	if closing: return
	keyboard.key(KEY_A,true)
	await create_timer(0.4).timeout
	if closing: return
	keyboard.key(KEY_A,false); keyboard.key(KEY_W,false); keyboard.require_focus=true
	report.strafe_probes=[]
	for code in [KEY_Q,KEY_E]:
		keyboard.require_focus=false
		await create_timer(0.4).timeout
		if closing or not world.ready_for_control(): return
		var state: Dictionary=world.motion.objects[world.controlled_id]; var facing: Vector3=state.orientation; var origin: Vector3=state.render
		var min_dot:=1.0; var steps:=0; var still:=0; var prior: Vector3=state.render; var until:=Time.get_ticks_msec()+600
		keyboard.key(code,true)
		while Time.get_ticks_msec()<until and not closing:
			await process_frame
			min_dot=minf(min_dot,facing.dot(state.orientation)); steps+=1
			if state.render.distance_to(prior)<0.00001: still+=1
			prior=state.render
		keyboard.key(code,false); keyboard.require_focus=true
		report.strafe_probes.append({"key":"Q" if code==KEY_Q else "E","distance":state.render.distance_to(origin),"minimum_facing_dot":min_dot,"frames":steps,"stationary_frames":still,"walkRate":state.walkRate,"runRate":state.runRate,"collision":world.drive_collision.snapshot()})
		if min_dot<0.99 or state.render.distance_to(origin)<0.2: fail("Local original-server strafe did not retain forward facing and sideways movement"); return
	report.keyboard_probe={"released":keyboard.held.is_empty(),"drive_requests":keyboard.stats.drive,"stop_requests":keyboard.stats.stop,"stats":keyboard.stats.duplicate(true),"collision":world.drive_collision.snapshot(),"inventory_open":gameplay_ui.inventory.ui.visible,"scope":"Native input owner exercised without OS focus with inventory open; accepted movement must be checked in original server replication"}
	gameplay_ui.inventory.ui.close_inventory()
	send({"kind":"drive-probe-done","generation":epoch})
func probe_inventory(reopen: bool) -> void:
	var owner=gameplay_ui.inventory; owner.ui.open()
	var deadline:=Time.get_ticks_msec()+20000
	while not closing and (owner.views.is_empty() or not owner.icons.pending.is_empty()) and Time.get_ticks_msec()<deadline: await process_frame
	if closing: return
	if owner.views.is_empty() or not owner.icons.stats.errors.is_empty() or not owner.icons.pending.is_empty(): fail("Native inventory/items/icons did not finish: "+str(owner.icons.snapshot())); return
	var id:=-1; var slot:=-1
	for row in owner.ui.items.values():
		if row.channel=="I" and int(row.slotMask)!=0: id=int(row.itemId); slot=int(row.slot); break
	if id<0: fail("Original wizard has no server-replicated equipped item for the local inventory test"); return
	var pixels:=0
	for texture in owner.icons.textures.values():
		var image: Image=texture.get_image()
		for y in image.get_height():
			for x in image.get_width():
				if image.get_pixel(x,y).a>0.01: pixels+=1
	if pixels==0: fail("Original GUI item icons rendered no visible pixels"); return
	if not reopen:
		var equipped_key:=str(world.installed.get(world.controlled_id,""))
		owner.ui.operation(id,"unequip")
		deadline=Time.get_ticks_msec()+12000
		while not closing and (str(owner.objects.get(id,{}).get("inventoryLocation",{}).get("channel",""))!="R" or str(owner.ui.items.get(id,{}).get("channel",""))!="R" or str(world.installed.get(world.controlled_id,""))==equipped_key) and Time.get_ticks_msec()<deadline: await process_frame
		if closing: return
		if str(owner.objects.get(id,{}).get("inventoryLocation",{}).get("channel",""))!="R" or str(world.installed.get(world.controlled_id,""))==equipped_key: fail("Original server unequip did not reach inventory and rendered appearance"); return
		owner.ui.drop_slot({"entryId":id},slot)
		deadline=Time.get_ticks_msec()+15000
		while not closing and (str(owner.objects.get(id,{}).get("inventoryLocation",{}).get("channel",""))!="I" or not world.batches.is_empty() or str(world.installed.get(world.controlled_id,""))!=equipped_key) and Time.get_ticks_msec()<deadline: await process_frame
		if closing: return
		if str(owner.objects.get(id,{}).get("inventoryLocation",{}).get("channel",""))!="I" or str(world.installed.get(world.controlled_id,""))!=equipped_key: fail("Original server re-equip did not restore inventory and rendered appearance"); return
	await RenderingServer.frame_post_draw; await RenderingServer.frame_post_draw
	if closing: return
	root.get_texture().get_image().save_png(str(args.report).trim_suffix(".json")+(".inventory-reopen.png" if reopen else ".inventory.png"))
	var result:={"item":id,"slot":slot,"visible_pixels":pixels,"items":owner.views.size(),"icons":owner.icons.snapshot(),"creature_slots_hidden":not owner.ui.creature_slots,"rendered_equipment_roundtrip":not reopen,"reopen":reopen,"scope":"Native original GUI icon pixels and inventory controls; item moves accepted only from original server replication. Initial probe also checks rendered appearance changes/restoration."}
	report["inventory_reopen_probe" if reopen else "inventory_probe"]=result
	if not reopen: owner.ui.close_inventory()
	send({"kind":"inventory-probe-done","itemId":id,"slot":slot,"reopen":reopen,"generation":epoch})
func probe_interact(id: int) -> void:
	if not registry.entities.has(id): fail("Local interaction probe target is not rendered"); return
	var before:=int(gameplay_ui.stats.examines)
	hud.examine_requested.emit(id)
	var deadline:=Time.get_ticks_msec()+5000
	while not closing and int(gameplay_ui.stats.examines)==before and Time.get_ticks_msec()<deadline: await process_frame
	if closing: return
	if int(gameplay_ui.stats.examines)==before: fail("Server examine result did not reach native UI"); return
	gameplay_ui.examine.hide()
	world_action({"id":id,"entity":registry.entities[id]})
	deadline=Time.get_ticks_msec()+20000
	while not closing and gameplay_ui.conversation.entry_id<0 and Time.get_ticks_msec()<deadline: await process_frame
	if closing: return
	if gameplay_ui.conversation.entry_id<0: fail("Server conversation did not reach native reply controls"); return
	var choices:=0
	while gameplay_ui.conversation.opened and gameplay_ui.conversation.entry_id>=0 and choices<16:
		if gameplay_ui.conversation.reply_ids.is_empty(): break
		# Local Prelude fixture policy only: choose an offered tutorial skip or
		# goodbye. No DLG scripts execute here; the original server owns them.
		var selected:=0
		var preferred:=["not interested in a tutorial","not need tutorial","goodbye","time for me to go","not really interested in chatting"]
		var found:=false
		for phrase in preferred:
			for index in gameplay_ui.conversation.replies.get_child_count():
				var button: Button=gameplay_ui.conversation.replies.get_child(index)
				if str(button.get_child(0).get_parsed_text()).to_lower().contains(phrase): selected=index; found=true; break
			if found: break
		gameplay_ui.conversation.choose(gameplay_ui.conversation.reply_ids[selected]); choices+=1
		deadline=Time.get_ticks_msec()+8000
		while not closing and gameplay_ui.conversation.opened and (gameplay_ui.conversation.pending or gameplay_ui.conversation.entry_id<0) and Time.get_ticks_msec()<deadline: await process_frame
		if closing: return
		if Time.get_ticks_msec()>=deadline: break
	if gameplay_ui.conversation.opened: gameplay_ui.conversation.choose(4294967295,true)
	deadline=Time.get_ticks_msec()+5000
	while not closing and gameplay_ui.conversation.opened and Time.get_ticks_msec()<deadline: await process_frame
	if closing: return
	report.interaction_probe={"target":id,"examine_received":int(gameplay_ui.stats.examines)>before,"server_dialog_closed":not gameplay_ui.conversation.opened,"choices":choices,"scope":"Rendered target through normal native action callback; real server examine and conversation, bounded native first-reply choices and server close"}
	if gameplay_ui.conversation.opened: fail("Server conversation close did not reach native UI"); return
	send({"kind":"interact-probe-done","generation":epoch})
func probe_door(id: int) -> void:
	var old_epoch:=epoch
	if not registry.entities.has(id): fail("Original campaign door is not rendered"); return
	world_action({"id":id,"entity":registry.entities[id]})
	var deadline:=Time.get_ticks_msec()+25000
	while not closing and epoch==old_epoch and int(world.desired.get(id,{}).get("object",{}).get("replicated",{}).get("doorOpenState",0))==0 and Time.get_ticks_msec()<deadline: await process_frame
	if closing: return
	if epoch!=old_epoch: fail("Door changed area before the native open/transition probe"); return
	var state: Dictionary=world.desired.get(id,{}).get("object",{}).get("replicated",{})
	if int(state.get("doorOpenState",0))==0 or not bool(state.get("hasTransition",false)): fail("Original server did not open a transition door"); return
	world_action({"id":id,"entity":registry.entities[id]})
	deadline=Time.get_ticks_msec()+35000
	while not closing and (epoch==old_epoch or not world.ready_for_control() or not world.batches.is_empty()) and Time.get_ticks_msec()<deadline: await process_frame
	if closing: return
	report.door_probe={"target":id,"opened_by_server":true,"previous_generation":old_epoch,"generation":epoch,"new_area_ready":epoch!=old_epoch and world.ready_for_control()}
	if not report.door_probe.new_area_ready: fail("Original server door transition did not reach a rendered area"); return
	send({"kind":"door-probe-done","generation":epoch})
func shutdown_stage(stage: String) -> void:
	# Retain the last completed boundary even when a later join/render fence
	# stalls. This is shutdown-only I/O, never per-frame presentation work.
	if not report.has("shutdown_stages"): report.shutdown_stages=[]
	report.shutdown_stages.append({"stage":stage,"ticks_ms":Time.get_ticks_msec()})
	var file:=FileAccess.open(str(args.report).trim_suffix(".json")+".shutdown.json",FileAccess.WRITE)
	if file!=null:
		file.store_string(JSON.stringify({"stages":report.shutdown_stages},"\t")); file.close()
func shutdown() -> void:
	if closing: return
	closing=true
	shutdown_stage("snapshot")
	if report.has("performance_window"): report.performance_window.elapsed_ms=Time.get_ticks_msec()-int(report.performance_window.started_at_ms)
	report.presentation_state={"headless":DisplayServer.get_name()=="headless","engine":Engine.get_version_info(),"method":RenderingServer.get_current_rendering_method(),"driver":RenderingServer.get_current_rendering_driver_name(),"viewport":[root.size.x,root.size.y],"msaa_3d":root.msaa_3d,"vsync":DisplayServer.window_get_vsync_mode(root.get_window_id()) if DisplayServer.get_name()!="headless" else -1,"focused":root.has_focus(),"detailed_profiling":is_instance_valid(frame_profile) and FrameProfile.enabled,"nodes":Performance.get_monitor(Performance.OBJECT_NODE_COUNT),"draws":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"triangles":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),"static_memory_bytes":Performance.get_monitor(Performance.MEMORY_STATIC),"texture_memory_bytes":Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED),"configured_threaded_cull_threshold":ProjectSettings.get_setting("rendering/limits/spatial_indexer/threaded_cull_minimum_instances",-1),"scope":"One cached-counter/configuration observation before shutdown captures; no forced GPU timing queries. Not a clean benchmark by itself."}
	report.diagnostic_preview_policy={"enabled":interactive and str(args.get("capture-preview","false"))=="true" and DisplayServer.get_name()!="headless","captured":preview_captured,"scope":"Automatic ready screenshot is opt-in; explicit diagnostic and shutdown captures are separate"}
	report.animation_validation={"compiled_available":preload("res://systems/native_data/packed_animation_keys.gd").native_available,"forced_gd":OS.get_cmdline_user_args().has("--animation-keys=gd"),"scope":"Read-only binary key finite/time/range validation; ASCII precision and playback channels unchanged"}
	if is_instance_valid(loading_screen): report.loading_screen=loading_screen.snapshot()
	if is_instance_valid(keyboard): report.keyboard=keyboard.stats.duplicate(); keyboard.stop(false)
	if is_instance_valid(world): report.world=world.snapshot()
	if is_instance_valid(environment): report.environment=environment.snapshot(); report.environment_source=environment.source.duplicate(true)
	if is_instance_valid(registry): report.picking=registry.stats.duplicate(true)
	if is_instance_valid(world) and world.instances.has(world.controlled_id):
		var player: Vector3=world.instances[world.controlled_id].global_position
		report.camera={"player":[player.x,player.y,player.z],"target":[controller.target.x,controller.target.y,controller.target.z],"valid":controller.follow_valid(player),"screen":[camera.unproject_position(player).x,camera.unproject_position(player).y]}
		report.protocol_objects=[]
		for id in world.desired:
			var source: Dictionary=world.desired[id].object
			report.protocol_objects.append({"id":id,"name":object_name(source),"type":int(source.objectType),"replicated":source.get("replicated",{})})
	if is_instance_valid(gameplay_ui): report.gameplay_ui=gameplay_ui.snapshot(); gameplay_ui.close()
	report.received_snapshots=received; report.controlled_distance=maximum_distance
	report.playable=not report.has("failure") and report.get("world",{}).get("ready",false)
	report.object_visuals_complete=report.get("world",{}).get("object_visuals_complete",false)
	report.success=report.playable and report.object_visuals_complete and (interactive or maximum_distance>0.2) and report.get("environment_accepted",false)
	shutdown_stage("screenshot")
	if camera!=null and DisplayServer.get_name()!="headless": RenderingServer.force_draw(false); root.get_texture().get_image().save_png(str(args.report).trim_suffix(".json")+".png")
	shutdown_stage("world_close")
	if is_instance_valid(world): world.close()
	shutdown_stage("retired_worlds")
	if is_instance_valid(world_retirement): world_retirement.close(); report.world_retirement=world_retirement.snapshot()
	shutdown_stage("retired_data")
	if is_instance_valid(data_retirement): data_retirement.close(); report.data_retirement=data_retirement.snapshot()
	report.resource_recordings=[]
	for recorder in resource_recordings: report.resource_recordings.append(recorder.close())
	resource_recordings.clear()
	shutdown_stage("render_cache")
	report.render_cache_before_release=render_pool.snapshot(); render_pool.clear(); report.render_cache_after_release=render_pool.snapshot()
	shutdown_stage("host_release")
	await process_frame; await process_frame
	if is_instance_valid(host): host.free()
	shutdown_stage("prepared_cache_writes")
	if prepared_write_session_lease: prepared_write_session_lease=false; GameplayUi.Assets.CacheWrites.release()
	shutdown_stage("render_drain")
	await process_frame; await process_frame
	# With the last camera/canvas freed, an inactive viewport may produce no
	# future frame_post_draw. Flush queued render releases without awaiting a
	# draw signal that now has no producer, and without presenting/activating.
	if DisplayServer.get_name()!="headless": RenderingServer.force_draw(false)
	report.shutdown_render_fence="force_draw_no_swap"
	shutdown_stage("protocol_finish")
	report.workers_remaining=0
	report.prepared_write_queue=GameplayUi.Assets.CacheWrites.snapshot()
	if not samples.is_empty():
		var sorted:=samples.duplicate(); sorted.sort(); var sum:=0.0; var hitches:=0
		for value in samples:
			sum+=value
			if value>50: hitches+=1
		report.frame_intervals={"count":samples.size(),"average_ms":sum/samples.size(),"p95_ms":sorted[mini(sorted.size()-1,int(ceil(sorted.size()*0.95))-1)],"p99_ms":sorted[mini(sorted.size()-1,int(ceil(sorted.size()*0.99))-1)],"worst_ms":sorted[-1],"over_50ms":hitches,"scope":"Retained active-world tick samples (up to4096), may include loading unless performance_window.steady is true; functional run, not clean performance acceptance"}
	send({"kind":"finished","success":report.success})
	var finish_deadline:=Time.get_ticks_msec()+2000
	while not finish_acknowledged and peer.get_status()==StreamPeerTCP.STATUS_CONNECTED and Time.get_ticks_msec()<finish_deadline:
		peer.poll(); var available:=peer.get_available_bytes()
		if available>0:
			for message in frames.feed(peer.get_data(mini(available,1048576))[1]): receive(message)
		if not finish_acknowledged: await process_frame
	report.protocol_finish_ack=finish_acknowledged
	shutdown_stage("report")
	var file:=FileAccess.open(args.report,FileAccess.WRITE); file.store_string(JSON.stringify(report,"\t")); file.close(); peer.disconnect_from_host(); quit(0 if report.success and finish_acknowledged else 1)
