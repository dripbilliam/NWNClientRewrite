extends SceneTree
# Live original campaign rendering. The loopback peer supplies decoded protocol
# state only; native catalogs select/read/prepare every presented game asset.
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const SessionCatalog=preload("res://systems/native_data/session_catalog.gd")
const World=preload("res://systems/native_render/live_world_pending_appearances.gd")
const Frames=preload("res://systems/bridge_frames.gd")
const AreaEnvironment=preload("res://systems/area_environment.gd")
const CameraController=preload("res://systems/camera_controller.gd")
const CameraKeyhole=preload("res://systems/native_render/camera_keyhole_presentation.gd")
const TargetPreviewShader=preload("res://systems/native_render/native_target_preview_shader.gd")
const Lights=preload("res://systems/native_render/model_light_budget.gd")
const Registry=preload("res://systems/native_render/door_entity_registry.gd")
const Hud=preload("res://systems/native_hud.gd")
const InputOwner=preload("res://systems/world_input.gd")
const GameplayUi=preload("res://systems/native_gameplay_ui.gd")
const Keyboard=preload("res://systems/native_keyboard.gd")
const FrameProfile=preload("res://systems/native_render/frame_profile.gd")
const CameraObservation=preload("res://systems/native_render/camera_observation.gd")
const WorldRetirement=preload("res://systems/native_render/world_retirement.gd")
const AreaGraphicsPreparation=preload("res://systems/native_render/area_graphics_preparation.gd")
const RendererResourceRetirement=preload("res://systems/native_render/renderer_resource_retirement.gd")
const RenderPool=preload("res://systems/native_render/resource_pool.gd")
const Interaction=preload("res://systems/native_interaction_policy.gd")
const ActionMenu=preload("res://systems/native_data/native_network_action_menu.gd")
const StartupPaths=preload("res://systems/native_data/native_startup_paths.gd")
var render_pool:=RenderPool.new()
var peer:=StreamPeerTCP.new()
var protocol_output=preload("res://systems/native_protocol_output.gd").new()
var creation_runtime=preload("res://systems/native_data/creation_runtime_trace.gd").new()
var frames:=Frames.new()
var args: Dictionary={}
var ticket: Dictionary={}
var direct_mode:=false
var catalog=Catalog.new()
var catalog_loader
var catalog_loading:=false
var resource_recordings: Array=[]
var world
var environment
var gamma_controller
var native_output
var native_output_settings: Dictionary={}
var camera: Camera3D
var controller
var keyhole
var registry
var transition_targets
var hud
var world_input
var gameplay_ui
var keyboard
var walkmesh_registered:=false
var walk_pointer_serial:=0
var interactive:=false
var module_name:="Prelude"
var server_label:="LOCAL"
var presentation_stats: Dictionary={}
var stats_at:=0
var preview_captured:=false
var frame_profile
var runtime_feature_report=preload("res://systems/native_render/native_feature_report.gd").new()
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
var _native_entry_snapshot: Dictionary={}
var _finish_renderer_retirement: Callable
var _finish_graphics_retirement: Callable
var _finish_renderer_resource_transition: Callable
var _finish_renderer_resource_graphics: Callable
var graphics_pending:=false
var area_graphics_failed_epoch:=-1
var area_graphics:=AreaGraphicsPreparation.new()
var _area_graphics_expected_nodes:=-1
var _area_graphics_lights: Dictionary={}
var _area_graphics_exiting_lights: Dictionary={}
var _area_graphics_prune_queued:=false
var renderer_resource_retirement:=RendererResourceRetirement.new()
func begin_renderer_retirement() -> void:
	finish_renderer_retirement()
	# The outgoing scene's keyhole is disposed before the next area installs its
	# own shader state. Its later world exit must not reset the new owner.
	if is_instance_valid(keyhole):keyhole.close();keyhole=null
	graphics_pending=false
	_finish_renderer_resource_transition=renderer_resource_retirement.begin()
	_finish_graphics_retirement=area_graphics.begin()
	renderer_resource_retirement.retire(func():area_graphics.flush())
	if is_instance_valid(world) and is_instance_valid(world_retirement):_finish_renderer_retirement=world_retirement.begin()
func finish_area_graphics_hold() -> void:
	# Area material preparation settles at ACK; previous-world transition
	# retirement may continue until the first scene update is delivered.
	graphics_pending=false
	if _finish_renderer_resource_graphics.is_valid():_finish_renderer_resource_graphics.call()
	_finish_renderer_resource_graphics=Callable()
func renderer_transition_pending() -> bool:
	return _finish_renderer_retirement.is_valid() or _finish_renderer_resource_transition.is_valid() or _finish_graphics_retirement.is_valid()
func finish_renderer_retirement() -> void:
	finish_area_graphics_hold()
	if _finish_renderer_retirement.is_valid():_finish_renderer_retirement.call()
	_finish_renderer_retirement=Callable()
	if _finish_renderer_resource_transition.is_valid():_finish_renderer_resource_transition.call()
	_finish_renderer_resource_transition=Callable()
	if _finish_graphics_retirement.is_valid():_finish_graphics_retirement.call()
	_finish_graphics_retirement=Callable()
	area_graphics.flush()

func native_model_world_timer() -> Variant:
	var runtime: Variant=get("native_clock_runtime")
	return runtime.world_timer() if runtime!=null and runtime.has_method("world_timer") else null
func native_model_diagnostic(_row: Dictionary) -> void: pass

func native_camera_follow_target_id()->int:
	return world.controlled_id if is_instance_valid(world) else -1

func native_camera_follow_height(_target_id: int)->float:
	return 1.0

func native_camera_clear_view_facing(_target_id: int)->float:
	return NAN

func native_camera_clear_view_query()->Callable:
	return Callable()

func native_camera_collision_context()->Dictionary:
	return {}

static func native_camera_steering_input(actor: Dictionary, movement: Dictionary, controlled_rotation: Variant = null) -> Dictionary:
	# NetworkPlayerCamera follows the attached target's position but steers from
	# the controlled actor's orientation and animation.
	var replicated: Dictionary=actor.get("replicated",{})
	var orientation: Variant=movement.get("orientation",replicated.get("orientation"))
	if orientation is Dictionary:orientation=orientation.get("vector")
	var facing:=0.0
	if orientation is Vector3:facing=rad_to_deg(atan2(-orientation.x,orientation.y))
	elif orientation is Array and orientation.size()>=2:facing=rad_to_deg(atan2(-float(orientation[0]),float(orientation[1])))
	elif controlled_rotation is float:facing=rad_to_deg(controlled_rotation)
	var animation:=int(movement.get("animation",0)) if bool(movement.get("active",false)) else int(replicated.get("animation",0))
	return {"facing":facing,"animation":animation}

func native_camera_anchor_early(_delta: float,scoped_world: Node,scoped_epoch: int) -> void:
	if closing or not is_instance_valid(scoped_world) or world!=scoped_world or epoch!=scoped_epoch or scoped_world.closed or scoped_world.retiring or not is_instance_valid(camera) or not is_instance_valid(controller):return
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
		maximum_distance=maxf(maximum_distance,position.distance_to(initial_controlled))

func native_camera_post_motion(delta: float,scoped_world: Node,scoped_epoch: int) -> void:
	if closing or not is_instance_valid(scoped_world) or world!=scoped_world or epoch!=scoped_epoch or scoped_world.closed or scoped_world.retiring or not is_instance_valid(camera) or not is_instance_valid(controller):return
	var phase_began:=FrameProfile.begin()
	var camera_follow_id:=native_camera_follow_target_id()
	if world.instances.has(camera_follow_id):
		var camera_position: Vector3=world.instances[camera_follow_id].position
		var controlled: Dictionary=world.desired.get(world.controlled_id,{}).get("object",{})
		var controlled_motion: Dictionary=world.motion.objects.get(world.controlled_id,{})
		var controlled_rotation: Variant=world.instances[world.controlled_id].rotation.y if world.instances.has(world.controlled_id) else null
		var steering:=native_camera_steering_input(controlled,controlled_motion,controlled_rotation)
		controller.follow_frame(camera_position,float(steering.facing),int(steering.animation),delta,native_camera_follow_height(camera_follow_id),native_camera_clear_view_facing(camera_follow_id),native_camera_clear_view_query(),native_camera_collision_context())
	if is_instance_valid(keyhole):
		var keyhole_player: Variant=world.instances[world.controlled_id].position if world.instances.has(world.controlled_id) else null
		keyhole.update(keyhole_player if keyhole_player is Vector3 else Vector3.ZERO,keyhole_player is Vector3 and gameplay_presentation_allowed())
	FrameProfile.finish("root_camera",phase_began)

func native_focus_player_camera() -> bool:
	if not is_instance_valid(world) or not is_instance_valid(controller) or not is_instance_valid(camera) or controller.follow_state==null:return false
	var controlled_id: int=world.controlled_id
	if not world.instances.has(controlled_id) or not is_instance_valid(world.instances[controlled_id]):return false
	var followed_id:=native_camera_follow_target_id()
	if not world.instances.has(followed_id) or not is_instance_valid(world.instances[followed_id]):return false
	var controlled: Node3D=world.instances[controlled_id]
	var followed: Node3D=world.instances[followed_id]
	controller.focus_on(followed.position)
	var actor: Dictionary=world.desired.get(controlled_id,{}).get("object",{})
	var movement: Dictionary=world.motion.objects.get(controlled_id,{})
	var steering:=native_camera_steering_input(actor,movement,controlled.rotation.y)
	# Old focusPlayer performs one immediate camera update with the controlled
	# actor even when the stored recenter anchor belongs to another attachment.
	camera.keep_aspect=Camera3D.KEEP_HEIGHT
	camera.fov=45.0
	camera.near=0.1
	camera.far=500.0
	controller.follow_frame(controlled.position,float(steering.facing),int(steering.animation),1.0,native_camera_follow_height(followed_id),native_camera_clear_view_facing(followed_id),native_camera_clear_view_query(),native_camera_collision_context())
	return true

func native_entry_snapshot_allowed(_message: Dictionary) -> bool:return true
func complete_native_entry_loading(load_errors: Array) -> void:
	if not is_instance_valid(world) or world.closed or world.retiring or not world.get_meta("native_entry_loading",false) or world.generation!=epoch or not is_instance_valid(loading_screen) or loading_screen.epoch!=epoch or loading_screen.active or not load_errors.is_empty():return
	var milestones: Dictionary=loading_screen.milestones
	if not milestones.get("terrain",false) or not milestones.get("player",false) or not milestones.get("camera",false):return
	world.set_meta("native_entry_loading",false)
	for entry in report.get("entry_commit_entries",[]):
		if int(entry.generation)==epoch and int(entry.area_id)==world.area_id:entry.first_playable_ms=(Time.get_ticks_usec()-int(entry.started_us))/1000.0
func complete_native_publication_loading(load_errors: Array) -> void:
	if not is_instance_valid(world) or not world.get_meta("native_publication_loading",false):return
	if world.closed or world.retiring or world.generation!=epoch or not load_errors.is_empty():
		world.set_meta("native_publication_loading",false);return
	# The loading screen clears at first playable, while known scenery may
	# continue publishing for several seconds. End the private allowance only
	# when the current known static population is fully resolved. Later server
	# population changes use the ordinary budget; no mark is reactivated.
	if world.base_scenery_population_known and not world.base_scenery_progress_dirty and world.base_scenery_known_complete_since_ms!=null:
		world.set_meta("native_publication_loading",false)
func native_entry_snapshot_current(state: Dictionary) -> bool:
	return not closing and initialized and is_same(_native_entry_snapshot,state) and native_entry_snapshot_allowed(state.message)
func begin_native_entry_snapshot(message: Dictionary) -> bool:
	if not initialized or not _native_entry_snapshot.is_empty() or int(message.generation)==epoch or int(message.generation)<epoch or str(message.data.get("bridgeMode","full"))!="full":return false
	_native_entry_snapshot={"message":message,"phase":"capture","new_world":null,"previous_mode":Node.PROCESS_MODE_INHERIT,"renderer_done":false,"phase_us":{},"maximum_unit_us":0,"overruns":{}}
	creation_trace("snapshot:received");creation_trace("snapshot:transition-begin")
	return true
func cancel_native_entry_snapshot() -> void:
	var state: Dictionary=_native_entry_snapshot;_native_entry_snapshot={}
	finish_renderer_retirement()
	if not state.is_empty() and is_instance_valid(state.get("new_world")):
		state.new_world.set_meta("native_publication_loading",false)
		state.new_world.cancel_received_snapshot()
		# Lifecycle reset/replacement retires this unpublished owner. Never
		# activate a cancelled partial entry scene.
		state.new_world.process_mode=Node.PROCESS_MODE_DISABLED
func _native_entry_next(state: Dictionary,phase: String) -> void:
	if native_entry_snapshot_current(state):state.phase=phase
func advance_native_entry_snapshot(deadline_usec: int) -> Dictionary:
	var began:=Time.get_ticks_usec();var units:=0;var maximum:=0;var overruns: Dictionary={}
	while not _native_entry_snapshot.is_empty() and Time.get_ticks_usec()<deadline_usec:
		var state: Dictionary=_native_entry_snapshot
		if not native_entry_snapshot_current(state):cancel_native_entry_snapshot();return {"done":true,"cancelled":true}
		var phase: String=state.phase;var unit_began:=Time.get_ticks_usec()
		_native_entry_snapshot_unit(state,deadline_usec);units+=1
		var elapsed:=Time.get_ticks_usec()-unit_began
		maximum=maxi(maximum,elapsed);state.maximum_unit_us=maxi(int(state.maximum_unit_us),elapsed)
		state.phase_us[phase]=int(state.phase_us.get(phase,0))+elapsed
		if Time.get_ticks_usec()>deadline_usec:
			overruns[phase]=Time.get_ticks_usec()-deadline_usec
			state.overruns[phase]=maxi(int(state.overruns.get(phase,0)),Time.get_ticks_usec()-deadline_usec)
	return {"done":_native_entry_snapshot.is_empty(),"cancelled":false,"units":units,"elapsed_us":Time.get_ticks_usec()-began,"maximum_unit_us":maximum,"overruns":overruns}
func _native_entry_snapshot_unit(state: Dictionary,deadline_usec: int) -> void:
	var message: Dictionary=state.message;var data: Dictionary=message.data
	match str(state.phase):
		"capture":
			gameplay_ui.set_gameplay_visible(false)
			if not native_entry_snapshot_current(state):return
			if is_instance_valid(world):
				report.retired_areas=report.get("retired_areas",[]);report.retired_areas.append(world.snapshot());camera_memory=controller.remembered_pose()
			_native_entry_next(state,"retire")
		"retire":
			begin_renderer_retirement()
			if is_instance_valid(keyboard):keyboard.stop(false);keyboard.queue_free()
			for owned in [world_input,hud,registry]:
				if is_instance_valid(owned):owned.process_mode=Node.PROCESS_MODE_DISABLED;owned.queue_free()
			if is_instance_valid(world):world_retirement.retire(world)
			area_graphics.retire()
			if is_instance_valid(environment):environment.queue_free()
			_native_entry_next(state,"open")
		"open":
			epoch=int(message.generation);acknowledged=-1;initial_controlled=null;entry_camera=preload("res://systems/native_render/entry_camera.gd").new();walkmesh_registered=false;presentation_stats={};stats_at=0
			loading_screen.begin(epoch,str(data.area.get("resRef",module_name)),data.get("entry",{}))
			if not native_entry_snapshot_current(state):return
			world=World.new();world.visual_world_timer=native_model_world_timer();world.set_meta("native_area_graphics_owner",area_graphics);world.camera_pre_motion=Callable(self,"native_camera_anchor_early").bind(world,epoch);world.camera_post_motion=Callable(self,"native_camera_post_motion").bind(world,epoch);state.new_world=world;state.previous_mode=world.process_mode;world.process_mode=Node.PROCESS_MODE_DISABLED
			world.set_meta("native_model_diagnostic",Callable(self,"native_model_diagnostic"))
			world.set_meta("native_entry_loading",true);world.set_meta("native_entry_commit_pending",true)
			if render_pool.scenery_publication_budget_us>render_pool.publication_budget_us:world.set_meta("native_publication_loading",true)
			world.tile_borders_enabled=native_tile_borders_enabled();world.set_meta("native_enhanced_lighting",render_pool.native_lighting)
			if render_pool.native_surface_output:world.set_meta("native_surface_output",true)
			world.entry_prefetch_enabled=args.get("entry-prefetch","")!="false";world.minutes_per_hour=int(data.get("module",{}).get("minutesPerHour",5));world.use_skeleton=args.get("skeleton","")=="true"
			host.add_child(world)
			world.open(catalog,data.area,epoch,ProjectSettings.globalize_path(str(args.get("prepared-cache","user://native-prepared-v2"))),render_pool,data.get("entry",{}))
			if not native_entry_snapshot_current(state):return
			native_material_policy_ready();_native_entry_next(state,"camera")
		"camera":
			if camera==null:
				camera=Camera3D.new();host.add_child(camera);camera.near=0.1;camera.far=150;camera.current=true;camera.position=Vector3(0,15,15)
				gamma_controller.attach(camera);controller=CameraController.new();host.add_child(controller);controller.configure(camera,Vector3.ZERO);controller.orbit_admission=native_camera_orbit_allowed;controller.key_admission=native_camera_keys_allowed;controller.pointer_admission=native_camera_pointer_allowed;controller.focus_request=Callable(self,"native_focus_player_camera")
			keyhole=CameraKeyhole.new();world.add_child(keyhole);keyhole.configure(world.terrain,camera,controller,catalog)
			if keyhole.blocked:native_model_diagnostic({"code":"camera.keyhole-load-failed","message":str(preload("res://systems/native_render/native_camera_keyhole.gd").source_profile.get("error","Native keyhole shader is unavailable")),"detail":{},"severity":"error"})
			controller.keyboard_pan=false;_native_entry_next(state,"registry")
		"registry":
			registry=Registry.new();host.add_child(registry);gameplay_ui.world_camera=camera;gameplay_ui.world_registry=registry
			registry.configure_highlight_assets(world.references.assets,catalog,world.pool)
			gameplay_ui.world_camera_yaw=func():return controller.follow_state.quaternion_yaw(controller.follow_state.state.quaternion) if controller.follow_state!=null else NAN
			transition_targets=preload("res://systems/native_render/transition_targets.gd").new();world.add_child(transition_targets);transition_targets.configure(registry,world.area_id)
			bind_scenery_picking()
			hud=Hud.new();host.add_child(hud);hud.configure(registry,camera);hud.enable_live_mode();hud.metrics.hide();hud.bind_gameplay(gameplay_ui)
			hud.instructions.text="Middle drag: orbit · wheel: zoom\nW/S: forward/back · A/D: turn · Q/E: strafe\nShift: walk · left click: move, talk, use or pick up\nHold Tab: highlights · right click: examine\nFull gameplay menus and effects pending."
			hud.examine_requested.connect(func(id):send({"kind":"examine","generation":epoch,"areaId":world.area_id,"targetId":id}))
			_native_entry_next(state,"input")
		"input":
			bind_world_input()
			var hover=preload("res://systems/native_render/world_hover_presentation.gd").new();world.add_child(hover);hover.configure(world,registry);world_input.hover_presentation=hover.select
			world_input.extra_pointer_block=native_world_pointer_blocked
			world_input.context_action=gameplay_ui.desktop.open_radial;world_input.cursor_action=gameplay_ui.mouse_cursor.world_pointer
			world.instance_ready.connect(instance_ready)
			world.instance_state_changed.connect(func(id,source):instance_ready(id,source,world.instances[id]))
			world.instance_removed.connect(func(id):
				if registry.forget_entity(id):hud.queue_refresh_entities())
			keyboard=Keyboard.new();host.add_child(keyboard);keyboard.context_query=keyboard_context;keyboard.enabled_query=native_keyboard_enabled;keyboard.transmit=player_command;keyboard.predict=world.preview_drive;keyboard.end_prediction=world.end_drive;world.preview_token=keyboard.preview_token;world.preview_completed=keyboard.complete_async_preview
			world_input.clear_movement=func():
				if is_instance_valid(keyboard):keyboard.stop()
			keyboard.set_key_bindings(gameplay_ui.key_bindings);world_input.set_key_bindings(gameplay_ui.key_bindings);controller.set_key_bindings(gameplay_ui.key_bindings)
			keyboard.set_frame_input_admission(bool(ProjectSettings.get_setting("nwn/private/keyboard_frame_admission",true)))
			var budget:=Lights.new();world.add_child(budget);budget.camera=camera;budget.maximum=int(args.get("native-shadow-lights",3));budget.focus_query=world.shadow_focus;world.set_meta("native_point_shadow_budget",weakref(budget))
			_native_entry_next(state,"environment")
		"environment":
			environment=AreaEnvironment.new();host.add_child(environment);environment.configure({},world);environment.camera=camera;environment.controller=controller
			if is_instance_valid(native_output):native_output.bind(world,environment,gamma_controller,native_output_settings)
			_native_entry_next(state,"header")
		"header":
			report.environment_accepted=publish_area_environment(data,int(message.generation))
			if not native_entry_snapshot_current(state):return
			if is_instance_valid(world.placeable_lights):world.placeable_lights.receive_area(data.area.get("placeableLights",[]))
			_native_entry_next(state,"renderer_begin")
		"renderer_begin":
			var metadata: Dictionary=snapshot_metadata if not snapshot_metadata.is_empty() and is_same(snapshot_metadata_objects,data.objects) else {}
			if not world.begin_received_snapshot(data.objects,int(data.controlledId),metadata):
				# Fresh-entry admission is deliberately narrow. Never silently
				# resume a rejected partial world through a different algorithm.
				fail("Native entry world rejected cooperative full boundary");return
			_native_entry_next(state,"renderer")
		"renderer":
			var result: Dictionary=world.advance_received_snapshot(deadline_usec)
			state.renderer_receipt=result
			if result.get("cancelled",false):cancel_native_entry_snapshot();return
			if result.get("done",false):state.renderer_done=true;_native_entry_next(state,"ui")
		"ui":
			gameplay_ui.set_world(epoch,world.area_id,int(data.controlledId),data.objects,data.get("inventory",{}),data)
			_native_entry_next(state,"wind_voice")
		"wind_voice":
			if is_instance_valid(world.point_wind):world.point_wind.set_area(data.area.get("fields",{}))
			if data.get("ui",{}).has("players"):world.effects.creature_voices.set_players(data.ui.players)
			_native_entry_next(state,"targets")
		"targets":
			if transition_targets.receive(data.objects,data.get("removedObjectIds",[]),false):hud.queue_refresh_entities()
			_native_entry_next(state,"combat")
		"combat":
			flush_combat();_native_entry_next(state,"finish")
		"finish":
			received+=1;_native_entry_snapshot={}
			# Session keeps the coherent scene disabled through visibility/API/
			# ACK publication, then restores this original process mode.
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
# Private native-only sidecar; decoded bridge fields never populate it.
var snapshot_metadata_objects: Array=[]
var snapshot_metadata: Dictionary={}
func native_clock_startup() -> void: pass
func observed_camera_snapshot() -> Dictionary:
	if not is_instance_valid(camera): return {}
	var value:=CameraObservation.pose(camera)
	if is_instance_valid(controller):
		value.target=[controller.target.x,controller.target.y,controller.target.z]
		value.follow=controller.remembered_pose()
		if controller.follow_state!=null:
			value.follow_height=float(controller.follow_state.state.height)
			value.networkCamera=controller.follow_state.snapshot()
	if is_instance_valid(world) and world.motion.objects.has(world.controlled_id):
		var state: Dictionary=world.motion.objects[world.controlled_id]
		var controlled:={"actor_id":world.controlled_id,"generation":world.generation,"area_id":world.area_id,"lifetime":int(state.get("lifetime",-1)),"active":bool(state.get("active",false)),"script":int(state.get("script",0)),"driveHeld":bool(state.get("driveHeld",false))}
		for field in ["driveSequence","driveSentSequence","driveSentRequestId","releasedTerminalCorrections","releasedTerminalSequence"]:
			if state.has(field): controlled[field]=state[field]
		for field in ["position","render"]:
			var point: Variant=state.get(field)
			if point is Vector3: controlled[field]=[point.x,point.y,point.z]
		var received: Variant=world.desired.get(world.controlled_id,{}).get("object",{}).get("replicated",{}).get("position")
		if received is Array: controlled.received_position=received.duplicate()
		value.controlled=controlled
	return value
func runtime_features_snapshot() -> Dictionary:
	var value:=runtime_feature_report.snapshot()
	value.presentation={"detailed_profiling":is_instance_valid(frame_profile) and FrameProfile.enabled,"viewport":[root.size.x,root.size.y],"msaa_3d":root.msaa_3d,"maximum_fps":Engine.max_fps,"vsync":DisplayServer.window_get_vsync_mode(root.get_window_id()) if DisplayServer.get_name()!="headless" else null,"screen":root.current_screen if DisplayServer.get_name()!="headless" else null,"primary_screen":DisplayServer.get_primary_screen() if DisplayServer.get_name()!="headless" else null,"unfocusable":root.unfocusable,"focused":root.has_focus(),"mouse_mode":Input.mouse_mode}
	value.presentation.camera=observed_camera_snapshot()
	return value
func native_clock_prefix() -> void: pass
func native_clock_post_receive() -> void: pass
func dispatch_protocol_messages(messages: Array,_wire_sizes: PackedInt32Array) -> void:
	for message in messages:receive(message)
func native_material_policy_ready() -> void: pass
func native_area_graphics_gate() -> Dictionary:
	# Request the actual published area's color/fade material variants and
	# retain its shadow-casting materials through the current epoch. Godot's
	# material RID request does not expose compileAsync completion.
	if not _finish_renderer_resource_graphics.is_valid():_finish_renderer_resource_graphics=renderer_resource_retirement.begin()
	graphics_pending=true
	var result: Dictionary=area_graphics.prepare(world,epoch)
	# The old graphics work releases its resource hold only in finally, after
	# complete/failed has settled. The caller finishes this hold after its
	# area-ready or error path; reset/shutdown also release it on cancellation.
	return result
func native_area_graphics_failed(reason: String) -> void:
	fail("Native area graphics preparation failed: "+reason)
func _begin_area_graphics_light_census() -> void:
	if _area_graphics_expected_nodes>=0:return
	# Start before the session creates its World. Count deltas detect reads
	# reentered before SceneTree has emitted the corresponding node signal.
	_area_graphics_expected_nodes=get_node_count()
	for light in root.find_children("*","Light3D",true,false):
		_area_graphics_lights[light.get_instance_id()]=light
	node_added.connect(_area_graphics_node_added)
	node_removed.connect(_area_graphics_node_removed)

func _end_area_graphics_light_census() -> void:
	if node_added.is_connected(_area_graphics_node_added):node_added.disconnect(_area_graphics_node_added)
	if node_removed.is_connected(_area_graphics_node_removed):node_removed.disconnect(_area_graphics_node_removed)
	_area_graphics_expected_nodes=-1
	_area_graphics_lights.clear()
	_area_graphics_exiting_lights.clear()

func _area_graphics_node_added(node: Node) -> void:
	_area_graphics_expected_nodes+=1
	if not node is Light3D:return
	var id:=node.get_instance_id()
	_area_graphics_lights[id]=node
	_area_graphics_exiting_lights.erase(id)

func _area_graphics_node_removed(node: Node) -> void:
	_area_graphics_expected_nodes-=1
	if not node is Light3D:return
	# During child_exiting_tree the old query can still see an exiting light.
	# Leave its identity in the index until its tree exit has unwound.
	_area_graphics_exiting_lights[node.get_instance_id()]=true
	if not _area_graphics_prune_queued:
		_area_graphics_prune_queued=true
		_prune_area_graphics_exiting_lights.call_deferred()

func _prune_area_graphics_exiting_lights() -> void:
	_area_graphics_prune_queued=false
	for id in _area_graphics_exiting_lights:
		_area_graphics_lights.erase(id)
	_area_graphics_exiting_lights.clear()

func native_area_graphics_profile() -> Array:
	# Old readProfile observes renderer light slot capacities and the visible
	# shadow-casting scene before preparing each asset. Godot exposes only its
	# authored admission result and live Light3D state, not WebGL internals.
	var slots: Array=[]
	var shadows: Array[int]=[0,0,0]
	if is_instance_valid(world):
		if is_instance_valid(world.focus_lighting):
			var admitted: Dictionary=world.focus_lighting.renderer_result
			if admitted.has("maxLights"):slots.append(int(admitted.maxLights))
		var began:=FrameProfile.begin()
		var use_census: bool=_area_graphics_expected_nodes==get_node_count() and world.is_inside_tree() and world.get_tree()==self
		var candidates: Array=_area_graphics_lights.values() if use_census else world.find_children("*","Light3D",true,false)
		for candidate in candidates:
			if not is_instance_valid(candidate) or use_census and not world.is_ancestor_of(candidate):continue
			var light:=candidate as Light3D
			if light==null or not light.shadow_enabled or not light.is_visible_in_tree():continue
			if is_instance_valid(camera) and (light.layers&camera.cull_mask)==0:continue
			if light is OmniLight3D:shadows[0]+=1
			elif light is SpotLight3D:shadows[1]+=1
			elif light is DirectionalLight3D:shadows[2]+=1
		if use_census:
			FrameProfile.finish("area_graphics_profile_live_lights_ms",began)
			FrameProfile.count("count_area_graphics_profile_live_reads",1)
		else:
			FrameProfile.finish("area_graphics_profile_tree_lights_ms",began)
			FrameProfile.count("count_area_graphics_profile_tree_queries",1)
		FrameProfile.count("count_area_graphics_profile_light_candidates",candidates.size())
	var tone: Variant=null
	var fog: Variant=null
	if is_instance_valid(environment) and environment.environment!=null:
		tone=int(environment.environment.tonemap_mode)
		if environment.environment.fog_enabled:fog=int(environment.environment.fog_mode)
	var environment_identity: Variant=null
	if is_instance_valid(world) and is_instance_valid(world.model_environment) and world.model_environment.map_ready:
		environment_identity=[str(world.model_environment.selected),int(world.model_environment.publications)]
	# Shadow-map algorithm, output color space and global clipping plane count
	# are not exposed as equivalents of Three's renderer fields.
	return [slots,shadows,null,null,tone,fog,environment_identity,null]
func native_snapshot_transition_waiting() -> bool:return false
func _initialize() -> void:
	# Launchers select the secondary screen before the native window is created.
	# Recheck the current topology for direct entry and display hot-plug changes.
	if DisplayServer.get_name()!="headless":
		var primary:=DisplayServer.get_primary_screen()
		# Preserve an engine-selected secondary monitor. Only replace a primary
		# startup position; otherwise --screen was silently overridden here.
		if root.current_screen==primary:
			for screen in DisplayServer.get_screen_count():
				if screen!=primary:
					root.current_screen=screen
					break
	call_deferred("run")
func run() -> void:
	auto_accept_quit=false
	area_graphics.profile_provider=Callable(self,"native_area_graphics_profile")
	if not OS.get_cmdline_user_args().has("--area-graphics-light-profile=tree"):_begin_area_graphics_light_census()
	if not root.close_requested.is_connected(shutdown):root.close_requested.connect(shutdown)
	if not root.window_input.is_connected(toggle_performance_input):root.window_input.connect(toggle_performance_input)
	if not RenderingServer.frame_post_draw.is_connected(record_render_frame):RenderingServer.frame_post_draw.connect(record_render_frame)
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	direct_mode=OS.get_cmdline_user_args().has("--direct-session") or args.get("direct-session","")=="true"
	if direct_mode and not args.has("report"):
		args.report=ProjectSettings.globalize_path("user://nwn79-direct-"+str(OS.get_process_id())+"-"+str(Time.get_ticks_msec())+".json")
	creation_runtime.configure(args)
	if not args.has("report") or not direct_mode and not args.has("ticket") or FileAccess.file_exists(args.report): quit(2); return
	# The engine creates its main window non-activating (project.godot).
	# Keep it non-activating until the user clicks the actual game window.
	# Automated checks never activate it, including synthetic GUI probes.
	if args.get("settings-check","")!="true" and args.get("actions-check","")!="true" and not root.window_input.is_connected(activate_window_from_click): root.window_input.connect(activate_window_from_click)
	if direct_mode:
		var selector_source=preload("res://systems/native_install_selector.gd")
		var explicit_install:=str(args.get("direct-install",""))
		if not explicit_install.is_empty() and not selector_source.valid_install(explicit_install):fail("NWN installation is unavailable or missing game data");return
		var install:=explicit_install
		if install.is_empty():
			var settings_directory:=str(args.get("direct-settings",OS.get_environment("APPDATA").path_join("nwn-model-viewer-research")))
			var install_settings=preload("res://systems/native_data/client_settings_store.gd").new()
			if not install_settings.open(settings_directory):fail("Godot settings could not open: "+install_settings.error);return
			install=selector_source.candidate("",str(install_settings.state.get("installDirectory","")),ProjectSettings.globalize_path("res://../../FullDecomp/NwnRootInstall"))
			if install.is_empty():
				if DisplayServer.get_name()=="headless":install_settings.close();fail("NWN installation is unavailable; launch graphically to choose its folder or pass --direct-install");return
				var selector=selector_source.new();root.add_child(selector);selector.begin()
				selector.chosen.connect(func(path: String):
					selector.queue_free();install_settings.close();args["direct-install"]=path;args["direct-install-to-save"]=path
					if not closing:call_deferred("run"),CONNECT_ONE_SHOT)
				return
			install_settings.close()
		args["direct-install"]=install
		ticket=StartupPaths.direct_ticket(install,str(args.get("direct-profile","")),str(args.get("direct-settings","")))
		if ticket.has("error"):
			report.failure=str(ticket.error)
			var startup_file:=FileAccess.open(str(args.report),FileAccess.WRITE)
			if startup_file!=null:startup_file.store_string(JSON.stringify(report));startup_file.close()
			quit(2);return
	else:
		ticket=JSON.parse_string(FileAccess.get_file_as_string(args.ticket))
		if ticket.get("host")!="127.0.0.1" or not ticket.get("port") is float or str(ticket.get("token","")).length()!=64: quit(2); return
	if not runtime_feature_report.configure(OS.get_cmdline_user_args(),ticket.get("featureSelection",{})):
		report.failure="Native startup feature validation failed";report.runtime_features=runtime_feature_report.snapshot()
		var failure_file:=FileAccess.open(str(args.report),FileAccess.WRITE)
		if failure_file!=null:failure_file.store_string(JSON.stringify(report));failure_file.close()
		quit(2);return
	# Keep cache disposal off transient world/menu close paths. The application
	# releases this lease only after every asset owner has joined at shutdown.
	if GameplayUi.Assets.CacheWrites.configured_enabled(): GameplayUi.Assets.CacheWrites.acquire(); prepared_write_session_lease=true
	host=Node3D.new(); root.add_child(host); var canvas:=CanvasLayer.new(); host.add_child(canvas); label=Label.new(); canvas.add_child(label); label.position=Vector2(12,12); label.add_theme_color_override("font_shadow_color",Color.BLACK); label.add_theme_constant_override("shadow_offset_x",2); label.add_theme_constant_override("shadow_offset_y",2); label.text="Opening native Prelude renderer…"
	# src/main.js installs model_light.js's quadratic/ambient-only shader
	# adapter unconditionally. The old ordinary client therefore selects the
	# legacy response; explicit enhanced and Godot modes remain available.
	var lighting_mode:=str(args.get("native-lighting",""))
	if lighting_mode.is_empty():lighting_mode="legacy"
	render_pool.native_lighting=lighting_mode in ["legacy","enhanced"]
	render_pool.native_legacy_lighting=lighting_mode=="legacy"
	gamma_controller=preload("res://systems/native_render/native_gamma.gd").new(); host.add_child(gamma_controller)
	native_output_settings=preload("res://systems/native_render/native_scene_output.gd").options(args,OS.get_cmdline_user_args().has("--native-light-history"))
	if native_output_settings.has("error"):
		report.failure=native_output_settings.error; call_deferred("shutdown"); return
	render_pool.native_surface_output=bool(native_output_settings.enabled)
	if render_pool.native_surface_output:
		gamma_controller.effect.set_surface_output(true)
		native_output=preload("res://systems/native_render/native_scene_output.gd").new(); host.add_child(native_output)
	if args.has("native-gamma") and str(args["native-gamma"]).is_valid_float(): gamma_controller.set_gamma(float(args["native-gamma"]))
	if render_pool.native_lighting: host.add_child(preload("res://systems/native_render/native_light_palette.gd").new())
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
	native_clock_startup()
	if not direct_mode and peer.connect_to_host("127.0.0.1",int(ticket.port))!=OK: fail("Local protocol peer is unavailable"); return
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
	var write_error: int=protocol_output.enqueue(encoded,"observed" if value.get("kind","")=="observed" else ""); FrameProfile.finish("protocol_enqueue",began)
	if write_error!=OK:
		report.protocol_write_error={"error":write_error,"bytes":encoded.size(),"ticks_ms":Time.get_ticks_msec(),"status":peer.get_status()}
		creation_runtime.event("protocol:enqueue-error",report.protocol_write_error)
func flush_protocol_output() -> void:
	if peer.get_status()!=StreamPeerTCP.STATUS_CONNECTED: return
	var began:=FrameProfile.begin(); var result: int=protocol_output.flush(Callable(peer,"put_partial_data")); FrameProfile.finish("protocol_write",began)
	if result!=OK:
		report.protocol_write_error={"error":result,"queue":protocol_output.snapshot(),"ticks_ms":Time.get_ticks_msec(),"status":peer.get_status()}
		creation_runtime.event("protocol:write-error",{"error":result,"queued_bytes":protocol_output.queued_bytes,"ticks_ms":Time.get_ticks_msec(),"status":peer.get_status()})
		if not closing: fail.call_deferred("Local protocol output failed")
var creation_trace_sequence:=0
func creation_runtime_values() -> Dictionary:
	var value: Dictionary={"frame":Engine.get_process_frames(),"ticks_ms":Time.get_ticks_msec(),"epoch":epoch,"status":peer.get_status(),"queued_bytes":protocol_output.queued_bytes,"received":received,"closing":closing,"initialized":initialized,"acknowledged":finish_acknowledged}
	if is_instance_valid(world):
		value.entities=world.instances.size();value.desired=world.desired.size();value.pending_batches=world.batches.size();value.hidden=world.hidden.size();value.failed=world.failed_objects.size()
		value.world_closed=world.closed;value.world_retiring=world.retiring;value.world_processing=world.is_processing()
	return value
func creation_runtime_phase(stage: String) -> void:
	if creation_runtime.enabled:creation_runtime.phase(stage,creation_runtime_values())
func creation_trace(stage: String) -> void:
	if args.get("creation-phase-trace","")!="true" or args.get("settings-check","")!="true" or creation_trace_sequence>=128:return
	var destination: String=str(args.get("report",""))+".phases.jsonl"
	if creation_trace_sequence==0 and FileAccess.file_exists(destination):report.creation_phase_failure="Existing owned diagnostic phase file retained";return
	var file:=FileAccess.open(destination,FileAccess.WRITE if creation_trace_sequence==0 else FileAccess.READ_WRITE)
	if file==null:report.creation_phase_failure="Cannot write owned diagnostic phase file";return
	creation_trace_sequence+=1
	var value: Dictionary={"kind":"creation-native-phase","phase":stage,"sequence":creation_trace_sequence,"ticks_ms":Time.get_ticks_msec(),"epoch":epoch}
	file.seek_end();file.store_line(JSON.stringify(value));file.flush();file.close()
	send(value)
func install_mounted_catalog(prepared: RefCounted,install: String,sources: Dictionary,recording_directory: String="") -> bool:
	# The Godot network session already mounted these exact admitted sources.
	# Its direct handoff reuses this UI owner instead of remounting or serializing
	# the catalog through a local Node.js protocol.
	if closing or initialized or is_instance_valid(gameplay_ui) or not is_instance_valid(host) or not is_instance_valid(loading_screen) or prepared==null or not prepared.has_method("get_resource"):
		return false
	catalog=prepared
	if not recording_directory.is_empty():
		var recorder:=preload("res://systems/native_data/resource_recording.gd").new()
		var talk_files:={"base":install.path_join("lang/en/data/dialog.tlk"),"female":install.path_join("lang/en/data/dialogf.tlk")}
		if sources.get("customTlk") is Dictionary and sources.customTlk.get("path") is String:
			talk_files.custom=sources.customTlk.path; talk_files.custom_female=str(sources.customTlk.path).trim_suffix(".tlk")+"f.tlk"
		if not recorder.start(recording_directory,catalog.layers,talk_files):fail("Native resource recording could not start");return false
		catalog.recording=recorder; resource_recordings.append(recorder)
	# Match the old active resolver after recording has attached to the layers.
	if not TargetPreviewShader.load_profile(catalog):
		# The original network onArea attaches WorldPointerView after installing
		# the area root and reports an unavailable inc_target source here.
		native_model_diagnostic({"code":"target.preview-load-failed","message":str(TargetPreviewShader.source_profile.get("error","Native target preview shader is unavailable")),"detail":{}})
	var ui_configure_began:=Time.get_ticks_msec()
	gameplay_ui=GameplayUi.new(); host.add_child(gameplay_ui)
	gameplay_ui.configure(catalog,install,ProjectSettings.globalize_path(str(args.get("prepared-cache","user://native-prepared-v2"))),str(args.get("menu-layout","user://native-menu-layout.cfg")),sources.customTlk if sources.get("customTlk") is Dictionary else {})
	gameplay_ui.creator.capture_changed.connect(native_creator_capture)
	gameplay_ui.world_camera=camera; gameplay_ui.world_registry=registry
	gameplay_ui.native_connection_query=native_text_connection;gameplay_ui.overhead_anchor_query=native_text_anchor
	gameplay_ui.script_floating_anchor_query=native_script_floating_anchor;gameplay_ui.script_floating_object_delta_query=native_script_floating_object_delta
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
	creation_trace("setup:configured")
	initialized=true
	return true

func receive(message: Dictionary) -> void:
	if closing and message.get("kind")!="finish-ack": return
	match str(message.get("kind","")):
		"finish-ack":
			finish_acknowledged=true
			if creation_runtime.enabled:creation_runtime.event("finish:ack-received",creation_runtime_values())
		"setup":
			creation_trace("setup:received")
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
			report.native_catalog=mounted.stats
			print("NATIVE_SESSION_CATALOG_READY mount_ms=",mounted.stats.get("mount_ms",-1)," ticks_ms=",Time.get_ticks_msec())
			if not install_mounted_catalog(mounted.catalog,install,sources,str(message.get("recordingDirectory",""))):return
			send({"kind":"catalog-ready","layers":catalog.layers.size()})
		"ui-protocol":
			# SessionWorld has already admitted this outer connection. The base
			# entry has no accepted connection and retains its legacy UI route.
			if is_instance_valid(gameplay_ui): gameplay_ui.receive(message.message,int(message.generation),message.get("connection") if native_text_connection()!=null else null)
		"snapshot":
			creation_trace("snapshot:received")
			if not initialized or int(message.generation)<epoch: return
			var data: Dictionary=message.data
			if is_instance_valid(world): world.minutes_per_hour=int(data.get("module",{}).get("minutesPerHour",5))
			if int(message.generation)!=epoch:
				creation_trace("snapshot:transition-begin")
				gameplay_ui.set_gameplay_visible(false)
				begin_renderer_retirement()
				var transition_began:=FrameProfile.begin()
				if is_instance_valid(world):
					report.retired_areas=report.get("retired_areas",[]); report.retired_areas.append(world.snapshot())
					camera_memory=controller.remembered_pose()
				FrameProfile.finish("transition_old_snapshot",transition_began); transition_began=FrameProfile.begin()
				if is_instance_valid(keyboard): keyboard.stop(false); keyboard.queue_free()
				for owned in [world_input,hud,registry]:
					if is_instance_valid(owned): owned.process_mode=Node.PROCESS_MODE_DISABLED; owned.queue_free()
				if is_instance_valid(world): world_retirement.retire(world)
				area_graphics.retire()
				if is_instance_valid(environment): environment.queue_free()
				FrameProfile.finish("transition_retire_begin",transition_began); transition_began=FrameProfile.begin()
				epoch=int(message.generation); acknowledged=-1; initial_controlled=null; entry_camera=preload("res://systems/native_render/entry_camera.gd").new(); walkmesh_registered=false; presentation_stats={}; stats_at=0
				loading_screen.begin(epoch,str(data.area.get("resRef",module_name)),data.get("entry",{}))
				world=World.new();world.visual_world_timer=native_model_world_timer();world.tile_borders_enabled=native_tile_borders_enabled(); world.set_meta("native_enhanced_lighting",render_pool.native_lighting);world.set_meta("native_area_graphics_owner",area_graphics);world.camera_pre_motion=Callable(self,"native_camera_anchor_early").bind(world,epoch);world.camera_post_motion=Callable(self,"native_camera_post_motion").bind(world,epoch)
				world.set_meta("native_model_diagnostic",Callable(self,"native_model_diagnostic"))
				world.set_meta("native_entry_loading",true)
				if render_pool.scenery_publication_budget_us>render_pool.publication_budget_us:world.set_meta("native_publication_loading",true)
				# Absence is the established ordinary-world contract. In particular,
				# emitter ancestor lookup must not acquire a new scope on rollback.
				if render_pool.native_surface_output: world.set_meta("native_surface_output",true)
				creation_trace("snapshot:world-open-before")
				world.entry_prefetch_enabled=args.get("entry-prefetch","")!="false"; world.minutes_per_hour=int(data.get("module",{}).get("minutesPerHour",5)); world.use_skeleton=args.get("skeleton","")=="true"; host.add_child(world); world.open(catalog,data.area,epoch,ProjectSettings.globalize_path(str(args.get("prepared-cache","user://native-prepared-v2"))),render_pool,data.get("entry",{}))
				native_material_policy_ready()
				creation_trace("snapshot:world-open-after")
				FrameProfile.finish("transition_world_open",transition_began)
				transition_began=FrameProfile.begin()
				creation_trace("snapshot:camera-before")
				if camera==null:
					camera=Camera3D.new(); host.add_child(camera); camera.near=0.1; camera.far=150; camera.current=true; camera.position=Vector3(0,15,15)
					gamma_controller.attach(camera)
					controller=CameraController.new(); host.add_child(controller); controller.configure(camera,Vector3.ZERO); controller.orbit_admission=native_camera_orbit_allowed;controller.key_admission=native_camera_keys_allowed;controller.pointer_admission=native_camera_pointer_allowed;controller.focus_request=Callable(self,"native_focus_player_camera")
				keyhole=CameraKeyhole.new();world.add_child(keyhole);keyhole.configure(world.terrain,camera,controller,catalog)
				if keyhole.blocked:native_model_diagnostic({"code":"camera.keyhole-load-failed","message":str(preload("res://systems/native_render/native_camera_keyhole.gd").source_profile.get("error","Native keyhole shader is unavailable")),"detail":{},"severity":"error"})
				controller.keyboard_pan=false
				creation_trace("snapshot:registry-hud-before")
				FrameProfile.finish("transition_camera_setup_ms",transition_began);transition_began=FrameProfile.begin()
				registry=Registry.new(); host.add_child(registry); gameplay_ui.world_camera=camera; gameplay_ui.world_registry=registry
				registry.configure_highlight_assets(world.references.assets,catalog,world.pool)
				gameplay_ui.world_camera_yaw=func(): return controller.follow_state.quaternion_yaw(controller.follow_state.state.quaternion) if controller.follow_state!=null else NAN
				transition_targets=preload("res://systems/native_render/transition_targets.gd").new(); world.add_child(transition_targets); transition_targets.configure(registry,world.area_id)
				bind_scenery_picking()
				hud=Hud.new(); host.add_child(hud); hud.configure(registry,camera); hud.enable_live_mode(); hud.metrics.hide()
				hud.bind_gameplay(gameplay_ui)
				hud.instructions.text="Middle drag: orbit · wheel: zoom\nW/S: forward/back · A/D: turn · Q/E: strafe\nShift: walk · left click: move, talk, use or pick up\nHold Tab: highlights · right click: examine\nFull gameplay menus and effects pending."
				hud.examine_requested.connect(func(id): send({"kind":"examine","generation":epoch,"areaId":world.area_id,"targetId":id}))
				creation_trace("snapshot:registry-hud-after-input-before")
				FrameProfile.finish("transition_registry_hud_ms",transition_began);transition_began=FrameProfile.begin()
				bind_world_input()
				var hover_presentation=preload("res://systems/native_render/world_hover_presentation.gd").new();world.add_child(hover_presentation);hover_presentation.configure(world,registry);world_input.hover_presentation=hover_presentation.select
				world_input.extra_pointer_block=native_world_pointer_blocked; world_input.context_action=gameplay_ui.desktop.open_radial
				world_input.cursor_action=gameplay_ui.mouse_cursor.world_pointer
				world.instance_ready.connect(instance_ready)
				world.instance_state_changed.connect(func(id,source): instance_ready(id,source,world.instances[id]))
				world.instance_removed.connect(func(id):
					if registry.forget_entity(id): hud.queue_refresh_entities())
				creation_trace("snapshot:input-after-keyboard-before")
				keyboard=Keyboard.new(); host.add_child(keyboard); keyboard.context_query=keyboard_context; keyboard.enabled_query=native_keyboard_enabled; keyboard.transmit=player_command; keyboard.predict=world.preview_drive; keyboard.end_prediction=world.end_drive; world.preview_token=keyboard.preview_token; world.preview_completed=keyboard.complete_async_preview
				world_input.clear_movement=func():
					if is_instance_valid(keyboard):keyboard.stop()
				keyboard.set_key_bindings(gameplay_ui.key_bindings); world_input.set_key_bindings(gameplay_ui.key_bindings); controller.set_key_bindings(gameplay_ui.key_bindings)
				keyboard.set_frame_input_admission(bool(ProjectSettings.get_setting("nwn/private/keyboard_frame_admission",true)))
				var budget:=Lights.new(); world.add_child(budget); budget.camera=camera; budget.maximum=int(args.get("native-shadow-lights",3))
				budget.focus_query=world.shadow_focus
				world.set_meta("native_point_shadow_budget",weakref(budget))
				creation_trace("snapshot:keyboard-after-environment-before")
				FrameProfile.finish("transition_input_keyboard_ms",transition_began);transition_began=FrameProfile.begin()
				environment=AreaEnvironment.new(); host.add_child(environment); environment.configure({},world); environment.camera=camera; environment.controller=controller
				if is_instance_valid(native_output): native_output.bind(world,environment,gamma_controller,native_output_settings)
				FrameProfile.finish("transition_environment_bind_ms",transition_began)
			var header_began:=FrameProfile.begin()
			report.environment_accepted=publish_area_environment(data,int(message.generation))
			FrameProfile.finish("snapshot_environment_header_ms",header_began)
			creation_trace("snapshot:environment-after")
			var state_began:=FrameProfile.begin()
			var lights_began:=FrameProfile.begin()
			if is_instance_valid(world.placeable_lights): world.placeable_lights.receive_area(data.area.get("placeableLights",[]))
			FrameProfile.finish("snapshot_placeable_lights_ms",lights_began)
			if str(data.get("bridgeMode","full"))=="delta":
				var removed: Array=data.get("removedObjectIds",[])
				world.receive_delta(data.objects,removed,int(data.controlledId))
				var ui_began:=FrameProfile.begin(); gameplay_ui.update_world(epoch,world.area_id,int(data.controlledId),data.objects,removed,data.get("inventory",{}),data); FrameProfile.finish("snapshot_ui_apply",ui_began)
			else:
				var world_began:=FrameProfile.begin()
				creation_trace("snapshot:world-receive-before")
				if not snapshot_metadata.is_empty() and is_same(snapshot_metadata_objects,data.objects):world.stage_received_metadata(data.objects,snapshot_metadata)
				world.receive(data.objects,int(data.controlledId))
				creation_trace("snapshot:world-receive-after")
				FrameProfile.finish("snapshot_world_apply",world_began)
				var ui_began:=FrameProfile.begin()
				creation_trace("snapshot:gameplay-set-world-before")
				gameplay_ui.set_world(epoch,world.area_id,int(data.controlledId),data.objects,data.get("inventory",{}),data)
				creation_trace("snapshot:gameplay-set-world-after")
				FrameProfile.finish("snapshot_ui_apply",ui_began)
			FrameProfile.finish("snapshot_world_and_ui_apply",state_began)
			var post_began:=FrameProfile.begin()
			if is_instance_valid(world.point_wind): world.point_wind.set_area(data.area.get("fields",{}))
			if data.get("ui",{}).has("players"): world.effects.creature_voices.set_players(data.ui.players)
			FrameProfile.finish("snapshot_wind_voice_ms",post_began)
			creation_trace("snapshot:transition-targets-before")
			post_began=FrameProfile.begin()
			if transition_targets.receive(data.objects,data.get("removedObjectIds",[]),str(data.get("bridgeMode","full"))=="delta"): hud.queue_refresh_entities()
			FrameProfile.finish("snapshot_transition_targets_ms",post_began)
			creation_trace("snapshot:transition-targets-after-combat-before")
			post_began=FrameProfile.begin()
			flush_combat()
			FrameProfile.finish("snapshot_flush_combat_ms",post_began)
			creation_trace("snapshot:combat-after")
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
		"finish":
			if creation_runtime.enabled:creation_runtime.event("finish:received",creation_runtime_values())
			shutdown()
		"failure": fail(str(message.get("reason","Local protocol session failed")))
func publish_area_environment(data: Dictionary,generation_value: int) -> bool:
	# SessionWorld admits the outer connection before this snapshot boundary.
	# Keep authored atmosphere/time in its existing owner during a long stay,
	# not just on area entry. No per-frame header scan or new world store.
	if closing or not is_instance_valid(world) or world.closed or world.retiring or not is_instance_valid(environment):return false
	if generation_value!=epoch or world.generation!=epoch or not data.get("area") is Dictionary or not data.area.get("fields") is Dictionary:return false
	if not preload("res://systems/native_data/overhead_speech_scope.gd").integer(data.area.get("id"),0,4294967295) or int(data.area.id)!=world.area_id:return false
	if environment.lighting_world==null or environment.lighting_world.get_ref()!=world:return false
	var owner_scope: Array=[native_text_connection(),world.get_instance_id(),epoch,world.area_id,environment.get_instance_id()]
	if environment.has_meta("native_header_scope") and environment.get_meta("native_header_scope")!=owner_scope:return false
	if not data.get("time") is Dictionary or not data.get("module") is Dictionary:return false
	var time: Dictionary=data.time
	if not preload("res://systems/native_data/overhead_speech_scope.gd").integer(time.get("timeOfDay"),0,4) or not preload("res://systems/native_data/overhead_speech_scope.gd").integer(time.get("transition"),0,4294967295):return false
	var minutes: Variant=data.module.get("minutesPerHour")
	if not (minutes is int or minutes is float) or not is_finite(float(minutes)) or float(minutes)<=0:return false
	var fields: Dictionary={}
	for key in ["98","9c","a0","a4","a8","ac","b0","b4","b8","bc","c0","c4","c8","cc","d0","d4","d8","dc","e0","104","108"]:
		if not data.area.fields.has(key):continue
		var value: Variant=data.area.fields[key]
		if value is bool:fields[key]=1 if value else 0
		elif (value is int or value is float) and is_finite(float(value)):fields[key]=value
		else:return false
	var phase: Dictionary={"timeOfDay":int(time.timeOfDay),"transition":int(time.transition)}
	var same_phase: bool=not environment.source.is_empty() and environment.source.get("time")==phase
	var state: Dictionary={"fields":fields,"time":phase,"minutesPerHour":float(minutes),"elapsed":environment.source.elapsed if same_phase else float(time.transition)/1000.0}
	# source.elapsed is the last received origin, not the advancing GUI clock.
	# Unchanged/full/calendar-only snapshots must not restart interpolation.
	if environment.source==state:return true
	if same_phase:state.elapsed=environment.elapsed
	var accepted: bool=environment.receive({"revision":maxi(0,environment.revision)+1,"state":state})
	if accepted:environment.set_meta("native_header_scope",owner_scope)
	return accepted
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
func toggle_performance_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_F3 and event.ctrl_pressed and event.alt_pressed and is_instance_valid(hud):hud.toggle_performance()
func record_render_frame() -> void:
	if closing or not is_instance_valid(hud):return
	var shown: bool=root.visible
	if DisplayServer.get_name()!="headless":shown=shown and DisplayServer.window_get_mode(root.get_window_id())!=DisplayServer.WINDOW_MODE_MINIMIZED
	var frame: Dictionary={"at":Time.get_ticks_usec()/1000.0,"visible":shown,"rendered":shown,"details":{"draw":{"calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"triangles":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)},"viewport":{"width":root.size.x,"height":root.size.y}}}
	if is_instance_valid(world) and is_instance_valid(world.focus_lighting):
		var admission: Dictionary=world.focus_lighting.renderer_result
		if not admission.is_empty():frame.details.lighting={"selection":{"admitted":int(admission.admitted)}}
	if is_instance_valid(world):
		var budget_reference: WeakRef=world.get_meta("native_point_shadow_budget",null)
		var budget: Variant=budget_reference.get_ref() if budget_reference!=null else null
		if is_instance_valid(budget):
			if not frame.details.has("lighting"):frame.details.lighting={}
			frame.details.lighting.shadows={"admitted":budget.active,"requested":budget.eligible}
	hud.record_performance(frame)
func _profile_tick() -> void:
	if closing: return
	native_clock_prefix()
	if closing:return
	if creation_runtime.enabled:creation_runtime.begin_frame(creation_runtime_values())
	var phase_began:=FrameProfile.begin()
	var poll_error:=OK
	if not direct_mode:poll_error=peer.poll()
	creation_runtime_phase("frame:poll-after")
	if not direct_mode and peer.get_status()==StreamPeerTCP.STATUS_CONNECTED:
		if not authenticated: authenticated=true; send({"kind":"hello","token":ticket.token,"runtimeFeatures":runtime_features_snapshot()}); ticket.clear()
		var count:=peer.get_available_bytes()
		if count>0:
			var decode_began:=FrameProfile.begin()
			var chunk:=peer.get_data(mini(count,1048576))
			if int(chunk[0])!=OK:
				report.protocol_read_error={"error":int(chunk[0]),"expected":count,"bytes":chunk[1].size(),"ticks_ms":Time.get_ticks_msec(),"status":peer.get_status()}
				creation_runtime.event("protocol:read-error",report.protocol_read_error)
			var messages:=frames.feed(chunk[1])
			FrameProfile.finish("protocol_read_decode",decode_began)
			decode_began=FrameProfile.begin()
			dispatch_protocol_messages(messages,frames.last_frame_sizes)
			FrameProfile.finish("protocol_apply",decode_began)
			if not frames.failure.is_empty(): fail(frames.failure); return
	elif not direct_mode and authenticated:
		report.protocol_disconnect={"poll_error":poll_error,"status":peer.get_status(),"ticks_ms":Time.get_ticks_msec()}
		creation_runtime.event("protocol:disconnect",report.protocol_disconnect)
		fail("Local protocol session disconnected"); return
	# Complete one admitted OS-key burst after protocol changes and before output.
	if is_instance_valid(keyboard) and keyboard.frame_input_admission and keyboard.can_process():keyboard.flush_input_frame()
	if not direct_mode:flush_protocol_output()
	creation_runtime_phase("frame:protocol-after")
	FrameProfile.finish("root_protocol",phase_began)
	native_clock_post_receive()
	if closing or not is_instance_valid(world) or native_snapshot_transition_waiting(): return
	var now:=Time.get_ticks_usec()
	if previous>0:
		samples.append((now-previous)/1000.0)
		if interactive and samples.size()>4096: samples=samples.slice(2048)
	previous=now
	if presentation_stats.is_empty() or now-stats_at>100000:
		creation_runtime_phase("frame:stats-before")
		phase_began=FrameProfile.begin()
		presentation_stats=preload("res://systems/native_render/presentation_counters.gd").capture(world); stats_at=now
		FrameProfile.finish("root_stats",phase_began)
		label.text="%.1f FPS · Native Godot · %s · %s\n%d/%d entities · %d/%d tiles · %d pending batches\n%d meshes · %d textures	\nMiddle drag: orbit · wheel: zoom · Tab: highlights" % [Engine.get_frames_per_second(),module_name,server_label,presentation_stats.entities,presentation_stats.desired,presentation_stats.terrain.get("rendered_tiles",0),presentation_stats.terrain.get("tiles",0),presentation_stats.pending_batches,presentation_stats.pool.meshes_created,presentation_stats.pool.textures_created]
		if not presentation_stats.failed_objects.is_empty(): label.text+="\n%d object visuals failed · details retained in diagnostics"%presentation_stats.failed_objects.size()
	var state: Dictionary=presentation_stats
	creation_runtime_phase("frame:stats-after")
	if not walkmesh_registered and is_instance_valid(world.surface) and world.surface.ready(): registry.register_walkmesh(world.surface); walkmesh_registered=true
	var load_errors: Array=[]
	for failure in state.errors: load_errors.append(str(failure))
	for failure in world.terrain.diagnostics.get("errors",[]): load_errors.append(str(failure))
	if is_instance_valid(world.surface) and world.surface.done and world.surface.table.is_empty():
		for failure in world.surface.stats.errors:
			if str(failure.get("resource",""))=="@surfacemat":load_errors.append(str(failure.get("reason","Native surface table is unavailable")))
	var anchored: bool=initial_controlled!=null and world.instances.has(world.controlled_id) and controller.follow_valid(world.instances[world.controlled_id].position)
	loading_screen.advance(epoch,{"terrain":world.ready_for_admission(),"player":world.ready_for_control(),"camera":anchored,"tiles":world.terrain.completed_tiles,"total_tiles":world.terrain.definition.get("tiles",[]).size(),"errors":load_errors})
	complete_native_entry_loading(load_errors)
	if render_pool.scenery_publication_budget_us>render_pool.publication_budget_us:complete_native_publication_loading(load_errors)
	gameplay_ui.set_gameplay_visible(gameplay_presentation_allowed())
	creation_runtime_phase("frame:loading-after")
	if not load_errors.is_empty(): report.area_loading_error=load_errors
	if state.admission_ready and acknowledged!=epoch and area_graphics_failed_epoch!=epoch:
		var graphics_gate: Dictionary=native_area_graphics_gate()
		if graphics_gate.has("error"):
			area_graphics_failed_epoch=epoch
			native_area_graphics_failed(str(graphics_gate.error));return
		if bool(graphics_gate.get("ready",false)):
			# The original onArea configures shadow-casting lights in its loaded
			# root once. Preserve the first full population's pending model identity
			# alongside the lights already present at this gate.
			world.capture_initial_shadow_membership(epoch)
			world.set_meta("native_area_model_shadow_capture_epoch",epoch)
			# The normal direct session releases this transition after the first
			# scene-delivery update settles (main.js onUpdates), not at area ACK.
			if direct_mode:finish_area_graphics_hold()
			else:finish_renderer_retirement()
			acknowledged=epoch; send({"kind":"area-ready","generation":epoch,"areaId":world.area_id})
	if Time.get_ticks_msec()-observed_at>500:
		observed_at=Time.get_ticks_msec()
		if not direct_mode:
			send({"kind":"observed","generation":epoch,"areaId":world.area_id,"state":world.snapshot(false),"area_graphics_preparation":area_graphics.snapshot(),"ui_startup":gameplay_ui.startup_snapshot() if is_instance_valid(gameplay_ui) else {},"protocol_output":protocol_output.snapshot(),"record_selection":gameplay_ui.desktop.sheet.selection_timings.duplicate() if is_instance_valid(gameplay_ui) and is_instance_valid(gameplay_ui.desktop) else {},"controlledDistance":maximum_distance,"fps":Engine.get_frames_per_second(),"frame_profile":frame_profile.snapshot() if is_instance_valid(frame_profile) else {}})
		if interactive and str(args.get("capture-preview","false"))=="true" and DisplayServer.get_name()!="headless" and state.ready and state.pending_batches==0 and not preview_captured:
			preview_captured=true; capture_preview.call_deferred()
	creation_runtime_phase("frame:end")
func gameplay_presentation_allowed() -> bool:
	# Readiness gates the first reveal. Later appearance/reference preparation
	# must not hide an admitted HUD or steal text focus. New epochs explicitly
	# hide the canvases before opening their world, so this latch cannot cross
	# an area boundary. Server phase/connection gates remain in the session owner.
	return not closing and is_instance_valid(world) and (gameplay_ui.presentation_enabled or world.ready_for_control()) and not loading_screen.blocks_input()
func native_camera_keys_allowed() -> bool:
	if not gameplay_presentation_allowed() or graphics_pending:return false
	if is_instance_valid(gameplay_ui.creator) and gameplay_ui.creator.phase!="closed":return false
	return true
func native_keyboard_enabled() -> bool:
	# The old NetworkKeyboardInput.enabled callback is independent of the
	# dialog, inventory and panel OrbitControls visibility callbacks.
	return native_camera_keys_allowed() and is_instance_valid(world) and world.ready_for_control()
func native_camera_orbit_allowed() -> bool:
	return native_camera_keys_allowed()
func native_camera_pointer_allowed(point: Vector2) -> bool:
	return native_camera_keys_allowed() and (not is_instance_valid(gameplay_ui) or not is_instance_valid(gameplay_ui.desktop) or not gameplay_ui.desktop.blocks_pointer(point))
func native_creator_capture(_captured: bool) -> void:
	# CharacterFrontend.onCapture runs at both open and finish boundaries.
	if is_instance_valid(keyboard):keyboard.stop()
	if is_instance_valid(world_input):
		world_input.left_press.clear()
		world_input.pending_button=0
		world_input.highlight_pointer_active=false
	if is_instance_valid(gameplay_ui) and is_instance_valid(gameplay_ui.desktop):
		gameplay_ui.desktop.retire_shortcut_context()
func native_world_pointer_blocked(point: Vector2) -> bool:
	if closing or graphics_pending or native_snapshot_transition_waiting():return true
	if is_instance_valid(loading_screen) and loading_screen.blocks_input():return true
	if not is_instance_valid(gameplay_ui) or not gameplay_ui.presentation_enabled:return true
	if is_instance_valid(gameplay_ui.creator) and gameplay_ui.creator.phase!="closed":return true
	if gameplay_ui.blocks_world_pointer_globally():return true
	return gameplay_ui.blocks_pointer(point)
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
		if child.get_script()==Lights: child.maximum=0 if mode=="no-point-shadows" else int(args.get("native-shadow-lights",3))
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
	var replicated: Variant=object.get("replicated")
	if not replicated is Dictionary:return {}
	var position: Variant=replicated.get("position")
	if not position is Array or position.size()!=3:return {}
	for value in position:
		if not (value is int or value is float) or not is_finite(float(value)):return {}
	var orientation: Variant=replicated.get("orientation")
	if orientation is Dictionary:
		if orientation.get("vector") is Array:orientation=orientation.vector
		elif (orientation.get("yaw") is int or orientation.get("yaw") is float) and is_finite(float(orientation.yaw)):
			var angle:=float(orientation.yaw)*PI/180.0
			orientation=[-sin(angle),cos(angle),0.0]
	if not orientation is Array or orientation.size()<2:return {}
	for value in orientation:
		if not (value is int or value is float) or not is_finite(float(value)):return {}
	return {"identity":"%s/%s/%s/%s/%s"%[world.get_instance_id(),epoch,world.area_id,world.controlled_id,state.lifetime],"id":world.controlled_id,"state":state,"position":state.render}
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
func bind_scenery_picking()->void:
	if not is_instance_valid(registry) or not is_instance_valid(world) or not is_instance_valid(world.terrain):return
	var current_registry=registry
	var current_terrain=world.terrain
	for index in current_terrain.instances:
		var tile: Variant=current_terrain.instances[index]
		if tile is Node3D:current_registry.register_scenery("tile:"+str(index),tile)
	current_terrain.tile_published.connect(func(index: int,instance):
		if is_instance_valid(current_registry) and is_same(registry,current_registry) and is_instance_valid(world) and is_same(world.terrain,current_terrain) and instance is Node3D:current_registry.register_scenery("tile:"+str(index),instance))
func _profile_instance_ready(id: int,source: Dictionary,instance) -> void:
	# All visual sources, including non-interactable scenery, get only a small
	# provenance stamp. Selection registry eligibility remains unchanged.
	var text_context:=preload("res://systems/native_data/overhead_speech_scope.gd").context(native_text_connection(),epoch,world.area_id)
	preload("res://systems/native_data/overhead_speech_anchor.gd").stamp(instance,source,text_context)
	# Wake only an already-admitted popup candidate at actual visual publication.
	# This follows the identity stamp and also covers non-interactable speakers;
	# no world scan or new raw entity update is needed when a model finishes.
	if text_context.get("ready",false) and is_instance_valid(gameplay_ui) and gameplay_ui.has_method("popup_visual_ready"):
		gameplay_ui.popup_visual_ready(id,source,[text_context.connection,text_context.generation,text_context.areaId])
	var row:={"eligible":false}
	if not instance.has_meta("native_selection_scope"):
		instance.set_meta("native_selection_scope",[world.get_instance_id(),world.generation,world.area_id,id,preload("res://systems/native_data/entity_presentation_lifetime.gd").token(source)])
	if Interaction.eligible(source,world.area_id): row={"id":id,"name":object_name(source),"type":int(source.objectType),"eligible":true,"color":"#66ff99" if int(source.objectType)==5 else "#55ddff","source":source}
	var changed: bool=registry.register_native(id,row,instance)
	if is_instance_valid(registry) and instance is Node3D:registry.register_scenery("object:"+str(id),instance,id)
	if changed: hud.queue_refresh_entities()
func native_text_connection() -> Variant:
	# Offline/base entry has no admitted connection. The session entry supplies
	# its accepted owner; a received text event can never choose this value.
	return null
func native_tile_borders_enabled() -> bool:return true
func native_text_anchor(id: int,witness: Array,scope: Array) -> Dictionary:
	if closing or not is_instance_valid(world) or world.closed or world.retiring or not is_instance_valid(gameplay_ui):return {"ready":false,"retired":true}
	var source: Dictionary=world.desired.get(id,{}).get("object",{})
	return preload("res://systems/native_data/overhead_speech_anchor.gd").project(world.instances.get(id),source,witness,scope,preload("res://systems/native_data/overhead_speech_scope.gd").context(native_text_connection(),epoch,world.area_id),camera)
func native_script_floating_anchor(id: int,witness: Array,scope: Array,height: float) -> Dictionary:
	if closing or not is_instance_valid(world) or world.closed or world.retiring:return {"ready":false,"retired":true}
	var source: Dictionary=world.desired.get(id,{}).get("object",{})
	var pose: Dictionary=world.motion.pose(id) if world.motion.objects.has(id) else world.object_pose(source) if not source.is_empty() else {}
	var point: Variant=world.to_global(pose.position) if pose.get("position") is Vector3 else null
	return preload("res://systems/native_data/script_floating_anchor.gd").project(source,witness,scope,preload("res://systems/native_data/overhead_speech_scope.gd").context(native_text_connection(),epoch,world.area_id),point,height,camera)
func native_script_floating_object_delta(id: int,witness: Array,scope: Array) -> Variant:
	if closing or not is_instance_valid(world) or world.closed or world.retiring:return null
	var source: Dictionary=world.desired.get(id,{}).get("object",{})
	var current:=preload("res://systems/native_data/overhead_speech_scope.gd").context(native_text_connection(),epoch,world.area_id)
	if not preload("res://systems/native_data/script_floating_anchor.gd").current(source,witness,scope,current):return null
	# This is the established nominal native movement clock. Special original
	# timer-selection/time-stop state is not inferred from GUI frame seconds.
	return world.motion.last_delta_ms if world.motion.last_delta_frame==Engine.get_process_frames() else null
func bind_world_input() -> void:
	world_input=InputOwner.new()
	host.add_child(world_input)
	world_input.configure(registry,camera,hud)
	world_input.camera_controller=controller
	world_input.player_id_query=func():return world.controlled_id if is_instance_valid(world) else -1
	world_input.include_player_query=func():return is_instance_valid(gameplay_ui) and is_instance_valid(gameplay_ui.desktop) and not gameplay_ui.desktop.target.is_empty()
	world_input.action=world_action
	world_input.pointer_miss=gameplay_ui.desktop.world_pointer_miss

func world_action(hit: Dictionary) -> void:
	if is_instance_valid(loading_screen) and loading_screen.blocks_input(): return
	if is_instance_valid(gameplay_ui) and is_instance_valid(gameplay_ui.desktop) and gameplay_ui.desktop.world_click(hit): return
	if not is_instance_valid(world) or not world.ready_for_control(): return
	var id:=int(hit.get("id",-1)); var base:={"generation":epoch,"areaId":world.area_id}
	var selected_object: Dictionary=world.desired.get(id,{}).get("object",{})
	if selected_object.is_empty() and is_instance_valid(transition_targets): selected_object=transition_targets.objects.get(id,{})
	if id>=0 and not Interaction.eligible(selected_object,world.area_id): return
	if id==world.controlled_id: return
	if id>=0:
		var action: Variant=ActionMenu.default_interaction(selected_object)
		if action==null:
			if is_instance_valid(gameplay_ui):gameplay_ui.chat.append_message({"system":true,"text":"No interaction is available"})
			return
		if str(action)=="item.pickup":base.merge({"kind":"item-action","itemId":id,"operation":"pickup"})
		else:base.merge({"kind":"interact","targetId":id,"action":str(action),"run":bool(hit.get("run",not Input.is_key_pressed(KEY_SHIFT)))})
	elif hit.has("position"):
		var position: Vector3=hit.position; base.merge({"kind":"walk","position":[position.x,-position.z,position.y],"run":bool(hit.get("run",not Input.is_key_pressed(KEY_SHIFT)))})
		walk_pointer_serial+=1; base.walkPointerRequestId=walk_pointer_serial
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
func application_exit_policy() -> bool: return false
func retain_world_diagnostics(reason: String,connection: int=0) -> void:
	if not is_instance_valid(world): return
	var value:={"reason":reason,"connection":connection,"generation":world.generation,"area_id":world.area_id,"ticks_ms":Time.get_ticks_msec(),"world":world.snapshot(),"interactive":interactive,"controlled_distance":maximum_distance,"environment_accepted":report.get("environment_accepted",false)}
	if is_instance_valid(world_input): value.pointer_attempts=world_input.pointer_attempts
	if is_instance_valid(environment): value.environment=environment.snapshot(); value.environment_source=environment.source
	if is_instance_valid(gamma_controller): value.gamma=gamma_controller.snapshot()
	if is_instance_valid(native_output): value.native_scene_output=native_output.snapshot()
	if world.desired.has(world.controlled_id): value.controlled=world.desired[world.controlled_id].object
	if is_instance_valid(camera) and is_instance_valid(controller): value.camera={"position":[camera.position.x,camera.position.y,camera.position.z],"target":[controller.target.x,controller.target.y,controller.target.z],"quaternion":[camera.quaternion.x,camera.quaternion.y,camera.quaternion.z,camera.quaternion.w]}
	# One detailed last-world packet, with a bounded compact history. Do not retain
	# live scene owners or mutable dictionaries that retirement will clear/change.
	report.last_world=value.duplicate(true)
	if not report.has("world_end_history"): report.world_end_history=[]
	report.world_end_history.append({"reason":reason,"connection":connection,"generation":world.generation,"area_id":world.area_id,"ready":value.world.get("ready",false),"complete":value.world.get("object_visuals_complete",false)})
	while report.world_end_history.size()>16: report.world_end_history.pop_front()
func accepted_bundle_shutdown_snapshot() -> Dictionary:
	# This function runs once after the timed window closes, before world owners
	# are retired. No new per-frame scan, cache, clock or authored callback.
	var core: Dictionary=runtime_feature_report.render_core_observation()
	var out: Dictionary={"version":1,"enabled":not core.flags.is_empty(),"flags":core.flags,"scope":"One cold final normal-bundle receipt; zero use can be legitimate outside the matched heavy-world acceptance cohort"}
	if not out.enabled:return out
	out.engine_features=core.feature_totals
	out.diagnostics={"profiling":FrameProfile.enabled,"pacing":{}}
	if ClassDB.class_exists("NwnFramePacing") and ClassDB.class_has_method("NwnFramePacing","snapshot"):
		out.diagnostics.pacing=ClassDB.class_call_static("NwnFramePacing","snapshot",1)
	out.skin_owners=[]
	if not is_instance_valid(world):return out
	if is_instance_valid(world.focus_lighting) and world.focus_lighting._input_registry.native!=null:
		out.light_inputs=world.focus_lighting._input_registry.native.call("dispatch",9,{})
	if is_instance_valid(world.particle_stream_group) and world.particle_stream_group.native!=null:
		var native_owner: RefCounted=world.particle_stream_group.native
		out.particle_boundary=native_owner.call("dispatch",13,{})
		out.particle_setup=native_owner.call("dispatch",16,{})
		out.hot_parameters=native_owner.call("dispatch",18,{})
		out.resident_text=native_owner.call("dispatch",21,{})
		out.empty_clips=native_owner.call("dispatch",22,{})
	for owner: Node in world.find_children("*","Node",true,false):
		if owner.get_script()==preload("res://systems/model_rigs.gd"):
			out.skin_owners.append(owner.call("native_skin_publication_snapshot"))
	return out

func shutdown() -> void:
	if closing: return
	closing=true
	finish_renderer_retirement()
	area_graphics.release()
	area_graphics.profile_provider=Callable()
	_end_area_graphics_light_census()
	if root.window_input.is_connected(toggle_performance_input):root.window_input.disconnect(toggle_performance_input)
	if RenderingServer.frame_post_draw.is_connected(record_render_frame):RenderingServer.frame_post_draw.disconnect(record_render_frame)
	if creation_runtime.enabled:creation_runtime.event("finish:shutdown-start",creation_runtime_values())
	shutdown_stage("snapshot")
	report.runtime_features=runtime_features_snapshot()
	report.cpu_skin_deformation=preload("res://systems/native_data/skin_deformation.gd").compiled_status()
	if report.has("performance_window"):
		report.performance_window.elapsed_ms=Time.get_ticks_msec()-int(report.performance_window.started_at_ms)
		report.performance_window.view_end=runtime_features_snapshot().presentation
	report.presentation_state={"headless":DisplayServer.get_name()=="headless","engine":Engine.get_version_info(),"method":RenderingServer.get_current_rendering_method(),"driver":RenderingServer.get_current_rendering_driver_name(),"viewport":[root.size.x,root.size.y],"msaa_3d":root.msaa_3d,"vsync":DisplayServer.window_get_vsync_mode(root.get_window_id()) if DisplayServer.get_name()!="headless" else -1,"focused":root.has_focus(),"detailed_profiling":is_instance_valid(frame_profile) and FrameProfile.enabled,"nodes":Performance.get_monitor(Performance.OBJECT_NODE_COUNT),"draws":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"triangles":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),"static_memory_bytes":Performance.get_monitor(Performance.MEMORY_STATIC),"texture_memory_bytes":Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED),"configured_threaded_cull_threshold":ProjectSettings.get_setting("rendering/limits/spatial_indexer/threaded_cull_minimum_instances",-1),"scope":"One cached-counter/configuration observation before shutdown captures; no forced GPU timing queries. Not a clean benchmark by itself."}
	report.diagnostic_preview_policy={"enabled":interactive and str(args.get("capture-preview","false"))=="true" and DisplayServer.get_name()!="headless","captured":preview_captured,"scope":"Automatic ready screenshot is opt-in; explicit diagnostic and shutdown captures are separate"}
	report.animation_validation={"compiled_available":preload("res://systems/native_data/packed_animation_keys.gd").native_available,"forced_gd":OS.get_cmdline_user_args().has("--animation-keys=gd"),"scope":"Read-only binary key finite/time/range validation; ASCII precision and playback channels unchanged"}
	if is_instance_valid(loading_screen): report.loading_screen=loading_screen.snapshot()
	if is_instance_valid(keyboard): report.keyboard=keyboard.stats.duplicate(); keyboard.stop(false)
	if is_instance_valid(world_input): report.pointer_attempts=world_input.pointer_attempts.duplicate(true)
	if is_instance_valid(world): report.world=world.snapshot()
	report.accepted_render_bundle=accepted_bundle_shutdown_snapshot()
	if is_instance_valid(environment): report.environment=environment.snapshot(); report.environment_source=environment.source.duplicate(true)
	if is_instance_valid(gamma_controller): report.gamma=gamma_controller.snapshot()
	if is_instance_valid(native_output): report.native_scene_output=native_output.snapshot()
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
	report.interactive=interactive
	report.exit_acceptance=preload("res://systems/native_render/exit_acceptance.gd").classify(report,args,application_exit_policy())
	report.gameplay_success=report.exit_acceptance.gameplay_success
	report.success=report.exit_acceptance.success
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
		var median_ms: float=(float(sorted[int((sorted.size()-1)/2.0)])+float(sorted[int(sorted.size()/2.0)]))*0.5
		report.frame_intervals={"count":samples.size(),"average_ms":sum/samples.size(),"median_ms":median_ms,"p95_ms":sorted[mini(sorted.size()-1,int(ceil(sorted.size()*0.95))-1)],"p99_ms":sorted[mini(sorted.size()-1,int(ceil(sorted.size()*0.99))-1)],"worst_ms":sorted[-1],"over_50ms":hitches,"scope":"Retained active-world tick samples (up to4096), may include loading unless performance_window.steady is true; functional run, not clean performance acceptance"}
	if creation_runtime.enabled:creation_runtime.event("finish:finished-enqueue-before",creation_runtime_values())
	send({"kind":"finished","success":report.success})
	if creation_runtime.enabled:creation_runtime.event("finish:finished-enqueue-after",creation_runtime_values())
	var finish_deadline:=Time.get_ticks_msec()+2000
	while not finish_acknowledged and peer.get_status()==StreamPeerTCP.STATUS_CONNECTED and Time.get_ticks_msec()<finish_deadline:
		peer.poll(); flush_protocol_output(); var available:=peer.get_available_bytes()
		if available>0:
			for message in frames.feed(peer.get_data(mini(available,1048576))[1]): receive(message)
		if not finish_acknowledged: await process_frame
	report.protocol_finish_ack=finish_acknowledged
	report.protocol_output=protocol_output.snapshot()
	report.clean_exit=report.success and finish_acknowledged and report.workers_remaining==0
	if creation_runtime.enabled:creation_runtime.event("finish:report-before",creation_runtime_values())
	if creation_runtime.enabled or not creation_runtime.failure.is_empty():report.creation_runtime_trace=creation_runtime.snapshot()
	shutdown_stage("report")
	var file:=FileAccess.open(args.report,FileAccess.WRITE); file.store_string(JSON.stringify(report,"\t")); file.close(); peer.disconnect_from_host(); quit(0 if report.clean_exit else 1)
