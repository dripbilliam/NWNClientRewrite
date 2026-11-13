extends Node3D
const Timing=preload("res://systems/native_render/frame_profile.gd")
# Native original-table/model selection for static replicated objects. Actor,
# equipment, animated door state and visual-transform consumers follow separately.
signal finished(state: Dictionary)
const Assets=preload("res://systems/native_data/asset_service.gd")
const Template=preload("res://systems/native_render/model_template.gd")
const Priority=preload("res://systems/native_render/stream_priority.gd")
const Placeable=preload("res://systems/native_render/placeable_instance.gd")
var _template_pending: Dictionary={}
var _template_entry: Dictionary={}
var _clone_pending: Dictionary={}
var _clone_entry: Dictionary={}
func _cancel_staged_publication() -> void:
	if pool!=null and pool.has_method("cancel_template_step"):pool.cancel_template_step(_template_pending)
	else:
		if _template_pending.has("template"):_template_pending.template.cancel_staged_build()
		_template_pending.clear()
	Template.cancel_creation(_clone_pending);_clone_entry={};_template_entry={}
func _resume_clone_head() -> void:
	var entry: Dictionary=_clone_entry if not _clone_entry.is_empty() else _template_entry
	if entry.is_empty():return
	for index in queue.size():
		if is_same(queue[index],entry):
			if index>0:queue.push_front(queue.pop_at(index))
			return
	# The exact queued row retired; cancel only its private publication work.
	if not _clone_entry.is_empty():Template.cancel_creation(_clone_pending);_clone_entry={}
	if not _template_entry.is_empty():
		if pool!=null and pool.has_method("cancel_template_step"):pool.cancel_template_step(_template_pending)
		_template_entry={}
func _cancel_publication_row(entry: Dictionary) -> void:
	if not _clone_entry.is_empty() and is_same(entry,_clone_entry):
		Template.cancel_creation(_clone_pending);_clone_entry={}
	if not _template_entry.is_empty() and is_same(entry,_template_entry):
		if pool!=null and pool.has_method("cancel_template_step"):pool.cancel_template_step(_template_pending)
		_template_entry={}
var priority_origin:=Vector3.ZERO
var has_priority_origin:=false
var priority_dirty:=false
func set_priority_origin(value: Vector3) -> void:
	if not value.is_finite() or has_priority_origin and priority_origin.distance_squared_to(value)<4.0: return
	priority_origin=value; has_priority_origin=true; priority_dirty=true
func refresh_priority() -> void:
	if not priority_dirty or not has_priority_origin: return
	priority_dirty=false
	var names: Array=Priority.model_order(groups.keys(),groups,priority_origin)
	var ranks: Dictionary={}
	for index in names.size(): ranks[names[index]]=index
	waiting.sort_custom(func(a,b):return int(ranks[a])<int(ranks[b]))
	assets.prioritize(Priority.request_order(model_requests,names))
	queue.sort_custom(func(a,b):
		var da: float=priority_origin.distance_squared_to(a.placement.position); var db: float=priority_origin.distance_squared_to(b.placement.position)
		return da<db or (da==db and int(a.placement.id)<int(b.placement.id)))
var assets
var pool
var maximum_asset_workers:=4
var tables: Dictionary={}
var table_requests: Dictionary={}
var initial_static_tables_only:=false
var model_requests: Dictionary={}
var groups: Dictionary={}
var waiting: Array=[]
var queue: Array=[]
var maximum_objects_per_frame:=0 #0 uses the existing time/shared-pool budget; positive values cap units.
var templates: Dictionary={}
var instances: Dictionary={}
var invisible_ids: Array=[]
var snapshot_objects: Array=[]
var area_id: int=-1
var admission_parent: Node3D
var done:=false
var closed:=false
# B1 retains only the table bank/service; per-wave templates and model jobs remain ordinary.
var wave_parked:=false
var reusable_table_scope: Dictionary={}
var reusable_asset_epoch:=-1
# B2 is separate and default-off; B1 continues to issue all ordinary model jobs.
var reuse_base_templates:=OS.get_cmdline_user_args().has("--base-scenery-templates=retained")
var base_templates
var base_retry_requests: Dictionary={}
# Default-off experiment: probe only the already-reserved current wave.
var probe_base_templates:=OS.get_cmdline_user_args().has("--base-scenery-template-probe=ready")
var base_template_probes: Dictionary={}
# Optional persistent owner: retire consumed rows and refill freed reservations.
var continuous_base_stream:=OS.get_cmdline_user_args().has("--base-scenery-stream=continuous")
var continuous_rows: Dictionary={}
var group_bundles: Dictionary={}
var maximum_continuous_rows:=64
var stats: Dictionary={"planned":0,"rendered":0,"invisible":0,"deferred_actors":0,"deferred_items":0,"errors":[],"scope_errors":[],"object_failures":{},"warnings":[],"limitations":[],"model_jobs":0}
func object_failed(id: int,reason: String,model: String="") -> void:
	var diagnostic:={"id":id,"reason":reason}
	if not model.is_empty(): diagnostic.model=model
	stats.errors.append(diagnostic); stats.object_failures[id]=diagnostic
func model_failed(name: String,reason: String) -> void:
	for placement in groups.get(name,[]): object_failed(int(placement.id),reason,name)
func configure(catalog, shared_pool, objects: Array, target_area: int, cache_path: String) -> void:
	pool=shared_pool; snapshot_objects=objects; area_id=target_area
	assets=Assets.new(); add_child(assets); assets.maximum_workers=maxi(1,maximum_asset_workers); assets.configure(catalog); assets.cache_directory=cache_path; assets.completed.connect(prepared)
	reusable_table_scope=_table_scope(catalog);reusable_asset_epoch=assets.epoch;wave_parked=false
	initial_static_tables_only=base_static_snapshot()
	if continuous_base_stream and initial_static_tables_only:
		for object in objects:continuous_rows[int(object.id)]=true
	if reuse_base_templates and initial_static_tables_only:
		base_templates=preload("res://systems/native_render/base_template_directory.gd").new();base_templates.begin_wave(assets,pool,area_id)
	for table_name in (["placeables"] if initial_static_tables_only else ["placeables","genericdoors","doortypes"]): table_requests[assets.request(table_name,2017,"2da")]=table_name
func base_static_snapshot() -> bool:
	if snapshot_objects.is_empty():return false
	for object in snapshot_objects:
		if int(object.get("objectType",-1))!=9 or not object.has("staticState"):return false
	return true
func _fresh_wave_stats() -> Dictionary:
	return {"planned":0,"rendered":0,"invisible":0,"deferred_actors":0,"deferred_items":0,"errors":[],"scope_errors":[],"object_failures":{},"warnings":[],"limitations":[],"model_jobs":0}
func _table_scope(source) -> Dictionary:
	if source==null or not source.has_method("preparation_cache"):return {}
	var store=source.preparation_cache()
	if store==null or not store.has_method("generation"):return {}
	var epoch: Variant=store.generation()
	if not epoch is int or epoch<0:return {}
	return {"catalog":source,"store":store,"generation":epoch}
func _wave_empty() -> bool:
	if not (instances.is_empty() and invisible_ids.is_empty() and table_requests.is_empty() and model_requests.is_empty() and base_retry_requests.is_empty() and waiting.is_empty() and queue.is_empty() and is_instance_valid(assets) and not assets.closed and assets.pending.is_empty() and assets.running.is_empty()):return false
	if not assets.mutex.try_lock():return false
	var empty: bool=assets.results.is_empty();assets.mutex.unlock();return empty
func can_park_wave() -> bool:
	return not closed and done and not wave_parked and _wave_empty() and (not continuous_base_stream or continuous_rows.is_empty()) and assets.epoch==reusable_asset_epoch and stats.scope_errors.is_empty() and not reusable_table_scope.is_empty()
func park_wave() -> Dictionary:
	if not can_park_wave():return {}
	_cancel_staged_publication()
	var payload:={"queue":queue,"groups":groups,"objects":snapshot_objects,"group_bundles":group_bundles}
	queue=[];groups={};snapshot_objects=[];templates.clear();model_requests.clear();waiting.clear();invisible_ids.clear();base_template_probes.clear();initial_static_tables_only=false
	group_bundles={};continuous_rows.clear()
	stats=_fresh_wave_stats();wave_parked=true;set_process(false);assets.set_process(false)
	return payload
func can_resume_wave(source,shared_pool,objects: Array,target_area: int,cache_path: String) -> bool:
	if closed or not wave_parked or not done or not _wave_empty() or not groups.is_empty() or not snapshot_objects.is_empty() or not templates.is_empty() or not base_template_probes.is_empty() or assets.epoch!=reusable_asset_epoch or pool!=shared_pool or area_id!=target_area or str(assets.cache_directory)!=cache_path or not stats.scope_errors.is_empty():return false
	var next_scope:=_table_scope(source)
	if next_scope.is_empty() or reusable_table_scope.is_empty() or next_scope.catalog!=reusable_table_scope.catalog or next_scope.store!=reusable_table_scope.store or next_scope.generation!=reusable_table_scope.generation:return false
	if objects.is_empty():return false
	for object in objects:
		if not object is Dictionary or int(object.get("objectType",-1))!=9 or not object.has("staticState"):return false
	return true
func resume_wave(source,shared_pool,objects: Array,target_area: int,cache_path: String) -> bool:
	if not can_resume_wave(source,shared_pool,objects,target_area,cache_path):return false
	snapshot_objects=objects;stats=_fresh_wave_stats();done=false;wave_parked=false
	if continuous_base_stream:
		continuous_rows.clear()
		for object in objects:continuous_rows[int(object.id)]=true
	priority_origin=Vector3.ZERO;has_priority_origin=false;priority_dirty=false
	# Match a fresh owner's worker policy before its first immediate request.
	assets.maximum_workers=maxi(1,maximum_asset_workers);set_process(true);assets.set_process(true)
	initial_static_tables_only=base_static_snapshot()
	if base_templates!=null:base_templates.begin_wave(assets,pool,area_id)
	for table_name in (["placeables"] if initial_static_tables_only else ["placeables","genericdoors","doortypes"]):
		if not tables.has(table_name):table_requests[assets.request(table_name,2017,"2da")]=table_name
	if table_requests.is_empty():plan_objects()
	return true
static func pose(object: Dictionary) -> Dictionary:
	var state: Dictionary=object.get("replicated",{}); var fixed: Dictionary=object.get("staticState",object.get("lightState",{}))
	var position: Variant=state.get("position",fixed.get("position"))
	if not position is Array or position.size()<3: return {}
	var orientation: Variant=state.get("orientation",fixed.get("orientation")); var rotation:=0.0
	var vector: Variant=orientation.get("vector") if orientation is Dictionary else orientation
	if vector is Array and vector.size()>=2: rotation=-atan2(float(vector[0]),float(vector[1]))
	elif orientation is Dictionary: rotation=deg_to_rad(float(orientation.get("yaw",0)))
	return {"position":Vector3(position[0],position[2],-position[1]),"rotation":rotation}
func table_row(name: String, index: int) -> Dictionary:
	var rows: Array=tables.get(name,{}).get("orderedRows",[])
	return rows[index] if index>=0 and index<rows.size() else {}
func plan_objects() -> void:
	plan_object_rows(snapshot_objects)
	waiting=groups.keys()
	priority_dirty=true
func plan_object_rows(objects: Array) -> Array:
	var planned: Array=[]
	for object in objects:
		if int(object.get("areaId",-1))!=area_id or object.get("replicationRemoved",false): continue
		var kind:=int(object.objectType); var placement:=pose(object)
		if placement.is_empty(): continue
		if kind==5: stats.deferred_actors+=1; continue
		if kind==6: stats.deferred_items+=1; continue
		if kind not in [9,10]: continue
		var state: Dictionary=object.get("replicated",{}); var fixed: Dictionary=object.get("staticState",object.get("lightState",{})); var row: Dictionary={}
		if kind==9: row=table_row("placeables",int(state.get("appearance",fixed.get("appearance",-1))))
		else:
			var appearance:=int(state.get("doorType",0)); row=table_row("genericdoors" if appearance==0 else "doortypes",int(state.get("genericType",0)) if appearance==0 else appearance)
			if str(row.get("VisibleModel","1"))=="0": stats.invisible+=1; invisible_ids.append(int(object.id)); continue
		var name:=str(row.get("ModelName",row.get("Model",""))).to_lower()
		if name.is_empty() or name=="****": object_failed(int(object.id),"Original appearance table has no model"); continue
		placement.merge({"id":int(object.id),"object":object,"model":name}); stats.planned+=1
		if not groups.has(name): groups[name]=[]
		groups[name].append(placement)
		planned.append(placement)
	priority_dirty=true
	return planned
func continuous_scope_current(source,shared_pool,target_area: int,cache_path: String) -> bool:
	if not continuous_base_stream or closed or wave_parked or not initial_static_tables_only or not table_requests.is_empty() or not is_instance_valid(assets) or assets.closed or assets.epoch!=reusable_asset_epoch or pool!=shared_pool or area_id!=target_area or str(assets.cache_directory)!=cache_path or not stats.scope_errors.is_empty():return false
	var next:=_table_scope(source)
	return not next.is_empty() and not reusable_table_scope.is_empty() and next.catalog==reusable_table_scope.catalog and next.store==reusable_table_scope.store and next.generation==reusable_table_scope.generation
func extend_base_wave(source,shared_pool,objects: Array,target_area: int,cache_path: String) -> bool:
	if not continuous_scope_current(source,shared_pool,target_area,cache_path) or objects.is_empty() or continuous_rows.size()+objects.size()>maximum_continuous_rows:return false
	var additions: Dictionary={}
	for object in objects:
		if not object is Dictionary or int(object.get("objectType",-1))!=9 or not object.has("staticState") or int(object.get("areaId",-1))!=area_id or continuous_rows.has(int(object.get("id",-1))) or additions.has(int(object.get("id",-1))):return false
		# A newly animated row may require a different group decoder. Let the
		# existing reservation finish and start its ordinary correctly typed wave.
		if Placeable.requires_animation(object.get("replicated",{})):return false
		additions[int(object.id)]=true
	snapshot_objects.append_array(objects)
	continuous_rows.merge(additions)
	for placement in plan_object_rows(objects):
		var name: String=placement.model
		if group_bundles.has(name):queue.append({"model":name,"bundle":group_bundles[name],"placement":placement})
		elif templates.has(name) and base_templates!=null and base_templates.still_bound(name,templates[name]):queue.append({"model":name,"bundle":{},"placement":placement,"base_template_hit":true})
		elif not waiting.has(name) and not model_requests.values().has(name):waiting.append(name);base_template_probes.erase(name)
	done=false;set_process(true);assets.set_process(true);priority_dirty=true
	stats["continuous_refills"]=int(stats.get("continuous_refills",0))+1
	stats["continuous_refilled_rows"]=int(stats.get("continuous_refilled_rows",0))+objects.size()
	stats["continuous_max_rows"]=maxi(int(stats.get("continuous_max_rows",0)),continuous_rows.size())
	return true
func retire_base_row(id: int) -> void:
	if not continuous_base_stream or not continuous_rows.erase(id):return
	snapshot_objects=snapshot_objects.filter(func(row):return int(row.id)!=id)
	for name in groups.keys():
		groups[name]=groups[name].filter(func(row):return int(row.id)!=id)
		if groups[name].is_empty():
			groups.erase(name);templates.erase(name);group_bundles.erase(name);base_template_probes.erase(name)
func prepared(id: int, result: Dictionary) -> void:
	if closed: return
	if base_retry_requests.has(id):prepared_base_retry(id,result);return
	if table_requests.has(id):
		var table_name: String=table_requests[id]; table_requests.erase(id)
		if not str(result.error).is_empty():
			var diagnostic:={"table":table_name,"reason":result.error}; stats.errors.append(diagnostic); stats.scope_errors.append(diagnostic)
		else: tables[table_name]=result.value
		if table_requests.is_empty():
			# The caller owns mutable rows. Escalate before planning if the batch changed.
			if initial_static_tables_only and not base_static_snapshot():
				initial_static_tables_only=false
				for name in ["genericdoors","doortypes"]:table_requests[assets.request(name,2017,"2da")]=name
			else:plan_objects()
		return
	if not model_requests.has(id): return
	var name: String=model_requests[id]; model_requests.erase(id)
	if not str(result.error).is_empty(): model_failed(name,str(result.error)); return
	stats.warnings.append_array(prepared_warnings(name,result))
	if continuous_base_stream:group_bundles[name]=result
	# Model de-duplication must not turn into model-group publication order.
	for placement in groups[name]: queue.append({"model":name,"bundle":result,"placement":placement})
	priority_dirty=true
func prepared_warnings(name: String,result: Dictionary) -> Array:
	var warnings: Array=[]
	for texture_name in result.get("missing_textures",[]): warnings.append({"model":name,"texture":texture_name,"reason":"Original texture lookup was recorded as missing; material retained without a bitmap"})
	for dependency in result.get("dependencies",[]):
		if dependency.get("role")=="emitter" and dependency.get("missing",false): warnings.append({"model":name,"texture":dependency.name,"reason":"Original emitter bitmap is unavailable; geometry retained, no replacement bitmap supplied"})
	return warnings
func reusable_static_group(name: String) -> bool:
	return base_templates!=null and initial_static_tables_only and groups.get(name,[]).all(func(row):return int(row.object.objectType)==9 and row.object.has("staticState") and not Placeable.requires_animation(row.object.get("replicated",{})))
func queue_base_template(name: String) -> bool:
	if not reusable_static_group(name):return false
	var cached: Dictionary=base_templates.lookup(name)
	if cached.is_empty():return false
	templates[name]=cached.template;stats.warnings.append_array(cached.warnings)
	for feature in cached.template.limitations:
		if not stats.limitations.has(feature):stats.limitations.append(feature)
	for placement in groups[name]:queue.append({"model":name,"bundle":{},"placement":placement,"base_template_hit":true})
	stats["base_template_request_hits"]=int(stats.get("base_template_request_hits",0))+1;priority_dirty=true
	return true
func probe_ready_base_templates() -> void:
	if not probe_base_templates or base_templates==null or not initial_static_tables_only:return
	var remaining: Array=[]
	for value in waiting:
		var name:=str(value)
		if base_template_probes.has(name) or base_template_probes.size()>=64:
			remaining.append(value);continue
		base_template_probes[name]=true
		if not reusable_static_group(name):
			stats["base_template_probe_skipped"]=int(stats.get("base_template_probe_skipped",0))+1
			remaining.append(value);continue
		stats["base_template_probe_attempts"]=int(stats.get("base_template_probe_attempts",0))+1
		var saturated: bool=assets.pending.size()+assets.running.size()>=mini(assets.maximum_pending,assets.maximum_workers*2)
		if queue_base_template(name):
			stats["base_template_probe_hits"]=int(stats.get("base_template_probe_hits",0))+1
			if saturated:stats["base_template_probe_saturated_hits"]=int(stats.get("base_template_probe_saturated_hits",0))+1
		else:
			stats["base_template_probe_misses"]=int(stats.get("base_template_probe_misses",0))+1
			remaining.append(value)
	waiting=remaining
func request_base_retry(name: String,placement: Dictionary,animated: bool) -> void:
	# A queued hit can outlive its classification/scope. Acquire an ordinary
	# fresh packet for this one current-wave placement instead of using {}.
	var request_id: int=assets.request(name,2002,"actor-model" if animated else "static-model",{"relevant_tracks":true} if animated else {})
	if request_id<0:object_failed(int(placement.id),str(assets.failure),name)
	else:base_retry_requests[request_id]={"model":name,"placement":placement};stats.model_jobs+=1
func prepared_base_retry(id: int,result: Dictionary) -> void:
	var entry: Dictionary=base_retry_requests[id];base_retry_requests.erase(id)
	if not str(result.get("error","")).is_empty():object_failed(int(entry.placement.id),str(result.error),str(entry.model));return
	stats.warnings.append_array(prepared_warnings(str(entry.model),result))
	queue.append({"model":entry.model,"bundle":result,"placement":entry.placement,"base_template_retry":true});priority_dirty=true
func _process(_delta: float) -> void:
	var began:=Timing.begin()
	_profile_process(_delta)
	Timing.finish("callback_objects",began)
func _profile_process(_delta: float) -> void:
	if closed or done or not is_instance_valid(assets) or not table_requests.is_empty(): return
	var phase_began:=Timing.begin()
	refresh_priority()
	Timing.finish("object_stream_priority_ms",phase_began); phase_began=Timing.begin()
	if probe_base_templates:
		var probe_began:=Timing.begin();probe_ready_base_templates();Timing.finish("object_stream_ready_probe_ms",probe_began)
	while not waiting.is_empty() and assets.pending.size()+assets.running.size()<mini(assets.maximum_pending,assets.maximum_workers*2):
		var name:=str(waiting.pop_front()); var door: bool=groups[name].any(func(row):return int(row.object.objectType)==10)
		var animated: bool=door or groups[name].any(func(row):return int(row.object.objectType)==9 and Placeable.requires_animation(row.object.get("replicated",{})))
		if not animated:
			# A speculative miss never suppresses this later ordinary lookup.
			if probe_base_templates and base_template_probes.has(name):stats["base_template_probe_rechecks"]=int(stats.get("base_template_probe_rechecks",0))+1
			if queue_base_template(name):continue
		var id: int=assets.request(name,2002,"actor-model" if animated else "static-model",{"relevant_tracks":true} if animated else {})
		if id<0: model_failed(name,str(assets.failure))
		else: model_requests[id]=name; stats.model_jobs+=1
	Timing.finish("object_stream_requests_ms",phase_began)
	if probe_base_templates:
		var ready_priority_began:=Timing.begin();refresh_priority();Timing.finish("object_stream_ready_priority_ms",ready_priority_began)
	_resume_clone_head()
	var began:=Time.get_ticks_usec(); var published:=0; var attempted:=0
	var shared_budget: bool=pool.has_method("can_publish") and pool.has_method("publication_finished")
	while not queue.is_empty() and (maximum_objects_per_frame==0 or published<maximum_objects_per_frame):
		if attempted>=16 and not shared_budget:break
		if attempted>0 and Time.get_ticks_usec()-began>=3000: break
		if pool.has_method("can_publish") and not pool.can_publish(): break
		var unit_began:=Time.get_ticks_usec()
		var entry: Dictionary=queue.pop_front(); var name: String=entry.model
		attempted+=1
		var placement: Dictionary=entry.placement; var door: bool=int(placement.object.objectType)==10
		var placeable: bool=int(placement.object.objectType)==9 and Placeable.requires_animation(placement.object.get("replicated",{}))
		if entry.get("base_template_hit",false) and (door or placeable or base_templates==null or not base_templates.still_bound(name,templates.get(name))):
			_cancel_publication_row(entry)
			if not door and not placeable:templates.erase(name)
			phase_began=Timing.begin();request_base_retry(name,placement,door or placeable)
			Timing.finish("object_stream_retry_requests_ms",phase_began)
			if pool.has_method("publication_finished"):pool.publication_finished(unit_began)
			continue
		if not door and not placeable and (not templates.has(name) or entry.get("base_template_retry",false)):
			phase_began=Timing.begin()
			var template
			if Template.configured_recipe() and pool.has_method("model_template_step"):
				var preparation: Dictionary=pool.model_template_step(entry.bundle,_template_pending)
				if preparation.status=="pending":
					_template_entry=entry;queue.push_front(entry);stats.staged_template_steps=int(stats.get("staged_template_steps",0))+1
					Timing.finish("object_stream_template_ms",phase_began)
					if pool.has_method("publication_finished"):pool.publication_finished(unit_began)
					continue
				_template_entry={};template=preparation.get("template")
			else:template=pool.model_template(entry.bundle)
			Timing.finish("object_stream_template_ms",phase_began)
			if template==null:
				if entry.get("base_template_retry",false):
					object_failed(int(placement.id),str(pool.failure),name)
					if pool.has_method("publication_finished"):pool.publication_finished(unit_began)
				else:model_failed(name,str(pool.failure));queue=queue.filter(func(row):return row.model!=name)
				continue
			templates[name]=template
			if reusable_static_group(name):base_templates.remember(name,Template.identity(entry.bundle,pool),prepared_warnings(name,entry.bundle))
			for feature in template.limitations:
				if not stats.limitations.has(feature): stats.limitations.append(feature)
		var instance
		phase_began=Timing.begin()
		if door:
			instance=preload("res://systems/native_render/door_instance.gd").new()
			if not instance.install_door(entry.bundle,pool,int(placement.id),placement.object.get("replicated",{})):
				object_failed(int(placement.id),instance.failure,name); instance.retire(); instance=null
		elif placeable:
			instance=Placeable.new()
			if not instance.install_placeable(entry.bundle,pool,int(placement.id),placement.object.get("replicated",{})):
				object_failed(int(placement.id),instance.failure,name);instance.retire();instance=null
		elif Template.configured_recipe() and templates[name].has_method("create_step"):
			var creation: Dictionary=templates[name].create_step(_clone_pending)
			if creation.status=="pending":
				_clone_entry=entry;queue.push_front(entry);stats.staged_clone_steps=int(stats.get("staged_clone_steps",0))+1
				Timing.finish("object_stream_clone_ms",phase_began)
				if pool.has_method("publication_finished"):pool.publication_finished(unit_began)
				continue
			_clone_entry={};instance=creation.get("instance")
		else: instance=templates[name].create()
		Timing.finish("object_stream_door_ms" if door else "object_stream_clone_ms",phase_began)
		if instance==null: object_failed(int(placement.id),"Native model instance failed",name)
		else:
			instance.position=placement.position; instance.rotation.y=float(placement.rotation); instance.set_meta("world_object_id",placement.id)
			phase_began=Timing.begin()
			if is_instance_valid(admission_parent): instance.hide(); admission_parent.add_child(instance)
			else: add_child(instance)
			Timing.finish("object_stream_attach_ms",phase_began)
			instances[placement.id]=instance; stats.rendered+=1
		published+=1
		phase_began=Timing.begin()
		if pool.has_method("publication_finished"): pool.publication_finished(unit_began)
		Timing.finish("object_stream_bookkeeping_ms",phase_began)
	if waiting.is_empty() and model_requests.is_empty() and base_retry_requests.is_empty() and queue.is_empty():
		done=true
		# Counters accumulate across this retained owner's waves; byte/entry gauges
		# describe this completion only. The envelope contains no live object refs.
		stats["base_template_directory"]={"owner_instance_id":get_instance_id(),
			"counter_scope":"owner-lifetime-cumulative","gauge_scope":"current-at-wave-finished",
			"present":base_templates!=null,"snapshot":base_templates.snapshot() if base_templates!=null else {}}
		finished.emit(stats.duplicate(true))
func detach_prepared_data() -> Dictionary:
	_cancel_staged_publication()
	var payload:={"queue":queue,"groups":groups,"objects":snapshot_objects,"tables":tables,"base_retry_requests":base_retry_requests,"base_template_probes":base_template_probes,"group_bundles":group_bundles}
	queue=[]; groups={}; snapshot_objects=[]; tables={};base_retry_requests={};base_template_probes={}
	group_bundles={};continuous_rows.clear()
	return payload
func close() -> void:
	if closed: return
	_cancel_staged_publication()
	closed=true;wave_parked=false;reusable_table_scope={};reusable_asset_epoch=-1
	if base_templates!=null:base_templates.clear();base_templates=null
	if is_instance_valid(assets): assets.close()
	for instance in instances.values():
		if is_instance_valid(instance): instance.retire()
	instances.clear(); templates.clear(); queue.clear(); model_requests.clear(); base_retry_requests.clear(); base_template_probes.clear(); waiting.clear(); groups.clear(); snapshot_objects.clear(); tables.clear()
	group_bundles.clear();continuous_rows.clear()
func _exit_tree() -> void: close()
