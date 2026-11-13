extends SceneTree
const Counters=preload("res://systems/native_render/presentation_counters.gd")
var checks:=0
var failures: Array=[]
class Owner:
	extends RefCounted
	var area_id:=41
	var generation:=7
	var controlled_id:=55
	var stats:={"errors":[]}
	var surface
	var terrain
	var pool={"stats":{"meshes_created":101,"textures_created":102}}
	var instances: Dictionary={}
	var desired: Dictionary={}
	var batches: Array=[]
	var failed_objects: Dictionary={}
	var admitted:=false
	var controlled:=false
	func ready_for_admission() -> bool:return admitted
	func ready_for_control() -> bool:return controlled
class Terrain:
	extends Node
	var definition:={"tiles":[1,2,3]}
	var completed_tiles:=2
	func snapshot() -> Dictionary:push_error("HUD must not request detailed terrain diagnostics");return {}
class Surface:
	extends Node
	var stats:={"errors":["surface error"]}
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label)
func _initialize() -> void:
	var owner:=Owner.new()
	var empty:=Counters.capture(owner)
	check(empty.terrain.is_empty(),"Terrain may be absent before area admission")
	check(not empty.ready and not empty.admission_ready,"Readiness is owner supplied")
	owner.terrain=Terrain.new();owner.surface=Surface.new()
	owner.instances={55:{"arbitrary":"not visited"}}
	owner.desired={55:{},56:{}};owner.batches=[1,2]
	owner.failed_objects={56:{"why":["missing model"]}}
	owner.stats.errors=[{"why":["world error"]}]
	owner.admitted=true
	var first:=Counters.capture(owner)
	check(first.area_id==41 and first.generation==7 and first.controlled_id==55,"Scope and controlled identity")
	check(first.entities==1 and first.desired==2 and first.pending_batches==2,"Counts without entity traversal")
	check(first.terrain=={"tiles":3,"rendered_tiles":2},"Terrain progress without detailed snapshot")
	check(first.pool=={"meshes_created":101,"textures_created":102},"Only HUD resource counters")
	check(not first.ready and first.admission_ready,"Terrain admission and player readiness remain distinct")
	check(first.errors==[{"why":["world error"]},"surface error"],"All loading errors remain visible")
	first.errors[0].why.append("consumer")
	first.failed_objects[56].why.append("consumer")
	first.pool.meshes_created=0;first.terrain.rendered_tiles=0
	check(owner.stats.errors[0].why==["world error"],"World error isolation")
	check(owner.failed_objects[56].why==["missing model"],"Failure isolation")
	check(owner.pool.stats.meshes_created==101 and owner.terrain.completed_tiles==2,"Counter isolation")
	owner.controlled=true;owner.generation=8;owner.area_id=42;owner.controlled_id=56
	owner.instances[56]={};owner.batches.clear();owner.terrain.completed_tiles=3
	var second:=Counters.capture(owner)
	check(second.ready and second.generation==8 and second.area_id==42 and second.controlled_id==56,"Fresh control and transition state")
	check(second.entities==2 and second.pending_batches==0 and second.terrain.rendered_tiles==3,"Fresh progress")
	check(first.entities==1 and first.generation==7,"Earlier views remain detached")
	owner.terrain.free();owner.surface.free()
	var freed:=Counters.capture(owner)
	check(freed.terrain.is_empty() and freed.errors==owner.stats.errors,"Freed area owners are tolerated")
	var proof={"success":failures.is_empty(),"checks":checks,"failures":failures,"scope":"HUD counters only; detailed observation payload remains unchanged and requires integration validation"}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):
			var file:=FileAccess.open(arg.trim_prefix("--report="),FileAccess.WRITE);file.store_string(JSON.stringify(proof));file.close()
	print(JSON.stringify(proof));quit(0 if failures.is_empty() else 1)
