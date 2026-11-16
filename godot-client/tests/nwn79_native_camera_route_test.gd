extends SceneTree
const DirectWorld=preload("res://native_direct_session_world.gd")
const LiveWorld=preload("res://native_live_world.gd")
const WorldState=preload("res://systems/native_data/native_network_world.gd")
const CameraState=preload("res://systems/game_camera_state.gd")

class FakeSession extends Node:
	var world_state: RefCounted

class FakeWorld extends Node:
	var area_id:=0
	var controlled_id:=0
	var desired: Dictionary={}
	var instances: Dictionary={}

class FakeController extends Node:
	var follow_state
	var target:=Vector3.ZERO
	var follow_height:=1.0
	var rebinds:=0
	func _init():
		follow_state=CameraState.new()
		follow_state.reset(1)
	func enable_follow(_mode: int,_position: Vector3,_height: float,_remembered: Dictionary,persistent: Variant)->void:
		follow_state=persistent
		rebinds+=1

func _initialize()->void:
	run_case.call_deferred()

func run_case()->void:
	var area:=0x80000041;var controlled:=0x80000401;var target:=0x80000402
	var direct=DirectWorld.new()
	var session:=FakeSession.new();session.world_state=WorldState.new();session.world_state.area_id=area
	var world:=FakeWorld.new();root.add_child(world);world.area_id=area;world.controlled_id=controlled
	var controlled_node:=Node3D.new();controlled_node.position=Vector3(1,2,3)
	var target_node:=Node3D.new();target_node.position=Vector3(4,5,6)
	world.add_child(controlled_node);world.add_child(target_node)
	world.instances[controlled]=controlled_node;world.instances[target]=target_node
	world.desired[controlled]={"object":{"objectType":5}}
	world.desired[target]={"object":{"objectType":9}}
	session.world_state.registry[target]={"id":target,"objectType":9,"areaId":area,"nativeLifetime":7}
	var first_controller:=FakeController.new()
	direct.direct_session=session;direct.world=world;direct.controller=first_controller
	var base=LiveWorld.new();base.world=world
	if base.native_camera_follow_target_id()!=controlled or direct.native_camera_follow_target_id()!=controlled:fail("Default camera target is not the controlled actor");return
	direct.direct_camera_command({"kind":"camera-mode","mode":2})
	if direct.direct_camera_state==null or int(direct.direct_camera_state.state.mode)!=2 or not direct.direct_camera_queue.is_empty():fail("Decoded camera mode did not reach active state");return
	direct.direct_camera_command({"kind":"camera-attach","objectId":target,"findClearView":true})
	if direct.native_camera_follow_target_id()!=target or direct.direct_camera_target_id!=target or int(direct.report.get("direct_camera_clear_view_unavailable",0))!=1 or bool(direct.direct_camera_state.state.findClearView):fail("Current-area placeable attachment or clear-view gate was lost");return
	var retained=direct.direct_camera_state
	var next_controller:=FakeController.new();direct.controller=next_controller
	direct.direct_camera_bind()
	if direct.direct_camera_state!=retained or next_controller.follow_state!=retained or next_controller.rebinds!=1 or int(retained.state.mode)!=2:fail("Travel replaced the persistent camera commands");return
	world.desired.erase(target);world.instances.erase(target)
	direct.direct_camera_bind()
	if direct.native_camera_follow_target_id()!=controlled or direct.direct_camera_target_id!=-1:fail("Removed attachment did not return to controlled actor");return
	world.desired[target]={"object":{"objectType":9}}
	world.instances[target]=target_node
	world.area_id=area+1
	direct.direct_camera_command({"kind":"camera-attach","objectId":target,"findClearView":false})
	if direct.native_camera_follow_target_id()!=controlled or not direct.direct_camera_queue.is_empty():fail("Old-area attachment crossed area transition");return
	base.world=null;direct.direct_session=null;direct.world=null;direct.controller=null
	base.free();direct.free();session.free();world.free();first_controller.free();next_controller.free()
	print("NWN79 Godot camera route PASS: controlled default, mode, current-area attach, travel persistence, detach, stale-area restraint")
	quit(0)

func fail(reason: String)->void:
	printerr("NWN79 Godot camera route failed: "+reason)
	quit(1)
