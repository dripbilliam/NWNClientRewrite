extends SceneTree
const World=preload("res://systems/native_render/live_world.gd")
const References=preload("res://systems/native_render/reference_assets.gd")
class TestWorld:
	extends World
	var terrain_ready:=false
	func ready_for_admission() -> bool: return terrain_ready and not closed
class Body:
	extends Node3D
	func retire() -> void: queue_free()
class Reference:
	extends Node3D
	var generation:=0
	var retired:=false
var checks:=0
var failures: Array=[]
func check(ok: bool,reason: String) -> void:
	checks+=1
	if not ok: failures.append(reason); print("FAIL: ",reason)
func object(id: int,kind: int,x: float) -> Dictionary:
	return {"id":id,"objectType":kind,"areaId":1,"replicated":{"position":[x,0,0]}}
func request(node: Node) -> Dictionary: return {"node":weakref(node),"generation":0,"resource":"authored"}
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("report") or FileAccess.file_exists(args.report): quit(2); return
	var world:=TestWorld.new(); root.add_child(world); world.set_process(false); world.area_id=1; world.controlled_id=1; world.maximum_actor_batch=3; world.maximum_static_batch=4
	var player:=Body.new(); world.add_child(player)
	var scenery:=Body.new(); world.add_child(scenery)
	var hub:=References.new(); world.add_child(hub); hub.set_process(false); world.references=hub
	var player_ref:=Reference.new(); player.add_child(player_ref)
	var scenery_ref:=Reference.new(); scenery.add_child(scenery_ref)
	var nested:=Node3D.new(); player_ref.add_child(nested); var nested_ref:=Reference.new(); nested.add_child(nested_ref)
	var objects: Array=[object(1,5,0)]
	for id in range(2,12): objects.append(object(id,5,float(id)))
	for id in range(12,32): objects.append(object(id,9,float(40-id)))
	objects.reverse() # Source order deliberately opposes player/distance priority.
	for row in objects: world.desired[int(row.id)]={"object":row,"key":"original-"+str(row.id)}
	var plan: Dictionary=world.pending_plan({})
	check(plan.actors.size()==1 and plan.actors[0].id==1 and plan.statics.is_empty(),"Only controlled actor queues before terrain/player readiness, regardless of source order")
	check(world.pending_plan({1:true}).actors.is_empty(),"In-flight controlled actor is not duplicated; background waits")
	world.installed[1]="original-1"; world.instances[1]=player
	check(not world.ready_for_control() and world.pending_plan({}).actors.is_empty(),"Actor alone cannot bypass terrain/walkmesh admission")
	world.terrain_ready=true
	hub.requests.authored=[request(scenery_ref)]; hub.waiting.authored=true
	check(not hub.ready() and hub.ready_for(player) and world.ready_for_control(),"Unrelated scenery reference does not block player input")
	plan=world.pending_plan({})
	check(plan.actors.map(func(row):return row.id)==[2,3,4],"Nearby actors stream first in a bounded batch")
	check(plan.statics.map(func(row):return row.id)==[31,30,29,28],"Nearby static objects stream first in a bounded batch")
	plan=world.pending_plan({2:true,31:true})
	check(plan.actors.map(func(row):return row.id)==[3,4,5] and plan.statics.map(func(row):return row.id)==[30,29,28,27],"Exact in-flight object keys excluded without losing remaining objects")
	var owner:=Node.new(); world.add_child(owner); owner.set_process(false)
	world.batches=[{"owner":owner}]
	plan=world.pending_plan({})
	check(plan.actors.size()==3 and plan.statics.is_empty(),"Two background-owner bound reserves a priority slot")
	world.batches.append({"owner":owner})
	check(world.pending_plan({}).actors.is_empty() and world.pending_plan({}).statics.is_empty(),"Background work respects the owner bound")
	world.desired[1].key="changed-equipment"
	check(world.pending_plan({}).actors.size()==1 and world.pending_plan({}).actors[0].id==1,"Changed controlled equipment retains priority over in-flight background work")
	world.desired[1].key="original-1"; world.batches.clear()
	hub.requests.authored.append(request(player_ref))
	check(not hub.ready_for(player) and not world.ready_for_control() and world.pending_plan({}).statics.is_empty(),"Player's own pending references gate control and background publication")
	hub.requests.authored=[request(scenery_ref)]; hub.publication=[{"request":request(nested_ref),"bundle":{}}]
	check(not hub.ready_for(player),"Nested player reference pending publication also gates control")
	hub.publication=[{"request":request(scenery_ref),"bundle":{}}]
	check(hub.ready_for(player) and world.ready_for_control(),"Only unrelated publication work remains; player can move")
	hub.publication=[{"request":request(player_ref),"bundle":{}}]; player_ref.retired=true
	check(hub.ready_for(player),"Retired requests do not indefinitely hold player readiness")
	player_ref.retired=false; hub.publication=[]; hub.requests.clear(); hub.waiting.clear()
	var admitted: Array=[]
	for turn in 20:
		plan=world.pending_plan({})
		for row in plan.actors+plan.statics:
			check(not admitted.has(row.id),"Object admitted once across bounded batches: "+str(row.id))
			admitted.append(row.id); world.installed[int(row.id)]=world.desired[int(row.id)].key
		if plan.actors.is_empty() and plan.statics.is_empty(): break
	check(admitted.size()==objects.size()-1,"Every background object eventually streams; no distance culling or scenery omission")
	world.stats.errors.append({"reason":"authored fatal scope error"}); world.installed.erase(2)
	check(world.pending_plan({}).actors.is_empty(),"Fatal scope errors do not become infinite preparation retries")
	world.instances.clear(); world.references=null; world.batches.clear(); world.close(); world.queue_free(); await process_frame; await process_frame
	var file:=FileAccess.open(args.report,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"background_objects":admitted.size(),"network_connections":0,"scope":"Actual native streaming planner and reference-owner readiness with authored delayed work; no GPU/FPS or real server loading acceptance"},"\t")); file.close(); print("NATIVE_STREAMING_PRIORITY ",checks," checks, ",failures.size()," failures"); quit(0 if failures.is_empty() else 1)
