extends "res://tests/native_parity_bridge_world_motion_test.gd"
# Dedicated offline presentation fixture. The 3-piece arrangement is authored;
# both original bridge resources, textures and the support/motion path are real.
const Actor=preload("res://systems/native_render/actor_instance.gd")
const Assets=preload("res://systems/native_data/asset_service.gd")
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Palette=preload("res://systems/native_render/native_light_palette.gd")
const Gamma=preload("res://systems/native_render/native_gamma.gd")
var visual_observations: Array=[]
var inspect_only:=false
var completed: Dictionary={}
func ready_asset(service: Node,name: String,decoder: String) -> Dictionary:
	var request: int=service.request(name,2002,decoder,{"relevant_tracks":true} if decoder=="actor-model" else {})
	var deadline:=Time.get_ticks_msec()+20000
	while not completed.has(request) and Time.get_ticks_msec()<deadline:await process_frame
	return completed.get(request,{"error":"Preparation did not complete"})
func render_wait() -> void:
	Palette.flush()
	for frame in 6:await process_frame
	await RenderingServer.frame_post_draw
func original_feet(actor) -> Array:
	var result: Array=[]
	for mesh in actor.meshes:
		var facts: Dictionary=mesh.get_meta("native_mesh_source",{})
		if not "foot" in str(facts.get("part_name","")).to_lower():continue
		var low:=INF;var point:=Vector3.ZERO
		for surface_index in mesh.mesh.get_surface_count():
			var arrays: Array=mesh.mesh.surface_get_arrays(surface_index)
			for vertex: Vector3 in arrays[Mesh.ARRAY_VERTEX]:
				var world: Vector3=mesh.global_transform*vertex
				if world.y<low:low=world.y;point=world
		result.append({"part":facts.part_name,"point":point,"local_bottom":low-actor.global_position.y,"has_skin":not mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_BONES].is_empty() if mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_BONES]!=null else false})
	return result
func run() -> void:
	var manifest_path:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):output=arg.substr(9)
		elif arg.begins_with("--assets-manifest="):manifest_path=arg.substr(18)
		elif arg=="--inspect":inspect_only=true
	if output.is_empty() or manifest_path.is_empty() or FileAccess.file_exists(output):quit(2);return
	retained_extension=load("res://native/particle_kernel.gdextension")
	check(retained_extension!=null and ClassDB.class_exists("NwnSceneIndex"),"Pinned existing native scene and model storage DLL loads without rebuild")
	var window: Dictionary={}
	if not inspect_only:
		var primary:=DisplayServer.get_primary_screen();var secondary:=-1
		for screen in DisplayServer.get_screen_count():
			if screen!=primary:secondary=screen;break
		if secondary>=0 and root.current_screen!=secondary:root.current_screen=secondary
		await process_frame
		window={"screen":root.current_screen,"primary":primary,"first_nonprimary":secondary,"focused":root.has_focus(),"unfocusable":root.unfocusable,"mouse":Input.get_mouse_mode()}
		check(secondary>=0 and root.current_screen==secondary and not root.has_focus() and root.unfocusable and Input.get_mouse_mode()==Input.MOUSE_MODE_VISIBLE,"Actual bridge pixels stay first nonprimary/unfocused without pointer capture")
		if secondary<0:quit(2);return
	var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	var catalog:=Catalog.new();check(catalog.mount_install("C:/Users/Niflheim/Desktop/Tools/Local Tools/FullDecomp/NwnRootInstall") and catalog.mount_directory(manifest.directory,10000000),"Original installed texture/actor providers and verified bridge directory mount read-only")
	var service:=Assets.new();root.add_child(service);service.configure(catalog);service.maximum_workers=1;service.cache_directory=output.get_base_dir().path_join("prepared");service.completed.connect(func(id,result):completed[id]=result)
	var bundles: Dictionary={};var source_bytes: Dictionary={};var dependencies: Dictionary={}
	for identity in manifest.files:
		var result: Dictionary=await ready_asset(service,identity.name,"static-model")
		check(str(result.get("error","missing")).is_empty() and result.get("sha256")==identity.sha256,identity.name+": original MDL prepares with genuine installed textures and exact received model identity")
		if not str(result.get("error","")).is_empty():continue
		bundles[identity.name]=result;source_bytes[identity.name]=var_to_bytes(result.value);dependencies[identity.name]=result.get("dependencies",[])
	var goblin: Dictionary=await ready_asset(service,"c_goblina","actor-model")
	check(str(goblin.get("error","missing")).is_empty(),"Original installed goblin actor prepares with its original texture/animation dependencies")
	if bundles.size()!=2 or not str(goblin.get("error","")).is_empty():
		service.close();service.free();write_result({"dependencies":dependencies,"preparation_errors":failures});return
	var world=make_world(71,77)
	world.pool.native_lighting=true;world.pool.native_surface_output=true;world.set_meta("native_surface_output",true)
	preload("res://systems/native_render/native_surface_state.gd").bind(world)
	Palette.ambient(Vector3(0.75,0.75,0.75))
	var pieces: Array=[]
	for placement in [{"name":"twh_udbridge_mai","y":20.0,"rotation":0.0},{"name":"twh_udbridge_end","y":10.0,"rotation":PI},{"name":"twh_udbridge_end","y":30.0,"rotation":0.0}]:
		var template=world.pool.model_template(bundles[placement.name]);check(template!=null,"Original textured bridge template publishes "+str(placement))
		if template==null:continue
		var instance=template.create();world.terrain.add_child(instance);instance.position=Vector3(10,11,-placement.y);instance.rotation.y=placement.rotation;world.terrain.instances[str(pieces.size())]=instance;world.terrain.collision_index.put(instance);pieces.append(instance)
	var columns: Array=[];var previous:=12.88
	for at in 59:
		var candidate:=Vector3(10,5.5+at*0.5,previous)
		var support: Dictionary=world.client_support_scene.query(candidate,previous)
		columns.append({"at":[candidate.x,candidate.y,candidate.z],"support":support})
		check(support.get("available",false) and support.get("branch","") in ["original","negative_seam","positive_seam"] and float(support.get("position",Vector3.ZERO).z)>12.5,"Original bridge entry/deck/exit has actual MDL support atY"+str(candidate.y))
		if support.get("available",false):previous=support.position.z
	var actor_parts: Array=[]
	for node in goblin.value.nodes:
		if "foot" in str(node.name).to_lower():actor_parts.append({"name":node.name,"position":node.position})
	if inspect_only:
		var state:={"dependencies":dependencies,"actor_sha256":goblin.sha256,"actor_parts":actor_parts,"actor_clips":goblin.value.rig_asset.clips.map(func(clip):return clip.name),"columns":columns,"source_unchanged":source_equal(bundles,source_bytes)}
		world.close();await process_frame;await process_frame;world.free();service.close();service.free();await process_frame;write_result(state);return
	var scene:=Node3D.new();root.add_child(scene)
	var environment:=WorldEnvironment.new();environment.environment=Environment.new();environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color(0.025,0.035,0.055);environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.environment.ambient_light_color=Color.BLACK;environment.environment.tonemap_mode=Environment.TONE_MAPPER_LINEAR;scene.add_child(environment)
	scene.add_child(Palette.new())
	var camera:=Camera3D.new();scene.add_child(camera);camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=8;camera.current=true
	var gamma:=Gamma.new();scene.add_child(gamma);gamma.attach(camera);gamma.effect.set_surface_output(true);gamma.set_gamma(1.2)
	var initial: Dictionary=world.client_support_scene.query(Vector3(10,6,12.88),12.88)
	var row:=source(world,1,initial.position);row.replicated.walkRate=5000;row.replicated.runRate=5000;var canonical:=var_to_bytes(row)
	world.receive([row],7)
	var actor:=Actor.new();world.add_child(actor)
	check(actor.install([{"bundle":goblin}],world.pool,7,{"0":{"0":"pause1","4":"walk"}},0),"Actual original goblin physical rig installs as controlled World actor")
	actor.rigs.set_process(false);actor.rigs._update(0.0);world.instances[7]=actor;world.installed[7]=world.desired[7].key;world.apply_pose(7)
	# Original received path target Z remains zero: only the production client
	# support owner supplies raised prediction/display; no canonical Z is edited.
	received_path(world,Vector3(10,34,0),1)
	var checkpoints: Array=[{"name":"entry","y":6.1},{"name":"deck","y":20.0},{"name":"exit","y":33.5}];var next:=0
	for tick in 400:
		var prior: float=world.motion.objects[7].position.z
		step(world,0.02);actor.rigs._update(0.0)
		var predicted: Vector3=world.motion.objects[7].position
		var support: Dictionary=world.client_support_scene.query(predicted,prior)
		check(support.get("available",false) and near(predicted.z,support.position.z) and predicted.z>12.5 and display_matches(world),"Actual World/Motion keeps displayed goblin foot origin on original bridge at tick"+str(tick))
		check(var_to_bytes(row)==canonical and world.desired[7].object.replicated.position==row.replicated.position,"Original authoritative received XYZ remains separate from raised prediction at tick"+str(tick))
		if next<checkpoints.size() and predicted.y>=checkpoints[next].y:
			var name: String=checkpoints[next].name
			camera.position=actor.global_position+Vector3(7,5,8);camera.look_at(actor.global_position+Vector3(0,0.7,0))
			await render_wait();var image:=root.get_texture().get_image();image.save_png(output.trim_suffix(".json")+"-"+name+".png")
			var feet:=original_feet(actor);var foot_rows: Array=[];var grounded:=0
			for foot in feet:
				var point: Vector3=foot.point;var ground: Dictionary=world.client_support_scene.query(Vector3(point.x,-point.z,point.y),predicted.z)
				var gap: float=point.y-ground.position.z if ground.get("available",false) else INF
				foot_rows.append({"part":foot.part,"vertex_world":[point.x,point.y,point.z],"support_z":ground.position.z if ground.get("available",false) else null,"gap":gap,"has_skin":foot.has_skin})
				if ground.get("available",false) and absf(gap)<0.12 and not foot.has_skin:grounded+=1
			check(feet.size()==2 and grounded>=1,"Original rigid foot vertices visibly meet the actual MDL support at "+name)
			actor.hide();await render_wait();var bare:=root.get_texture().get_image();actor.show();await render_wait();var actor_pixels:=0
			for y in image.get_height():
				for x in image.get_width():
					var color:=image.get_pixel(x,y);var backing:=bare.get_pixel(x,y)
					if maxf(absf(color.r-backing.r),maxf(absf(color.g-backing.g),absf(color.b-backing.b)))>0.04:actor_pixels+=1
			check(actor_pixels>40,"Actual textured actor has visible GPU pixels above original bridge at "+name)
			var anchor_pixel:=camera.unproject_position(actor.global_position)
			visual_observations.append({"stage":name,"tick":tick,"received":row.replicated.position.duplicate(),"received_path_target":[10,34,0],"predicted":[predicted.x,predicted.y,predicted.z],"displayed":[actor.position.x,actor.position.y,actor.position.z],"support":[support.position.x,support.position.y,support.position.z],"feet":foot_rows,"actor_pixels":actor_pixels,"foot_origin_pixel":[anchor_pixel.x,anchor_pixel.y],"original_actor_sha256":goblin.sha256})
			next+=1
		if predicted.y>=33.9:break
	check(next==3,"Actual original actor reaches entry, deck and exit graphical checkpoints")
	check(world.surface.height_calls==0,"Poison navigation WOK height never supplies bridge display Z")
	check(source_equal(bundles,source_bytes),"Original decoded bridge geometry/render flags remain unchanged")
	camera.position=Vector3(33,34,12);camera.look_at(Vector3(10,11,-20));camera.size=39
	await render_wait();root.get_texture().get_image().save_png(output.trim_suffix(".json")+"-overview.png")
	var gamma_state:=gamma.snapshot();check(gamma_state.failure.is_empty() and int(gamma_state.passes)>0,"Real native surface compositor renders original bridge and actor textures")
	var state:={"window":window,"dependencies":dependencies,"actor_sha256":goblin.sha256,"actor_parts":actor_parts,"columns":columns,"visual_observations":visual_observations,"gamma":gamma_state,"poison_wok_calls":world.surface.height_calls,"support":world.client_support_scene.snapshot(),"source_unchanged":source_equal(bundles,source_bytes)}
	world.close();await process_frame;await process_frame;world.free();scene.free();service.close();service.free();await process_frame;await process_frame;write_result(state)
func source_equal(bundles: Dictionary,original: Dictionary) -> bool:
	for name in bundles:
		if var_to_bytes(bundles[name].value)!=original[name]:return false
	return true
func write_result(details: Dictionary) -> void:
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"details":details,"serverConnections":0,"nativeBuilds":0,"performanceClaim":false,"inspectOnly":inspect_only,"scope":"Two exact retained original bridge MDLs, genuine installed fallback textures and original goblin, actual World receive/movement/Motion/support/display. Explicit authored3-piece placement; readiness/navigation/animation ports remain fixture scaffolding. Cached live ttu01_trim override bytes unavailable, so installed trim is declared fallback. No actual live bridge pose, full room/native screenshot comparison, server movement or FPS claim."}
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(result,"  ")+"\n");print("BRIDGE_SUPPORT_PIXELS ",checks," checks ",failures.size()," failures");quit(0 if failures.is_empty() else 1)
