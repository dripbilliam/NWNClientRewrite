extends SceneTree
const Original=preload("res://tests/perf140_original_live_world.gd")
const Candidate=preload("res://systems/native_render/live_world.gd")
class Before extends Original:
	func ready_for_control() -> bool:return true
	func ready_for_admission() -> bool:return true
class After extends Candidate:
	func ready_for_control() -> bool:return true
	func ready_for_admission() -> bool:return true
class Combat extends RefCounted:
	func forget(_id: int,_removed: bool=false) -> void:pass
var checks:=0
var failures: Array=[]
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label)
func fixture(type) -> Node3D:
	var world=type.new();world.controlled_id=1
	var controlled:=Node3D.new();world.add_child(controlled);world.instances[1]=controlled
	for id in 2048:
		world.desired[id]={"key":"key-"+str(id),"object":{"id":id,"objectType":9,"staticState":{"position":[id%17,id/17,0]}}}
		world.installed[id]="key-"+str(id)
	return world
func release(world: Node3D) -> void:
	world.instances.clear();world.desired.clear();world.installed.clear();world.free()
func run() -> void:
	var before=fixture(Before);var after=fixture(After)
	check(before.pending_plan({})==after.pending_plan({}),"Settled plan equals original")
	check(after.admission_settled and after.stats.admission_full_scans==1,"One complete scan establishes idle state")
	for frame in 100:check(before.pending_plan({})==after.pending_plan({}),"Unchanged frame retains exact empty plan")
	check(after.stats.admission_full_scans==1,"Unchanged frames do not scan 2048 objects again")
	# Reset through the same boundaries used by authoritative full/delta receives
	# and removal. No visual row cache or duplicate entity store is introduced.
	after.remove_instance(9999)
	check(not after.admission_settled,"Removal invalidates idle even for a never-loaded object")
	check(before.pending_plan({})==after.pending_plan({}) and after.admission_settled,"A new complete scan can settle again")
	for kind in ["new","changed","failed","inflight","missing-pose"]:
		before.desired[2050]={"key":"new","object":{"id":2050,"objectType":9,"staticState":{"position":[0,0,0]}}}
		after.desired[2050]=before.desired[2050].duplicate(true);after.admission_settled=false
		var inflight: Dictionary={}
		if kind=="changed":before.installed[2050]="old";after.installed[2050]="old"
		if kind=="failed":before.failed_objects[2050]={"key":"new"};after.failed_objects[2050]={"key":"new"}
		if kind=="inflight":inflight[2050]=true
		if kind=="missing-pose":before.desired[2050].object.staticState={};after.desired[2050].object.staticState={}
		check(before.pending_plan(inflight)==after.pending_plan(inflight),"Exact pending policy: "+kind)
		check(after.admission_settled==(kind=="failed"),"Only installed or failed exact keys settle: "+kind)
		before.failed_objects.clear();after.failed_objects.clear();before.installed.erase(2050);after.installed.erase(2050)
	after.combat=Combat.new();after.instances.clear()
	after.admission_settled=true;after.receive([],1)
	check(not after.admission_settled and after.desired.is_empty(),"Authoritative full receive invalidates idle and applies removals")
	after.admission_settled=true;after.receive_delta([],[],1)
	check(not after.admission_settled,"Authoritative delta receive invalidates idle even with no visual rows")
	after.admission_settled=true;after.closed=true;after.receive([],1)
	check(after.admission_settled,"Closed owner does not accept receive mutations")
	var next=After.new();check(not next.admission_settled,"New transition/reconnect owner starts unscanned");next.free()
	release(before);release(after)
	await process_frame
	var proof:={"success":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Original admission-plan oracle and settled-query scan contract; offline replay and original local-server acceptance pending"}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):
			var file:=FileAccess.open(arg.trim_prefix("--report="),FileAccess.WRITE);file.store_string(JSON.stringify(proof))
	print(JSON.stringify(proof));quit(0 if proof.success else 1)
func _initialize() -> void:call_deferred("run")
