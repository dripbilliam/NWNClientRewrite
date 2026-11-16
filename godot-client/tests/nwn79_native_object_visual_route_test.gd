extends SceneTree
const DirectWorld=preload("res://native_direct_session_world.gd")
const WorldState=preload("res://systems/native_data/native_network_world.gd")
const INVALID=0x7f000000

class FakeSession extends Node:
	var world_state: RefCounted

class FakeEffects extends Node:
	var last_serial:=-1
	var deliveries: Array[Dictionary]=[]
	func receive_raw(message: Dictionary)->void:
		last_serial=int(message.serial)
		deliveries.append(message.duplicate(true))

class FakeWorld extends Node:
	var area_id:=0
	var desired: Dictionary={}
	var effects: Node

func _initialize()->void:
	var direct=DirectWorld.new()
	var session:=FakeSession.new();session.world_state=WorldState.new()
	direct.direct_session=session
	var area:=0x80000041;var target:=0x80000402;var source:=0x80000403
	session.world_state.area_id=area
	session.world_state.registry[target]={"id":target,"objectType":5,"nativeLifetime":7}
	session.world_state.registry[source]={"id":source,"objectType":5,"nativeLifetime":12}
	var visual: Dictionary={"kind":"object-visual","visualId":66,"targetId":target,"sourceId":source,"position":[1.0,2.0,3.0],"nativeAreaId":area,"nativeTargetIdentity":7,"nativeSourceIdentity":12}
	direct.direct_object_visual(visual)
	if direct.direct_visual_queue.size()!=1:fail("Visual was not retained before renderer area opened");return
	var world:=FakeWorld.new();world.area_id=area;world.effects=FakeEffects.new();direct.world=world
	direct.direct_drain_visuals()
	if direct.direct_visual_queue.size()!=1 or world.effects.deliveries.size()!=0:fail("Visual was consumed before canonical target reached render snapshot");return
	world.desired[target]={"object":{"nativeLifetime":7}}
	world.desired[source]={"object":{"nativeLifetime":12}}
	direct.direct_drain_visuals()
	if direct.direct_visual_queue.size()!=0 or world.effects.deliveries.size()!=1:fail("Visible target did not receive retained visual exactly once");return
	var event: Dictionary=world.effects.deliveries[0].events[0]
	if int(event.id)!=target or int(event.lifetime)!=7 or int(event.sourceLifetime)!=12 or int(event.message.visualId)!=66:fail("Visual identity/lifetime was not handed to effect owner");return
	visual.nativeTargetIdentity=8
	direct.direct_object_visual(visual)
	if world.effects.deliveries.size()!=1:fail("Replaced target received stale visual");return
	visual.nativeTargetIdentity=7;visual.nativeSourceIdentity=13
	direct.direct_object_visual(visual)
	if world.effects.deliveries.size()!=1:fail("Replaced source received stale visual");return
	visual.nativeSourceIdentity=12;visual.nativeAreaId=area+1
	direct.direct_object_visual(visual)
	if world.effects.deliveries.size()!=1:fail("Other-area visual crossed area boundary");return
	visual.nativeAreaId=area;visual.targetId=INVALID;visual.nativeTargetIdentity=null
	direct.direct_object_visual(visual)
	if world.effects.deliveries.size()!=2 or int(world.effects.deliveries[-1].events[0].id)!=INVALID:fail("Original point visual was not handed to dummy route");return
	direct.direct_session=null;direct.world=null
	world.effects.free();world.free();session.free();direct.free()
	print("NWN79 Godot object visual route PASS: delayed target, exact lifetime, replacement/area restraint, point dummy")
	quit(0)

func fail(reason: String)->void:
	printerr("NWN79 Godot object visual route failed: "+reason)
	quit(1)
