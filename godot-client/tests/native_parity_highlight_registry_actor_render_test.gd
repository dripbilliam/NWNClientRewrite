extends SceneTree
# Actual installed actor preparation, native rig storage, ordinary Registry,
# borrowed texture service and candidate controller. Bounded functional/callback
# cost attribution; no native-binary/live-server FPS comparison.
const Actor=preload("res://systems/native_render/actor_instance.gd")
const Registry=preload("res://systems/native_render/door_entity_registry.gd")
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Assets=preload("res://systems/native_data/asset_service.gd")
const Pool=preload("res://systems/native_render/resource_pool.gd")
const Palette=preload("res://systems/native_render/native_light_palette.gd")
var checks:=0
var failures: Array=[]
var completed: Dictionary={}
var retained_extension: Resource
var retained_highlight_extension: Resource
var actors: Array=[]
var ids: Array=[]
var phase_reports: Array=[]
var walk_clip:=""
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label);print("FAIL ",label)
func _initialize() -> void:run.call_deferred()
func wait_draw() -> void:
	for frame in 3:await process_frame
	await RenderingServer.frame_post_draw
func counters() -> Dictionary:
	var result:={"scope":"This same primary viewport; not server/native-binary FPS"}
	var constants:=ClassDB.class_get_integer_constant_list("Viewport")
	for item in {"draw_calls":"RENDER_INFO_DRAW_CALLS_IN_FRAME","primitives":"RENDER_INFO_PRIMITIVES_IN_FRAME","objects":"RENDER_INFO_OBJECTS_IN_FRAME"}:
		var name: String={"draw_calls":"RENDER_INFO_DRAW_CALLS_IN_FRAME","primitives":"RENDER_INFO_PRIMITIVES_IN_FRAME","objects":"RENDER_INFO_OBJECTS_IN_FRAME"}[item]
		result[item]=root.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE,ClassDB.class_get_integer_constant("Viewport",name)) if constants.has(name) else null
	return result
func update_rigs(delta: float) -> void:
	for actor in actors:
		if not actor.retired:actor.rigs._update(delta)
func measure(registry,mode: String,selected: Array) -> Dictionary:
	var samples: Array=[]
	for repeat_index in 12:
		var began:=Time.get_ticks_usec();registry.mark(selected,-1,true)
		if mode=="native":registry.native_highlight._process(0.0)
		samples.append(Time.get_ticks_usec()-began)
	samples.sort()
	var meshes:=0;var overlays:=0
	for actor in actors:
		for mesh in actor.meshes:
			meshes+=1
			if mesh.material_overlay!=null:overlays+=1
	return {"mode":mode,"method_us":samples,"median_method_us":samples[6],"worst_method_us":samples.back(),"meshes":meshes,"material_overlays":overlays,"draw":counters(),"highlight":registry.highlight_snapshot(),"scope":"12 bounded same-scene mark/controller calls; native includes CPU bounds assembly; legacy includes its actual mark route; not FPS"}
func alpha_matches() -> bool:
	for actor in actors:
		if actor.retired:continue
		for mesh in actor.meshes:
			var material=mesh.material_override
			if not material.has_method("publish_actor_part_pose"):return false
			var context=material.actor_alpha_context
			var expected:=preload("res://tools/native_parity/ui/actor-alpha-publication.gd").compose(material.actor_part_color.a,context.alpha,context.multiplications)
			if absf(material.albedo_color.a-expected)>0.000001:return false
	return true
func run() -> void:
	var output:="";var install:="";var expected_screen:=2
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):output=arg.substr(9)
		elif arg.begins_with("--install="):install=arg.substr(10)
		elif arg.begins_with("--expected-screen="):expected_screen=int(arg.substr(18))
	if output.is_empty() or install.is_empty() or FileAccess.file_exists(output):quit(2);return
	if OS.get_cmdline_user_args().has("--highlight-kernel=compiled"):
		retained_highlight_extension=load("res://native/highlight_geometry.gdextension")
		check(retained_highlight_extension!=null and ClassDB.class_exists("NwnHighlightGeometry"),"Standalone highlight extension coexists with approved particle/native storage extension")
	retained_extension=load("res://native/particle_kernel.gdextension")
	check(retained_extension!=null and ClassDB.class_exists("NwnModelPoseStorage"),"Approved native storage DLL loads without rebuilding")
	var window:={"screen":root.current_screen,"primary":DisplayServer.get_primary_screen(),"focused":root.has_focus(),"unfocusable":root.unfocusable,"mouse":Input.get_mouse_mode()}
	check(window.screen==expected_screen and window.screen!=window.primary and not window.focused and window.unfocusable and window.mouse==Input.MOUSE_MODE_VISIBLE,"Actual registry fixture stays on configured nonprimary screen/unfocused without mouse capture")
	var catalog:=Catalog.new();check(catalog.mount_install(install) and catalog.mount_directory("C:/Users/Niflheim/Documents/Neverwinter Nights.0/override",10000000),"Actual original/profile catalog mounts read-only")
	var service:=Assets.new();root.add_child(service);service.configure(catalog);service.maximum_workers=1;service.cache_directory=output.get_base_dir().path_join("asset-cache");service.completed.connect(func(id,result):completed[id]=result)
	var request:=service.request("c_goblina",2002,"actor-model",{"relevant_tracks":true})
	var deadline:=Time.get_ticks_msec()+30000
	while not completed.has(request) and Time.get_ticks_msec()<deadline:await process_frame
	var bundle: Dictionary=completed.get(request,{})
	check(not bundle.is_empty() and str(bundle.get("error","missing")).is_empty(),"Actual local animated creature prepares through native AssetService: "+str(bundle.get("error")))
	if bundle.is_empty() or not str(bundle.get("error","")).is_empty():service.close();service.free();quit(1);return
	var world:=Node3D.new();root.add_child(world)
	var environment:=WorldEnvironment.new();environment.environment=Environment.new();environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color(0.025,0.03,0.05);world.add_child(environment)
	var camera:=Camera3D.new();world.add_child(camera);camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=9;camera.position=Vector3(8,9,13);camera.look_at(Vector3(0,1,0));camera.current=true
	Palette.ambient(Vector3.ONE)
	var pool:=Pool.new();pool.native_lighting=true;pool.native_surface_output=false
	var registry:=Registry.new();registry.native_highlight_enabled=false;world.add_child(registry)
	for index in 12:
		var actor:=Actor.new();actor.actor_alpha_enabled=true;world.add_child(actor)
		var pieces: Array=[{"bundle":bundle}]
		if index==0:pieces.append({"bundle":bundle,"equipmentSlot":16,"scale":0.4})
		var id: int=30000+index
		check(actor.install(pieces,pool,id,{},72),"Actual original actor installs "+str(index)+": "+actor.failure)
		if actor.rigs==null:actor.retire();continue
		actor.rigs.set_process(false);actor.position=Vector3((index%4-1.5)*2.3,0,(index/4-1)*2.6)
		actor.set_meta("native_selection_scope",[1,2,3,id,1]);actors.append(actor);ids.append(id)
		var declared: Array=[]
		var native_clips: Dictionary=actor.rigs.entities[id].models[0].asset_source.nativeAnimation.clips
		for clip in actor.rigs.entities[id].models[0].asset_source.clips:
			if native_clips.get(str(clip.name),{}).has("root"):declared.append(str(clip.name))
		if walk_clip.is_empty():
			for candidate in ["cwalkf","walk","cwalk","walk1"]:
				if declared.has(candidate):walk_clip=candidate;break
			if walk_clip.is_empty():
				for candidate in declared:
					if "walk" in str(candidate):walk_clip=str(candidate);break
			print("ACTUAL_DECLARED_WALK ",walk_clip," CLIPS ",declared)
		check(not walk_clip.is_empty() and actor.rigs.play_native(id,0,walk_clip,1.0,0,0.0),"Actual native controller selects declared inherited walk clip")
		actor.rigs._update(0.0);actor.set_renderer_alpha(0.25,actor.renderer_alpha_model_indices())
		check(registry.register_native(id,{"id":id,"type":5,"eligible":true,"color":"#00ff00"},actor),"Ordinary registry admits actual creature")
	check(actors.size()==12 and ids.size()==12,"Equivalent comparison retains all twelve animated translucent creatures")
	var native_storage:=0;var source_nodes:=0
	for actor in actors:
		for model in actor.rigs.entities[actor.object_id].models:
			if model.has("native_owner") and model.native_owner.pose.native_context!=null:native_storage+=1
		source_nodes+=actor.rigs.entities[actor.object_id].model_parts[0].size()
	check(native_storage>=12 and source_nodes>12,"Real actor native storage and original physical hierarchy are active")
	update_rigs(0);await wait_draw();var baseline:=root.get_texture().get_image();baseline.save_png(output.trim_suffix(".json")+"-baseline.png")
	registry.mark(ids);await wait_draw();phase_reports.append(measure(registry,"legacy",ids));var legacy:=root.get_texture().get_image();legacy.save_png(output.trim_suffix(".json")+"-legacy.png")
	check(phase_reports.back().material_overlays>0 and alpha_matches(),"Legacy phase genuinely adds full-mesh overlays to same translucent content")
	registry.mark([]);await wait_draw();check(root.get_texture().get_image().get_data()==baseline.get_data(),"Legacy unmark returns exact original scene before native comparison")
	registry.native_highlight_enabled=true;registry.configure_highlights(camera);registry.configure_highlight_assets(service,catalog,pool);registry.native_highlight.set_process(false)
	for actor in actors:registry.register_native(actor.object_id,{"id":actor.object_id,"type":5,"eligible":true,"color":"#00ff00","fixture_native_phase":true},actor)
	deadline=Time.get_ticks_msec()+15000
	while registry.native_highlight.texture_source.status=="loading" and Time.get_ticks_msec()<deadline:await process_frame
	check(registry.native_highlight.bounds.texture_ready and registry.native_highlight.texture_source.status=="ready","Actual Registry uses borrowed native texture service and original DDS/TXI")
	registry.mark(ids,-1,true);registry.native_highlight._process(0.0);await wait_draw();phase_reports.append(measure(registry,"native",ids));await wait_draw()
	var marked:=root.get_texture().get_image();marked.save_png(output.trim_suffix(".json")+"-native.png")
	check(phase_reports.back().material_overlays==0 and registry.native_highlight.bounds.stats.vertices>0,"Actual native route uses base channels plus retained textured bounds, no full-mesh overlay")
	check(alpha_matches() and registry.native_highlight.stats.channel_failures==0,"Actual native actor pose publications retain all translucent alpha factors")
	var writes: int=registry.native_highlight.stats.channel_writes;var stable:=true
	for frame in 12:
		update_rigs(0.0);registry.mark(ids,-1,true);registry.native_highlight._process(0.0);await wait_draw()
		if root.get_texture().get_image().get_data()!=marked.get_data():stable=false
	check(stable and registry.native_highlight.stats.channel_writes==writes,"Held Tab at fixed native pose/pulse has exact stable real-actor pixels and no repeated channel writes")
	var first=actors[0];first.set_renderer_vector(3,Vector3(0.2,0.3,0.7),first.renderer_alpha_model_indices());first.set_renderer_vector(0,Vector3(1,0,0),[1])
	registry.mark(ids,first.object_id,true);registry.native_highlight._process(0.0)
	check(first.actor_alpha.models[0].vector_active[1]==1 and first.actor_alpha.models[0].vector_active[2]==1 and first.actor_alpha.models[0].vector_active[3]==1,"Real actor hover1/Tab2/Type5channel3 coexist")
	check(registry.native_highlight.model_color(0,first.object_id)==Vector3(0,1,0) and registry.native_highlight.model_color(1,first.object_id)==Vector3(1,0,0),"Actual child Gob retains independent higher-priority channel color")
	registry.mark(ids,first.object_id,false);check(first.actor_alpha.models[0].vector_active[2]==0 and first.actor_alpha.models[0].vector_active[1]==1,"Actual Tab release preserves hovered actor channel1")
	registry.mark([],-1,false);check(first.actor_alpha.models[0].selected_vector==Vector3(0.2,0.3,0.7) and first.actor_alpha.models[1].selected_vector==Vector3(1,0,0),"Selection clear restores independent body/equipment server channels")
	first.set_renderer_vector(3,null,first.renderer_alpha_model_indices());first.set_renderer_vector(0,null,[1]);registry.mark(ids,-1,true)
	var before_animation: Array=[]
	for node in first.rigs.entities[first.object_id].nodes:before_animation.append(node.transform)
	var animated_alpha_ok:=true
	for frame in 24:
		update_rigs(1.0/60.0);registry.mark(ids,-1,true);registry.native_highlight._process(1.0/60.0)
		if not alpha_matches():animated_alpha_ok=false
		await process_frame
	check(animated_alpha_ok,"Actual inherited walk animation cycles retain native alpha while Tab pulse advances")
	var changed_pose:=false
	for index in before_animation.size():
		if first.rigs.entities[first.object_id].nodes[index].transform!=before_animation[index]:changed_pose=true
	check(changed_pose,"Declared native clip changes actual physical bone/Part transforms")
	await wait_draw();root.get_texture().get_image().save_png(output.trim_suffix(".json")+"-animated.png")
	var id: int=first.object_id;registry.native_highlight.bounds.entries[id].color_source=func(_model):registry.forget_entity(id);return Vector3.ONE
	var updates: int=registry.native_highlight.bounds.stats.updates;registry.native_highlight._process(0.0)
	check(not registry.native_highlight.entries.has(id) and registry.native_highlight.bounds.stats.updates==updates and not registry.native_highlight.bounds.batch.visible,"Actual Registry removal during color-provider callback revokes pending batch publication")
	registry.forget_entity(ids[1]);var retired=actors[1];retired.retire()
	check(not registry.native_highlight.entries.has(ids[1]),"Actual retired actor cannot remain in native selection membership")
	registry.mark([],-1,false);registry.native_highlight.close();registry.free()
	for actor in actors:
		if not actor.retired:actor.retire()
	service.close();service.free();pool.clear();world.free();await process_frame;await process_frame
	var file:=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"window":window,"phases":phase_reports,"native_storage_models":native_storage,"model_sha256":bundle.sha256,"model_name":bundle.value.name,"walk_clip":walk_clip,"performanceClaim":false,"scope":"Actual ordinaryRegistry+nativeActor/AssetService local comparison. Same12actors/poses/camera; callback cost and draw counters only, not native-binary/live-server FPS acceptance."},"  ")+"\n");file.close();quit(0 if failures.is_empty() else 1)
