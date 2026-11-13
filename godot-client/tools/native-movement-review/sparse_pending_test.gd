extends SceneTree
# Future private-stage correctness only. Uses the actual inherited receiver and
# original planner, with visual/readiness services as explicit test doubles.
const Base=preload("res://tools/native-movement-review/authoritative_world.gd")
const Sparse=preload("res://systems/native_render/live_world_pending_appearances.gd")
class QuietCombat:
	extends Node
	func forget(_id: int,_removed: bool=false) -> void:pass
	func sync(_id: int,_source: Dictionary,_instance) -> void:pass
	func close() -> void:pass
class Visual:
	extends Node3D
	func retain_decoded_data() -> Dictionary:return {}
	func retire() -> void:queue_free()
class BaselineWorld:
	extends Base
	var allow_control:=true
	func _enter_tree() -> void:pass
	func ready_for_control() -> bool:return allow_control and instances.has(controlled_id) and desired.has(controlled_id) and installed.get(controlled_id,"")==desired[controlled_id].key
	func ready_for_admission() -> bool:return true
	func apply_poses(_all: bool=false) -> void:pass
	func apply_pose(_id: int) -> void:pass
	func sync_combat(_id: int) -> void:pass
	func observe_facing_target(_object: Dictionary) -> void:pass
class Candidate:
	extends Sparse
	var allow_control:=true
	func _enter_tree() -> void:pass
	func ready_for_control() -> bool:return allow_control and instances.has(controlled_id) and desired.has(controlled_id) and installed.get(controlled_id,"")==desired[controlled_id].key
	func ready_for_admission() -> bool:return true
	func apply_poses(_all: bool=false) -> void:pass
	func apply_pose(_id: int) -> void:pass
	func sync_combat(_id: int) -> void:pass
	func observe_facing_target(_object: Dictionary) -> void:pass
var checks:=0
var failures: Array=[]
func check(value: bool,label: String) -> void:
	checks+=1
	if not value and failures.size()<40:failures.append(label)
func _initialize() -> void:call_deferred("run")
func creature(id: int,appearance: int=0) -> Dictionary:
	return {"id":id,"areaId":91,"objectType":5,"appearance":{"appearance":appearance},"replicated":{"position":[float(id%13),0.0,0.0],"orientation":[1.0,0.0],"animation":0,"walkRate":2000,"runRate":4000}}
func base_static(id: int,appearance: int=0) -> Dictionary:
	return {"id":id,"areaId":91,"objectType":9,"staticState":{"id":id,"appearance":appearance,"position":[float(id%31),float(id%7),0.0],"orientation":[1.0,0.0,0.0]},"replicated":{},"authored":{}}
func pair() -> Array:
	var result: Array=[BaselineWorld.new(),Candidate.new()]
	for world in result:
		root.add_child(world);world.set_process(false);world.area_id=91;world.generation=3
		world.combat=QuietCombat.new();world.add_child(world.combat)
	return result
func receive(worlds: Array,rows: Array,controlled: int=1) -> void:
	for world in worlds:world.receive(rows.duplicate(true),controlled)
func delta(worlds: Array,rows: Array,removed: Array=[],controlled: int=1) -> void:
	for world in worlds:world.receive_delta(rows.duplicate(true),removed.duplicate(),controlled)
func settle(worlds: Array,ids: Array=[]) -> void:
	for world in worlds:
		for id in (world.desired.keys() if ids.is_empty() else ids):
			if not world.instances.has(id):
				var node:=Visual.new();world.add_child(node);world.instances[id]=node
			world.installed[id]=world.desired[id].key
func same(worlds: Array,label: String,inflight: Dictionary={}) -> Dictionary:
	var expected: Dictionary=worlds[0].pending_plan(inflight)
	var actual: Dictionary=worlds[1].pending_plan(inflight)
	check(expected==actual,label+" exact original plan")
	return actual
func dense_active_planning() -> Dictionary:
	var worlds:=pair();var candidate: Candidate=worlds[1]
	var rows: Array=[creature(1)]
	for id in range(2,2002):rows.append(base_static(id))
	receive(worlds,rows);check(same(worlds,"Controlled admission").actors.size()==1,"Controlled object remains exclusive")
	settle(worlds)
	# Keep the inherited quiet shortcut ineligible, as during live background
	# work. No fake owner is ticked; only the real planner reads these keys.
	for world in worlds:world.batches=[{"actors":true,"base_scenery":false,"keys":{999999:"unrelated"}}]
	same(worlds,"Dense first active-plan sweep")
	var rebuilt: int=candidate.pending_schedule_counts.rebuild_rows
	var enumerated: int=candidate.pending_schedule_counts.enumerated_ids
	for frame in 40:same(worlds,"Dense installed scene with one background batch "+str(frame))
	check(candidate.pending_schedule_counts.rebuild_rows==rebuilt,"Active background planning does not rebuild the whole pending index")
	check(candidate.pending_schedule_counts.enumerated_ids==enumerated,"Installed dense scene contributes no candidate IDs")
	var moved:=creature(1);moved.replicated.position=[2.0,3.0,0.0]
	delta(worlds,[moved]);same(worlds,"Movement-only delta under active work")
	check(candidate._pending_model_ids.is_empty(),"Movement without appearance change does not enqueue another model")
	delta(worlds,[creature(3000),creature(3001)])
	var planned:=same(worlds,"New live actors while another model batch is active")
	check(planned.actors.size()==2,"Both new live actors use the original available owner slot")
	for frame in 40:same(worlds,"Only unresolved actors enumerated "+str(frame))
	check(candidate.pending_schedule_counts.rebuild_rows==rebuilt,"Delta arrivals update sparse IDs without a full rebuild")
	check(candidate._pending_model_ids.size()==2,"The metadata retains unresolved IDs only")
	same(worlds,"In-flight actor is skipped",{3000:true})
	for world in worlds:world.failed_objects[3000]={"key":world.desired[3000].key,"error":{"message":"Authored failure"}}
	same(worlds,"Exact failed key skipped")
	for world in worlds:world.failed_objects.erase(3000)
	check(same(worlds,"Cleared exact failure retries").actors.size()==2,"Failure clear needs no new receive to retry")
	delta(worlds,[creature(3001,7)])
	same(worlds,"Same-count appearance replacement")
	delta(worlds,[],[3000]);same(worlds,"Pending removal")
	delta(worlds,[creature(3000,9)]);same(worlds,"Removed pending ID is reused")
	settle(worlds);same(worlds,"Later installations prune pending IDs")
	check(candidate._pending_model_ids.is_empty(),"Published instances leave no stale pending IDs")
	for world in worlds:world.remove_instance(3001)
	check(same(worlds,"Visual retired under active work").actors.size()==1,"Visual retirement enqueues current appearance again")
	for world in worlds:world.generation+=1
	same(worlds,"Generation scope refresh")
	# The inherited explicit invalidation method remains a supported boundary
	# for equal-size owner edits outside canonical receive/removal writers.
	for world in worlds:world.installed[3000]="prior-key-retired-by-explicit-owner"
	candidate.invalidate_planning()
	check(same(worlds,"Explicit invalidation after equal-size owner edit").actors.size()==2,"Explicit invalidation refreshes pending IDs even without a receive")
	receive(worlds,[creature(1),base_static(4000),base_static(4001)])
	same(worlds,"Full replacement after sparse deltas")
	for world in worlds:
		world.batches.clear();world.allow_control=false
	same(worlds,"Before-control readiness policy")
	for world in worlds:world.maximum_actor_batch=0
	same(worlds,"Transient zero quota remains authoritative")
	var evidence:={"checks":checks,"metadata":candidate.pending_schedule_counts.duplicate(),"pending_ids":candidate._pending_model_ids.size()}
	check(candidate.pending_schedule_counts.enumerations>0,"Copied base planner actually calls the candidate enumeration seam")
	for world in worlds:world.batches.clear();world.free()
	return evidence
func reentrant_receivers() -> Dictionary:
	var worlds:=pair();var during: Array=[null,null]
	receive(worlds,[creature(1),base_static(2)]);settle(worlds)
	for index in worlds.size():
		var world=worlds[index];var slot: int=index;var state:={"entered":false}
		world.batches=[{"actors":true,"base_scenery":false,"keys":{999999:"unrelated"}}]
		world.instance_state_changed.connect(func(id: int,_source: Dictionary):
			if id!=1 or state.entered:return
			state.entered=true
			world.receive_delta([creature(7000)],[],1)
			during[slot]=world.pending_plan({}).duplicate(true))
	var moved:=creature(1);moved.replicated.position=[4.0,1.0,0.0]
	delta(worlds,[moved])
	check(during[0] is Dictionary and during[0]==during[1],"Reentrant admission sees the original live desired state during a receive writer")
	check(during[1].actors.size()==1 and int(during[1].actors[0].id)==7000,"Reentrant receive cannot hide the newly pending actor")
	var candidate: Candidate=worlds[1]
	check(candidate.pending_schedule_counts.writer_fallbacks>0,"Reentrant planning executes the explicit live-writer fallback")
	check(same(worlds,"Outermost writer returns with latest pending state").actors.size()==1,"Nested touched IDs survive outer receive completion")
	var result: Dictionary=candidate.pending_schedule_counts.duplicate()
	for world in worlds:world.batches.clear();world.free()
	return result
func admission_and_lifecycle() -> Dictionary:
	var worlds:=pair();var candidate: Candidate=worlds[1]
	var rows: Array=[creature(1),base_static(10),base_static(11),creature(12),creature(13),base_static(14)]
	rows[1].staticState.position=[1.0,0.0,0.0];rows[2].staticState.position=[-1.0,0.0,0.0]
	rows[5].usable=true
	receive(worlds,rows);settle(worlds,[1])
	var plan:=same(worlds,"Mixed base/live owner policy")
	check(plan.base_statics.size()==2 and int(plan.base_statics[0].id)==10 and int(plan.base_statics[1].id)==11,"Base distance ties retain original integer ID order")
	check(not plan.actors.is_empty() and plan.statics.is_empty(),"Base and nearest actor group consume the two owner slots")
	for world in worlds:
		world.maximum_actor_batch=1;world.maximum_static_batch=1;world.maximum_base_static_batch=1;world.maximum_stream_wave=2
	same(worlds,"Mixed per-group quotas and stream-wave limit")
	same(worlds,"Current in-flight base and actor keys",{10:true,12:true})
	for world in worlds:
		world.batches=[{"actors":false,"base_scenery":true,"keys":{10:world.desired[10].key}}]
	same(worlds,"Active base wave preserves spare live slot",{10:true})
	for world in worlds:world.base_live_idle_revision=world.base_live_revision
	same(worlds,"Existing base-live idle revision guard")
	for world in worlds:
		world.batches.clear();world.allow_control=false;world.entry_prefetch_enabled=false
	check(same(worlds,"Before-control prefetch disabled").base_statics.is_empty(),"Disabled entry prefetch stays disabled")
	for world in worlds:
		world.entry_prefetch_enabled=true;world.has_priority_origin=true;world.priority_origin=Vector3.ZERO
	check(same(worlds,"Before-control base-only prefetch").actors.is_empty(),"Entry prefetch does not admit ordinary live actors")
	var invalid:=creature(5000);invalid.areaId=92
	var removed:=creature(5001);removed.replicationRemoved=true
	var unsupported:=creature(5002);unsupported.objectType=4
	delta(worlds,[invalid,removed,unsupported]);same(worlds,"Existing receiver rejects removed, outside-area and unsupported rows")
	check(not candidate.desired.has(5000) and not candidate.desired.has(5001) and not candidate.desired.has(5002),"Rejected rows cannot enter sparse metadata")
	for world in worlds:world.retiring=true
	check(same(worlds,"Retirement stops new admission").base_statics.is_empty(),"Retiring plan remains empty")
	for world in worlds:world.close()
	check(candidate._pending_model_ids.is_empty() and candidate._pending_touched.is_empty() and candidate._pending_retired,"Close retires all pending metadata")
	delta(worlds,[creature(6000)]);receive(worlds,[creature(6001)])
	check(candidate.desired.is_empty() and candidate._pending_model_ids.is_empty(),"Late receive after close cannot resurrect pending work")
	var evidence: Dictionary=candidate.pending_schedule_counts.duplicate()
	for world in worlds:world.free()
	return evidence
func run() -> void:
	var report:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):report=arg.substr(9)
	if report.is_empty() or FileAccess.file_exists(report):quit(2);return
	var result:=dense_active_planning();var reentrant:=reentrant_receivers();var lifecycle:=admission_and_lifecycle()
	await process_frame;await process_frame
	var output:={"success":failures.is_empty(),"checks":checks,"failures":failures,"result":result,"reentrant":reentrant,"lifecycle":lifecycle,"scope":"Private actual planner/receiver dense active-admission, nested-receive and lifecycle comparison with visual/readiness doubles. No engine-performance/FPS, real assets, exhaustive lifecycle/reentrancy or native binary execution acceptance."}
	var file:=FileAccess.open(report,FileAccess.WRITE);file.store_string(JSON.stringify(output,"  "));file.close();quit(0 if failures.is_empty() else 1)
