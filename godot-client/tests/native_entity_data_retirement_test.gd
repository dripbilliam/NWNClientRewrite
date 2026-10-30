extends SceneTree
const World=preload("res://systems/native_render/live_world.gd")
const Actor=preload("res://systems/native_render/actor_instance.gd")
const ActorData=preload("res://systems/native_data/actor_model.gd")
const Cache=preload("res://systems/native_data/prepared_cache.gd")
const Disposal=preload("res://systems/native_data/data_retirement.gd")
class HeldDisposal:
	extends Disposal
	var entered:=Semaphore.new()
	var release:=Semaphore.new()
	func _release(payload: Dictionary) -> void:
		entered.post(); release.wait(); super._release(payload)
var checks:=0
var failures: Array=[]
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label); print("FAIL: ",label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var report:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): report=arg.substr(9)
	if report.is_empty() or FileAccess.file_exists(report): quit(2); return
	var disposal:=HeldDisposal.new(); root.add_child(disposal); disposal.set_process(false)
	var world:=World.new(); root.add_child(world); world.set_process(false)
	check(world.data_retirement==disposal and not world.owns_data_retirement,"Live entity disposal uses the persistent session worker owner")
	var text:="newmodel authored\nbeginmodelgeom authored\nnode trimesh root\nparent NULL\nverts 3\n0 0 0\n1 0 0\n0 0 1\ntverts 3\n0 0 0\n1 0 0\n0 1 0\nfaces 1\n0 1 2 1 0 1 2 0\nendnode\nendmodelgeom authored\n"
	var parser:=ActorData.new(); var model: Dictionary=parser.parse(text.to_utf8_buffer()); model.rig_asset=parser.rig_asset(model)
	var bundle:={"value":model,"sha256":Cache.digest(text.to_utf8_buffer()),"textures":{},"error":"","animation_sources":[]}
	var sources: Array=[]
	for id in [1,2]:
		var actor:=Actor.new(); world.add_child(actor)
		check(actor.install([{"bundle":bundle,"follow":true}],world.pool,id,{}),"Real native actor publishes for disposal fixture "+str(id))
		actor.rigs.set_process(false); world.instances[id]=actor; world.installed[id]="key-"+str(id)
		world.desired[id]={"key":"key-"+str(id),"object":{"id":id,"objectType":5,"areaId":1,"replicated":{"position":[0,0,0]}}}
		sources.append(weakref(actor))
	var retained: Dictionary=world.instances[1].retain_decoded_data()
	check(retained.rig_sources.size()==1 and retained.rig_sources[0]==model.rig_asset,"Only original decoded rig assets are retained; no physical Nodes/material owners enter the payload")
	retained.clear()
	var began:=Time.get_ticks_usec(); world.remove_instance(1); var main_ms:=(Time.get_ticks_usec()-began)/1000.0
	check(not world.instances.has(1) and not world.installed.has(1),"Removed actor immediately leaves canonical render/admission bindings")
	var deadline:=Time.get_ticks_msec()+5000; var parked:=false
	while not parked and Time.get_ticks_msec()<deadline:
		disposal.poll()
		parked=disposal.entered.try_wait()
		if not parked: await process_frame
	check(parked and disposal.tasks.size()==1,"Decoded source destruction reaches an actual worker while its release is deliberately held")
	for frame in 3: await process_frame
	check(sources[0].get_ref()==null and is_instance_valid(sources[1].get_ref()),"Main scene ownership retires independently while data disposal remains parked")
	check(not model.rig_asset.is_empty() and world.instances[2].rigs.entities.has(2),"Shared live model data and another actor remain intact during off-thread retirement")
	disposal.release.post(); deadline=Time.get_ticks_msec()+5000
	while not disposal.tasks.is_empty() and Time.get_ticks_msec()<deadline: disposal.poll(); await process_frame
	check(disposal.tasks.is_empty() and disposal.stats.completed==1 and disposal.stats.threads.all(func(id):return id!=OS.get_main_thread_id()),"Detached data release completes only on a worker; no main-thread disposal fallback")
	# Allow the second ordinary close to drain without leaving a parked worker.
	disposal.release.post(); world.close(); world.queue_free(); await process_frame; await process_frame
	disposal.close(); var metrics: Dictionary=disposal.snapshot(); disposal.queue_free(); await process_frame
	check(sources[1].get_ref()==null and metrics.pending==0,"Final world/session close releases the second actor and drains every worker")
	var file:=FileAccess.open(report,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"remove_main_ms":main_ms,"disposal":metrics,"public_connections":0,"scope":"Actual native private actor trees with shared immutable rig asset, parked worker disposal, continuing frames, canonical binding removal and final drain. This is ownership/threading coverage, not an Arelith hitch/FPS before-after benchmark."},"\t")); file.close(); print("NATIVE_ENTITY_DATA_RETIREMENT ",checks," checks"); quit(0 if failures.is_empty() else 1)
