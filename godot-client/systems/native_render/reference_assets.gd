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
var reference_trees: Dictionary={}
var reference_tree_jobs: Dictionary={}
var prefetched_models: Dictionary={}
var cache_order: Array=[]
var publication: Array=[]
var prefetched_publication: Array=[]
var maximum_names:=4096
var maximum_cached:=64
var maximum_publications:=2
var stats:={"requested":0,"jobs":0,"cache_hits":0,"published":0,"bundles_published":0,"chunk_models":0,"stale":0,"failed":0,"missing_root_requests":0,"errors":[],"worker_ms":0.0,"max_publication_ms":0.0}
func _init() -> void: set_process(false)
func _ready() -> void: _refresh_processing()
func _refresh_processing() -> void:
	set_process(not closed and is_instance_valid(assets) and (not waiting.is_empty() or not jobs.is_empty() or not publication.is_empty() or not reference_tree_jobs.is_empty()))
func configure(catalog,shared_pool,cache_path: String="") -> void:
	pool=shared_pool; assets=Assets.new(); add_child(assets); assets.configure(catalog); assets.cache_directory=cache_path; assets.completed.connect(completed)
	_refresh_processing()
func request_reference(reference: Node3D,resource: String) -> void:
	request_model(reference,resource,"reference")
func request_bundle(owner: Node3D,resource: String) -> void:
	request_model(owner,resource,"bundle")
# Mirror the old per-root recursive reference-asset read before a model owner is
# constructed. A tree owns decoded children until its last scene/admission owner
# releases them; closing the world releases any remaining tree.
func prefetch_tree(resource: String,bundle: Dictionary,owner: Node=null,admission: String="") -> Dictionary:
	var root:=resource.to_lower()
	if closed or root.is_empty() or not str(bundle.get("error","")).is_empty():return {"status":"failed","reason":"Referenced model name or root asset is unavailable"}
	if not reference_trees.has(root):
		var state: Dictionary={"status":"pending","reason":"","cache":{},"stack":[{"name":root,"bundle":bundle,"ancestors":[root],"index":0}],"awaiting":false,"owners":{},"admissions":{}}
		state.cache[root]=bundle
		reference_trees[root]=state
	if is_instance_valid(owner):reference_trees[root].owners[owner.get_instance_id()]=weakref(owner)
	if not admission.is_empty():reference_trees[root].admissions[admission]=true
	_prefetch_advance(root)
	var tree: Dictionary=reference_trees[root]
	return {"status":tree.status,"reason":tree.reason}
func release_admission(resource: String,admission: String) -> void:
	var root:=resource.to_lower()
	if admission.is_empty() or not reference_trees.has(root):return
	var tree: Dictionary=reference_trees[root]
	tree.admissions.erase(admission)
	if tree.admissions.is_empty() and tree.owners.is_empty():_release_tree(root)
func _release_tree(root: String) -> void:
	if not reference_trees.has(root):return
	reference_trees.erase(root)
	for id in reference_tree_jobs.keys():
		if str(reference_tree_jobs[id].root)==root:reference_tree_jobs.erase(id)
	prefetched_models.clear()
	for key in reference_trees.keys():
		var tree: Dictionary=reference_trees[key]
		if tree.status!="ready":continue
		for name in tree.cache.keys():
			if name!=key:prefetched_models[name]=tree.cache[name]
	_refresh_processing()
func _prefetch_fail(root: String,reason: String) -> void:
	if not reference_trees.has(root):return
	var tree: Dictionary=reference_trees[root]
	tree.status="failed";tree.reason=reason;tree.awaiting=false;tree.stack.clear();tree.cache.clear()
func _prefetch_advance(root: String) -> void:
	if closed or not is_instance_valid(assets) or not reference_trees.has(root):return
	var tree: Dictionary=reference_trees[root]
	if tree.status!="pending" or tree.awaiting:return
	while not tree.stack.is_empty():
		var frame: Dictionary=tree.stack.back()
		var nodes: Array=frame.bundle.value.nodes
		if int(frame.index)>=nodes.size():tree.stack.pop_back();continue
		var row: Dictionary=nodes[int(frame.index)];frame.index=int(frame.index)+1
		if not row.has("reference") or (row.has("type") and str(row.type)!="reference"):continue
		var header: Variant=row.reference
		if not header is Dictionary or not header.get("model","") is String:
			_prefetch_fail(root,"Referenced model name is unavailable at "+str(frame.name)+"/"+str(row.get("name","")));return
		# The binary parser already terminates the original fixed-width name.
		var child:=str(header.model).to_lower()
		if child.is_empty():_prefetch_fail(root,"Referenced model name is unavailable");return
		if frame.ancestors.has(child):
			var trail:=PackedStringArray(frame.ancestors+[child])
			_prefetch_fail(root,"Referenced model cycle: "+" -> ".join(trail));return
		if tree.cache.has(child):continue
		var child_bundle: Dictionary=prefetched_models.get(child,{})
		if not child_bundle.is_empty():
			tree.cache[child]=child_bundle;tree.stack.append({"name":child,"bundle":child_bundle,"ancestors":frame.ancestors+[child],"index":0});continue
		if assets.pending.size()+assets.running.size()+assets.repairing.size()>=assets.maximum_pending:
			frame.index=int(frame.index)-1;return
		var id: int=assets.request(child,2002,"actor-model",{"relevant_tracks":true,"references":true})
		if id<0:_prefetch_fail(root,"Referenced model "+child+": "+assets.failure);return
		tree.awaiting=true;reference_tree_jobs[id]={"root":root,"child":child,"ancestors":frame.ancestors+[child]};return
	tree.status="ready"
	for name in tree.cache.keys():
		if name!=root:prefetched_models[name]=tree.cache[name]
func request_model(reference: Node3D,resource: String,kind: String) -> void:
	if closed or not is_instance_valid(assets): reference.reject("Native reference preparation scope is closed"); return
	if not requests.has(resource) and requests.size()+jobs.size()>maximum_names: reference.reject("Native reference preparation exceeds name bound"); return
	stats.requested+=1; reference.generation=generation
	if kind=="reference":
		var root:=str(reference.get("origin_resource")).to_lower()
		if reference_trees.has(root):reference_trees[root].owners[reference.get_instance_id()]=weakref(reference)
	priority_dirty=true
	var request:={"node":weakref(reference),"generation":generation,"resource":resource,"kind":kind}
	if kind=="reference" and prefetched_models.has(resource):
		var origin:=str(reference.get("origin_resource")).to_lower()
		var gated:=false
		for tree in reference_trees.values():
			if tree.status=="ready" and tree.cache.has(origin):gated=true;break
		if gated:
			stats.cache_hits+=1;prefetched_publication.append({"request":request,"bundle":prefetched_models[resource]});return
	if prepared.has(resource) or prefetched_models.has(resource):
		stats.cache_hits+=1; publication.append({"request":request,"bundle":prepared.get(resource,prefetched_models.get(resource))}); _refresh_processing(); return
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
	_refresh_processing()
func current(request: Dictionary):
	var node=request.node.get_ref()
	if closed or request.generation!=generation or not is_instance_valid(node) or not node.is_inside_tree() or node.retired or node.generation!=generation: return null
	var ancestor: Node=node
	while ancestor!=null:
		if ancestor.is_queued_for_deletion(): return null
		ancestor=ancestor.get_parent()
	return node
func cancel_reference(reference: Node3D) -> void:
	var owner_root:=str(reference.get("origin_resource")).to_lower()
	for root in reference_trees.keys():
		var tree: Dictionary=reference_trees[root]
		tree.owners.erase(reference.get_instance_id())
		if tree.owners.is_empty() and tree.admissions.is_empty() and owner_root==root:
			_release_tree(str(root))
	for resource in requests.keys():
		requests[resource]=requests[resource].filter(func(request):return request.node.get_ref()!=reference)
		if requests[resource].is_empty():
			waiting.erase(resource)
			# A later owner may join the same live job without duplicate work.
			if not jobs.values().has(resource): requests.erase(resource)
	publication=publication.filter(func(entry):return entry.request.node.get_ref()!=reference)
	prefetched_publication=prefetched_publication.filter(func(entry):return entry.request.node.get_ref()!=reference)
	_refresh_processing()
func publish_prefetched_tree(root: Node3D) -> Dictionary:
	if closed or not is_instance_valid(root) or not root.is_inside_tree():return {"status":"failed","reason":"Native reference scene root is unavailable","equipmentItemId":-1,"sourcePieceIndex":-1}
	var delivered: Array=[]
	while true:
		var selected:=-1
		for index in prefetched_publication.size():
			var candidate=current(prefetched_publication[index].request)
			if candidate!=null and (candidate==root or root.is_ancestor_of(candidate)):selected=index;break
		if selected<0:break
		var entry: Dictionary=prefetched_publication.pop_at(selected)
		var reference=current(entry.request)
		if reference==null:continue
		var equipment_item_id:=int(reference.get_meta("native_equipment_item_id",-1))
		var source_piece_index:=int(reference.get_meta("native_source_piece_index",-1))
		var model:=Actor.new()
		if not reference.install_model(model,generation):model.free();return {"status":"failed","reason":"Native referenced model could not attach to its physical part","equipmentItemId":equipment_item_id,"sourcePieceIndex":source_piece_index}
		if not model.install([{"bundle":entry.bundle,"initial_clip":"default","follow":false,"equipmentItemId":equipment_item_id,"sourcePieceIndex":source_piece_index}],pool,0,{}):
			var reason:=model.failure;reference.reject(reason);return {"status":"failed","reason":reason,"equipmentItemId":equipment_item_id,"sourcePieceIndex":source_piece_index}
		delivered.append({"reference":reference,"model":model})
	for reference in root.find_children("native_reference","Node3D",true,false):
		if not str(reference.get("failure")).is_empty():return {"status":"failed","reason":str(reference.get("failure")),"equipmentItemId":int(reference.get_meta("native_equipment_item_id",-1)),"sourcePieceIndex":int(reference.get_meta("native_source_piece_index",-1))}
		if not is_instance_valid(reference.get("model68")):return {"status":"failed","reason":"Native referenced model was not constructed before scene admission","equipmentItemId":int(reference.get_meta("native_equipment_item_id",-1)),"sourcePieceIndex":int(reference.get_meta("native_source_piece_index",-1))}
	for entry in delivered:
		stats.published+=1;published.emit(entry.reference,entry.model)
	_refresh_processing()
	return {"status":"ready"}
func completed(id: int,bundle: Dictionary) -> void:
	if reference_tree_jobs.has(id):
		var job: Dictionary=reference_tree_jobs[id];reference_tree_jobs.erase(id)
		var root:=str(job.root)
		if closed or not reference_trees.has(root):return
		var tree: Dictionary=reference_trees[root];tree.awaiting=false
		if not str(bundle.get("error","")).is_empty():_prefetch_fail(root,"Referenced model "+str(job.child)+": "+str(bundle.error))
		else:
			tree.cache[str(job.child)]=bundle
			tree.stack.append({"name":str(job.child),"bundle":bundle,"ancestors":job.ancestors,"index":0})
			_prefetch_advance(root)
		_refresh_processing()
		return
	if closed or not jobs.has(id): return
	var resource:=str(jobs[id]); jobs.erase(id); stats.worker_ms+=float(bundle.get("worker_ms",0))
	var listeners: Array=requests.get(resource,[]); requests.erase(resource)
	if not str(bundle.get("error","")).is_empty():
		stats.failed+=1; stats.errors.append({"resource":resource,"reason":bundle.error})
		for request in listeners:
			var node=current(request)
			if node!=null: node.reject("Original referenced model unavailable: "+resource+": "+str(bundle.error))
		_refresh_processing()
		return
	prepared[resource]=bundle; cache_order.erase(resource); cache_order.append(resource)
	while cache_order.size()>maximum_cached: prepared.erase(cache_order.pop_front())
	for request in listeners: publication.append({"request":request,"bundle":bundle})
	priority_dirty=true
	_refresh_processing()
func _process(_delta: float) -> void:
	var began:=Profile.begin()
	_profile_process(_delta)
	Profile.finish("callback_references",began)
func _profile_process(_delta: float) -> void:
	if closed or not is_instance_valid(assets): return
	for root in reference_trees.keys():_prefetch_advance(str(root))
	refresh_priority()
	while not waiting.is_empty() and assets.pending.size()+assets.running.size()<mini(assets.maximum_pending,assets.maximum_workers*2):
		var resource:=str(waiting.keys()[0]); waiting.erase(resource)
		var id: int=assets.request(resource,2002,"actor-model",{"relevant_tracks":true,"references":true})
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
	_refresh_processing()
func create_chunk_model(owner: Node3D,bundle: Dictionary):
	if closed or pool==null or not is_instance_valid(owner) or owner.retired or owner.generation!=generation: return null
	var model:=Actor.new(); model.hide(); model.process_mode=Node.PROCESS_MODE_DISABLED; model.top_level=true; owner.add_child(model)
	# Private model ID0, not a protocol ID; each actor owns its rig dictionary.
	if not model.install([{"bundle":bundle,"initial_clip":"","follow":false}],pool,0,{}):
		stats.failed+=1; stats.errors.append({"resource":owner.resource,"reason":model.failure}); model.retire(); return null
	var constructed: Dictionary=publish_prefetched_tree(model)
	if constructed.status=="failed":
		stats.failed+=1;stats.errors.append({"resource":owner.resource,"reason":str(constructed.reason)});model.retire();return null
	stats.chunk_models+=1; return model
func blocks_control(node: Node,owner: Node) -> bool:
	var ancestor:=node
	while ancestor!=null:
		if ancestor.has_meta("native_nonblocking_effect"): return false
		if ancestor==owner: return true
		ancestor=ancestor.get_parent()
	return false
func ready() -> bool: return waiting.is_empty() and jobs.is_empty() and publication.is_empty() and prefetched_publication.is_empty() and reference_tree_jobs.is_empty()
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
	for entry in prefetched_publication:
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
	closed=true; generation+=1; waiting.clear(); requests.clear(); publication.clear(); prefetched_publication.clear(); jobs.clear(); prepared.clear(); cache_order.clear(); reference_trees.clear(); reference_tree_jobs.clear(); prefetched_models.clear()
	if is_instance_valid(assets): assets.close()
	pool=null
	_refresh_processing()
func _exit_tree() -> void: close()
