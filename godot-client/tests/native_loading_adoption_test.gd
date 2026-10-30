extends SceneTree
const World=preload("res://systems/native_render/live_world.gd")
class Body:
	extends Node3D
	func retire() -> void: queue_free()
class Owner:
	extends Node
	var instances: Dictionary={}
	var invisible_ids: Array=[]
	var done:=true
	var closed:=false
	var stats:={"errors":[],"scope_errors":[]}
	func detach_prepared_data() -> Dictionary: return {"payload":[1,2,3]}
	func close() -> void: closed=true
var checks:=0
var failures: Array=[]
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures.append(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	var world:=World.new(); root.add_child(world); world.set_process(false); world.maximum_adoptions_per_frame=2; world.adoption_budget_ms=1000
	var owner:=Owner.new(); world.add_child(owner); var keys: Dictionary={}; var admitted: Array=[]
	world.instance_ready.connect(func(id,_source,_body):admitted.append(id))
	for id in 30:
		var body:=Body.new(); world.add_child(body); body.hide(); owner.instances[id]=body; keys[id]="key-"+str(id)
		world.desired[id]={"key":keys[id],"object":{"id":id,"objectType":9,"replicated":{"position":[id,0,0]}}}
	world.batches.append({"owner":owner,"actors":false,"keys":keys})
	world._profile_process(0)
	check(admitted.size()==2 and owner.instances.size()==28,"Completed batch publishes only the per-frame quota")
	check(not owner.closed and world.batches.size()==1,"Completed owner remains alive until every prepared entity is adopted")
	for turn in 14: world._profile_process(0)
	check(admitted.size()==30 and world.installed.size()==30 and world.instances.size()==30,"Every prepared entity eventually publishes")
	check(owner.closed and world.batches.is_empty(),"Owner closes only after final publication")
	var unique: Dictionary={}
	for id in admitted: unique[id]=true
	check(unique.size()==30 and world.instances.values().all(func(body):return body.visible),"All entities publish exactly once and remain visible")
	world.close(); check(world.data_retirement.snapshot().pending==0,"Detached CPU data drains on shutdown")
	world.free(); await process_frame; await process_frame
	var file:=FileAccess.open(args.report,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"network":false,"scope":"Actual live-world quota, completed-owner lifetime and exactly-once publication using authored prepared entities"},"  ")+"\n"); quit(0 if failures.is_empty() else 1)
