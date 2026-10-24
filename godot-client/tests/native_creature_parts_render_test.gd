extends SceneTree
# Native original body-part mesh + two independent PLT color sets. This checks
# actual publication/drawing, not full actor animation or campaign playability.
const Capture=preload("res://systems/native_data/capture_catalog.gd")
const Assets=preload("res://systems/native_data/asset_service.gd")
const Pool=preload("res://systems/native_render/resource_pool.gd")
const Template=preload("res://systems/native_render/model_template.gd")
const Cache=preload("res://systems/native_data/prepared_cache.gd")
var checks:=0
var failures: Array=[]
func _initialize() -> void: call_deferred("run")
func check(value: bool, label: String) -> void:
	checks+=1
	if not value: failures.append(label)
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("fixture") or not args.has("report") or FileAccess.file_exists(args.report): quit(2); return
	var fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(args.fixture))
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(fixture.input)); var catalog:=Capture.new()
	check(FileAccess.get_sha256(fixture.input)==fixture.inputSha256 and catalog.mount(data.capture,data.context,data.supplements),"Raw original input/capture integrity")
	var cases: Array=[]
	for item in fixture.plts:
		if not catalog.has_resource(item.name,2002): continue
		if cases.is_empty() or item.name==cases[0].name: cases.append(item)
		if cases.size()==2: break
	check(cases.size()==2,"Original body-part model has two palette variants")
	var service:=Assets.new(); root.add_child(service); service.configure(catalog); service.cache_directory=ProjectSettings.globalize_path("user://native-prepared-v2")
	var results: Dictionary={}; service.completed.connect(func(id: int,result: Dictionary): results[id]=result)
	var ids: Array=[]
	for item in cases: ids.append(service.request(item.name,2002,"static-model",{"plt_candidates":[item.name],"palette_colors":item.rows}))
	var deadline:=Time.get_ticks_msec()+30000
	while results.size()<ids.size() and Time.get_ticks_msec()<deadline: await process_frame
	check(results.size()==2,"Both original model/PLT worker jobs complete")
	var host:=Node3D.new(); root.add_child(host); var pool:=Pool.new(); pool.unshaded=true
	var instances: Array=[]; var templates: Array=[]; var texture_ids: Array=[]; var bitmap_hashes: Array=[]; var mesh_ids: Array=[]
	var bounds:=AABB(); var has_bounds:=false
	for index in ids.size():
		if not results.has(ids[index]): continue
		var bundle: Dictionary=results[ids[index]]
		check(str(bundle.error).is_empty(),"Native original model dependencies: "+str(bundle.error))
		if not str(bundle.error).is_empty(): continue
		var template:=Template.new(); check(template.build(bundle,pool),"Native original model template publishes: "+template.failure)
		if template.scene==null: continue
		var instance=template.create(); host.add_child(instance); instances.append(instance); templates.append(template)
		instance.position.x=float(index)*0.8
		check(not instance.meshes.is_empty(),"Original part has visible mesh geometry")
		var observed:={}
		for mesh in instance.meshes:
			mesh_ids.append(mesh.mesh.get_instance_id())
			var material: StandardMaterial3D=mesh.material_override
			if material.albedo_texture!=null:
				var texture: Texture2D=material.albedo_texture
				observed[texture.get_instance_id()]=Cache.digest(texture.get_image().get_data().slice(0,int(cases[index].width)*int(cases[index].height)*4))
			var transformed: AABB=mesh.global_transform*mesh.get_aabb()
			bounds=transformed if not has_bounds else bounds.merge(transformed); has_bounds=true
		check(not observed.is_empty(),"Prepared PLT reaches actual native mesh material")
		check(observed.values().all(func(value): return value==cases[index].sha256),"GPU texture pixels preserve exact original color selection")
		texture_ids.append(observed.keys()); bitmap_hashes.append(observed.values())
	if texture_ids.size()==2:
		check(texture_ids[0]!=texture_ids[1],"Two part instances keep independent palette textures")
		check(bitmap_hashes[0]!=bitmap_hashes[1],"Two original color sets produce different pixels")
	check(pool.stats.mesh_hits>0,"Unchanged original geometry is shared across palette variants")
	var camera:=Camera3D.new(); host.add_child(camera); camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	var center:=bounds.get_center(); var extent:=maxf(0.4,bounds.size.length())
	camera.size=extent*1.35; camera.position=center+Vector3(0.2,0.3,1.0).normalized()*extent*3.0; camera.look_at(center); camera.near=0.01; camera.far=extent*10.0; camera.current=true
	root.size=Vector2i(960,640)
	for frame in 10: await process_frame
	await RenderingServer.frame_post_draw
	var image:=root.get_texture().get_image(); image.save_png(str(args.report).trim_suffix(".json")+".png")
	var colors: Dictionary={}
	for y in range(0,image.get_height(),4):
		for x in range(0,image.get_width(),4): colors[image.get_pixel(x,y).to_rgba32()]=true
	check(colors.size()>32,"Actual viewport contains textured body-part drawing")
	var resource_stats:=pool.stats.duplicate(); var tracked: Array=[]
	for instance in instances: tracked.append(weakref(instance)); instance.retire()
	service.close(); service.queue_free(); results.clear(); templates.clear(); instances.clear()
	await process_frame; await process_frame; pool.clear(); host.free()
	await process_frame; await process_frame; await RenderingServer.frame_post_draw
	check(tracked.all(func(reference): return reference.get_ref()==null),"Native part owners retire without surviving scene instances")
	var report:={"passed":failures.is_empty(),"checks":checks,"failures":failures,"native_only":true,"models":cases.map(func(item): return item.name),"resources":resource_stats,"scope":"Original native body-part mesh/palette drawing and retirement; complete actors, animation, equipment and campaign integration pending","performance_accepted":false}
	var file:=FileAccess.open(args.report,FileAccess.WRITE); file.store_string(JSON.stringify(report,"\t")); file.close(); quit(0 if failures.is_empty() else 1)
