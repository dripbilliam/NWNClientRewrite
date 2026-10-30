extends SceneTree
const World=preload("res://systems/native_render/live_world.gd")
const Motion=preload("res://systems/network_motion.gd")
class Rig:
	extends RefCounted
	func clip_length(_id: int,_code: int) -> float: return 1.0
class Body:
	extends Node3D
	var rigs:=Rig.new()
	func set_animation(_code: int,_speed: float) -> void: pass
	func retire() -> void: queue_free()
var checks:=0
var failures: Array=[]
func check(ok: bool,reason: String) -> void:
	checks+=1
	if not ok: failures.append(reason); print("FAIL ",reason)
func advance(world,frames: int=120) -> void:
	for frame in frames: world.motion.update(1.0/60.0); world.apply_pose(1)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var output:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
	if output.is_empty() or FileAccess.file_exists(output): quit(2); return
	var world:=World.new(); root.add_child(world); world.set_process(false); world.area_id=42; world.generation=7
	var source:={"id":1,"areaId":42,"objectType":5,"appearance":{"appearance":0},"replicated":{"position":[0.0,0.0,0.0],"orientation":{"vector":[0.0,1.0,0.0]},"animation":0,"walkRate":1000.0,"runRate":1000.0,"facingTarget":2}}
	var target:={"id":2,"areaId":42,"objectType":9,"replicated":{"position":[10.0,0.0,0.0],"orientation":{"vector":[0.0,1.0,0.0]}}}
	world.receive([source,target],1)
	var actor:=Body.new(); world.add_child(actor); world.instances[1]=actor; world.installed[1]=world.signature(source)
	world.motion.adopt([{"id":1,"state":{"modelType":1,"walkDistance":1.0,"runDistance":1.0}}])
	var wire_before:=JSON.stringify(source)
	advance(world)
	check(world.motion.objects[1].orientation.dot(Vector3.RIGHT)>0.99,"Stationary creature follows the server's facing target through actual live-world motion")
	check((-actor.basis.z).dot(Vector3.RIGHT)>0.99,"Actual native actor pivot faces the resolved target rather than only recording metadata")
	check(actor.position==Vector3.ZERO and JSON.stringify(source)==wire_before,"Target facing changes neither authoritative positions nor received orientation data")
	check(not world.instances.has(2),"Target can resolve before its visual model is admitted")
	target=target.duplicate(true); target.replicated.position=[-10.0,0.0,0.0]; world.receive_delta([target],[],1); advance(world)
	check(world.motion.objects[1].orientation.dot(Vector3.LEFT)>0.99,"Moving target positions are re-resolved without a new source orientation packet")
	var unlocked:=source.duplicate(true); unlocked.replicated.facingTarget=0x7f000000; world.receive_delta([unlocked],[],1)
	var facing: Vector3=world.motion.objects[1].orientation; advance(world)
	check(world.motion.objects[1].orientation.is_equal_approx(facing),"A target unlock retains the last derived bearing instead of snapping back to an old wire heading")
	var replacement:={"id":3,"areaId":42,"objectType":9,"replicated":{"position":[0.0,10.0,0.0],"orientation":{"vector":[0.0,1.0,0.0]}}}
	unlocked.replicated.facingTarget=3; world.receive_delta([unlocked,replacement],[],1); advance(world)
	check(world.motion.objects[1].orientation.dot(Vector3(0,1,0))>0.99,"Target-only full-state updates reach native facing even without movement events")
	world.motion.observe(1,{"facingTarget":2},false,source.replicated); advance(world)
	check(world.motion.objects[1].orientation.dot(Vector3.LEFT)>0.99,"An explicit movement delta can update facing target independently")
	world.motion.observe(1,{"animation":4,"path":[[0.0,0.0],[0.0,10.0]],"field8F4":1,"field8EC":1.0},false)
	advance(world,45)
	check(world.motion.objects[1].position.y>0 and world.motion.objects[1].orientation.y>0.99,"An active path preserves locomotion-facing priority over the lock target")
	var state: Dictionary=world.motion.objects[1]
	world.motion.observe(1,{"animation":0,"path":[]},false); advance(world)
	check(state.orientation.dot(Motion.normalized32(Vector3(-10,0,0)-state.position))>0.99,"Stopping the path resumes target-facing through the same turning step")
	world.receive_delta([], [2],1); facing=state.orientation; advance(world)
	check(state.orientation.is_equal_approx(facing) and state.targetOrientation==state.orientation,"Removed target stops further turning without stale position reuse")
	world.desired[2]={"object":{"id":2,"areaId":43,"objectType":5,"replicated":{"position":[100,0,0]}},"key":"other-area"}
	check(world.motion_target_position(2)==null,"A different-area object cannot provide a facing target")
	world.desired.erase(2)
	state.facingTarget=1; advance(world)
	check(state.orientation.is_finite() and state.orientation.is_equal_approx(facing),"Self-target does not create a zero-direction turn")
	state.facingTarget=3; replacement.replicated.position=[state.position.x,state.position.y,10.0]; world.receive_delta([replacement],[],1); facing=state.orientation; advance(world)
	check(state.orientation.is_finite() and state.orientation.is_equal_approx(facing),"Vertically coincident target retains a finite planar bearing")
	world.close(); check(not world.motion.facing_target_query.is_valid(),"Closing a world releases its target resolver binding")
	world.queue_free(); await process_frame; await process_frame
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"game_network_connections":0,"scope":"Native live-world received-state -> target resolution -> original turn step -> actual pivot; target motion/unlock/removal/scope and path priority. Authored fixture, not live attack or mixed-client acceptance."},"  ")); file.close(); quit(0 if failures.is_empty() else 1)
