extends SceneTree
const SkyOwner=preload("res://systems/native_render/sky_world.gd")
class TestWorld extends Node3D:
	var closed:=false
	var retiring:=false
class TestAssets extends RefCounted:
	var next_id:=0
	func retire_scope() -> void: pass
	func close() -> void: pass
	func request(_name: String,_kind: int,_decoder: String) -> int:
		next_id+=1; return next_id
class TestPool extends RefCounted:
	var allowed:=false
	var publications:=0
	func can_publish() -> bool:return allowed
	func publication_finished(_began: int) -> void:publications+=1
var checks:=0
var failures: Array=[]
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures.append(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var output:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
	if output.is_empty() or FileAccess.file_exists(output): quit(2); return
	var world:=TestWorld.new(); root.add_child(world)
	var sky:=SkyOwner.new(); world.add_child(sky); sky.world_owner=weakref(world); sky.assets=TestAssets.new(); sky.pool=TestPool.new(); sky.set_process(false)
	check(not sky.is_processing(),"No complete sky set does not schedule publication")
	check(sky.select_sky(1) and not sky.is_processing(),"Table request stays off the frame callback")
	var table_id: int=sky.pending.keys()[0]
	var row:={"DAWN":"skyda_001","DAY":"sky_001","DUSK":"skyd_001","NIGHT":"skyn_001"}
	sky.completed(table_id,{"value":{"orderedRows":[{},row]}})
	check(sky.waiting.size()==5 and not sky.is_processing(),"Five original model requests still leave publication asleep")
	var model_ids: Array=sky.pending.keys()
	for index in model_ids.size():
		sky.completed(int(model_ids[index]),{"value":{"nodes":[]},"sha256":"fixture"})
		check(sky.is_processing()==(index==model_ids.size()-1),"Only the last staged model wakes publication: "+str(index))
	sky._process(0)
	check(sky.is_processing() and sky.waiting.size()==5 and sky.published==0,"Blocked pool keeps the completed cohort scheduled without partial publication")
	sky.pool.allowed=true
	for index in 5:
		sky._process(0)
		check(sky.is_processing()==(index<4),"Publication stops precisely after the fifth model: "+str(index))
	check(sky.published==1 and sky.instances.size()==5 and sky.pool.publications==5,"All five models publish once after the pool opens")
	sky.reject("Injected model failure")
	check(not sky.is_processing() and sky.waiting.is_empty() and sky.staged.is_empty(),"Failure retires the publication callback")
	check(sky.select_sky(0) and not sky.is_processing() and sky.configured and sky.sky_id==0,"No-sky selection stays off the callback")
	sky.select_sky(1); sky.stop()
	check(sky.closed and not sky.is_processing(),"Retirement stops pending publication")
	sky.close(); sky.free(); world.free()
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures},"  ")); file.close()
	quit(0 if failures.is_empty() else 1)
