extends Node

# Source-only counterpart to ResourcePrefetch. The foreground stream may claim
# a running or completed bundle; this owner never constructs scene instances.
signal finished(key: String,result: Dictionary)
signal idle_reached
const Assets=preload("res://systems/native_data/asset_service.gd")
const Appearance=preload("res://systems/native_data/creature_appearance.gd")
const Placeable=preload("res://systems/native_render/placeable_instance.gd")
var world
var assets
var catalog
var creature_tables: Dictionary={}
var queue: Dictionary={}
var running: Dictionary={}
var staged: Dictionary={}
var stage_serial:=0
var dispatched: Dictionary={}
var request_ids: Dictionary={}
var claimed_running: Dictionary={}
var skipped_dispatch: Dictionary={}
var results: Dictionary={}
var foreground_running: Dictionary={}
var promoted: Dictionary={}
var closed:=false
var limit:=2
var stats:={"completed":0,"failed":0,"skipped":0,"peak":0}
const LOOKAHEAD_KEYS:=8
const LOOKAHEAD_SUBMISSION_MARKS:=128
var lookahead_stats: Dictionary={}
var _lookahead_queue: Dictionary={}
var _lookahead_staged: Dictionary={}
var _lookahead_submitted: Dictionary={}
static func key(name: String,decoder: String,options: Dictionary)->String:
	return JSON.stringify([name,decoder,options])
func configure(owner,source,pool,cache_path: String,maximum: int=2)->void:
	assert(maximum>=1)
	world=owner;catalog=source;limit=maximum
	assets=Assets.new();add_child(assets);assets.maximum_workers=limit;assets.high_priority=false;assets.configure(source);assets.completion_pool=pool;assets.cache_directory=cache_path
	assets.completed.connect(_prepared)
func _current(request: Dictionary)->bool:
	var current: Variant=request.get("current")
	return not closed and is_instance_valid(world) and not world.closed and not world.retiring and (not (current is Callable) or current.call())
func _asset_dispatch_current(id: String)->bool:
	if not running.has(id):return false
	# A foreground stream may have claimed this source after it entered the
	# asset queue. It still needs the ordinary completion even if the original
	# speculative object's own predicate has become stale.
	if not closed and is_instance_valid(world) and not world.closed and not world.retiring:
		if claimed_running.has(id) or _current(running[id]):return true
	skipped_dispatch[id]=true;stats.skipped+=1
	return false
func enqueue(requests: Array)->void:
	if closed or not is_instance_valid(world) or world.closed or world.retiring:return
	for request in requests:
		var id:=str(request.key)
		if not running.has(id) and not promoted.has(id) and not foreground_running.has(id) and not results.has(id):queue[id]=request
	pump()
func prioritize_queued_models(ids: Array)->void:
	var requests: Variant=_object_requests(ids)
	if not requests is Array:return
	if lookahead_stats.is_empty():
		lookahead_stats={"waves":0,"candidateRows":0,"queuedHints":0,"alreadyReady":0,"alreadyRunning":0,
			"notQueued":0,"expiredHints":0,"prioritySubmissions":0,"readyClaims":0,"runningClaims":0,"claimLeadMs":0.0}
	lookahead_stats.waves+=1
	lookahead_stats.candidateRows+=ids.size()
	_lookahead_queue.clear()
	var hinted: Dictionary={}
	for request in requests:
		var id:=str(request.key)
		if hinted.has(id):continue
		hinted[id]=true
		if results.has(id):lookahead_stats.alreadyReady+=1
		elif running.has(id) or foreground_running.has(id) or promoted.has(id):lookahead_stats.alreadyRunning+=1
		elif queue.has(id):
			_lookahead_queue[id]=request
			lookahead_stats.queuedHints+=1
		else:lookahead_stats.notQueued+=1
		if hinted.size()>=LOOKAHEAD_KEYS:break
	if not _lookahead_queue.is_empty():pump()
func _next_lookahead_key()->String:
	for id in _lookahead_queue.keys():
		var hint: Dictionary=_lookahead_queue[id]
		_lookahead_queue.erase(id)
		if queue.has(id) and _current(hint) and _current(queue[id]):return id
		lookahead_stats.expiredHints+=1
	return ""
func pump()->void:
	if closed or not is_instance_valid(world) or world.closed or world.retiring:
		stats.skipped+=queue.size();queue.clear();_notify();return
	while not queue.is_empty() and running.size()<limit:
		var hinted:=_next_lookahead_key() if not _lookahead_queue.is_empty() else ""
		var id:=hinted if not hinted.is_empty() else str(queue.keys()[0])
		var request: Dictionary=queue[id];queue.erase(id)
		if not _current(request):stats.skipped+=1;continue
		# Match the old Promise continuation: reserve a running slot now, then
		# recheck its owner before handing a read to the asset service.
		running[id]=request;stats.peak=maxi(int(stats.peak),running.size())
		if not hinted.is_empty():_lookahead_staged[id]=true
		stage_serial+=1;staged[id]=stage_serial
		call_deferred("_dispatch",id,stage_serial)
	_notify()
func _dispatch(id: String,stage: int)->void:
	if not running.has(id) or int(staged.get(id,-1))!=stage:return # A foreground request claimed this staged slot.
	staged.erase(id)
	var lookahead:=not _lookahead_staged.is_empty() and _lookahead_staged.erase(id)
	var request: Dictionary=running[id]
	if not _current(request):
		running.erase(id);stats.skipped+=1;pump();_notify();return
	var job_id: int=int(assets.request(str(request.name),2002,str(request.decoder),request.options,Callable(self,"_asset_dispatch_current").bind(id)))
	if job_id<0:
		running.erase(id);stats.failed+=1;results[id]={"error":str(assets.failure)}
		finished.emit(id,results[id]);pump();_notify();return
	dispatched[id]=job_id;request_ids[job_id]=id
	if lookahead:
		lookahead_stats.prioritySubmissions+=1
		if _lookahead_submitted.size()>=LOOKAHEAD_SUBMISSION_MARKS:_lookahead_submitted.erase(_lookahead_submitted.keys()[0])
		_lookahead_submitted[id]=Time.get_ticks_usec()
func _prepared(request_id: int,result: Dictionary)->void:
	if not request_ids.has(request_id):return
	var id: String=request_ids[request_id];request_ids.erase(request_id)
	# An already-skipped source may have been claimed by the foreground and
	# replaced under the same key before its deferred asset receipt arrives.
	if int(dispatched.get(id,-1))!=request_id:return
	skipped_dispatch.erase(id)
	if not running.has(id):claimed_running.erase(id);return
	dispatched.erase(id)
	if bool(result.get("cancelled",false)):
		claimed_running.erase(id);running.erase(id);pump();_notify();return
	var request: Dictionary=running[id]
	if not closed and not str(result.get("error","")).is_empty() and not str(request.get("fallbackModel","")).is_empty() and str(request.fallbackModel)!=str(request.name) and (_current(request) or claimed_running.has(id) and is_instance_valid(world) and not world.closed and not world.retiring) and not bool(request.get("fallback_attempted",false)):
		request.fallback_attempted=true
		var fallback_id: int=int(assets.request(str(request.fallbackModel),2002,str(request.decoder),request.options,Callable(self,"_asset_dispatch_current").bind(id)))
		if fallback_id>=0:
			running[id]=request;dispatched[id]=fallback_id;request_ids[fallback_id]=id;return
		result={"error":str(assets.failure)}
	claimed_running.erase(id)
	running.erase(id)
	if closed:return
	results[id]=result
	if str(result.get("error","")).is_empty():stats.completed+=1
	else:stats.failed+=1
	finished.emit(id,results[id])
	pump();_notify()
func claim(id: String,share_immutable_payload: bool=false)->Dictionary:
	if results.has(id):
		if _lookahead_submitted.has(id):_note_lookahead_claim(id,"readyClaims")
		# Consumers that only read prepared model data need their own result
		# envelope. Rig definitions, geometry and rasters can stay shared.
		return {"status":"ready","result":results[id].duplicate(not share_immutable_payload)}
	if running.has(id):
		if skipped_dispatch.has(id):
			var retired_request_id: int=int(dispatched.get(id,-1))
			if retired_request_id>=0:request_ids.erase(retired_request_id)
			running.erase(id);dispatched.erase(id);skipped_dispatch.erase(id);pump();_notify()
		elif not dispatched.has(id):
			promoted[id]=running[id];running.erase(id);staged.erase(id);_lookahead_staged.erase(id);pump();_notify()
		else:
			claimed_running[id]=true
			if _lookahead_submitted.has(id):_note_lookahead_claim(id,"runningClaims")
			return {"status":"running"}
	if foreground_running.has(id):return {"status":"running"}
	if queue.has(id):promoted[id]=queue[id];queue.erase(id);_notify()
	return {}
func _note_lookahead_claim(id: String,status: String)->void:
	lookahead_stats[status]+=1
	lookahead_stats.claimLeadMs+=(Time.get_ticks_usec()-int(_lookahead_submitted[id]))/1000.0
	_lookahead_submitted.erase(id)
func foreground_begin(id: String)->void:
	if not closed and not results.has(id):foreground_running[id]=true
func foreground_done(id: String,result: Dictionary)->void:
	if closed or not foreground_running.has(id):return
	foreground_running.erase(id)
	results[id]=result
	if promoted.has(id):
		var request: Dictionary=promoted[id];promoted.erase(id)
		if not _current(request):stats.skipped+=1
		elif str(result.get("error","")).is_empty():stats.completed+=1
		else:stats.failed+=1
	finished.emit(id,result)
	_notify()
func foreground_cancel(id: String)->void:
	if closed or not foreground_running.has(id):return
	foreground_running.erase(id)
	if promoted.has(id):promoted.erase(id);stats.failed+=1
	finished.emit(id,{"error":"Foreground model source retired"})
	_notify()
func _notify()->void:
	if queue.is_empty() and running.is_empty() and promoted.is_empty():idle_reached.emit()
func idle()->void:
	if not queue.is_empty() or not running.is_empty() or not promoted.is_empty():await idle_reached
func close()->void:
	if closed:return
	closed=true;stats.skipped+=queue.size()+promoted.size()+staged.size();queue.clear()
	# The old disposer waits for running source work after stopping new work.
	# AssetService.close joins its data workers before this owner is released.
	if is_instance_valid(assets):assets.close()
	stats.failed+=dispatched.size()-skipped_dispatch.size();running.clear();staged.clear();dispatched.clear();request_ids.clear();claimed_running.clear();skipped_dispatch.clear();results.clear();foreground_running.clear();promoted.clear();_notify()
	_lookahead_queue.clear();_lookahead_staged.clear();_lookahead_submitted.clear()
	catalog=null;creature_tables.clear();world=null
func snapshot()->Dictionary:
	var state:={"completed":stats.completed,"failed":stats.failed,"skipped":stats.skipped,"peak":stats.peak,"queued":queue.size()+promoted.size(),"pending":running.size(),"limit":limit,"closed":closed}
	if not lookahead_stats.is_empty():state.lookahead=lookahead_stats.duplicate()
	return state
func set_creature_tables(value: Dictionary)->void:
	creature_tables=value
	enqueue_objects()
func _plan_request(plan: Dictionary,current: Callable)->Dictionary:
	var name:=str(plan.get("model",""))
	if name in ["","****"]:return {}
	var fallback:=str(plan.get("fallbackModel",""))
	if not catalog.has_resource(name,2002) and not fallback.is_empty() and catalog.has_resource(fallback,2002):name=fallback
	var options:={"plt_candidates":plan.get("pltCandidates",[]),"relevant_tracks":true}
	if plan.has("paletteColors"):options.palette_colors=plan.paletteColors
	return {"key":key(name,"actor-model",options),"name":name,"decoder":"actor-model","options":options,"fallbackModel":fallback,"current":current}
func _object_current(object_id: int,identity: Dictionary,signature: String)->bool:
	return is_instance_valid(world) and not world.closed and not world.retiring and world.desired.has(object_id) and is_same(world.desired[object_id].object,identity) and str(world.desired[object_id].key)==signature and not bool(identity.get("replicationRemoved",false)) and int(identity.get("areaId",-1))==world.area_id
func enqueue_objects()->void:
	var requests: Variant=_object_requests()
	if requests is Array:enqueue(requests)
func _object_requests(object_ids: Variant=null)->Variant:
	if closed or not is_instance_valid(world) or world.closed or world.retiring or catalog==null or not is_instance_valid(world.drive_collision):return null
	if world.desired.has(world.controlled_id) and not world.instances.has(world.controlled_id):return null
	var static_tables: Dictionary=world.drive_collision.tables
	var requests: Array=[]
	var ids: Variant=world.desired if object_ids==null else object_ids
	for id in ids:
		if object_ids!=null and not world.desired.has(id):continue
		var wanted: Dictionary=world.desired[id];var object: Dictionary=wanted.object;var kind:=int(object.get("objectType",0))
		if kind not in [5,9,10] or int(id)==world.controlled_id or world.instances.has(id) or world.failed_objects.has(id) and str(world.failed_objects[id].key)==str(wanted.key) or int(object.get("areaId",-1))!=world.area_id or bool(object.get("replicationRemoved",false)):continue
		var state: Dictionary=object.get("replicated",{});var fixed: Dictionary=object.get("staticState",object.get("lightState",{}))
		var position: Variant=state.get("position",fixed.get("position")) if kind!=5 else state.get("position")
		if not position is Array or position.size()<3:continue
		var identity: Dictionary=object;var signature:=str(wanted.key);var object_id:=int(id)
		var current:=Callable(self,"_object_current").bind(object_id,identity,signature)
		if kind==5:
			if creature_tables.is_empty():continue
			var planner:=Appearance.new();var plan: Dictionary=planner.plan(object,creature_tables)
			if plan.is_empty():continue
			var pieces: Array=[{"model":plan.model,"fallbackModel":plan.get("fallbackModel","")}]
			pieces.append_array(plan.parts);pieces.append_array(plan.attachments)
			for piece in pieces:
				var request:=_plan_request(piece,current)
				if not request.is_empty():requests.append(request)
		else:
			if static_tables.size()!=4:continue
			var row: Dictionary={}
			if kind==9:
				var appearance:=int(state.get("appearance",fixed.get("appearance",-1)))
				var rows: Array=static_tables.get("placeables",{}).get("orderedRows",[])
				if appearance>=0 and appearance<rows.size():row=rows[appearance]
			else:
				var door_type:=int(state.get("doorType",0));var index:=int(state.get("genericType",0)) if door_type==0 else door_type
				var rows: Dictionary=static_tables.get("genericdoors" if door_type==0 else "doortypes",{}).get("rows",{})
				row=rows.get(index,{})
				if str(row.get("VisibleModel","1"))=="0":continue
			var name:=str(row.get("ModelName",row.get("Model",""))).to_lower()
			if name in ["","****"]:continue
			var animated:=kind==10 or Placeable.requires_animation(state)
			var decoder:="actor-model" if animated else "static-model"
			var options:={"relevant_tracks":true} if animated else {}
			requests.append({"key":key(name,decoder,options),"name":name,"decoder":decoder,"options":options,"current":current})
	return requests
