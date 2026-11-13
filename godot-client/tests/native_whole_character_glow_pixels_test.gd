extends "res://tests/native_parity_highlight_registry_actor_render_test.gd"
# User-requested visual policy candidate, not original native per-Part parity.
const Stream=preload("res://systems/native_render/creature_stream.gd")
const Gff=preload("res://systems/native_data/gff_document.gd")
const BicVisual=preload("res://systems/native_data/bic_visual.gd")
const Gamma=preload("res://systems/native_render/native_gamma.gd")
const Surface=preload("res://systems/native_render/native_surface_state.gd")
const Lamp=preload("res://systems/native_render/model_point_light.gd")
var output:=""
var scene: Node3D
var service
var pc_stream
var pool
var registry
var camera: Camera3D
var sources: Dictionary={}
var captures: Array=[]
var diagnostics: Array=[]
var desired_alpha: Dictionary={}
var scope_alive:=true

func _initialize() -> void:
	if DisplayServer.get_name()!="headless":
		for index in DisplayServer.get_screen_count():
			if index!=DisplayServer.get_primary_screen():root.current_screen=index;break
	run.call_deferred()
func hash_bytes(bytes: PackedByteArray) -> String:
	var hash:=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(bytes);return hash.finish().hex_encode()
func snapshot_materials() -> Array:
	var value: Array=[]
	for actor in actors:
		if not is_instance_valid(actor) or actor.retired:continue
		for mesh in actor.meshes:
			var material=mesh.material_override;var tangents: Array=[]
			for surface in mesh.mesh.get_surface_count():
				var arrays: Array=mesh.mesh.surface_get_arrays(surface);tangents.append(arrays[Mesh.ARRAY_TANGENT])
			value.append([str(mesh.get_instance_id()),str(mesh.mesh.get_instance_id()),str(material.get_instance_id()),str(material.shader.get_instance_id()),str(material.albedo_texture.get_instance_id()) if material.albedo_texture!=null else "",mesh.material_overlay,hash_bytes(var_to_bytes(tangents))])
	return value
func all_alpha() -> bool:
	if not alpha_matches():return false
	for actor in actors:
		if not is_instance_valid(actor) or actor.retired:continue
		if absf(float(actor.actor_alpha.models[0].alpha)-float(desired_alpha[actor.object_id]))>.000001:return false
	return true
func mark(value: Array,hover: int=-1,tab: bool=true) -> void:
	registry.mark(value,hover,tab);registry.native_highlight._process(0.)
func save_image(label: String) -> Image:
	var image:=root.get_texture().get_image();var file:=output.trim_suffix(".json")+"-"+label+".png";check(image.save_png(file)==OK,"Saved whole-character visual "+label);captures.append(file);return image
func quad_count(count: int,label: String) -> void:
	var bounds=registry.native_highlight.bounds
	check(bounds.stats.quads==count and bounds.stats.vertices==count*6 and bounds.positions.size()==count*6,label+": exactly one six-vertex quad per selected entity")
	check(bounds.batch.mesh.get_surface_count()==(1 if count>0 else 0),label+": one shared halo draw surface")
func skin_extent_sample(label: String) -> Dictionary:
	# Independent bounded diagnostic only; baked Skin meshes are never installed,
	# used as glow geometry, or included in callback-cost measurements.
	var result:={"label":label,"skin_meshes":0,"skin_vertices":0,"max_halo_overflow_pixels":0.,"actors":[]}
	for actor in actors:
		var fit: Dictionary=registry.native_highlight.bounds.diagnostic(actor.object_id)
		if not fit.get("available",false):continue
		var lo:=Vector2(INF,INF);var hi:=Vector2(-INF,-INF);var vertices:=0
		for mesh in actor.meshes:
			if mesh.skin==null:continue
			var posed: Mesh=mesh.bake_mesh_from_current_skeleton_pose();result.skin_meshes+=1
			for surface in posed.get_surface_count():
				var points: PackedVector3Array=posed.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
				for point in points:
					var projected:=camera.unproject_position(mesh.global_transform*point)
					if not projected.is_finite():continue
					lo=lo.min(projected);hi=hi.max(projected);vertices+=1
		result.skin_vertices+=vertices
		if vertices>0:
			var overflow:=maxf(0.,maxf(maxf(fit.halo_screen_min.x-lo.x,fit.halo_screen_min.y-lo.y),maxf(hi.x-fit.halo_screen_max.x,hi.y-fit.halo_screen_max.y)))
			result.max_halo_overflow_pixels=maxf(result.max_halo_overflow_pixels,overflow);result.actors.append({"id":actor.object_id,"vertices":vertices,"skin_min":lo,"skin_max":hi,"halo_min":fit.halo_screen_min,"halo_max":fit.halo_screen_max,"overflow_pixels":overflow})
	diagnostics.append(result);return result
func run() -> void:
	var install:="";var asset_only:=false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):output=arg.substr(9)
		elif arg.begins_with("--install="):install=arg.substr(10)
		elif arg=="--asset-only":asset_only=true
	if output.is_empty() or install.is_empty() or FileAccess.file_exists(output):quit(2);return
	retained_extension=load("res://native/particle_kernel.gdextension")
	check(retained_extension!=null and ClassDB.class_exists("NwnModelPoseStorage"),"Existing approved pose storage loads without native build")
	var catalog:=Catalog.new();check(catalog.mount_install(install) and catalog.mount_directory("C:/Users/Niflheim/Documents/Neverwinter Nights.0/override",10000000),"Actual original installation/profile catalog mounts read-only")
	var raw:=catalog.get_resource("c_goldem",2002);check(raw.size()==517418 and hash_bytes(raw)=="2a930d200205e26ae7ddbf0f875c3dc2d73637dc7fc174684ccfe3e2e9ab2082","Exact recovered original Claddath model identity")
	service=Assets.new();root.add_child(service);service.configure(catalog);service.maximum_workers=2;service.cache_directory=output.get_base_dir().path_join("asset-cache");service.completed.connect(func(id,result):completed[id]=result)
	var model_job: int=service.request("c_goldem",2002,"actor-model",{"relevant_tracks":true});var table_job: int=service.request("baseitems",2017,"2da",{"immutable_source":true});var floor_job: int=service.request("tic01_e01_01",2002,"actor-model",{"relevant_tracks":true});var deadline:=Time.get_ticks_msec()+60000
	while (not completed.has(model_job) or not completed.has(table_job) or not completed.has(floor_job)) and Time.get_ticks_msec()<deadline:await process_frame
	var bundle: Dictionary=completed.get(model_job,{});var table: Dictionary=completed.get(table_job,{});var floor_bundle: Dictionary=completed.get(floor_job,{})
	check(not bundle.is_empty() and str(bundle.get("error","unfinished")).is_empty() and not table.is_empty() and str(table.get("error","unfinished")).is_empty(),"Original c_goldem and active base-item table prepare through AssetService")
	check(not floor_bundle.is_empty() and str(floor_bundle.get("error","unfinished")).is_empty(),"Genuine original Prelude tile prepares as floor/depth control")
	if not failures.is_empty():finish_result(asset_only);return
	var bic:=FileAccess.get_file_as_bytes(install.path_join("data/lcv/wizard.bic"));check(hash_bytes(bic)=="00fd8475c7795069ff2be7e18130a3b6a658e98e9dfc9442c0cff6a955a06c9b","Original installed wizard BIC remains byte-identical")
	var parser:=Gff.new();var document:=parser.parse(bic,"BIC ");var visual:=BicVisual.source(document);var pc_source:=BicVisual.actor(visual,table.value)
	check(parser.failure.is_empty() and not pc_source.has("error"),"Actual native GFF/BicVisual extracts original robe/equipment PC input")
	sources={"claddath_model_sha256":bundle.sha256,"claddath_textures":{},"pc_bic_sha256":hash_bytes(bic),"pc_appearance":pc_source.get("appearance",{}).get("appearance"),"floor_model":"tic01_e01_01","floor_sha256":floor_bundle.sha256,"floor_textures":{},"historical_ids":[2147620731,2147620741],"historical_room_camera_known":false}
	for name in bundle.get("textures",{}):sources.claddath_textures[name]=bundle.textures[name].get("sha256")
	for name in floor_bundle.get("textures",{}):sources.floor_textures[name]=floor_bundle.textures[name].get("sha256")
	scene=Node3D.new();root.add_child(scene);scene.set_meta("native_enhanced_lighting",true);scene.set_meta("native_surface_output",true);Surface.bind(scene)
	pool=Pool.new();pool.native_lighting=true;pool.native_surface_output=true
	for index in 2:
		var actor:=Actor.new();actor.actor_alpha_enabled=true;scene.add_child(actor);var id: int=[2147620731,2147620741][index]
		check(actor.install([{"bundle":bundle}],pool,id,{},0),"Actual recovered Claddath Actor installs "+str(index))
		actor.rigs.set_process(false);actor.position=Vector3(-3.2 if index==0 else 3.2,0,-1);actor.set_meta("native_selection_scope",[1,3,2147618612,id,1]);actors.append(actor);ids.append(id);desired_alpha[id]=.5
		check(actor.rigs.play_native(id,0,"cpause1",1.,0,0.),"Actual retained Claddath idle clip selected")
		actor.rigs._update(0.);actor.set_renderer_alpha(.5,actor.renderer_alpha_model_indices())
	var pc_objects: Array=[]
	for index in 2:
		var copy: Dictionary=pc_source.duplicate(true);copy.id=90001+index;pc_objects.append(copy)
	pc_stream=Stream.new();scene.add_child(pc_stream);pc_stream.configure(catalog,pool,pc_objects,0,output.get_base_dir().path_join("pc-assets"),90001)
	deadline=Time.get_ticks_msec()+90000
	while not pc_stream.done and Time.get_ticks_msec()<deadline:await process_frame
	check(pc_stream.done and pc_stream.actors.size()==2 and pc_stream.stats.errors.is_empty(),"Actual CreatureStream assembles two original BIC modular PC controls")
	if pc_stream.actors.size()!=2:finish_result(asset_only);return
	for index in 2:
		var id:=90001+index;var actor=pc_stream.actors[id];pc_stream.actors.erase(id);actor.reparent(scene,false);actor.rigs.set_process(false);actor.position=Vector3(-1.4 if index==0 else 1.4,0,3);actor.set_meta("native_selection_scope",[1,3,2147618612,id,1]);actors.append(actor);ids.append(id);desired_alpha[id]=1. if index==0 else .5
		var clip_map: Dictionary=actor.rigs.entities[id].clip_map;var selected:="";var selected_code:=-1
		for code in clip_map:
			var candidate:=str(clip_map[code])
			if "walk" in candidate:selected=candidate;selected_code=int(code)
			if candidate in ["walk","cwalkf"]:break
		if selected_code>=0:actor.set_animation(selected_code,1.,true)
		check(selected_code>=0 and actor.rigs.playback_state(id,0).get("clip")==selected,"Original PC normal animation route selects actual mapped walk clip")
		actor.rigs._update(0.);actor.set_renderer_alpha(float(desired_alpha[id]),actor.renderer_alpha_model_indices())
		check(actor.rigs.stats.skin_meshes>0 and actor.rigs.stats.skin_vertices>0,"Actual original PC robe uses genuine animated Skin")
		sources["pc_control_"+str(index)]={"id":id,"models":actor.model_names.duplicate(),"skin_meshes":actor.rigs.stats.skin_meshes,"skin_vertices":actor.rigs.stats.skin_vertices,"clip":selected,"animation_code":selected_code,"alpha":desired_alpha[id]}
	pc_stream.close();pc_stream.free();pc_stream=null
	check(actors.size()==4 and all_alpha(),"Two half-alpha Claddath plus opaque/translucent PC controls retain intended primary alpha")
	if asset_only:
		var prepared_floor=pool.model_template(floor_bundle);check(prepared_floor!=null,"Actual original floor/depth model supports native pooled factory")
		if prepared_floor!=null:
			var asset_floor=prepared_floor.create();scene.add_child(asset_floor);asset_floor.process_mode=Node.PROCESS_MODE_DISABLED
			check(not asset_floor.meshes.is_empty(),"Original floor publishes genuine physical meshes before graphical acceptance");sources.floor_meshes=asset_floor.meshes.size();asset_floor.retire()
		finish_result(true);return
	check(root.current_screen!=DisplayServer.get_primary_screen() and root.unfocusable and not root.has_focus() and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"Actual functional window is nonprimary, unfocused and pointer visible")
	root.size=Vector2i(1280,900)
	var environment:=WorldEnvironment.new();environment.environment=Environment.new();environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color(.025,.03,.05);scene.add_child(environment)
	camera=Camera3D.new();scene.add_child(camera);camera.fov=45.;camera.near=.1;camera.position=Vector3(10,8,17);camera.look_at(Vector3(0,1.7,0));camera.current=true
	var gamma:=Gamma.new();scene.add_child(gamma);gamma.attach(camera);gamma.effect.set_surface_output(true);gamma.set_gamma(1.2)
	Palette.ambient(Vector3.ONE);var lamp:=Lamp.new();lamp.set_meta("native_enhanced_light",true);scene.add_child(lamp);lamp.position=Vector3(0,6,4);lamp.configure({"color":[.9,.7,.4],"radius":25.,"multiplier":1.});Palette.flush()
	registry=Registry.new();registry.native_highlight_enabled=true;registry.whole_character_highlight_enabled=true;scene.add_child(registry);registry.configure_highlights(camera);registry.configure_highlight_assets(service,catalog,pool);registry.native_highlight.set_process(false)
	check(registry.native_highlight.bounds.bind_scope({"connection":1,"generation":3,"area":2147618612},func(value):return scope_alive and value=={"connection":1,"generation":3,"area":2147618612}),"Whole-character candidate binds explicit fixture world scope")
	for actor in actors:check(registry.register_native(actor.object_id,{"id":actor.object_id,"type":5,"eligible":true,"color":"#00ff00"},actor),"Actual Registry flag route admits whole character "+str(actor.object_id))
	deadline=Time.get_ticks_msec()+15000
	while registry.native_highlight.texture_source.status=="loading" and Time.get_ticks_msec()<deadline:await process_frame
	var texture: Dictionary=registry.native_highlight.texture_source.snapshot();sources.highlight_texture=texture
	check(texture.status=="ready" and texture.resref=="fxpa_dot02" and texture.source_sha256=="4f3688a2e18273278988eb748a217b3316b59ab23bbec2dd3ac806b8acd7c8ec","Actual original fxpa_dot02 DDS and sampler are borrowed through normal texture owner")
	check(registry.native_highlight.bounds.snapshot().route=="whole-character-soft-textured-billboard" and registry.native_highlight.bounds.textured_material.native_surface_output,"Actual Registry selects new whole-character controller in enhanced native-surface mode")
	var original_materials:=snapshot_materials();mark([],-1,false);await wait_draw();var baseline:=save_image("baseline-no-floor")
	mark(ids);await wait_draw();var held:=save_image("held-no-floor");quad_count(4,"Claddath pair plus two real Skin PCs")
	check(held.get_data()!=baseline.get_data() and all_alpha() and snapshot_materials()==original_materials,"One-body glow is visible without original material/alpha/tangent changes")
	var writes: int=registry.native_highlight.stats.channel_writes;var stable:=true
	for frame in 8:
		update_rigs(0.);mark(ids);await wait_draw()
		if root.get_texture().get_image().get_data()!=held.get_data():stable=false
	check(stable and registry.native_highlight.stats.channel_writes==writes,"Held Tab has exact stable pixels and no repeated tint-channel writes")
	var opaque_pc=actors[2]
	check(opaque_pc.actor_alpha.models[0].alpha==1. and opaque_pc.set_presentation_draw_enabled(false,opaque_pc.renderer_alpha_model_indices()),"Actual opaque PC disables presentation draw independently of primary alpha1")
	mark(ids);await wait_draw();save_image("opaque-pc-draw-disabled")
	var hidden_fit: Dictionary=registry.native_highlight.bounds.diagnostic(opaque_pc.object_id)
	check(not hidden_fit.get("available",false) and "draw" in str(hidden_fit.get("reason","")),"Actual hidden-draw PC emits no whole-character halo despite alpha1")
	check(opaque_pc.actor_alpha.models[0].alpha==1. and snapshot_materials()==original_materials,"Hidden-draw suppression preserves original primary alpha/material/tangent identities")
	check(opaque_pc.set_presentation_draw_enabled(true,opaque_pc.renderer_alpha_model_indices()),"Actual opaque PC restores presentation draw")
	mark(ids);await wait_draw();check(save_image("opaque-pc-draw-restored").get_data()==held.get_data(),"Draw-state restoration reproduces exact held whole-character image")
	mark(ids,ids[0],true);await wait_draw();save_image("hover-tab")
	check(actors[0].actor_alpha.models[0].vector_active[1]==1 and actors[0].actor_alpha.models[0].vector_active[2]==1,"Pointer hover and Tab occupy existing distinct channels")
	mark(ids,ids[0],false);await wait_draw();save_image("hover-after-tab-release");quad_count(1,"Hover survives Tab release")
	check(actors[0].actor_alpha.models[0].vector_active[1]==1 and actors[0].actor_alpha.models[0].vector_active[2]==0,"Releasing Tab preserves actual hovered target")
	mark([],-1,false);await wait_draw();check(save_image("released-no-floor").get_data()==baseline.get_data(),"Releasing hover restores exact original base pixels")
	var floor_template=pool.model_template(floor_bundle);check(floor_template!=null,"Actual original Prelude floor model uses native pooled factory")
	var floor_model=floor_template.create();scene.add_child(floor_model);floor_model.position=Vector3(-5,0,5);floor_model.process_mode=Node.PROCESS_MODE_DISABLED
	mark([],-1,false);await wait_draw();save_image("baseline-original-floor");mark(ids);await wait_draw();save_image("held-original-floor");quad_count(4,"Genuine original floor depth")
	var floor_opaque:=false
	for mesh in floor_model.meshes:
		var material=mesh.material_override
		if material.albedo_color.a==1. and material.transparency==BaseMaterial3D.TRANSPARENCY_DISABLED:floor_opaque=true
	check(floor_opaque,"Genuine original floor contains opaque depth-writing physical geometry")
	floor_model.hide()
	var plane:=MeshInstance3D.new();var plane_mesh:=PlaneMesh.new();plane_mesh.size=Vector2(40,40);plane.mesh=plane_mesh;var plane_material:=ShaderMaterial.new();plane_material.shader=Shader.new();plane_material.shader.code="shader_type spatial;render_mode unshaded,cull_disabled;void fragment(){ALBEDO=vec3(.07);}";plane.material_override=plane_material;scene.add_child(plane)
	mark([],-1,false);await wait_draw();save_image("baseline-opaque-depth-control");mark(ids);await wait_draw();save_image("held-opaque-depth-control")
	check(snapshot_materials()==original_materials and all_alpha(),"Original actors remain immutable while genuine/control floor depth occludes glow")
	plane.hide();mark(ids);await wait_draw();check(save_image("floor-control-removed").get_data()==held.get_data(),"Removing only floor controls restores exact one-body held image")
	var initial_camera:=camera.transform
	for angle in [0.,1.3,2.7]:
		camera.position=Vector3(sin(angle)*20.,9.,cos(angle)*20.);camera.look_at(Vector3(0,1.7,0));mark(ids);await wait_draw();save_image("orbit-"+str(angle));quad_count(4,"Camera orbit "+str(angle))
		var available:=true
		for id in ids:available=available and registry.native_highlight.bounds.diagnostic(id).get("available",false)
		check(available,"One-body projected authored envelope remains finite through orbit "+str(angle));skin_extent_sample("orbit-"+str(angle))
	camera.transform=initial_camera
	var before_pose: Array=[];var pc_skin_before: Dictionary={}
	for actor in actors:
		before_pose.append(actor.rigs.entities[actor.object_id].nodes.map(func(node):return node.transform))
		if actor.object_id>=90001 and actor.object_id<=90002:pc_skin_before[actor.object_id]=actor.rigs.diagnostic_sample([actor.object_id],true)
	for frame in 24:update_rigs(1./60.);mark(ids);await process_frame
	await wait_draw();save_image("animated-skin-and-rigid");quad_count(4,"Animated real Skin and rigid actors")
	var moving:=false
	for at in actors.size():
		var actor=actors[at]
		for index in before_pose[at].size():moving=moving or before_pose[at][index]!=actor.rigs.entities[actor.object_id].nodes[index].transform
	var skin: Dictionary=skin_extent_sample("animated")
	check(moving and skin.skin_meshes>0 and skin.skin_vertices>0,"Actual inherited animation changes physical rig while real Skin diagnostic samples posed vertices")
	var pc_motion: Array=[]
	for actor in actors:
		if not pc_skin_before.has(actor.object_id):continue
		var difference: Dictionary=actor.rigs.compare_samples(pc_skin_before[actor.object_id],actor.rigs.diagnostic_sample([actor.object_id],true));pc_motion.append({"id":actor.object_id,"difference":difference})
		check(difference.changed_local_parts>0 and difference.maximum_local_skin_vertex_delta>.0001,"Actual PC Skin vertices animate through the original mapped walk route "+str(actor.object_id))
	sources.pc_motion=pc_motion
	check(snapshot_materials()==original_materials and all_alpha(),"Animation/whole-body glow preserves exact original mesh/material/texture/tangent identities and alpha")
	var near:=camera.near;var current_body: Dictionary=registry.native_highlight.bounds.diagnostic(ids[0])
	var current_draw: Variant=registry.native_highlight.model_draw_enabled(0,ids[0])
	check(current_body.get("available",false) and float(current_body.get("depth",0.))>near and current_draw==true and camera.far>float(current_body.get("depth",0.)),"Near-plane control derives crossing depth from actual current drawn whole-body fit within camera far plane")
	camera.near=float(current_body.depth);mark(ids);await wait_draw();save_image("near-plane-crossing")
	var rejected_count:=0;var finite_count:=0;var zero_count:=0
	var crossing: Array=[]
	for id in ids:
		var fit: Dictionary=registry.native_highlight.bounds.diagnostic(id);crossing.append({"id":id,"fit":fit})
		if fit.get("reason","")=="whole-body-crosses-camera-near-plane" and fit.get("available",true)==false:rejected_count+=1
	for point in registry.native_highlight.bounds.positions:
		if point.is_finite():finite_count+=1
		if point==Vector3.ZERO:zero_count+=1
	sources.near_plane_control={"selected_id":ids[0],"current_draw":current_draw,"ordinary_near":near,"crossing_near":camera.near,"first_body_before":current_body,"diagnostics":crossing,"rejected_count":rejected_count,"finite_positions":finite_count,"zero_positions":zero_count,"position_count":registry.native_highlight.bounds.positions.size()}
	check(rejected_count==ids.size(),"Near-plane crossing explicitly rejects every selected whole-body fit with the exact source reason")
	check(finite_count==ids.size()*6 and zero_count==ids.size()*6,"Rejected near-plane halos retain only finite zero vertices instead of growing/capping geometry")
	camera.near=near;mark(ids);await wait_draw();quad_count(4,"Near-plane restoration")
	var costs: Array=[]
	for index in 12:
		var began:=Time.get_ticks_usec();mark(ids);costs.append(Time.get_ticks_usec()-began)
	costs.sort();sources.callback_cost={"samples_us":costs,"median_us":costs[6],"p95_us":costs[11],"worst_us":costs.back(),"actors":4,"source_parts":registry.native_highlight.bounds.stats.source_parts,"source_corners":registry.native_highlight.bounds.stats.source_corners,"scope":"12 warmed actual Registry mark + whole-character fit/provider/gather/upload callbacks; no baked Skin diagnostics/readbacks included; not FPS"}
	var removed_id:=int(ids.back());var removed=actors.back();registry.forget_entity(removed_id);removed.retire();actors.pop_back();ids.pop_back();mark(ids);await wait_draw();save_image("retired-pc");quad_count(3,"Actual actor retirement")
	check(not registry.native_highlight.entries.has(removed_id) and not registry.native_highlight.bounds.entries.has(removed_id),"Removed character leaves neither controller nor glow ownership")
	scope_alive=false;registry.native_highlight._process(0.);check(not registry.native_highlight.bounds.batch.visible,"Retired world scope fences stale whole-character publication")
	check(root.current_screen!=DisplayServer.get_primary_screen() and root.unfocusable and not root.has_focus() and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"Functional check preserves nonprimary/unfocused/uncaptured policy")
	finish_result(false)
func finish_result(asset_only: bool) -> void:
	var glow_state: Dictionary=registry.highlight_snapshot() if is_instance_valid(registry) else {}
	if is_instance_valid(registry):registry.native_highlight.close();registry.free();registry=null
	for actor in actors:
		if is_instance_valid(actor):actor.retire()
	actors.clear()
	if is_instance_valid(pc_stream):pc_stream.close();pc_stream.free()
	if is_instance_valid(service):service.close();service.free()
	if pool!=null:pool.clear()
	if is_instance_valid(scene):scene.free()
	await process_frame;await process_frame
	var value:={"success":failures.is_empty(),"checks":checks,"failures":failures,"asset_only":asset_only,"sources":sources,"captures":captures,"skin_extent_diagnostics":diagnostics,"highlight":glow_state,"serverConnections":0,"nativeBuilds":0,"performanceClaim":false,"nativeVisualParityClaim":false,"scope":"User-requested ONE camera-facing soft original-texture quad per whole character. Recovered c_goldem pair + original installed BIC robe/Skin PC opaque/translucent controls, real native factories/Registry/animation/materials; original Prelude floor and separately authored opaque-plane depth control. Authored layout/camera/perception alpha and scope. Body envelope is projected authored Part boxes incl Skin, not exact deformed Skin hull or original native per-Part visual parity. Independent posed-Skin overflow is diagnostic, never used to create glow geometry."}
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(value,"  "));print("WHOLE_CHARACTER_GLOW_PIXELS ",checks," checks ",failures.size()," failures");quit(0 if value.success else 1)
