extends Node3D
# Original protocol state in; original native resource loaders and private scene
# owners out. No scene-transfer or renderer-prepared metadata is accepted.
const Terrain=preload("res://systems/native_render/area_stream.gd")
const Objects=preload("res://systems/native_render/object_stream.gd")
const Creatures=preload("res://systems/native_render/creature_stream.gd")
const Pool=preload("res://systems/native_render/resource_pool.gd")
const Cache=preload("res://systems/native_data/prepared_cache.gd")
const Motion=preload("res://systems/network_motion.gd")
const Surface=preload("res://systems/native_render/terrain_surface.gd")
const FrameProfile=preload("res://systems/native_render/frame_profile.gd")
const ParticleRandom=preload("res://systems/native_render/particle_random.gd")
const ReferenceAssets=preload("res://systems/native_render/reference_assets.gd")
const Assets=preload("res://systems/native_data/asset_service.gd")
const PointWind=preload("res://systems/native_render/scene_point_wind.gd")
const ParticleMetrics=preload("res://systems/native_render/particle_metrics.gd")
const SceneHit=preload("res://systems/native_render/projectile_scene.gd")
const Priority=preload("res://systems/native_render/stream_priority.gd")
signal instance_ready(id: int,source: Dictionary,instance)
signal instance_removed(id: int)
signal instance_state_changed(id: int,source: Dictionary)
var pool:=Pool.new()
var owns_pool:=true
var point_wind
var particle_metrics:=ParticleMetrics.new()
var catalog
var terrain
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
var motion:=Motion.new()
var motion_revisions: Dictionary={}
var cache_path:=""
var area_id:=-1
var generation:=-1
var controlled_id:=-1
func _init() -> void:
	motion.facing_target_query=motion_target_position
func motion_target_position(id: int) -> Variant:
	if closed or retiring or not desired.has(id): return null
	var source: Dictionary=desired[id].object
	if int(source.get("areaId",-1))!=area_id or source.get("replicationRemoved",false): return null
	if motion.objects.has(id): return motion.objects[id].position
	var point: Variant=source.get("replicated",{}).get("position")
	return Motion.vector(point) if point is Array and point.size()>=3 else null
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
var maximum_stream_wave:=64
var entry_prefetch_enabled:=true # One measured near-scenery wave; player request stays first.
var entry_prefetch_limit:=8
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
	for owner in [terrain,surface,references]:
		if is_instance_valid(owner): owner.set_priority_origin(value)
	for batch in batches:
		if is_instance_valid(batch.owner): batch.owner.set_priority_origin(value)
var adoption_budget_ms:=3.0
var maximum_adoptions_per_frame:=8
var data_retirement
var owns_data_retirement:=false
var drive_collision
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
	if shared_pool!=null: pool=shared_pool; owns_pool=false
	catalog=source; area_id=int(area.id); generation=epoch; cache_path=cache_directory
	opened_at=Time.get_ticks_usec()
	references=ReferenceAssets.new(); add_child(references); references.configure(catalog,pool,cache_path); set_meta("native_reference_hub",references)
	effects=preload("res://systems/native_render/effect_world.gd").new(); add_child(effects); effects.configure(self)
	# Selection shapes are lazy and instance eligibility is decided from the
	# latest server state, independently of immutable shared render resources.
	pool.picking=false
	terrain=Terrain.new(); terrain.use_terrain_batches=false; add_child(terrain)
	var entry_position: Variant=entry.get("position")
	if entry_position is Array and entry_position.size()==3:
		set_priority_origin(Vector3(float(entry_position[0]),float(entry_position[2]),-float(entry_position[1])))
	terrain.definition_ready.connect(func(value):
		surface=Surface.new(); add_child(surface); surface.configure(catalog,value,cache_path)
		if has_priority_origin: surface.set_priority_origin(priority_origin)
		motion.height_query=surface.height)
	terrain.open_network_area(catalog,area,pool,cache_path)
	drive_collision=preload("res://systems/native_render/drive_collision.gd").new(); add_child(drive_collision); drive_collision.configure(self,catalog,cache_path)
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
	var clear: Callable=drive_collision.query(id)
	if not clear.is_valid(): return {}
	if heading>=0:
		state.orientation=planner.wire_facing(heading); state.targetOrientation=state.orientation; state.previewFacing=state.orientation
	var plan: Dictionary=planner.plan(state.position,state.orientation,float(state.walkRate),float(state.runRate),flags)
	var path: Dictionary=planner.path(state.position,plan.target,state.render,clear)
	if not path.is_empty(): plan.factor=path.factor
	motion.preview(id,plan,path.get("target"))
	FrameProfile.finish("keyboard_preview",began)
	return path if not path.is_empty() else {"blocked":true}
func end_drive(id: int) -> void:
	if motion.objects.has(id): motion.objects[id].driveHeld=false
func signature(object: Dictionary) -> String:
	var state: Dictionary=object.get("replicated",{}); var fixed: Dictionary=object.get("staticState",object.get("lightState",{}))
	return Cache.digest(var_to_bytes([object.get("objectType"),object.get("appearance",{}),object.get("item",state.get("item",{})),state.get("appearance",fixed.get("appearance")),state.get("doorType"),state.get("genericType")]))
func receive(objects: Array,controlled: int) -> void:
	if closed or retiring: return
	controlled_id=controlled; var current: Dictionary={}
	for object in objects:
		if int(object.get("areaId",-1))!=area_id or object.get("replicationRemoved",false) or int(object.get("objectType",0)) not in [5,6,9,10]: continue
		if object_pose(object).is_empty(): continue
		current[int(object.id)]={"object":object,"key":signature(object)}
		if int(object.objectType)==5 and not motion.objects.has(int(object.id)):
			# Bootstrap from raw replication once. Repeated full registry snapshots
			# must not restart a path already advanced by the native frame owner.
			var state: Dictionary=object.get("replicated",{})
			motion.observe(int(object.id),state,true,state)
		observe_facing_target(object)
	for id in desired:
		if not current.has(id): combat.forget(int(id),true)
	desired=current
	for id in instances:
		if desired.has(id): sync_combat(int(id))
	if is_instance_valid(drive_collision): drive_collision.warm_dirty=true
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
func receive_delta(objects: Array,removed: Array,controlled: int) -> void:
	if closed or retiring: return
	var receive_began:=FrameProfile.begin()
	controlled_id=controlled
	if is_instance_valid(drive_collision) and (not removed.is_empty() or objects.any(func(object):return int(object.get("objectType",0)) in [9,10])): drive_collision.warm_dirty=true
	var remove: Dictionary={}
	for id in removed: remove[int(id)]=true
	for object in objects:
		var id:=int(object.id)
		if int(object.get("areaId",-1))!=area_id or object.get("replicationRemoved",false) or int(object.get("objectType",0)) not in [5,6,9,10] or object_pose(object).is_empty(): remove[id]=true; continue
		var key:=signature(object); desired[id]={"object":object,"key":key}; remove.erase(id)
		if instances.has(id): sync_combat(id)
		if failed_objects.has(id) and str(failed_objects[id].key)!=key: failed_objects.erase(id)
		if int(object.objectType)==5 and not motion.objects.has(id):
			var state: Dictionary=object.get("replicated",{}); motion.observe(id,state,true,state)
		observe_facing_target(object)
		apply_pose(id)
		if instances.has(id): instance_state_changed.emit(id,object)
	for id in remove:
		combat.forget(int(id),true)
		desired.erase(id); failed_objects.erase(id); motion.objects.erase(id); motion_revisions.erase(id)
		if instances.has(id) or hidden.has(id): remove_instance(int(id)); stats.removed+=1
	FrameProfile.finish("snapshot_native_delta",receive_began)
func sync_combat(id: int) -> void:
	if str(installed.get(id,""))!=str(desired[id].key):
		combat.forget(id); return
	combat.sync(id,desired[id].object,instances[id])
func remove_instance(id: int) -> void:
	var removal_began:=FrameProfile.begin()
	if is_instance_valid(combat): combat.forget(id,not desired.has(id))
	if instances.has(id): instance_removed.emit(id)
	if instances.has(id) and is_instance_valid(instances[id]):
		var instance=instances[id]
		var decoded: Dictionary=instance.retain_decoded_data() if instance.has_method("retain_decoded_data") else {}
		static_collision_index.erase(instance.get_instance_id()); instance.retire()
		if is_instance_valid(data_retirement): data_retirement.defer_release(decoded)
	instances.erase(id); installed.erase(id); animations.erase(id); hidden.erase(id)
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
			combat.base_frame(id,animation[0],animation[1])
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
	update_stream_priority()
	FrameProfile.finish("world_motion",phase_began)
	phase_began=FrameProfile.begin()
	var adoption_began:=Time.get_ticks_usec(); var adopted:=0
	var candidates: Array=[]
	for batch in batches:
		var owner=batch.owner; var actors: bool=batch.actors
		var prepared: Dictionary=owner.actors if actors else owner.instances
		if not actors:
			for id in owner.invisible_ids:
				if desired.has(id) and str(desired[id].key)==str(batch.keys.get(id,"")): remove_instance(id); installed[id]=batch.keys[id]; hidden[id]=true
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
		if adopted>=maximum_adoptions_per_frame or adopted>0 and (Time.get_ticks_usec()-adoption_began)/1000.0>=adoption_budget_ms: break
		var batch: Dictionary=candidate.batch; var id:=int(candidate.id); var owner=batch.owner
		var prepared: Dictionary=owner.actors if batch.actors else owner.instances
		var install_began:=Time.get_ticks_usec()
		var instance: Node3D=prepared[id]
		if not desired.has(id) or str(desired[id].key)!=str(batch.keys.get(id,"")):
			stats.stale_results+=1; prepared.erase(id); instance.retire(); continue
		remove_instance(id)
		# Live streams attach directly to the final parent. Reparenting an
		# already-active model invokes _exit_tree and retires its effects.
		if instance.get_parent()!=self: instance.reparent(self,true)
		prepared.erase(id)
		failed_objects.erase(id)
		instances[id]=instance; installed[id]=batch.keys[id]; stats.replacements+=1
		combat.sync(id,desired[id].object,instance)
		adopted+=1
		adoption_timing("install",install_began)
		if batch.actors and int(desired[id].object.objectType)==5:
			motion.adopt([{"id":id,"state":instance.get_meta("native_movement",{})}])
		# The snapshot may have moved an object while its model was preparing.
		var pose_began:=Time.get_ticks_usec(); apply_pose(id); adoption_timing("pose",pose_began)
		instance.show()
		var registration_began:=Time.get_ticks_usec(); instance_ready.emit(id,desired[id].object,instance); adoption_timing("registration",registration_began)
		if stats.admissions.size()<512: stats.admissions.append({"id":id,"kind":int(desired[id].object.objectType),"elapsed_ms":(Time.get_ticks_usec()-opened_at)/1000.0})
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
				if not desired.has(id) or str(desired[id].key)!=str(batch.keys.get(id,"")):
					stats.stale_results+=1; continue
				var error: Dictionary=owner.stats.object_failures[id].duplicate(true)
				failed_objects[id]={"key":batch.keys[id],"error":error}; stats.failed_admissions+=1
				if stats.object_errors.size()<512: stats.object_errors.append(error)
				if int(id)==controlled_id: stats.errors.append(error)
			if stats.batches.size()<128: stats.batches.append(owner.stats.duplicate(true))
			adoption_timing("statistics",stats_began)
			var close_began:=Time.get_ticks_usec(); data_retirement.retire(owner.detach_prepared_data()); owner.close(); owner.queue_free(); batches.erase(batch); stats.completed_batches+=1; adoption_timing("close",close_began)
	FrameProfile.finish("world_adoption",phase_began)
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
	# New actors need not wait for an unrelated older batch. Bound independent
	# owners and skip exact in-flight appearance keys to avoid duplicate work.
	if catalog==null or batches.size()>=3: return
	var inflight: Dictionary={}
	for batch in batches:
		for id in batch.keys:
			if desired.has(id) and str(desired[id].key)==str(batch.keys[id]): inflight[id]=true
	var plan:=pending_plan(inflight)
	var actor_objects: Array=plan.actors; var static_objects: Array=plan.statics; var actor_keys: Dictionary={}; var static_keys: Dictionary={}
	for object in actor_objects: actor_keys[int(object.id)]=desired[int(object.id)].key
	for object in static_objects: static_keys[int(object.id)]=desired[int(object.id)].key
	if not actor_objects.is_empty():
		var owner:=Creatures.new(); owner.use_skeleton=use_skeleton; owner.admission_parent=self; add_child(owner); owner.configure(catalog,pool,actor_objects,area_id,cache_path,controlled_id); batches.append({"owner":owner,"actors":true,"keys":actor_keys})
		if has_priority_origin: owner.set_priority_origin(priority_origin)
	if not static_objects.is_empty():
		if not ready_for_control():
			stats.entry_prefetch_batches=int(stats.get("entry_prefetch_batches",0))+1
			stats.entry_prefetch_objects=int(stats.get("entry_prefetch_objects",0))+static_objects.size()
		var owner:=Objects.new(); owner.admission_parent=self; add_child(owner); owner.configure(catalog,pool,static_objects,area_id,cache_path); batches.append({"owner":owner,"actors":false,"keys":static_keys})
		if has_priority_origin: owner.set_priority_origin(priority_origin)
func pending_plan(inflight: Dictionary) -> Dictionary:
	var plan:={"actors":[],"statics":[]}
	if closed or retiring or not stats.errors.is_empty(): return plan
	# Terrain and the complete controlled actor (including equipment) own the
	# first preparation window. Area-ready still releases original server player
	# replication; waiting for that player before the protocol ack would deadlock.
	if desired.has(controlled_id) and installed.get(controlled_id,"")!=desired[controlled_id].key and not inflight.has(controlled_id):
		plan.actors.append(desired[controlled_id].object); return plan
	var before_control:=not ready_for_control()
	if batches.size()>=2: return plan
	var origin:=Vector3.ZERO
	if before_control:
		# The exclusive player request has already started and terrain owns its
		# admission gate. At most one nearby scenery owner can overlap that job;
		# remote actor/supermodel work cannot consume this initial window.
		if not entry_prefetch_enabled or int(stats.get("entry_prefetch_batches",0))>0 or not ready_for_admission() or not inflight.has(controlled_id) or not desired.has(controlled_id): return plan
		var controlled_pose:=object_pose(desired[controlled_id].object)
		if controlled_pose.is_empty(): return plan
		origin=controlled_pose.position
	else: origin=instances[controlled_id].position
	var candidates: Array=[]
	for id in desired:
		var wanted: Dictionary=desired[id]
		if before_control and int(wanted.object.objectType) not in [9,10]: continue
		if str(installed.get(id,""))==str(wanted.key): continue
		# Keep failure distinct from hidden or installed. An appearance change,
		# removal/recreation or new world scope may try again; snapshots alone do not.
		if failed_objects.has(id) and str(failed_objects[id].key)==str(wanted.key): continue
		if inflight.has(id): continue
		var placement:=object_pose(wanted.object)
		if placement.is_empty(): continue
		var distance:=origin.distance_squared_to(placement.position)
		if before_control and distance>entry_prefetch_radius*entry_prefetch_radius: continue
		var entry:={"object":wanted.object,"distance":distance}
		candidates.append(entry)
	var nearer:=func(a,b):return a.distance<b.distance or (a.distance==b.distance and int(a.object.id)<int(b.object.id))
	candidates.sort_custom(nearer)
	var owner_slots:=1 if before_control else 2-batches.size()
	# One shared distance wave: far-away actors cannot jump ahead merely because
	# their category still has room. Completed work never waits on a slow model.
	for entry in candidates.slice(0,mini(maximum_stream_wave,entry_prefetch_limit) if before_control else maximum_stream_wave):
		var group: Array=plan.actors if int(entry.object.objectType) in [5,6] else plan.statics
		var limit:=maximum_actor_batch if int(entry.object.objectType) in [5,6] else maximum_static_batch
		if group.size()>=limit or group.is_empty() and owner_slots<=0: continue
		if group.is_empty(): owner_slots-=1
		group.append(entry.object)
	# Keep at most two background owners; reserve the third slot for a changed
	# controlled appearance even while scenery and other actors are streaming.
	return plan
func ready_for_control() -> bool:
	return ready_for_admission() and instances.has(controlled_id) and (not is_instance_valid(references) or references.ready_for(instances[controlled_id]))
func ready_for_admission() -> bool:
	# Native 4/3 releases initial player replication. Waiting for the player
	# before acknowledging the prepared area deadlocks a first admission.
	return not closed and not retiring and is_instance_valid(terrain) and terrain.done and terrain.diagnostics.errors.is_empty() and is_instance_valid(surface) and surface.ready() and stats.errors.is_empty()
func asset_owners() -> Array:
	var owners: Array=[]
	for owner in [terrain,surface,references,drive_collision,effects]:
		if is_instance_valid(owner) and owner.get("assets") is Assets: owners.append(owner.assets)
	if is_instance_valid(effects) and effects.creature_voices!=null and is_instance_valid(effects.creature_voices.assets): owners.append(effects.creature_voices.assets)
	for batch in batches:
		if is_instance_valid(batch.owner) and batch.owner.get("assets") is Assets: owners.append(batch.owner.assets)
	return owners
func worker_tasks() -> Array:
	var tasks: Array=[]
	for owner in asset_owners(): tasks.append_array(owner.running.values())
	if is_instance_valid(terrain) and terrain.definition_task>=0: tasks.append(int(terrain.definition_task))
	return tasks
func begin_retirement() -> void:
	if closed or retiring: return
	var began:=FrameProfile.begin()
	retiring=true
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
	for field in stats:
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
	FrameProfile.finish("snapshot_combat_effects",snapshot_began); snapshot_began=FrameProfile.begin()
	state.native_particles=particle_metrics.snapshot()
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
	state.native_references=references.snapshot() if is_instance_valid(references) else {}
	state.failed_objects=failed_objects.duplicate(true)
	state.streaming_priority={"player_centered":has_priority_origin,"origin":[priority_origin.x,priority_origin.y,priority_origin.z],"wave_limit":maximum_stream_wave,"entry_prefetch":{"enabled":entry_prefetch_enabled,"limit":entry_prefetch_limit,"radius":entry_prefetch_radius},"policy":"controlled actor first, then nearest ready placements across model groups"}
	state.object_visuals_complete=failed_objects.is_empty() and stats.errors.is_empty() and instances.size()+hidden.size()==desired.size() and batches.is_empty()
	state.surface=surface.snapshot() if is_instance_valid(surface) else {}
	FrameProfile.finish("snapshot_scene_metadata",snapshot_began); snapshot_began=FrameProfile.begin()
	state.preparation_cache=catalog.preparation_cache().snapshot() if catalog!=null and catalog.has_method("preparation_cache") else {}
	state.decoded_cache=catalog.decoded_cache().snapshot() if catalog!=null and catalog.has_method("decoded_cache") else {}
	FrameProfile.finish("snapshot_preparation_cache",snapshot_began)
	if is_instance_valid(surface): state.errors.append_array(surface.stats.errors)
	state.merge({"area_id":area_id,"generation":generation,"controlled_id":controlled_id,"entities":instances.size(),"hidden":hidden.size(),"desired":desired.size(),"pending_batches":batches.size(),"admission_ready":ready_for_admission(),"ready":ready_for_control(),"terrain":terrain.snapshot() if is_instance_valid(terrain) else {},"pool":pool.snapshot(),"owns_pool":owns_pool,"native_rendering":true,"full_migration":false})
	return state
func close() -> void:
	if closed: return
	closed=true
	var close_began:=FrameProfile.begin()
	if is_instance_valid(combat): combat.close()
	if is_instance_valid(effects): effects.close()
	FrameProfile.finish("retirement_effects_close",close_began); close_began=FrameProfile.begin()
	if is_instance_valid(references): references.close()
	FrameProfile.finish("retirement_references_close",close_began); close_began=FrameProfile.begin()
	if is_instance_valid(terrain): terrain.close()
	if is_instance_valid(surface): surface.close()
	if is_instance_valid(drive_collision): drive_collision.close()
	FrameProfile.finish("retirement_terrain_close",close_began); close_began=FrameProfile.begin()
	motion.height_query=Callable()
	motion.facing_target_query=Callable()
	for batch in batches:
		if is_instance_valid(batch.owner): data_retirement.retire(batch.owner.detach_prepared_data()); batch.owner.close(); batch.owner.queue_free()
	batches.clear()
	for id in instances.keys(): remove_instance(id)
	if is_instance_valid(point_wind): point_wind.close()
	particle_metrics.close()
	desired.clear(); installed.clear(); animations.clear(); failed_objects.clear(); motion.objects.clear(); motion_revisions.clear()
	static_collision_index.clear()
	if owns_pool: pool.clear()
	if is_instance_valid(data_retirement) and not retired_data.is_empty():
		data_retirement.defer_release(retired_data); retired_data={}
	if owns_data_retirement and is_instance_valid(data_retirement): data_retirement.close()
	catalog=null
	FrameProfile.finish("retirement_other_close",close_began)
func _exit_tree() -> void: close()
