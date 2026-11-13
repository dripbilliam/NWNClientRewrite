extends "res://tests/native_parity_highlight_registry_actor_render_test.gd"
# Exact retained Fleshwarp NPC model batch, not a recreated room or live login.
const Target=preload("res://tools/native_parity/visibility/reveal_fade.gd")
const Alpha=preload("res://tools/native_parity/visibility/alpha_program.gd")
const Surface=preload("res://systems/native_render/native_surface_state.gd")
const Lamp=preload("res://systems/native_render/model_point_light.gd")
var output:=""
var material_endpoints: Array=[]

func digest(bytes: PackedByteArray) -> String:
	var context:=HashingContext.new();context.start(HashingContext.HASH_SHA256);context.update(bytes);return context.finish().hex_encode()
func endpoints() -> Array:
	var rows: Array=[]
	for actor in actors:
		for mesh in actor.meshes:
			var material=mesh.material_override
			rows.append([mesh.get_instance_id(),material.get_instance_id(),material.shader.get_instance_id(),material.albedo_texture.get_instance_id() if material.albedo_texture!=null else 0,mesh.material_overlay])
	return rows
func save_phase(label: String) -> Image:
	var value:=root.get_texture().get_image();value.save_png(output.trim_suffix(".json")+"-"+label+".png");return value
func finish(value: Dictionary,code: int) -> void:
	value.merge({"success":failures.is_empty(),"checks":checks,"failures":failures,"performanceClaim":false,"scope":"Historical named Claddath Fleshwarp Monstrosity single-model batch c_goldem; actual V5 Actor/Registry/native controller/compiled bounds, enhanced native-surface output. Received visibility triple exercised through native target helper with explicit fixture PlayerInfo context. Room/camera, exact received appearanceID and historical per-texture hashes are unavailable; no live or full-room pixel parity/FPS claim."})
	var file:=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify(value,"  ")+"\n");file.close();quit(code if failures.is_empty() else 1)
func run() -> void:
	var install:="";var expected_screen:=0;var asset_only:=false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):output=arg.substr(9)
		elif arg.begins_with("--install="):install=arg.substr(10)
		elif arg.begins_with("--expected-screen="):expected_screen=int(arg.substr(18))
		elif arg=="--asset-only":asset_only=true
	if output.is_empty() or install.is_empty() or FileAccess.file_exists(output):quit(2);return
	retained_highlight_extension=load("res://native/highlight_geometry.gdextension")
	retained_extension=load("res://native/particle_kernel.gdextension")
	check(retained_extension!=null and retained_highlight_extension!=null and ClassDB.class_exists("NwnModelPoseStorage") and ClassDB.class_exists("NwnHighlightGeometry"),"Exact existing V5 pose and highlight kernels load without a rebuild")
	var catalog:=Catalog.new();check(catalog.mount_install(install) and catalog.mount_directory("C:/Users/Niflheim/Documents/Neverwinter Nights.0/override",10000000),"Original installation and current profile mount read-only")
	var original: PackedByteArray=catalog.get_resource("c_goldem",2002)
	check(original.size()==517418 and digest(original)=="2a930d200205e26ae7ddbf0f875c3dc2d73637dc7fc174684ccfe3e2e9ab2082","Exact original model hash/byte size matches recovered single-model Fleshwarp batch")
	var service:=Assets.new();root.add_child(service);service.configure(catalog);service.maximum_workers=1;service.cache_directory=output.get_base_dir().path_join("asset-cache");service.completed.connect(func(id,result):completed[id]=result)
	var request:=service.request("c_goldem",2002,"actor-model",{"relevant_tracks":true});var deadline:=Time.get_ticks_msec()+30000
	while not completed.has(request) and Time.get_ticks_msec()<deadline:await process_frame
	var bundle: Dictionary=completed.get(request,{})
	check(not bundle.is_empty() and str(bundle.get("error","unfinished")).is_empty(),"Actual original Demonflesh model prepares through V5 AssetService: "+str(bundle.get("error")))
	if bundle.is_empty() or not str(bundle.get("error","")).is_empty():service.close();service.free();finish({},1);return
	var sources:={"model":"c_goldem","raw_sha256":digest(original),"bundle_sha256":bundle.sha256,"textures":{},"nodes":bundle.value.nodes.size(),"historical_actor_ids":[2147620731,2147620741],"historical_area":2147618612,"historical_appearance_id":null,"catalog_matching_appearance_row":468}
	for name in bundle.get("textures",{}):sources.textures[name]=bundle.textures[name].get("sha256")
	check(not sources.textures.is_empty(),"Original prepared texture dependencies are retained")
	var target:=Target.target_alpha({"is_creature":true,"revealed":1,"player_info_present":true,"matching_perception_present":true,"perception":[1,0,0]})
	check(target.available and target.alpha_word==Alpha.word(.5) and target.reason=="native_detected_perception","Retained received visibility triple selects native half-opacity with explicit fixture PlayerInfo context")
	if asset_only:
		service.close();service.free();await process_frame;finish({"asset_only":true,"sources":sources,"target":target},0);return
	var window:={"screen":root.current_screen,"primary":DisplayServer.get_primary_screen(),"focused":root.has_focus(),"unfocusable":root.unfocusable,"mouse":Input.mouse_mode}
	check(window.screen==expected_screen and window.screen!=window.primary and not window.focused and window.unfocusable and window.mouse==Input.MOUSE_MODE_VISIBLE,"Verified nonprimary window remains unfocused and without pointer capture")
	var world:=Node3D.new();root.add_child(world);world.set_meta("native_enhanced_lighting",true);world.set_meta("native_surface_output",true);Surface.bind(world)
	var environment:=WorldEnvironment.new();environment.environment=Environment.new();environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color(.025,.03,.05);world.add_child(environment)
	var camera:=Camera3D.new();world.add_child(camera);camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=16;camera.position=Vector3(9,11,18);camera.look_at(Vector3(0,2,0));camera.current=true
	Palette.ambient(Vector3.ONE);var lamp:=Lamp.new();lamp.set_meta("native_enhanced_light",true);world.add_child(lamp);lamp.position=Vector3(0,5,3);lamp.configure({"color":[.9,.7,.4],"radius":20.,"multiplier":1.});Palette.flush()
	var pool:=Pool.new();pool.native_lighting=true;pool.native_surface_output=true
	var registry:=Registry.new();registry.native_highlight_enabled=true;world.add_child(registry);registry.configure_highlights(camera);registry.configure_highlight_assets(service,catalog,pool);registry.native_highlight.set_process(false)
	for index in 2:
		var actor:=Actor.new();actor.actor_alpha_enabled=true;world.add_child(actor);var id: int=[2147620731,2147620741][index]
		check(actor.install([{"bundle":bundle}],pool,id,{},0),"Actual historical Fleshwarp actor installs with original texture/clip ownership "+str(id)+": "+actor.failure)
		if actor.rigs==null:actor.retire();continue
		actor.rigs.set_process(false);actor.position=Vector3(-3.5 if index==0 else 3.5,0,0);actor.set_meta("native_selection_scope",[1,3,2147618612,id,1]);actors.append(actor);ids.append(id)
		check(actor.meshes.size()==29,"Historical per-actor29 mesh publication reproduced exactly "+str(id))
		check(actor.rigs.play_native(id,0,"cpause1",1.,0,0.),"Exact original retained idle clip cpause1 is declared and selected "+str(id))
		actor.rigs._update(0.);actor.set_renderer_alpha(Alpha.scalar(target.alpha_word),actor.renderer_alpha_model_indices())
		check(registry.register_native(id,{"id":id,"type":5,"eligible":true,"color":"#00ff00"},actor),"Ordinary native registry admits actual named NPC model "+str(id))
	check(actors.size()==2,"Both historical Fleshwarp NPCs remain installed")
	deadline=Time.get_ticks_msec()+15000
	while registry.native_highlight.texture_source.status=="loading" and Time.get_ticks_msec()<deadline:await process_frame
	check(registry.native_highlight.bounds.texture_ready and registry.native_highlight.bounds.textured_material.native_surface_output,"Borrowed original highlight DDS/TXI uses native surface transfer")
	var authentic:=true
	for actor in actors:
		for mesh in actor.meshes:
			if not mesh.material_override is ShaderMaterial or not mesh.material_override.native_surface_output or mesh.material_override.albedo_texture==null:authentic=false
	check(authentic and pool.native_lighting and pool.native_surface_output and lamp.native_slot>=0,"Every real actor material retains original texture with enhanced lighting/native surface output")
	registry.mark([],-1,false);registry.native_highlight._process(0.);update_rigs(0.);await wait_draw();var baseline:=save_phase("baseline");material_endpoints=endpoints()
	registry.mark(ids,-1,true);registry.native_highlight._process(0.);await wait_draw();var held:=save_phase("held-tab")
	check(held.get_data()!=baseline.get_data() and registry.native_highlight.bounds.stats.vertices>0,"Held Tab produces visible real-model highlight pixels and bounds")
	check(alpha_matches() and endpoints()==material_endpoints,"Tab retains half-opacity and identical original material/shader/texture objects")
	var writes: int=registry.native_highlight.stats.channel_writes;var stable:=true
	for frame in 12:
		update_rigs(0.);registry.mark(ids,-1,true);registry.native_highlight._process(0.);await wait_draw()
		if root.get_texture().get_image().get_data()!=held.get_data():stable=false
	check(stable and registry.native_highlight.stats.channel_writes==writes,"Held Tab has exact stable Fleshwarp pixels and no repeated channel writes at fixed native pose/pulse")
	check(alpha_matches() and endpoints()==material_endpoints,"Held Tab never rebuilds original materials or changes translucent alpha")
	registry.mark(ids,ids[0],true);registry.native_highlight._process(0.);await wait_draw();save_phase("hover-tab")
	check(actors[0].actor_alpha.models[0].vector_active[1]==1 and actors[0].actor_alpha.models[0].vector_active[2]==1,"Hover and held Tab coexist on actual Fleshwarp model")
	registry.mark(ids,ids[0],false);registry.native_highlight._process(0.);await wait_draw();save_phase("release-hover")
	check(actors[0].actor_alpha.models[0].vector_active[2]==0 and actors[0].actor_alpha.models[0].vector_active[1]==1 and alpha_matches(),"Tab release clears only Tab and preserves hovered translucent creature")
	registry.mark([],-1,false);registry.native_highlight._process(0.);await wait_draw();var released:=save_phase("released")
	check(released.get_data()==baseline.get_data(),"Clearing hover after Tab release restores exact original Fleshwarp pixels")
	check(endpoints()==material_endpoints and alpha_matches(),"Release preserves original texture/material/shader identities and half-opacity")
	var before_pose: Array=[]
	for node in actors[0].rigs.entities[ids[0]].nodes:before_pose.append(node.transform)
	registry.mark(ids,-1,true);var animated_alpha_ok:=true
	for frame in 24:
		update_rigs(1./60.);registry.mark(ids,-1,true);registry.native_highlight._process(1./60.)
		if not alpha_matches() or endpoints()!=material_endpoints:animated_alpha_ok=false
		await process_frame
	var changed:=false
	for index in before_pose.size():
		if before_pose[index]!=actors[0].rigs.entities[ids[0]].nodes[index].transform:changed=true
	check(changed and animated_alpha_ok,"Exact retained idle clip animates physical Parts while alpha/material ownership stays stable under Tab")
	await wait_draw();save_phase("animated-tab")
	var final_stats:=registry.highlight_snapshot();registry.mark([],-1,false);registry.native_highlight.close();registry.free()
	for actor in actors:actor.retire()
	service.close();service.free();pool.clear();world.free();await process_frame;await process_frame
	finish({"asset_only":false,"window":window,"sources":sources,"target":target,"material_endpoint_count":material_endpoints.size(),"held_pixel_stable":stable,"highlight":final_stats},0)
