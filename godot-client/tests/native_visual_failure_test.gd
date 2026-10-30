extends SceneTree
const World=preload("res://systems/native_render/live_world.gd")
const Stream=preload("res://systems/native_render/object_stream.gd")
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
class TestWorld:
	extends World
	func ready_for_admission() -> bool: return not closed and stats.errors.is_empty()
class Rigs:
	extends RefCounted
	var stats:={"skin_meshes":0,"pose_frames":0,"clips":0,"missing_requested_clips":[]}
	func clip_length(_id: int,_code: int) -> float: return 1.0
class Body:
	extends Node3D
	var rigs:=Rigs.new()
	func set_animation(_code: int,_speed: float) -> void: pass
	func retire() -> void: queue_free()
class FailedActorBatch:
	extends Node
	var actors: Dictionary={}
	var done:=true
	var stats:={"errors":[{"id":1,"reason":"Authored required player model failure"}]}
	func detach_prepared_data() -> Dictionary: return {}
	func close() -> void: pass
var checks:=0
var failures: Array=[]
var streams: Array=[]
func check(ok: bool,reason: String) -> void:
	checks+=1
	if not ok: failures.append(reason); print("FAIL: ",reason)
func write(path: String,text: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir()); var file:=FileAccess.open(path,FileAccess.WRITE); file.store_string(text); file.close()
func row(id: int,appearance: int,kind: int=9) -> Dictionary:
	return {"id":id,"objectType":kind,"areaId":1,"replicated":{"appearance":appearance,"position":[float(id),0,0],"animation":0,"orientation":[1,0]}}
func model() -> String:
	return "newmodel authored\nbeginmodelgeom authored\nnode trimesh root\nparent NULL\nverts 3\n0 0 0\n1 0 0\n0 0 1\ntverts 3\n0 0 0\n1 0 0\n0 1 0\nfaces 1\n0 1 2 1 0 1 2 0\nendnode\nendmodelgeom authored\n"
func batch(world,catalog,rows: Array):
	var owner:=Stream.new(); world.add_child(owner); owner.configure(catalog,world.pool,rows,1,"")
	var keys: Dictionary={}
	for object in rows: keys[int(object.id)]=world.signature(object)
	world.batches.append({"owner":owner,"actors":false,"keys":keys})
	var deadline:=Time.get_ticks_msec()+30000
	while not owner.done and Time.get_ticks_msec()<deadline: await process_frame
	check(owner.done,"Actual static stream completes bounded authored worker jobs")
	check(owner.assets.pending.is_empty() and owner.assets.running.is_empty(),"Completed batch has zero asset workers")
	var sample: Dictionary=owner.stats.duplicate(true); streams.append(sample)
	world._process(0.0)
	return sample
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("report") or FileAccess.file_exists(args.report): quit(2); return
	var original: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://../backups/animations/native-world-visual-admission-v1.json"))
	check(original.rows.size()==54 and original.binarySha256=="3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a","Complete original visual-loader oracle identity")
	check(original.rows.filter(func(value):return value.attempted and not value.case.loaded).all(func(value):return not value.result and value.modelSlot==0 and value.field44==123 and value.resref=="previous_model"),"Original null model results do not commit resref/reset state")
	var folder:=OS.get_temp_dir().path_join("nwn-native-admission-"+str(OS.get_process_id())+"-"+str(Time.get_ticks_usec()))
	write(folder.path_join("authored.mdl"),model())
	write(folder.path_join("placeables.2da"),"2DA V2.0\n\nModelName\n0 absent_model\n1 authored\n2 ****\n")
	for name in ["genericdoors","doortypes"]: write(folder.path_join(name+".2da"),"2DA V2.0\n\nModelName VisibleModel\n0 authored 0\n")
	var catalog:=Catalog.new(); check(catalog.mount_directory(folder),"Authored raw model/table catalog mounts without original assets")
	var world:=TestWorld.new(); root.add_child(world); world.set_process(false); world.area_id=1
	var rows: Array=[row(1,0,5),row(2,0),row(3,1),row(4,2),row(5,0,10)]
	world.receive(rows,1); var player:=Body.new(); world.add_child(player); world.instances[1]=player; world.installed[1]=world.signature(rows[0])
	var state: Dictionary=await batch(world,catalog,rows.slice(1))
	check(state.errors.size()==2 and state.scope_errors.is_empty() and state.object_failures.has(2) and state.object_failures.has(4),"Missing model and appearance produce object-specific failures, preserving strict stream diagnostics")
	check(world.stats.errors.is_empty() and world.ready_for_control(),"Independent static failures leave admitted player's input available")
	check(world.instances.has(3) and world.instances[3].meshes.size()==1 and world.installed.has(3),"Valid neighboring original-data path admits its authored mesh despite missing models")
	check(world.hidden.has(5) and not world.failed_objects.has(5),"Authored invisible door stays distinct from a failed visual")
	check(world.failed_objects.size()==2 and not world.installed.has(2) and not world.hidden.has(2),"Failed visuals remain explicitly failed and are never counted as installed/hidden")
	check(world.pending_plan({}).statics.is_empty() and not world.snapshot().object_visuals_complete,"Failed appearance keys stop endless preparation retries without claiming object completeness")
	for frame in 5: world.receive(rows,1); world._process(0.0)
	check(world.failed_objects.size()==2 and world.stats.failed_admissions==2,"Unchanged raw snapshots preserve failure binding without new attempts")
	rows[1].replicated.appearance=1; world.receive(rows,1)
	check(not world.failed_objects.has(2) and world.pending_plan({}).statics.any(func(object):return int(object.id)==2),"Changed appearance removes only its old failure and may prepare again")
	await batch(world,catalog,[rows[1]])
	check(world.instances.has(2) and world.installed[2]==world.signature(rows[1]),"Corrected appearance recovers through actual workers and model publication")
	var previous=world.instances[3]; var previous_key: String=world.installed[3]
	rows[2].replicated.appearance=0; world.receive(rows,1); await batch(world,catalog,[rows[2]])
	check(world.instances[3]==previous and world.installed[3]==previous_key and world.failed_objects.has(3),"Failed replacement preserves the previously admitted model while marking replacement incomplete")
	# A result from an earlier appearance must not fail a newly changed binding.
	var stale:=Stream.new(); world.add_child(stale); stale.set_process(false); stale.done=true; stale.object_failed(2,"Authored old result"); world.batches.append({"owner":stale,"actors":false,"keys":{2:"old-key"}})
	var before:=int(world.stats.stale_results); world._process(0.0)
	check(not world.failed_objects.has(2) and world.stats.stale_results==before+1,"Stale failed results cannot poison current appearance")
	rows=rows.filter(func(object):return int(object.id) not in [3,4]); world.receive(rows,1)
	check(world.failed_objects.is_empty() and world.snapshot().object_visuals_complete,"Server removal clears failed bindings and complete state reflects remaining actual models")
	rows=rows.filter(func(object):return int(object.id)!=5); world.receive(rows,1)
	check(not world.hidden.has(5) and not world.installed.has(5) and world.snapshot().object_visuals_complete,"Server deletion retires invisible bindings as well as physical instances")
	# Shared table failure is not an optional-object failure.
	var bad_folder:=folder.path_join("bad"); write(bad_folder.path_join("placeables.2da"),"not a table")
	for name in ["genericdoors","doortypes"]: write(bad_folder.path_join(name+".2da"),"2DA V2.0\n\nModelName\n0 authored\n")
	var bad_catalog:=Catalog.new(); bad_catalog.mount_directory(bad_folder)
	await batch(world,bad_catalog,[rows[1]])
	check(not world.stats.errors.is_empty() and not world.ready_for_control(),"Corrupt required appearance table still stops world admission")
	world.stats.errors.clear(); var actor:=FailedActorBatch.new(); world.add_child(actor); world.batches.append({"owner":actor,"actors":true,"keys":{1:world.signature(rows[0])}}); world._process(0.0)
	check(not world.stats.errors.is_empty() and not world.ready_for_control(),"Required actor failure retains explicit scope failure")
	var tracked: Array=[]
	for instance in world.instances.values(): tracked.append(weakref(instance))
	world.close(); check(world.failed_objects.is_empty() and world.batches.is_empty(),"World close clears all failure and stream bindings")
	world.queue_free(); await process_frame; await process_frame
	check(tracked.all(func(reference):return reference.get_ref()==null),"Retired valid and retained replacement models have no owner survivors")
	var file:=FileAccess.open(args.report,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"streams":streams,"network_connections":0,"scope":"Actual native object worker/publication and world admission failures using authored raw resources plus original loader bookkeeping oracle; not dense-world/FPS or full original retry/replication parity"},"\t")); file.close(); print("NATIVE_VISUAL_FAILURE ",checks," checks, ",failures.size()," failures"); quit(0 if failures.is_empty() else 1)
