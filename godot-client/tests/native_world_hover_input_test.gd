extends SceneTree
# Real pointer owner + world/registry boundary adapter. Asset animation is
# independently exercised by native_transition_door_hover_test's original MDLs.
const Pointer=preload("res://systems/world_input.gd")
const Presentation=preload("res://systems/native_render/world_hover_presentation.gd")
class World extends Node3D:
	var closed:=false
	var retiring:=false
	var area_id:=40
	var controlled_id:=7
	var desired: Dictionary={}
	var instances: Dictionary={}
	var installed: Dictionary={}
class Door extends Node3D:
	var retired:=false
	var received_state:=1
	var object_id:=10
	var begins:=0
	var ends:=0
	func begin_transition_hover() -> bool:begins+=1;return true
	func end_transition_hover() -> bool:ends+=1;return true
class Registry extends Node:
	var native_owners: Dictionary={}
	var entities:={10:{"eligible":true}}
	var marked: Array=[]
	var calls:=0
	func pick(_camera: Camera3D,_screen: Vector2) -> Dictionary:return {"id":10,"position":Vector3.ZERO,"entity":entities[10]}
	func eligible_ids() -> Array:return [10]
	func mark(ids: Array,hovered: int,tab: bool) -> void:marked=[ids.duplicate(),hovered,tab];calls+=1
class Hud extends Node:
	var blocked:=false
	var current_id:=-1
	func blocks_pointer(_point: Vector2) -> bool:return blocked
	func labels(_ids: Array,_hover: int) -> void:pass
var checks:=0
var failures: Array=[]
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label);print("FAIL ",label)
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var world:=World.new();root.add_child(world)
	var door:=Door.new();world.add_child(door)
	world.desired={7:{"object":{"id":7,"objectType":5,"areaId":40}},10:{"key":"door-1","object":{"id":10,"objectType":10,"replicated":{"hasTransition":true}}}}
	world.instances[10]=door;world.installed[10]="door-1"
	var registry:=Registry.new();root.add_child(registry);registry.native_owners[10]=door
	var hud:=Hud.new();root.add_child(hud);var camera:=Camera3D.new();root.add_child(camera)
	var presentation:=Presentation.new();world.add_child(presentation);presentation.configure(world,registry)
	var pointer:=Pointer.new();root.add_child(pointer);pointer.configure(registry,camera,hud);pointer.set_physics_process(false);pointer.hover_presentation=presentation.select
	var source: Dictionary=world.desired[10].object.duplicate(true)
	pointer._pointer_step(0.1)
	check(pointer.hovered==10 and door.begins==1 and registry.marked==[[],-1,false],"Native open transition door begins Trans and suppresses only ordinary hover")
	pointer._pointer_step(0.1)
	check(door.begins==1,"Unchanged pointer does not restart auxiliary animation")
	pointer.tab=true;pointer._pointer_step(0.1)
	check(registry.marked==[[10],-1,true],"Tab remains independent while transition-door hover is suppressed")
	hud.blocked=true;pointer._pointer_step(0.1)
	check(door.ends==1 and pointer.hovered==-1,"Actual blocked-menu pointer boundary cleans up transition hover")
	hud.blocked=false;pointer.tab=false;pointer._pointer_step(0.1)
	check(door.begins==2,"Unblocked re-entry starts only one fresh hover run")
	world.desired[10].object.replicated.hasTransition=false;pointer._pointer_step(0.1)
	check(door.ends==2 and registry.marked==[[10],10,false],"Fresh received transition flag restores ordinary hover without changing target ID")
	world.desired[10].object.replicated.hasTransition=true;world.desired.erase(7);pointer._pointer_step(0.1)
	check(door.begins==2,"Unavailable controlled object cannot admit native transition hover")
	world.desired[7]={"object":{"id":7,"objectType":5,"areaId":40}};world.installed[10]="retired-key";pointer._pointer_step(0.1)
	check(door.begins==2,"Unadmitted replacement model cannot receive old selection presentation")
	world.installed[10]="door-1";pointer._pointer_step(0.1);world.retiring=true;pointer._pointer_step(0.1)
	check(door.begins==3 and door.ends==3,"World retirement clears only weak held physical door")
	check(world.desired[10].object==source,"Hover never writes received open/transition state")
	# Real native wire flags are JSON numbers, hence GDScript float values.
	# Array membership is type-strict even though numeric comparison is not.
	world.retiring=false
	world.desired[10].object.replicated=JSON.parse_string('{"hasTransition":1}')
	var starts: int=door.begins;var ends: int=door.ends
	pointer._pointer_step(0.1)
	check(door.begins==starts+1 and registry.marked==[[],-1,false],"Actual JSON1.0 starts transition hover on the same received target")
	pointer._pointer_step(0.1)
	check(door.begins==starts+1,"Repeated JSON flag does not restart Trans")
	world.desired[10].object.replicated=JSON.parse_string('{"hasTransition":0}')
	pointer._pointer_step(0.1)
	check(door.ends==ends+1 and registry.marked==[[10],10,false],"Actual JSON0.0 clears Trans and keeps ordinary selection")
	for invalid in [null,-1.0,2.0,0.5,"1",NAN,INF]:
		world.desired[10].object.replicated.hasTransition=invalid
		var unavailable:=presentation.select({"id":10},false)
		check(unavailable.get("available")==false and unavailable.get("reason")=="received-transition-flag-unavailable","Unavailable or malformed flags never become an invented transition")
	pointer.free();presentation.free();world.free();registry.free();hud.free();camera.free();await process_frame
	print("NATIVE_WORLD_HOVER_INPUT ",checks," checks ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
