extends Node
# One bounded native preparation owner per world, shared by all physical
# references. Requests deduplicate resource reads; instantiated Parts stay private.
const Assets=preload("res://systems/native_data/asset_service.gd")
const Actor=preload("res://systems/native_render/actor_instance.gd")
const Profile=preload("res://systems/native_render/frame_profile.gd")
const Priority=preload("res://systems/native_render/stream_priority.gd")
var priority_origin:=Vector3.ZERO
var has_priority_origin:=false
var priority_dirty:=false
func set_priority_origin(value: Vector3) -> void:
	if not value.is_finite() or has_priority_origin and priority_origin.distance_squared_to(value)<4.0: return
	priority_origin=value; has_priority_origin=true; priority_dirty=true
func request_distance(request: Dictionary) -> float:
	var node=current(request)
	return priority_origin.distance_squared_to(node.global_position) if node!=null else INF
func refresh_priority() -> void:
	if not has_priority_origin or not priority_dirty: return
	priority_dirty=false
	var ranked: Array=[]
	for resource in waiting.keys()+jobs.values():
		var distance:=INF
		for request in requests.get(resource,[]): distance=minf(distance,request_distance(request))
		ranked.append({"name":resource,"distance":distance})
	ranked.sort_custom(func(a,b):return a.distance<b.distance or (a.distance==b.distance and str(a.name)<str(b.name)))
	var names: Array=ranked.map(func(row):return row.name); var ordered: Dictionary={}
	for name in names:
		if waiting.has(name): ordered[name]=true
	waiting=ordered
	assets.prioritize(Priority.request_order(jobs,names))
	publication.sort_custom(func(a,b):return request_distance(a.request)<request_distance(b.request))
signal published(reference,model)
var assets
var pool
var generation:=0
var closed:=false
var waiting: Dictionary={}
var jobs: Dictionary={}
var requests: Dictionary={}
var prepared: Dictionary={}
var cache_order: Array=[]
var publication: Array=[]
var maximum_names:=4096
var maximum_cached:=64
var maximum_publications:=2
var stats:={"requested":0,"jobs":0,"cache_hits":0,"published":0,"bundles_published":0,"chunk_models":0,"stale":0,"failed":0,"missing_root_requests":0,"errors":[],"worker_ms":0.0,"max_publication_ms":0.0}
func configure(catalog,shared_pool,cache_path: String="") -> void:
	pool=shared_pool; assets=Assets.new(); add_child(assets); assets.configure(catalog); assets.cache_directory=cache_path; assets.completed.connect(completed)
func request_reference(reference: Node3D,resource: String) -> void:
	request_model(reference,resource,"reference")
func request_bundle(owner: Node3D,resource: String) -> void:
	request_model(owner,resource,"bundle")
func request_model(reference: Node3D,resource: String,kind: String) -> void:
	if closed or not is_instance_valid(assets): reference.reject("Native reference preparation scope is closed"); return
	if not requests.has(resource) and requests.size()+jobs.size()>maximum_names: reference.reject("Native reference preparation exceeds name bound"); return
	stats.requested+=1; reference.generation=generation
	priority_dirty=true
	var request:={"node":weakref(reference),"generation":generation,"resource":resource,"kind":kind}
	if prepared.has(resource):
		stats.cache_hits+=1; publication.append({"request":request,"bundle":prepared[resource]}); return
	# Catalog lookup uses the current ordered bindings, including absent names.
	# A missing root cannot be prepared: avoid a worker, fork and later delivery
	# for every new physical owner of the same absent chunk/reference. Do not
	# cache a failure here: a later catalog mount must be visible immediately,
	# and a present but malformed/unreadable resource keeps its existing path.
	if not assets.catalog.has_resource(resource,2002):
		var reason:="Resource not found: "+resource+":2002"
		stats.failed+=1; stats.missing_root_requests+=1
		# Owner failures remain explicit; bound repetitive diagnostic samples.
		if stats.errors.size()<512: stats.errors.append({"resource":resource,"reason":reason})
		reference.reject("Original referenced model unavailable: "+resource+": "+reason); return
	if not requests.has(resource): requests[resource]=[]; waiting[resource]=true
	requests[resource].append(request)
func current(request: Dictionary):
	var node=request.node.get_ref()
	if closed or request.generation!=generation or not is_instance_valid(node) or not node.is_inside_tree() or node.retired or node.generation!=generation: return null
	var ancestor: Node=node
	while ancestor!=null:
		if ancestor.is_queued_for_deletion(): return null
		ancestor=ancestor.get_parent()
	return node
func cancel_reference(reference: Node3D) -> void:
	for resource in requests.keys():
		requests[resource]=requests[resource].filter(func(request):return request.node.get_ref()!=reference)
		if requests[resource].is_empty():
			waiting.erase(resource)
			# A later owner may join the same live job without duplicate work.
			if not jobs.values().has(resource): requests.erase(resource)
	publication=publication.filter(func(entry):return entry.request.node.get_ref()!=reference)
func completed(id: int,bundle: Dictionary) -> void:
	if closed or not jobs.has(id): return
	var resource:=str(jobs[id]); jobs.erase(id); stats.worker_ms+=float(bundle.get("worker_ms",0))
	var listeners: Array=requests.get(resource,[]); requests.erase(resource)
	if not str(bundle.get("error","")).is_empty():
		stats.failed+=1; stats.errors.append({"resource":resource,"reason":bundle.error})
		for request in listeners:
			var node=current(request)
			if node!=null: node.reject("Original referenced model unavailable: "+resource+": "+str(bundle.error))
		return
	prepared[resource]=bundle; cache_order.erase(resource); cache_order.append(resource)
	while cache_order.size()>maximum_cached: prepared.erase(cache_order.pop_front())
	for request in listeners: publication.append({"request":request,"bundle":bundle})
	priority_dirty=true
func _process(_delta: float) -> void:
	var began:=Profile.begin()
	_profile_process(_delta)
	Profile.finish("callback_references",began)
func _profile_process(_delta: float) -> void:
	if closed or not is_instance_valid(assets): return
	refresh_priority()
	while not waiting.is_empty() and assets.pending.size()+assets.running.size()<mini(assets.maximum_pending,assets.maximum_workers*2):
		var resource:=str(waiting.keys()[0]); waiting.erase(resource)
		var id: int=assets.request(resource,2002,"actor-model",{"relevant_tracks":true})
		if id<0:
			stats.failed+=1; stats.errors.append({"resource":resource,"reason":assets.failure})
			for request in requests.get(resource,[]):
				var node=current(request)
				if node!=null: node.reject(assets.failure)
			requests.erase(resource)
		else: jobs[id]=resource; stats.jobs+=1
	var began:=Time.get_ticks_usec(); var published_count:=0
	while not publication.is_empty() and published_count<maximum_publications:
		if published_count>0 and Time.get_ticks_usec()-began>=3000: break
		if pool!=null and pool.has_method("can_publish") and not pool.can_publish(): break
		var unit_began:=Time.get_ticks_usec()
		var entry: Dictionary=publication.pop_front(); var reference=current(entry.request)
		if reference==null: stats.stale+=1; continue
		if entry.request.get("kind","reference")=="bundle":
			if reference.install_bundle(entry.bundle,generation): stats.bundles_published+=1; published_count+=1
			else: stats.stale+=1
			if pool!=null and pool.has_method("publication_finished"): pool.publication_finished(unit_began)
			continue
		var phase:=Profile.begin(); var model:=Actor.new()
		if not reference.install_model(model,generation): model.free(); stats.stale+=1; continue
		# This ID is private to this model's rig, never a protocol/game registry ID.
		if not model.install([{"bundle":entry.bundle,"initial_clip":"default","follow":false}],pool,0,{}):
			reference.reject(model.failure); stats.failed+=1; stats.errors.append({"resource":entry.request.resource,"reason":model.failure}); model.free(); continue
		published_count+=1; stats.published+=1; published.emit(reference,model)
		if pool.has_method("publication_finished"): pool.publication_finished(unit_began)
		Profile.finish("native_reference_publication",phase)
	stats.max_publication_ms=maxf(stats.max_publication_ms,(Time.get_ticks_usec()-began)/1000.0)
func create_chunk_model(owner: Node3D,bundle: Dictionary):
	if closed or pool==null or not is_instance_valid(owner) or owner.retired or owner.generation!=generation: return null
	var model:=Actor.new(); model.hide(); model.process_mode=Node.PROCESS_MODE_DISABLED; model.top_level=true; owner.add_child(model)
	# Private model ID0, not a protocol ID; each actor owns its rig dictionary.
	if not model.install([{"bundle":bundle,"initial_clip":"","follow":false}],pool,0,{}):
		stats.failed+=1; stats.errors.append({"resource":owner.resource,"reason":model.failure}); model.retire(); return null
	stats.chunk_models+=1; return model
func blocks_control(node: Node,owner: Node) -> bool:
	var ancestor:=node
	while ancestor!=null:
		if ancestor.has_meta("native_nonblocking_effect"): return false
		if ancestor==owner: return true
		ancestor=ancestor.get_parent()
	return false
func ready() -> bool: return waiting.is_empty() and jobs.is_empty() and publication.is_empty()
func ready_for(owner: Node) -> bool:
	# A distant object's references must not delay player control. Requests stay
	# scoped to their actual physical owners, including nested referenced models.
	if closed or not is_instance_valid(owner) or owner.is_queued_for_deletion(): return false
	for listeners in requests.values():
		for request in listeners:
			var node=current(request)
			if node!=null and blocks_control(node,owner): return false
	for entry in publication:
		var node=current(entry.request)
		if node!=null and blocks_control(node,owner): return false
	return true
func snapshot() -> Dictionary:
	var value:=stats.duplicate(true); value.pending=waiting.size()+jobs.size()+publication.size(); value.cached=prepared.size(); value.workers=assets.running.size() if is_instance_valid(assets) else 0; return value
func detach_prepared_data() -> Dictionary:
	# Native decoded graphs only: requests/publication hold live weak owners and
	# stay on the main thread. Call after actual asset workers have completed.
	var payload:={"prepared":prepared}; prepared={}; cache_order=[]; return payload
func close() -> void:
	if closed: return
	closed=true; generation+=1; waiting.clear(); requests.clear(); publication.clear(); jobs.clear(); prepared.clear(); cache_order.clear()
	if is_instance_valid(assets): assets.close()
	pool=null
func _exit_tree() -> void: close()
