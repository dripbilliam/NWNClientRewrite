extends SceneTree
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Pool=preload("res://systems/native_render/resource_pool.gd")
const AreaStream=preload("res://systems/native_render/area_stream.gd")
var checks:=0
var failures: Array=[]
var args: Dictionary={}
var observations: Array=[]
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	checks+=1
	if not value: failures.append(message)
func frame() -> void:
	await process_frame; await RenderingServer.frame_post_draw
func wait_area(stream) -> bool:
	var deadline:=Time.get_ticks_msec()+45000
	while not stream.done and Time.get_ticks_msec()<deadline: await process_frame
	check(stream.done,"Native area work finishes within bounded timeout")
	return stream.done
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("fixture") or not args.has("report") or FileAccess.file_exists(args.report) or DisplayServer.get_name()=="headless": quit(2); return
	var fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(args.fixture))
	root.size=Vector2i(960,720); RenderingServer.set_default_clear_color(Color(0.02,0.03,0.04))
	var catalog:=Catalog.new(); var began:=Time.get_ticks_usec()
	check(catalog.mount_install(fixture.install) and catalog.mount_erf(fixture.module,4000000),"Native original install/owned module registration: "+catalog.failure)
	var index_ms:=(Time.get_ticks_usec()-began)/1000.0
	var host:=Node3D.new(); root.add_child(host)
	var environment:=WorldEnvironment.new(); environment.environment=Environment.new(); environment.environment.background_mode=Environment.BG_COLOR; environment.environment.background_color=Color(0.02,0.03,0.04); environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR; environment.environment.ambient_light_color=Color.WHITE; environment.environment.ambient_light_energy=0.7; host.add_child(environment)
	var light:=DirectionalLight3D.new(); host.add_child(light); light.rotation_degrees=Vector3(-60,-20,0)
	var camera:=Camera3D.new(); host.add_child(camera); camera.position=Vector3(100,100,10); camera.look_at(Vector3(50,0,-50)); camera.current=true; camera.far=500
	var pool:=Pool.new(); var stream:=AreaStream.new(); host.add_child(stream)
	stream.use_terrain_batches=str(args.get("batch","0"))!="0"
	stream.maximum_tiles_per_frame=3
	var cache_path:=OS.get_temp_dir().path_join("nwn-native-area-"+str(OS.get_process_id())+"-"+str(Time.get_ticks_usec()))
	var first_mesh: WeakRef; var first_texture: WeakRef; var resource_counts: Dictionary={}
	for name in ["dense_a","dense_b","dense_a"]:
		stream.open_area(catalog,name,pool,cache_path)
		if not await wait_area(stream): break
		var state: Dictionary=stream.snapshot(); observations.append(state)
		check(state.success,"All native terrain tiles publish: "+JSON.stringify(state.errors))
		check(state.rendered_tiles==100 and state.failed_tiles==0 and stream.instances.size()==100,"All 100 original tile placements render")
		check(state.model_jobs==1 and state.unique_models==1,"Repeated tiles prepare their original model once per area")
		check(int(state.definition_thread)!=OS.get_main_thread_id(),"ARE/SET parsing runs on a native worker")
		check(state.publish_frames>1,"Publication is spread across frames")
		check(stream.bundles.is_empty() and stream.requests.is_empty() and stream.assets.running.is_empty(),"CPU bundles and active model jobs drain after publication")
		if not state.success: continue
		var original=stream.instances[0]
		var resources: Array=[]
		if stream.use_terrain_batches:
			check(stream.batcher.owners.size()>0 and state.batches_published==stream.batcher.owners.size(),"Terrain publishes native batched render owners")
			for owner in stream.batcher.owners:
				if owner is MultiMeshInstance3D:
					resources.append(owner.multimesh.mesh)
					check(owner.multimesh.instance_count<=16,"Terrain batch retains 4x4-tile culling granularity")
			check(stream.batcher.owners.size()<100*26,"Batch render owners reduce original per-tile mesh instance count")
		else:
			check(original.meshes.size()>0,"Original tile contains direct native geometry")
			if original.meshes.is_empty(): continue
			resources.append(original.meshes[0].mesh)
			check(is_same(original.meshes[0].mesh,stream.instances[1].meshes[0].mesh) and not is_same(original.parts[0],stream.instances[1].parts[0]),"Repeated tiles share GPU mesh with private transforms")
		check(original.position==Vector3(5,0,-5) and stream.instances[99].position==Vector3(95,0,-95),"First and final original tiles retain map positions")
		if resource_counts.is_empty():
			if not resources.is_empty(): first_mesh=weakref(resources[0])
			resource_counts={"meshes":pool.meshes.size(),"textures":pool.textures.size(),"materials":pool.materials.size()}
			if not pool.textures.is_empty(): first_texture=weakref(pool.textures.values()[0])
		else:
			check(pool.meshes.size()==int(resource_counts.meshes) and pool.textures.size()==int(resource_counts.textures) and pool.materials.size()==int(resource_counts.materials),"A-B-A reuses prepared GPU resources without growth")
			check(state.cache_hits==1,"Subsequent native area uses persistent decoded model cache")
		await frame(); await frame()
		var image:=root.get_texture().get_image(); var visible_pixels:=0
		for y in range(0,image.get_height(),4):
			for x in range(0,image.get_width(),4):
				var color:=image.get_pixel(x,y)
				if color.r>0.06 or color.g>0.07 or color.b>0.08: visible_pixels+=1
		check(visible_pixels>2000,"Original area is visibly drawn, not an empty loaded state")
		if observations.size()==1: image.save_png(str(args.report).trim_suffix(".json")+"-terrain.png")
		var frame_ms: Array=[]; var draw_calls: Array=[]
		for i in 30:
			var frame_begin:=Time.get_ticks_usec()
			camera.position=Vector3(50+cos(i*0.03)*90,90,-50+sin(i*0.03)*90); camera.look_at(Vector3(50,0,-50)); await frame()
			frame_ms.append((Time.get_ticks_usec()-frame_begin)/1000.0); draw_calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		frame_ms.sort(); draw_calls.sort(); state.orbit_frame_ms_median=frame_ms[15]; state.orbit_frame_ms_p95=frame_ms[28]; state.orbit_draws_median=draw_calls[15]
		resources.clear()
	# Retire an in-flight definition, then admit another: no stale publication.
	stream.open_area(catalog,"missing_area",pool,cache_path)
	stream.open_area(catalog,"dense_b",pool,cache_path)
	if await wait_area(stream):
		check(stream.snapshot().success and stream.definition.name=="dense_b" and stream.instances.size()==100,"Retired definition cannot publish errors or tiles into the next area")
	stream.open_area(catalog,"missing_area",pool,cache_path)
	if await wait_area(stream): check(not stream.snapshot().success and stream.instances.is_empty(),"Missing area fails explicitly without leaving stale terrain")
	stream.close(); check(stream.definition_task==-1 and stream.assets.running.is_empty() and stream.instances.is_empty(),"Native area definition and model tasks drain on close")
	await frame(); await frame(); pool.clear(); host.free(); await frame(); await frame()
	check(first_mesh==null or first_mesh.get_ref()==null,"Area mesh GPU resources release after owners and pool retire")
	check(first_texture==null or first_texture.get_ref()==null,"Area texture resources release after owners and pool retire")
	var hashes: Dictionary={}
	for folder in ["native_data","native_render"]:
		for name in DirAccess.get_files_at("res://systems/"+folder):
			if name.ends_with(".gd"): hashes["systems/"+folder+"/"+name]=FileAccess.get_sha256("res://systems/"+folder+"/"+name)
	hashes["tests/native_area_render_test.gd"]=FileAccess.get_sha256("res://tests/native_area_render_test.gd")
	var report: Dictionary={"passed":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Native original terrain A-B-A and orbit only; no actors, effects, multiplayer or full-world FPS acceptance","native_only":true,"complete_migration":false,"index_ms":index_ms,"cache_directory":cache_path,"areas":observations,"resources":resource_counts,"sourceSha256":hashes}
	var file:=FileAccess.open(args.report,FileAccess.WRITE); file.store_string(JSON.stringify(report,"\t")); file.close(); quit(0 if failures.is_empty() else 1)
