extends "res://tests/native_particle_scene_batches_test.gd"
const InstallCatalog=preload("res://systems/native_data/resource_catalog.gd")
const NativeAssets=preload("res://systems/native_data/asset_service.gd")
const RenderPool=preload("res://systems/native_render/resource_pool.gd")
const RefHub=preload("res://systems/native_render/reference_assets.gd")
const WorldScene=preload("res://systems/native_render/live_world.gd")
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("report") or not args.has("install") or FileAccess.file_exists(args.report): quit(2); return
	var catalog:=InstallCatalog.new(); check(catalog.mount_install(args.install),"Original installed resources mount")
	var assets:=NativeAssets.new(); root.add_child(assets); assets.configure(catalog); var results: Dictionary={}; assets.completed.connect(func(id,result):results[id]=result)
	var job: int=assets.request("plc_i05",2002,"static-model"); var deadline:=Time.get_ticks_msec()+15000
	while not results.has(job) and Time.get_ticks_msec()<deadline: await process_frame
	if not results.has(job): check(false,"Original placeable prepares"); assets.close(); quit(1); return
	check(str(results[job].error).is_empty(),"Original placeable and particle textures decode")
	var world:=WorldScene.new(); root.add_child(world); world.set_process(false)
	var group: Node=world.particle_stream_group; group.set_process(false)
	var camera:=Camera3D.new(); world.add_child(camera); camera.position=Vector3(0,5,12); camera.look_at(Vector3(0,1,0)); camera.current=true
	var environment:=WorldEnvironment.new(); world.add_child(environment); environment.environment=Environment.new(); environment.environment.background_mode=Environment.BG_COLOR; environment.environment.background_color=Color(0.03,0.04,0.06); environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR; environment.environment.ambient_light_color=Color(0.3,0.4,0.5)
	environment.environment.fog_enabled=true; environment.environment.fog_mode=Environment.FOG_MODE_DEPTH; environment.environment.fog_depth_begin=5; environment.environment.fog_depth_end=35; environment.environment.fog_density=0.3; environment.environment.fog_sun_scatter=0
	var light:=OmniLight3D.new(); world.add_child(light); light.position=Vector3(2,3,3); light.omni_range=30; light.light_color=Color(1,0.7,0.3); light.light_energy=2.0
	var pool:=RenderPool.new(); var hub:=RefHub.new(); world.add_child(hub); hub.configure(catalog,pool); world.set_meta("native_reference_hub",hub)
	var template=pool.model_template(results[job]); check(template!=null,"Original placeable template publishes")
	if template==null: world.close(); hub.close(); assets.close(); world.free(); quit(1); return
	var model=template.create(); world.add_child(model)
	deadline=Time.get_ticks_msec()+15000
	while not hub.ready() and Time.get_ticks_msec()<deadline: await process_frame
	var emitters: Array=model.find_children("native_emitter","Node3D",true,false)
	var lit: Array=emitters.filter(func(e):return e.effective_flags()&8 and str(e.original_properties.get("chunkname","")).is_empty() and str(e.original_properties.get("update",""))=="Explosion")
	check(not lit.is_empty(),"Actual original model contains a lit explosion emitter")
	for e in lit: e.detonate()
	for frame in 16: group.step(1.0/60.0); await process_frame
	check(group.failure.is_empty() and not group.closed and group.fallback_reasons.is_empty(),"Actual original effects remain on the native grouped path")
	check(int(group.last.scene_vertices)>0 and group.scene_batches.last_batches>0,"A real original explosion actually draws lit GPU instances")
	# Compare the existing renderer against the SAME original state/corners.
	# This is cold test-only inspection; production never exports these arrays.
	world.process_mode=Node.PROCESS_MODE_DISABLED; group.effect.enabled=false
	var references: Array=[]; var vertices:=0
	for e in lit:
		var packet: Dictionary=e.native_owner.call("dispatch",6,{"factor":e.source.global_basis.get_scale().x,"camera":e.camera_quaternion(),"tint":[1.0,1.0,1.0],"capacity":0},{})
		check(not packet.has("error") and int(packet.count)>0,"Original native source exports a nonempty reference range")
		var surface:=Surface.new(); world.add_child(surface); surface.configure(e.original_texture,1,int(e._state.blendMode68)!=0,bool(e._state.twoSided),true)
		var b: Array=packet.bounds
		check(surface.apply_frame(1,1,int(packet.count),int(packet.capacity),packet.positions,packet.attributes,AABB(Vector3(b[0],b[1],b[2]),Vector3(b[3],b[4],b[5]))),"Existing lit renderer publishes the exact original explosion")
		# Match the pooled material's sorted pass relative to the placeable's
		# own transparent meshes, just as the all-mode pixel fixture does.
		surface.draw_material.render_priority=clampi(references.size()-128,-128,127)
		references.append(surface); vertices+=int(packet.count)
	for surface in group.scene_batches.surfaces.values(): surface.hide()
	await freeze(); var baseline:=root.get_texture().get_image()
	for surface in references: surface.hide()
	for surface in group.scene_batches.surfaces.values(): surface.visible=surface.vertex_count>0
	await freeze(); var candidate:=root.get_texture().get_image()
	var difference:=compare_images(baseline,candidate,"Real plc_i05 original explosion, its actual texture/atlas and scene light/fog")
	check(vertices==group.scene_batches.last_vertices,"Every active original lit vertex reaches the GPU batch")
	var summary: Dictionary=group.snapshot(); var prefix: String=str(args.report).trim_suffix(".json"); baseline.save_png(prefix+".baseline.png"); candidate.save_png(prefix+".candidate.png")
	for surface in references: surface.retire()
	model.retire(); world.close(); hub.close(); assets.close(); world.free(); assets.free(); await freeze(); pool.clear()
	var file:=FileAccess.open(args.report,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"resource":"plc_i05","difference":difference,"vertices":vertices,"group":summary,"network_connections":0,"scope":"Real installed original model/texture/channels and actual native detonation, comparing exact source state against the existing lit renderer under scene light and fog. Complements authoritative local effect tests; not a server-triggered placeable destruction receipt or full-gameplay acceptance."},"\t")); file.close(); quit(0 if failures.is_empty() else 1)
