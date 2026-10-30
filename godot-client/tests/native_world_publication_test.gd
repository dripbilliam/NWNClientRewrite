extends SceneTree
const World=preload("res://systems/native_render/live_world.gd")
const Objects=preload("res://systems/native_render/object_stream.gd")
const Creatures=preload("res://systems/native_render/creature_stream.gd")
const Assets=preload("res://systems/native_data/asset_service.gd")
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Hub=preload("res://systems/native_render/reference_assets.gd")
class TestWorld:
	extends World
	func ready_for_admission() -> bool: return not closed and not retiring and stats.errors.is_empty()
var checks:=0
var failures: Array=[]
func check(ok: bool,reason: String) -> void:
	checks+=1
	if not ok: failures.append(reason); print("FAIL: ",reason)
func write(path: String,text: String) -> void:
	var file:=FileAccess.open(path,FileAccess.WRITE); file.store_string(text); file.close()
func row(id: int,kind: int) -> Dictionary: return {"id":id,"areaId":1,"objectType":kind,"replicated":{"appearance":0,"position":[float(id),0,0],"orientation":[1,0],"animation":0}}
func model(name: String) -> String: return "newmodel "+name+"\nbeginmodelgeom "+name+"\nnode trimesh root\nparent NULL\nverts 3\n0 0 0\n0.3 0 0\n0 0 0.3\ntverts 3\n0 0 0\n1 0 0\n0 1 0\nfaces 1\n0 1 2 1 0 1 2 0\nendnode\nendmodelgeom "+name+"\n"
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("report") or FileAccess.file_exists(args.report): quit(2); return
	var folder:=OS.get_temp_dir().path_join("nwn-native-publication-"+str(OS.get_process_id())+"-"+str(Time.get_ticks_usec())); DirAccess.make_dir_recursive_absolute(folder)
	write(folder.path_join("auth_chunk.mdl"),model("auth_chunk")); write(folder.path_join("auth_marker.mdl"),model("auth_marker"))
	write(folder.path_join("auth_parent.mdl"),"newmodel auth_parent\nbeginmodelgeom auth_parent\nnode dummy root\nparent NULL\nendnode\nnode reference marker\nparent root\nrefmodel auth_marker\nreattachable 0\nendnode\nnode emitter source\nparent root\nupdate Fountain\nrender Normal\nblend Normal\ntexture absent_unused\nchunkname auth_chunk\nxgrid 1\nygrid 1\nbirthrate 8\nlifeexp 0.25\nvelocity 0.5\nendnode\nendmodelgeom auth_parent\n")
	for name in ["placeables","genericdoors","doortypes"]: write(folder.path_join(name+".2da"),"2DA V2.0\n\nModelName\n0 auth_parent\n")
	var catalog:=Catalog.new(); check(catalog.mount_directory(folder),"Authored production resource catalog mounts")
	var world:=TestWorld.new(); root.add_child(world); world.set_process(false); world.area_id=1; world.receive([row(2,9),row(3,5)],3)
	var camera:=Camera3D.new(); world.add_child(camera); camera.position=Vector3(0,4,7); camera.look_at(Vector3(2,0,0)); camera.current=true
	var hub:=Hub.new(); world.add_child(hub); hub.configure(catalog,world.pool); world.references=hub; world.set_meta("native_reference_hub",hub)
	var source:=Assets.new(); world.add_child(source); source.configure(catalog); var bundles: Array=[]; source.completed.connect(func(_id,result):bundles.append(result)); source.request("auth_parent",2002,"actor-model")
	var deadline:=Time.get_ticks_msec()+10000
	while bundles.is_empty() and Time.get_ticks_msec()<deadline: await process_frame
	if bundles.is_empty() or not str(bundles[0].error).is_empty(): check(false,"Native actor source prepares"); source.close(); world.close(); world.queue_free(); quit(1); return
	var statics:=Objects.new(); statics.admission_parent=world; world.add_child(statics); statics.configure(catalog,world.pool,[row(2,9)],1,"")
	world.batches.append({"owner":statics,"actors":false,"keys":{2:world.signature(row(2,9))}})
	var actors:=Creatures.new(); actors.admission_parent=world; world.add_child(actors); actors.assets=Assets.new(); actors.add_child(actors.assets); actors.assets.configure(catalog)
	actors.bundles.auth=bundles[0]; actors.plans=[{"id":3,"kind":5,"position":Vector3(3,0,0),"rotation":0.0,"pieces":[{"key":"auth","model":"auth_parent","anchor":"","follow":true}],"maps":{},"animation":0}]
	world.batches.append({"owner":actors,"actors":true,"keys":{3:world.signature(row(3,5))}})
	deadline=Time.get_ticks_msec()+10000
	while (not statics.done or not actors.done) and Time.get_ticks_msec()<deadline: await process_frame
	check(statics.done and actors.done and statics.instances.has(2) and actors.actors.has(3),"Actual static and actor stream publication paths prepare complete instances")
	if not statics.instances.has(2) or not actors.actors.has(3): source.close(); world.close(); world.queue_free(); quit(1); return
	var static_instance=statics.instances[2]; var actor_instance=actors.actors[3]
	check(static_instance.get_parent()==world and actor_instance.get_parent()==world and not static_instance.visible and not actor_instance.visible,"Streams attach hidden instances directly to the final world before adoption")
	var static_emitter=static_instance.find_children("native_emitter","Node3D",true,false)[0]; var actor_emitter=actor_instance.find_children("native_emitter","Node3D",true,false)[0]
	var static_reference=static_instance.find_children("native_reference","Node3D",true,false)[0]; var actor_reference=actor_instance.find_children("native_reference","Node3D",true,false)[0]
	check(not static_emitter.retired and not actor_emitter.retired and not static_reference.retired and not actor_reference.retired,"Initial native effect/reference owners remain active before admission")
	world._process(0.0)
	check(world.instances[2]==static_instance and world.instances[3]==actor_instance and static_instance.visible and actor_instance.visible,"Normal world adoption preserves identity and reveals admitted instances")
	deadline=Time.get_ticks_msec()+10000
	while not hub.ready() and Time.get_ticks_msec()<deadline: await process_frame
	deadline=Time.get_ticks_msec()+10000
	while (static_emitter.allocated==0 or actor_emitter.allocated==0) and Time.get_ticks_msec()<deadline: await process_frame
	for frame in 5: await process_frame
	var after: Array=[static_emitter.snapshot(),actor_emitter.snapshot()]
	check(after.all(func(s):return s.failure.is_empty() and s.frames>0 and s.allocated>0 and s.chunks.created>0),"Static and actor effects keep simulating after the batch owners close")
	check(not static_reference.retired and not actor_reference.retired and is_instance_valid(static_reference.model68) and is_instance_valid(actor_reference.model68),"Native referenced models survive world adoption and completed-batch retirement")
	# Controlled engine reproduction of the old in-tree handoff.
	var template=world.pool.model_template(bundles[0]); var staging:=Node3D.new(); world.add_child(staging); var control=template.create(); staging.add_child(control)
	var control_emitter=control.find_children("native_emitter","Node3D",true,false)[0]; var control_reference=control.find_children("native_reference","Node3D",true,false)[0]
	check(not control_emitter.retired and not control_reference.retired,"Legacy handoff control starts with active owners")
	control.reparent(world,true)
	check(control_emitter.retired and control_reference.retired,"Actual Godot in-tree reparent invokes exit retirement, reproducing the old failure")
	control.retire(); staging.queue_free(); var tracked: Array=[]
	for e in [static_emitter,actor_emitter]:
		for chunk in e.chunk_models.models: tracked.append(weakref(chunk))
	var summary:=hub.snapshot(); source.close(); world.close(); world.queue_free(); await process_frame; await process_frame
	check(tracked.all(func(ref):return ref.get_ref()==null),"Final world close releases surviving chunk/reference ownership with no stale models")
	var file:=FileAccess.open(args.report,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"after_admission":after,"hub":summary,"network_connections":0,"scope":"Production static/actor stream publication and live-world admission using authored native source plus an actual Godot reparent control. Actor plan/terrain readiness authored; not full protocol or original pixels/performance acceptance"},"\t")); file.close(); print("NATIVE_WORLD_PUBLICATION ",checks," checks, ",failures.size()," failures"); quit(0 if failures.is_empty() else 1)
