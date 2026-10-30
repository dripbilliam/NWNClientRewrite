extends SceneTree
const World=preload("res://systems/native_render/live_world.gd")
const Retirement=preload("res://systems/native_render/world_retirement.gd")
const Stream=preload("res://systems/native_render/object_stream.gd")
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
class Gate:
	extends RefCounted
	var started:=Semaphore.new()
	var release:=Semaphore.new()
class DelayedSource:
	extends RefCounted
	var inner
	var gate
	var failure:=""
	func fork():
		var copy:=DelayedSource.new(); copy.inner=inner.fork(); copy.gate=gate; return copy
	func get_resource(name: String,kind: int) -> PackedByteArray:
		if name=="placeables": gate.started.post(); gate.release.wait()
		var bytes: PackedByteArray=inner.get_resource(name,kind); failure=inner.failure; return bytes
class TestWorld:
	extends World
	func ready_for_admission() -> bool: return not closed and not retiring and stats.errors.is_empty()
class Rigs:
	extends RefCounted
	var stats:={"skin_meshes":0,"pose_frames":0,"clips":0,"missing_requested_clips":[]}
	func clip_length(_id: int,_code: int) -> float: return 1.0
class Body:
	extends Node3D
	var rigs:=Rigs.new()
	func set_animation(_code: int,_speed: float) -> void: pass
	func retire() -> void: queue_free()
var checks:=0
var failures: Array=[]
var canceled_callbacks:=0
var stale_registry_callbacks:=0
func check(ok: bool,reason: String) -> void:
	checks+=1
	if not ok: failures.append(reason); print("FAIL: ",reason)
func write(path: String,text: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir()); var file:=FileAccess.open(path,FileAccess.WRITE); file.store_string(text); file.close()
func row(id: int,kind: int) -> Dictionary: return {"id":id,"objectType":kind,"areaId":1,"replicated":{"appearance":0,"position":[float(id),0,0],"animation":0,"orientation":[1,0]}}
func make_world():
	var world:=TestWorld.new(); root.add_child(world); world.set_process(false); world.area_id=1; world.receive([row(1,5),row(2,9)],1)
	var player:=Body.new(); world.add_child(player); world.instances[1]=player; world.installed[1]=world.signature(row(1,5))
	return world
func make_stream(world,source):
	var owner:=Stream.new(); world.add_child(owner); owner.configure(source,world.pool,[row(2,9)],1,""); world.batches.append({"owner":owner,"actors":false,"keys":{2:world.signature(row(2,9))}}); return owner
func blocked_world(catalog):
	var world=make_world(); var gate:=Gate.new(); var source:=DelayedSource.new(); source.inner=catalog; source.gate=gate; var owner=make_stream(world,source)
	var deadline:=Time.get_ticks_msec()+10000; var started:=false
	while not started and Time.get_ticks_msec()<deadline:
		started=gate.started.try_wait()
		if not started: await process_frame
	check(started,"Real asset worker reached controlled delayed read")
	return {"world":world,"owner":owner,"gate":gate,"started":started}
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("report") or FileAccess.file_exists(args.report): quit(2); return
	var folder:=OS.get_temp_dir().path_join("nwn-retire-world-"+str(OS.get_process_id())+"-"+str(Time.get_ticks_usec()))
	write(folder.path_join("authored.mdl"),"newmodel authored\nbeginmodelgeom authored\nnode trimesh root\nparent NULL\nverts 3\n0 0 0\n1 0 0\n0 0 1\ntverts 3\n0 0 0\n1 0 0\n0 1 0\nfaces 1\n0 1 2 1 0 1 2 0\nendnode\nendmodelgeom authored\n")
	for name in ["placeables","genericdoors","doortypes"]: write(folder.path_join(name+".2da"),"2DA V2.0\n\nModelName\n0 authored\n")
	var catalog:=Catalog.new(); check(catalog.mount_directory(folder),"Authored native catalog mounts")
	var retirement:=Retirement.new(); root.add_child(retirement); var cycles: Array=[]
	for index in 6:
		var blocked: Dictionary=await blocked_world(catalog); var old=blocked.world; var owner=blocked.owner; var gate=blocked.gate
		var old_ref: WeakRef=weakref(old); var assets_ref: WeakRef=weakref(owner.assets); var epoch:=int(owner.assets.epoch)
		var body:=StaticBody3D.new(); old.add_child(body); body.collision_layer=7; body.collision_mask=5
		var shape:=CollisionShape3D.new(); shape.shape=BoxShape3D.new(); body.add_child(shape)
		await physics_frame; await physics_frame; await process_frame
		var ray:=PhysicsRayQueryParameters3D.create(Vector3(0,2,0),Vector3(0,-2,0),7)
		check(old.get_world_3d().direct_space_state.intersect_ray(ray).get("collider")==body,"Original old-area body participates before retirement")
		# Physics setup above deliberately advances frames. Only completions after
		# the retirement boundary are stale; ordinary earlier results are valid.
		owner.assets.completed.connect(func(_id,_result): canceled_callbacks+=1)
		old.instance_removed.connect(func(_id): stale_registry_callbacks+=1)
		check(old.worker_tasks().any(func(task):return not WorkerThreadPool.is_task_completed(int(task))),"Old scope has a verified live worker before retirement")
		retirement.retire(old)
		check(old.retiring and old.is_inside_tree() and not old.is_queued_for_deletion() and not old.visible and old.process_mode==Node.PROCESS_MODE_DISABLED,"Old scene stays owned but hidden and stopped while worker is live")
		check(old.get_world_3d().direct_space_state.intersect_ray(ray).is_empty() and old.instance_removed.get_connections().is_empty(),"Old picking/collision and registry callbacks are disabled immediately")
		check(owner.assets.epoch==epoch+1 and owner.assets.pending.is_empty() and retirement.pending_workers()>0,"Old pending work is canceled without waiting for the live read")
		old.receive([],99); check(old.controlled_id==1 and old.desired.size()==2,"Retired scope rejects further state")
		for frame in 3: await process_frame
		check(old_ref.get_ref()!=null and retirement.worlds.size()==1,"Frames continue while the old read is held; owner is not prematurely freed")
		var current=make_world(); var current_owner=make_stream(current,catalog); var deadline:=Time.get_ticks_msec()+10000
		while not current_owner.done and Time.get_ticks_msec()<deadline: await process_frame
		check(current_owner.done,"Next world prepares through actual workers while old read is still held")
		current._process(0.0); check(current.instances.has(2) and current.instances[2].meshes.size()==1 and current.ready_for_control(),"Next scope admits its real authored mesh and player independently")
		gate.release.post(); deadline=Time.get_ticks_msec()+10000
		while old_ref.get_ref()!=null and Time.get_ticks_msec()<deadline: await process_frame
		await process_frame
		check(old_ref.get_ref()==null and assets_ref.get_ref()==null and retirement.worlds.is_empty(),"Completed old worker is joined and both scene/service owners are released")
		check(canceled_callbacks==0 and stale_registry_callbacks==0 and current.instances.has(1) and current.instances.has(2),"Late completion/close cannot publish or remove IDs from the new registry")
		cycles.append({"index":index,"current_entities":current.instances.size(),"pending_retired":retirement.worlds.size()}); current.close(); current.queue_free(); await process_frame; await process_frame
	# Exercise the memory bound with two actually blocked scopes. Releasing the
	# oldest read before overflow makes the forced join deterministic and safe.
	var first: Dictionary=await blocked_world(catalog); var second: Dictionary=await blocked_world(catalog)
	retirement.retire(first.world); retirement.retire(second.world); check(retirement.worlds.size()==2,"Retired-world retention reaches its explicit bound")
	first.gate.release.post(); var overflow=make_world(); retirement.retire(overflow)
	check(retirement.stats.forced_drains==1 and retirement.worlds.size()<=2,"Overflow safely drains the oldest owner and never exceeds the retention bound")
	second.gate.release.post(); retirement.close(); check(retirement.worlds.is_empty() and retirement.pending_workers()==0,"Explicit shutdown joins all remaining workers")
	var metrics:=retirement.snapshot(); retirement.queue_free(); await process_frame; await process_frame
	var file:=FileAccess.open(args.report,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"cycles":cycles,"retirement":metrics,"canceled_callbacks":canceled_callbacks,"stale_registry_callbacks":stale_registry_callbacks,"network_connections":0,"scope":"Actual native asset workers held at an authored read boundary, next-world preparation and deferred owner release across six cycles plus overflow; no full network transition/cold-warm/FPS acceptance"},"\t")); file.close(); print("NATIVE_WORLD_RETIREMENT ",checks," checks, ",failures.size()," failures"); quit(0 if failures.is_empty() else 1)
