extends "res://tests/native_physical_fog_endpoints_test.gd"
# New composed GPU path: physical resolver + reducer + exact endpoints.
# Source geometry, camera and collection tokens are explicit fixture controls.
const Palette=preload("res://systems/native_render/native_light_palette.gd")
const Gamma=preload("res://systems/native_render/native_gamma.gd")
var images: Array=[]
var observations: Array=[]
func _initialize() -> void:
	if DisplayServer.get_name()!="headless":
		for index in DisplayServer.get_screen_count():
			if index!=DisplayServer.get_primary_screen():root.current_screen=index;break
	run.call_deferred()
func floor_bundle(name_value: String,offset: float=0.) -> Dictionary:
	var value:=bundle(name_value);value.value.nodes[0].position=[offset,0.,0.]
	value.value.nodes[0].mesh.vertices=PackedFloat32Array([-.5,-.5,0,.5,-.5,0,.5,.5,0,-.5,.5,0])
	value.value.nodes[0].mesh.normals=PackedFloat32Array([0,0,1,0,0,1,0,0,1,0,0,1])
	return value
func capture_pixels(name_value: String) -> Image:
	Palette.flush()
	for index in 5:await process_frame
	await RenderingServer.frame_post_draw
	var image:=root.get_texture().get_image();var file:=output.get_base_dir().path_join(name_value+".png")
	check(image.save_png(file)==OK,"Saved composed physical fog pixels "+name_value);images.append(file);return image
func sample(image: Image,camera: Camera3D,point: Vector3) -> Color:
	var pixel:=camera.unproject_position(point);return image.get_pixel(roundi(pixel.x),roundi(pixel.y))
func delta(a: Color,b: Color) -> float:return absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b)
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):output=arg.substr(9)
	if output.is_empty() or FileAccess.file_exists(output):quit(2);return
	check(DisplayServer.get_name()!="headless" and root.current_screen!=DisplayServer.get_primary_screen(),"Composed functional GPU run uses current first nonprimary display")
	check(root.unfocusable and not root.has_focus() and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"Composed fixture is unfocused and pointer remains visible")
	if not failures.is_empty():finish_pixels();return
	root.size=Vector2i(960,400)
	scene=WorldPort.new();root.add_child(scene);scene.pool.native_lighting=true;scene.pool.native_surface_output=true
	scene.terrain=Terrain.new();scene.add_child(scene.terrain);scene.terrain.set_process(false)
	var environment:=WorldEnvironment.new();environment.environment=Environment.new();environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color.BLACK;environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.environment.ambient_light_color=Color.BLACK;environment.environment.tonemap_mode=Environment.TONE_MAPPER_LINEAR;scene.add_child(environment)
	var camera:=Camera3D.new();scene.add_child(camera);camera.position=Vector3(11.2,6,0);camera.look_at(Vector3(11.2,0,-5));camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=6.;camera.current=true
	var gamma:=Gamma.new();scene.add_child(gamma);gamma.attach(camera);gamma.effect.set_surface_output(true);gamma.set_gamma(1.2)
	resolver=Resolver.new();check(resolver.configure({"connection":8,"generation":2,"area":3},func(_value):return facts.current,2,1,1.,10.).available,"Actual approved resolver/kernel bind the authored source area")
	var tile: Dictionary=resolver.register_canonical(0,0,1.,["terrain",1]);var outside: Dictionary=resolver.register_canonical(1,0,1.,["terrain",2]);var static_tile: Dictionary=resolver.register_spawn("world:33",["static",1],"static",[6.2,5.,0.],func(_context):return facts.current)
	check(tile.available and outside.available and static_tile.tile_token==tile.tile_token and outside.tile_token!=tile.tile_token,"Actual source positions associate floor/static with shared physical TileData and adjacent outside separately")
	terrain_assoc=association("terrain:0",["terrain",1],"surface");static_assoc=association("world:33",["static",1],"surface");var outside_assoc:=association("terrain:1",["terrain",2],"surface")
	var template=scene.pool.model_template(floor_bundle("fog_endpoint_floor"));var floor_model=template.create();var static_model=template.create();scene.terrain.add_child(floor_model);scene.add_child(static_model);floor_model.position=Vector3(5,0,-5);static_model.position=Vector3(6.2,0,-5);scene.terrain.instances[0]=floor_model;scene.instances[33]=static_model
	var floor_mesh: MeshInstance3D=floor_model.meshes[0];var static_mesh: MeshInstance3D=static_model.meshes[0];var material=static_mesh.material_override;var mesh: Mesh=static_mesh.mesh;var shader: Shader=material.shader;var alpha: float=material.albedo_color.a;var shadow:=static_mesh.cast_shadow
	var batcher:=Batches.new();scene.terrain.add_child(batcher);scene.terrain.batcher=batcher
	var prepared: Dictionary=batcher.prepare(floor_bundle("fog_endpoint_batch",2.4),scene.pool,[{"index":0,"position":Vector3(5,0,-5),"rotation_y":0.,"model":"fog_endpoint_batch"},{"index":1,"position":Vector3(15,0,-5),"rotation_y":0.,"model":"fog_endpoint_batch"}])
	for group in prepared.get("groups",[]):batcher.publish(group)
	check(batcher.owners.size()==1 and batcher.owners[0] is MultiMeshInstance3D,"Actual existing batch factory creates two source-indexed terrain slots")
	var geometry: MultiMeshInstance3D=batcher.owners[0];var data: MultiMesh=geometry.multimesh
	check(floor_mesh.material_override==material and geometry.material_override==material,"Ordinary floor/static and MultiMesh share genuine immutable native-surface material")
	material.native_world_fog=false;material.set_shader_parameter("native_emission_enabled",true);material.set_shader_parameter("native_emission",Vector3(.03,.08,.15));material.set_shader_parameter("native_surface_fog_color",Vector3(.7,.4,.2));material.set_shader_parameter("native_surface_fog_range",Vector2(1,16));material.set_shader_parameter("native_surface_fog_params",Vector3.ZERO);Palette.ambient(Vector3.ZERO)
	endpoints=Endpoints.new();check(endpoints.configure(scene,scope,func(value):return value==scope and facts.current,resolver.association_current).available,"Composed GPU adapter binds exact World scope and actual resolver guard")
	fog=Reducer.new();check(fog.configure(scope,func(value):return value==scope and facts.current).available and fog.register_tile(tile.tile_token,tile.tile_lifetime).available and fog.register_tile(outside.tile_token,outside.tile_lifetime).available,"Root physical reducer owns the two actual physical TileData identities")
	var floor_end: Dictionary=endpoints.terrain_mesh("floor",terrain_assoc,0,floor_model,floor_mesh);var static_end: Dictionary=endpoints.static_world_mesh("static",static_assoc,33,static_model,static_mesh);var batch_end: Dictionary=endpoints.terrain_batch("batch0",terrain_assoc,0,batcher);var outside_end: Dictionary=endpoints.terrain_batch("batch1",outside_assoc,1,batcher)
	check(adopt(floor_end,tile) and adopt(static_end,tile) and adopt(batch_end,tile) and adopt(outside_end,outside),"Actual reducer adopts guarded real floor/static/batch endpoints")
	var baseline:=await capture_pixels("physical-default-one")
	fog.receive_fog(tile.tile_token,tile.tile_lifetime,true)
	var pending:=await capture_pixels("physical-incomplete-default-one");check(pending.get_data()==baseline.get_data(),"Incomplete participant binding leaves every physical endpoint at byte-identical default1")
	check(fog.set_publish_ready(tile.tile_token,tile.tile_lifetime,true).available,"Explicit complete participant certificate enables only the shared physical TileData")
	var points: Array=[Vector3(5,0,-5),Vector3(6.2,0,-5),Vector3(7.4,0,-5)]
	for value in [0.,.5,1.]:
		if value>0:
			fog.receive_fog(tile.tile_token,tile.tile_lifetime,false);fog.advance_collected(PackedInt64Array([tile.tile_token]),.125 if value==.5 else .25)
		var image:=await capture_pixels("physical-factor-"+str(int(value*10)));var colors: Array=[]
		for point in points:colors.append(sample(image,camera,point))
		check(delta(colors[0],colors[1])<.008 and delta(colors[0],colors[2])<.008,"One physical factor agrees in actual floor/static/MultiMesh GPU pixels "+str(value))
		check(sample(image,camera,Vector3(17.4,0,-5))==sample(baseline,camera,Vector3(17.4,0,-5)) and data.get_instance_custom_data(1)==Color(1,1,0,0),"Adjacent outside slot retains actual factor1 pixels/custom data "+str(value))
		check(factor(floor_mesh)==value and factor(static_mesh)==value and data.get_instance_custom_data(0)==Color(value,1,0,0),"Uniform and actual GPU slot agree with physical reducer "+str(value))
		check(value==1. or delta(colors[0],sample(baseline,camera,points[0]))>.03,"Fogged/ramping physical factors materially change GPU pixels "+str(value))
		observations.append({"factor":value,"colors":colors,"tile":fog.tile_view(tile.tile_token,tile.tile_lifetime)})
		if value==1.:check(image.get_data()==baseline.get_data(),"Settled factor1 restores exact baseline pixels across all physical endpoints")
	check(fog.set_publish_ready(tile.tile_token,tile.tile_lifetime,false).available and fog.retire_endpoint("static",static_end.lease) and endpoints.retire("static",static_end.lease),"Retirement revokes completeness and exact old static endpoint")
	resolver.retire_part("world:33",["static",1],"surface",["surface",1]);scene.instances.erase(33);static_model.retire()
	var successor=template.create();scene.add_child(successor);successor.position=Vector3(6.2,0,-5);scene.instances[33]=successor
	var again: Dictionary=resolver.register_spawn("world:33",["static",2],"static",[6.2,5.,0.],func(_context):return facts.current);var new_assoc:=association("world:33",["static",2],"surface")
	check(again.tile_token==tile.tile_token and again.tile_lifetime==tile.tile_lifetime,"Same-ID static replacement reuses physical TileData without resetting its state")
	var fresh: Dictionary=endpoints.static_world_mesh("static-new",new_assoc,33,successor,successor.meshes[0]);check(adopt(fresh,tile) and fog.set_publish_ready(tile.tile_token,tile.tile_lifetime,true).available,"Fresh associated model adopts retained physical factor through cold endpoint")
	check(not endpoints.publish(.2,static_end.lease),"Old static lease cannot write onto same-ID successor")
	var replaced:=await capture_pixels("physical-static-readopted");check(replaced.get_data()==baseline.get_data(),"Actual static retirement/re-adoption restores exact baseline pixels")
	var transform:=data.get_instance_transform(0);var changed:=transform;changed.origin.x+=.25;data.set_instance_transform(0,changed)
	check(data.get_instance_transform(0)==changed and not endpoints.publish(.2,batch_end.lease) and batcher.tile_fog_factors[0]==1.,"Real GPU transform readback detects same-MultiMesh slot reuse before any fog write")
	data.set_instance_transform(0,transform);check(not endpoints.lease_current(batch_end.lease),"Restoring GPU slot transform cannot revive invalidated old endpoint")
	check(fog.retire_endpoint("batch0",batch_end.lease) and fog.set_publish_ready(tile.tile_token,tile.tile_lifetime,false).available and endpoints.retire("batch0",batch_end.lease),"Cold batch retirement revokes its exact reducer lease before readiness publication")
	var rebound: Dictionary=endpoints.terrain_batch("batch-rebound",terrain_assoc,0,batcher);check(adopt(rebound,tile) and fog.set_publish_ready(tile.tile_token,tile.tile_lifetime,true).available,"Rebound batch endpoint adopts retained settled physical state")
	var final:=await capture_pixels("physical-batch-readopted");check(final.get_data()==baseline.get_data(),"Rebinding real GPU slot restores exact scene pixels")
	# Successor regression: failed publication must retain an explicit retry,
	# rather than certify unchanged publish_ready=false with stale survivors.
	fog.receive_fog(tile.tile_token,tile.tile_lifetime,true);fog.receive_fog(tile.tile_token,tile.tile_lifetime,false);fog.advance_collected(PackedInt64Array([tile.tile_token]),.125)
	var retry_half:=await capture_pixels("physical-retry-half")
	check(factor(floor_mesh)==.5 and factor(successor.meshes[0])==.5 and data.get_instance_custom_data(0)==Color(.5,1,0,0),"Retry regression begins with all actual current endpoints at retained half factor")
	scene.terrain.instances.erase(0)
	var interrupted: Dictionary=fog.set_publish_ready(tile.tile_token,tile.tile_lifetime,false)
	check(not interrupted.available and fog.tile_view(tile.tile_token,tile.tile_lifetime).get("publication_pending",false),"Stale-first failed fallback retains explicit pending publication")
	check(factor(successor.meshes[0])==.5 and data.get_instance_custom_data(0)==Color(.5,1,0,0),"First stale endpoint interrupts fallback before later two current endpoints write")
	check(fog.retire_endpoint("floor",floor_end.lease) and endpoints.retire("floor",floor_end.lease),"Exact stale-first endpoint is removed before retrying pending fallback")
	check(fog.set_publish_ready(tile.tile_token,tile.tile_lifetime,false).available and not fog.tile_view(tile.tile_token,tile.tile_lifetime).get("publication_pending",true),"Explicit same-false setter retries and completes pending publication")
	var retry_current:=await capture_pixels("physical-retry-current-fallback")
	check(factor(successor.meshes[0])==1. and data.get_instance_custom_data(0)==Color(1,1,0,0) and sample(retry_current,camera,points[1])==sample(baseline,camera,points[1]) and sample(retry_current,camera,points[2])==sample(baseline,camera,points[2]),"Both surviving current endpoints actually reach default1 uniforms and pixels after retry")
	scene.terrain.instances[0]=floor_model
	var floor_rebound: Dictionary=endpoints.terrain_mesh("floor-rebound",terrain_assoc,0,floor_model,floor_mesh)
	check(adopt(floor_rebound,tile) and factor(floor_mesh)==1.,"Fresh floor endpoint adopts incomplete default1 without reviving old lease")
	var retry_adopted:=await capture_pixels("physical-retry-floor-readopted");check(retry_adopted.get_data()==baseline.get_data(),"Readopting missing participant completes byte-identical default1 fallback")
	check(fog.set_publish_ready(tile.tile_token,tile.tile_lifetime,true).available,"Fresh complete certificate restores retained physical factor after retry")
	var retry_complete:=await capture_pixels("physical-retry-complete-half");check(retry_complete.get_data()==retry_half.get_data(),"Completeness restoration reproduces exact retained half-factor pixels")
	fog.advance_collected(PackedInt64Array([tile.tile_token]),.25)
	var retry_restored:=await capture_pixels("physical-retry-restored-one");check(retry_restored.get_data()==baseline.get_data(),"Retry sequence ends with exact original baseline1 pixels")
	check(successor.meshes[0].material_override==material and floor_mesh.material_override==material and geometry.material_override==material and successor.meshes[0].mesh==mesh and material.shader==shader and material.albedo_color.a==alpha and successor.meshes[0].cast_shadow==shadow and successor.renderer_alpha==null,"Composed path retains exact shared material/shader/mesh/alpha/shadow identities")
	var gamma_state: Dictionary=gamma.snapshot();check(gamma_state.failure.is_empty() and gamma_state.passes>0 and gamma_state.gamma==1.2,"Approved native-surface/gamma1.2 compositor executes")
	check(root.current_screen!=DisplayServer.get_primary_screen() and root.unfocusable and not root.has_focus() and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"GPU run preserves nonprimary/unfocused/uncaptured policy")
	finish_pixels()
func finish_pixels() -> void:
	var endpoint_state: Dictionary=endpoints.snapshot() if endpoints!=null else {};var fog_state: Dictionary=fog.snapshot() if fog!=null else {};var resolver_state: Dictionary=resolver.snapshot() if resolver!=null else {}
	if fog!=null:fog.close()
	if endpoints!=null:endpoints.close()
	if resolver!=null:resolver.close()
	if is_instance_valid(scene):scene.close();scene.free()
	fog=null;endpoints=null;resolver=null;scene=null
	await process_frame;await process_frame
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"images":images,"observations":observations,"endpointState":endpoint_state,"fogState":fog_state,"resolverState":resolver_state,"serverConnections":0,"nativeBuilds":0,"performanceClaim":false,"scope":"Actual isolated TileData resolver + physical reducer + cold endpoint adapter, genuine pooled ordinary terrain/static Placements and existing terrain MultiMesh. Explicit World ownership/source guards, authored floor geometry/source area/camera and collected-token inputs. No opened production world, LOS, original-room, server or FPS parity claim."}
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(result,"  "));print("PHYSICAL_FOG_ENDPOINT_PIXELS ",checks," checks ",failures.size()," failures");quit(0 if result.success else 1)
