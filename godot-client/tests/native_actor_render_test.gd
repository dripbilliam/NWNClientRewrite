extends SceneTree
const Capture=preload("res://systems/native_data/capture_catalog.gd")
const Binary=preload("res://systems/native_data/binary_data.gd")
const Table=preload("res://systems/native_data/two_da.gd")
const Appearance=preload("res://systems/native_data/creature_appearance.gd")
const Lookup=preload("res://systems/native_data/animation_lookup.gd")
const Assets=preload("res://systems/native_data/asset_service.gd")
const Pool=preload("res://systems/native_render/resource_pool.gd")
const Actor=preload("res://systems/native_render/actor_instance.gd")
const Cache=preload("res://systems/native_data/prepared_cache.gd")
var checks:=0
var failures: Array=[]
var started:=0
func compare_vertices(reference,candidate) -> Dictionary:
	var maximum:=0.0; var vertices:=0
	check(reference.meshes.size()==candidate.meshes.size(),"Skeletal candidate retains every original mesh")
	for mesh_index in mini(reference.meshes.size(),candidate.meshes.size()):
		var old: MeshInstance3D=reference.meshes[mesh_index]; var next: MeshInstance3D=candidate.meshes[mesh_index]
		var old_mesh: Mesh=old.bake_mesh_from_current_skeleton_pose() if old.skin!=null else old.mesh
		var next_mesh: Mesh=next.bake_mesh_from_current_skeleton_pose()
		check(old_mesh.get_surface_count()==next_mesh.get_surface_count(),"Original surface count survives native skeletal assembly")
		for surface in mini(old_mesh.get_surface_count(),next_mesh.get_surface_count()):
			var a: PackedVector3Array=old_mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]; var b: PackedVector3Array=next_mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
			check(a.size()==b.size(),"Original vertex topology survives native skeletal assembly")
			for index in mini(a.size(),b.size()): maximum=maxf(maximum,(old.global_transform*a[index]).distance_to(next.global_transform*b[index])); vertices+=1
	check(maximum<0.00002,"Every original posed rigid/weighted world vertex agrees within 2e-5: "+str(maximum))
	return {"maximum_world_vertex_error":maximum,"vertices":vertices,"meshes":candidate.meshes.size()}
func _initialize() -> void: call_deferred("run")
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures.append(label)
func stage(args: Dictionary,name: String) -> void:
	var state:={"stage":name,"elapsed_ms":Time.get_ticks_msec()-started,"checks":checks,"failures":failures.duplicate()}
	print("NATIVE_ACTOR_STAGE "+JSON.stringify(state))
	var file:=FileAccess.open(str(args.report).trim_suffix(".json")+".progress.json",FileAccess.WRITE); file.store_string(JSON.stringify(state,"\t")); file.close()
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("fixture") or not args.has("report") or FileAccess.file_exists(args.report): quit(2); return
	started=Time.get_ticks_msec(); stage(args,"start")
	var fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(args.fixture)); var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(fixture.input)); var catalog:=Capture.new()
	check(FileAccess.get_sha256(fixture.input)==fixture.inputSha256 and catalog.mount(data.capture,data.context,data.supplements),"Original input/capture integrity")
	var tables: Dictionary={}
	for name in ["appearance","racialtypes","gender","phenotype","capart","parts_robe","tailmodel","wingmodel","cloakmodel","baseitems"]:
		var bytes:=catalog.get_resource(name,2017); var parser:=Table.new(); tables[name]=parser.parse(Binary.new(bytes).text(0,bytes.size()))
		check(catalog.failure.is_empty() and parser.failure.is_empty(),"Original actor rule table: "+name)
	var object: Dictionary={}; var plan: Dictionary={}; var planner:=Appearance.new()
	for candidate in data.objects:
		if int(candidate.get("objectType",0))!=5 or int(candidate.get("areaId",-1))!=int(data.area.id) or candidate.get("replicationRemoved",false): continue
		var possible:=planner.plan(candidate,tables)
		if not possible.is_empty() and possible.model==fixture.samples[0].name: object=candidate; plan=possible; break
	check(not object.is_empty() and not plan.is_empty(),"Native original appearance plan selects an actual captured character")
	if object.is_empty(): finish(args,{}); return
	var lookup:=Lookup.new(); var context:=lookup.context(object,tables); var maps:=lookup.maps(context)
	check(not context.is_empty() and lookup.failure.is_empty(),"Original native equipment/body animation context")
	var service:=Assets.new(); root.add_child(service); service.configure(catalog); service.cache_directory=ProjectSettings.globalize_path("user://native-prepared-v2")
	var completed: Dictionary={}; service.completed.connect(func(id: int,result: Dictionary): completed[id]=result)
	var descriptors: Array=[{"model":plan.model,"fallbackModel":plan.get("fallbackModel",""),"anchor":"","follow":true}]
	for part in plan.parts:
		var descriptor: Dictionary=part.duplicate(); descriptor.anchor=part.get("node","") if part.get("node")!=null else ""; descriptor.follow=int(part.get("partIndex",-1))==18
		descriptors.append(descriptor)
	for part in plan.attachments:
		var descriptor: Dictionary=part.duplicate(); descriptor.anchor=part.node; descriptor.follow=true; descriptors.append(descriptor)
	var jobs: Array=[]
	for descriptor in descriptors:
		var name:=str(descriptor.model)
		if not catalog.has_resource(name,2002): name=str(descriptor.get("fallbackModel",""))
		check(not name.is_empty() and catalog.has_resource(name,2002),"Original native body/part model exists: "+str(descriptor.model))
		jobs.append(service.request(name,2002,"actor-model",{"plt_candidates":descriptor.get("pltCandidates",[]),"palette_colors":descriptor.get("paletteColors",plan.paletteColors)}))
	var deadline:=Time.get_ticks_msec()+120000
	while completed.size()<jobs.size() and Time.get_ticks_msec()<deadline: await process_frame
	check(completed.size()==jobs.size(),"All original body/part/supermodel jobs complete on native workers")
	stage(args,"resources-prepared")
	var pieces: Array=[]
	for index in jobs.size():
		if not completed.has(jobs[index]): continue
		var bundle: Dictionary=completed[jobs[index]]; check(str(bundle.error).is_empty(),"Original actor piece prepares: "+str(descriptors[index].model)+" "+str(bundle.error))
		var piece: Dictionary=descriptors[index].duplicate(); piece.bundle=bundle; pieces.append(piece)
	var host:=Node3D.new(); root.add_child(host); var pool:=Pool.new(); pool.unshaded=true; var actor:=Actor.new(); actor.use_skeleton=args.get("compare-skeleton","")=="true"; host.add_child(actor)
	var reference
	if actor.use_skeleton:
		reference=Actor.new(); host.add_child(reference); check(reference.install(pieces,pool,int(object.id),maps,0),"Reference node actor installs"); reference.visible=false; reference.rigs.set_process(false)
	check(actor.install(pieces,pool,int(object.id),maps,0),"Native original body/parts/skin assemble: "+actor.failure)
	stage(args,"actor-installed")
	if not actor.failure.is_empty():
		actor.retire(); service.close(); service.queue_free(); await process_frame; pool.clear(); host.free(); finish(args,{}); return
	check(actor.model_names.size()==pieces.size() and not actor.meshes.is_empty(),"All original character part owners and meshes are retained")
	check(actor.rigs.stats.skin_meshes>0 and actor.rigs.stats.skin_vertices>0,"Original robe reaches actual Godot GPU skinning")
	check(actor.rigs.stats.failures.is_empty(),"Native rig owner accepts original binding/weights")
	if is_instance_valid(reference): actor.rigs.set_process(false)
	var camera:=Camera3D.new(); host.add_child(camera); camera.projection=Camera3D.PROJECTION_ORTHOGONAL; camera.size=2.8; camera.position=Vector3(0,1.4,-4); camera.look_at(Vector3(0,0.9,0)); camera.near=0.01; camera.far=30; camera.current=true; root.size=Vector2i(960,768)
	for frame in 12:
		if is_instance_valid(reference): reference.rigs._update(1.0/60.0); actor.rigs._update(1.0/60.0)
		await process_frame
	await RenderingServer.frame_post_draw
	var before: Dictionary=actor.rigs.diagnostic_sample([int(object.id)]); var idle_image:=root.get_texture().get_image(); idle_image.save_png(str(args.report).trim_suffix(".json")+"-idle.png")
	var skeletal_comparisons: Array=[]
	if is_instance_valid(reference): skeletal_comparisons.append(compare_vertices(reference,actor))
	var walk_name: String=lookup.name_for(2,context); actor.set_animation(2,1.0,true)
	if is_instance_valid(reference): reference.set_animation(2,1.0,true)
	for frame in 45:
		if is_instance_valid(reference): reference.rigs._update(1.0/60.0); actor.rigs._update(1.0/60.0)
		await process_frame
	await RenderingServer.frame_post_draw
	var after: Dictionary=actor.rigs.diagnostic_sample([int(object.id)]); var delta: Dictionary=actor.rigs.compare_samples(before,after)
	if is_instance_valid(reference): skeletal_comparisons.append(compare_vertices(reference,actor))
	check(delta.changed_local_parts>0,"Original clip playback changes actual physical bones")
	check(delta.maximum_local_skin_vertex_delta>0.00001,"Actual native GPU skin vertices change with original animation")
	var active: Array=delta.get("active_clips",[])
	check(active.any(func(clip): return clip.clip==walk_name),"Original native animation ID selects the intended clip: "+walk_name)
	var walk_image:=root.get_texture().get_image(); walk_image.save_png(str(args.report).trim_suffix(".json")+"-walk.png")
	check(Cache.digest(idle_image.get_data())!=Cache.digest(walk_image.get_data()),"Actual original character drawing changes between poses")
	stage(args,"poses-drawn")
	var summary: Dictionary=actor.snapshot(); var actor_ref: WeakRef=weakref(actor); actor.retire()
	if is_instance_valid(reference): reference.retire()
	service.close(); service.queue_free(); pieces.clear(); completed.clear()
	stage(args,"workers-and-inputs-retired")
	await process_frame; await process_frame; pool.clear(); stage(args,"pool-cleared"); host.free(); stage(args,"host-freed"); await process_frame; await process_frame; await RenderingServer.frame_post_draw
	stage(args,"retirement-drawn")
	check(actor_ref.get_ref()==null,"Native original actor/rig/skin owner retires")
	finish(args,{"actor":summary,"pose_delta":delta,"context":context,"walk_clip":walk_name,"skeletal_comparisons":skeletal_comparisons})
func finish(args: Dictionary,details: Dictionary) -> void:
	var report:={"passed":failures.is_empty(),"checks":checks,"failures":failures,"native_only":true,"performance_accepted":false,"scope":"Original native multipart body/robe animation and GPU skin drawing; held/worn equipment, full live campaign and full migration pending"}
	report.merge(details)
	var file:=FileAccess.open(args.report,FileAccess.WRITE); file.store_string(JSON.stringify(report,"\t")); file.close(); quit(0 if failures.is_empty() else 1)
