extends SceneTree
const Perception=preload("res://systems/native_render/perception_visuals.gd")
class World extends Node3D:
	var generation:=3
	var area_id:=42
	var desired: Dictionary={}
var checks:=0
var failures: Array=[]
var applied: Array=[]
var removed: Array=[]
var next_effect:=100
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);print("FAIL ",label)
func add_visual(id: int,lifetime: int,visual: int) -> int:
	next_effect+=1;applied.append([id,lifetime,visual,next_effect]);return next_effect
func remove_visual(id: int,effect: int) -> void:removed.append([id,effect])
func entity(id: int,life: Variant=1) -> Dictionary:
	return {"id":id,"objectType":5,"nativeLifetime":life,"disclosureLifetime":1,"replicated":{"visibility":[1,0,0]}}
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var world:=World.new();root.add_child(world)
	var observer:=entity(1);observer.playerState={"visibility":{}}
	var target:=entity(7,1.0);world.desired={1:{"object":observer},7:{"object":target}}
	var owner:=Perception.new();owner.configure(world,add_visual,remove_visual)
	owner.receive([target],1)
	check(applied.is_empty(),"Creature triple is not conflated with PlayerInfo packing")
	observer.playerState.visibility["7"]=[1.0,0.0,0.0];owner.receive([observer],1)
	check(applied==[[7,1,6,101]],"Received PlayerInfo can apply active-resource visual6 before model loads")
	owner.receive([observer,target],1)
	check(applied.size()==1,"Repeated full or delta update does not duplicate effect")
	observer.playerState.visibility["7"]=[0,0,0];owner.receive([observer],1)
	check(removed.is_empty(),"All-false triple retains native latch")
	observer.playerState.visibility["7"]=[1,1,0];owner.receive([observer],1)
	check(removed==[[7,101]],"Reveal removes exactly owned effect ID")
	owner.receive([observer],1);check(removed.size()==1,"Repeated reveal is idempotent")
	observer.playerState.visibility["7"]=[0,0,1];owner.receive([observer],1)
	check(applied.size()==2,"Third flag applies visual independently")
	target.nativeLifetime=2;owner.receive([target],1)
	check(removed.back()==[7,102] and applied.back()==[7,2,6,103],"Same-ID new lifetime retires old latch before new effect")
	world.desired.erase(7);owner.receive([],1)
	check(removed.back()==[7,103] and owner.snapshot().entries==0,"Removal retires owner before loaded-instance availability")
	world.desired[7]={"object":entity(7,3)};owner.receive([world.desired[7].object],1)
	check(applied.back()==[7,3,6,104],"Reentry creates a fresh scoped effect")
	owner.receive([],99);check(removed.back()==[7,104],"Observer control change drops previous observer latch")
	var detached:=owner.snapshot();detached.stats.applied=999
	check(owner.snapshot().stats.applied!=999,"Diagnostic snapshot is detached")
	owner.close();world.free()
	print("NATIVE_PERCEPTION_VISUALS ",checks," checks ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
