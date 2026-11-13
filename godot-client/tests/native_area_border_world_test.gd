extends SceneTree
const World=preload("res://systems/native_render/live_world.gd")
const SessionRoot=preload("res://native_session_world.gd")
class ControlledWorld extends "res://systems/native_render/live_world.gd":
	func _enter_tree()->void:pass # Isolate new hooks from unrelated rendering.
class Terrain extends Node:
	var done:=false
	var diagnostics: Dictionary={"errors":[]}
	var definition_task:=-1
	var assets=null
	var instances: Dictionary={}
	var definition: Dictionary={"width":1,"height":1,"tiles":[{"tile_id":0,"orientation":0,"height":0}],"tileset_name":"ttr01","tileset":{"transition":1.0,"tiles":[{}]}}
	func set_priority_origin(_value: Vector3)->void:pass
	func detach_prepared_data()->Dictionary:return {}
	func close()->void:pass
class Surface extends Node:
	var available:=false
	var assets=null
	func ready()->bool:return available
	func set_priority_origin(_value: Vector3)->void:pass
	func detach_prepared_data()->Dictionary:return {}
	func close()->void:pass
class Actor extends Node3D:
	func retire()->void:queue_free()
class MissingCatalog extends RefCounted:
	var failure:=""
	var forks:=0
	var reads:=0
	func fork():forks+=1;return self
	func has_resource(_name: String,_type: int)->bool:reads+=1;return false
class Disposal extends Node:
	var payloads: Array=[]
	func retire(value: Dictionary)->void:payloads.append(value)
	func defer_release(value: Dictionary)->void:payloads.append(value)
class BudgetProbe extends Node:
	var assets=null
	var budgets: Array=[]
	var retired:=false
	func worker_tasks()->Array:return []
	func begin_retirement()->void:retired=true
	func retirement_step(ms: float)->bool:budgets.append(ms);return true
	func detach_prepared_data()->Dictionary:return {}
	func close()->void:pass
var checks:=0
var failures: Array=[]
func check(value: bool,label: String)->void:
	checks+=1
	if not value:failures.append(label)
func _initialize()->void:run.call_deferred()
func until(condition: Callable)->bool:
	var deadline:=Time.get_ticks_msec()+15000
	while not condition.call() and Time.get_ticks_msec()<deadline:await process_frame
	return condition.call()
func fixture(enabled: bool,disabled: Variant)->ControlledWorld:
	var world:=ControlledWorld.new();root.add_child(world);world.set_process(false);world.generation=2;world.area_id=7;world.controlled_id=42
	world.tile_borders_enabled=enabled;world.border_disabled=disabled;world.catalog=MissingCatalog.new()
	world.terrain=Terrain.new();world.add_child(world.terrain);world.surface=Surface.new();world.add_child(world.surface)
	world.data_retirement=Disposal.new();world.add_child(world.data_retirement)
	return world
func admit(world)->void:
	world.terrain.done=true;world.surface.available=true
	var actor:=Actor.new();world.add_child(actor);world.instances[42]=actor
func run()->void:
	var output:=""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="):output=argument.trim_prefix("--report=")
	if output.is_empty() or FileAccess.file_exists(output):quit(2);return
	check(SessionRoot!=null,"Final current actual NativeSessionWorld/World source graph compiles without a session")
	for value in [0,1,0.0,1.0,false,true]:
		var wire: Dictionary=JSON.parse_string(JSON.stringify({"fields":{"10c":value}}))
		check(World.border_disabled_from_network(wire)==(float(value)==1.0),"Actual JSON numeric/bool10c retains strict original disabled bit")
	for value in [null,2,-1,0.5,"0","1",{},[]]:check(World.border_disabled_from_network({"fields":{"10c":value}})==null,"Absent/malformed original10c never becomes enabled by default")
	check(World.border_disabled_from_network({})==null and World.border_disabled_from_network({"fields":null})==null,"Missing field container remains explicit unavailable")
	for gate in [[false,false],[true,true],[true,null]]:
		var suppressed:=fixture(gate[0],gate[1]);admit(suppressed);suppressed.start_area_border()
		check(suppressed.borders_started and suppressed.borders==null and suppressed.catalog.forks==0 and suppressed.catalog.reads==0,"Disabled/unknown caller gate constructs no border or resource work")
		suppressed.close();suppressed.free()
	var world:=fixture(true,World.border_disabled_from_network(JSON.parse_string('{"fields":{"10c":0.0}}')))
	world.start_area_border();check(not world.borders_started and world.borders==null,"No optional work starts before original base terrain/surface admission")
	world.terrain.done=true;world.surface.available=true
	check(world.ready_for_admission() and not world.ready_for_control(),"Base area admission remains independent from controlled-player readiness")
	world.start_area_border();check(not world.borders_started,"Optional border cannot delay initial4/3 base-area acknowledgment")
	var actor:=Actor.new();world.add_child(actor);world.instances[42]=actor;world.set_priority_origin(Vector3(3,0,-4))
	check(world.ready_for_control(),"Original controlled player/base area gate is ready without any border")
	var definition_before: Dictionary=world.terrain.definition.duplicate(true)
	world.start_area_border();var borders=world.borders
	check(is_instance_valid(borders) and borders.scope==[world.get_instance_id(),world.generation,world.area_id] and borders.has_priority_origin,"Actual World starts private owner once with exact opaque World scope/player priority")
	check(not borders.done,"Priority-before-open cannot mark actual World border complete while planning is pending")
	check(not borders.assets.is_processing(),"Actual private Assets child stays idle while only the optional plan is running")
	var task: int=borders.loader.task;check(task>=0 and world.worker_tasks().has(task),"Actual World retirement observes the border planning task")
	check(world.asset_owners().has(borders.assets),"Actual World exposes the border's real asset service for cancellation/join")
	check(world.ready_for_control() and world.desired.is_empty() and world.instances.size()==1 and world.static_collision_index.snapshot().entries==0,"Optional background work adds no entity/selection/collision/readiness dependency")
	check(await until(func():return borders.done),"Known-missing optional table settles through actual private planning worker")
	check(world.ready_for_control() and not borders.assets.is_processing() and not borders.is_processing() and not borders.loader.is_processing(),"Settled empty border and both real child owners do no idle frame work")
	check(world.terrain.definition==definition_before and borders.instances.is_empty(),"Border does not mutate original terrain grid or invent filler models")
	world.tile_borders_enabled=false;world.border_disabled=true;world.start_area_border()
	check(world.borders==borders and borders.generation==1,"Original setting/area gate is one-shot at open, no claimed live rebuild")
	world.remove_instance(42);borders.close();borders.queue_free()
	var probe:=BudgetProbe.new();world.add_child(probe);world.borders=probe
	world.begin_retirement();check(probe.retired,"Actual World forwards retirement before canceling shared asset owners")
	check(not world.retirement_step(0.0) and probe.budgets.is_empty(),"Exhausted World budget does not grant a second full border retirement slice")
	check(world.retirement_step(100.0) and probe.budgets.size()==1 and float(probe.budgets[0])>0 and float(probe.budgets[0])<=100.0,"Actual World forwards only its remaining retirement budget")
	world.close();world.free();await process_frame;await process_frame
	var file:=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Actual World optional-start/readiness, JSON10c, resource task exposure/no-idle and retirement hooks with controlled admitted terrain/surface/player; real private optional loader/Assets and full SessionWorld graph compile. No GPU/world entry/server/key or user-process action."})+"\n");file.close();quit(0 if failures.is_empty() else 1)
