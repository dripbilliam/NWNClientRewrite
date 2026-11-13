extends SceneTree
const World=preload("res://systems/native_render/live_world_quiescent_candidate.gd")
const Lifetime=preload("res://systems/native_data/entity_presentation_lifetime.gd")
class CombatPort extends Node:
	var forgotten: Array=[]
	func forget(id: int,removed: bool=false) -> void:forgotten.append([id,removed])
var checks:=0
var failures: Array=[]
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);print("FAIL ",label)
func row(lifetime: int,disclosure: int=1) -> Dictionary:
	return {"id":7,"objectType":5,"areaId":42,"nativeLifetime":lifetime,"disclosureLifetime":disclosure,"appearance":{"appearance":1},"replicated":{"position":[1,2,3],"animation":0}}
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var world:=World.new();root.add_child(world);world.set_process(false);world.area_id=42;world.generation=3
	var combat:=CombatPort.new();world.add_child(combat);world.combat=combat
	var original:=row(1);world.receive([original],7)
	var key: String=world.desired[7].key
	world.motion.objects[7].position=Vector3(9,8,7)
	world.failed_objects[7]={"key":key,"error":{"reason":"prior job"}}
	world.receive([row(1)],7)
	check(world.desired[7].key==key,"Full repeat keeps job identity")
	check(world.motion.objects[7].position==Vector3(9,8,7),"Full repeat preserves live path/presentation")
	check(world.failed_objects.has(7),"Unchanged failed job does not retry every snapshot")
	world.receive_delta([row(1)],[],7)
	check(world.desired[7].key==key and world.failed_objects.has(7),"Delta repeat also preserves identity")
	world.receive_delta([row(2)],[],7)
	check(world.desired[7].key!=key,"Reused ID with same appearance fences pending old job")
	check(not world.failed_objects.has(7),"Reused ID does not inherit failure")
	check(world.motion.objects[7].position==Vector3(1,2,3),"New lifetime bootstraps received position, not old path")
	check(combat.forgotten.has([7,true]),"New lifetime retires old combat state")
	check(world.stats.lifetime_replacements==1,"One lifetime retirement boundary")
	key=world.desired[7].key;world.receive([row(2,2)],7)
	check(world.desired[7].key!=key and world.stats.lifetime_replacements==2,"Full disclosure reentry fences same-ID same-appearance work")
	world.receive_delta([], [7],7)
	check(not world.desired.has(7) and not world.motion.objects.has(7),"Removal clears authoritative presentation membership")
	world.receive_delta([row(3)],[],7)
	check(world.desired.has(7) and world.motion.objects.has(7),"Removed entity can be admitted again")
	world.area_id=43;world.receive([row(3)],7)
	check(world.desired.is_empty() and world.motion.objects.is_empty(),"Old-area data cannot survive transition")
	check(not Lifetime.changed(row(2),row(2)),"Unchanged scope stable")
	check(Lifetime.changed({},row(1)),"First explicit lifetime cannot inherit unscoped presentation")
	check(not Lifetime.changed(row(1),{}),"Absent information is not invented as lifetime zero")
	var detached:=Lifetime.token(original);detached[0][2]=999
	check(original.nativeLifetime==1,"Token cannot mutate received data")
	var fresh:=World.new();check(fresh.signature(row(1))==world.signature(row(1)),"No synthetic session-global counter added to model data");fresh.free()
	world.combat=null;world.free()
	print("NATIVE_ENTITY_PRESENTATION_LIFETIME ",checks," checks ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
