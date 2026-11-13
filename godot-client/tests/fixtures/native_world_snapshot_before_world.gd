extends Node3D
# Original protocol state in; original native resource loaders and private scene
# owners out. No scene-transfer or renderer-prepared metadata is accepted.
const Terrain=preload("res://systems/native_render/area_stream.gd")
const Objects=preload("res://systems/native_render/object_stream.gd")
const Creatures=preload("res://systems/native_render/creature_stream.gd")
const Pool=preload("res://systems/native_render/resource_pool.gd")
const Cache=preload("res://systems/native_data/prepared_cache.gd")
const Motion=preload("res://systems/network_motion.gd")
const CombatMotion=preload("res://systems/native_data/combat_motion.gd")
const Surface=preload("res://systems/native_render/terrain_surface.gd")
const FrameProfile=preload("res://systems/native_render/frame_profile.gd")
const ParticleRandom=preload("res://systems/native_render/particle_random.gd")
const ReferenceAssets=preload("res://systems/native_render/reference_assets.gd")
const Assets=preload("res://systems/native_data/asset_service.gd")
const PointWind=preload("res://systems/native_render/scene_point_wind.gd")
const ParticleMetrics=preload("res://systems/native_render/particle_metrics.gd")
const SceneHit=preload("res://systems/native_render/projectile_scene.gd")
const Priority=preload("res://systems/native_render/stream_priority.gd")
const BaseScenery=preload("res://systems/native_render/base_world_scenery.gd")
const EntityLifetime=preload("res://systems/native_data/entity_presentation_lifetime.gd")
signal instance_ready(id: int,source: Dictionary,instance)
signal instance_removed(id: int)
signal instance_state_changed(id: int,source: Dictionary)
var pool:=Pool.new()
var owns_pool:=true
var point_wind
var particle_metrics:=ParticleMetrics.new()
var particle_stream_group: Node
var catalog
var terrain
var borders
var borders_started:=false
var tile_borders_enabled:=true
var border_disabled: Variant=null
var surface
var batches: Array=[]
var desired: Dictionary={}
var installed: Dictionary={}
var instances: Dictionary={}
var static_collision_index=preload("res://systems/native_render/scene_query_index.gd").new()
var direct_particle_collision_enabled:=true # Diagnostic callback-boundary A/B.
var animations: Dictionary={}
var hidden: Dictionary={}
var failed_objects: Dictionary={}
var show_blockers_enabled:=false
func set_show_blockers(enabled: bool) -> void:
	if closed or retiring or show_blockers_enabled==enabled:return
	show_blockers_enabled=enabled
	# Only an explicit settings change visits the installed subset.
	for instance in instances.values():
		if is_instance_valid(instance) and instance.has_method("set_show_blockers"):instance.set_show_blockers(enabled)
var motion:=Motion.new()
var motion_revisions: Dictionary={}
var cache_path:=""
var area_id:=-1
var generation:=-1
var controlled_id:=-1
var focus_lighting
var model_environment
var native_sky
var placeable_lights
var base_draw_merge
var base_draw_merge_enabled:=OS.get_cmdline_user_args().has("--base-scenery-draw=merged")
func invalidate_static_draw(id: int,reason: String) -> void:
	if is_instance_valid(base_draw_merge) and instances.has(id):preload("res://systems/native_render/static_draw_invalidation.gd").withdraw(instances[id],reason)
func admit_static_draw(id: int) -> void:
	if is_instance_valid(base_draw_merge) and instances.has(id):base_draw_merge.consider_instance(id,instances[id])
func _init() -> void:
	motion.facing_target_query=motion_target_position
func motion_target_position(id: int) -> Variant:
	if closed or retiring or not desired.has(id): return null
	var source: Dictionary=desired[id].object
	if int(source.get("areaId",-1))!=area_id or source.get("replicationRemoved",false): return null
	if motion.objects.has(id): return motion.objects[id].position
	var point: Variant=source.get("replicated",{}).get("position")
	return Motion.vector(point) if point is Array and point.size()>=3 else null
func shadow_focus() -> Dictionary:
	if closed or retiring:return {}
	var owner: int=focus_lighting.only_light_owner() if is_instance_valid(focus_lighting) else 0
	if instances.has(controlled_id) and is_instance_valid(instances[controlled_id]):return {"position":instances[controlled_id].global_position,"source":"controlled-actor","only_owner":owner}
	if desired.has(controlled_id):
		var pose:=object_pose(desired[controlled_id].object)
		if not pose.is_empty():return {"position":global_transform*pose.position,"source":"controlled-pose","only_owner":owner}
	if has_priority_origin:return {"position":global_transform*priority_origin,"source":"area-entry","only_owner":owner}
	return {}
func observe_facing_target(object: Dictionary) -> void:
	var id:=int(object.id)
	if int(object.objectType)==5 and motion.objects.has(id): motion.objects[id].facingTarget=int(object.get("replicated",{}).get("facingTarget",0x7f000000))
var minutes_per_hour:=5
var use_skeleton:=false
var closed:=false
var retiring:=false
var retirement_physics_scan:=OS.get_cmdline_user_args().has("--retirement-physics=scan")
var stats:={"errors":[],"object_errors":[],"failed_admissions":0,"replacements":0,"stale_results":0,"removed":0,"pose_updates":0,"pose_evaluations":0,"static_pose_evaluations":0,"animation_changes":0,"completed_batches":0,"movement_records":0,"stale_movement_records":0,"simulated_motion_frames":0,"batches":[],"admissions":[]}
var opened_at:=0
var references
var maximum_actor_batch:=32
var maximum_static_batch:=64
var maximum_base_static_batch:=64 # Separate continuing base lane; not the legacy one-shot prefetch cap.
var maximum_stream_wave:=64
var entry_prefetch_enabled:=true # Allow bounded base preparation before control; player request stays first.
var entry_prefetch_limit:=8
var entry_base_workers:=1
var continuous_base_stream:=OS.get_cmdline_user_args().has("--base-scenery-stream=continuous")
var base_stream_schedule=preload("res://systems/native_render/base_stream_schedule.gd").new()
var reuse_base_scenery_owner:=OS.get_cmdline_user_args().has("--base-scenery-owner=retained") or OS.get_cmdline_user_args().has("--base-scenery-stream=continuous")
var retained_base_owner
var retained_base_generation:=-1
var base_scenery_population_known:=false
var base_scenery_progress_dirty:=true
const BASE_SCENERY_PROGRESS_FIELDS=["expected","resolved","instances_resolved","hidden_resolved","failed","unknown_placeables","unresolved_static","omitted_static"]
# Per-slot flags/reason live on the existing desired owner; only totals here.
var base_scenery_progress_counts: Dictionary={"expected":0,"resolved":0,"instances_resolved":0,"hidden_resolved":0,"failed":0,"unknown_placeables":0,"unresolved_static":0,"omitted_static":0,"unresolved_reasons":{}}
var base_scenery_boundary_depth:=0
var base_scenery_rebuild_pending:=false
var base_scenery_population_changed:=false
var base_scenery_population_revision:=0
var base_scenery_known_complete_since_ms: Variant=null
var base_scenery_complete_since_ms: Variant=null
# Sparse renderer omissions only: ID -> reason. No source rows/model data or second world store.
var base_scenery_omitted: Dictionary={}
var base_scenery_unaddressable_omitted:=false
var base_live_revision:=0
var base_live_idle_revision:=-1
var entry_prefetch_radius:=20.0
var priority_origin:=Vector3.ZERO
var has_priority_origin:=false
func update_stream_priority() -> void:
	var point: Vector3=priority_origin
	if instances.has(controlled_id): point=instances[controlled_id].position
	elif desired.has(controlled_id): point=object_pose(desired[controlled_id].object).position
	elif not has_priority_origin: return
	if has_priority_origin and priority_origin.distance_squared_to(point)<4.0: return
	set_priority_origin(point)
func set_priority_origin(value: Vector3) -> void:
	if not value.is_finite(): return
	priority_origin=value; has_priority_origin=true
	if continuous_base_stream:base_stream_schedule.set_origin(value)
	for owner in [terrain,surface,references,borders]:
		if is_instance_valid(owner): owner.set_priority_origin(value)
	for batch in batches:
		if is_instance_valid(batch.owner): batch.owner.set_priority_origin(value)
var adoption_budget_ms:=3.0
var maximum_adoptions_per_frame:=8
# Default-off experiment: only verified current base-wave candidates may use
# unused time after the original first-eight allowance. No deadline reset.
var base_admission_allowance:=OS.get_cmdline_user_args().has("--base-scenery-admission=timed")
var data_retirement
var owns_data_retirement:=false
var drive_collision
var drive_collision_configuration:=configured_drive_collision(OS.get_cmdline_user_args())
var drive_spatial_enabled: bool=drive_collision_configuration.valid and drive_collision_configuration.requested=="indexed"
var drive_collision_active_configuration: Dictionary={}
static func _registry_drive_collision_default(registry: Variant) -> Dictionary:
	var result:={"requested":"","explicit":false,"valid":false,"reason":"invalid-registry-default"}
	if not registry is Dictionary or registry.get("version")!=1 or not registry.get("features") is Array:return result
	var matches: Array=[]
	for row in registry.features:
		if row is Dictionary and row.get("name")=="drive-collision":matches.append(row)
	if matches.size()!=1:return result
	var value: Variant=matches[0].get("default")
	if not value is String or value not in ["legacy","indexed"] or not matches[0].get("choices") is Array or not matches[0].choices.has(value):return result
	result.requested=value;result.valid=true;result.reason="registry-default"
	return result
static func configured_drive_collision(arguments: PackedStringArray) -> Dictionary:
	# Omission uses the authoritative registry; explicit diagnostic selections
	# remain valid. Missing/invalid defaults and malformed flags fail closed.
	var result:={"requested":"","explicit":false,"valid":true,"reason":""}
	var matches: Array[String]=[]
	for argument in arguments:
		if argument=="--drive-collision" or argument.begins_with("--drive-collision="):matches.append(argument)
	if matches.is_empty():
		var registry_path:="res://systems/native_data/client_feature_registry.json"
		var registry: Variant=JSON.parse_string(FileAccess.get_file_as_string(registry_path)) if FileAccess.file_exists(registry_path) else null
		return _registry_drive_collision_default(registry)
	result.explicit=true
	result.requested=matches[0].trim_prefix("--drive-collision=") if matches[0].begins_with("--drive-collision=") else ""
	if matches.size()!=1:result.valid=false;result.reason="duplicate-selection"
	elif result.requested.is_empty():result.valid=false;result.reason="missing-value"
	elif result.requested not in ["legacy","indexed"]:result.valid=false;result.reason="invalid-value"
	else:result.reason="explicit-selection"
	return result
func _new_drive_collision() -> Node:
	if not bool(drive_collision_configuration.valid):return null
	drive_collision_active_configuration=drive_collision_configuration.duplicate(true)
	drive_collision_active_configuration.constructed_route="indexed" if drive_spatial_enabled else "legacy"
	drive_collision_active_configuration.scope={"world_instance":get_instance_id(),"generation":generation,"area_id":area_id}
	if drive_spatial_enabled!=(drive_collision_configuration.requested=="indexed"):
		drive_collision_active_configuration.reason="programmatic-pre-open-override"
	return preload("res://systems/native_render/drive_collision_indexed.gd").new() if drive_spatial_enabled else preload("res://systems/native_render/drive_collision.gd").new()
func drive_collision_selection_snapshot() -> Dictionary:
	var result: Dictionary=(drive_collision_active_configuration if not drive_collision_active_configuration.is_empty() else drive_collision_configuration).duplicate(true)
	result.owner_script=""
	result.effective="unavailable"
	if is_instance_valid(drive_collision):
		var script: Script=drive_collision.get_script()
		result.owner_script=script.resource_path if script!=null else ""
		result.effective="indexed" if result.owner_script=="res://systems/native_render/drive_collision_indexed.gd" else "legacy" if result.owner_script=="res://systems/native_render/drive_collision.gd" else "custom"
	if not result.has("scope"):result.scope={"world_instance":get_instance_id(),"generation":generation,"area_id":area_id}
	return result
var combat
var effects
var release_started:=false
var retired_data: Dictionary={}
var retirement_disable_timings: Dictionary={}
func retirement_step(budget_ms: float=2.0) -> bool:
	if closed: return true
	if not retiring: return false
	if not release_started:
		release_started=true
		var detach_began:=FrameProfile.begin()
		var detached:={"asset_results":[]}
		for owner in asset_owners(): detached.asset_results.append(owner.detach_retired_results())
		# Completed decoded caches can be very large even when no jobs remain.
		# Drop their final CPU-only references on the existing disposal owner.
		if is_instance_valid(references): detached.references=references.detach_prepared_data()
		if is_instance_valid(effects): detached.effects=effects.detach_prepared_data()
		if is_instance_valid(surface): detached.surface=surface.detach_prepared_data()
		if is_instance_valid(drive_collision): detached.drive=drive_collision.detach_prepared_data()
		if is_instance_valid(borders):detached.borders=borders.detach_prepared_data()
		# One bounded CPU-data disposal job per world instead of one job per
		# owner. Frame-budgeted scene/GPU destruction below remains on the main thread.
		retired_data=detached
		FrameProfile.finish("retirement_detach_data",detach_began)
	var began:=Time.get_ticks_usec(); var released:=0
	# Main-thread scene/GPU owners must stay on this thread. Spread their
	# destruction over frames while the next world is already streaming.
	for id in instances.keys():
		var release_began:=FrameProfile.begin(); remove_instance(int(id)); released+=1
		FrameProfile.finish("retirement_entity_release",release_began)
		if released>=4 or (Time.get_ticks_usec()-began)/1000.0>=budget_ms: return false
	if is_instance_valid(borders):
		var remaining_ms:=budget_ms-(Time.get_ticks_usec()-began)/1000.0
		if remaining_ms<=0 or not borders.retirement_step(remaining_ms):return false
		if (Time.get_ticks_usec()-began)/1000.0>=budget_ms:return false
	if is_instance_valid(terrain):
		for id in terrain.instances.keys():
			var release_began:=FrameProfile.begin()
			var instance=terrain.instances[id]; terrain.instances.erase(id)
			if is_instance_valid(instance): instance.retire()
			FrameProfile.finish("retirement_tile_release",release_began)
			released+=1
			if released>=4 or (Time.get_ticks_usec()-began)/1000.0>=budget_ms: return false
		data_retirement.retire(terrain.detach_prepared_data())
	return true
func adoption_timing(name: String,began: int) -> void:
	var elapsed:=(Time.get_ticks_usec()-began)/1000.0
	if not stats.has("adoption_timings"): stats.adoption_timings={}
	if not stats.adoption_timings.has(name): stats.adoption_timings[name]={"count":0,"total_ms":0.0,"max_ms":0.0}
	var entry: Dictionary=stats.adoption_timings[name]; entry.count+=1; entry.total_ms+=elapsed; entry.max_ms=maxf(entry.max_ms,elapsed)
	FrameProfile.record("adoption_"+name,elapsed)
func _enter_tree() -> void:
	if get_meta("native_surface_output",false): preload("res://systems/native_render/native_surface_state.gd").bind(self)
	focus_lighting=preload("res://systems/native_render/focus_lighting.gd").new(); add_child(focus_lighting); focus_lighting.configure(self)
	var ancestor:=get_parent()
	while ancestor!=null:
		if ancestor.has_meta("native_data_retirement"): data_retirement=ancestor.get_meta("native_data_retirement"); break
		ancestor=ancestor.get_parent()
	if not is_instance_valid(data_retirement):
		data_retirement=preload("res://systems/native_data/data_retirement.gd").new(); add_child(data_retirement); owns_data_retirement=true
	# One local visual stream per admitted world, never canonical gameplay RNG.
	set_meta("native_particle_random",ParticleRandom.new())
	set_meta("native_particle_metrics",particle_metrics)
	set_meta("native_particle_collision",collide_particle)
	set_meta("native_particle_collision_indices",particle_collision_indices)
	point_wind=PointWind.new(); add_child(point_wind); set_meta("native_point_wind_owner",point_wind)
	if OS.get_cmdline_user_args().has("--particle-presentation=shared") or OS.get_environment("NWN_PARTICLE_PRESENTATION")=="shared":
		particle_stream_group=preload("res://systems/native_render/particle_stream_group.gd").new(); add_child(particle_stream_group)
		if not particle_stream_group.configure(self): stats.particle_stream_failure=particle_stream_group.failure
	combat=preload("res://systems/native_render/combat_presentation.gd").new(); add_child(combat)
func particle_collision_indices() -> Array:
	if closed or retiring or not direct_particle_collision_enabled or not is_instance_valid(terrain): return []
	var tiles=terrain.get("collision_index")
	if tiles==null or not (tiles.entries.is_empty() or tiles.native_ready()) or not (static_collision_index.entries.is_empty() or static_collision_index.native_ready()): return []
	if is_instance_valid(terrain.batcher) and not terrain.batcher.owners.is_empty(): return []
	return [tiles.native_owner.call("dispatch",5,{}) if not tiles.entries.is_empty() else 0,static_collision_index.native_owner.call("dispatch",5,{}) if not static_collision_index.entries.is_empty() else 0]
func collide_particle(start: Array,end: Array,out: Array,hit: Dictionary) -> bool:
	if closed or retiring: return false
	var began:=FrameProfile.begin(); var result:=SceneHit.trace(self,start,end,true)
	FrameProfile.finish("native_particle_scene_collision",began)
	stats.particle_scene_queries=int(stats.get("particle_scene_queries",0))+1
	stats.particle_scene_hits=int(stats.get("particle_scene_hits",0))+int(result.hit)
	if not result.hit: return false
	out.assign(result.position); hit.normal=result.normal; return true
func open(source,area: Dictionary,epoch: int,cache_directory: String,shared_pool=null,entry: Dictionary={}) -> void:
	if not bool(drive_collision_configuration.valid):
		stats.errors.append("Rejected --drive-collision: "+str(drive_collision_configuration.reason)+" (expected legacy or indexed)")
		return
	if shared_pool!=null: pool=shared_pool; owns_pool=false
	catalog=source; area_id=int(area.id); generation=epoch; cache_path=cache_directory
	if base_draw_merge_enabled:
		base_draw_merge=preload("res://systems/native_render/base_static_draw_merge.gd").new();add_child(base_draw_merge)
		var context: Variant=get_meta("native_static_draw_context_provider",Callable())
		if not base_draw_merge.configure(self,context if context is Callable else Callable()):base_draw_merge.close();base_draw_merge.queue_free();base_draw_merge=null
	border_disabled=border_disabled_from_network(area)
	if is_instance_valid(point_wind): point_wind.set_area(area.get("fields",{}))
	opened_at=Time.get_ticks_usec()
	model_environment=preload("res://systems/native_render/model_environment.gd").new(); add_child(model_environment); model_environment.configure(catalog,pool)
	references=ReferenceAssets.new(); add_child(references); references.configure(catalog,pool,cache_path); set_meta("native_reference_hub",references)
	native_sky=preload("res://systems/native_render/sky_world.gd").new(); add_child(native_sky); native_sky.configure(self,catalog,pool,cache_path); set_meta("native_sky_owner",native_sky)
	effects=preload("res://systems/native_render/effect_world.gd").new(); add_child(effects); effects.configure(self)
	placeable_lights=preload("res://systems/native_render/placeable_lights.gd").new(); add_child(placeable_lights); placeable_lights.configure(self,catalog,pool,cache_path,area.get("placeableLights",[]))
	# Selection shapes are lazy and instance eligibility is decided from the
	# latest server state, independently of immutable shared render resources.
	pool.picking=false
	terrain=Terrain.new(); terrain.use_terrain_batches=false; add_child(terrain)
	var entry_position: Variant=entry.get("position")
	if entry_position is Array and entry_position.size()==3:
		set_priority_origin(Vector3(float(entry_position[0]),float(entry_position[2]),-float(entry_position[1])))
	terrain.definition_ready.connect(func(value):
		if is_instance_valid(model_environment): model_environment.receive_definition(value)
		surface=Surface.new(); add_child(surface); surface.configure(catalog,value,cache_path)
		if has_priority_origin: surface.set_priority_origin(priority_origin)
		motion.height_query=surface.height)
	terrain.open_network_area(catalog,area,pool,cache_path)
	drive_collision=_new_drive_collision(); add_child(drive_collision); drive_collision.configure(self,catalog,cache_path)
static func border_disabled_from_network(area: Dictionary) -> Variant:
	# Original received CNWCArea+10c, not Interior or a guessed default. Older
	# packets can omit the field; that absence must remain explicit.
	var fields: Variant=area.get("fields")
	if not fields is Dictionary:return null
	var value: Variant=fields.get("10c")
	if value is bool:return value
	if (value is int or value is float) and is_finite(float(value)) and (float(value)==0.0 or float(value)==1.0):return int(value)!=0
	return null
func start_area_border() -> void:
	if borders_started or closed or retiring or not ready_for_control():return
	borders_started=true
	# Match the original caller's short-circuit gates. Off/area-disabled needs
	# no decorative service or catalog work; an absent flag stays unavailable.
	if not tile_borders_enabled or not border_disabled is bool or border_disabled:return
	# The original LoadBorder supplies optional scenery, not more walkable
	# tiles/entities. Our asynchronous adaptation starts AFTER player+base-area
	# admission so optional work cannot extend the playable-world loading gate.
	borders=preload("res://systems/native_render/area_border_stream.gd").new();add_child(borders)
	if has_priority_origin:borders.set_priority_origin(priority_origin)
	borders.open_network(catalog,terrain.definition,{"enabled":tile_borders_enabled,"disabled":border_disabled},pool,[get_instance_id(),generation,area_id],cache_path)
func preview_drive(id: int,flags: int,heading: int) -> Dictionary:
	if id!=controlled_id or not ready_for_control() or not motion.objects.has(id): return {}
	var began:=FrameProfile.begin()
	var state: Dictionary=motion.objects[id]; var raw: Dictionary=desired[id].object.get("replicated",{})
	var planner=preload("res://systems/native_data/drive_preview.gd")
	if planner.blocked(int(raw.get("animation",0))) or raw.has("field8D4") and (int(raw.field8D4)&2)==0: return {}
	if (flags&15)==0:
		state.targetOrientation=planner.turn(state.orientation,flags)
		return {"turn":true}
	if not is_instance_valid(drive_collision): return {}
	var query_began:=FrameProfile.begin()
	var preview_plan: Dictionary={}
	var clear: Callable
	if drive_collision.has_method("query_preview"):
		# Prepare against the planned heading without committing orientation before
		# the original ready-query boundary. Authority queries stay unrestricted.
		var planned_orientation: Vector3=planner.wire_facing(heading) if heading>=0 else state.orientation
		preview_plan=planner.plan(state.position,planned_orientation,float(state.walkRate),float(state.runRate),flags)
		clear=drive_collision.query_preview(id,state.position,preview_plan.target,state.render)
	else:clear=drive_collision.query(id)
	FrameProfile.finish("keyboard_preview_query",query_began)
	if not clear.is_valid(): return {}
	if heading>=0:
		state.orientation=planner.wire_facing(heading); state.targetOrientation=state.orientation; state.previewFacing=state.orientation
	var plan: Dictionary=preview_plan if not preview_plan.is_empty() else planner.plan(state.position,state.orientation,float(state.walkRate),float(state.runRate),flags)
	var path_began:=FrameProfile.begin()
	var path: Dictionary=planner.path(state.position,plan.target,state.render,clear)
	FrameProfile.finish("keyboard_preview_path",path_began)
	if not path.is_empty(): plan.factor=path.factor
	motion.preview(id,plan,path.get("target"))
	FrameProfile.finish("keyboard_preview",began)
	return path if not path.is_empty() else {"blocked":true}
func end_drive(id: int) -> void:
	if motion.objects.has(id): motion.objects[id].driveHeld=false
func signature(object: Dictionary) -> String:
	var state: Dictionary=object.get("replicated",{}); var fixed: Dictionary=object.get("staticState",object.get("lightState",{}))
	var appearance: Variant=object.get("appearance",{})
	# Native creature P400 updates names/popups without marking the model dirty.
	# Keep the received row intact for name/state consumers and retain all other
	# opaque appearance/equipment bytes in the model key.
	if int(object.get("objectType",0))==5 and appearance is Dictionary and appearance.has("name"):
		appearance=appearance.duplicate(); appearance.erase("name")
	var animated_placeable: bool=int(object.get("objectType",0))==9 and preload("res://systems/native_render/placeable_instance.gd").requires_animation(state)
	return Cache.digest(var_to_bytes([EntityLifetime.token(object),animated_placeable,object.get("objectType"),appearance,object.get("item",state.get("item",{})),state.get("appearance",fixed.get("appearance")),state.get("doorType"),state.get("genericType")]))
func retire_replaced_lifetime(object: Dictionary) -> void:
	var id:=int(object.id)
	if not desired.has(id) or not EntityLifetime.changed(desired[id].object,object):return
	# Reused IDs must not inherit a failed job, an old path or old physical
	# instance. Pending jobs are fenced by signature at the existing adoption.
	if is_instance_valid(combat):combat.forget(id,true)
	remove_instance(id)
	failed_objects.erase(id);motion.objects.erase(id);motion_revisions.erase(id)
	stats.lifetime_replacements=int(stats.get("lifetime_replacements",0))+1
func receive(objects: Array,controlled: int) -> void:
	if closed or retiring:return
	base_scenery_begin_boundary(true)
	_receive_base_scenery_boundary(objects,controlled)
	base_scenery_end_boundary()
func _receive_base_scenery_boundary(objects: Array,controlled: int) -> void:
	if closed or retiring: return
	if continuous_base_stream:base_stream_schedule.clear()
	if is_instance_valid(placeable_lights): placeable_lights.receive(objects,[],true)
	controlled_id=controlled; var current: Dictionary={}
	var prior_omitted: Dictionary=base_scenery_omitted;var prior_unaddressable:=base_scenery_unaddressable_omitted
	base_scenery_omitted={};base_scenery_unaddressable_omitted=false
	for object in objects:
		base_scenery_forget_omitted(int(object.get("id",-1)))
		invalidate_static_draw(int(object.get("id",-1)),"received-full-state")
		if int(object.get("areaId",-1))!=area_id or object.get("replicationRemoved",false) or int(object.get("objectType",0)) not in [5,6,9,10]:
			note_omitted_base_scenery(object);continue
		if object_pose(object).is_empty():
			note_omitted_base_scenery(object);continue
		retire_replaced_lifetime(object)
		current[int(object.id)]={"object":object,"key":signature(object)}
		base_scenery_stamp_slot(int(object.id),current[int(object.id)])
		base_stream_note_desired(int(object.id),current[int(object.id)])
		if int(object.objectType)==5 and not motion.objects.has(int(object.id)):
			# Bootstrap from raw replication once. Repeated full registry snapshots
			# must not restart a path already advanced by the native frame owner.
			var state: Dictionary=object.get("replicated",{})
			motion.observe(int(object.id),state,true,state)
		observe_facing_target(object)
	for id in desired:
		if not current.has(id): combat.forget(int(id),true)
		base_scenery_note_population_change(desired[id],current.get(id,{}))
	for id in current:
		if not desired.has(id):base_scenery_note_population_change({},current[id])
	if prior_omitted!=base_scenery_omitted or prior_unaddressable!=base_scenery_unaddressable_omitted:base_scenery_population_changed=true
	desired=current
	base_scenery_population_known=true; base_live_revision+=1
	for id in instances:
		if desired.has(id): sync_combat(int(id))
	if is_instance_valid(drive_collision):
		var drive_publish_began:=FrameProfile.begin()
		if drive_collision.has_method("sync_full"):drive_collision.sync_full()
		else:drive_collision.warm_dirty=true
		FrameProfile.finish("drive_publish_full",drive_publish_began)
	for object in objects:
		var id:=int(object.id)
		if instances.has(id) and current.has(id): instance_state_changed.emit(id,object)
	for id in failed_objects.keys():
		if not desired.has(id) or str(desired[id].key)!=str(failed_objects[id].key): failed_objects.erase(id)
	for id in motion.objects.keys():
		if not desired.has(id): motion.objects.erase(id); motion_revisions.erase(id)
	for id in instances.keys():
		if not desired.has(id): remove_instance(id); stats.removed+=1
	for id in hidden.keys():
		if not desired.has(id): installed.erase(id); hidden.erase(id); stats.removed+=1
	apply_poses(true)
	if is_instance_valid(base_draw_merge):
		for id in instances:admit_static_draw(int(id))
func observe_movement(records: Array) -> void:
	if closed or retiring: return
	for row in records:
		var id:=int(row.id); var revision:=int(row.revision)
		if revision<=int(motion_revisions.get(id,-1)):
			stats.stale_movement_records+=1; continue
		motion_revisions[id]=revision
		var state: Dictionary=motion.objects.get(id,{}); var changes: Dictionary=row.changes; var deferred:=false
		if id==controlled_id and not row.get("created",false) and not state.is_empty() and not changes.get("path",[]).is_empty() and Motion.path_animation(int(changes.get("animation",state.animation))) and is_instance_valid(drive_collision) and drive_collision.ready():
			var clear: Callable=drive_collision.query(id,1.0/64)
			if clear.is_valid():
				deferred=true
				var stale: bool=int(state.script)!=0 and state.has("driveSequence") and int(changes.get("actionFlag",0))!=0 and int(changes.actionFlag)!=int(state.driveSequence)
				motion.observe(id,changes,false,row.initial,true)
				if not stale:
					var repair:=preload("res://systems/native_data/drive_preview.gd").repair({"render":state.render,"path":state.path,"cursor":state.cursor},changes.path,Motion.vector(changes.get("position",row.initial.get("position",state.position))),clear)
					if not repair.is_empty(): motion.accept_path(id,repair,changes)
		if not deferred: motion.observe(id,changes,bool(row.get("created",false)),row.initial)
		stats.movement_records+=1
		if is_instance_valid(drive_collision) and drive_collision.has_method("sync_motion_id"):drive_collision.sync_motion_id(id)
func receive_delta(objects: Array,removed: Array,controlled: int) -> void:
	if closed or retiring:return
	base_scenery_begin_boundary(false)
	_receive_delta_base_scenery_boundary(objects,removed,controlled)
	base_scenery_end_boundary()
func _receive_delta_base_scenery_boundary(objects: Array,removed: Array,controlled: int) -> void:
	if closed or retiring: return
	if not objects.is_empty() or not removed.is_empty():base_live_revision+=1
	if is_instance_valid(placeable_lights): placeable_lights.receive(objects,removed)
	var receive_began:=FrameProfile.begin()
	controlled_id=controlled
	if is_instance_valid(drive_collision) and not drive_collision.has_method("sync_delta") and (not removed.is_empty() or objects.any(func(object):return int(object.get("objectType",0)) in [9,10])):drive_collision.warm_dirty=true
	var remove: Dictionary={}
	for id in removed:
		remove[int(id)]=true;base_scenery_forget_omitted(int(id))
	for object in objects:
		var id:=int(object.id)
		base_scenery_forget_omitted(id)
		invalidate_static_draw(id,"received-delta-state")
		if int(object.get("areaId",-1))!=area_id or object.get("replicationRemoved",false) or int(object.get("objectType",0)) not in [5,6,9,10] or object_pose(object).is_empty():
			note_omitted_base_scenery(object);remove[id]=true;continue
		retire_replaced_lifetime(object)
		var key:=signature(object); base_scenery_replace_desired(id,{"object":object,"key":key}); remove.erase(id)
		if instances.has(id): sync_combat(id)
		if failed_objects.has(id) and str(failed_objects[id].key)!=key: failed_objects.erase(id)
		if int(object.objectType)==5 and not motion.objects.has(id):
			var state: Dictionary=object.get("replicated",{}); motion.observe(id,state,true,state)
		observe_facing_target(object)
		apply_pose(id)
		if instances.has(id): instance_state_changed.emit(id,object);admit_static_draw(id)
	for id in remove:
		combat.forget(int(id),true)
		base_scenery_forget_desired(int(id)); failed_objects.erase(id); motion.objects.erase(id); motion_revisions.erase(id)
		if instances.has(id) or hidden.has(id): remove_instance(int(id)); stats.removed+=1
	if is_instance_valid(drive_collision) and drive_collision.has_method("sync_delta"):
		var drive_publish_began:=FrameProfile.begin()
		drive_collision.sync_delta(objects,remove.keys())
		FrameProfile.finish("drive_publish_delta",drive_publish_began)
	FrameProfile.finish("snapshot_native_delta",receive_began)
func sync_combat(id: int) -> void:
	if str(installed.get(id,""))!=str(desired[id].key):
		combat.forget(id); return
	combat.sync(id,desired[id].object,instances[id])
func remove_instance(id: int) -> void:
	base_scenery_begin_boundary(false)
	_remove_instance_base_scenery_boundary(id)
	base_scenery_end_boundary()
func _remove_instance_base_scenery_boundary(id: int) -> void:
	var had_instance:=instances.has(id) or hidden.has(id)
	if desired.has(id) and not BaseScenery.classify(desired[id].object,area_id).base:base_live_revision+=1
	var removal_began:=FrameProfile.begin()
	if is_instance_valid(combat): combat.forget(id,not desired.has(id))
	invalidate_static_draw(id,"world-instance-removal")
	if instances.has(id): instance_removed.emit(id)
	if instances.has(id) and is_instance_valid(instances[id]):
		var instance=instances[id]
		var decoded: Dictionary=instance.retain_decoded_data() if instance.has_method("retain_decoded_data") else {}
		static_collision_index.erase(instance.get_instance_id()); instance.retire()
		if is_instance_valid(data_retirement): data_retirement.defer_release(decoded)
	instances.erase(id); installed.erase(id); animations.erase(id); hidden.erase(id)
	base_scenery_refresh_slot(id)
	if had_instance and desired.has(id):base_stream_note_desired(id,desired[id])
	FrameProfile.finish("entity_removal",removal_began)
static func object_pose(object: Dictionary) -> Dictionary:
	return Creatures.pose(object) if int(object.get("objectType",0)) in [5,6] else Objects.pose(object)
func apply_poses(include_statics: bool=false) -> void:
	# Only creatures own per-frame native motion. Other world objects retain
	# their received transforms until another snapshot or their first admission.
	# Native animation/effect owners still tick independently on those instances.
	for id in instances if include_statics else motion.objects: apply_pose(int(id))
func apply_pose(id: int) -> void:
	if not instances.has(id) or not desired.has(id): return
	var object: Dictionary=desired[id].object; var state: Dictionary=object.get("replicated",{}); var creature: bool=int(object.objectType)==5
	var pose: Dictionary=motion.pose(id) if creature else object_pose(object); var instance: Node3D=instances[id]
	if pose.is_empty(): return
	stats.pose_evaluations+=1
	if not creature: stats.static_pose_evaluations+=1
	if not instance.position.is_equal_approx(pose.position) or not is_equal_approx(instance.rotation.y,float(pose.rotation)):
		invalidate_static_draw(id,"world-pose-change")
		instance.position=pose.position; instance.rotation.y=float(pose.rotation); stats.pose_updates+=1
	var node_id:=instance.get_instance_id()
	if object.has("staticState"):
		if not static_collision_index.entries.has(node_id) or static_collision_index.entries[node_id].pose!=instance.global_transform: static_collision_index.put(instance)
	else: static_collision_index.erase(node_id)
	if creature:
		var movement: Dictionary=motion.objects[id]
		var code:=int(movement.animation)
		var animation:=[code,motion.gait_speed(id,instance.rigs.clip_length(id,code))*float(state.get("animationSpeed",1.0))]
		if animations.get(id)!=animation:
			animations[id]=animation; stats.animation_changes+=1
		if is_instance_valid(combat):
			combat.base_frame(id,animation[0],animation[1],CombatMotion.remaining_path(movement))
			# Original movement/turn requests enter private playback; they must not
			# replace the replicated base state or reset a running combat cue.
			if movement.get("correctionCue") is Dictionary: combat.movement_cue(id,movement.correctionCue)
			elif movement.get("facingTurn")!=null and not movement.active: combat.movement_cue(id,{"animation":int(movement.facingTurn)})
			movement.visualAnimation=combat.visual_animation(id,code)
		else: instance.set_animation(animation[0],animation[1])
		if is_instance_valid(effects) and effects.casts!=null: effects.casts.observe(object,code)
		if is_instance_valid(effects) and effects.special_attacks!=null: effects.special_attacks.observe(object)
		if is_instance_valid(effects) and effects.equipped_attacks!=null: effects.equipped_attacks.observe(object)
	elif int(object.objectType)==10 and instance.has_method("observe_door"):
		instance.observe_door(state)
	elif int(object.objectType)==9 and instance.has_method("observe_placeable"):
		instance.observe_placeable(state)
func receive_combat(message: Dictionary) -> void:
	if not closed and not retiring and int(message.get("generation",-1))==generation and int(message.get("areaId",-1))==area_id and is_instance_valid(combat):
		if is_instance_valid(effects) and effects.casts!=null:
			for row in message.get("events",[]):
				if row.get("action","")=="cast-state": effects.casts.receive(row)
		combat.receive(message)
func _process(delta: float) -> void:
	var began:=FrameProfile.begin()
	_profile_process(delta)
	FrameProfile.finish("callback_world",began)
func _profile_process(delta: float) -> void:
	FrameProfile.count("count_world_instances",instances.size()); FrameProfile.count("count_world_desired",desired.size()); FrameProfile.count("count_pending_batches",batches.size())
	if closed or retiring: return
	var phase_began:=FrameProfile.begin()
	motion.update(delta); stats.simulated_motion_frames+=1
	if is_instance_valid(drive_collision) and drive_collision.has_method("sync_motion"):
		var drive_publish_began:=FrameProfile.begin()
		drive_collision.sync_motion()
		FrameProfile.finish("drive_publish_motion",drive_publish_began)
	update_stream_priority()
	FrameProfile.finish("world_motion",phase_began)
	phase_began=FrameProfile.begin()
	var adoption_began:=Time.get_ticks_usec(); var adopted:=0;var base_adopted:=0
	var candidates: Array=[]
	for batch in batches:
		var owner=batch.owner; var actors: bool=batch.actors
		var prepared: Dictionary=owner.actors if actors else owner.instances
		if continuous_base_stream and batch.get("base_scenery",false):
			for id in owner.stats.get("object_failures",{}).keys():
				if batch.keys.has(id):
					consume_stream_failure(batch,int(id),owner.stats.object_failures[id])
					owner.stats.object_failures.erase(id);release_base_reservation(batch,int(id))
		if not actors:
			for id in owner.invisible_ids:
				if desired.has(id) and str(desired[id].key)==str(batch.keys.get(id,"")): remove_instance(id); installed[id]=batch.keys[id]; hidden[id]=true; note_base_scenery_publication(int(id))
				release_base_reservation(batch,int(id))
			owner.invisible_ids.clear()
		for id in prepared.keys():
			var point: Vector3=prepared[id].position
			if desired.has(id): point=object_pose(desired[id].object).position
			candidates.append({"id":id,"batch":batch,"position":point})
	Priority.sort_rows(candidates,priority_origin)
	# Changed player appearance still wins even if the old player is far from
	# the new received pose. All other completed owners share one distance order.
	for index in candidates.size():
		if int(candidates[index].id)==controlled_id: candidates.push_front(candidates.pop_at(index)); break
	for candidate in candidates:
		if adopted>0 and (Time.get_ticks_usec()-adoption_began)/1000.0>=adoption_budget_ms:break
		var current_base_admission:=base_admission_allowance and extra_base_admission_allowed(candidate,base_adopted)
		if adopted>=maximum_adoptions_per_frame and not current_base_admission:break
		var batch: Dictionary=candidate.batch; var id:=int(candidate.id); var owner=batch.owner
		var prepared: Dictionary=owner.actors if batch.actors else owner.instances
		var install_began:=Time.get_ticks_usec()
		var instance: Node3D=prepared[id]
		if not desired.has(id) or str(desired[id].key)!=str(batch.keys.get(id,"")):
			stats.stale_results+=1; prepared.erase(id); instance.retire();release_base_reservation(batch,id);continue
		remove_instance(id)
		# Live streams attach directly to the final parent. Reparenting an
		# already-active model invokes _exit_tree and retires its effects.
		if instance.get_parent()!=self: instance.reparent(self,true)
		prepared.erase(id)
		failed_objects.erase(id)
		instances[id]=instance; installed[id]=batch.keys[id]; stats.replacements+=1
		combat.sync(id,desired[id].object,instance)
		adopted+=1
		if current_base_admission:
			base_adopted+=1
			# Scalar World-lifetime counters only at successful current-base install.
			if adopted>maximum_adoptions_per_frame:stats.base_admission_extra_successes=int(stats.get("base_admission_extra_successes",0))+1
			stats.base_admission_max_base_adoptions=maxi(int(stats.get("base_admission_max_base_adoptions",0)),base_adopted)
		adoption_timing("install",install_began)
		if batch.actors and int(desired[id].object.objectType)==5:
			motion.adopt([{"id":id,"state":instance.get_meta("native_movement",{})}])
			if is_instance_valid(drive_collision) and drive_collision.has_method("sync_motion_id"):drive_collision.sync_motion_id(id)
		# The snapshot may have moved an object while its model was preparing.
		var pose_began:=Time.get_ticks_usec(); apply_pose(id); adoption_timing("pose",pose_began)
		if instance.has_method("set_show_blockers"):instance.set_show_blockers(show_blockers_enabled)
		instance.show()
		note_base_scenery_publication(id)
		var registration_began:=Time.get_ticks_usec(); instance_ready.emit(id,desired[id].object,instance); adoption_timing("registration",registration_began)
		admit_static_draw(id)
		if stats.admissions.size()<512: stats.admissions.append({"id":id,"kind":int(desired[id].object.objectType),"elapsed_ms":(Time.get_ticks_usec()-opened_at)/1000.0})
		release_base_reservation(batch,id)
	for batch in batches.duplicate():
		var owner=batch.owner; var actors: bool=batch.actors
		var prepared: Dictionary=owner.actors if actors else owner.instances
		if owner.done and prepared.is_empty():
			var stats_began:=Time.get_ticks_usec()
			# Shared rules remain required. Independent visual failures retain their
			# exact appearance binding; a remote creature cannot revoke player input.
			# Original creature failure scope is unproven: this is our explicit
			# streaming policy, preserving the stricter required-player failure gate.
			for error in owner.stats.get("scope_errors",owner.stats.errors): stats.errors.append(error)
			for id in owner.stats.get("object_failures",{}):
				consume_stream_failure(batch,int(id),owner.stats.object_failures[id])
			if stats.batches.size()<128: stats.batches.append(owner.stats.duplicate(true))
			adoption_timing("statistics",stats_began)
			finish_stream_owner(batch)
	FrameProfile.finish("world_adoption",phase_began)
	if is_instance_valid(base_draw_merge) and base_draw_merge.has_pending() and pool.can_publish():
		var draw_began:=Time.get_ticks_usec();base_draw_merge.flush(0.5,1);pool.publication_finished(draw_began)
	phase_began=FrameProfile.begin()
	apply_poses()
	combat.update(delta,desired)
	for id in motion.objects:
		motion.objects[id].visualAnimation=combat.visual_animation(int(id),int(motion.objects[id].animation))
		motion.finish_frame(id)
	FrameProfile.finish("world_poses",phase_began)
	if ready_for_admission() and not stats.has("terrain_admission_ms"): stats.terrain_admission_ms=(Time.get_ticks_usec()-opened_at)/1000.0
	if desired.has(controlled_id) and not stats.has("controlled_received_ms"): stats.controlled_received_ms=(Time.get_ticks_usec()-opened_at)/1000.0
	if ready_for_control() and not stats.has("playable_ms"):
		stats.playable_ms=(Time.get_ticks_usec()-opened_at)/1000.0
		stats.playable_pending_entities=desired.size()-installed.size()
		stats.playable_pending_batches=batches.size()
	if not borders_started and ready_for_control():start_area_border()
	# New actors need not wait for an unrelated older batch. Bound independent
	# owners and skip exact in-flight appearance keys to avoid duplicate work.
	if catalog==null or batches.size()>=3 and not continuous_base_stream:return
	var inflight: Dictionary={}
	for batch in batches:
		for id in batch.keys:
			if desired.has(id) and str(desired[id].key)==str(batch.keys[id]): inflight[id]=true
	var plan:=pending_plan(inflight)
	if batches.size()>=3:
		plan.actors.clear();plan.statics.clear()
	var actor_objects: Array=plan.actors; var static_objects: Array=plan.statics; var base_objects: Array=plan.base_statics; var actor_keys: Dictionary={}; var static_keys: Dictionary={}; var base_keys: Dictionary={}
	for object in actor_objects: actor_keys[int(object.id)]=desired[int(object.id)].key
	for object in static_objects: static_keys[int(object.id)]=desired[int(object.id)].key
	for object in base_objects: base_keys[int(object.id)]=desired[int(object.id)].key
	if not actor_objects.is_empty():
		var owner:=Creatures.new(); owner.use_skeleton=use_skeleton; owner.admission_parent=self; add_child(owner); owner.configure(catalog,pool,actor_objects,area_id,cache_path,controlled_id); batches.append({"owner":owner,"actors":true,"keys":actor_keys})
		if has_priority_origin: owner.set_priority_origin(priority_origin)
	if not base_objects.is_empty():
		var before_control:=not ready_for_control()
		stats.base_scenery_batches=int(stats.get("base_scenery_batches",0))+1
		stats.base_scenery_objects=int(stats.get("base_scenery_objects",0))+base_objects.size()
		if before_control:
			stats.entry_prefetch_batches=int(stats.get("entry_prefetch_batches",0))+1
			stats.entry_prefetch_objects=int(stats.get("entry_prefetch_objects",0))+base_objects.size()
		var active: Dictionary={}
		if continuous_base_stream:
			for batch in batches:
				if batch.get("base_scenery",false):active=batch;break
		if not active.is_empty():
			if active.owner.extend_base_wave(catalog,pool,base_objects,area_id,cache_path):
				active.keys.merge(base_keys);base_stream_schedule.reserved(base_objects,desired)
				stats.base_stream_refills=int(stats.get("base_stream_refills",0))+1
		else:
			var owner=base_scenery_stream(base_objects,before_control)
			if owner==null:return
			batches.append({"owner":owner,"actors":false,"keys":base_keys,"base_scenery":true})
			if continuous_base_stream:base_stream_schedule.reserved(base_objects,desired)
			if has_priority_origin:owner.set_priority_origin(priority_origin)
	if not static_objects.is_empty():
		if not ready_for_control():
			stats.entry_prefetch_batches=int(stats.get("entry_prefetch_batches",0))+1
			stats.entry_prefetch_objects=int(stats.get("entry_prefetch_objects",0))+static_objects.size()
		var owner:=Objects.new(); owner.admission_parent=self; add_child(owner); owner.configure(catalog,pool,static_objects,area_id,cache_path); batches.append({"owner":owner,"actors":false,"keys":static_keys})
		if has_priority_origin: owner.set_priority_origin(priority_origin)
func consume_stream_failure(batch: Dictionary,id: int,error: Dictionary) -> void:
	if not desired.has(id) or str(desired[id].key)!=str(batch.keys.get(id,"")):
		stats.stale_results+=1;return
	var detached:=error.duplicate(true)
	failed_objects[id]={"key":batch.keys[id],"error":detached};stats.failed_admissions+=1;note_base_scenery_state(id)
	if stats.object_errors.size()<512:stats.object_errors.append(detached)
	if id==controlled_id:stats.errors.append(detached)
func release_base_reservation(batch: Dictionary,id: int) -> void:
	if not continuous_base_stream or not batch.get("base_scenery",false):return
	batch.keys.erase(id);batch.owner.retire_base_row(id)
func base_admission_snapshot() -> Dictionary:
	# Detached POD. Counters are cumulative/high-water over this World lifetime.
	return {"enabled":base_admission_allowance,"mode":"timed" if base_admission_allowance else "ordinary","counter_scope":"world-lifetime-cumulative","extra_successful_base_admissions":int(stats.get("base_admission_extra_successes",0)) if base_admission_allowance else 0,"gauge_scope":"world-lifetime-high-water","max_base_admissions_per_callback":int(stats.get("base_admission_max_base_adoptions",0)) if base_admission_allowance else 0}
func extra_base_admission_allowed(candidate: Dictionary,base_adopted: int) -> bool:
	if not base_admission_allowance or maximum_adoptions_per_frame<=0 or base_adopted>=64:return false
	var batch: Dictionary=candidate.get("batch",{})
	if not batch.get("base_scenery",false) or batch.get("actors",false):return false
	var id:=int(candidate.get("id",-1))
	if not desired.has(id) or str(desired[id].key)!=str(batch.get("keys",{}).get(id,"")):return false
	# The batch tag alone cannot accelerate an object whose live usability,
	# provenance, area or classification changed without a new model key.
	return bool(BaseScenery.classify(desired[id].object,area_id).base)
func base_scenery_stream(objects: Array,before_control: bool):
	if reuse_base_scenery_owner and is_instance_valid(retained_base_owner):
		if retained_base_owner.get_parent()!=self or retained_base_owner.admission_parent!=self:
			stats.errors.append("Retained base scenery owner belongs to another World");return null
		if not retained_base_owner.wave_parked:
			stats.errors.append("Retained base scenery owner still has an active wave");return null
		if retained_base_generation==generation and retained_base_owner.can_resume_wave(catalog,pool,objects,area_id,cache_path):
			# Four is the unchanged fresh ObjectStream default after control.
			retained_base_owner.maximum_asset_workers=entry_base_workers if before_control else 4
			if retained_base_owner.resume_wave(catalog,pool,objects,area_id,cache_path):
				stats.base_owner_reuses=int(stats.get("base_owner_reuses",0))+1;return retained_base_owner
		stats.base_owner_reuse_refusals=int(stats.get("base_owner_reuse_refusals",0))+1
		close_retained_base_owner()
	var owner:=Objects.new()
	if before_control:owner.maximum_asset_workers=entry_base_workers
	owner.admission_parent=self;add_child(owner);owner.configure(catalog,pool,objects,area_id,cache_path)
	if reuse_base_scenery_owner:retained_base_owner=owner;retained_base_generation=generation
	stats.base_owner_creations=int(stats.get("base_owner_creations",0))+1
	return owner
func finish_stream_owner(batch: Dictionary) -> void:
	var owner=batch.owner;var close_began:=Time.get_ticks_usec()
	var parked:=false
	if reuse_base_scenery_owner and batch.get("base_scenery",false) and owner==retained_base_owner:
		var payload: Dictionary=owner.park_wave();parked=owner.wave_parked
		if parked:data_retirement.retire(payload);stats.base_owner_parks=int(stats.get("base_owner_parks",0))+1
	if not parked:
		data_retirement.retire(owner.detach_prepared_data());owner.close();owner.queue_free()
		if owner==retained_base_owner:retained_base_owner=null;retained_base_generation=-1
	batches.erase(batch);stats.completed_batches+=1;adoption_timing("close",close_began)
func close_retained_base_owner() -> void:
	if is_instance_valid(retained_base_owner) and not retained_base_owner.closed:
		data_retirement.retire(retained_base_owner.detach_prepared_data());retained_base_owner.close();retained_base_owner.queue_free()
	retained_base_owner=null;retained_base_generation=-1
func pending_plan(inflight: Dictionary) -> Dictionary:
	var plan:={"actors":[],"statics":[],"base_statics":[]}
	if closed or retiring or not stats.errors.is_empty():return plan
	# A newly available/changed controlled appearance owns the next request.
	if desired.has(controlled_id) and installed.get(controlled_id,"")!=desired[controlled_id].key and not inflight.has(controlled_id):
		plan.actors.append(desired[controlled_id].object);return plan
	var before_control:=not ready_for_control()
	var background_owners:=0;var base_owner_active:=false
	for batch in batches:
		if batch.get("base_scenery",false):base_owner_active=true
		if not (batch.get("actors",false) and batch.get("keys",{}).has(controlled_id)):background_owners+=1
	var owner_slots:=2-background_owners
	if continuous_base_stream:
		return pending_continuous_plan(inflight,before_control,owner_slots)
	if owner_slots<=0:return plan
	# A running base owner cannot admit another base wave. With no live work
	# at the last canonical revision, there is nothing to rescan until a
	# receive/removal boundary or that owner finishing. No second ID store.
	if base_owner_active and (before_control or base_live_idle_revision==base_live_revision):return plan
	var origin:=Vector3.ZERO
	if before_control:
		if not entry_prefetch_enabled:return plan
		if has_priority_origin and priority_origin.is_finite():origin=priority_origin
		elif desired.has(controlled_id):
			var controlled_pose:=object_pose(desired[controlled_id].object)
			if controlled_pose.is_empty():return plan
			origin=controlled_pose.position
		else:return plan
	else:origin=instances[controlled_id].position
	var base_candidates: Array=[];var live_candidates: Array=[]
	for id in desired:
		var wanted: Dictionary=desired[id]
		var classification: Dictionary=BaseScenery.classify(wanted.object,area_id)
		if str(installed.get(id,""))==str(wanted.key) or inflight.has(id):continue
		if failed_objects.has(id) and str(failed_objects[id].key)==str(wanted.key):continue
		var placement:=object_pose(wanted.object)
		if placement.is_empty():continue
		var entry:={"object":wanted.object,"distance":origin.distance_squared_to(placement.position)}
		if classification.base:base_candidates.append(entry)
		elif not before_control:live_candidates.append(entry)
	if not before_control and live_candidates.is_empty():base_live_idle_revision=base_live_revision
	var nearer:=func(a,b):return a.distance<b.distance or (a.distance==b.distance and int(a.object.id)<int(b.object.id))
	base_candidates.sort_custom(nearer)
	# One continuing base owner prevents bursty worker/owner growth. This lane
	# is not capped to one initial wave and has no permanent distance cutoff.
	if not base_owner_active and not base_candidates.is_empty():
		var base_limit:=mini(maximum_static_batch,maximum_base_static_batch)
		for entry in base_candidates.slice(0,maxi(0,base_limit)):plan.base_statics.append(entry.object)
		if not plan.base_statics.is_empty():owner_slots-=1
	if before_control or owner_slots<=0:return plan
	# Remaining live entities retain their shared nearest-ready wave, using
	# only the spare background capacity. Base scenery never rejoins this wave.
	live_candidates.sort_custom(nearer)
	for entry in live_candidates.slice(0,maximum_stream_wave):
		var actors: bool=int(entry.object.objectType) in [5,6]
		var group: Array=plan.actors if actors else plan.statics
		var limit:=maximum_actor_batch if actors else maximum_static_batch
		if group.size()>=limit or group.is_empty() and owner_slots<=0:continue
		if group.is_empty():owner_slots-=1
		group.append(entry.object)
	return plan
func pending_continuous_plan(inflight: Dictionary,before_control: bool,owner_slots: int) -> Dictionary:
	var plan:={"actors":[],"statics":[],"base_statics":[]}
	var active: Dictionary={}
	for batch in batches:
		if batch.get("base_scenery",false):active=batch;break
	if before_control and (not entry_prefetch_enabled or not has_priority_origin):return plan
	# update_stream_priority already owns the two-metre refresh threshold.
	# Using the raw interpolated actor position here would re-sort all pending
	# metadata for every tiny movement despite that existing throttle.
	var origin: Vector3=priority_origin if has_priority_origin else instances[controlled_id].position
	base_stream_schedule.set_origin(origin)
	var capacity:=maxi(0,mini(64,mini(maximum_static_batch,maximum_base_static_batch)))
	if not active.is_empty():
		active.owner.maximum_asset_workers=entry_base_workers if before_control else 4
		active.owner.assets.maximum_workers=maxi(1,active.owner.maximum_asset_workers)
		capacity=maxi(0,capacity-active.keys.size())
		if not active.owner.continuous_scope_current(catalog,pool,area_id,cache_path):capacity=0
	elif owner_slots<=0:capacity=0
	plan.base_statics=base_stream_schedule.peek(capacity,desired,inflight,installed,failed_objects)
	if active.is_empty() and not plan.base_statics.is_empty():owner_slots-=1
	# Only live-entity planning needs the legacy registry scan, and only after a
	# receive/removal revision or live-owner completion, never on each base refill.
	if before_control or owner_slots<=0 or not active.is_empty() and base_live_idle_revision==base_live_revision:return plan
	var candidates: Array=[]
	for id in desired:
		var wanted: Dictionary=desired[id]
		var flags:=int(wanted.get("base_progress_flags",0))
		if flags&1 and not flags&64 or str(installed.get(id,""))==str(wanted.key) or inflight.has(id):continue
		if failed_objects.has(id) and str(failed_objects[id].key)==str(wanted.key):continue
		var pose:=object_pose(wanted.object)
		if not pose.is_empty():candidates.append({"object":wanted.object,"distance":origin.distance_squared_to(pose.position)})
	if candidates.is_empty():base_live_idle_revision=base_live_revision
	candidates.sort_custom(func(a,b):return a.distance<b.distance or (a.distance==b.distance and int(a.object.id)<int(b.object.id)))
	for entry in candidates.slice(0,maximum_stream_wave):
		var actors: bool=int(entry.object.objectType) in [5,6]
		var group: Array=plan.actors if actors else plan.statics
		var limit:=maximum_actor_batch if actors else maximum_static_batch
		if group.size()>=limit or group.is_empty() and owner_slots<=0:continue
		if group.is_empty():owner_slots-=1
		group.append(entry.object)
	return plan
func base_scenery_contribution(id: int,wanted: Dictionary) -> Dictionary:
	var classification:=BaseScenery.classify(wanted.object,area_id);var flags:=0;var reason:=""
	if classification.base:
		flags=1
		if str(installed.get(id,""))==str(wanted.key) and (instances.has(id) or hidden.has(id)):flags|=2|(8 if hidden.has(id) else 4)
		elif failed_objects.has(id) and str(failed_objects[id].key)==str(wanted.key):flags|=16
	elif int(wanted.object.get("objectType",0))==9 and not classification.available:
		flags=32
		if wanted.object.has("staticState"):flags|=1|64;reason=str(classification.reason)
	return {"flags":flags,"reason":reason}
func base_scenery_adjust(flags: int,reason: String,amount: int) -> void:
	for index in BASE_SCENERY_PROGRESS_FIELDS.size():
		if flags&(1<<index):base_scenery_progress_counts[BASE_SCENERY_PROGRESS_FIELDS[index]]+=amount
	if not reason.is_empty():
		var reasons: Dictionary=base_scenery_progress_counts.unresolved_reasons
		var count:=int(reasons.get(reason,0))+amount
		if count==0:reasons.erase(reason)
		else:reasons[reason]=count
func base_scenery_stamp_slot(id: int,wanted: Dictionary) -> void:
	var contribution:=base_scenery_contribution(id,wanted)
	wanted.base_progress_flags=contribution.flags;wanted.base_progress_reason=contribution.reason
	if continuous_base_stream and int(contribution.flags)&(2|16):base_stream_schedule.erase(id)
func base_stream_note_desired(id: int,wanted: Dictionary) -> void:
	if not continuous_base_stream:return
	var flags:=int(wanted.get("base_progress_flags",0))
	if flags&1 and not flags&64 and str(installed.get(id,""))!=str(wanted.key) and not (failed_objects.has(id) and str(failed_objects[id].key)==str(wanted.key)):
		var pose:=object_pose(wanted.object)
		if not pose.is_empty():base_stream_schedule.update(id,str(wanted.key),pose.position)
	else:base_stream_schedule.erase(id)
func base_scenery_population_tag(wanted: Dictionary) -> Array:
	if wanted.is_empty():return []
	var contribution: Dictionary={"flags":wanted.base_progress_flags,"reason":wanted.base_progress_reason} if wanted.has("base_progress_flags") else base_scenery_contribution(int(wanted.object.id),wanted)
	var flags:=int(contribution.flags)&(1|32|64)
	return [flags,contribution.reason,str(wanted.key)] if flags!=0 else []
func base_scenery_note_population_change(before: Dictionary,after: Dictionary) -> void:
	if base_scenery_population_tag(before)!=base_scenery_population_tag(after):base_scenery_population_changed=true
func base_scenery_replace_desired(id: int,wanted: Dictionary) -> void:
	var prior: Dictionary=desired.get(id,{})
	base_scenery_stamp_slot(id,wanted);base_scenery_note_population_change(prior,wanted)
	base_stream_note_desired(id,wanted)
	if not base_scenery_rebuild_pending:base_scenery_adjust(int(prior.get("base_progress_flags",0)),str(prior.get("base_progress_reason","")),-1)
	desired[id]=wanted
	if not base_scenery_rebuild_pending:base_scenery_adjust(int(wanted.base_progress_flags),str(wanted.base_progress_reason),1)
func base_scenery_forget_desired(id: int) -> void:
	if continuous_base_stream:base_stream_schedule.erase(id)
	if not desired.has(id):return
	var prior: Dictionary=desired[id];base_scenery_note_population_change(prior,{})
	if not base_scenery_rebuild_pending:base_scenery_adjust(int(prior.get("base_progress_flags",0)),str(prior.get("base_progress_reason","")),-1)
	desired.erase(id)
func base_scenery_forget_omitted(id: int) -> void:
	if not base_scenery_omitted.has(id):return
	if not base_scenery_rebuild_pending:
		base_scenery_adjust(1|64|128,str(base_scenery_omitted[id]),-1);base_scenery_population_changed=true
	base_scenery_omitted.erase(id)
func note_omitted_base_scenery(object: Dictionary) -> void:
	var reason:=BaseScenery.omitted_reason(object,area_id)
	if reason.is_empty():return
	# Unknown identities remain sticky until the existing full replacement.
	if not BaseScenery.integer(object.get("id"),0,4294967295):
		if not base_scenery_unaddressable_omitted and not base_scenery_rebuild_pending:base_scenery_population_changed=true
		base_scenery_unaddressable_omitted=true;return
	var id:=int(object.id)
	if base_scenery_omitted.get(id)==reason:return
	base_scenery_forget_omitted(id);base_scenery_omitted[id]=reason
	if not base_scenery_rebuild_pending:base_scenery_adjust(1|64|128,reason,1);base_scenery_population_changed=true
func base_scenery_begin_boundary(full: bool=false) -> void:
	base_scenery_boundary_depth+=1;base_scenery_progress_dirty=true
	if full:base_scenery_rebuild_pending=true
func base_scenery_end_boundary() -> void:
	base_scenery_boundary_depth-=1
	if base_scenery_boundary_depth==0:base_scenery_commit_progress()
func base_scenery_refresh_slot(id: int) -> void:
	if base_scenery_rebuild_pending or not desired.has(id):return
	var wanted: Dictionary=desired[id];var prior:=base_scenery_population_tag(wanted)
	base_scenery_adjust(int(wanted.get("base_progress_flags",0)),str(wanted.get("base_progress_reason","")),-1)
	base_scenery_stamp_slot(id,wanted)
	if prior!=base_scenery_population_tag(wanted):base_scenery_population_changed=true
	base_scenery_adjust(int(wanted.base_progress_flags),str(wanted.base_progress_reason),1)
func note_base_scenery_state(id: int) -> void:
	base_scenery_progress_dirty=true;base_scenery_refresh_slot(id)
	if base_scenery_boundary_depth==0:base_scenery_commit_progress()
func note_base_scenery_publication(id: int) -> void:note_base_scenery_state(id)
func base_scenery_commit_progress() -> void:
	if base_scenery_rebuild_pending:
		for field in BASE_SCENERY_PROGRESS_FIELDS:base_scenery_progress_counts[field]=0
		base_scenery_progress_counts.unresolved_reasons={}
		for id in desired:
			var wanted: Dictionary=desired[id];base_scenery_stamp_slot(int(id),wanted)
			base_scenery_adjust(int(wanted.base_progress_flags),str(wanted.base_progress_reason),1)
		for reason in base_scenery_omitted.values():base_scenery_adjust(1|64|128,str(reason),1)
		base_scenery_rebuild_pending=false;stats.base_scenery_scans=int(stats.get("base_scenery_scans",0))+1
	if base_scenery_population_changed:
		base_scenery_population_revision+=1;base_scenery_population_changed=false
		base_scenery_known_complete_since_ms=null;base_scenery_complete_since_ms=null
	base_scenery_progress_dirty=false
	if closed or retiring or not base_scenery_population_known:return
	var progress: Dictionary=base_scenery_progress_counts.duplicate(true);var elapsed:=(Time.get_ticks_usec()-opened_at)/1000.0
	progress.pending=progress.expected-progress.resolved
	progress.available=true;progress.population_revision=base_scenery_population_revision
	progress.known_base_complete=not base_scenery_unaddressable_omitted and stats.errors.is_empty() and progress.pending==0 and progress.failed==0 and progress.unresolved_static==0
	progress.classification_complete=progress.unknown_placeables==0
	progress.complete=progress.known_base_complete and progress.classification_complete
	progress.scope="Current received ClientArea static provenance; unknown placeable provenance is explicit"
	progress.completion_semantics="First client-known population milestone; later received population changes can reopen completion"
	if progress.resolved>0 and not stats.has("base_scenery_first_resolved_ms"):stats.base_scenery_first_resolved_ms=elapsed
	if progress.known_base_complete:
		if base_scenery_known_complete_since_ms==null:base_scenery_known_complete_since_ms=elapsed
		if not stats.has("base_scenery_first_known_complete_ms"):
			stats.base_scenery_first_known_complete_ms=elapsed;stats.base_scenery_first_known_complete_population_revision=base_scenery_population_revision;stats.base_scenery_first_known_complete_expected=progress.expected
	else:base_scenery_known_complete_since_ms=null
	if progress.complete:
		if base_scenery_complete_since_ms==null:base_scenery_complete_since_ms=elapsed
		if not stats.has("base_scenery_first_complete_ms"):
			stats.base_scenery_first_complete_ms=elapsed;stats.base_scenery_first_complete_population_revision=base_scenery_population_revision;stats.base_scenery_first_complete_expected=progress.expected
	else:base_scenery_complete_since_ms=null
	progress.known_complete_since_ms=base_scenery_known_complete_since_ms;progress.complete_since_ms=base_scenery_complete_since_ms
	stats.base_scenery_progress=progress;stats.base_scenery_boundary_updates=int(stats.get("base_scenery_boundary_updates",0))+1
func base_scenery_snapshot() -> Dictionary:
	var result:={"available":false,"first_resolved_ms":stats.get("base_scenery_first_resolved_ms"),"first_known_complete_ms":stats.get("base_scenery_first_known_complete_ms"),"first_complete_ms":stats.get("base_scenery_first_complete_ms"),"population_revision":base_scenery_population_revision,"first_known_complete_population_revision":stats.get("base_scenery_first_known_complete_population_revision"),"first_known_complete_expected":stats.get("base_scenery_first_known_complete_expected"),"first_complete_population_revision":stats.get("base_scenery_first_complete_population_revision"),"first_complete_expected":stats.get("base_scenery_first_complete_expected")}
	if closed or retiring:result.reason="retired-world";return result
	if not stats.errors.is_empty():result.reason="scope-errors";return result
	if not base_scenery_population_known:result.reason="population-unavailable";return result
	if base_scenery_unaddressable_omitted:result.reason="static-population-identity-unavailable";return result
	if base_scenery_progress_dirty or base_scenery_boundary_depth>0:result.reason="boundary-in-progress";return result
	result.merge(stats.get("base_scenery_progress",{}),true)
	return result
func ready_for_control() -> bool:
	return ready_for_admission() and instances.has(controlled_id) and (not is_instance_valid(references) or references.ready_for(instances[controlled_id]))
func ready_for_admission() -> bool:
	# Native 4/3 releases initial player replication. Waiting for the player
	# before acknowledging the prepared area deadlocks a first admission.
	return not closed and not retiring and is_instance_valid(terrain) and terrain.done and terrain.diagnostics.errors.is_empty() and is_instance_valid(surface) and surface.ready() and stats.errors.is_empty()
func asset_owners() -> Array:
	var owners: Array=[]
	for owner in [terrain,surface,references,drive_collision,effects,native_sky,placeable_lights,borders]:
		if is_instance_valid(owner) and owner.get("assets") is Assets: owners.append(owner.assets)
	if is_instance_valid(effects) and effects.creature_voices!=null and is_instance_valid(effects.creature_voices.assets): owners.append(effects.creature_voices.assets)
	for batch in batches:
		if is_instance_valid(batch.owner) and batch.owner.get("assets") is Assets: owners.append(batch.owner.assets)
	if is_instance_valid(retained_base_owner) and retained_base_owner.get("assets") is Assets and not owners.has(retained_base_owner.assets):owners.append(retained_base_owner.assets)
	return owners
func worker_tasks() -> Array:
	var tasks: Array=[]
	if is_instance_valid(base_draw_merge):tasks.append_array(base_draw_merge.worker_tasks())
	for owner in asset_owners(): tasks.append_array(owner.running.values())
	if is_instance_valid(terrain) and terrain.definition_task>=0: tasks.append(int(terrain.definition_task))
	if is_instance_valid(terrain) and is_instance_valid(terrain.static_scenery_batches) and terrain.static_scenery_batches.has_method("worker_tasks"):
		for task in terrain.static_scenery_batches.worker_tasks():
			if not tasks.has(task):tasks.append(task)
	if is_instance_valid(borders):
		for task in borders.worker_tasks():
			if not tasks.has(task):tasks.append(task)
	return tasks
func begin_retirement() -> void:
	preload("res://systems/native_render/native_surface_state.gd").retire(self)
	if is_instance_valid(model_environment): model_environment.close()
	if is_instance_valid(native_sky): native_sky.stop()
	if is_instance_valid(borders):borders.begin_retirement()
	if closed or retiring: return
	var began:=FrameProfile.begin()
	retiring=true
	if is_instance_valid(base_draw_merge):base_draw_merge.retire_scope()
	if is_instance_valid(terrain) and is_instance_valid(terrain.static_scenery_batches) and terrain.static_scenery_batches.has_method("retire_scope"):terrain.static_scenery_batches.retire_scope()
	if is_instance_valid(drive_collision) and drive_collision.has_method("retire_index"):drive_collision.retire_index()
	if is_instance_valid(focus_lighting): focus_lighting.close()
	var disable_began:=Time.get_ticks_usec()
	hide()
	FrameProfile.finish("retirement_hide_scene_ms",disable_began)
	retirement_disable_timings.hide_ms=(Time.get_ticks_usec()-disable_began)/1000.0
	disable_began=Time.get_ticks_usec()
	process_mode=Node.PROCESS_MODE_DISABLED
	FrameProfile.finish("retirement_disable_processing_ms",disable_began)
	retirement_disable_timings.processing_ms=(Time.get_ticks_usec()-disable_began)/1000.0
	FrameProfile.finish("retirement_disable_scene_ms",began); began=FrameProfile.begin()
	if is_instance_valid(effects) and effects.creature_voices!=null: effects.creature_voices.begin_retirement()
	if is_instance_valid(effects) and is_instance_valid(effects.world_audio): effects.world_audio.close()
	FrameProfile.finish("retirement_stop_audio_ms",began); began=FrameProfile.begin()
	# Root callbacks refer to the current registry. A deferred old-world close
	# must not remove IDs that the next registry may already have admitted.
	for event in [instance_ready,instance_removed,instance_state_changed]:
		for binding in event.get_connections(): event.disconnect(binding.callable)
	FrameProfile.finish("retirement_disconnect_ms",began); began=FrameProfile.begin()
	# Native bodies inherit area processing and use DISABLE_MODE_REMOVE. Their
	# physics-space removal is synchronous with the area's disabled notification.
	# The redundant scan is retained only as a diagnostic reference.
	if retirement_physics_scan:
		for body in find_children("*","CollisionObject3D",true,false): body.collision_layer=0; body.collision_mask=0
	FrameProfile.finish("retirement_collision_scan_ms",began); began=FrameProfile.begin()
	# Running jobs own only private data and are kept alive until their join.
	# Pending jobs never start; incrementing epochs also rejects old results.
	for owner in asset_owners(): owner.retire_scope()
	FrameProfile.finish("retirement_cancel_assets_ms",began)
func snapshot(details: bool=true) -> Dictionary:
	var state: Dictionary={}
	state.base_scenery=base_scenery_snapshot()
	state.base_admission=base_admission_snapshot()
	state.base_draw_merge=base_draw_merge.snapshot() if is_instance_valid(base_draw_merge) else {"enabled":false,"mode":"individual"}
	state.continuous_base_stream={"enabled":continuous_base_stream,"mode":"continuous" if continuous_base_stream else "waves","reservation_limit":mini(64,mini(maximum_static_batch,maximum_base_static_batch)),"refills":int(stats.get("base_stream_refills",0)),"schedule":base_stream_schedule.snapshot()}
	for field in stats:
		if field=="base_scenery_progress":continue # Internal cached counts; state.base_scenery is the sole current view.
		if not details and field in ["batches","admissions","object_errors"]: continue
		var value: Variant=stats[field]
		state[field]=value.duplicate(details) if value is Array or value is Dictionary else value
	var skins:=0; var prepared_skins:=0; var main_skins:=0; var pose_frames:=0; var clips:=0; var indexed_clips:=0; var clip_metadata:=0; var missing: Array=[]
	for id in instances:
		if not desired.has(id) or int(desired[id].object.objectType)!=5: continue
		var rig_state: Dictionary=instances[id].rigs.stats
		skins+=int(rig_state.skin_meshes); pose_frames+=int(rig_state.pose_frames); clips+=int(rig_state.clips)
		prepared_skins+=int(rig_state.get("skin_prepared_meshes",0)); main_skins+=int(rig_state.get("skin_main_meshes",0))
		indexed_clips+=int(rig_state.get("indexed_clip_models",0)); clip_metadata+=int(rig_state.get("indexed_clip_metadata",0))
		missing.append_array(rig_state.missing_requested_clips)
	state.actor_rigs={"skin_meshes":skins,"skin_prepared_meshes":prepared_skins,"skin_main_meshes":main_skins,"pose_frames":pose_frames,"clips":clips,"indexed_clip_models":indexed_clips,"indexed_clip_metadata":clip_metadata,"missing_requested_clips":missing}
	state.clip_preparation={"enabled":preload("res://systems/model_rigs.gd").configured_prepared_clips(),"revision":"actor-rig-emitter-v10-clip-index","policy":"Shared immutable clip indices/controller definitions; private requested Animation resources, events, libraries and playback clocks"}
	var snapshot_began:=FrameProfile.begin()
	state.combat=combat.snapshot() if is_instance_valid(combat) else {}
	state.effects=effects.sample() if is_instance_valid(effects) else {}
	state.focus_lighting=focus_lighting.snapshot() if is_instance_valid(focus_lighting) else {}
	var shadow_reference: WeakRef=get_meta("native_point_shadow_budget",null)
	var shadow_owner: Node=shadow_reference.get_ref() if shadow_reference!=null else null
	state.point_shadows=shadow_owner.snapshot() if is_instance_valid(shadow_owner) else {}
	state.model_environment=model_environment.snapshot() if is_instance_valid(model_environment) else {}
	state.sky=native_sky.snapshot() if is_instance_valid(native_sky) else {}
	state.placeable_lights=placeable_lights.snapshot() if is_instance_valid(placeable_lights) else {}
	FrameProfile.finish("snapshot_combat_effects",snapshot_began); snapshot_began=FrameProfile.begin()
	state.native_particles=particle_metrics.snapshot()
	if is_instance_valid(particle_stream_group): state.native_particle_stream=particle_stream_group.snapshot()
	state.static_collision_index=static_collision_index.snapshot()
	state.data_retirement=data_retirement.snapshot() if is_instance_valid(data_retirement) else {}
	state.ancestor_preparation=Assets.Ancestors.snapshot()
	state.raster_conversion=Assets.Raster.Conversion.snapshot()
	state.ascii_key_write="typed" if Assets.ActorModel.configured_typed_ascii_keys() else "arrays"
	state.prepared_cache_writes=Cache.configured_writes_enabled()
	state.prepared_cache_lock="path" if Cache.new().path_publication else "global"
	state.prepared_write_queue=Assets.CacheWrites.snapshot()
	state.skin_preparation={"enabled":Assets.SkinPreparation.configured_enabled(),"revision":Assets.SkinPreparation.REVISION,"scope":"Immutable worker skin streams; per-instance skeleton/bind validation and GPU publication stay main"}
	state.retirement_physics_scan=retirement_physics_scan
	state.native_point_wind=point_wind.snapshot() if is_instance_valid(point_wind) else {}
	state.drive_collision=drive_collision.snapshot() if is_instance_valid(drive_collision) else {}
	state.drive_collision_configuration=drive_collision_selection_snapshot()
	state.drive_collision_route=str(state.drive_collision_configuration.effective)
	state.native_references=references.snapshot() if is_instance_valid(references) else {}
	state.failed_objects=failed_objects.duplicate(true)
	state.streaming_priority={"player_centered":has_priority_origin,"origin":[priority_origin.x,priority_origin.y,priority_origin.z],"wave_limit":maximum_stream_wave,"base_scenery_wave_limit":mini(maximum_static_batch,maximum_base_static_batch),"entry_prefetch":{"enabled":entry_prefetch_enabled,"limit":entry_prefetch_limit,"radius":entry_prefetch_radius},"policy":"controlled actor first, then nearest ready placements across model groups"}
	state.object_visuals_complete=failed_objects.is_empty() and stats.errors.is_empty() and instances.size()+hidden.size()==desired.size() and batches.is_empty() and base_scenery_omitted.is_empty() and not base_scenery_unaddressable_omitted
	state.surface=surface.snapshot() if is_instance_valid(surface) else {}
	FrameProfile.finish("snapshot_scene_metadata",snapshot_began); snapshot_began=FrameProfile.begin()
	state.preparation_cache=catalog.preparation_cache().snapshot() if catalog!=null and catalog.has_method("preparation_cache") else {}
	state.decoded_cache=catalog.decoded_cache().snapshot() if catalog!=null and catalog.has_method("decoded_cache") else {}
	FrameProfile.finish("snapshot_preparation_cache",snapshot_began)
	if is_instance_valid(surface): state.errors.append_array(surface.stats.errors)
	state.merge({"area_id":area_id,"generation":generation,"controlled_id":controlled_id,"entities":instances.size(),"hidden":hidden.size(),"desired":desired.size(),"pending_batches":batches.size(),"admission_ready":ready_for_admission(),"ready":ready_for_control(),"terrain":terrain.snapshot() if is_instance_valid(terrain) else {},"pool":pool.snapshot(),"owns_pool":owns_pool,"native_rendering":true,"full_migration":false})
	state.area_border=borders.snapshot() if is_instance_valid(borders) else {"started":false,"enabled":tile_borders_enabled,"area_disabled":border_disabled}
	return state
func close() -> void:
	if is_instance_valid(base_draw_merge):base_draw_merge.close()
	preload("res://systems/native_render/native_surface_state.gd").retire(self)
	if is_instance_valid(model_environment): model_environment.close()
	if is_instance_valid(native_sky): native_sky.close()
	if closed: return
	closed=true
	if is_instance_valid(focus_lighting): focus_lighting.close()
	if is_instance_valid(particle_stream_group): particle_stream_group.close()
	var close_began:=FrameProfile.begin()
	if is_instance_valid(combat): combat.close()
	if is_instance_valid(effects): effects.close()
	if is_instance_valid(placeable_lights): placeable_lights.close()
	FrameProfile.finish("retirement_effects_close",close_began); close_began=FrameProfile.begin()
	if is_instance_valid(references): references.close()
	FrameProfile.finish("retirement_references_close",close_began); close_began=FrameProfile.begin()
	if is_instance_valid(terrain): terrain.close()
	if is_instance_valid(borders):borders.close()
	if is_instance_valid(surface): surface.close()
	if is_instance_valid(drive_collision): drive_collision.close()
	FrameProfile.finish("retirement_terrain_close",close_began); close_began=FrameProfile.begin()
	motion.height_query=Callable()
	motion.facing_target_query=Callable()
	for batch in batches:
		if is_instance_valid(batch.owner): data_retirement.retire(batch.owner.detach_prepared_data()); batch.owner.close(); batch.owner.queue_free()
	batches.clear()
	close_retained_base_owner()
	for id in instances.keys(): remove_instance(id)
	if is_instance_valid(point_wind): point_wind.close()
	particle_metrics.close()
	desired.clear(); installed.clear(); animations.clear(); failed_objects.clear(); motion.objects.clear(); motion_revisions.clear()
	base_stream_schedule.clear()
	static_collision_index.clear()
	if owns_pool: pool.clear()
	if is_instance_valid(data_retirement) and not retired_data.is_empty():
		data_retirement.defer_release(retired_data); retired_data={}
	if owns_data_retirement and is_instance_valid(data_retirement): data_retirement.close()
	catalog=null
	FrameProfile.finish("retirement_other_close",close_began)
func _exit_tree() -> void: close()
