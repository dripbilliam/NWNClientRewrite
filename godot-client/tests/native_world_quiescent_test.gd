extends SceneTree
const Original=preload("res://systems/native_render/live_world.gd")
const Candidate=preload("res://systems/native_render/live_world_quiescent_candidate.gd")
class QuietCombat:
	extends Node
	func forget(_id: int,_removed: bool=false) -> void:pass
	func sync(_id: int,_source: Dictionary,_instance) -> void:pass
	func close() -> void:pass
class Visual:
	extends Node3D
	func retain_decoded_data() -> Dictionary:return {}
	func retire() -> void:queue_free()
class OriginalHarness:
	extends Original
	var allow_control:=true
	func _enter_tree() -> void:pass
	func ready_for_control() -> bool:return allow_control and desired.has(controlled_id) and instances.has(controlled_id) and installed.get(controlled_id,"")==desired[controlled_id].key
	func ready_for_admission() -> bool:return true
	func apply_poses(_include_statics: bool=false) -> void:pass
	func apply_pose(_id: int) -> void:pass
	func sync_combat(_id: int) -> void:pass
	func observe_facing_target(_object: Dictionary) -> void:pass
class CandidateHarness:
	extends Candidate
	var allow_control:=true
	func _enter_tree() -> void:pass
	func ready_for_control() -> bool:return allow_control and desired.has(controlled_id) and instances.has(controlled_id) and installed.get(controlled_id,"")==desired[controlled_id].key
	func ready_for_admission() -> bool:return true
	func apply_poses(_include_statics: bool=false) -> void:pass
	func apply_pose(_id: int) -> void:pass
	func sync_combat(_id: int) -> void:pass
	func observe_facing_target(_object: Dictionary) -> void:pass
var checks:=0
var failures: Array=[]
var observations: Dictionary={}
func check(value: bool,label: String) -> void:
	checks+=1
	if not value and failures.size()<40:failures.append(label)
func _initialize() -> void:call_deferred("run")
func creature(id: int=1,appearance: int=0) -> Dictionary:
	return {"id":id,"areaId":91,"objectType":5,"appearance":{"appearance":appearance},"replicated":{"position":[0,0,0],"orientation":[1,0],"animation":0,"walkRate":2000,"runRate":4000}}
func scenery(id: int,appearance: int=0,kind: int=9) -> Dictionary:
	if kind==10:return {"id":id,"areaId":91,"objectType":10,"replicated":{"position":[id,0,0],"doorType":appearance,"genericType":0,"doorOpenState":0}}
	return {"id":id,"areaId":91,"objectType":9,"staticState":{"position":[id,0,0],"appearance":appearance,"usable":false,"static":true}}
func pair() -> Array:
	var a:=OriginalHarness.new();var b:=CandidateHarness.new()
	for world in [a,b]:
		root.add_child(world);world.set_process(false);world.area_id=91;world.generation=3
		world.combat=QuietCombat.new();world.add_child(world.combat)
	return [a,b]
func receive(worlds: Array,objects: Array,controlled: int=1) -> void:
	for world in worlds:world.receive(objects.duplicate(true),controlled)
func delta(worlds: Array,objects: Array,removed: Array=[],controlled: int=1) -> void:
	for world in worlds:world.receive_delta(objects.duplicate(true),removed.duplicate(),controlled)
func settle(worlds: Array) -> void:
	for world in worlds:
		for id in world.desired:
			if not world.instances.has(id):
				var node:=Visual.new();world.add_child(node);world.instances[id]=node
			world.installed[id]=world.desired[id].key
func same(worlds: Array,label: String,inflight: Dictionary={}) -> Dictionary:
	var a: Dictionary=worlds[0].pending_plan(inflight)
	var b: Dictionary=worlds[1].pending_plan(inflight)
	check(a==b,label+" exact authoritative plan")
	return b
func dispose(worlds: Array) -> void:
	for world in worlds:world.free()
func lifecycle() -> void:
	var worlds:=pair();var candidate=worlds[1]
	receive(worlds,[creature(),scenery(2),scenery(3,0,10)])
	check(same(worlds,"Initial exclusive controlled request").actors.size()==1,"Controlled character remains first")
	settle(worlds);same(worlds,"First settled proof")
	var scans: int=candidate.planning_cache_counts.base_calls
	for frame in 120:same(worlds,"Unchanged settled frame "+str(frame))
	check(candidate.planning_cache_counts.base_calls==scans,"120 settled frames perform no base whole-world planning scan")
	var moved:=scenery(2);moved.staticState.position=[-5,8,1]
	delta(worlds,[moved]);same(worlds,"Received position-only delta")
	check(candidate.planning_cache_counts.base_calls==scans,"Position-only delta retains proven empty plan")
	var door:=scenery(3,0,10);door.replicated.doorOpenState=1
	delta(worlds,[door]);same(worlds,"Received door open-state delta")
	check(candidate.planning_cache_counts.base_calls==scans,"Door state is live without invalidating unchanged model key")
	var named:=creature();named.appearance.name={"text":"Changed name"}
	delta(worlds,[named]);same(worlds,"Received name-only delta")
	check(candidate.planning_cache_counts.base_calls==scans,"Creature name-only delta retains settled proof")
	delta(worlds,[scenery(2,1)])
	check(same(worlds,"Same-count appearance replacement").statics.size()==1,"Changed appearance is scheduled despite unchanged entity count")
	settle(worlds);same(worlds,"Replacement completed")
	delta(worlds,[scenery(4)])
	check(same(worlds,"Streamed-in static").statics.size()==1,"Static noninteractable objects remain planned")
	same(worlds,"In-flight static",{4:true})
	check(not candidate._planning_quiet,"In-flight emptiness never creates a settled proof")
	for world in worlds:world.failed_objects[4]={"key":world.desired[4].key,"error":{"message":"Authored missing resource"}}
	same(worlds,"Exact failed appearance does not retry every frame")
	check(candidate._planning_quiet,"Exact installed/failed keys can establish quiescence")
	delta(worlds,[scenery(4,2)])
	check(same(worlds,"Failed appearance changes").statics.size()==1,"Changed failed key is retried")
	settle(worlds);same(worlds,"All complete again")
	delta(worlds,[],[2]);same(worlds,"Removal")
	delta(worlds,[scenery(2,5)])
	check(same(worlds,"Removed ID reused").statics.size()==1,"Reused ID cannot inherit prior completion")
	settle(worlds);same(worlds,"Reused ID installed")
	for world in worlds:world.remove_instance(2)
	check(same(worlds,"Explicit visual retirement").statics.size()==1,"Visual removal invalidates empty-plan proof")
	settle(worlds);same(worlds,"Retired visual rebuilt")
	delta(worlds,[creature(5)],[],5)
	check(same(worlds,"Possession/control change").actors.size()==1,"New controlled entity gets exclusive priority")
	settle(worlds);same(worlds,"Possessed entity ready")
	for world in worlds:world.generation+=1
	same(worlds,"Generation stamp change")
	check(candidate._quiet_generation==candidate.generation,"New generation cannot reuse old stamp")
	for world in worlds:world.area_id=92
	same(worlds,"Area scope stamp change")
	check(candidate._quiet_area==92,"Area scope cannot inherit old stamp")
	for world in worlds:world.stats.errors.append({"message":"Authored scope error"})
	same(worlds,"Fatal scope gate")
	check(not candidate._planning_quiet,"Fatal error cannot establish settled proof")
	for world in worlds:world.stats.errors.clear();world.area_id=91
	receive(worlds,[creature(),scenery(9)],1)
	check(same(worlds,"Full reconnect-like replacement").statics.size()==1,"Full snapshot invalidates same-sized old world")
	settle(worlds);same(worlds,"Full replacement settled")
	for world in worlds:world.retiring=true
	same(worlds,"Retirement gate")
	check(not candidate._planning_quiet,"Retiring world never hits settled fast path")
	observations.lifecycle=candidate.planning_cache_counts.duplicate(true)
	dispose(worlds)
func transient_gates() -> void:
	var worlds:=pair();var candidate=worlds[1]
	receive(worlds,[creature(),scenery(2)]);settle(worlds)
	for world in worlds:world.remove_instance(2);world.maximum_static_batch=0
	same(worlds,"No owner capacity")
	check(not candidate._planning_quiet,"Empty plan from configured batch limit is not completion")
	for world in worlds:world.maximum_static_batch=128
	check(same(worlds,"Capacity returns").statics.size()==1,"Capacity restoration schedules pending entity")
	settle(worlds);same(worlds,"Settled after capacity restoration")
	candidate.instance_state_changed.connect(func(_id: int,_object: Dictionary):
		candidate.invalidate_planning())
	var prior_calls: int=candidate.planning_cache_counts.base_calls
	delta(worlds,[creature()]);same(worlds,"Reentrant publication invalidation")
	check(candidate.planning_cache_counts.base_calls==prior_calls+1,"Reentrant receiver invalidation prevents restoration of an old settled proof")
	dispose(worlds)
func dense_idle() -> void:
	var worlds:=pair();var objects: Array=[creature()]
	for id in range(2,2002):objects.append(scenery(id))
	receive(worlds,objects);settle(worlds);same(worlds,"Dense settled proof")
	var candidate=worlds[1];var rows: int=candidate.planning_cache_counts.verification_rows
	var scans: int=candidate.planning_cache_counts.base_calls
	for frame in 60:same(worlds,"Dense unchanged frame "+str(frame))
	check(candidate.planning_cache_counts.base_calls==scans and candidate.planning_cache_counts.verification_rows==rows,"Dense idle frames perform neither legacy nor verification world scans")
	var moved:=scenery(100);moved.staticState.position=[17,3,0]
	delta(worlds,[moved]);same(worlds,"Dense motion-only update")
	check(candidate.planning_cache_counts.base_calls==scans,"Dense motion update retains settled proof")
	delta(worlds,[scenery(100,1)])
	check(same(worlds,"Dense equal-count dirty appearance").statics.size()==1,"Dense key change immediately schedules replacement")
	observations.dense=candidate.planning_cache_counts.duplicate(true)
	dispose(worlds)
func run() -> void:
	lifecycle();transient_gates();dense_idle()
	await process_frame;await process_frame
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"observations":observations,"scope":"Actual original/candidate World receivers and pending_plan over authored state. Controlled readiness/visual adoption/combat are explicit test doubles. No rendering, server, native build, CPU performance or FPS acceptance."}
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="):
			var file:=FileAccess.open(argument.trim_prefix("--report="),FileAccess.WRITE)
			if file!=null:file.store_string(JSON.stringify(result,"  ")+"\n")
	print(JSON.stringify(result));quit(0 if failures.is_empty() else 1)
