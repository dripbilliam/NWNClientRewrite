extends SceneTree
const World=preload("res://systems/native_render/live_world.gd")
class EntryWorld:
	extends World
	var terrain_admitted:=true
	func ready_for_admission() -> bool: return terrain_admitted
	func ready_for_control() -> bool: return false
var checks:=0
var failures: Array=[]
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label); print("FAIL: ",label)
func object(id: int,kind: int,x: float) -> Dictionary:
	return {"id":id,"objectType":kind,"areaId":1,"replicated":{"position":[x,0,0]}}
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var report:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): report=arg.substr(9)
	if report.is_empty() or FileAccess.file_exists(report): quit(2); return
	var world:=EntryWorld.new(); root.add_child(world); world.set_process(false); world.controlled_id=1; world.area_id=1; world.entry_prefetch_enabled=true
	world.desired[1]={"key":"player","object":object(1,5,0)}
	for index in 12: world.desired[index+10]={"key":"static-"+str(index),"object":object(index+10,9,12-index)}
	world.desired[100]={"key":"far","object":object(100,10,50)}
	world.desired[200]={"key":"remote","object":object(200,5,0.1)}
	var plan:=world.pending_plan({})
	check(plan.actors.size()==1 and plan.actors[0].id==1 and plan.statics.is_empty(),"First request remains exclusively the controlled actor")
	plan=world.pending_plan({1:true})
	check(plan.actors.is_empty() and plan.statics.size()==8,"Only one bounded eight-scenery wave overlaps the controlled job")
	check(plan.statics.map(func(row):return row.id)==[21,20,19,18,17,16,15,14],"Nearest placements win independently of received order")
	check(not plan.statics.any(func(row):return row.id==100 or row.id==200),"Far scenery and remote actors cannot consume the initial window")
	world.entry_prefetch_enabled=false
	check(world.pending_plan({1:true}).statics.is_empty(),"Disabled reference retains the original exclusive preparation window")
	world.entry_prefetch_enabled=true; world.terrain_admitted=false
	check(world.pending_plan({1:true}).statics.is_empty(),"Prefetch cannot compete with required terrain admission")
	world.terrain_admitted=true; world.batches=[{},{}]
	check(world.pending_plan({1:true}).statics.is_empty(),"Existing owner cap prevents extra background owners")
	world.batches=[]; world.installed[21]="static-11"; world.failed_objects[20]={"key":"static-10","error":{}}
	plan=world.pending_plan({1:true,19:true})
	check(not plan.statics.any(func(row):return row.id in [21,20,19]),"Installed, failed and in-flight appearances are not duplicated")
	world.stats.entry_prefetch_batches=1
	check(world.pending_plan({1:true}).statics.is_empty(),"A fast completed scenery wave cannot start more initial batches while the player is still preparing")
	world.batches=[]; world.close(); world.queue_free(); await process_frame; await process_frame
	var file:=FileAccess.open(report,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"publicConnections":0,"scope":"Entry scheduling and ownership limits only; actual contention, readiness/pop-in and rendering require full frozen/local runs"})); file.close()
	quit(0 if failures.is_empty() else 1)
