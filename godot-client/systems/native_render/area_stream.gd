extends Node3D
const Timing=preload("res://systems/native_render/frame_profile.gd")
# Native original-resource terrain streaming. No JS scene/geometry input.
signal progress(state: Dictionary)
signal finished(state: Dictionary)
signal tile_published(index: int,instance)
signal definition_ready(value: Dictionary)
const Definition = preload("res://systems/native_data/area_definition.gd")
const Assets = preload("res://systems/native_data/asset_service.gd")
const Template = preload("res://systems/native_render/model_template.gd")
const TerrainBatches = preload("res://systems/native_render/terrain_batches.gd")
const TileLights = preload("res://systems/native_render/tile_lights.gd")
const Priority=preload("res://systems/native_render/stream_priority.gd")
var priority_origin:=Vector3.ZERO
var has_priority_origin:=false
var priority_dirty:=false
var publication_remaining: Dictionary={}
func set_priority_origin(value: Vector3) -> void:
	if not value.is_finite() or has_priority_origin and priority_origin.distance_squared_to(value)<4.0: return
	priority_origin=value; has_priority_origin=true; priority_dirty=true
func refresh_priority() -> void:
	if not priority_dirty or not has_priority_origin or definition.is_empty(): return
	priority_dirty=false
	var names: Array=Priority.model_order(definition.models.keys(),definition.models,priority_origin,definition.tiles)
	var ranks: Dictionary={}
	for index in names.size(): ranks[names[index]]=index
	waiting.sort_custom(func(a,b):return int(ranks[a])<int(ranks[b]))
	assets.prioritize(Priority.request_order(requests,names))
	publish_queue.sort_custom(func(a,b):
		var da: float=priority_origin.distance_squared_to(definition.tiles[int(a.index)].position); var db: float=priority_origin.distance_squared_to(definition.tiles[int(b.index)].position)
		return da<db or (da==db and int(a.index)<int(b.index)))
var assets
var pool
var generation := 0
var closed := false
var failure := ""
var definition_task := -1
var definition_wait := {}
var definition_result := {}
var definition_mutex := Mutex.new()
var definition := {}
var requests := {}
var waiting: Array = []
var bundles := {}
var templates := {}
var template_keys := {}
var use_terrain_batches := false
var batcher
var batch_queue: Array=[]
var batch_remaining: Dictionary={}
var maximum_batches_per_frame:=8
var publish_queue: Array = []
var instances: Dictionary = {}
var collision_index=preload("res://systems/native_render/scene_query_index.gd").new()
var completed_tiles := 0
var failed_tiles := 0
var load_started := 0
var done := false
var light_table_job:=-1
var light_table: Dictionary={}
var publication_budget_ms := 3.0
var maximum_tiles_per_frame := 8
var diagnostics := {}
func open_area(catalog, area_name: String, shared_pool, cache_path: String = "") -> void:
	open_source(catalog,area_name,shared_pool,cache_path,{})
func open_network_area(catalog, state: Dictionary, shared_pool, cache_path: String="") -> void:
	open_source(catalog,str(state.get("resRef","")),shared_pool,cache_path,state.duplicate(true))
func open_source(catalog, area_name: String, shared_pool, cache_path: String, network_area: Dictionary) -> void:
	if closed: failure="Native area owner is closed"; return
	retire_scope(); pool=shared_pool; load_started=Time.get_ticks_usec()
	if not is_instance_valid(assets):
		assets=Assets.new(); add_child(assets); assets.completed.connect(model_prepared)
	if not is_instance_valid(batcher): batcher=TerrainBatches.new(); add_child(batcher)
	assets.configure(catalog); assets.cache_directory=cache_path
	definition_wait={"catalog":catalog.fork(),"name":area_name,"generation":generation,"network_area":network_area}
	diagnostics={"generation":generation,"name":area_name,"unique_models":0,"model_jobs":0,"worker_ms":0.0,"publish_ms":0.0,"publish_frames":0,"max_publish_ms":0.0,"max_tile_publish_ms":0.0,"template_ms":0.0,"clone_ms":0.0,"attach_ms":0.0,"batch_prepare_ms":0.0,"batches_published":0,"batched":use_terrain_batches,"templates_built":0,"templates_reused":0,"cache_hits":0,"limitations":[],"errors":[],"definition_thread":0}
	diagnostics.tile_lights=[]
	light_table_job=assets.request("lightcolor",2017,"2da")
	start_definition()
func start_definition() -> void:
	if closed or definition_task!=-1 or definition_wait.is_empty(): return
	var job := definition_wait; definition_wait={}
	definition_task=WorkerThreadPool.add_task(load_definition.bind(job),false,"Native original area definition")
func load_definition(job: Dictionary) -> void:
	var begin := Time.get_ticks_usec(); var parser := Definition.new()
	var value: Dictionary=parser.load_original(job.catalog,job.name) if job.get("network_area",{}).is_empty() else parser.load_network(job.catalog,job.network_area)
	var result := {"generation":job.generation,"value":value,"error":parser.failure,"thread":OS.get_thread_caller_id(),"ms":(Time.get_ticks_usec()-begin)/1000.0}
	definition_mutex.lock(); definition_result=result; definition_mutex.unlock()
func poll_definition() -> void:
	if definition_task==-1 or not WorkerThreadPool.is_task_completed(definition_task): return
	WorkerThreadPool.wait_for_task_completion(definition_task); definition_task=-1
	definition_mutex.lock(); var result := definition_result; definition_result={}; definition_mutex.unlock()
	if int(result.get("generation",-1))==generation and not closed:
		diagnostics.definition_ms=result.ms; diagnostics.definition_thread=result.thread
		if not str(result.error).is_empty():
			failure=result.error; diagnostics.errors.append(failure); complete()
		else:
			definition=result.value; waiting=definition.models.keys(); diagnostics.unique_models=waiting.size(); priority_dirty=true
			definition_ready.emit(definition)
	start_definition()
func model_prepared(id: int, result: Dictionary) -> void:
	if not closed and id==light_table_job:
		light_table_job=-1
		if not str(result.error).is_empty(): failure="Original LightColor table: "+str(result.error); diagnostics.errors.append(failure); complete()
		else: light_table=result.value
		return
	if closed or not requests.has(id): return
	var model_name := str(requests[id]); requests.erase(id)
	diagnostics.worker_ms+=float(result.worker_ms)
	if not str(result.error).is_empty():
		failed_tiles+=definition.models[model_name].size(); diagnostics.errors.append(model_name+": "+str(result.error)); return
	if result.cache_hit: diagnostics.cache_hits+=1
	if use_terrain_batches:
		var tiles: Array=[]
		for index in definition.models[model_name]: tiles.append(definition.tiles[index])
		var begin:=Time.get_ticks_usec(); var prepared: Dictionary=batcher.prepare(result,pool,tiles)
		diagnostics.batch_prepare_ms+=(Time.get_ticks_usec()-begin)/1000.0
		if prepared.is_empty(): failed_tiles+=tiles.size(); diagnostics.errors.append(model_name+": "+batcher.failure); return
		instances.merge(prepared.records)
		for feature in prepared.limitations:
			if not diagnostics.limitations.has(feature): diagnostics.limitations.append(feature)
		batch_remaining[model_name]={"groups":prepared.groups.size(),"tiles":tiles.size()}
		if prepared.groups.is_empty(): completed_tiles+=tiles.size(); batch_remaining.erase(model_name)
		for group in prepared.groups: group.model_name=model_name; batch_queue.append(group)
		return
	bundles[model_name]=result
	template_keys[model_name]=Template.identity(result,pool)
	publication_remaining[model_name]=definition.models[model_name].size()
	for index in definition.models[model_name]: publish_queue.append({"model":model_name,"index":index})
	priority_dirty=true
func _process(_delta: float) -> void:
	var began:=Timing.begin()
	_profile_process(_delta)
	Timing.finish("callback_terrain",began)
func _profile_process(_delta: float) -> void:
	if closed: return
	poll_definition()
	if definition.is_empty() or done: return
	refresh_priority()
	while not waiting.is_empty() and assets.pending.size()+assets.running.size()<mini(assets.maximum_pending,assets.maximum_workers*2):
		var model_name := str(waiting.pop_front()); var id: int = assets.request(model_name,2002,"static-model")
		if id<0:
			failed_tiles+=definition.models[model_name].size(); diagnostics.errors.append(assets.failure)
		else: requests[id]=model_name; diagnostics.model_jobs+=1
	if use_terrain_batches:
		publish_batches(); return
	if light_table.is_empty(): return
	var begin := Time.get_ticks_usec(); var published := 0
	while not publish_queue.is_empty() and published<maximum_tiles_per_frame:
		if published>0 and (Time.get_ticks_usec()-begin)/1000.0>=publication_budget_ms: break
		if pool.has_method("can_publish") and not pool.can_publish(): break
		var row: Dictionary = publish_queue.pop_front(); var tile: Dictionary = definition.tiles[int(row.index)]
		var tile_begin:=Time.get_ticks_usec(); var key:=str(template_keys[row.model])
		if not templates.has(key):
			var template_begin:=Time.get_ticks_usec()
			var count_before:=int(pool.stats.templates_created)
			var template=pool.model_template(bundles[row.model])
			if template!=null:
				templates[key]=template
				if int(pool.stats.templates_created)>count_before: diagnostics.templates_built+=1
				else: diagnostics.templates_reused+=1
			else: diagnostics.errors.append(str(row.model)+": "+pool.failure)
			diagnostics.template_ms+=(Time.get_ticks_usec()-template_begin)/1000.0
		else: diagnostics.templates_reused+=1
		var clone_begin:=Time.get_ticks_usec()
		var model = templates[key].create() if templates.has(key) else null
		diagnostics.clone_ms+=(Time.get_ticks_usec()-clone_begin)/1000.0
		if model==null: failed_tiles+=1
		else:
			var attach_begin:=Time.get_ticks_usec()
			add_child(model)
			diagnostics.attach_ms+=(Time.get_ticks_usec()-attach_begin)/1000.0
			model.position=tile.position; model.rotation.y=float(tile.rotation_y); model.set_meta("native_tile_index",int(row.index)); instances[int(row.index)]=model; completed_tiles+=1
			if not diagnostics.has("first_tile_ms"): diagnostics.first_tile_ms=(Time.get_ticks_usec()-load_started)/1000.0
			collision_index.put(model)
			diagnostics.tile_lights.append({"index":int(row.index),"model":row.model,"indices":tile.main_lights.duplicate(),"lights":TileLights.apply(model,str(row.model),TileLights.colors(tile.main_lights,light_table))})
			tile_published.emit(int(row.index),model)
			for feature in model.limitations:
				if not diagnostics.limitations.has(feature): diagnostics.limitations.append(feature)
		published+=1
		if pool.has_method("publication_finished"): pool.publication_finished(tile_begin)
		diagnostics.max_tile_publish_ms=maxf(diagnostics.max_tile_publish_ms,(Time.get_ticks_usec()-tile_begin)/1000.0)
		# Once every placement for this model was consumed, drop the CPU bundle.
		publication_remaining[row.model]-=1
		if int(publication_remaining[row.model])==0: bundles.erase(row.model); publication_remaining.erase(row.model)
	if published>0:
		var elapsed:=(Time.get_ticks_usec()-begin)/1000.0
		diagnostics.publish_frames+=1; diagnostics.publish_ms+=elapsed; diagnostics.max_publish_ms=maxf(diagnostics.max_publish_ms,elapsed); progress.emit(snapshot())
	if waiting.is_empty() and requests.is_empty() and publish_queue.is_empty(): complete()
func publish_batches() -> void:
	var begin:=Time.get_ticks_usec(); var published:=0
	while not batch_queue.is_empty() and published<maximum_batches_per_frame:
		if published>0 and (Time.get_ticks_usec()-begin)/1000.0>=publication_budget_ms: break
		if pool.has_method("can_publish") and not pool.can_publish(): break
		var unit_began:=Time.get_ticks_usec()
		var group: Dictionary=batch_queue.pop_front(); batcher.publish(group); published+=1
		if pool.has_method("publication_finished"): pool.publication_finished(unit_began)
		var remaining: Dictionary=batch_remaining[group.model_name]; remaining.groups-=1
		if int(remaining.groups)==0: completed_tiles+=int(remaining.tiles); batch_remaining.erase(group.model_name)
	if published>0:
		var elapsed:=(Time.get_ticks_usec()-begin)/1000.0
		diagnostics.batches_published+=published; diagnostics.publish_ms+=elapsed; diagnostics.publish_frames+=1; diagnostics.max_publish_ms=maxf(diagnostics.max_publish_ms,elapsed); progress.emit(snapshot())
	if waiting.is_empty() and requests.is_empty() and batch_queue.is_empty(): complete()
func snapshot() -> Dictionary:
	var state := diagnostics.duplicate(true)
	state.collision_index=collision_index.snapshot()
	state.streaming_priority={"player_centered":has_priority_origin,"origin":[priority_origin.x,priority_origin.y,priority_origin.z],"policy":"nearest ready tile; unique model work ranked by nearest placement"}
	state.merge({"complete":done,"success":done and diagnostics.errors.is_empty(),"tiles":definition.get("tiles",[]).size(),"rendered_tiles":completed_tiles,"failed_tiles":failed_tiles,"instances":instances.size(),"elapsed_ms":(Time.get_ticks_usec()-load_started)/1000.0,"rendering_native":true,"full_world":false})
	return state
func complete() -> void:
	if done: return
	done=true; diagnostics.complete_ms=(Time.get_ticks_usec()-load_started)/1000.0; finished.emit(snapshot())
func collision_candidates(start: Vector3,end: Vector3) -> Array: return collision_index.query(start,end)
func retire_scope() -> void:
	generation+=1; definition_wait={}; waiting.clear(); requests.clear(); publish_queue.clear(); bundles.clear(); template_keys.clear(); definition={}; light_table={}; light_table_job=-1; failure=""; done=false; completed_tiles=0; failed_tiles=0
	batch_queue.clear(); batch_remaining.clear()
	publication_remaining.clear(); priority_dirty=true
	if is_instance_valid(batcher): batcher.retire_scope()
	if is_instance_valid(assets): assets.retire_scope()
	for model in instances.values():
		if model is Node and is_instance_valid(model): model.retire()
	instances.clear()
	collision_index.clear()
func close() -> void:
	if closed: return
	closed=true; retire_scope()
	if is_instance_valid(assets): assets.close()
	if definition_task!=-1: WorkerThreadPool.wait_for_task_completion(definition_task); definition_task=-1
	definition_mutex.lock(); definition_result={}; definition_mutex.unlock()
	templates.clear()
	if is_instance_valid(batcher): batcher.close()
	pool=null
func detach_prepared_data() -> Dictionary:
	var payload:={"bundles":bundles,"definition":definition,"definition_result":definition_result,"light_table":light_table}
	bundles={}; definition={}; definition_result={}; light_table={}
	return payload
func _exit_tree() -> void: close()
