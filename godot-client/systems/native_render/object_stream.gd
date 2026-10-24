extends Node3D
# Native original-table/model selection for static replicated objects. Actor,
# equipment, animated door state and visual-transform consumers follow separately.
signal finished(state: Dictionary)
const Assets=preload("res://systems/native_data/asset_service.gd")
const Template=preload("res://systems/native_render/model_template.gd")
var assets
var pool
var tables: Dictionary={}
var table_requests: Dictionary={}
var model_requests: Dictionary={}
var groups: Dictionary={}
var waiting: Array=[]
var queue: Array=[]
var templates: Dictionary={}
var instances: Dictionary={}
var snapshot_objects: Array=[]
var area_id: int=-1
var done:=false
var closed:=false
var stats: Dictionary={"planned":0,"rendered":0,"invisible":0,"deferred_actors":0,"deferred_items":0,"errors":[],"warnings":[],"limitations":[],"model_jobs":0}
func configure(catalog, shared_pool, objects: Array, target_area: int, cache_path: String) -> void:
	pool=shared_pool; snapshot_objects=objects; area_id=target_area
	assets=Assets.new(); add_child(assets); assets.configure(catalog); assets.cache_directory=cache_path; assets.completed.connect(prepared)
	for table_name in ["placeables","genericdoors","doortypes"]: table_requests[assets.request(table_name,2017,"2da")]=table_name
func pose(object: Dictionary) -> Dictionary:
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
	for object in snapshot_objects:
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
			if str(row.get("VisibleModel","1"))=="0": stats.invisible+=1; continue
		var name:=str(row.get("ModelName",row.get("Model",""))).to_lower()
		if name.is_empty() or name=="****": stats.errors.append({"id":object.id,"reason":"Original appearance table has no model"}); continue
		placement.merge({"id":int(object.id),"object":object,"model":name}); stats.planned+=1
		if not groups.has(name): groups[name]=[]
		groups[name].append(placement)
	waiting=groups.keys()
func prepared(id: int, result: Dictionary) -> void:
	if closed: return
	if table_requests.has(id):
		var table_name: String=table_requests[id]; table_requests.erase(id)
		if not str(result.error).is_empty(): stats.errors.append({"table":table_name,"reason":result.error})
		else: tables[table_name]=result.value
		if table_requests.is_empty(): plan_objects()
		return
	if not model_requests.has(id): return
	var name: String=model_requests[id]; model_requests.erase(id)
	if not str(result.error).is_empty(): stats.errors.append({"model":name,"reason":result.error,"objects":groups[name].size()}); return
	for texture_name in result.get("missing_textures",[]): stats.warnings.append({"model":name,"texture":texture_name,"reason":"Original texture lookup was recorded as missing; material retained without a bitmap"})
	queue.append({"model":name,"bundle":result,"index":0})
func _process(_delta: float) -> void:
	if closed or done or not is_instance_valid(assets) or not table_requests.is_empty(): return
	while not waiting.is_empty() and assets.pending.size()+assets.running.size()<assets.maximum_pending:
		var name:=str(waiting.pop_front()); var id: int=assets.request(name,2002,"static-model")
		if id<0: stats.errors.append({"model":name,"reason":assets.failure})
		else: model_requests[id]=name; stats.model_jobs+=1
	var began:=Time.get_ticks_usec(); var published:=0
	while not queue.is_empty() and published<4:
		if published>0 and Time.get_ticks_usec()-began>=3000: break
		var entry: Dictionary=queue[0]; var name: String=entry.model
		if not templates.has(name):
			var template:=Template.new()
			if not template.build(entry.bundle,pool): stats.errors.append({"model":name,"reason":template.failure}); queue.pop_front(); continue
			templates[name]=template
			for feature in template.limitations:
				if not stats.limitations.has(feature): stats.limitations.append(feature)
		var placement: Dictionary=groups[name][int(entry.index)]; var instance=templates[name].create()
		if instance==null: stats.errors.append({"id":placement.id,"reason":"Native model instance failed"})
		else:
			add_child(instance); instance.position=placement.position; instance.rotation.y=float(placement.rotation); instance.set_meta("world_object_id",placement.id); instances[placement.id]=instance; stats.rendered+=1
		entry.index+=1; published+=1
		if int(entry.index)>=groups[name].size(): queue.pop_front()
	if waiting.is_empty() and model_requests.is_empty() and queue.is_empty(): done=true; finished.emit(stats.duplicate(true))
func close() -> void:
	if closed: return
	closed=true
	if is_instance_valid(assets): assets.close()
	for instance in instances.values():
		if is_instance_valid(instance): instance.retire()
	instances.clear(); templates.clear(); queue.clear(); model_requests.clear(); waiting.clear(); groups.clear(); snapshot_objects.clear(); tables.clear()
func _exit_tree() -> void: close()
