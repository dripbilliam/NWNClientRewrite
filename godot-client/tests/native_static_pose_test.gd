extends SceneTree
const World=preload("res://systems/native_render/live_world.gd")
class Rigs:
	extends RefCounted
	func clip_length(_id: int,_code: int) -> float: return 1.0
class Body:
	extends Node3D
	var rigs:=Rigs.new()
	func set_animation(_code: int,_speed: float) -> void: pass
	func retire() -> void: queue_free()
class Batch:
	extends Node
	var instances: Dictionary={}
	var invisible_ids: Array=[]
	var done:=false
	var stats:={"errors":[]}
	func close() -> void: pass
var checks:=0
var failures: Array=[]
func check(ok: bool,reason: String) -> void:
	checks+=1
	if not ok: failures.append(reason); print("FAIL: ",reason)
func row(id: int,kind: int,x: float) -> Dictionary:
	return {"id":id,"areaId":42,"objectType":kind,"replicated":{"position":[x,2.0,3.0],"orientation":[1.0,0.0],"animation":0},"appearance":{"appearance":0}}
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("report") or FileAccess.file_exists(args.report): quit(2); return
	var world:=World.new(); root.add_child(world); world.set_process(false); world.area_id=42
	var rows: Array=[row(1,5,1.0)]
	for id in range(2,602): rows.append(row(id,9,float(id)))
	rows.append(row(602,6,10.0)); rows.append(row(603,10,11.0))
	world.receive(rows,1)
	for object in rows:
		var body:=Body.new(); world.add_child(body); world.instances[int(object.id)]=body; world.installed[int(object.id)]=world.signature(object)
	world.apply_poses(true)
	check(world.stats.static_pose_evaluations==602 and world.instances[2].position==Vector3(2,3,-2),"All authored static/item/door poses first apply from server state")
	var evaluations:=int(world.stats.pose_evaluations); var statics:=int(world.stats.static_pose_evaluations)
	for frame in 180:
		world.motion.objects[1].render=Vector3(1+float(frame)/60.0,2,3); world.apply_poses()
	check(int(world.stats.pose_evaluations)-evaluations==180 and int(world.stats.static_pose_evaluations)==statics,"180 frames update only the moving creature, with zero repeated evaluations of 602 static poses")
	check(world.instances[1].position.x>3.9 and world.instances[2].position==Vector3(2,3,-2),"Creature advances while unchanged scenery remains at its original pose")
	rows[1].replicated.position=[8.0,7.0,6.0]; rows[-2].replicated.position=[20.0,4.0,1.0]; rows[-1].replicated.orientation=[0.0,1.0]
	world.receive(rows,1)
	check(world.instances[2].position==Vector3(8,6,-7) and world.instances[602].position==Vector3(20,1,-4) and is_zero_approx(world.instances[603].rotation.y),"Actual subsequent snapshot updates static positions, ground item and door orientation")
	check(world.instances[1].position.x>3.9,"Repeated snapshot does not reset the native moving creature")
	var pending:=row(700,9,12.0); rows.append(pending); world.receive(rows,1)
	var batch:=Batch.new(); world.add_child(batch); var late:=Body.new(); batch.add_child(late); late.position=Vector3(12,3,-2); batch.instances[700]=late
	world.batches.append({"owner":batch,"actors":false,"keys":{700:world.signature(pending)}})
	pending.replicated.position=[70.0,8.0,9.0]; world.receive(rows,1); world._process(0.0)
	check(world.instances.has(700) and world.instances[700].position==Vector3(70,9,-8),"Late static admission uses the newest raw pose rather than its preparation-time pose")
	batch.done=true; world._process(0.0)
	rows=rows.filter(func(object):return int(object.id)!=2); world.receive(rows,1)
	check(not world.instances.has(2) and not world.desired.has(2),"Server deletion removes the unchanged-static optimization entry and instance")
	var tracked: Array=[]
	for instance in world.instances.values(): tracked.append(weakref(instance))
	var metrics:=world.stats.duplicate(true); world.close(); world.queue_free(); await process_frame; await process_frame
	check(tracked.all(func(reference):return reference.get_ref()==null),"Moving/static/late-admitted owners retire without survivors")
	var file:=FileAccess.open(args.report,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"stats":metrics,"static_objects":602,"frames":180,"network_connections":0,"scope":"Actual native world pose processing with authored snapshots/admission/deletion; local authoritative movement and full-world performance need separate evidence"},"\t")); file.close(); print("NATIVE_STATIC_POSE ",checks," checks, ",failures.size()," failures"); quit(0 if failures.is_empty() else 1)
