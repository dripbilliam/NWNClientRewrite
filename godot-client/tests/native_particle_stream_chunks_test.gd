extends "res://tests/native_chunk_binding_test.gd"
const Group=preload("res://systems/native_render/particle_stream_group.gd")
const Metrics=preload("res://systems/native_render/particle_metrics.gd")
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("report") or FileAccess.file_exists(args.report): quit(2); return
	var folder:=OS.get_temp_dir().path_join("nwn-native-group-chunks-"+str(OS.get_process_id())+"-"+str(Time.get_ticks_usec())); DirAccess.make_dir_recursive_absolute(folder)
	write(folder,"auth_parent",parent("auth_parent","auth_chunk")); write(folder,"auth_nested",shape("auth_nested"))
	# Each private model creates a further emitter from inside native Animate.
	# NULL deliberately invokes the original no-model chunk convention, without
	# introducing a resource cycle, a fake bitmap or recursive model replacement.
	var nested_emitter:="node emitter sparks\nparent root\nupdate Single\nrender Normal\nblend Normal\nchunkname NULL\nxgrid 1\nygrid 1\nbirthrate 1\nlifeexp 1\nsizestart 0.1\nendnode\n"
	write(folder,"auth_chunk",shape("auth_chunk",true).replace("endmodelgeom auth_chunk",nested_emitter+"endmodelgeom auth_chunk"))
	var catalog:=Catalog.new(); check(catalog.mount_directory(folder),"Actual raw chunk models mount")
	var assets:=Assets.new(); root.add_child(assets); assets.configure(catalog); var results: Dictionary={}; assets.completed.connect(func(id,result):results[id]=result)
	var job: int=assets.request("auth_parent",2002,"static-model"); var deadline:=Time.get_ticks_msec()+10000
	while not results.has(job) and Time.get_ticks_msec()<deadline: await process_frame
	if not results.has(job): check(false,"Parent resource worker finishes"); assets.close(); quit(1); return
	check(str(results[job].error).is_empty(),"Parent native preparation succeeds")
	var world:=Node3D.new(); root.add_child(world); var metrics:=Metrics.new(); world.set_meta("native_particle_metrics",metrics)
	var camera:=Camera3D.new(); world.add_child(camera); camera.position=Vector3(2,3,6); camera.look_at(Vector3.ZERO); camera.current=true
	var pool:=Pool.new(); pool.unshaded=true; var hub:=Hub.new(); world.add_child(hub); hub.configure(catalog,pool); world.set_meta("native_reference_hub",hub)
	var group:=Group.new(); world.add_child(group); check(group.configure(world),"Shared owner configures with real chunk services"); group.set_process(false)
	var template=pool.model_template(results[job]); check(template!=null,"Production chunk template builds")
	if template==null: group.close(); assets.close(); hub.close(); world.free(); quit(1); return
	var parents: Array=[]; var emitters: Array=[]
	for index in 2:
		var owner=template.create(); world.add_child(owner); owner.position.x=-2 if index==0 else 2; parents.append(owner); emitters.append(emitter(owner))
	check(group.fast_members==2 and group.fallback_reasons.is_empty(),"Private chunk emitters join native simulation without old callbacks")
	group.step(1.0/60.0)
	check(emitters.all(func(e):return group.info(e.get_instance_id()).frames==0 and e.active_count()==0),"Pending templates advance neither chunk time nor particles")
	deadline=Time.get_ticks_msec()+10000
	while not hub.ready() and Time.get_ticks_msec()<deadline: await process_frame
	check(hub.ready() and emitters.all(func(e):return e.chunk_models.ready()),"Both private bindings receive the shared asynchronous template")
	var peak_pending:=0
	for frame in 96:
		group.step(1.0/60.0); peak_pending=maxi(peak_pending,group.pending_registrations.size())
		check(not group.closed and group.failure.is_empty() and not group.last.has("error"),"Complete native chunk frame "+str(frame)+" "+group.failure+" "+str(group.last.get("error","")))
		await process_frame
	deadline=Time.get_ticks_msec()+10000
	while not hub.ready() and Time.get_ticks_msec()<deadline: await process_frame
	var samples: Array=[]
	for e in emitters: samples.append(e.snapshot())
	check(samples.all(func(s):return s.frames==96 and s.allocated>0 and s.vertices==0 and s.chunks.created>0 and s.chunks.detached>0 and s.failure.is_empty()),"Native chunk frames retain private allocation, recycling and exact zero quad counts")
	check(peak_pending>0 and group.pending_registrations.is_empty(),"Nested emitters created inside native simulation are admitted on the next frame boundary")
	check(group.fast_members>2 and group.fallback_reasons.is_empty(),"Nested NULL emitters also remain native rather than leaking into fallback ticks")
	check(emitters[0].chunk_models.models[0]!=emitters[1].chunk_models.models[0] and emitters[0].chunk_models.models[0].meshes[0].mesh==emitters[1].chunk_models.models[0].meshes[0].mesh,"Private chunk identities retain shared immutable mesh data")
	var held: Array=[]
	for model in emitters[0].chunk_models.models: held.append(weakref(model))
	parents[0].retire(); await process_frame; await process_frame
	check(held.all(func(reference):return reference.get_ref()==null),"Parent retirement destroys its private hierarchy and nested emitters")
	group.step(1.0/60.0)
	check(not group.closed and group.failure.is_empty() and group.fast_members>0,"Remaining chunk parent survives another hierarchy's retirement")
	var summary:=group.snapshot(); var hub_summary:=hub.snapshot(); parents[1].retire(); await process_frame; await process_frame
	group.step(0.0); check(group.members.is_empty() and metrics.snapshot().emitters==0,"All native child owners and fixed counter records retire together")
	group.close(); assets.close(); hub.close(); world.free(); assets.free(); await process_frame; await RenderingServer.frame_post_draw; RenderingServer.force_sync(); pool.clear()
	for name in ["auth_parent","auth_chunk","auth_nested"]: DirAccess.remove_absolute(folder.path_join(name+".mdl"))
	DirAccess.remove_absolute(folder)
	var file:=FileAccess.open(args.report,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"samples":samples,"group":summary,"hub":hub_summary,"peak_deferred_registrations":peak_pending,"network_connections":0,"scope":"Production raw-model preparation, asynchronous chunk readiness, native grouped simulation/private model publication, reentrant nested NULL emitter admission, recycling, shared meshes and complete hierarchy/counter retirement. Not a whole-room performance or full original-pixel acceptance."},"\t")); file.close(); quit(0 if failures.is_empty() else 1)
