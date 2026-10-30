extends SceneTree
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Assets=preload("res://systems/native_data/asset_service.gd")
const Pool=preload("res://systems/native_render/resource_pool.gd")
const Hub=preload("res://systems/native_render/reference_assets.gd")
const Actor=preload("res://systems/native_render/actor_instance.gd")
const Reference=preload("res://systems/native_render/model_reference.gd")
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
		if name=="auth_chunk": gate.started.post(); gate.release.wait()
		var bytes: PackedByteArray=inner.get_resource(name,kind); failure=inner.failure; return bytes
var checks:=0
var failures: Array=[]
func check(ok: bool,reason: String) -> void:
	checks+=1
	if not ok: failures.append(reason); print("FAIL: ",reason)
func write(folder: String,name: String,text: String) -> void:
	var file:=FileAccess.open(folder.path_join(name+".mdl"),FileAccess.WRITE); file.store_string(text); file.close()
func shape(name: String,reference: bool=false) -> String:
	return "newmodel "+name+"\nbeginmodelgeom "+name+"\nnode trimesh root\nparent NULL\nverts 3\n0 0 0\n0.3 0 0\n0 0 0.3\ntverts 3\n0 0 0\n1 0 0\n0 1 0\nfaces 1\n0 1 2 1 0 1 2 0\nendnode\n"+("node reference child\nparent root\nrefmodel auth_nested\nreattachable 0\nendnode\n" if reference else "")+"endmodelgeom "+name+"\nnewanim impact "+name+"\nlength 1\ntranstime 0\nanimroot "+name+"\nnode dummy root\nparent NULL\npositionkey 2\n0 0 0 0\n1 0 0 0.1\nendnode\ndoneanim impact "+name+"\n"
func parent(name: String,chunk: String) -> String:
	return "newmodel "+name+"\nbeginmodelgeom "+name+"\nnode dummy root\nparent NULL\nendnode\nnode emitter source\nparent root\nupdate Fountain\nrender Normal\nblend Normal\ntexture unused_quad\nchunkname "+chunk+"\nxgrid 1\nygrid 1\nbirthrate 8\nlifeexp 0.25\nvelocity 0.5\nparticlerot 1.5\nsizestart 1\nendnode\nendmodelgeom "+name+"\n"
func emitter(owner): return owner.find_children("native_emitter","Node3D",true,false)[0]
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("report") or FileAccess.file_exists(args.report): quit(2); return
	var folder:=OS.get_temp_dir().path_join("nwn-native-chunk-binding-"+str(OS.get_process_id())+"-"+str(Time.get_ticks_usec())); DirAccess.make_dir_recursive_absolute(folder)
	write(folder,"auth_parent",parent("auth_parent","auth_chunk")); write(folder,"auth_chunk",shape("auth_chunk",true)); write(folder,"auth_nested",shape("auth_nested"))
	write(folder,"auth_cycle",parent("auth_cycle","auth_cycle")); write(folder,"auth_missing",parent("auth_missing","auth_absent"))
	write(folder,"auth_null",parent("auth_null","NuLl"))
	var catalog:=Catalog.new(); check(catalog.mount_directory(folder),"Authored raw native chunk catalog mounts")
	var assets:=Assets.new(); root.add_child(assets); assets.configure(catalog); var results: Dictionary={}; var jobs: Dictionary={}; assets.completed.connect(func(id,result):results[id]=result)
	for name in ["auth_parent","auth_cycle","auth_missing","auth_null"]: jobs[assets.request(name,2002,"static-model")]=name
	var deadline:=Time.get_ticks_msec()+10000
	while results.size()<jobs.size() and Time.get_ticks_msec()<deadline: await process_frame
	var bundles: Dictionary={}
	for id in jobs:
		check(results.has(id) and str(results[id].error).is_empty(),"Native parent emitter preparation: "+str(jobs[id]))
		if results.has(id): bundles[jobs[id]]=results[id]
	if bundles.size()!=4: assets.close(); assets.queue_free(); quit(1); return
	var world:=Node3D.new(); root.add_child(world); var camera:=Camera3D.new(); world.add_child(camera); camera.position=Vector3(2,3,6); camera.look_at(Vector3.ZERO); camera.current=true
	var pool:=Pool.new(); pool.unshaded=true; var hub:=Hub.new(); world.add_child(hub); hub.configure(catalog,pool); world.set_meta("native_reference_hub",hub)
	var template=pool.model_template(bundles.auth_parent); check(template!=null,"Production PackedScene emitter template builds from raw source")
	var owners: Array=[]; var emitters: Array=[]
	for index in 2:
		var owner=template.create(); world.add_child(owner); owner.position.x=-2 if index==0 else 2; owners.append(owner); var e=emitter(owner); e.set_process(false); emitters.append(e)
	check(emitters.all(func(e):return e.origin_resource=="auth_parent" and e.failure.is_empty() and is_instance_valid(e.chunk_models)),"Packed emitter clones automatically bind native chunk owners with preserved origin")
	check(hub.ready_for(owners[0]) and not hub.ready(),"Pending decorative chunk assets do not gate admitted player control")
	for e in emitters: e.tick(1.0/60.0)
	check(emitters.all(func(e):return e.frames==0 and e.allocated==0),"Unprepared chunk sources never emit placeholder geometry or half-ready private models")
	deadline=Time.get_ticks_msec()+10000
	while not hub.ready() and Time.get_ticks_msec()<deadline: await process_frame
	check(hub.ready() and hub.stats.jobs==1 and hub.stats.bundles_published==2 and emitters.all(func(e):return e.chunk_models.ready()),"Two emitters share one actual chunk preparation job and receive separate bindings")
	var samples: Array=[]
	for frame in 96:
		for e in emitters: e.tick(1.0/60.0)
		await process_frame
	deadline=Time.get_ticks_msec()+10000
	while not hub.ready() and Time.get_ticks_msec()<deadline: await process_frame
	for e in emitters: samples.append(e.snapshot())
	check(samples.all(func(s):return s.failure.is_empty() and s.frames==96 and s.allocated>0 and s.vertices==0 and s.chunks.created>0 and s.chunks.impact_requests>s.chunks.created and s.chunks.detached>0),"Automatically bound chunks simulate, play impact and recycle without supplied factory callbacks")
	check(hub.stats.jobs==2 and hub.stats.published>=4 and hub.stats.chunk_models>=4,"Nested referenced meshes share one further native job and publish under private chunks")
	var first=emitters[0].chunk_models.models[0]; var second=emitters[1].chunk_models.models[0]
	check(first!=second and first.rigs!=second.rigs and first.meshes[0].mesh==second.meshes[0].mesh and first.global_position.x<second.global_position.x,"Two original chunk hierarchies keep private models/rigs/positions with shared immutable mesh")
	check(hub.ready_for(owners[0]),"Nested effect references remain nonblocking for player control")
	var ordinary:=Reference.new(); ordinary.original_header={"model":"auth_nested"}; ordinary.origin_resource="auth_parent"; owners[1].add_child(ordinary)
	check(not hub.ready_for(owners[1]),"Ordinary required model reference still gates control during publication")
	deadline=Time.get_ticks_msec()+10000
	while not hub.ready() and Time.get_ticks_msec()<deadline: await process_frame
	check(hub.ready_for(owners[1]),"Required ordinary reference releases readiness after actual native publication")
	var tracked: Array=[]
	for model in emitters[0].chunk_models.models: tracked.append(weakref(model))
	owners[0].retire(); await process_frame; await process_frame
	check(tracked.all(func(ref):return ref.get_ref()==null) and not hub.prepared.auth_chunk.is_empty() and emitters[1].chunk_models.ready(),"Source retirement frees its private chunks without clearing another listener's cached bundle")
	var actor:=Actor.new(); world.add_child(actor); check(actor.install([{"bundle":bundles.auth_parent,"follow":false}],pool,17,{}),"Production actor/equipment assembly preserves chunk source metadata")
	var actor_emitter=emitter(actor); actor_emitter.set_process(false); deadline=Time.get_ticks_msec()+10000
	while not hub.ready() and Time.get_ticks_msec()<deadline: await process_frame
	actor_emitter.tick(0.2); check(actor_emitter.failure.is_empty() and actor_emitter.chunk_models.ready() and actor_emitter.allocated>0,"Actor route activates cached native chunk data without external model services")
	var cycle_template=pool.model_template(bundles.auth_cycle); var cyclic=cycle_template.create(); world.add_child(cyclic)
	check(str(emitter(cyclic).failure).contains("cycle/depth"),"Original self-referencing chunk resource is diagnosed before recursive publication")
	var missing_template=pool.model_template(bundles.auth_missing); var missing=missing_template.create(); world.add_child(missing); var missing_emitter=emitter(missing)
	deadline=Time.get_ticks_msec()+10000
	while not hub.ready() and Time.get_ticks_msec()<deadline: await process_frame
	missing_emitter.tick(0.2); check(not missing_emitter.failure.is_empty() and missing_emitter.allocated==0,"Absent source remains an explicit native resource failure with no replacement model")
	var no_model_template=pool.model_template(bundles.auth_null); var no_model=no_model_template.create(); world.add_child(no_model); var no_model_emitter=emitter(no_model); no_model_emitter.set_process(false); var requests_before:=int(hub.stats.requested); no_model_emitter.tick(0.2)
	check(no_model_emitter.failure.is_empty() and no_model_emitter.allocated>0 and no_model_emitter.missing_chunk_models==0 and no_model_emitter.chunk_models.no_model and int(hub.stats.requested)==requests_before,"Original case-insensitive NULL chunk has no model/I/O while retaining native particle simulation")
	# Cancel after a real worker completed but before the hub publishes its bundle.
	var cancel=template.create(); world.add_child(cancel); var canceled_emitter=emitter(cancel); canceled_emitter.set_process(false); var source=canceled_emitter.chunk_models
	check(hub.publication.any(func(entry):return entry.request.node.get_ref()==source),"Cached source has a pending actual native publication")
	cancel.retire(); await process_frame; await process_frame
	check(hub.publication.all(func(entry):return entry.request.node.get_ref()!=source),"Retired listener cannot receive late cached model data")
	var other_world:=Node3D.new(); root.add_child(other_world); var other_hub:=Hub.new(); other_world.add_child(other_hub); other_hub.configure(catalog,pool); other_hub.set_process(false); other_world.set_meta("native_reference_hub",other_hub)
	var unstarted=template.create(); other_world.add_child(unstarted)
	check(other_hub.waiting.has("auth_chunk") and other_hub.stats.jobs==0,"New source is queued before actual job submission")
	unstarted.retire(); await process_frame
	check(other_hub.waiting.is_empty() and other_hub.requests.is_empty() and other_hub.ready(),"Last listener cancellation removes unstarted resource work")
	other_hub.close(); other_world.queue_free(); await process_frame
	var delayed_world:=Node3D.new(); root.add_child(delayed_world); var delayed_hub:=Hub.new(); delayed_world.add_child(delayed_hub); var gate:=Gate.new(); var delayed_source:=DelayedSource.new(); delayed_source.inner=catalog; delayed_source.gate=gate; delayed_hub.configure(delayed_source,pool); delayed_world.set_meta("native_reference_hub",delayed_hub)
	var held=template.create(); delayed_world.add_child(held); var held_emitter=emitter(held); held_emitter.set_process(false); var held_ref: WeakRef=weakref(held_emitter.chunk_models)
	var began:=false; deadline=Time.get_ticks_msec()+10000
	while not began and Time.get_ticks_msec()<deadline:
		began=gate.started.try_wait()
		if not began: await process_frame
	check(began and delayed_hub.assets.running.values().any(func(task):return not WorkerThreadPool.is_task_completed(int(task))),"Chunk preparation has a verified live worker at controlled file-read boundary")
	held.retire(); await process_frame
	check(held_ref.get_ref()==null and delayed_hub.waiting.is_empty() and delayed_hub.jobs.size()==1,"Retired listener leaves a live job safely owned with no duplicate submission")
	var replacement=template.create(); delayed_world.add_child(replacement); var replacement_emitter=emitter(replacement); replacement_emitter.set_process(false)
	check(delayed_hub.waiting.is_empty() and delayed_hub.requests.auth_chunk.size()==1 and delayed_hub.stats.jobs==1,"Replacement listener joins the existing chunk preparation")
	gate.release.post(); deadline=Time.get_ticks_msec()+10000
	while not delayed_hub.ready() and Time.get_ticks_msec()<deadline: await process_frame
	check(delayed_hub.ready() and replacement_emitter.chunk_models.ready() and delayed_hub.stats.jobs==1 and delayed_hub.stats.bundles_published==1,"Only the replacement receives the completed native chunk bundle")
	var delayed_metrics:=delayed_hub.snapshot(); replacement.retire(); delayed_hub.close(); delayed_world.queue_free(); await process_frame; await process_frame
	var summary:=hub.snapshot(); var live_stats: Dictionary=actor_emitter.chunk_models.snapshot(); actor.retire(); owners[1].retire(); cyclic.retire(); missing.retire(); no_model.retire(); assets.close(); hub.close()
	check(hub.assets.running.is_empty() and hub.assets.pending.is_empty(),"World resource owner joins all remaining native asset work")
	world.queue_free(); assets.queue_free(); await process_frame; await process_frame; pool.clear()
	var file:=FileAccess.open(args.report,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"emitters":samples,"hub":summary,"actor_chunks":live_stats,"delayed":delayed_metrics,"network_connections":0,"scope":"Actual production PackedScene and actor chunk bindings with authored raw models, native worker deduplication, nested reference publication, readiness/failure/cancel/retirement and controlled in-flight replacement; no full original pixels, complete effects or dense-world FPS acceptance"},"\t")); file.close(); print("NATIVE_CHUNK_BINDING ",checks," checks, ",failures.size()," failures"); quit(0 if failures.is_empty() else 1)
