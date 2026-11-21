extends Node3D
# Optional source-derived decorative edge. No entity IDs, collision index,
# selection registry, walkmesh or gameplay-ready conditions belong here.
signal finished(state: Dictionary)
const Assets=preload("res://systems/native_data/asset_service.gd")
const Loader=preload("res://systems/native_render/area_border_loader.gd")
const Priority=preload("res://systems/native_render/stream_priority.gd")
const Timing=preload("res://systems/native_render/frame_profile.gd")
var assets
var loader
var pool
var scope: Array=[]
var generation:=0
var loader_ticket:=-1
var opened:=false
var retiring:=false
var closed:=false
var done:=false
var failure:=""
var plans: Array=[]
var groups: Dictionary={}
var waiting: Array=[]
var requests: Dictionary={}
var bundles: Dictionary={}
var templates: Dictionary={}
var ready_models: Array=[]
var instances: Dictionary={}
var planning_data: Dictionary={}
var priority_origin:=Vector3.ZERO
var has_priority_origin:=false
var priority_dirty:=true
var maximum_instances_per_frame:=4
var maximum_model_requests_per_frame:=4
var publication_budget_ms:=2.0
var retire_keys: Array=[]
var retire_template_keys: Array=[]
var stats:={"plans":0,"published":0,"failed":0,"stale":0,"model_jobs":0,"models_prepared":0,"publication_frames":0,"max_publish_ms":0.0,"retired_instances":0,"errors":[]}
func make_assets():return Assets.new()
func make_loader():return Loader.new()
static func valid_scope(value: Array)->bool:
	if value.size()!=3:return false
	# Private Godot World nonce, not a network connection/entity identity.
	if not value[0] is int or value[0]==0:return false
	for index in range(1,3):
		var number: Variant=value[index]
		if not (number is int or number is float) or not is_finite(float(number)) or float(number)!=floorf(float(number)) or number<0 or number>(4294967295 if index==2 else 9007199254740991):return false
	return true
func start(catalog,shared_pool,current_scope: Array,cache_path: String)->bool:
	if closed or retiring or opened or not valid_scope(current_scope) or catalog==null or shared_pool==null:
		failure="Decorative border owner needs a new current scope and resource owners.";return false
	opened=true;done=false;generation+=1;scope=current_scope.duplicate();pool=shared_pool
	assets=make_assets();add_child(assets);assets.completed.connect(model_prepared);assets.configure(catalog);assets.cache_directory=cache_path
	assets.set_process(false)
	set_process(false);return true
func open_network(catalog,definition: Dictionary,gate: Dictionary,shared_pool,current_scope: Array,cache_path: String="")->bool:
	if not start(catalog,shared_pool,current_scope,cache_path):return false
	loader=make_loader();add_child(loader);loader.completed.connect(plan_prepared)
	loader_ticket=loader.request(catalog,definition,gate,scope)
	if loader_ticket<0:fail("Original decorative border plan could not start.");return false
	return true
func open_plan(catalog,value: Dictionary,shared_pool,current_scope: Array,cache_path: String="")->bool:
	if not start(catalog,shared_pool,current_scope,cache_path):return false
	accept_plan(Loader.render_plan(value));return failure.is_empty()
func plan_prepared(ticket: int,received_scope: Array,result: Dictionary)->void:
	if closed or retiring or ticket!=loader_ticket or received_scope!=scope:stats.stale+=1;return
	planning_data={"original_border_plan":result.get("plan",{})}
	stats.plan_worker_ms=result.get("worker_ms",0.0);stats.plan_thread=result.get("thread",0);stats.edge_resource=result.get("edge_resource","");stats.known_missing=result.get("known_missing",false)
	accept_plan(result.get("render",{}))
func accept_plan(value: Dictionary)->void:
	if closed or retiring:return
	if not value.get("ready",false):fail(str(value.get("reason","Original decorative plan is unavailable.")));return
	plans=value.placements;groups=value.models;waiting=groups.keys();stats.plans=plans.size();priority_dirty=true
	if plans.is_empty():complete();return
	update_processing()
func set_priority_origin(value: Vector3)->void:
	if not value.is_finite() or has_priority_origin and priority_origin.distance_squared_to(value)<4.0:return
	priority_origin=value;has_priority_origin=true;priority_dirty=true
	if opened and not closed and not retiring and not done:update_processing()
func refresh_priority()->void:
	if not priority_dirty:return
	priority_dirty=false
	var names: Array=Priority.model_order(groups.keys(),groups,priority_origin,plans)
	var ranks: Dictionary={}
	for index in names.size():ranks[names[index]]=index
	waiting.sort_custom(func(a,b):return int(ranks.get(a,2147483647))<int(ranks.get(b,2147483647)))
	var request_ids: Array=requests.keys()
	request_ids.sort_custom(func(a,b):return int(ranks.get(requests[a].model,2147483647))<int(ranks.get(requests[b].model,2147483647)))
	assets.prioritize(request_ids)
	for indices in groups.values():
		indices.sort_custom(func(a,b):
			var da: float=priority_origin.distance_squared_to(plans[int(a)].position);var db: float=priority_origin.distance_squared_to(plans[int(b)].position)
			return da>db or da==db and int(a)>int(b))
func capacity()->bool:
	return is_instance_valid(assets) and assets.pending.size()+assets.running.size()<mini(int(assets.maximum_pending),maxi(1,int(assets.maximum_workers)*2))
func update_asset_processing()->void:
	if is_instance_valid(assets):assets.set_process(not closed and not retiring and (not assets.pending.is_empty() or not assets.running.is_empty()))
func pump_models()->void:
	var submitted:=0
	while not waiting.is_empty() and submitted<maxi(1,maximum_model_requests_per_frame) and capacity():
		var name:=str(waiting.pop_front());assets.set_process(true);var id: int=assets.request(name,2002,"static-model")
		if id<0:reject_model(name,"Original decorative model request failed.")
		else:requests[id]={"model":name,"generation":generation,"scope":scope.duplicate()};stats.model_jobs+=1
		submitted+=1
	update_asset_processing()
func model_prepared(id: int,result: Dictionary)->void:
	update_asset_processing()
	if closed or retiring or not requests.has(id):stats.stale+=1;return
	var request: Dictionary=requests[id];requests.erase(id)
	if int(request.generation)!=generation or request.scope!=scope:stats.stale+=1;return
	var name:=str(request.model)
	if not str(result.get("error","")).is_empty():reject_model(name,"Original decorative model data is unavailable.")
	else:bundles[name]=result;ready_models.append(name);stats.models_prepared+=1;priority_dirty=true
	update_processing()
func reject_model(name: String,reason: String)->void:
	stats.failed+=groups.get(name,[]).size();groups.erase(name);bundles.erase(name);templates.erase(name);ready_models.erase(name)
	if stats.errors.size()<32:stats.errors.append({"model":name,"reason":reason})
func next_model()->String:
	var chosen:="";var distance:=INF;var ordinal:=2147483647
	for name in ready_models:
		var indices: Array=groups.get(name,[])
		if indices.is_empty():continue
		var index:=int(indices.back());var candidate: float=priority_origin.distance_squared_to(plans[index].position)
		if candidate<distance or candidate==distance and index<ordinal:chosen=str(name);distance=candidate;ordinal=index
	return chosen
func publish()->void:
	var began:=Time.get_ticks_usec();var count:=0
	while not ready_models.is_empty() and count<maxi(1,maximum_instances_per_frame):
		if count>0 and (Time.get_ticks_usec()-began)/1000.0>=publication_budget_ms:break
		if pool.has_method("can_publish") and not pool.can_publish():break
		var name:=next_model()
		if name.is_empty():break
		var unit:=Time.get_ticks_usec();count+=1
		if not templates.has(name):
			var prepared=pool.model_template(bundles[name])
			if prepared==null:
				reject_model(name,"Original decorative native template could not be published.")
				if pool.has_method("publication_finished"):pool.publication_finished(unit)
				continue
			templates[name]=prepared
		var index: int=groups[name].pop_back();var row: Dictionary=plans[index];var instance=templates[name].create()
		if not is_instance_valid(instance):stats.failed+=1
		else:
			add_child(instance);instance.position=row.position;instance.rotation.y=float(row.orientation)*PI/2
			instance.set_meta("native_area_border_index",index);instance.set_meta("native_area_border_scope",scope.duplicate());instances[index]=instance;stats.published+=1
		if pool.has_method("publication_finished"):pool.publication_finished(unit)
		if groups[name].is_empty():ready_models.erase(name);groups.erase(name);bundles.erase(name);templates.erase(name)
	if count>0:stats.publication_frames+=1;stats.max_publish_ms=maxf(float(stats.max_publish_ms),(Time.get_ticks_usec()-began)/1000.0)
func _process(delta: float)->void:
	var began:=Timing.begin();tick(delta);Timing.finish("callback_area_border",began)
func tick(_delta: float)->void:
	if not opened or closed or retiring:return
	refresh_priority();pump_models();publish();update_processing()
func update_processing()->void:
	if not opened or closed or retiring:set_process(false);return
	if not done and waiting.is_empty() and requests.is_empty() and ready_models.is_empty() and (loader_ticket<0 or not plans.is_empty() or stats.get("known_missing",false)):complete()
	set_process(not done and (not ready_models.is_empty() or not waiting.is_empty() and capacity()))
func complete()->void:
	if done:return
	done=true;set_process(false)
	if is_instance_valid(assets):assets.set_process(false)
	finished.emit(snapshot())
func fail(reason: String)->void:
	failure=reason
	if stats.errors.size()<32:stats.errors.append({"reason":reason})
	complete()
func asset_owners()->Array:return [assets] if is_instance_valid(assets) else []
func worker_tasks()->Array:
	var tasks: Array=loader.worker_tasks() if is_instance_valid(loader) else []
	if is_instance_valid(assets):tasks.append_array(assets.running.values())
	return tasks
func begin_retirement()->void:
	if retiring:return
	retiring=true;generation+=1;hide();set_process(false);waiting.clear();requests.clear();ready_models.clear()
	if is_instance_valid(loader):loader.retire_scope()
	if is_instance_valid(assets):assets.retire_scope();assets.set_process(false)
	retire_keys=instances.keys();retire_template_keys=templates.keys()
func retirement_step(budget_ms: float=2.0)->bool:
	if not retiring:begin_retirement()
	var began:=Time.get_ticks_usec();var count:=0
	while not retire_keys.is_empty() and count<maxi(1,maximum_instances_per_frame):
		if count>0 and (Time.get_ticks_usec()-began)/1000.0>=maxf(0.0,budget_ms):break
		var index: int=retire_keys.pop_back();var instance=instances.get(index)
		instances.erase(index)
		if is_instance_valid(instance):
			if instance.has_method("retire"):instance.retire()
			else:instance.queue_free()
		count+=1;stats.retired_instances+=1
	while retire_keys.is_empty() and not retire_template_keys.is_empty() and count<maxi(1,maximum_instances_per_frame):
		if count>0 and (Time.get_ticks_usec()-began)/1000.0>=maxf(0.0,budget_ms):break
		templates.erase(retire_template_keys.pop_back());count+=1
	return retire_keys.is_empty() and retire_template_keys.is_empty()
func detach_prepared_data()->Dictionary:
	if not retiring:return {}
	var payload:={"border_bundles":bundles,"border_plans":plans,"border_groups":groups,"border_planning":planning_data}
	bundles={};plans=[];groups={};planning_data={}
	if is_instance_valid(loader):payload.merge(loader.detach_prepared_data())
	if is_instance_valid(assets):payload.merge(assets.detach_retired_results())
	return payload
func snapshot()->Dictionary:
	var value:=stats.duplicate(true);value.merge({"scope":scope.duplicate(),"done":done,"retiring":retiring,"failure":failure,"instances":instances.size(),"waiting_models":waiting.size(),"requests":requests.size(),"ready_models":ready_models.size(),"player_centered":has_priority_origin,"decorative_only":true,"gameplay_registration":false});return value
func close()->void:
	if closed:return
	begin_retirement();closed=true
	if is_instance_valid(loader):loader.close()
	if is_instance_valid(assets):assets.close()
	while not retirement_step(1000000.0):pass
	bundles.clear();plans.clear();groups.clear();planning_data.clear();templates.clear();pool=null
func _exit_tree()->void:close()
