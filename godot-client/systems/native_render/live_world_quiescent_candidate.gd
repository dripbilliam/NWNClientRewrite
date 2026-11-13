extends "res://systems/native_render/live_world.gd"
# Isolated candidate, not imported by normal launches. The authoritative World
# still owns all data and planning. Retain only the proof that no work is left.
var planning_cache_counts: Dictionary={"base_calls":0,"hits":0,"verification_rows":0,"invalidations":0}
var _planning_revision:=0
var _planning_quiet:=false
var _quiet_generation:=-1
var _quiet_area:=-1
var _quiet_controlled:=-1
var _quiet_desired:=-1
var _quiet_installed:=-1
var _quiet_failed:=-1
var _received_quiet_finished:=false

func invalidate_planning() -> void:
	_planning_revision+=1
	_planning_quiet=false
	planning_cache_counts.invalidations+=1

func _quiet_scope_matches() -> bool:
	return _quiet_generation==generation and _quiet_area==area_id and _quiet_controlled==controlled_id and _quiet_desired==desired.size() and _quiet_installed==installed.size() and _quiet_failed==failed_objects.size()

func _remember_quiet() -> void:
	_planning_quiet=true
	_quiet_generation=generation;_quiet_area=area_id;_quiet_controlled=controlled_id
	_quiet_desired=desired.size();_quiet_installed=installed.size();_quiet_failed=failed_objects.size()

func receive(objects: Array,controlled: int) -> void:
	invalidate_planning()
	super.receive(objects,controlled)
	# Public signals during receive may re-enter another state update/planner.
	# Only a subsequent completed-boundary plan can establish quiescence again.
	invalidate_planning()

func received_snapshot_scope_begin(objects: Array,controlled: int) -> void:
	invalidate_planning()
	_received_quiet_finished=false
	super.received_snapshot_scope_begin(objects,controlled)

func received_snapshot_scope_step() -> bool:
	if not super.received_snapshot_scope_step():return false
	# Original quiet.receive invalidates before returning to support.receive's
	# perception observer, which may synchronously invoke another planner.
	if not _received_quiet_finished:_received_quiet_finished=true;invalidate_planning()
	return true

func received_snapshot_scope_end(objects: Array,controlled: int,completed: bool) -> void:
	super.received_snapshot_scope_end(objects,controlled,completed)
	if not _received_quiet_finished:invalidate_planning()
	_received_quiet_finished=false

func receive_delta(objects: Array,removed: Array,controlled: int) -> void:
	var was_quiet:=_planning_quiet and _quiet_scope_matches()
	var prior_keys: Dictionary={}
	for object in objects:
		var id:=int(object.id)
		prior_keys[id]=desired[id].key if desired.has(id) else null
	invalidate_planning()
	var boundary_revision:=_planning_revision
	super.receive_delta(objects,removed,controlled)
	# A movement/name/door-state-only delta must not reintroduce the complete
	# world scan. Read the keys already computed by the authoritative receiver;
	# do not hash appearance/equipment again or retain another entity store.
	if not was_quiet or _planning_revision!=boundary_revision or not removed.is_empty() or not _quiet_scope_matches():return
	for id in prior_keys:
		var current_key: Variant=desired[id].key if desired.has(id) else null
		if prior_keys[id]!=current_key:return
	_planning_quiet=true

func remove_instance(id: int) -> void:
	invalidate_planning()
	super.remove_instance(id)

func pending_plan(inflight: Dictionary) -> Dictionary:
	# Keep readiness/error/lifecycle gates live. In-flight work never uses a
	# settled proof; ordinary owner completion and retry semantics stay intact.
	var can_cache: bool=not closed and not retiring and stats.errors.is_empty() and batches.is_empty() and inflight.is_empty() and ready_for_control()
	if can_cache and _planning_quiet and _quiet_scope_matches():
		planning_cache_counts.hits+=1
		return {"actors":[],"statics":[],"base_statics":[]}
	_planning_quiet=false
	planning_cache_counts.base_calls+=1
	var plan: Dictionary=super.pending_plan(inflight)
	if not can_cache or not plan.actors.is_empty() or not plan.statics.is_empty() or not plan.get("base_statics",[]).is_empty():return plan
	# An empty result caused by limits, an unresolved pose or a transient gate
	# is not a proof of completion. Verify exact installed/failed appearance keys
	# once; subsequent unchanged frames can return in constant time.
	for id in desired:
		planning_cache_counts.verification_rows+=1
		var key:=str(desired[id].key)
		if str(installed.get(id,""))==key:continue
		if failed_objects.has(id) and str(failed_objects[id].key)==key:continue
		return plan
	_remember_quiet()
	return plan

func close() -> void:
	invalidate_planning()
	super.close()
