extends "res://systems/native_render/static_scenery_batches.gd"
# V2 private prototype: compatible different meshes share a material/cell draw.
# The inherited conservative tile eligibility and original physical owners stay.
const MergeData=preload("res://systems/native_render/static_scenery_merge_data.gd")
const CPU_STREAMS:="native_cpu_draw_streams"
var merge_tasks: Dictionary={}
var merge_results: Dictionary={}
var merge_gate:=Mutex.new()
var maximum_workers:=2
var merging_retired:=false

func consider_tile(tile: int,model: Node3D) -> void:
	if merging_retired:return
	var prior: Dictionary={}
	for mesh in model.get("meshes"):
		if mesh is MeshInstance3D:prior[mesh.get_instance_id()]=members.has(mesh.get_instance_id())
	super.consider_tile(tile,model)
	for source in model.get("meshes"):
		if not source is MeshInstance3D or prior.get(source.get_instance_id(),true) or not members.has(source.get_instance_id()):continue
		var id: int=source.get_instance_id();var row: Dictionary=members[id];var old_key:=str(row.group);var old_group: Dictionary=groups[old_key]
		old_group.rows.erase(row)
		if old_group.rows.is_empty():groups.erase(old_key);dirty.erase(old_key)
		var arrays: Variant=source.mesh.get_meta(CPU_STREAMS,null)
		var layout:=MergeData.channel_layout(arrays) if arrays is Array else ""
		if layout.is_empty() or source.mesh.get_surface_count()!=1 or source.mesh.shadow_mesh!=null:
			row.active=false;members.erase(id);stats.eligible_surfaces-=1;_reject("immutable-cpu-draw-streams-unavailable");continue
		var cell:=Vector2i(floori(row.pose.origin.x/cell_size),floori(row.pose.origin.z/cell_size));var origin:=Vector3(cell.x*cell_size,0,cell.y*cell_size)
		var signature:="merge:"+str([cell,source.material_override.get_instance_id(),old_group.properties,layout]);var tail:=int(tails.get(signature,0));var key:=signature+":"+str(tail)
		var count: int=arrays[Mesh.ARRAY_VERTEX].size();var indices: int=arrays[Mesh.ARRAY_INDEX].size()
		if count>MergeData.MAX_VERTICES or indices>MergeData.MAX_INDICES:
			row.active=false;members.erase(id);stats.eligible_surfaces-=1;_reject("merge-source-budget");continue
		if groups.has(key) and (groups[key].rows.size()>=MergeData.MAX_SOURCES or int(groups[key].vertices)+count>MergeData.MAX_VERTICES or int(groups[key].indices)+indices>MergeData.MAX_INDICES):tail+=1;tails[signature]=tail;key=signature+":"+str(tail)
		if not groups.has(key):groups[key]={"material":source.material_override,"properties":old_group.properties,"rows":[],"geometry":null,"queued":false,"epoch":_epoch,"revision":0,"vertices":0,"indices":0,"origin":origin,"job":false}
		var group: Dictionary=groups[key]
		row.group=key;row.arrays=arrays;row.pose.origin-=origin;row.slot=-1;row.original_visible=source.visible
		group.rows.append(row);group.vertices+=count;group.indices+=indices;group.revision+=1
		material_groups[source.material_override.get_instance_id()].groups[key]=true
		_mark_dirty(key)

func _withdraw(id: int) -> void:
	if not members.has(id):return
	var row: Dictionary=members[id]
	if not row.active:return
	row.active=false;_restore(row);members.erase(id);stats.withdrawn_surfaces+=1
	var group: Dictionary=groups.get(row.group,{})
	if group.is_empty():return
	group.revision+=1
	# Do not alter vertices in-place or free render nodes inside Resource.changed
	# callbacks. Hide the complete replacement and restore every original draw;
	# the next bounded publication can build the reduced compatible group.
	var geometry: MeshInstance3D=group.geometry
	if is_instance_valid(geometry):
		geometry.hide();geometry.queue_free();group.geometry=null;stats.active_batches-=1
		for other in group.rows:_restore(other)
	_mark_dirty(str(row.group))

func _bake_worker(key: String,job: Dictionary) -> void:
	var result:=MergeData.bake(job)
	merge_gate.lock();merge_results[key]=result;merge_gate.unlock()

func _start_jobs() -> void:
	var examined:=0
	while not dirty.is_empty() and merge_tasks.size()<maximum_workers and examined<64:
		var key: String=dirty.pop_front();examined+=1
		if not groups.has(key):continue
		var group: Dictionary=groups[key];group.queued=false
		if group.job:continue
		var rows: Array=[]
		for row in group.rows:
			if _current(row)!=null:rows.append({"source_id":row.source_id,"arrays":row.arrays,"pose":row.pose})
		if rows.size()<2:continue
		var job:={"rows":rows,"epoch":_epoch,"revision":int(group.revision)}
		var task:=WorkerThreadPool.add_task(_bake_worker.bind(key,job),false,"Merge immutable static cell draws")
		if task>=0:merge_tasks[key]=task;group.job=true

func flush(budget_ms: float=0.75,maximum_groups: int=1) -> void:
	if closed or merging_retired:return
	var began:=Time.get_ticks_usec();var published:=0
	for key in merge_tasks.keys():
		if published>=maximum_groups or published>0 and (Time.get_ticks_usec()-began)/1000.0>=budget_ms:break
		var task: int=merge_tasks[key]
		if not WorkerThreadPool.is_task_completed(task):continue
		WorkerThreadPool.wait_for_task_completion(task);merge_tasks.erase(key)
		merge_gate.lock();var result: Dictionary=merge_results.get(key,{});merge_results.erase(key);merge_gate.unlock()
		if not groups.has(key):continue
		var group: Dictionary=groups[key];group.job=false
		if int(result.get("epoch",-1))!=_epoch or int(result.get("revision",-1))!=int(group.revision):
			stats["merge_stale_results"]=int(stats.get("merge_stale_results",0))+1;_mark_dirty(str(key));continue
		if not str(result.get("error","Merge result unavailable")).is_empty():
			stats["merge_failures"]=int(stats.get("merge_failures",0))+1;continue
		var rows: Array=[]
		for row in group.rows:
			if _current(row)!=null:rows.append(row)
		if rows.size()!=result.ranges.size():_mark_dirty(str(key));continue
		var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,result.arrays)
		var geometry:=MeshInstance3D.new();geometry.mesh=mesh;geometry.material_override=group.material;geometry.position=group.origin;geometry.custom_aabb=result.bounds
		for index in DRAW_PROPERTIES.size():geometry.set(DRAW_PROPERTIES[index],group.properties[index])
		if not configure_replacement(group,geometry):geometry.free();stats["replacement_context_failures"]=int(stats.get("replacement_context_failures",0))+1;continue
		add_child(geometry)
		if is_instance_valid(group.geometry):group.geometry.hide();group.geometry.queue_free();stats.batch_rebuilds+=1
		else:stats.batches_created+=1;stats.active_batches+=1
		group.geometry=geometry
		_mutating=true
		for row in rows:
			var source:=_current(row)
			if source==null:continue
			_set_source_draw_enabled(source,false);source.set_meta("native_static_batch_draw",true)
			if not row.batched:row.batched=true;stats.active_batched_surfaces+=1;stats.source_draws_replaced+=1
		_mutating=false
		stats["merge_worker_us"]=int(stats.get("merge_worker_us",0))+int(result.worker_us)
		stats["merged_vertices"]=int(stats.get("merged_vertices",0))+int(result.vertices)
		stats["merged_indices"]=int(stats.get("merged_indices",0))+int(result.indices)
		published+=1
	_start_jobs()
	var elapsed:=Time.get_ticks_usec()-began;stats.flush_us+=elapsed;stats.maximum_flush_us=maxi(int(stats.maximum_flush_us),elapsed)

func configure_replacement(_group: Dictionary,_geometry: MeshInstance3D) -> bool:
	# Specialized owners may install verified per-group instance context here,
	# before original draws are suppressed. Terrain's admitted subset uses none.
	return true

func worker_tasks() -> Array:return merge_tasks.values().duplicate()
func has_pending() -> bool:return not dirty.is_empty() or not merge_tasks.is_empty()
func retire_scope() -> void:
	merging_retired=true;_epoch+=1;dirty.clear()
	for group in groups.values():
		if is_instance_valid(group.geometry):group.geometry.hide()
func clear() -> void:
	retire_scope()
	var began:=Time.get_ticks_usec()
	# Final destruction is a join boundary. Normal World retirement must include
	# worker_tasks() before calling clear; no live Node is touched by bake jobs.
	for task in merge_tasks.values():WorkerThreadPool.wait_for_task_completion(int(task))
	merge_tasks.clear();merge_gate.lock();merge_results.clear();merge_gate.unlock()
	stats["merge_close_join_us"]=int(stats.get("merge_close_join_us",0))+Time.get_ticks_usec()-began
	_mutating=true
	for row in members.values():_restore(row)
	for group in groups.values():
		if is_instance_valid(group.geometry):group.geometry.hide();group.geometry.queue_free()
	groups.clear();members.clear();model_members.clear();material_groups.clear();tails.clear();dirty.clear();stats.active_batches=0;stats.active_batched_surfaces=0;_mutating=false;merging_retired=false
func snapshot() -> Dictionary:
	var value:=super.snapshot();value.mode="material-cell-merged";value.pending_workers=merge_tasks.size();value.suppression="RenderingServer instance visibility; Node visibility and layer masks preserved";value.policy="Different immutable geometry shares a material/spatial cell draw; original physical/collision/light owners retained; source CPU draw arrays required";return value
