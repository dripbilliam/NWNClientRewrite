extends "res://systems/native_render/live_world_support.gd"
# Requires the base planner's planning_source_ids() seam. Canonical rows/keys
# remain on desired; only unresolved integer IDs are
# retained here. Existing planner gates, limits, sorting and readiness own plans.
var _pending_model_ids: Dictionary={}
var _pending_touched: Dictionary={}
var _pending_full_dirty:=true
var _pending_capture_ready:=false
var _pending_writer_depth:=0
var _pending_retired:=false
var _pending_generation:=-1
var _pending_area:=-1
var _pending_desired_size:=-1
var _pending_installed_size:=-1
var pending_schedule_counts:={"rebuilds":0,"rebuild_rows":0,"touched":0,"enumerations":0,"enumerated_ids":0,"writer_fallbacks":0,"scope_fallbacks":0,"pruned":0,"external_invalidations":0}

func invalidate_planning() -> void:
	super.invalidate_planning()
	# Canonical receive/removal writers record their actual touched IDs below.
	# Preserve the existing explicit invalidation port for other callers that
	# update owner state between boundaries, including equal-size replacements.
	if _pending_writer_depth==0 and not _pending_retired:
		_pending_full_dirty=true;pending_schedule_counts.external_invalidations+=1

func _pending_stamp() -> void:
	_pending_generation=generation;_pending_area=area_id
	_pending_desired_size=desired.size();_pending_installed_size=installed.size()

func _pending_refresh_id(id: int) -> void:
	if not desired.has(id) or str(installed.get(id,""))==str(desired[id].key):
		_pending_model_ids.erase(id)
	else:
		# Keep exact-key failures here. The authoritative planner skips them,
		# and clearing a failure can retry without inventing another retry policy.
		_pending_model_ids[id]=true

func _pending_rebuild() -> void:
	_pending_model_ids.clear()
	for id in desired:
		pending_schedule_counts.rebuild_rows+=1
		_pending_refresh_id(int(id))
	_pending_touched.clear();_pending_full_dirty=false;_pending_capture_ready=true
	pending_schedule_counts.rebuilds+=1;_pending_stamp()

func _pending_flush() -> void:
	if _pending_writer_depth>0:return
	if _pending_retired or closed or retiring:
		_pending_model_ids.clear();_pending_touched.clear();_pending_capture_ready=false
		return
	if _pending_full_dirty or not _pending_capture_ready or _pending_generation!=generation or _pending_area!=area_id:
		_pending_rebuild();return
	for id in _pending_touched:
		pending_schedule_counts.touched+=1
		_pending_refresh_id(int(id))
	_pending_touched.clear();_pending_stamp()

func _pending_touch(id: int) -> void:
	if _pending_retired:return
	_pending_touched[id]=true
	_pending_flush()

func open(source,area: Dictionary,epoch: int,cache_directory: String,shared_pool=null,entry: Dictionary={}) -> void:
	_pending_writer_depth+=1;_pending_full_dirty=true
	super.open(source,area,epoch,cache_directory,shared_pool,entry)
	_pending_writer_depth-=1;_pending_flush()

func receive(objects: Array,controlled: int) -> void:
	# Full snapshots replace desired as a single canonical boundary. Nested
	# receivers may change the final state; rebuild from the actual owner only
	# after the outermost writer finishes, never from the caller's old array.
	_pending_writer_depth+=1;_pending_full_dirty=true
	super.receive(objects,controlled)
	_pending_writer_depth-=1;_pending_flush()

func receive_delta(objects: Array,removed: Array,controlled: int) -> void:
	_pending_writer_depth+=1
	super.receive_delta(objects,removed,controlled)
	_pending_writer_depth-=1;_pending_flush()

func base_scenery_replace_desired(id: int,wanted: Dictionary) -> void:
	super.base_scenery_replace_desired(id,wanted)
	_pending_touch(id)

func base_scenery_forget_desired(id: int) -> void:
	super.base_scenery_forget_desired(id)
	_pending_touch(id)

func remove_instance(id: int) -> void:
	_pending_writer_depth+=1
	super.remove_instance(id)
	_pending_touched[id]=true
	_pending_writer_depth-=1;_pending_flush()

func planning_source_ids() -> Dictionary:
	# During reentrant receive/removal, preserve the original live enumeration.
	# The inherited planner still performs its existing lifecycle/error gates.
	if _pending_writer_depth>0:
		pending_schedule_counts.writer_fallbacks+=1
		return desired
	if _pending_retired or closed or retiring:return desired
	if _pending_full_dirty or not _pending_capture_ready or _pending_generation!=generation or _pending_area!=area_id or _pending_desired_size!=desired.size() or installed.size()<_pending_installed_size:
		pending_schedule_counts.scope_fallbacks+=1
		_pending_rebuild()
	# Successful ordinary/invisible adoptions publish installed after removal.
	# Prune their small pending set here; no extra signal/provider callback.
	for id in _pending_model_ids.keys():
		if not desired.has(id) or str(installed.get(id,""))==str(desired[id].key):
			_pending_model_ids.erase(id);pending_schedule_counts.pruned+=1
	_pending_installed_size=installed.size()
	pending_schedule_counts.enumerations+=1
	pending_schedule_counts.enumerated_ids+=_pending_model_ids.size()
	return _pending_model_ids

func snapshot(details: bool=true) -> Dictionary:
	var result:=super.snapshot(details)
	result.pending_appearance_schedule=pending_schedule_counts.duplicate()
	result.pending_appearance_schedule.merge({"pending_ids":_pending_model_ids.size(),"writer_depth":_pending_writer_depth,"ready":_pending_capture_ready,"retired":_pending_retired,"scope":"Unresolved appearance IDs only; canonical World planner owns policy"})
	return result

func close() -> void:
	_pending_retired=true;_pending_capture_ready=false
	_pending_model_ids.clear();_pending_touched.clear()
	super.close()
